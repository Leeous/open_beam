import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/io_client.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vizio_remote/data/models/discovered_tv.dart';

class TvCacheRepository {
  static const String _discoveredKey = 'cached_discovered_tvs';
  static const String _authPrefix = 'vizio_auth_';

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secureStorage;
  final NetworkInfo _networkInfo;

  TvCacheRepository(
    this._prefs,
    this._secureStorage, {
    NetworkInfo? networkInfo,
  }) : _networkInfo = networkInfo ?? NetworkInfo();

  // ---------------------------------------------------------------------------
  // Local Cache Methods
  // ---------------------------------------------------------------------------

  /// Saves or updates a [DiscoveredTv] in local storage.
  /// Securely isolates the auth token in FlutterSecureStorage while storing
  /// metadata in SharedPreferences.
  Future<void> saveTv(DiscoveredTv tv) async {
    if (tv.authToken != null && tv.authToken!.isNotEmpty) {
      await _secureStorage.write(
        key: '$_authPrefix${tv.id}',
        value: tv.authToken,
      );
    }

    final List<DiscoveredTv> current = await loadTvs();
    final index = current.indexWhere((item) => item.id == tv.id);

    if (index >= 0) {
      current[index] = tv;
    } else {
      current.add(tv);
    }

    final jsonList = current.map((item) {
      final map = item.toJson();
      map.remove(
        'authToken',
      ); // Keep secure credentials out of SharedPreferences
      return map;
    }).toList();

    await _prefs.setString(_discoveredKey, jsonEncode(jsonList));
  }

  /// Loads all cached TVs and attaches their secure auth tokens.
  Future<List<DiscoveredTv>> loadTvs() async {
    final rawJson = _prefs.getString(_discoveredKey);
    if (rawJson == null) return [];

    final List<dynamic> decoded = jsonDecode(rawJson) as List<dynamic>;
    final List<DiscoveredTv> tvs = [];

    for (final item in decoded) {
      final map = item as Map<String, dynamic>;
      final id = map['id'] as String;

      final token = await _secureStorage.read(key: '$_authPrefix$id');
      tvs.add(DiscoveredTv.fromJson(map, authToken: token));
    }

    return tvs;
  }

  // ---------------------------------------------------------------------------
  // Network Verification & Subnet Discovery
  // ---------------------------------------------------------------------------

  /// Fast TCP socket ping to check if a single IP:port is reachable.
  Future<bool> pingTv(
    String ip,
    int port, {
    Duration timeout = const Duration(milliseconds: 1200),
  }) async {
    try {
      final socket = await Socket.connect(ip, port, timeout: timeout);
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Pings all cached TVs in parallel and returns their online status.
  Future<List<({DiscoveredTv tv, bool isOnline})>>
  getVerifiedCachedTvs() async {
    final cached = await loadTvs();

    return Future.wait(
      cached.map((tv) async {
        final isOnline = await pingTv(tv.ipAddress, tv.port);
        return (tv: tv, isOnline: isOnline);
      }),
    );
  }

  /// Scans the current LAN subnet (ports 7345 and 9000), verifies Vizio HTTPS endpoints,
  /// merges results with local cache, and returns the updated list.
  Future<List<DiscoveredTv>> scanAndSyncNetwork({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final String? wifiIp = await _networkInfo.getWifiIP();
    if (wifiIp == null || wifiIp.isEmpty) {
      if (kDebugMode) print('TvCacheRepository: Device is not connected to Wi-Fi.');
      return loadTvs();
    }

    final String subnetPrefix = wifiIp.substring(
      0,
      wifiIp.lastIndexOf('.') + 1,
    );

    final List<int> targetPorts = [7345, 9000];
    final List<DiscoveredTv> discoveredDevices = [];
    final List<Future<void>> scanFutures = [];

    for (int i = 1; i < 255; i++) {
      final String targetIp = "$subnetPrefix$i";

      for (int port in targetPorts) {
        scanFutures.add(
          _checkAndVerifyVizio(targetIp, port, timeout).then((device) {
            if (device != null) {
              discoveredDevices.add(device);
            }
          }),
        );
      }
    }

    await Future.wait(scanFutures);

    // Merge discovered devices with existing cache
    final List<DiscoveredTv> cached = await loadTvs();

    for (final device in discoveredDevices) {
      final existingIndex = cached.indexWhere(
        (c) => c.name == device.name || c.ipAddress == device.ipAddress,
      );

      if (existingIndex >= 0) {
        final existing = cached[existingIndex];
        final updated = existing.copyWith(
          ipAddress: device.ipAddress,
          port: device.port,
          lastSeen: DateTime.now(),
        );
        await saveTv(updated);
      } else {
        await saveTv(device);
      }
    }

    return loadTvs();
  }

  /// Performs a fast TCP pre-check followed by an HTTPS deviceinfo query.
  Future<DiscoveredTv?> _checkAndVerifyVizio(
    String ip,
    int port,
    Duration timeout,
  ) async {
    final bool isOpen = await pingTv(ip, port, timeout: timeout);
    if (!isOpen) return null;

    final ioClient = HttpClient()
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;

    final client = IOClient(ioClient);

    try {
      final response = await client
          .get(Uri.parse('https://$ip:$port/state/device/deviceinfo'))
          .timeout(timeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;
        final items = data['ITEMS'] as List?;

        if (items != null && items.isNotEmpty) {
          final Map<String, dynamic> item = items.first as Map<String, dynamic>;
          final String? itemName = item['NAME'] as String?;

          if (itemName != null && itemName.toLowerCase().contains('vizio')) {
            final value = item['VALUE'] as Map<String, dynamic>?;

            final String castName = value?['CAST_NAME'] as String? ?? '';
            final String modelName =
                value?['MODEL_NAME'] as String? ?? 'Vizio TV';

            final String displayName = castName.isNotEmpty
                ? castName
                : modelName;

            return DiscoveredTv(
              id: ip,
              name: displayName,
              ipAddress: ip,
              port: port,
              lastSeen: DateTime.now(),
            );
          }
        }
      }
    } catch (_) {
      // Non-Vizio device or TLS handshake error
    } finally {
      client.close();
    }

    return null;
  }
}

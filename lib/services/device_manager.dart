import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/io_client.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class DiscoveredDevice {
  final String name;
  final String ip;
  final int port;

  DiscoveredDevice({required this.name, required this.ip, required this.port});

  @override
  String toString() => '$name ($ip:$port)';
}

/// Scan current device LAN for devices listening on 7345 or 9000, and verifies
/// if the device is a valid Vizio TV by polling /state/device/deviceinfo for TV
/// name and IP.
///
class LanScannerService {
  final NetworkInfo _networkInfo = NetworkInfo();

  Future<List<DiscoveredDevice>> scanForVizioDevices({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final List<DiscoveredDevice> discoveredDevices = [];

    final String? wifiIp = await _networkInfo.getWifiIP();
    if (wifiIp == null || wifiIp.isEmpty) {
      print('Not connected to WiFi.');
      return [];
    }

    final String subnetPrefix = wifiIp.substring(
      0,
      wifiIp.lastIndexOf('.') + 1,
    );

    // Known Vizio TV ports
    final List<int> targetPorts = [7345, 9000];
    final List<Future<void>> scanFutures = [];

    // Scan network for devices with open targetPorts
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

    // Wait for scan to complete
    await Future.wait(scanFutures);

    return discoveredDevices;
  }

  /// 1. Checks if socket port is open
  /// 2. Queries /state/device/deviceinfo over HTTPS
  /// 3. Validates Vizio payload and extracts TV display name
  Future<DiscoveredDevice?> _checkAndVerifyVizio(
    String ip,
    int port,
    Duration timeout,
  ) async {
    // Fast socket pre-check before executing HTTPS handshake
    final bool isOpen = await _checkPort(ip, port, timeout);
    if (!isOpen) return null;

    // Create HttpClient that bypasses Vizio's self-signed SSL cert
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

          // Verify this is a Vizio device response
          if (itemName != null && itemName.toLowerCase().contains('vizio')) {
            // Cast VALUE explicitly to avoid 'dynamic' assignment error
            final value = item['VALUE'] as Map<String, dynamic>?;

            final String castName = value?['CAST_NAME'] as String? ?? '';
            final String modelName =
                value?['MODEL_NAME'] as String? ?? 'Vizio TV';

            final String displayName = castName.isNotEmpty
                ? castName
                : modelName;

            return DiscoveredDevice(name: displayName, ip: ip, port: port);
          }
        }
      }
    } catch (e) {
      // Non-Vizio device or HTTP connection error
    } finally {
      client.close();
    }

    return null;
  }

  Future<bool> _checkPort(String ip, int port, Duration timeout) async {
    try {
      final socket = await Socket.connect(ip, port, timeout: timeout);
      socket.destroy();
      return true;
    } catch (error) {
      return false;
    }
  }
}

class VizioRemoteService {
  final String tvIp;
  final int port;
  final String? authToken;

  late final http.Client _client;

  VizioRemoteService({required this.tvIp, this.port = 7345, this.authToken}) {
    final ioClient = HttpClient()
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        return true;
      }
      ..connectionTimeout = const Duration(seconds: 8);

    _client = IOClient(ioClient);
  }

  Map<String, String> _buildHeaders() {
    final headers = <String, String>{'Content-Type': 'application/json'};

    if (authToken != null && authToken!.isNotEmpty) {
      headers['AUTH'] = authToken!;
    }

    return headers;
  }

  Future<Map<String, dynamic>?> sendPutRequest({
    required String endpoint,
    required Map<String, dynamic> body,
    Duration timeout = const Duration(seconds: 8),
    int maxAttempts = 2,
  }) async {
    final uri = Uri.parse('https://$tvIp:$port$endpoint');

    _debugLog('PUT', uri.toString(), body: body);

    Duration currentTimeout = timeout;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await _client
            .put(uri, headers: _buildHeaders(), body: jsonEncode(body))
            .timeout(currentTimeout);

        // Safely decode response body for debug logging
        Object? decodedBody;
        try {
          decodedBody = response.body.isNotEmpty
              ? jsonDecode(response.body)
              : null;
        } catch (_) {
          decodedBody = response.body;
        }

        _debugLog('PUT RESPONSE', uri.toString(), body: decodedBody);

        if (response.statusCode == 200) {
          if (decodedBody is Map<String, dynamic>) return decodedBody;
          // If decoding produced a non-map (or null), try to decode fresh
          return jsonDecode(response.body) as Map<String, dynamic>?;
        }

        print('HTTP Error: ${response.statusCode} - ${response.body}');
        return null;
      } on TimeoutException catch (e) {
        if (attempt >= maxAttempts) {
          print('Request timed out: $e');
          return null;
        }
        // increase timeout and retry
        currentTimeout = Duration(seconds: currentTimeout.inSeconds * 2);
        await Future<void>.delayed(const Duration(milliseconds: 200));
        continue;
      } on http.ClientException catch (e) {
        if (attempt >= maxAttempts) {
          print('Connection Error: $e');
          return null;
        }
        currentTimeout = Duration(seconds: currentTimeout.inSeconds + 4);
        await Future<void>.delayed(const Duration(milliseconds: 200));
        continue;
      } on SocketException catch (e) {
        if (attempt >= maxAttempts) {
          print('Socket Error: $e');
          return null;
        }
        currentTimeout = Duration(seconds: currentTimeout.inSeconds + 4);
        await Future<void>.delayed(const Duration(milliseconds: 200));
        continue;
      } catch (error) {
        print('Connection Error: $error');
        return null;
      }
    }

    return null;
  }

  Future<Map<String, dynamic>?> sendPostRequest({
    required String endpoint,
    required Map<String, dynamic> body,
    Duration timeout = const Duration(seconds: 8),
    int maxAttempts = 2,
  }) async {
    final uri = Uri.parse('https://$tvIp:$port$endpoint');

    _debugLog('POST', uri.toString(), body: body);

    Duration currentTimeout = timeout;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await _client
            .post(uri, headers: _buildHeaders(), body: jsonEncode(body))
            .timeout(currentTimeout);

        Object? decodedBody;
        try {
          decodedBody = response.body.isNotEmpty
              ? jsonDecode(response.body)
              : null;
        } catch (_) {
          decodedBody = response.body;
        }

        _debugLog('POST RESPONSE', uri.toString(), body: decodedBody);

        if (response.statusCode == 200) {
          if (decodedBody is Map<String, dynamic>) return decodedBody;
          return jsonDecode(response.body) as Map<String, dynamic>?;
        }

        print('HTTP Error: ${response.statusCode} - ${response.body}');
        return null;
      } on TimeoutException catch (e) {
        if (attempt >= maxAttempts) {
          print('Request timed out: $e');
          return null;
        }
        currentTimeout = Duration(seconds: currentTimeout.inSeconds * 2);
        await Future<void>.delayed(const Duration(milliseconds: 200));
        continue;
      } on http.ClientException catch (e) {
        if (attempt >= maxAttempts) {
          print('Connection Error: $e');
          return null;
        }
        currentTimeout = Duration(seconds: currentTimeout.inSeconds + 4);
        await Future<void>.delayed(const Duration(milliseconds: 200));
        continue;
      } on SocketException catch (e) {
        if (attempt >= maxAttempts) {
          print('Socket Error: $e');
          return null;
        }
        currentTimeout = Duration(seconds: currentTimeout.inSeconds + 4);
        await Future<void>.delayed(const Duration(milliseconds: 200));
        continue;
      } catch (error) {
        print('Connection Error: $error');
        return null;
      }
    }

    return null;
  }

  Future<PairingChallenge?> startPairing({
    required String deviceId,
    required String deviceName,
  }) async {
    final endpoint = '/pairing/start';
    final body = <String, dynamic>{
      'DEVICE_ID': deviceId,
      'DEVICE_NAME': deviceName,
    };

    final response = await sendPutRequest(endpoint: endpoint, body: body);
    if (response == null) {
      return null;
    }

    final item = response['ITEM'];
    if (item is! Map<String, dynamic>) {
      return null;
    }

    final pairingReqToken = item['PAIRING_REQ_TOKEN'];
    final challengeType = item['CHALLENGE_TYPE'];

    if (pairingReqToken is int && challengeType is int) {
      return PairingChallenge(
        deviceId: deviceId,
        pairingReqToken: pairingReqToken,
        challengeType: challengeType,
      );
    }

    return null;
  }

  Future<String?> confirmPairing({
    required String deviceId,
    required String pin,
    required int pairingReqToken,
    required int challengeType,
  }) async {
    final endpoint = '/pairing/pair';
    final body = <String, dynamic>{
      'DEVICE_ID': deviceId,
      'CHALLENGE_TYPE': challengeType,
      'RESPONSE_VALUE': pin,
      'PAIRING_REQ_TOKEN': pairingReqToken,
    };

    final response = await sendPutRequest(endpoint: endpoint, body: body);
    if (response == null) {
      return null;
    }

    return _extractAuthToken(response);
  }

  Future<bool> cancelPairing({
    required String deviceId,
    required int pairingReqToken,
    required int challengeType,
    String responseValue = '',
  }) async {
    final endpoint = '/pairing/cancel';
    final body = <String, dynamic>{
      'DEVICE_ID': deviceId,
      'CHALLENGE_TYPE': challengeType,
      'RESPONSE_VALUE': responseValue,
      'PAIRING_REQ_TOKEN': pairingReqToken,
    };

    final response = await sendPutRequest(endpoint: endpoint, body: body);
    return response != null;
  }

  String? _extractAuthToken(Map<String, dynamic> response) {
    final tokenKeys = ['AUTH', 'auth', 'token', 'AUTH_TOKEN', 'authToken'];

    for (final key in tokenKeys) {
      final token = response[key];
      if (token is String && token.isNotEmpty) {
        return token;
      }
    }

    final item = response['ITEM'];
    if (item is Map<String, dynamic>) {
      for (final key in tokenKeys) {
        final token = item[key];
        if (token is String && token.isNotEmpty) {
          return token;
        }
      }
    }

    return null;
  }

  void _debugLog(String label, String url, {required Object? body}) {
    if (!kDebugMode) return;

    final payload = body is String ? body : jsonEncode(body);
    print('VizioRemoteService: $label $url');
    print('VizioRemoteService: BODY $payload');
  }

  Future<bool> sendKeyPress(int codeSet, int code) async {
    final endpoint = '/keypress';
    final body = <String, dynamic>{
      'CODE_SET': codeSet,
      'CODE': code,
      'ACTION': 'KEYPRESS',
    };

    final response = await sendPutRequest(endpoint: endpoint, body: body);

    return response != null;
  }
}

class PairingChallenge {
  final String deviceId;
  final int pairingReqToken;
  final int challengeType;

  PairingChallenge({
    required this.deviceId,
    required this.pairingReqToken,
    required this.challengeType,
  });
}

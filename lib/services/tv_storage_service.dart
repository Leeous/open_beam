import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:open_beam/models/paired_tv_device.dart';
import 'package:open_beam/services/logging_helper.dart';

/// Manages persistent, encrypted storage for paired TV devices and active session state.
///
/// Uses [FlutterSecureStorage] to ensure sensitive tokens (such as Vizio auth tokens)
/// are encrypted at rest using platform-native security mechanisms (Keychain on iOS/macOS,
/// Keystore on Android).
class TvStorageService {
  /// Storage key mapping to the JSON-serialized list of [PairedTvDevice] instances.
  static const _storageKey = 'openbeam_paired_tvs';

  /// Storage key mapping to the unique identifier of the currently active TV.
  static const _activeTvKey = 'openbeam_active_tv_id';

  final FlutterSecureStorage _storage;

  /// Creates a [TvStorageService].
  ///
  /// Optionally accepts a custom [_storage] instance for testing and dependency injection.
  const TvStorageService({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(resetOnError: true),
          );

  /// Retrieves all paired TV devices stored on the device.
  ///
  /// Returns an empty list if no devices have been saved or if an unrecoverable
  /// deserialization error occurs.
  Future<List<PairedTvDevice>> getPairedDevices() async {
    try {
      final jsonString = await _storage.read(key: _storageKey);
      if (jsonString == null || jsonString.isEmpty) return [];

      final decoded = jsonDecode(jsonString) as List<dynamic>;
      return decoded
          .map((item) => PairedTvDevice.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      dPrint('Failed to load paired devices: $e');
      return [];
    }
  }

  /// Saves a [device] to secure storage.
  ///
  /// If a device with matching [PairedTvDevice.id] already exists, it will be updated
  /// in-place; otherwise, the new device is appended to the saved list.
  Future<void> saveDevice(PairedTvDevice device) async {
    final devices = await getPairedDevices();
    final index = devices.indexWhere((d) => d.id == device.id);

    if (index >= 0) {
      devices[index] = device;
    } else {
      devices.add(device);
    }

    await _persistDeviceList(devices);
  }

  /// Removes the device matching [deviceId] from storage.
  ///
  /// If the removed device is currently marked as the active TV, the active TV
  /// reference is cleared as well.
  Future<void> removeDevice(String deviceId) async {
    final devices = await getPairedDevices();
    devices.removeWhere((d) => d.id == deviceId);
    await _persistDeviceList(devices);

    final activeId = await getActiveDeviceId();
    if (activeId == deviceId) {
      await _storage.delete(key: _activeTvKey);
    }
  }

  /// Persists the [deviceId] of the currently selected TV session.
  Future<void> setActiveDeviceId(String deviceId) async {
    await _storage.write(key: _activeTvKey, value: deviceId);
  }

  /// Retrieves the identifier for the currently active TV, or `null` if none is set.
  Future<String?> getActiveDeviceId() async {
    return _storage.read(key: _activeTvKey);
  }

  /// Serializes and writes [devices] to [_storageKey].
  Future<void> _persistDeviceList(List<PairedTvDevice> devices) async {
    final jsonString = jsonEncode(devices.map((d) => d.toJson()).toList());
    await _storage.write(key: _storageKey, value: jsonString);
  }
}

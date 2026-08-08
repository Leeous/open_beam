import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:vizio_remote/remote_screen.dart';
import 'services/device_manager.dart';

class TVListScreen extends StatefulWidget {
  const TVListScreen({super.key});

  @override
  State<TVListScreen> createState() => _TVListScreen();
}

class _TVListScreen extends State<TVListScreen> {
  final LanScannerService _scannerService = LanScannerService();
  List<DiscoveredDevice> _discoveredDevices = [];
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _discoveredDevices = [];
    });

    final devices = await _scannerService.scanForVizioDevices();

    if (!mounted) return;

    setState(() {
      _discoveredDevices = devices;
      _isScanning = false;
    });
  }

  Future<void> _onDeviceTap(DiscoveredDevice device) async {
    final localDeviceName = await _resolveLocalDeviceName();
    final deviceId = _buildDeviceId(localDeviceName);
    final service = VizioRemoteService(tvIp: device.ip, port: device.port);

    if (!mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const AlertDialog(
          content: SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          ),
        );
      },
    );

    final challenge = await service.startPairing(
      deviceId: deviceId,
      deviceName: localDeviceName,
    );

    if (!mounted) return;
    Navigator.of(context).pop();

    if (challenge == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to initiate pairing with TV.')),
      );
      return;
    }

    final pin = await _showPinDialog(context, device.name);
    if (pin == null || pin.isEmpty) {
      await service.cancelPairing(
        deviceId: deviceId,
        pairingReqToken: challenge.pairingReqToken,
        challengeType: challenge.challengeType,
        responseValue: '',
      );
      return;
    }

    if (!mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const AlertDialog(
          content: SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          ),
        );
      },
    );

    final authToken = await service.confirmPairing(
      deviceId: deviceId,
      pin: pin,
      pairingReqToken: challenge.pairingReqToken,
      challengeType: challenge.challengeType,
    );

    if (!mounted) return;
    Navigator.of(context).pop();

    if (authToken == null || authToken.isEmpty) {
      await service.cancelPairing(
        deviceId: deviceId,
        pairingReqToken: challenge.pairingReqToken,
        challengeType: challenge.challengeType,
        responseValue: pin,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pairing failed. Check the displayed PIN and try again.',
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => RemoteScreen(
          tvName: device.name,
          tvIp: device.ip,
          port: device.port,
          authToken: authToken,
        ),
      ),
    );
  }

  String _buildDeviceId(String deviceName) {
    final cleaned = deviceName
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9_]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();

    return 'VIZIO_REMOTE_${cleaned.isEmpty ? 'APP' : cleaned}';
  }

  Future<String> _resolveLocalDeviceName() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        final deviceName = androidInfo.device;
        final model = androidInfo.model;
        if (deviceName.isNotEmpty) return deviceName;
        if (model.isNotEmpty) return model;
        return 'Android Device';
      }

      if (Platform.isLinux) {
        final hostname = Platform.localHostname;
        if (hostname.isNotEmpty) return hostname;

        final osReleaseFile = File('/etc/os-release');
        if (await osReleaseFile.exists()) {
          final lines = await osReleaseFile.readAsLines();
          final prettyName = _parseOsReleaseValue(lines, 'PRETTY_NAME');
          if (prettyName.isNotEmpty) return prettyName;
          final name = _parseOsReleaseValue(lines, 'NAME');
          if (name.isNotEmpty) return name;
        }

        return 'Linux Device';
      }
    } catch (_) {
      // Ignore failures and fallback to default.
    }

    return 'Flutter Device';
  }

  String _parseOsReleaseValue(List<String> lines, String key) {
    for (final line in lines) {
      if (line.startsWith('$key=')) {
        return line.split('=')[1].replaceAll('"', '').trim();
      }
    }
    return '';
  }

  Future<String?> _showPinDialog(BuildContext context, String deviceName) {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Pair with $deviceName'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter the PIN shown on the TV.'),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'TV PIN',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Confirm PIN'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discovered TVs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isScanning ? null : _startScan,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isScanning) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Scanning LAN for Vizio TVs...'),
          ],
        ),
      );
    }

    if (_discoveredDevices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.tv_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No Vizio TVs found.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            const Text(
              'Make sure your TV is turned on and connected\nto the same WiFi network',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
              onPressed: _startScan,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _discoveredDevices.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final device = _discoveredDevices[index];
        return ListTile(
          leading: const Icon(Icons.tv),
          title: Text(device.name),
          subtitle: Text('${device.ip}:${device.port}'),
          contentPadding: const EdgeInsets.all(20),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _onDeviceTap(device),
        );
      },
    );
  }
}

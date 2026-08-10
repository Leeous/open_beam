import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:vizio_remote/data/models/discovered_tv.dart';
import 'package:vizio_remote/data/repositories/tv_cache_repository.dart';
import 'package:vizio_remote/main.dart'; // Location of your GetIt locator instance
import 'package:vizio_remote/remote_screen.dart';
import 'package:vizio_remote/services/vizio_remote_service.dart';

class TVListScreen extends StatefulWidget {
  const TVListScreen({super.key});

  @override
  State<TVListScreen> createState() => _TVListScreenState();
}

class _TVListScreenState extends State<TVListScreen> {
  final TvCacheRepository _tvRepo = getIt<TvCacheRepository>();

  List<({DiscoveredTv tv, bool isOnline})> _tvList = [];
  bool _isLoading = true;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _loadCachedTvs();
  }

  /// Load cached TVs immediately on launch and ping them in parallel.
  Future<void> _loadCachedTvs() async {
    setState(() => _isLoading = true);
    final verified = await _tvRepo.getVerifiedCachedTvs();
    if (!mounted) return;

    setState(() {
      _tvList = verified;
      _isLoading = false;
    });
  }

  /// Run full subnet scan across ports 7345 and 9000.
  Future<void> _runFullScan() async {
    setState(() => _isScanning = true);
    await _tvRepo.scanAndSyncNetwork();
    await _loadCachedTvs();
    if (!mounted) return;

    setState(() => _isScanning = false);
  }

  /// Handles selection: bypasses pairing if already paired, otherwise runs pairing sequence.
  Future<void> _onTvSelected(DiscoveredTv tv) async {
    // If the TV is already paired, directly launch RemoteScreen
    if (tv.isPaired && tv.authToken != null && tv.authToken!.isNotEmpty) {
      _navigateToRemote(
        tvName: tv.name,
        tvIp: tv.ipAddress,
        port: tv.port,
        authToken: tv.authToken!,
      );
      return;
    }

    // Otherwise, initiate PIN pairing process
    await _executePairingFlow(tv);
  }

  Future<void> _executePairingFlow(DiscoveredTv tv) async {
    final localDeviceName = await _resolveLocalDeviceName();
    final deviceId = _buildDeviceId(localDeviceName);
    final remoteService = VizioRemoteService(tvIp: tv.ipAddress, port: tv.port);

    if (!mounted) return;

    // Show loading spinner while requesting pairing token
    _showLoadingDialog();

    final challenge = await remoteService.startPairing(
      deviceId: deviceId,
      deviceName: localDeviceName,
    );

    if (!mounted) return;
    Navigator.of(context).pop(); // Dismiss loading dialog

    if (challenge == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to initiate pairing with TV.')),
      );
      return;
    }

    // Prompt user for the PIN displayed on the TV screen
    final pin = await _showPinDialog(tv.name);
    if (pin == null || pin.isEmpty) return;

    if (!mounted) return;
    _showLoadingDialog();

    final authToken = await remoteService.confirmPairing(
      deviceId: deviceId,
      pin: pin,
      pairingReqToken: challenge.pairingReqToken,
      challengeType: challenge.challengeType,
    );

    if (!mounted) return;
    Navigator.of(context).pop(); // Dismiss loading dialog

    if (authToken == null || authToken.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pairing failed. Please check the PIN and try again.'),
        ),
      );
      return;
    }

    // Save auth token & updated TV state to repository
    final updatedTv = tv.copyWith(
      authToken: authToken,
      lastSeen: DateTime.now(),
    );
    await _tvRepo.saveTv(updatedTv);

    // Refresh UI list state
    await _loadCachedTvs();

    // Navigate to remote control UI
    _navigateToRemote(
      tvName: updatedTv.name,
      tvIp: updatedTv.ipAddress,
      port: updatedTv.port,
      authToken: authToken,
    );
  }

  void _navigateToRemote({
    required String tvName,
    required String tvIp,
    required int port,
    required String authToken,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => RemoteScreen(
          tvName: tvName,
          tvIp: tvIp,
          port: port,
          authToken: authToken,
        ),
      ),
    );
  }

  void _showLoadingDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  Future<String?> _showPinDialog(String tvName) {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pair with $tvName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the PIN displayed on your TV screen.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'TV PIN',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Confirm PIN'),
          ),
        ],
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
      // Fall back on platform discovery failure
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vizio Remote'),
        actions: [
          IconButton(
            icon: _isScanning
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.radar),
            tooltip: 'Scan Network',
            onPressed: _isScanning ? null : _runFullScan,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Status',
            onPressed: _loadCachedTvs,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_tvList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.tv_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No Vizio TVs Found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Ensure your TV is turned on and connected\nto the same Wi-Fi network.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.radar),
              label: const Text('Scan Local Network'),
              onPressed: _runFullScan,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _tvList.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final entry = _tvList[index];
        final tv = entry.tv;
        final isOnline = entry.isOnline;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 8,
          ),
          leading: Icon(
            Icons.tv,
            size: 32,
            color: isOnline ? Colors.green : Colors.grey,
          ),
          title: Text(
            tv.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            '${tv.ipAddress}:${tv.port} • ${tv.isPaired ? "Paired" : "Not Paired"}',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isOnline
                      ? Colors.green.withValues(alpha: 0.15)
                      : Colors.grey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    color: isOnline ? Colors.green : Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
          onTap: isOnline ? () => _onTvSelected(tv) : null,
        );
      },
    );
  }
}

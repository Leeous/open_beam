import 'dart:async';
import 'package:flutter/material.dart';
import 'package:open_beam/services/tv_discovery_prober.dart';
import 'package:open_beam/services/tv_storage_service.dart';
import 'package:open_beam/models/paired_tv_device.dart';
import 'package:open_beam/services/lan_scanner_service.dart';
import 'package:open_beam/services/tv_brands/vizio/vizio_pairing_manager.dart';
import 'package:open_beam/services/http_service.dart';
import 'package:open_beam/services/logging_helper.dart';

class TvListScreen extends StatefulWidget {
  final TvStorageService storageService;
  final LanScannerService scannerService;
  final HTTPService httpService;

  const TvListScreen({
    super.key,
    required this.storageService,
    required this.scannerService,
    required this.httpService,
  });

  @override
  State<TvListScreen> createState() => _TvListScreenState();
}

class _TvListScreenState extends State<TvListScreen> {
  List<PairedTvDevice> _cachedDevices = [];
  final List<DiscoveredTvCandidate> _discoveredDevices = [];
  StreamSubscription<DiscoveredTvCandidate>? _scanSubscription;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _loadCachedAndScan();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }

  /// 1. Load devices cached for this specific Wi-Fi, then kick off auto-probe
  Future<void> _loadCachedAndScan() async {
    final cached = await widget.storageService.getPairedDevices();
    if (mounted) {
      setState(() => _cachedDevices = cached);
      _startDiscovery();
    }
  }

  /// 2. Stream discoveries from SSDP + Subnet Sweep
  void _startDiscovery() {
    _scanSubscription?.cancel();
    setState(() {
      _discoveredDevices.clear();
      _isScanning = true;
    });

    _scanSubscription = widget.scannerService.scan().listen(
      (candidate) {
        if (!mounted) return;
        // Avoid listing candidates that are already saved in cached list
        final alreadySaved = _cachedDevices.any(
          (d) => d.ipAddress == candidate.ipAddress,
        );
        final alreadyDiscovered = _discoveredDevices.any(
          (d) => d.ipAddress == candidate.ipAddress,
        );

        if (!alreadySaved && !alreadyDiscovered) {
          setState(() => _discoveredDevices.add(candidate));
        }
      },
      onDone: () => setState(() => _isScanning = false),
      onError: (Object e) {
        dPrint('Scan stream error: $e');
        setState(() => _isScanning = false);
      },
    );
  }

  /// 3. Select a device: Route Roku straight to storage, Vizio to PIN dialog
  Future<void> _onDeviceSelected(DiscoveredTvCandidate candidate) async {
    if (!candidate.requiresPairing) {
      // Direct connection (Roku)
      final device = PairedTvDevice(
        id: '${candidate.ipAddress}:${candidate.port}',
        name: candidate.defaultName,
        ipAddress: candidate.ipAddress,
        port: candidate.port,
        brand: candidate.brand,
      );

      await _persistAndOpenRemote(device);
    } else {
      // Challenge-response connection (Vizio)
      _showVizioPairingDialog(candidate);
    }
  }

  Future<void> _persistAndOpenRemote(PairedTvDevice device) async {
    await widget.storageService.saveDevice(device);
    await widget.storageService.setActiveDeviceId(device.id);

    if (mounted) {
      Navigator.pushNamed(context, '/remote', arguments: device);
    }
  }

  /// 4. Vizio PIN input handshake modal
  Future<void> _showVizioPairingDialog(DiscoveredTvCandidate candidate) async {
    final pairingManager = VizioPairingManager(
      ipAddress: candidate.ipAddress,
      port: candidate.port,
      httpService: widget.httpService,
    );

    // Step 1: Initiate pairing to display PIN on TV
    final initResult = await pairingManager.initiatePairing();
    if (!initResult.isSuccess || initResult.pairingReqToken == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to initiate pairing: ${initResult.errorMessage}',
          ),
        ),
      );
      return;
    }

    final pinController = TextEditingController();

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('Pair with ${candidate.defaultName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the 4-digit PIN currently displayed on your TV screen:',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              autofocus: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '1234',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final pin = pinController.text.trim();
              if (pin.length != 4) return;

              final pairResult = await pairingManager.completePairing(
                pin: pin,
                pairingReqToken: initResult.pairingReqToken!,
                challengeType: initResult.challengeType ?? 1,
              );

              if (pairResult.isSuccess && pairResult.authToken != null) {
                final device = PairedTvDevice(
                  id: '${candidate.ipAddress}:${candidate.port}',
                  name: candidate.defaultName,
                  ipAddress: candidate.ipAddress,
                  port: candidate.port,
                  brand: candidate.brand,
                  authToken: pairResult.authToken,
                );

                if (ctx.mounted) Navigator.pop(ctx);
                await _persistAndOpenRemote(device);
              } else {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(pairResult.errorMessage ?? 'Invalid PIN'),
                    ),
                  );
                }
              }
            },
            child: const Text('Pair'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available TVs'),
        actions: [
          IconButton(
            icon: _isScanning
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isScanning ? null : _startDiscovery,
          ),
        ],
      ),
      body: ListView(
        children: [
          if (_cachedDevices.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'PAIRED ON THIS NETWORK',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            ..._cachedDevices.map(
              (device) => ListTile(
                leading: Icon(
                  device.brand == TvBrand.roku ? Icons.tv : Icons.connected_tv,
                ),
                title: Text(device.name),
                subtitle: Text(
                  '${device.ipAddress} (${device.brand.name.toUpperCase()})',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _persistAndOpenRemote(device),
              ),
            ),
            const Divider(),
          ],
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'DISCOVERED DEVICES',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          if (_discoveredDevices.isEmpty && _isScanning)
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(child: Text('Scanning Wi-Fi network for TVs...')),
            )
          else if (_discoveredDevices.isEmpty && !_isScanning)
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(
                child: Text('No new TVs found. Tap refresh to scan again.'),
              ),
            )
          else
            ..._discoveredDevices.map(
              (candidate) => ListTile(
                leading: const Icon(Icons.add_to_queue),
                title: Text(candidate.defaultName),
                subtitle: Text(
                  '${candidate.ipAddress} • ${candidate.requiresPairing ? "Requires PIN" : "Direct Connect"}',
                ),
                trailing: ElevatedButton(
                  onPressed: () => _onDeviceSelected(candidate),
                  child: Text(candidate.requiresPairing ? 'Pair' : 'Connect'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

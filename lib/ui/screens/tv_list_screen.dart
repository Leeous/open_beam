import 'package:flutter/material.dart';
import 'package:open_beam/data/models/discovered_tv.dart';
import 'package:open_beam/data/models/tv_brand.dart';
import 'package:open_beam/data/repositories/tv_cache_repository.dart';
import 'package:open_beam/main.dart';
import 'package:open_beam/services/device_info_helper.dart';
import 'package:open_beam/services/vizio_pairing_service.dart';
import 'package:open_beam/ui/screens/remote_screen.dart';

class TVListScreen extends StatefulWidget {
  const TVListScreen({super.key});

  @override
  State<TVListScreen> createState() => _TVListScreenState();
}

class _TVListScreenState extends State<TVListScreen> {
  final TvCacheRepository _tvRepo = getIt<TvCacheRepository>();
  final VizioPairingService _vizioPairingService = VizioPairingService();

  List<({DiscoveredTv tv, bool isOnline})> _tvList = [];
  bool _isLoading = true;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _loadCachedTvs();
    _runFullScan();
  }

  Future<void> _loadCachedTvs() async {
    setState(() => _isLoading = true);
    final verified = await _tvRepo.getVerifiedCachedTvs();
    if (!mounted) return;

    setState(() {
      _tvList = verified;
      _isLoading = false;
    });
  }

  Future<void> _runFullScan() async {
    setState(() => _isScanning = true);
    await _tvRepo.scanAndSyncNetwork();
    await _loadCachedTvs();
    if (!mounted) return;

    setState(() => _isScanning = false);
  }

  Future<void> _onTvSelected(DiscoveredTv tv) async {
    if (tv.brand == TvBrand.roku) {
      _navigateToRemote(
        tvName: tv.name,
        tvIp: tv.ipAddress,
        port: tv.port,
        authToken: tv.authToken ?? '',
        brand: tv.brand,
      );
      return;
    }

    if (tv.isPaired && tv.authToken != null && tv.authToken!.isNotEmpty) {
      _navigateToRemote(
        tvName: tv.name,
        tvIp: tv.ipAddress,
        port: tv.port,
        authToken: tv.authToken!,
        brand: tv.brand,
      );
      return;
    }

    await _executePairingFlow(tv);
  }

  Future<void> _executePairingFlow(DiscoveredTv tv) async {
    if (tv.brand != TvBrand.vizio) {
      return;
    }

    final localDeviceName = await DeviceInfoHelper.getHostDeviceName();
    final deviceId = _buildDeviceId(localDeviceName);

    if (!mounted) return;

    _showLoadingDialog();

    final challenge = await _vizioPairingService.startPairing(
      tvIp: tv.ipAddress,
      port: tv.port,
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

    final pin = await _showPinDialog(tv.name);
    if (pin == null || pin.isEmpty) return;

    if (!mounted) return;
    _showLoadingDialog();

    final authToken = await _vizioPairingService.confirmPairing(
      tvIp: tv.ipAddress,
      port: tv.port,
      deviceId: deviceId,
      pin: pin,
      pairingReqToken: challenge.pairingReqToken,
      challengeType: challenge.challengeType,
    );

    if (!mounted) return;
    Navigator.of(context).pop();

    if (authToken == null || authToken.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pairing failed. Please check the PIN and try again.'),
        ),
      );
      return;
    }

    final updatedTv = tv.copyWith(
      authToken: authToken,
      isPaired: true,
      lastSeen: DateTime.now(),
    );
    await _tvRepo.saveTv(updatedTv);
    await _loadCachedTvs();

    _navigateToRemote(
      tvName: updatedTv.name,
      tvIp: updatedTv.ipAddress,
      port: updatedTv.port,
      authToken: authToken,
      brand: updatedTv.brand,
    );
  }

  void _navigateToRemote({
    required String tvName,
    required String tvIp,
    required int port,
    required String authToken,
    required TvBrand brand,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => RemoteScreen(
          tvName: tvName,
          tvIp: tvIp,
          port: port,
          authToken: authToken,
          brand: brand,
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

    return 'OPEN_BEAM_${cleaned.isEmpty ? 'APP' : cleaned}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Open Beam'),
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
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add TV by IP',
            onPressed: _addTvByIp,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Future<void> _addTvByIp() async {
    final ipController = TextEditingController();
    TvBrand brand = TvBrand.roku;

    final result = await showDialog<({String ip, TvBrand brand})?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Add TV by IP'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: ipController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'IP Address',
                    hintText: '192.168.1.50',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<TvBrand>(
                  initialValue: brand,
                  decoration: const InputDecoration(labelText: 'Brand'),
                  items: TvBrand.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.name.toUpperCase()),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => brand = value);
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final ip = ipController.text.trim();
                  if (ip.isEmpty) return;
                  Navigator.of(context).pop((ip: ip, brand: brand));
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    if (result == null || !mounted) return;

    final tv = DiscoveredTv(
      name: result.brand == TvBrand.roku ? 'Roku TV' : 'Vizio TV',
      ipAddress: result.ip,
      port: result.brand == TvBrand.roku ? 8060 : 7345,
      brand: result.brand,
      isPaired: false,
      lastSeen: DateTime.now(),
    );

    await _tvRepo.saveTv(tv);
    await _loadCachedTvs();
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
              'No TVs Found',
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
            '${tv.ipAddress}:${tv.port} • ${tv.brand.name.toUpperCase()} • ${tv.isPaired ? 'Paired' : 'Not Paired'}',
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

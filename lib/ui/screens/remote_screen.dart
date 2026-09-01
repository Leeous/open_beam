import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:open_beam/models/paired_tv_device.dart';
import 'package:open_beam/models/tv_key.dart';
import 'package:open_beam/services/tv_service.dart';
import 'package:open_beam/services/http_service.dart';
import 'package:open_beam/services/logging_helper.dart';
import 'package:open_beam/services/tv_brands/roku/roku_tv_service.dart';
import 'package:open_beam/services/tv_brands/vizio/vizio_tv_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RemoteScreen extends StatefulWidget {
  final PairedTvDevice device;

  const RemoteScreen({super.key, required this.device});

  @override
  State<RemoteScreen> createState() => _RemoteScreenState();
}

class _RemoteScreenState extends State<RemoteScreen> {
  late final TVService _tvService;
  bool _isLoading = true;
  bool _hapticFeedback = true;
  bool _reverseRemoteOrder = false;

  @override
  void initState() {
    super.initState();
    _initTvService();
    _loadPreferences();
  }

  void _initTvService() {
    final httpService = GetIt.instance<HTTPService>();

    _tvService = switch (widget.device.brand) {
      TvBrand.vizio => VizioTvService(
        ipAddress: widget.device.ipAddress,
        name: widget.device.name,
        port: widget.device.port,
        authToken: widget.device.authToken ?? '',
        httpService: httpService,
      ),
      TvBrand.roku => RokuTvService(
        ipAddress: widget.device.ipAddress,
        name: widget.device.name,
        port: widget.device.port,
        httpService: httpService,
      ),
      _ => throw UnsupportedError(
        'Brand ${widget.device.brand} not supported yet',
      ),
    };
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _hapticFeedback = prefs.getBool('haptics_enabled') ?? true;
      _reverseRemoteOrder = prefs.getBool('reverse_remote_order') ?? false;
      _isLoading = false;
    });
  }

  Future<void> _sendKey(TvKey key) async {
    if (_hapticFeedback) {
      HapticFeedback.lightImpact();
    }

    final response = await _tvService.sendKey(key);
    if (!response.isSuccess) {
      dPrint('Keypress error ($key): ${response.errorMessage}');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final children = [_buildDPad(context), _buildControlRow(context)];

    final orderedWidgets = _reverseRemoteOrder
        ? children.reversed.toList()
        : children;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.device.name),
            Text(
              '${widget.device.ipAddress} (${widget.device.brand.name.toUpperCase()})',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.power_settings_new, color: Colors.redAccent),
            tooltip: 'Power Off',
            onPressed: () => _sendKey(TvKey.powerOff),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: orderedWidgets,
        ),
      ),
    );
  }

  Widget _buildDPad(BuildContext context) {
    BorderRadius parseRadii(List<double>? radii) {
      if (radii == null || radii.length < 4) return BorderRadius.zero;
      return BorderRadius.only(
        topLeft: Radius.circular(radii[0]),
        topRight: Radius.circular(radii[1]),
        bottomRight: Radius.circular(radii[2]),
        bottomLeft: Radius.circular(radii[3]),
      );
    }

    ButtonStyle dpadButtonStyle({
      double iconSize = 80,
      Size minimumSize = const Size(128, 128),
      List<double>? radii,
    }) {
      return ElevatedButton.styleFrom(
        minimumSize: minimumSize,
        iconSize: iconSize,
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: parseRadii(radii)),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 500),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            style: dpadButtonStyle(radii: [16, 16, 0, 0]),
            onPressed: () => _sendKey(TvKey.up),
            child: const Icon(Icons.keyboard_arrow_up),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                style: dpadButtonStyle(radii: [16, 0, 0, 16]),
                onPressed: () => _sendKey(TvKey.left),
                child: const Icon(Icons.keyboard_arrow_left),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: dpadButtonStyle(iconSize: 32),
                onPressed: () => _sendKey(TvKey.select),
                child: const Icon(Icons.circle),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: dpadButtonStyle(radii: [0, 16, 16, 0]),
                onPressed: () => _sendKey(TvKey.right),
                child: const Icon(Icons.keyboard_arrow_right),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            style: dpadButtonStyle(radii: [0, 0, 16, 16]),
            onPressed: () => _sendKey(TvKey.down),
            child: const Icon(Icons.keyboard_arrow_down),
          ),
        ],
      ),
    );
  }

  Widget _buildControlRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(padding: EdgeInsets.all(10), child: Text('Back')),
            IconButton.outlined(
              onPressed: () => _sendKey(TvKey.back),
              icon: const Icon(Icons.arrow_back),
            ),
          ],
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton.filledTonal(
              icon: const Icon(Icons.volume_up),
              onPressed: () => _sendKey(TvKey.volUp),
            ),
            const Padding(padding: EdgeInsets.all(10), child: Text('Volume')),
            IconButton.filledTonal(
              icon: const Icon(Icons.volume_down),
              onPressed: () => _sendKey(TvKey.volDown),
            ),
          ],
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(padding: EdgeInsets.all(10), child: Text('Mute')),
            IconButton.outlined(
              icon: const Icon(Icons.volume_off),
              onPressed: () => _sendKey(TvKey.mute),
            ),
          ],
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(padding: EdgeInsets.all(10), child: Text('Home')),
            IconButton.outlined(
              icon: const Icon(Icons.home),
              onPressed: () => _sendKey(TvKey.home),
            ),
          ],
        ),
      ],
    );
  }
}

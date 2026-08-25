import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_beam/data/models/discovered_tv.dart';
import 'package:open_beam/data/models/tv_brand.dart';
import 'package:open_beam/data/tv_provider.dart';
import 'package:open_beam/models/vizio_payload.dart';
import 'package:open_beam/services/tv_provider_factory.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RemoteScreen extends StatefulWidget {
  final String tvName;
  final String tvIp;
  final int port;
  final String authToken;
  final TvBrand brand;

  const RemoteScreen({
    super.key,
    required this.tvName,
    required this.tvIp,
    required this.authToken,
    this.port = 7345,
    this.brand = TvBrand.vizio,
  });

  @override
  State<RemoteScreen> createState() => _RemoteScreenState();
}

class _RemoteScreenState extends State<RemoteScreen> {
  late final TvProvider _provider;
  bool _isLoading = true;
  bool _hapticFeedback = true;
  bool _reverseRemoteOrder = false;

  @override
  void initState() {
    super.initState();
    final discovered = DiscoveredTv(
      name: widget.tvName,
      ipAddress: widget.tvIp,
      port: widget.port,
      brand: widget.brand,
      authToken: widget.authToken.isNotEmpty ? widget.authToken : null,
      isPaired: widget.authToken.isNotEmpty,
    );
    _provider = TvProviderFactory.create(discovered);
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
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

    await _provider.pressKey(key);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final children = [_buildDPad(context), _buildControlRow(context)];

    final orderedWidgets = _reverseRemoteOrder ? children.reversed.toList() : children;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.tvName),
            Text(
              widget.tvIp,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.power_settings_new, color: Colors.redAccent),
            tooltip: 'Power Toggle',
            onPressed: () => _sendKey(TvKey.home),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: orderedWidgets),
      ),
    );
  }

  // DPad controls
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

    return SafeArea(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              style: dpadButtonStyle(radii: [16, 16, 0, 0]),
              onPressed: () => _sendKey(TvKey.up),
              child: const Icon(Icons.keyboard_arrow_up),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  style: dpadButtonStyle(radii: [16, 0, 0, 16]),
                  onPressed: () => _sendKey(TvKey.left),
                  child: const Icon(Icons.keyboard_arrow_left),
                ),
                ElevatedButton(
                  style: dpadButtonStyle(iconSize: 32),
                  onPressed: () => _sendKey(TvKey.select),
                  child: const Icon(Icons.circle),
                ),
                ElevatedButton(
                  style: dpadButtonStyle(radii: [0, 16, 16, 0]),
                  onPressed: () => _sendKey(TvKey.right),
                  child: const Icon(Icons.keyboard_arrow_right),
                ),
              ],
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: dpadButtonStyle(radii: [0, 0, 16, 16]),
              onPressed: () => _sendKey(TvKey.down),
              child: const Icon(Icons.keyboard_arrow_down),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Column(
          children: [
            Padding(padding: EdgeInsetsGeometry.all(10), child: Text('Back')),
            IconButton.outlined(
              onPressed: () => _sendKey(TvKey.back),
              icon: const Icon(Icons.arrow_back),
            ),
          ],
        ),
        Column(
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
          children: [
            Padding(padding: EdgeInsetsGeometry.all(10), child: Text('Mute')),
            IconButton.outlined(
              icon: const Icon(Icons.volume_off),
              onPressed: () => _sendKey(TvKey.mute),
            ),
          ],
        ),
        Column(
          children: [
            Padding(padding: EdgeInsetsGeometry.all(10), child: Text('Home')),
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

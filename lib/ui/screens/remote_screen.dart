import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vizio_remote/services/vizio_remote_service.dart';

class RemoteScreen extends StatefulWidget {
  final String tvName;
  final String tvIp;
  final int port;
  final String authToken;

  const RemoteScreen({
    super.key,
    required this.tvName,
    required this.tvIp,
    required this.authToken,
    this.port = 7345,
  });

  @override
  State<RemoteScreen> createState() => _RemoteScreenState();
}

class _RemoteScreenState extends State<RemoteScreen> {
  late final VizioRemoteService _service;
  bool _isLoading = true;
  bool _hapticFeedback = true;

  @override
  void initState() {
    super.initState();
    _service = VizioRemoteService(
      tvIp: widget.tvIp,
      port: widget.port,
      authToken: widget.authToken,
    );
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hapticFeedback = prefs.getBool('haptics_enabled') ?? true;
      _isLoading = false;
    });
  }

  Future<void> _sendKey(int codeSet, int code, String actionName) async {
    // Only play haptics if enabled in settings_screen
    if (_hapticFeedback) {
      HapticFeedback.lightImpact();
    }

    await _service.sendKeyPress(codeSet, code);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.tvName),
            Text(
              widget.tvIp,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.power_settings_new, color: Colors.redAccent),
            tooltip: 'Power Toggle',
            onPressed: () => _sendKey(11, 0, 'Power Toggle'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [_buildDPad(context), _buildControlRow(context)],
        ),
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
      double iconSize = 128,
      Size minimumSize = const Size(128, 128),
      List<double>? radii,
    }) {
      return ElevatedButton.styleFrom(
        minimumSize: minimumSize,
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
              onPressed: () => _sendKey(3, 8, 'Up'),
              child: const Icon(Icons.keyboard_arrow_up),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  style: dpadButtonStyle(radii: [16, 0, 0, 16]),
                  onPressed: () => _sendKey(3, 1, 'Left'),
                  child: const Icon(Icons.keyboard_arrow_left),
                ),
                ElevatedButton(
                  style: dpadButtonStyle(),
                  onPressed: () => _sendKey(3, 2, 'OK'),
                  child: const Icon(Icons.circle),
                ),
                ElevatedButton(
                  style: dpadButtonStyle(radii: [0, 16, 16, 0]),
                  onPressed: () => _sendKey(3, 7, 'Right'),
                  child: const Icon(Icons.keyboard_arrow_right),
                ),
              ],
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: dpadButtonStyle(radii: [0, 0, 16, 16]),
              onPressed: () => _sendKey(3, 0, 'Down'),
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
            IconButton.filledTonal(
              icon: const Icon(Icons.volume_up),
              onPressed: () => _sendKey(5, 1, 'Volume Up'),
            ),
            const Padding(padding: EdgeInsets.all(10), child: Text('Volume')),
            IconButton.filledTonal(
              icon: const Icon(Icons.volume_down),
              onPressed: () => _sendKey(5, 0, 'Volume Down'),
            ),
          ],
        ),
        Column(
          children: [
            Padding(padding: EdgeInsetsGeometry.all(10), child: Text('Mute')),
            IconButton.outlined(
              icon: const Icon(Icons.volume_off),
              onPressed: () => _sendKey(5, 2, 'Mute'),
            ),
          ],
        ),
        Column(
          children: [
            Padding(padding: EdgeInsetsGeometry.all(10), child: Text('Home')),
            IconButton.outlined(
              icon: const Icon(Icons.home),
              onPressed: () => _sendKey(4, 3, 'Home'),
            ),
          ],
        ),
      ],
    );
  }
}

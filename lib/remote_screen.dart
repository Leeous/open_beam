import 'package:flutter/material.dart';
import 'services/device_manager.dart';

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
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _service = VizioRemoteService(
      tvIp: widget.tvIp,
      port: widget.port,
      authToken: widget.authToken,
    );
  }

  Future<void> _sendKey(
    BuildContext context,
    int codeSet,
    int code,
    String actionName,
  ) async {
    setState(() => _isSending = true);

    final success = await _service.sendKeyPress(codeSet, code);

    if (!mounted) return;

    setState(() => _isSending = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Sent: $actionName'
              : 'Failed to send $actionName. Reconnect or re-pair if needed.',
        ),
        duration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            onPressed: _isSending
                ? null
                : () => _sendKey(context, 11, 0, 'Power Toggle'),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          onPressed: _isSending ? null : () => _sendKey(context, 3, 8, 'Up'),
          child: const Icon(Icons.keyboard_arrow_up),
        ),
        const SizedBox(width: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _isSending
                  ? null
                  : () => _sendKey(context, 3, 1, 'Left'),
              child: const Icon(Icons.keyboard_arrow_left),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(20),
              ),
              onPressed: _isSending
                  ? null
                  : () => _sendKey(context, 3, 2, 'OK'),
              child: const Text('Ok'),
            ),
            ElevatedButton(
              onPressed: _isSending
                  ? null
                  : () => _sendKey(context, 3, 7, 'Right'),
              child: const Icon(Icons.keyboard_arrow_right),
            ),
          ],
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _isSending ? null : () => _sendKey(context, 3, 0, 'Down'),
          child: const Icon(Icons.keyboard_arrow_down),
        ),
      ],
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
              onPressed: _isSending
                  ? null
                  : () => _sendKey(context, 5, 0, 'Vol Up'),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 8, right: 8),
              child: Text('VOL'),
            ),
            IconButton.filledTonal(
              icon: const Icon(Icons.volume_down),
              onPressed: _isSending
                  ? null
                  : () => _sendKey(context, 5, 1, 'Vol Down'),
            ),
          ],
        ),
        IconButton.outlined(
          icon: const Icon(Icons.volume_off),
          onPressed: _isSending ? null : () => _sendKey(context, 5, 2, 'Mute'),
        ),
        IconButton.outlined(
          icon: const Icon(Icons.home),
          onPressed: _isSending
              ? null
              : () => _sendKey(context, 4, 3, 'SmartCast Home'),
        ),
      ],
    );
  }
}

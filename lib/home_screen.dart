import 'package:flutter/material.dart';
import 'package:vizio_remote/settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _sendKey(
    BuildContext context,
    int codeSet,
    int code,
    String actionName,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sent: $actionName'),
        duration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Vizio Remote"),
        actions: [
          IconButton(
            icon: const Icon(Icons.power_settings_new, color: Colors.redAccent),
            tooltip: 'Power Toggle',
            onPressed: () => _sendKey(context, 11, 0, 'Power Toggle'),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsScreen()),
              );
            },
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
        // Left arrow
        ElevatedButton(
          onPressed: () => _sendKey(context, 3, 8, 'Up'),
          child: Icon(Icons.keyboard_arrow_up),
        ),
        const SizedBox(width: 8),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => _sendKey(context, 3, 1, 'Left'),
              child: const Icon(Icons.keyboard_arrow_left),
            ),
            const SizedBox(width: 8),

            // Ok / Select
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(20),
              ),
              onPressed: () => _sendKey(context, 3, 2, 'OK'),
              child: Text('Ok'),
            ),

            // Right arrow
            ElevatedButton(
              onPressed: () => _sendKey(context, 3, 7, 'Right'),
              child: const Icon(Icons.keyboard_arrow_right),
            ),
          ],
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () => _sendKey(context, 3, 0, 'Down'),
          child: const Icon(Icons.keyboard_arrow_down),
        ),
      ],
    );
  }

  // Volume & Channel Controls
  Widget _buildControlRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Volume Group
        Column(
          children: [
            // Volume up
            IconButton.filledTonal(
              icon: const Icon(Icons.volume_up),
              onPressed: () => _sendKey(context, 5, 0, 'Vol Up'),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 8, right: 8),
              child: Text('VOL'),
            ),
            // Volume down
            IconButton.filledTonal(
              icon: const Icon(Icons.volume_down),
              onPressed: () => _sendKey(context, 5, 1, 'Vol Down'),
            ),
          ],
        ),
        // Mute
        IconButton.outlined(
          icon: const Icon(Icons.volume_off),
          onPressed: () => _sendKey(context, 5, 2, 'Mute'),
        ),
        // Home Button
        IconButton.outlined(
          icon: const Icon(Icons.home),
          onPressed: () => _sendKey(context, 4, 3, 'SmartCast Home'),
        ),
      ],
    );
  }
}

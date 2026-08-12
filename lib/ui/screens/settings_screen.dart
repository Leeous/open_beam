import 'package:flutter/material.dart';
import 'package:vizio_remote/ui/screens/about_screen.dart';
import 'package:vizio_remote/ui/widgets/app_bar.dart';
import 'package:vizio_remote/ui/widgets/menu_tile.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _darkMode = true;
  bool _hapticFeedback = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DefaultAppBar(title: "Settings", showAppIcon: false),
      body: SafeArea(
        child: ListView(
          children: [
            ListTile(
              leading: Icon(Icons.av_timer),
              title: Text("Pairing Timeout"),
            ),
            SwitchListTile(
              title: const Text("Dark mode"),
              secondary: Icon(Icons.dark_mode),
              value: _darkMode,
              onChanged: (bool value) => setState(() => _darkMode = value),
            ),
            SwitchListTile(
              title: Text("Haptic Feedback"),
              secondary: Icon(Icons.vibration),
              value: _hapticFeedback,
              onChanged: (bool value) =>
                  setState(() => _hapticFeedback = value),
            ),
            ListTile(
              leading: Icon(Icons.info),
              title: Text("About"),
              onTap: () => {
                Navigator.of(context).push(
                  MaterialPageRoute<dynamic>(builder: (_) => AboutScreen()),
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

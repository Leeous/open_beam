import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vizio_remote/ui/screens/about_screen.dart';
import 'package:vizio_remote/ui/widgets/app_bar.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  SharedPreferences? _prefs;
  bool _isLoading = true;
  bool _darkMode = true;
  bool _hapticFeedback = true;
  bool _reverseRemoteOrder = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _updateHaptics(bool value) async {
    setState(() => _hapticFeedback = value);

    await _prefs?.setBool('haptics_enabled', value);
  }

  Future<void> _updateReverseRemoteOrder(bool value) async {
    setState(() => _reverseRemoteOrder = value);

    await _prefs?.setBool('reverse_remote_order', value);
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _prefs = prefs;
      _hapticFeedback = prefs.getBool('haptics_enabled') ?? true;
      _reverseRemoteOrder = prefs.getBool('reverse_remote_order') ?? false;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
              title: const Text("Reverse remote order"),
              secondary: Icon(Icons.sort),
              value: _reverseRemoteOrder,
              onChanged: _updateReverseRemoteOrder,
            ),
            SwitchListTile(
              title: Text("Haptic Feedback"),
              secondary: Icon(Icons.vibration),
              value: _hapticFeedback,
              onChanged: _updateHaptics,
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

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:open_beam/ui/screens/about_screen.dart';
import 'package:open_beam/ui/theme_controller.dart';
import 'package:open_beam/ui/widgets/app_bar.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  SharedPreferences? _prefs;
  bool _isLoading = true;
  bool _lightMode = false;
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

  Future<void> _clearAllData() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all data?'),
        content: const Text(
          'This will delete saved TV data and paired device tokens from storage.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear Data'),
          ),
        ],
      ),
    );

    if (shouldClear != true) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await const FlutterSecureStorage().deleteAll();

    if (!mounted) return;

    await _loadPreferences();

    final currentContext = context;
    if (!mounted || !currentContext.mounted) return;

    ScaffoldMessenger.of(
      currentContext,
    ).showSnackBar(const SnackBar(content: Text('Saved data cleared.')));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: DefaultAppBar(title: 'Settings', showAppIcon: false),
      body: SafeArea(
        child: ListView(
          children: [
            SwitchListTile(
              title: const Text('Light mode'),
              secondary: Icon(Icons.light_mode),
              subtitle: const Text('Enable/Disable light mode.'),
              value: _lightMode,
              onChanged: (bool value) => {
                setState(() {
                  _lightMode = value;
                }),
                ThemeController.updateTheme(
                  value ? ThemeMode.light : ThemeMode.dark,
                ),
              },
            ),
            SwitchListTile(
              title: const Text('Reverse remote order'),
              secondary: Icon(Icons.sort),
              subtitle: Text(
                'Reverses remote render order, control row at the top, d-pad at the bottom.',
              ),
              value: _reverseRemoteOrder,
              onChanged: _updateReverseRemoteOrder,
            ),
            SwitchListTile(
              title: Text('Haptic Feedback'),
              secondary: Icon(Icons.vibration),
              subtitle: Text(
                'Enable/Disable haptic feedback on remote presses.',
              ),
              value: _hapticFeedback,
              onChanged: _updateHaptics,
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever),
              title: const Text('Clear data'),
              subtitle: const Text(
                'Remove cached TVs, preferences, and secure tokens.',
              ),
              onTap: _clearAllData,
            ),
            ListTile(
              leading: Icon(Icons.info),
              title: Text('About'),
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

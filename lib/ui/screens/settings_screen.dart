import 'package:flutter/material.dart';
import 'package:vizio_remote/ui/widgets/app_bar.dart';
import 'package:vizio_remote/ui/widgets/menu_tile.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DefaultAppBar(title: "Settings", showAppIcon: false),
      body: SafeArea(
        child: ListView(
          children: [MenuTile(icon: Icons.av_timer, text: "Pairing Timeout")],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:vizio_remote/home_screen.dart';

class SettingsScreen extends StatelessWidget {
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
        actions: [TextButton(onPressed: () {}, child: Text('Support'))],
      ),
    );
  }
}

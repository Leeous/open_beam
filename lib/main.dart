import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

void main() {
  runApp(const VizioRemoteApp());
}

class VizioRemoteApp extends StatelessWidget {
  const VizioRemoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Vizio Remote",
      debugShowCheckedModeBanner: true,
      theme: ThemeData.dark(),
      home: const HomeScreen(),
    );
  }
}

// class RemoteHomeScreen extends StatelessWidget {
  
// }
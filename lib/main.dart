import 'package:flutter/material.dart';
import 'intro_screen.dart';
import 'home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final seenOnboarding = prefs.getBool('seenOnboarding') ?? false;

  runApp(VizioRemoteApp(seenOnboarding: seenOnboarding));
}

class VizioRemoteApp extends StatelessWidget {
  final bool seenOnboarding;
  const VizioRemoteApp({super.key, required this.seenOnboarding});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Vizio Remote",
      debugShowCheckedModeBanner: true,
      theme: ThemeData.dark(),
      home: seenOnboarding ? const HomeScreen() : const IntroScreen(),
    );
  }
}



// class RemoteHomeScreen extends StatelessWidget {
  
// }
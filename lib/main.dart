import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:vizio_remote/data/repositories/tv_cache_repository.dart';
import 'package:vizio_remote/ui/screens/screens.dart';
import 'package:shared_preferences/shared_preferences.dart';

final GetIt getIt = GetIt.instance;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final secureStorage = FlutterSecureStorage();
  final seenOnboarding = prefs.getBool('seenOnboarding') ?? false;

  // Load cached TVs
  getIt.registerSingleton<TvCacheRepository>(
    TvCacheRepository(prefs, secureStorage),
  );

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
      // Check if user has already seen intro; if so, skip to home screen
      home: seenOnboarding ? const HomeScreen() : const IntroScreen(),
    );
  }
}



// class RemoteHomeScreen extends StatelessWidget {
  
// }
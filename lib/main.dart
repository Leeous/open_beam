import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:open_beam/services/tv_storage_service.dart';
import 'package:open_beam/services/lan_scanner_service.dart';
import 'package:open_beam/services/ssdp_discovery_service.dart';
import 'package:open_beam/services/tv_discovery_prober.dart';
import 'package:open_beam/services/http_service.dart';
import 'package:open_beam/ui/app_theme.dart';
import 'package:open_beam/ui/screens/screens.dart';
import 'package:open_beam/ui/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

final GetIt getIt = GetIt.instance;

Future<void> _setupDependencyInjection() async {
  // 1. Core Platform Storage & Network Utilities
  const secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: true),
  );
  getIt.registerSingleton<FlutterSecureStorage>(secureStorage);

  final networkInfo = NetworkInfo();
  getIt.registerSingleton<NetworkInfo>(networkInfo);

  // 2. Base HTTP Service
  final httpService = HTTPService();
  getIt.registerSingleton<HTTPService>(httpService);

  // 3. TV Storage Service (Encrypted + Wi-Fi Scoped)
  final tvStorageService = TvStorageService(storage: secureStorage);
  getIt.registerSingleton<TvStorageService>(tvStorageService);

  // 4. Discovery & Probing Services
  final discoveryProber = TvDiscoveryProber(httpService: httpService);
  getIt.registerSingleton<TvDiscoveryProber>(discoveryProber);

  final ssdpService = SsdpDiscoveryService();
  getIt.registerSingleton<SsdpDiscoveryService>(ssdpService);

  final lanScannerService = LanScannerService(
    prober: discoveryProber,
    ssdpService: ssdpService,
    networkInfo: networkInfo,
  );
  getIt.registerSingleton<LanScannerService>(lanScannerService);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final seenOnboarding = prefs.getBool('seenOnboarding') ?? false;

  await ThemeController.loadTheme();
  await _setupDependencyInjection();

  runApp(OpenBeamApp(seenOnboarding: seenOnboarding));
}

class OpenBeamApp extends StatelessWidget {
  final bool seenOnboarding;
  const OpenBeamApp({super.key, required this.seenOnboarding});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          title: 'Open Beam',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          home: seenOnboarding ? const HomeScreen() : const IntroScreen(),
        );
      },
    );
  }
}

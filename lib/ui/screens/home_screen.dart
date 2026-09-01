import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:open_beam/services/tv_storage_service.dart';
import 'package:open_beam/services/lan_scanner_service.dart';
import 'package:open_beam/services/http_service.dart';
import 'package:open_beam/ui/screens/screens.dart';
import 'package:open_beam/ui/widgets/widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final getIt = GetIt.instance;

    return Scaffold(
      appBar: const DefaultAppBar(showAppIcon: true),
      body: SafeArea(
        child: ListView(
          children: <Widget>[
            MenuTile(
              icon: Icons.tv_sharp,
              text: 'TVs',
              destination: TvListScreen(
                storageService: getIt<TvStorageService>(),
                scannerService: getIt<LanScannerService>(),
                httpService: getIt<HTTPService>(),
              ),
            ),
            const MenuTile(
              icon: Icons.settings,
              text: 'Settings',
              destination: SettingsScreen(),
            ),
          ],
        ),
      ),
    );
  }
}

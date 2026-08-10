import 'package:flutter/material.dart';
import 'package:vizio_remote/ui/screens/screens.dart';
import 'package:vizio_remote/ui/widgets/widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext build) {
    return Scaffold(
      appBar: DefaultAppBar(showAppIcon: true),
      body: SafeArea(
        child: ListView(
          children: <Widget>[
            MenuTile(
              icon: Icons.tv_sharp,
              text: "TVs",
              destination: TVListScreen(),
            ),
            MenuTile(
              icon: Icons.gamepad,
              text: "Remote",
              destination: RemoteScreen(
                tvName: "tvName",
                tvIp: "",
                authToken: "",
              ),
            ),
            MenuTile(
              icon: Icons.settings,
              text: "Settings",
              destination: SettingsScreen(),
            ),
          ],
        ),
      ),
    );
  }
}

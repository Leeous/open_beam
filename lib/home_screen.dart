import 'package:flutter/material.dart';
import 'package:vizio_remote/remote_screen.dart';
import 'package:vizio_remote/settings_screen.dart';
import 'package:vizio_remote/ui/widgets/menu_tile.dart';
import 'tv_list_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext build) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text('Vizio Remote'),
            const SizedBox(width: 4),
            Image.asset(
              "assets/icon/icon.png",
              fit: BoxFit.contain,
              height: 35,
            ),
          ],
        ),
        backgroundColor: Colors.black12,
        foregroundColor: Color(0xFFFFD42A),
      ),
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

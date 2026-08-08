import 'package:flutter/material.dart';
import 'package:vizio_remote/remote_screen.dart';
import 'package:vizio_remote/settings_screen.dart';
import 'tv_list_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext build) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Vizio Remote'),
        backgroundColor: Colors.black12,
        foregroundColor: Colors.amber,
      ),
      body: SafeArea(
        child: ListView(
          children: <Widget>[
            ListTile(
              leading: Icon(Icons.tv_sharp),
              title: Text('TVs'),
              onTap: () {
                Navigator.push(
                  build,
                  MaterialPageRoute<dynamic>(
                    builder: (context) => TVListScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.gamepad),
              title: Text('Remote'),
              onTap: () {
                Navigator.push(
                  build,
                  MaterialPageRoute<dynamic>(
                    builder: (context) =>
                        RemoteScreen(tvName: '', tvIp: '', authToken: ''),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('Settings'),
              onTap: () {
                Navigator.push(
                  build,
                  MaterialPageRoute<dynamic>(
                    builder: (context) => SettingsScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

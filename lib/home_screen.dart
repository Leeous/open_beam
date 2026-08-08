import 'package:flutter/material.dart';
import 'package:vizio_remote/remote_screen.dart';
import 'tv_list_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext build) {
    return Scaffold(
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
                    builder: (context) => RemoteScreen(),
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

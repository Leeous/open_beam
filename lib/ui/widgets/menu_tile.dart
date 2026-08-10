import 'package:flutter/material.dart';

/// A simplified, reusable wrapper around [ListTile] for navigation
/// IconData [icon] - Icon for menu item.
/// String [text] - Text for menu item.
/// Widget [destination] - Menu item destination.
class MenuTile extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget destination;

  final Color? iconColor;
  final double iconSize;
  final EdgeInsets padding;

  const MenuTile({
    super.key,
    required this.icon,
    required this.text,
    required this.destination,
    this.iconColor,
    this.iconSize = 24.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(text),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute<dynamic>(builder: (context) => destination),
        );
      },
    );
  }
}

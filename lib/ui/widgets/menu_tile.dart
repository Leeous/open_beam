import 'package:flutter/material.dart';

/// A simplified, reusable wrapper around [ListTile] for navigation
/// IconData [icon] - Icon for menu item.
/// String [text] - Text for menu item.
/// Widget [destination] - Menu item destination.
class MenuTile extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color? iconColor;
  final double iconSize;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Widget? destination;
  final bool popOnTap;

  const MenuTile({
    super.key,
    required this.text,
    this.icon,
    this.iconColor,
    this.iconSize = 24.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.onTap,
    this.destination,
    this.popOnTap = false,
  });

  VoidCallback? _resolveOnTap(BuildContext context) {
    if (onTap != null) {
      return onTap;
    }

    if (destination != null) {
      return () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute<dynamic>(builder: (_) => destination!));
      };
    }

    if (popOnTap) {
      Navigator.of(context).pop();
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final resolvedTap = _resolveOnTap(context);

    return ListTile(
      leading: Icon(
        icon ?? Icons.chevron_right,
        color: iconColor,
        size: iconSize,
      ),
      title: Text(text),
      contentPadding: padding,
      onTap: resolvedTap,
    );
  }
}

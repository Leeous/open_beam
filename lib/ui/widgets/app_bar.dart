import 'package:flutter/material.dart';

class DefaultAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBackButton;
  final bool showAppIcon;
  final Color foregroundColor;
  final Color backgroundColor;

  const DefaultAppBar({
    super.key,
    this.title = "Vizio Remote",
    this.actions,
    this.backgroundColor = Colors.black12,
    this.foregroundColor = const Color(0xFFFFD42A),
    this.showBackButton = true,
    this.showAppIcon = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Row(
        children: [
          Text(title),
          SizedBox(width: 4),
          if (showAppIcon)
            Image.asset(
              "assets/icon/icon.png",
              fit: BoxFit.contain,
              height: 35,
            ),
        ],
      ),
      foregroundColor: foregroundColor,
      backgroundColor: backgroundColor,
    );
  }
}

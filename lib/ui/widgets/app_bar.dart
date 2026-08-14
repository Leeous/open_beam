import 'package:flutter/material.dart';

class DefaultAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBackButton;
  final bool showAppIcon;

  const DefaultAppBar({
    super.key,
    this.title = "Vizio Remote",
    this.actions,
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
    );
  }
}

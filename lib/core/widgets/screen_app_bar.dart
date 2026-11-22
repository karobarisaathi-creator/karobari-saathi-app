import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ScreenAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool isUrdu;
  final List<Widget>? actions;
  final bool showBackButton;

  const ScreenAppBar({
    super.key,
    required this.title,
    required this.isUrdu,
    this.actions,
    this.showBackButton = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final fontFamily = isUrdu ? 'NooriNastaleeq' : null;

    return AppBar(
      backgroundColor: AppTheme.backgroundColor,
      foregroundColor: AppTheme.darkColor,
      elevation: 0,
      leading: showBackButton
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.maybePop(context),
              tooltip: isUrdu ? 'پیچھے جائیں' : 'Back',
            )
          : null,
      automaticallyImplyLeading: showBackButton,
      title: UrduAwareText(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          fontFamily: fontFamily,
          color: AppTheme.darkColor,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: actions,
    );
  }
}

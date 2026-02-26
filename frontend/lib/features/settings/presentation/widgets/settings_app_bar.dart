import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';

class SettingsAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final bool centerLogo;
  final String logoAsset;
  final bool showBackButton;
  final VoidCallback? onBack;
  final List<Widget>? actions;

  const SettingsAppBar({
    super.key,
    this.title,
    this.centerLogo = false,
    this.logoAsset = 'assets/images/branding/logo.png',
    this.showBackButton = true,
    this.onBack,
    this.actions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, c) {
        final w = MediaQuery.of(context).size.width;
        final iconSize = (w * 0.045).clamp(18.0, 22.0);
        final logoSize = (w * 0.07).clamp(26.0, 32.0);
        final titleSize = (w * 0.045).clamp(16.0, 20.0);

        Widget? titleWidget;
        if (centerLogo) {
          titleWidget = SizedBox(
            width: logoSize,
            height: logoSize,
            child: Image.asset(
              logoAsset,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                Icons.person,
                size: iconSize,
                color: isDark ? AppColors.grey50 : const Color(0xFF0F111D),
              ),
            ),
          );
        } else if (title != null) {
          titleWidget = Text(
            title!,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: titleSize,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.grey50 : const Color(0xFF0F111D),
              height: 1.2,
            ),
          );
        }

        return AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: titleWidget,
          leading: showBackButton
              ? InkWell(
                  onTap: onBack ?? () => context.pop(),
                  borderRadius: BorderRadius.circular(24),
                  child: Center(
                    child: Icon(
                      Icons.arrow_back_ios_new,
                      size: iconSize,
                      color:
                          isDark ? AppColors.grey50 : const Color(0xFF0F111D),
                    ),
                  ),
                )
              : null,
          actions: actions,
        );
      },
    );
  }
}

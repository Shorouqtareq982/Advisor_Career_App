import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';

class HomeBottomNav extends StatelessWidget {
  final String currentRoute;

  const HomeBottomNav({
    super.key,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Container(
        height: context.h(70),
        padding: EdgeInsets.only(
          left: context.w(24),
          right: context.w(24),
          bottom: context.h(3),
        ),
        decoration: BoxDecoration(
          // Dark: blue900, Light: textDark (#EBEBEB)
          color: isDark ? AppColors.blue900 : AppColors.textDark,
          border: Border(
            top: BorderSide(
              color: isDark
                  ? AppColors.blue200.withOpacity(0.3)
                  : AppColors.grey800.withOpacity(0.3),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              // Dark: blue200, Light: grey800
              color: isDark
                  ? AppColors.blue200.withOpacity(0.25)
                  : AppColors.grey800.withOpacity(0.25),
              offset: const Offset(0, 0),
              blurRadius: 4,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: context.contentConstraints,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _NavItem(
                  icon: Icons.home,
                  label: 'Home',
                  isActive: currentRoute == '/home',
                  onTap: () => context.go('/home'),
                  isDark: isDark,
                ),
                _NavItem(
                  icon: Icons.work_outline,
                  label: 'Jobs',
                  isActive: currentRoute == '/jobs',
                  onTap: () => context.go('/jobs'),
                  isDark: isDark,
                ),
                _NavItem(
                  icon: Icons.notifications_outlined,
                  label: 'Alerts',
                  isActive: currentRoute == '/alerts',
                  onTap: () => context.go('/alerts'),
                  isDark: isDark,
                ),
                _NavItem(
                  icon: Icons.person_outline,
                  label: 'Profile',
                  isActive: currentRoute == '/profile',
                  onTap: () => context.go('/profile'),
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool isDark;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    // Inactive: 24px design, Active: 29px design — responsive
    // constraint h=49.6px → icon + gap + text must fit
    final double inactiveSize = context.icon(22).clamp(18.0, 24.0);
    final double activeSize = context.icon(26).clamp(22.0, 28.0);
    final double iconSize = isActive ? activeSize : inactiveSize;

    // Keep font small enough to not overflow
    final double fontSize = isActive
        ? context.sp(13).clamp(11.0, 14.0)
        : context.sp(11).clamp(9.0, 13.0);

    final Color activeColor =
        isDark ? AppColors.lightBlue500 : AppColors.lightBlue700;
    final Color inactiveColor = isDark ? AppColors.blue200 : AppColors.grey800;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.r(12)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? activeColor : inactiveColor,
              size: iconSize,
            ),
            SizedBox(height: context.h(2)),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: fontSize,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                height: 1.0,
                color: isActive ? activeColor : inactiveColor,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

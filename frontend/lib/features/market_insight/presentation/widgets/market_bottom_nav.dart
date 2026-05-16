import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';

class MarketBottomNav extends StatelessWidget {
  const MarketBottomNav({super.key});

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
                _MarketNavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Home',
                  isActive: false,
                  onTap: () => context.go('/home'),
                  isDark: isDark,
                ),
                _MarketNavItem(
                  icon: Icons.work_outline_rounded,
                  activeIcon: Icons.work_rounded,
                  label: 'Jobs',
                  isActive: false,
                  onTap: () => context.go('/jobs'),
                  isDark: isDark,
                ),
                _MarketNavItem(
                  icon: Icons.notifications_none_rounded,
                  activeIcon: Icons.notifications_rounded,
                  label: 'Alerts',
                  isActive: false,
                  onTap: () => context.go('/alerts'),
                  isDark: isDark,
                ),
                _MarketNavItem(
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: 'Profile',
                  isActive: false,
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

class _MarketNavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool isDark;

  const _MarketNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor =
        isDark ? AppColors.lightBlue500 : AppColors.lightBlue700;

    final inactiveColor = isDark ? AppColors.blue200 : const Color(0xFF686868);

    final color = isActive ? activeColor : inactiveColor;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.r(12)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: color,
              size: isActive ? context.icon(27) : context.icon(24),
            ),
            SizedBox(height: context.h(2)),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontFamily: 'Inter',
                fontSize: isActive ? 13 : 12,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                height: 1.2,
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

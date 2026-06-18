import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../providers/ai_portfolio_provider.dart';

class AIPortfolioBottomNav extends StatelessWidget {
  final PortfolioTab currentTab;
  final bool canNavigate;
  final bool canPreview;
  final ValueChanged<PortfolioTab> onTap;

  const AIPortfolioBottomNav({
    super.key,
    required this.currentTab,
    required this.canNavigate,
    required this.canPreview,
    required this.onTap,
  });

  static const _basePath = 'assets/images/ai_protifilo';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final items = [
      _PortfolioNavItemData(
        label: 'Edit',
        assetPath: '$_basePath/edit.png',
        tab: PortfolioTab.edit,
      ),
      _PortfolioNavItemData(
        label: 'Designs',
        assetPath: '$_basePath/designs.png',
        tab: PortfolioTab.designs,
      ),
      _PortfolioNavItemData(
        label: 'Preview',
        assetPath: '$_basePath/preview.png',
        tab: PortfolioTab.preview,
      ),
      _PortfolioNavItemData(
        label: 'Settings',
        assetPath: '$_basePath/settings.png',
        tab: PortfolioTab.settings,
      ),
    ];

    return Container(
      height: context.h(70),
      padding: EdgeInsets.only(
        left: context.w(21),
        right: context.w(21),
        top: context.h(8),
        bottom: context.h(3),
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131A3B) : AppColors.grey100,
        boxShadow: const [
          BoxShadow(
            color: AppColors.lightshadow,
            blurRadius: 4,
            offset: Offset(0, 0),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: items.map((item) {
          final enabled = item.tab == PortfolioTab.edit || canNavigate;
          final previewAllowed = item.tab != PortfolioTab.preview || canPreview;
          final settingsAllowed =
              item.tab != PortfolioTab.settings || canPreview;
          final isEnabled = enabled && previewAllowed && settingsAllowed;

          return _PortfolioNavItem(
            label: item.label,
            assetPath: item.assetPath,
            isSelected: currentTab == item.tab,
            isEnabled: isEnabled,
            onTap: () {
              if (isEnabled) onTap(item.tab);
            },
          );
        }).toList(),
      ),
    );
  }
}

class _PortfolioNavItemData {
  final String label;
  final String assetPath;
  final PortfolioTab tab;

  const _PortfolioNavItemData({
    required this.label,
    required this.assetPath,
    required this.tab,
  });
}

class _PortfolioNavItem extends StatelessWidget {
  final String label;
  final String assetPath;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback onTap;

  const _PortfolioNavItem({
    required this.label,
    required this.assetPath,
    required this.isSelected,
    required this.isEnabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? AppColors.lightBlue700
        : (isEnabled ? AppColors.grey700 : AppColors.grey500);

    return InkWell(
      onTap: isEnabled ? onTap : null,
      borderRadius: BorderRadius.circular(context.r(10)),
      child: SizedBox(
        width: context.w(67),
        height: context.h(67),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              assetPath,
              width: context.icon(20),
              height: context.icon(20),
              color: color,
            ),
            SizedBox(height: context.h(4)),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: context.sp(12).clamp(11.0, 12.0),
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

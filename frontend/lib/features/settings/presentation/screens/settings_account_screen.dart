import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../widgets/settings_app_bar.dart';

class SettingsAccountScreen extends StatefulWidget {
  const SettingsAccountScreen({super.key});

  @override
  State<SettingsAccountScreen> createState() => _SettingsAccountScreenState();
}

class _SettingsAccountScreenState extends State<SettingsAccountScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.blue500,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: context.contentConstraints,
            child: Column(
              children: [
                //     AppBar
                SettingsAppBar(
                  title: null,
                  showBackButton: true,
                  actions: [
                    SizedBox(
                      width: context.w(32),
                      height: context.w(32),
                      child: Image.asset(
                        'assets/images/branding/logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.person,
                          color: isDark
                              ? AppColors.grey50
                              : const Color(0xFF0F111D),
                          size: context.icon(18),
                        ),
                      ),
                    ),
                    SizedBox(width: context.w(12)),
                  ],
                ),

                SizedBox(height: context.h(8)),

                //     Title
                Text(
                  'Account',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: context.sp(20),
                    fontWeight: FontWeight.w700,
                    color: AppColors.grey50,
                    height: 1.2,
                  ),
                ),

                SizedBox(height: context.h(16)),

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: context.w(16)),
                  child: _AccountTabs(
                    selectedIndex: _selectedTab,
                    onSelect: (i) {
                      setState(() => _selectedTab = i);

                      if (i == 0) context.push('/personal-info');
                      if (i == 1) context.push('/career-preferences');
                    },
                  ),
                ),

                SizedBox(height: context.h(16)),

                //     Content
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: context.w(16)),
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _buildInfoTile(
                          context,
                          isDark: isDark,
                          icon: Icons.email_outlined,
                          title: 'Email',
                          value: 'user@example.com',
                          onEdit: () {},
                        ),
                        _buildInfoTile(
                          context,
                          isDark: isDark,
                          icon: Icons.phone_outlined,
                          title: 'Phone',
                          value: '+20 123 456 7890',
                          onEdit: () {},
                        ),
                        _buildInfoTile(
                          context,
                          isDark: isDark,
                          icon: Icons.cake_outlined,
                          title: 'Date of Birth',
                          value: 'January 1, 1990',
                          onEdit: () {},
                        ),
                        _buildInfoTile(
                          context,
                          isDark: isDark,
                          icon: Icons.location_on_outlined,
                          title: 'Location',
                          value: 'Cairo, Egypt',
                          onEdit: () {},
                        ),
                        SizedBox(height: context.h(24)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(
    BuildContext context, {
    required bool isDark,
    required IconData icon,
    required String title,
    required String value,
    VoidCallback? onEdit,
  }) {
    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(context.r(12)),
      child: Container(
        margin: EdgeInsets.only(bottom: context.h(12)),
        padding: EdgeInsets.all(context.w(16)),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2F) : AppColors.grey50,
          borderRadius: BorderRadius.circular(context.r(12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: context.w(44),
              height: context.w(44),
              decoration: BoxDecoration(
                color: AppColors.lightBlue500.withOpacity(0.12),
                borderRadius: BorderRadius.circular(context.r(10)),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: AppColors.lightBlue500,
                size: context.icon(20),
              ),
            ),
            SizedBox(width: context.w(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: context.sp(12),
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey.shade400 : AppColors.grey800,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: context.h(4)),
                  Text(
                    value,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: context.sp(14),
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.grey50 : AppColors.blue900,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.edit_outlined,
              color: AppColors.lightBlue500,
              size: context.icon(20),
            ),
          ],
        ),
      ),
    );
  }
}

//        ===
//     Oval Tabs Widget
//        ===
class _AccountTabs extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _AccountTabs({
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(context.w(6)),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2F) : AppColors.grey50,
        borderRadius: BorderRadius.circular(context.r(999)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _tabButton(
              context,
              label: 'Personal Info',
              isSelected: selectedIndex == 0,
              onTap: () => onSelect(0),
            ),
          ),
          SizedBox(width: context.w(8)),
          Expanded(
            child: _tabButton(
              context,
              label: 'Career',
              isSelected: selectedIndex == 1,
              onTap: () => onSelect(1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.r(999)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: context.h(46), //     bigger
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.lightBlue700
              : (isDark ? Colors.transparent : Colors.transparent),
          borderRadius: BorderRadius.circular(context.r(999)),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : (isDark
                    ? AppColors.grey50.withOpacity(0.15)
                    : const Color(0xFFE6E6E6)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: context.sp(14),
            fontWeight: FontWeight.w700,
            color: isSelected
                ? AppColors.grey50
                : (isDark ? AppColors.grey50 : const Color(0xFF0F111D)),
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

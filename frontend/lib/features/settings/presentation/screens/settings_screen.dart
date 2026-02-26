import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../home/presentation/widgets/home_bottom_nav.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/notification_service.dart';
import '../widgets/settings_switch.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsEnabled = false;
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    await _notificationService.init();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? false;
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() => _notificationsEnabled = value);
    await _notificationService.toggleNotifications(value);

    if (!mounted) return;

    final w = MediaQuery.of(context).size.width;
    final font = (w * 0.032).clamp(13.0, 15.0);
    final margin = (w * 0.04).clamp(12.0, 18.0);
    final radius = (w * 0.03).clamp(10.0, 14.0);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value ? 'Notifications enabled' : 'Notifications disabled',
          style: TextStyle(fontFamily: 'Inter', fontSize: font),
        ),
        backgroundColor: value ? AppColors.green700 : AppColors.grey800,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(margin),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }

  Future<void> _toggleTheme(bool value) async {
    await ref.read(themeProvider.notifier).toggleTheme();
  }

  void _navigateToProfile() {
    context.push('/personal-info');
  }

  Future<void> _handleLogout() async {
    final w = MediaQuery.of(context).size.width;
    final radius = (w * 0.03).clamp(12.0, 18.0);
    final fs = (w * 0.034).clamp(13.0, 15.0);

    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Logout',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: (w * 0.04).clamp(15.0, 18.0),
          ),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: TextStyle(fontFamily: 'Inter', fontSize: fs),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: AppColors.grey800,
                fontFamily: 'Inter',
                fontSize: fs,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50),
              ),
            ),
            child: Text(
              'Logout',
              style: TextStyle(
                fontFamily: 'Inter',
                color: AppColors.grey50,
                fontSize: fs,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      await ref.read(authProvider.notifier).signOut();
      if (mounted) context.go('/splash');
    }
  }

  Future<void> _handleDeleteAccount() async {
    final w = MediaQuery.of(context).size.width;
    final radius = (w * 0.03).clamp(12.0, 18.0);
    final fs = (w * 0.034).clamp(13.0, 15.0);

    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Account',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            color: AppColors.red600,
            fontSize: (w * 0.04).clamp(15.0, 18.0),
          ),
        ),
        content: Text(
          'This action cannot be undone!\n\n'
          'All your data will be permanently deleted and you will not be able to recover it.',
          style: TextStyle(fontFamily: 'Inter', fontSize: fs),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: AppColors.grey800,
                fontFamily: 'Inter',
                fontSize: fs,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50),
              ),
            ),
            child: Text(
              'Continue',
              style: TextStyle(
                fontFamily: 'Inter',
                color: AppColors.grey50,
                fontSize: fs,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldProceed == true && mounted) {
      context.push('/delete-account');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;

    final headerIconColor = isDark ? AppColors.grey50 : const Color(0xFF0F111D);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      bottomNavigationBar: const HomeBottomNav(currentRoute: '/profile'),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenW = constraints.maxWidth;
            final screenH = constraints.maxHeight;

            final horizontalPadding = (screenW * 0.04).clamp(14.0, 36.0);

            final headerTop = (screenH * 0.01).clamp(6.0, 10.0);
            final smallGap = (screenH * 0.012).clamp(6.0, 10.0);
            final mediumGap = (screenH * 0.02).clamp(14.0, 20.0);

            final logoSize = (screenW * 0.04).clamp(28.0, 38.0);
            final backIconSize = (screenW * 0.02).clamp(18.0, 24.0);
            final titleSize = (screenW * 0.025).clamp(20.0, 28.0);

            final contentWidth = screenW;

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Column(
                children: [
                  SizedBox(height: headerTop),
                  SizedBox(
                    height: (screenH * 0.07).clamp(48.0, 58.0),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: InkWell(
                            onTap: () => context.go('/home'),
                            borderRadius: BorderRadius.circular(24),
                            child: Padding(
                              padding: EdgeInsets.all(
                                (contentWidth * 0.01).clamp(6.0, 10.0),
                              ),
                              child: Icon(
                                Icons.arrow_back_ios_new,
                                size: backIconSize,
                                color: headerIconColor,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: logoSize,
                          height: logoSize,
                          child: Image.asset(
                            'assets/images/branding/logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.person,
                              color: headerIconColor,
                              size: backIconSize,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: smallGap),
                  Text(
                    'Settings',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: titleSize,
                      fontWeight: FontWeight.w700,
                      color: headerIconColor,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: mediumGap),
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _buildSettingsItem(
                          context,
                          maxContentWidth: contentWidth,
                          icon: Icons.person_outline,
                          title: 'Profile',
                          subtitle: 'personal information & Career Preferences',
                          onTap: _navigateToProfile,
                        ),

                        // ✅✅✅ Security -> Change Password مباشرة
                        _buildSettingsItem(
                          context,
                          maxContentWidth: contentWidth,
                          icon: Icons.shield_outlined,
                          title: 'Security',
                          subtitle: 'Password & authentication',
                          onTap: () => context.push('/change-password'),
                        ),

                        _buildSettingsItem(
                          context,
                          maxContentWidth: contentWidth,
                          icon: Icons.notifications_outlined,
                          title: 'Alerts',
                          trailing: SettingsSwitch(
                            value: _notificationsEnabled,
                            onChanged: _toggleNotifications,
                          ),
                        ),
                        _buildSettingsItem(
                          context,
                          maxContentWidth: contentWidth,
                          icon: Icons.wb_sunny_outlined,
                          title: 'Theme',
                          trailing: SettingsSwitch(
                            value: isDark,
                            onChanged: (_) => _toggleTheme(isDark),
                          ),
                        ),
                        _buildSettingsItem(
                          context,
                          maxContentWidth: contentWidth,
                          icon: Icons.help_outline,
                          title: 'Support',
                          subtitle: 'Help & contact us',
                          onTap: () => context.push('/settings-support'),
                        ),
                        _buildSettingsItem(
                          context,
                          maxContentWidth: contentWidth,
                          icon: Icons.logout,
                          title: 'Logout',
                          onTap: _handleLogout,
                        ),
                        SizedBox(height: smallGap),
                        _buildSettingsItem(
                          context,
                          maxContentWidth: contentWidth,
                          icon: Icons.delete_outline,
                          title: 'Delete Account',
                          titleColor: AppColors.red600,
                          onTap: _handleDeleteAccount,
                        ),
                        SizedBox(height: mediumGap),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSettingsItem(
    BuildContext context, {
    required double maxContentWidth,
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? titleColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final padH = (maxContentWidth * 0.02).clamp(14.0, 22.0);
    final padV = (maxContentWidth * 0.012).clamp(10.0, 16.0);
    final radius = (maxContentWidth * 0.02).clamp(10.0, 16.0);

    final iconSize = (maxContentWidth * 0.02).clamp(18.0, 24.0);
    final titleSize = (maxContentWidth * 0.018).clamp(14.0, 18.0);
    final subSize = (maxContentWidth * 0.015).clamp(12.0, 15.0);

    final gap = (maxContentWidth * 0.015).clamp(10.0, 16.0);
    final marginBottom = (maxContentWidth * 0.012).clamp(10.0, 16.0);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        margin: EdgeInsets.only(bottom: marginBottom),
        padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2F) : AppColors.grey50,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: titleColor ??
                  (isDark ? AppColors.grey50 : const Color(0xFF0F111D)),
              size: iconSize,
            ),
            SizedBox(width: gap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: titleSize,
                      fontWeight: FontWeight.w500,
                      color: titleColor ??
                          (isDark ? AppColors.grey50 : const Color(0xFF0F111D)),
                      height: 1.2,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: subSize,
                        fontWeight: FontWeight.w400,
                        color: isDark
                            ? Colors.grey.shade400
                            : const Color(0xFF686868),
                        height: 1.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing,
            if (onTap != null && trailing == null)
              Icon(
                Icons.arrow_forward_ios,
                color: isDark ? Colors.grey.shade400 : const Color(0xFF686868),
                size: (maxContentWidth * 0.016).clamp(14.0, 18.0),
              ),
          ],
        ),
      ),
    );
  }
}

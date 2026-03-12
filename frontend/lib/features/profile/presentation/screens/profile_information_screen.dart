import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../auth/presentation/widgets/custom_text_field.dart';

class ProfileInformationScreen extends ConsumerStatefulWidget {
  final bool fromHome;

  const ProfileInformationScreen({
    super.key,
    this.fromHome = false,
  });

  @override
  ConsumerState<ProfileInformationScreen> createState() =>
      _ProfileInformationScreenState();
}

class _ProfileInformationScreenState
    extends ConsumerState<ProfileInformationScreen> {
  final _interestedTracksController = TextEditingController();
  final _jobTitleController = TextEditingController();
  final _preferredLocationController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;

  @override
  void dispose() {
    _interestedTracksController.dispose();
    _jobTitleController.dispose();
    _preferredLocationController.dispose();
    super.dispose();
  }

  String get _afterProfileRoute => widget.fromHome ? '/settings' : '/home';

  Future<void> _handleSave() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _isLoading = false);
    context.go(_afterProfileRoute);
  }

  void _handleSkip() => context.go(_afterProfileRoute);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF1E1E2F) : Colors.white;
    final titleColor = isDark ? AppColors.grey50 : AppColors.blue900;
    final descColor = isDark ? Colors.grey.shade400 : AppColors.grey800;

    return Scaffold(
      backgroundColor: AppColors.blue500,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenW = constraints.maxWidth;
            final screenH = constraints.maxHeight;

            final horizontalPad = screenW >= 1024 ? 40.0 : 20.0;
            final panelTop = (screenH * 0.42).clamp(220.0, 360.0);

            final bottomSafe = MediaQuery.of(context).padding.bottom;
            final keyboard = MediaQuery.of(context).viewInsets.bottom;

            return Stack(
              children: [
                Positioned.fill(child: Container(color: AppColors.blue500)),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Image.asset(
                    'assets/images/top_curve.png',
                    width: screenW,
                    height: screenH * 0.38,
                    fit: BoxFit.fill,
                  ),
                ),
                Positioned(
                  top: context.h(16),
                  right: context.w(20),
                  child: TextButton(
                    onPressed: _handleSkip,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: context.sp(16),
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: context.h(60),
                  left: 0,
                  right: 0,
                  child: const Center(child: AppLogo()),
                ),
                Positioned(
                  top: panelTop,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(44)),
                    ),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPad,
                        context.h(24),
                        horizontalPad,
                        context.h(24) + bottomSafe + keyboard,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Profile Information',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: context.sp(screenW >= 600 ? 24 : 22),
                                fontWeight: FontWeight.w700,
                                color: titleColor,
                              ),
                            ),
                            SizedBox(height: context.h(8)),
                            Text(
                              'Complete your profile to help us personalize your career experience.',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: context.sp(screenW >= 600 ? 15 : 13),
                                color: descColor,
                              ),
                            ),
                            SizedBox(height: context.h(28)),
                            CustomTextField(
                              controller: _interestedTracksController,
                              label: 'Interested Tracks',
                              hintText: 'UI/UX, Machine Learning...',
                              prefixIcon: Icons.track_changes_outlined,
                              useTheme: true,
                            ),
                            SizedBox(height: context.h(16)),
                            CustomTextField(
                              controller: _jobTitleController,
                              label: 'Job Title',
                              hintText: 'Data Analyst, ML Engineer...',
                              prefixIcon: Icons.work_outline,
                              useTheme: true,
                            ),
                            SizedBox(height: context.h(16)),
                            CustomTextField(
                              controller: _preferredLocationController,
                              label: 'Preferred Location',
                              hintText: 'Alexandria, Cairo...',
                              prefixIcon: Icons.location_on_outlined,
                              useTheme: true,
                            ),
                            SizedBox(height: context.h(32)),
                            Theme(
                              data: Theme.of(context).copyWith(
                                elevatedButtonTheme: ElevatedButtonThemeData(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isDark
                                        ? AppColors.lightBlue500
                                        : AppColors.lightBlue700,
                                  ),
                                ),
                              ),
                              child: CustomButton(
                                text: 'Continue',
                                onPressed: _handleSave,
                                isLoading: _isLoading,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

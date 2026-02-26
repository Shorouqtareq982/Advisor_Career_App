import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_colors.dart';
import '../widgets/onboarding_dots.dart';
import '../widgets/onboarding_nav_buttons.dart';
import '../widgets/onboarding_page_content.dart';
import '../widgets/onboarding_top_bar.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _controller;
  int _index = 0;

  static const List<_OnboardingPageData> _pages = [
    _OnboardingPageData(
      imagePath: 'assets/images/onboarding/onboarding_1.png',
      title: 'Build Your Career Smarter',
      body:
          'Get personalized guidance to craft the perfect career path with the power of AI.',
      primaryButtonText: 'Next',
    ),
    _OnboardingPageData(
      imagePath: 'assets/images/onboarding/onboarding_2.png',
      title: 'Your AI Career Partner',
      body:
          'Optimize your resume, practice AI interviews, and match with jobs that truly fit you.',
      primaryButtonText: 'Next',
    ),
    _OnboardingPageData(
      imagePath: 'assets/images/onboarding/onboarding_3.png',
      title: 'Ready to Land Your Dream Job?',
      body:
          'Start your journey today with intelligent tools designed for your success.',
      primaryButtonText: 'Start',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goNext() {
    if (_index < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finishOnboarding(); // صفحة 3 => Start
    }
  }

  void _goBack() {
    if (_index > 0) {
      _controller.previousPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  // ✅ Skip في الصفحة 1 و 2: يودّي للصفحة الثالثة مباشرة
  void _skipToLast() {
    final lastIndex = _pages.length - 1;
    if (_index == lastIndex) return; // ✅ ممنوع في الصفحة الأخيرة
    _controller.animateToPage(
      lastIndex,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    if (mounted) context.go('/'); // ✅ يسلّم القرار للـ Splash/Router
  }

  @override
  Widget build(BuildContext context) {
    final safeIndex = _index.clamp(0, _pages.length - 1);
    final data = _pages[safeIndex];
    final isLast = safeIndex == _pages.length - 1;

    return Scaffold(
      backgroundColor: AppColors.blue500,
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenW = constraints.maxWidth;
            final screenH = constraints.maxHeight;
            final safeBottom = MediaQuery.of(context).padding.bottom;

            final maxContentWidth =
                screenW >= 1024 ? 720.0 : (screenW >= 600 ? 560.0 : screenW);

            final horizontalPad = (screenW * 0.06).clamp(16.0, 28.0);
            final isShort = screenH < 650;

            final topBarZone =
                (screenH * (isShort ? 0.16 : 0.18)).clamp(120.0, 170.0);

            final afterTopBar =
                (screenH * (isShort ? 0.008 : 0.014)).clamp(6.0, 14.0);

            final dotsGap =
                (screenH * (isShort ? 0.006 : 0.008)).clamp(4.0, 10.0);

            final dotsH = (maxContentWidth * 0.03).clamp(8.0, 12.0);

            final bottomPad =
                (screenH * (isShort ? 0.001 : 0.002)).clamp(0.0, 4.0);

            final btnH = (screenH * 0.055).clamp(44.0, 52.0);

            final reserved = topBarZone +
                afterTopBar +
                dotsGap +
                dotsH +
                bottomPad +
                safeBottom +
                btnH;

            final pageViewH = (screenH - reserved).clamp(240.0, screenH);

            return Column(
              children: [
                SizedBox(
                  height: topBarZone,
                  width: double.infinity,
                  child: OnboardingTopBar(
                    onSkip: _skipToLast,
                    showSkip: !isLast, // ✅ اخفاء Skip في الصفحة 3
                  ),
                ),
                SizedBox(height: afterTopBar),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxContentWidth),
                      child: Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: horizontalPad),
                        child: Column(
                          children: [
                            SizedBox(
                              height: pageViewH,
                              child: PageView.builder(
                                controller: _controller,
                                itemCount: _pages.length,
                                onPageChanged: (i) =>
                                    setState(() => _index = i),
                                itemBuilder: (context, i) {
                                  final p = _pages[i];
                                  return OnboardingPageContent(
                                    imagePath: p.imagePath,
                                    title: p.title,
                                    body: p.body,
                                  );
                                },
                              ),
                            ),
                            SizedBox(height: dotsGap),
                            OnboardingDots(
                              count: _pages.length,
                              activeIndex: safeIndex,
                            ),
                            SizedBox(height: bottomPad),
                            SizedBox(
                              height: btnH,
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: OnboardingNavButtons(
                                  index: safeIndex,
                                  primaryText: data.primaryButtonText,
                                  onBack: _goBack,
                                  onPrimary: _goNext,
                                ),
                              ),
                            ),
                            SizedBox(height: safeBottom * 0.6),
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

class _OnboardingPageData {
  final String imagePath;
  final String title;
  final String body;
  final String primaryButtonText;

  const _OnboardingPageData({
    required this.imagePath,
    required this.title,
    required this.body,
    required this.primaryButtonText,
  });
}

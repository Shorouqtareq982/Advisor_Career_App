import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../../../../core/theme/app_text_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/home_bottom_nav.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final List<_QuickActionItem> items = const [
    _QuickActionItem(
      imagePath: 'assets/images/home_icons/job_recommendation.png',
      title: 'Job Matching',
      subtitle: 'Find jobs tailored to you',
      route: '/jobs',
    ),
    _QuickActionItem(
      imagePath: 'assets/images/home_icons/resume.png',
      title: 'Resume',
      subtitle: 'Optimize your CV for ATS & jobs',
      route: '/resume-optimization',
    ),
    _QuickActionItem(
      imagePath: 'assets/images/home_icons/mock_interview.png',
      title: 'Mock Interview',
      subtitle: 'Practice interviews with AI',
      route: '/mock-interview',
    ),
    _QuickActionItem(
      imagePath: 'assets/images/home_icons/career_build.png',
      title: 'Career Builder',
      subtitle: 'Personalized career roadmap',
      route: '/career-builder',
    ),
    _QuickActionItem(
      imagePath: 'assets/images/home_icons/ai_portfolio.png',
      title: 'AI Portfolio',
      subtitle: 'Showcase projects & achievements',
      route: '/ai-portfolio',
    ),
    _QuickActionItem(
      imagePath: 'assets/images/home_icons/market_insights.png',
      title: 'Market Insights',
      subtitle: 'Salaries, demand & trends',
      route: '/market-insights',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).completeOnboarding();
    });
  }

  int _getCrossAxisCount(BuildContext context) {
    if (context.isDesktop) return 3;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final isProfileComplete = user?.isProfileComplete ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final crossAxisCount = _getCrossAxisCount(context);
    final textTheme = context.appTextTheme;

    return Scaffold(
      backgroundColor: isDark ? AppColors.blue900 : AppColors.textDark,
      bottomNavigationBar: const HomeBottomNav(currentRoute: '/home'),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.w(16),
              vertical: context.h(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, user, isDark, textTheme),
                context.mediumSpace,
                if (!isProfileComplete) ...[
                  _buildAIRecommendationCard(context, isDark, textTheme),
                  context.mediumSpace,
                ],
                // Quick Actions label - Responsive
                context.text(
                  'Quick Actions',
                  style: textTheme.title1Medium.copyWith(
                    color: isDark ? AppColors.grey100 : AppColors.blue900,
                  ),
                ),
                SizedBox(height: context.h(16)),
                // Grid of cards
                Column(
                  children: [
                    for (int i = 0; i < items.length; i += crossAxisCount)
                      Padding(
                        padding: EdgeInsets.only(bottom: context.h(12)),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (int j = 0; j < crossAxisCount; j++) ...[
                              if (j > 0) SizedBox(width: context.w(12)),
                              if (i + j < items.length)
                                Expanded(
                                  child: _QuickActionCard(
                                    item: items[i + j],
                                    isDark: isDark,
                                    textTheme: textTheme,
                                    onTap: () =>
                                        context.push(items[i + j].route),
                                  ),
                                )
                              else
                                const Expanded(child: SizedBox()),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, user, bool isDark, AppTextTheme textTheme) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              context.text(
                'Hi, ${user?.username ?? 'User'}',
                style: textTheme.title1Bold.copyWith(
                  color: isDark ? AppColors.grey100 : AppColors.blue900,
                ),
              ),
              SizedBox(height: context.h(4)),
              context.text(
                "Let's build your career with AI",
                style: textTheme.title2Medium.copyWith(
                  color: isDark ? AppColors.blue200 : AppColors.grey800,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: context.w(12)),
        _buildAvatar(context, user, isDark, textTheme),
      ],
    );
  }

  Widget _buildAvatar(
      BuildContext context, user, bool isDark, AppTextTheme textTheme) {
    final avatarSize = context.icon(50);
    final borderRadius = context.r(24);

    return GestureDetector(
      onTap: () => context.push('/settings'),
      child: Container(
        width: avatarSize,
        height: avatarSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: AppColors.lightBlue700,
            width: context.isMobile ? 2 : 3,
          ),
          image: user?.avatarUrl != null
              ? DecorationImage(
                  image: NetworkImage(user!.avatarUrl!),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: user?.avatarUrl == null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(borderRadius),
                child: ColoredBox(
                  color: AppColors.lightBlue700.withOpacity(0.2),
                  child: Center(
                    child: Text(
                      user?.username?.isNotEmpty == true
                          ? user!.username![0].toUpperCase()
                          : 'M',
                      style: context.responsiveText(
                        textTheme.title1Bold.copyWith(
                          fontSize: avatarSize * 0.38,
                          color: AppColors.lightBlue700,
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildAIRecommendationCard(
      BuildContext context, bool isDark, AppTextTheme textTheme) {
    final tealColor = isDark ? AppColors.lightBlue500 : AppColors.lightBlue700;
    final cardColor = isDark ? AppColors.blue700 : AppColors.grey50;
    final borderColor =
        isDark ? AppColors.lightBlue500 : AppColors.lightBlue700;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final leftOffset = totalWidth * (28.0 / 348.0);

        return Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(context.r(8)),
                child: Container(color: tealColor),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(left: leftOffset),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(context.w(12)),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(context.r(8)),
                  border: Border.all(color: borderColor, width: 1),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 4,
                      spreadRadius: 0,
                      offset: Offset(4, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    context.text(
                      'AI Recommendation',
                      style: textTheme.title2Bold.copyWith(
                        color: isDark ? AppColors.grey100 : AppColors.blue900,
                      ),
                    ),
                    SizedBox(height: context.h(8)),
                    context.text(
                      'Complete your profile to get better job matches',
                      style: textTheme.bodyMedium.copyWith(
                        color: isDark ? AppColors.blue200 : AppColors.grey800,
                      ),
                      maxLines: 2,
                    ),
                    SizedBox(height: context.h(12)),
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () => context.push(
                          '/profile-information',
                          extra: {'fromHome': true},
                        ),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: context.w(20),
                            vertical: context.h(7),
                          ),
                          decoration: BoxDecoration(
                            color: tealColor,
                            borderRadius: BorderRadius.circular(context.r(50)),
                          ),
                          child: context.text(
                            'Start now',
                            style: textTheme.bodyBold.copyWith(
                              color:
                                  isDark ? AppColors.blue700 : AppColors.grey50,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Data Model ──────────────────────────────────────────────────────────────

class _QuickActionItem {
  final String imagePath;
  final String title;
  final String subtitle;
  final String route;

  const _QuickActionItem({
    required this.imagePath,
    required this.title,
    required this.subtitle,
    required this.route,
  });
}

// ── Quick Action Card ────────────────────────────────────────────────────────

class _QuickActionCard extends StatelessWidget {
  final _QuickActionItem item;
  final bool isDark;
  final AppTextTheme textTheme;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.item,
    required this.isDark,
    required this.textTheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final padding = context.w(13);
    final radius = context.r(8);
    final imageSize = context.w(40).clamp(36.0, 56.0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: isDark ? AppColors.blue700 : AppColors.grey50,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: isDark ? AppColors.grey300 : AppColors.grey900,
            width: isDark ? 0.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? const Color(0x40868686) : const Color(0x40000000),
              blurRadius: context.r(4),
              spreadRadius: 0,
              offset: Offset(context.r(4), context.r(4)),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image بدل الـ Icon Container
            SizedBox(
              width: imageSize,
              height: imageSize,
              child: Image.asset(
                item.imagePath,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: imageSize,
                  height: imageSize,
                  decoration: BoxDecoration(
                    color: AppColors.lightBlue700.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(radius),
                  ),
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: AppColors.lightBlue700,
                    size: imageSize * 0.55,
                  ),
                ),
              ),
            ),
            SizedBox(height: context.h(15)),
            // Title
            context.text(
              item.title,
              style: textTheme.title2Bold.copyWith(
                color: isDark ? AppColors.textDark : AppColors.blue900,
              ),
              maxLines: 1,
            ),
            SizedBox(height: context.h(10)),
            // Subtitle
            context.text(
              item.subtitle,
              style: textTheme.bodyMedium.copyWith(
                color: isDark ? AppColors.grey300 : AppColors.grey900,
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

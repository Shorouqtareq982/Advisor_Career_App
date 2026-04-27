// lib/features/job_matching/presentation/screens/recommended_jobs_screen.dart
//
// التغيير الوحيد من النسخة السابقة:
// بيعمل setUserId على الـ provider بعد التحميل عشان يعزل البيانات per-user

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../../../../core/theme/app_text_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../home/presentation/widgets/home_bottom_nav.dart';
import '../../domain/entities/job_entity.dart';
import '../providers/job_matching_provider.dart';
import '../widgets/job_card.dart';

class RecommendedJobsScreen extends ConsumerStatefulWidget {
  const RecommendedJobsScreen({super.key});

  @override
  ConsumerState<RecommendedJobsScreen> createState() =>
      _RecommendedJobsScreenState();
}

class _RecommendedJobsScreenState extends ConsumerState<RecommendedJobsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    // ← المهم: نعطي الـ provider الـ userId الحالي قبل أي حاجة
    final userId = ref.read(authProvider).user?.id;
    if (userId != null) {
      ref.read(jobMatchingProvider.notifier).setUserId(userId);
    }
    ref.read(jobMatchingProvider.notifier).loadRecommendedJobs();
    ref.read(jobMatchingProvider.notifier).loadSavedJobs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openDetails(JobEntity job) {
    ref.read(jobMatchingProvider.notifier).markJobSeen(job.id);
    context.push('/job-details', extra: job);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = context.appTextTheme;
    final jobState = ref.watch(jobMatchingProvider);

    final bg = isDark ? AppColors.blue900 : AppColors.grey100;
    final primary = isDark ? AppColors.grey50 : AppColors.blue900;
    final accent = isDark ? AppColors.lightBlue500 : AppColors.lightBlue700;

    return Scaffold(
      backgroundColor: bg,
      bottomNavigationBar: const HomeBottomNav(currentRoute: '/jobs'),
      body: SafeArea(
        child: Column(
          children: [
            // ── App bar ──────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: context.w(16), vertical: context.h(12)),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Icon(Icons.arrow_back_ios_new,
                        color: primary, size: context.icon(20)),
                  ),
                  const Spacer(),
                  Image.asset(
                    'assets/images/branding/growza_logo.png',
                    width: context.w(40),
                    height: context.h(40),
                    fit: BoxFit.contain,
                  ),
                  const Spacer(),
                  // Filter icon → job preferences
                  GestureDetector(
                    onTap: () => context.push(
                      '/job-preferences',
                      extra: {'fromJobMatching': false},
                    ),
                    child: Icon(Icons.tune,
                        color: primary, size: context.icon(22)),
                  ),
                ],
              ),
            ),

            // ── Title ────────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.only(bottom: context.h(8)),
              child: Text(
                'Recommended Jobs',
                style: textTheme.title1Bold.copyWith(color: primary),
              ),
            ),

            // ── Tab bar ──────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.w(16)),
              child: TabBar(
                controller: _tabController,
                indicator: UnderlineTabIndicator(
                  borderSide: BorderSide(width: 2.5, color: accent),
                  insets: EdgeInsets.zero,
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: accent,
                unselectedLabelColor:
                    isDark ? AppColors.grey400 : AppColors.grey600,
                labelStyle: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: context.sp(14),
                    fontWeight: FontWeight.w600),
                unselectedLabelStyle: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: context.sp(14),
                    fontWeight: FontWeight.w400),
                dividerColor: isDark ? AppColors.blue400 : AppColors.grey300,
                tabs: const [
                  Tab(text: 'Recommended'),
                  Tab(text: 'Saved'),
                ],
              ),
            ),

            SizedBox(height: context.h(4)),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Recommended
                  _JobsList(
                    jobs: jobState.recommendedJobs,
                    status: jobState.recommendedStatus,
                    showRating: true,
                    emptyTitle: 'No recommendations yet.',
                    emptySubtitle: 'Complete your preferences to get started.',
                    onViewDetails: _openDetails,
                    onToggleSave: (id) =>
                        ref.read(jobMatchingProvider.notifier).toggleSave(id),
                    onRate: (id, r) => ref
                        .read(jobMatchingProvider.notifier)
                        .rateJob(jobId: id, rating: r),
                    onRefresh: () => ref
                        .read(jobMatchingProvider.notifier)
                        .loadRecommendedJobs(),
                    isDark: isDark,
                  ),
                  // Saved
                  _JobsList(
                    jobs: jobState.savedJobs,
                    status: jobState.savedStatus,
                    showRating: false,
                    emptyTitle: "You haven't saved any jobs yet.",
                    emptySubtitle:
                        'Tap the save icon on any job to keep your favorites!',
                    emptyIcon: Icons.bookmark_border,
                    onViewDetails: _openDetails,
                    onToggleSave: (id) =>
                        ref.read(jobMatchingProvider.notifier).toggleSave(id),
                    onRate: (_, __) {},
                    onRefresh: () =>
                        ref.read(jobMatchingProvider.notifier).loadSavedJobs(),
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Generic jobs list ────────────────────────────────────────────────────────

class _JobsList extends StatelessWidget {
  final List<JobEntity> jobs;
  final JobMatchingStatus status;
  final bool showRating;
  final String emptyTitle;
  final String emptySubtitle;
  final IconData emptyIcon;
  final ValueChanged<JobEntity> onViewDetails;
  final ValueChanged<String> onToggleSave;
  final void Function(String, int) onRate;
  final Future<void> Function() onRefresh;
  final bool isDark;

  const _JobsList({
    required this.jobs,
    required this.status,
    required this.showRating,
    required this.emptyTitle,
    required this.emptySubtitle,
    this.emptyIcon = Icons.work_off_outlined,
    required this.onViewDetails,
    required this.onToggleSave,
    required this.onRate,
    required this.onRefresh,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (status == JobMatchingStatus.loading) {
      return Center(
        child: CircularProgressIndicator(
          color: isDark ? AppColors.lightBlue500 : AppColors.lightBlue700,
        ),
      );
    }

    if (jobs.isEmpty) {
      final textMuted = isDark ? AppColors.grey400 : AppColors.grey700;
      final textPrimary = isDark ? AppColors.grey50 : AppColors.blue900;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: context.w(72),
              height: context.w(72),
              decoration: BoxDecoration(
                color: isDark ? AppColors.blue700 : AppColors.grey200,
                shape: BoxShape.circle,
              ),
              child: Icon(emptyIcon, color: textMuted, size: context.icon(32)),
            ),
            SizedBox(height: context.h(16)),
            Text(emptyTitle,
                style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: context.sp(16),
                    fontWeight: FontWeight.w700,
                    color: textPrimary)),
            SizedBox(height: context.h(8)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.w(32)),
              child: Text(
                emptySubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: context.sp(13),
                    color: textMuted),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(
            horizontal: context.w(16), vertical: context.h(12)),
        itemCount: jobs.length,
        itemBuilder: (_, i) => JobCard(
          job: jobs[i],
          showRating: showRating,
          onViewDetails: () => onViewDetails(jobs[i]),
          onToggleSave: () => onToggleSave(jobs[i].id),
          onRate: (r) => onRate(jobs[i].id, r),
        ),
      ),
    );
  }
}

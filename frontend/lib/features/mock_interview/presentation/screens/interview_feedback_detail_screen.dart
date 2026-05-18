import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../../../../core/theme/app_text_theme.dart';
import '../../domain/entities/interview_entities.dart';
import '../providers/mock_interview_provider.dart';

class InterviewFeedbackDetailScreen extends ConsumerStatefulWidget {
  final String sessionId;

  const InterviewFeedbackDetailScreen({super.key, required this.sessionId});

  @override
  ConsumerState<InterviewFeedbackDetailScreen> createState() =>
      _InterviewFeedbackDetailScreenState();
}

class _InterviewFeedbackDetailScreenState
    extends ConsumerState<InterviewFeedbackDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentDetail = ref.read(mockInterviewProvider).feedbackDetail;
      if (currentDetail?.sessionId != widget.sessionId) {
        ref
            .read(mockInterviewProvider.notifier)
            .loadFeedbackDetail(widget.sessionId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(mockInterviewProvider);
    final detail = state.feedbackDetail;
    final hasReport = detail != null &&
        (detail.strongPoints.isNotEmpty ||
            detail.areasForImprovement.isNotEmpty ||
            detail.suggestions.isNotEmpty);
    final bgColor = isDark ? AppColors.blue900 : AppColors.grey100;
    final textPrimary = isDark ? AppColors.grey50 : AppColors.blue900;
    final textTheme = context.appTextTheme;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: state.isLoadingDetail
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.lightBlue500))
            : state.feedbackDetail == null
                ? _buildError(context, textTheme, textPrimary)
                : CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      // AppBar
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: context.w(8), vertical: context.h(8)),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: () => context.pop(),
                                icon: Icon(Icons.arrow_back_ios_new_rounded,
                                    color: textPrimary, size: context.icon(20)),
                              ),
                              Expanded(
                                child: Center(
                                  child: Image.asset(
                                    'assets/images/branding/growza_logo.png',
                                    width: context.logo(40),
                                    height: context.logo(40),
                                    errorBuilder: (_, __, ___) => Icon(
                                        Icons.shield_outlined,
                                        color: AppColors.lightBlue500,
                                        size: context.icon(40)),
                                  ),
                                ),
                              ),
                              SizedBox(width: context.w(48)),
                            ],
                          ),
                        ),
                      ),

                      SliverPadding(
                        padding:
                            EdgeInsets.symmetric(horizontal: context.w(20)),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            // Summary card
                            _buildSummaryCard(context, isDark, textTheme),
                            SizedBox(height: context.h(16)),

                            // → pending state
                            if (!hasReport)
                              _buildPendingState(context, isDark, textTheme),

                            //  sections
                            if (hasReport) ...[
                              // Strengths
                              _buildSection(
                                context: context,
                                isDark: isDark,
                                textTheme: textTheme,
                                title: 'Strengths',
                                titleColor: AppColors.green500,
                                icon: Icons.check_circle_outline_rounded,
                                items: state.feedbackDetail!.strongPoints,
                              ),
                              SizedBox(height: context.h(16)),

                              // Weaknesses
                              _buildSection(
                                context: context,
                                isDark: isDark,
                                textTheme: textTheme,
                                title: 'Weaknesses',
                                titleColor: AppColors.orange500,
                                icon: Icons.info_outline_rounded,
                                items:
                                    state.feedbackDetail!.areasForImprovement,
                              ),
                              SizedBox(height: context.h(16)),

                              // Suggestions
                              _buildSuggestions(context, isDark, textTheme),
                            ],

                            SizedBox(height: context.h(24)),
                          ]),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  // ── Pending State ────────────────────────────────────

  Widget _buildPendingState(
      BuildContext context, bool isDark, AppTextTheme textTheme) {
    final textPrimary = isDark ? AppColors.grey50 : AppColors.blue900;
    final textMuted = isDark ? AppColors.grey400 : AppColors.grey800;
    final iconBg = isDark
        ? AppColors.lightBlue500.withOpacity(0.1)
        : AppColors.lightBlue100;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.h(40)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: context.w(80),
            height: context.w(80),
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(Icons.hourglass_top_rounded,
                color: AppColors.lightBlue500, size: context.icon(40)),
          ),
          SizedBox(height: context.h(20)),
          context.text(
            'Feedback is being prepared',
            style: textTheme.title2Bold.copyWith(color: textPrimary),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: context.h(8)),
          context.text(
            "We're still analyzing your interview.\nYou'll receive a notification once it's ready.",
            style: textTheme.bodyRegular.copyWith(color: textMuted),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: context.h(24)),
          ElevatedButton.icon(
            onPressed: () => ref
                .read(mockInterviewProvider.notifier)
                .loadFeedbackDetail(widget.sessionId),
            icon: Icon(Icons.refresh_rounded, size: context.icon(18)),
            label: const Text('Check Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.lightBlue500,
              foregroundColor: AppColors.blue900,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(context.r(50)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Error ──────────────────────────────────────────────────────────────────

  Widget _buildError(
      BuildContext context, AppTextTheme textTheme, Color textPrimary) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline,
              color: AppColors.red600, size: context.icon(48)),
          SizedBox(height: context.h(16)),
          context.text('Failed to load feedback',
              style: textTheme.title2Bold.copyWith(color: textPrimary)),
          SizedBox(height: context.h(16)),
          ElevatedButton(
            onPressed: () => ref
                .read(mockInterviewProvider.notifier)
                .loadFeedbackDetail(widget.sessionId),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // ── Summary Card  ──────────────────────────────────────────────

  Widget _buildSummaryCard(
      BuildContext context, bool isDark, AppTextTheme textTheme) {
    final detail = ref.watch(mockInterviewProvider).feedbackDetail!;
    final cardColor = isDark ? AppColors.blue700 : AppColors.grey50;
    final borderColor =
        isDark ? AppColors.blue400.withOpacity(0.3) : AppColors.grey300;
    final textPrimary = isDark ? AppColors.grey50 : AppColors.blue900;
    final dateColor = isDark ? AppColors.grey300 : AppColors.grey700;
    final isBehavioral = detail.sessionType == InterviewSessionType.behavioral;

    return Container(
      padding: EdgeInsets.all(context.w(16)),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(context.r(12)),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: context.text(
                  detail.roleName,
                  style: textTheme.title2Bold.copyWith(color: textPrimary),
                ),
              ),
              // Session type badge
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: context.w(10), vertical: context.h(4)),
                decoration: BoxDecoration(
                  color: isBehavioral
                      ? AppColors.lightBlue500.withOpacity(0.15)
                      : AppColors.purple500.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(context.r(20)),
                ),
                child: context.text(
                  isBehavioral ? 'Behavioral' : 'Technical',
                  style: textTheme.captionBold.copyWith(
                    color: isBehavioral
                        ? AppColors.lightBlue500
                        : AppColors.purple500,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: context.h(8)),
          Row(
            children: [
              Icon(Icons.calendar_today_outlined,
                  color: dateColor, size: context.icon(13)),
              SizedBox(width: context.w(4)),
              context.text(
                DateFormat('MMMM d, y').format(detail.createdAt),
                style: textTheme.captionRegular.copyWith(color: dateColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Section (Strengths / Weaknesses) ──────────────────────────────────────

  Widget _buildSection({
    required BuildContext context,
    required bool isDark,
    required AppTextTheme textTheme,
    required String title,
    required Color titleColor,
    required IconData icon,
    required List<String> items,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    final cardColor = isDark ? AppColors.blue700 : AppColors.grey50;
    final borderColor =
        isDark ? AppColors.blue400.withOpacity(0.3) : AppColors.grey300;
    final textMuted = isDark ? AppColors.blue200 : AppColors.grey800;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.w(16)),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(context.r(12)),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: titleColor, size: context.icon(16)),
              SizedBox(width: context.w(6)),
              context.text(title,
                  style: textTheme.title2Bold.copyWith(color: titleColor)),
            ],
          ),
          SizedBox(height: context.h(12)),
          ...items.map((item) => Padding(
                padding: EdgeInsets.only(bottom: context.h(8)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: context.h(4)),
                      child: Container(
                        width: context.w(5),
                        height: context.w(5),
                        decoration: BoxDecoration(
                            color: textMuted, shape: BoxShape.circle),
                      ),
                    ),
                    SizedBox(width: context.w(8)),
                    Expanded(
                      child: context.text(item,
                          style:
                              textTheme.bodyRegular.copyWith(color: textMuted)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ── Suggestions ────────────────────────────────────────────────────────────

  Widget _buildSuggestions(
      BuildContext context, bool isDark, AppTextTheme textTheme) {
    final detail = ref.watch(mockInterviewProvider).feedbackDetail!;
    if (detail.suggestions.isEmpty) return const SizedBox.shrink();

    final cardColor = isDark ? AppColors.blue700 : AppColors.grey50;
    final borderColor =
        isDark ? AppColors.blue400.withOpacity(0.3) : AppColors.grey300;
    final accentColor =
        isDark ? AppColors.lightBlue400 : AppColors.lightBlue700;
    final textMuted = isDark ? AppColors.blue200 : AppColors.grey800;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.w(16)),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(context.r(12)),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded,
                  color: accentColor, size: context.icon(16)),
              SizedBox(width: context.w(6)),
              context.text('Suggestions',
                  style: textTheme.title2Bold.copyWith(color: accentColor)),
            ],
          ),
          SizedBox(height: context.h(12)),
          // Suggestions كـ bullet points
          ...detail.suggestions.split('\n').where((s) => s.isNotEmpty).map(
                (item) => Padding(
                  padding: EdgeInsets.only(bottom: context.h(8)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: context.h(4)),
                        child: Container(
                          width: context.w(5),
                          height: context.w(5),
                          decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.6),
                              shape: BoxShape.circle),
                        ),
                      ),
                      SizedBox(width: context.w(8)),
                      Expanded(
                        child: context.text(item,
                            style: textTheme.bodyRegular
                                .copyWith(color: textMuted)),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

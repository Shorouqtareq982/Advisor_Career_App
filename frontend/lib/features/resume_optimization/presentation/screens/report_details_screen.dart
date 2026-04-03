import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../../../../core/theme/app_text_theme.dart';
import '../../domain/entities/resume_report_entity.dart';
import '../providers/resume_optimization_provider.dart';

class ReportDetailsScreen extends ConsumerStatefulWidget {
  final String reportId;
  const ReportDetailsScreen({super.key, required this.reportId});

  @override
  ConsumerState<ReportDetailsScreen> createState() =>
      _ReportDetailsScreenState();
}

class _ReportDetailsScreenState extends ConsumerState<ReportDetailsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(resumeOptimizationProvider.notifier).loadReport(widget.reportId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(resumeOptimizationProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = context.appTextTheme;
    final bgColor = isDark ? AppColors.blue900 : AppColors.grey100;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: state.isLoadingReport
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.lightBlue500))
            : state.currentReport == null
                ? _buildError(context, isDark, textTheme)
                : _buildContent(
                    context, state.currentReport!, isDark, textTheme),
      ),
    );
  }

  Widget _buildError(
      BuildContext context, bool isDark, AppTextTheme textTheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline,
              color: AppColors.red600, size: context.icon(48)),
          SizedBox(height: context.h(16)),
          context.text('Failed to load report',
              style: textTheme.title2Bold.copyWith(
                  color: isDark ? AppColors.grey100 : AppColors.blue900)),
          SizedBox(height: context.h(16)),
          ElevatedButton(
            onPressed: () => ref
                .read(resumeOptimizationProvider.notifier)
                .loadReport(widget.reportId),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, ResumeReportEntity report,
      bool isDark, AppTextTheme textTheme) {
    final textPrimary = isDark ? AppColors.grey100 : AppColors.blue900;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // App Bar
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
                      errorBuilder: (_, __, ___) => Icon(Icons.shield_outlined,
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
          padding: EdgeInsets.symmetric(horizontal: context.w(20)),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _SummaryCard(
                  report: report, isDark: isDark, textTheme: textTheme),
              SizedBox(height: context.h(16)),
              _SectionInsightsCard(
                  report: report, isDark: isDark, textTheme: textTheme),
              SizedBox(height: context.h(16)),
              if (report.jobAlignment != null) ...[
                _JobMatchingCard(
                    alignment: report.jobAlignment!,
                    isDark: isDark,
                    textTheme: textTheme),
                SizedBox(height: context.h(16)),
              ],
              _IndustryKeywordsCard(
                  keyword: report.industryKeyword,
                  isDark: isDark,
                  textTheme: textTheme),
              SizedBox(height: context.h(16)),
              if (report.atsIssues.isNotEmpty) ...[
                _IssuesCard(
                    issues: report.atsIssues,
                    isDark: isDark,
                    textTheme: textTheme),
                SizedBox(height: context.h(16)),
              ],
              if (report.improvementTips.isNotEmpty) ...[
                _ImprovementTipsCard(
                    tips: report.improvementTips,
                    isDark: isDark,
                    textTheme: textTheme),
                SizedBox(height: context.h(24)),
              ],
            ]),
          ),
        ),
      ],
    );
  }
}

// ─── Summary Card ─────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final ResumeReportEntity report;
  final bool isDark;
  final AppTextTheme textTheme;

  const _SummaryCard(
      {required this.report, required this.isDark, required this.textTheme});

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? AppColors.blue700 : AppColors.grey50;
    final borderColor =
        isDark ? AppColors.blue400.withOpacity(0.3) : AppColors.grey300;
    final textPrimary = isDark ? AppColors.grey100 : AppColors.blue900;
    final scoreColor = isDark ? AppColors.grey100 : AppColors.blue900;
    final dateColor = isDark ? AppColors.grey300 : AppColors.grey700;

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
          context.text(report.cvName,
              style: textTheme.title2Bold.copyWith(color: textPrimary)),
          SizedBox(height: context.h(10)),

          // Scores
          _ScoreRow(
            scores: [
              ('ATS Score:', '${report.atsScore} %'),
            ],
            scoreColor: scoreColor,
            textTheme: textTheme,
          ),
          SizedBox(height: context.h(4)),
          _ScoreRow(
            scores: [
              ('Quality Score:', '${report.contentQualityScore} %'),
              if (report.jobMatchScore != null)
                ('Job Match Score:', '${report.jobMatchScore} %'),
            ],
            scoreColor: scoreColor,
            textTheme: textTheme,
          ),
          SizedBox(height: context.h(10)),

          // Date with custom icon
          Row(
            children: [
              ColorFiltered(
                colorFilter: ColorFilter.mode(dateColor, BlendMode.srcIn),
                child: Image.asset(
                  'assets/icons/icon_calendar.png',
                  width: context.icon(14),
                  height: context.icon(14),
                ),
              ),
              SizedBox(width: context.w(4)),
              context.text(
                DateFormat('MMMM d, y').format(report.createdAt),
                style: textTheme.captionRegular.copyWith(color: dateColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final List<(String, String)> scores;
  final Color scoreColor;
  final AppTextTheme textTheme;

  const _ScoreRow({
    required this.scores,
    required this.scoreColor,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: scores.map((s) {
        return Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '${s.$1} ',
                  style: context.responsiveText(
                      textTheme.bodyRegular.copyWith(color: scoreColor)),
                ),
                TextSpan(
                  text: s.$2,
                  style: context.responsiveText(
                      textTheme.bodyBold.copyWith(color: scoreColor)),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Section Insights Card ────────────────────────────────────────────────────

class _SectionInsightsCard extends StatelessWidget {
  final ResumeReportEntity report;
  final bool isDark;
  final AppTextTheme textTheme;

  const _SectionInsightsCard(
      {required this.report, required this.isDark, required this.textTheme});

  @override
  Widget build(BuildContext context) {
    final s = report.sectionAnalysis;
    final sections = [
      ('Contact Information', s.contactInfo),
      ('Work Experience', s.workExperience),
      ('Education', s.education),
      ('Skills', s.skills),
      ('Additional Sections', s.additionalSections),
    ];

    return _InfoCard(
      isDark: isDark,
      title: 'Section Insights',
      titleColor: isDark ? AppColors.grey100 : AppColors.blue900,
      child: Column(
        children: sections
            .map((item) => _SectionItem(
                  title: item.$1,
                  passNotes: item.$2,
                  isDark: isDark,
                  textTheme: textTheme,
                ))
            .toList(),
      ),
    );
  }
}

class _SectionItem extends StatelessWidget {
  final String title;
  final PassNotesEntity passNotes;
  final bool isDark;
  final AppTextTheme textTheme;

  const _SectionItem({
    required this.title,
    required this.passNotes,
    required this.isDark,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark ? AppColors.grey100 : AppColors.blue900;
    final textMuted = isDark ? AppColors.blue200 : AppColors.grey800;
    final iconColor = passNotes.pass ? AppColors.green600 : AppColors.orange600;
    final icon =
        passNotes.pass ? Icons.check_circle_outline : Icons.info_outline;

    return Padding(
      padding: EdgeInsets.only(bottom: context.h(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: context.icon(18)),
          SizedBox(width: context.w(8)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                context.text(title,
                    style: textTheme.bodyBold.copyWith(color: textPrimary)),
                SizedBox(height: context.h(2)),
                context.text(passNotes.notes,
                    style: textTheme.captionRegular.copyWith(color: textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Job Matching Card ────────────────────────────────────────────────────────

class _JobMatchingCard extends StatelessWidget {
  final JobAlignmentEntity alignment;
  final bool isDark;
  final AppTextTheme textTheme;

  const _JobMatchingCard({
    required this.alignment,
    required this.isDark,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      isDark: isDark,
      title: 'Job Matching',
      titleColor: isDark ? AppColors.grey100 : AppColors.blue900,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MatchSection(
            heading: 'Skills Overview:',
            matchedLabel: 'You already have:',
            matchedItems: alignment.matchedSkills,
            missingLabel: 'Consider adding:',
            missingItems: alignment.missingSkills,
            isDark: isDark,
            textTheme: textTheme,
          ),
          SizedBox(height: context.h(12)),
          Divider(
              color: isDark
                  ? AppColors.blue400.withOpacity(0.3)
                  : AppColors.grey300),
          SizedBox(height: context.h(12)),
          _MatchSection(
            heading: 'Experience Overview:',
            matchedLabel: 'You have experience in',
            matchedItems: alignment.matchedExperience,
            missingLabel: 'Consider adding experience in',
            missingItems: alignment.missingExperience,
            isDark: isDark,
            textTheme: textTheme,
          ),
          SizedBox(height: context.h(12)),
          Divider(
              color: isDark
                  ? AppColors.blue400.withOpacity(0.3)
                  : AppColors.grey300),
          SizedBox(height: context.h(12)),
          _MatchSection(
            heading: 'Keyword Analysis:',
            matchedLabel: 'You already have:',
            matchedItems: alignment.matchedKeywords,
            missingLabel: 'Consider adding:',
            missingItems: alignment.missingKeywords,
            isDark: isDark,
            textTheme: textTheme,
          ),
        ],
      ),
    );
  }
}

class _MatchSection extends StatelessWidget {
  final String heading;
  final String matchedLabel;
  final List<String> matchedItems;
  final String missingLabel;
  final List<String> missingItems;
  final bool isDark;
  final AppTextTheme textTheme;

  const _MatchSection({
    required this.heading,
    required this.matchedLabel,
    required this.matchedItems,
    required this.missingLabel,
    required this.missingItems,
    required this.isDark,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark ? AppColors.grey100 : AppColors.blue900;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        context.text(heading,
            style: textTheme.bodyBold.copyWith(color: textPrimary)),
        SizedBox(height: context.h(6)),
        if (matchedItems.isNotEmpty) ...[
          Row(
            children: [
              Icon(Icons.check_circle_outline,
                  color: AppColors.green600, size: context.icon(14)),
              SizedBox(width: context.w(4)),
              context.text(matchedLabel,
                  style: textTheme.captionBold
                      .copyWith(color: AppColors.green600)),
            ],
          ),
          SizedBox(height: context.h(4)),
          context.text(
            matchedItems.join(', '),
            style: textTheme.captionRegular.copyWith(
                color: isDark ? AppColors.grey300 : AppColors.grey800),
          ),
          SizedBox(height: context.h(8)),
        ],
        if (missingItems.isNotEmpty) ...[
          Row(
            children: [
              Icon(Icons.info_outline,
                  color: AppColors.orange600, size: context.icon(14)),
              SizedBox(width: context.w(4)),
              context.text(missingLabel,
                  style: textTheme.captionBold
                      .copyWith(color: AppColors.orange600)),
            ],
          ),
          SizedBox(height: context.h(4)),
          ...missingItems.map((item) => Padding(
                padding:
                    EdgeInsets.only(left: context.w(8), bottom: context.h(3)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    context.text('• ',
                        style: textTheme.captionRegular.copyWith(
                            color: isDark
                                ? AppColors.grey400
                                : AppColors.grey800)),
                    Expanded(
                      child: context.text(item,
                          style: textTheme.captionRegular.copyWith(
                              color: isDark
                                  ? AppColors.grey400
                                  : AppColors.grey800)),
                    ),
                  ],
                ),
              )),
        ],
      ],
    );
  }
}

// ─── Industry Keywords Card ───────────────────────────────────────────────────

class _IndustryKeywordsCard extends StatelessWidget {
  final IndustryKeywordEntity keyword;
  final bool isDark;
  final AppTextTheme textTheme;

  const _IndustryKeywordsCard({
    required this.keyword,
    required this.isDark,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark ? AppColors.grey100 : AppColors.blue900;
    final accentColor =
        isDark ? AppColors.lightBlue400 : AppColors.lightBlue700;

    return _InfoCard(
      isDark: isDark,
      title: 'Industry Keyword Optimization',
      titleColor: accentColor,
      svgIcon: 'assets/icons/icon_keyword.png',
      svgIconColor: accentColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (keyword.recommendedKeywords.isNotEmpty) ...[
            context.text('Recommended Keywords:',
                style: textTheme.bodyBold.copyWith(color: textPrimary)),
            SizedBox(height: context.h(8)),
            ...keyword.recommendedKeywords.map((kw) =>
                _BulletItem(text: kw, isDark: isDark, textTheme: textTheme)),
          ],
          if (keyword.suggestions.isNotEmpty) ...[
            SizedBox(height: context.h(12)),
            Divider(
                color: isDark
                    ? AppColors.blue400.withOpacity(0.3)
                    : AppColors.grey300),
            SizedBox(height: context.h(12)),
            context.text('Actionable Suggestions',
                style: textTheme.bodyBold.copyWith(color: textPrimary)),
            SizedBox(height: context.h(8)),
            ...keyword.suggestions.map((s) =>
                _BulletItem(text: s, isDark: isDark, textTheme: textTheme)),
          ],
        ],
      ),
    );
  }
}

// ─── Issues Card ──────────────────────────────────────────────────────────────

class _IssuesCard extends StatelessWidget {
  final List<String> issues;
  final bool isDark;
  final AppTextTheme textTheme;

  const _IssuesCard(
      {required this.issues, required this.isDark, required this.textTheme});

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      isDark: isDark,
      title: 'Resume Issues',
      titleColor: AppColors.red500,
      iconData: Icons.error_outline_rounded,
      child: Column(
        children: issues
            .map((i) =>
                _BulletItem(text: i, isDark: isDark, textTheme: textTheme))
            .toList(),
      ),
    );
  }
}

// ─── Improvement Tips Card ────────────────────────────────────────────────────

class _ImprovementTipsCard extends StatelessWidget {
  final List<String> tips;
  final bool isDark;
  final AppTextTheme textTheme;

  const _ImprovementTipsCard(
      {required this.tips, required this.isDark, required this.textTheme});

  @override
  Widget build(BuildContext context) {
    final accentColor =
        isDark ? AppColors.lightBlue400 : AppColors.lightBlue700;

    return _InfoCard(
      isDark: isDark,
      title: 'Improvement Suggestions',
      titleColor: accentColor,
      svgIcon: 'assets/icons/icon_improvement.png',
      svgIconColor: accentColor,
      child: Column(
        children: tips
            .map((t) =>
                _BulletItem(text: t, isDark: isDark, textTheme: textTheme))
            .toList(),
      ),
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final bool isDark;
  final String title;
  final Color titleColor;
  final Widget child;
  // Use either svgIcon or iconData
  final String? svgIcon;
  final Color? svgIconColor;
  final IconData? iconData;

  const _InfoCard({
    required this.isDark,
    required this.title,
    required this.titleColor,
    required this.child,
    this.svgIcon,
    this.svgIconColor,
    this.iconData,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? AppColors.blue700 : AppColors.grey50;
    final borderColor =
        isDark ? AppColors.blue400.withOpacity(0.3) : AppColors.grey300;
    final textTheme = context.appTextTheme;

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
              if (svgIcon != null) ...[
                ColorFiltered(
                  colorFilter: ColorFilter.mode(
                      svgIconColor ?? titleColor, BlendMode.srcIn),
                  child: Image.asset(
                    svgIcon!,
                    width: context.icon(16),
                    height: context.icon(16),
                  ),
                ),
                SizedBox(width: context.w(6)),
              ] else if (iconData != null) ...[
                Icon(iconData, color: titleColor, size: context.icon(16)),
                SizedBox(width: context.w(6)),
              ],
              Expanded(
                child: context.text(title,
                    style: textTheme.title2Bold.copyWith(color: titleColor)),
              ),
            ],
          ),
          SizedBox(height: context.h(14)),
          child,
        ],
      ),
    );
  }
}

class _BulletItem extends StatelessWidget {
  final String text;
  final bool isDark;
  final AppTextTheme textTheme;

  const _BulletItem(
      {required this.text, required this.isDark, required this.textTheme});

  @override
  Widget build(BuildContext context) {
    final textMuted = isDark ? AppColors.blue200 : AppColors.grey800;
    final bulletColor = isDark ? AppColors.grey100 : AppColors.blue900;

    return Padding(
      padding: EdgeInsets.only(bottom: context.h(6)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: context.h(2)),
            child: Container(
              width: context.w(5),
              height: context.w(5),
              decoration:
                  BoxDecoration(color: bulletColor, shape: BoxShape.circle),
            ),
          ),
          SizedBox(width: context.w(8)),
          Expanded(
            child: context.text(text,
                style: textTheme.captionRegular.copyWith(color: textMuted)),
          ),
        ],
      ),
    );
  }
}

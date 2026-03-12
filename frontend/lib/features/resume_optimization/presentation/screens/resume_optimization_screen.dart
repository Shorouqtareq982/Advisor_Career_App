import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../../../../core/theme/app_text_theme.dart';
import '../../../home/presentation/widgets/home_bottom_nav.dart';
import '../../domain/entities/resume_report_entity.dart';
import '../providers/resume_optimization_provider.dart';
import '../widgets/optimization_upload_dialog.dart';
import '../widgets/delete_confirmation_dialog.dart';

class ResumeOptimizationScreen extends ConsumerStatefulWidget {
  const ResumeOptimizationScreen({super.key});

  @override
  ConsumerState<ResumeOptimizationScreen> createState() =>
      _ResumeOptimizationScreenState();
}

class _ResumeOptimizationScreenState
    extends ConsumerState<ResumeOptimizationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(resumeOptimizationProvider.notifier).loadReports();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(resumeOptimizationProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = context.appTextTheme;
    final bgColor = isDark ? AppColors.blue900 : AppColors.grey100;
    final textPrimary = isDark ? AppColors.grey50 : AppColors.blue900;

    return Scaffold(
      backgroundColor: bgColor,
      bottomNavigationBar:
          const HomeBottomNav(currentRoute: '/resume-optimization'),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAppBar(context, isDark, textTheme, textPrimary),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.w(20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  context.text(
                    'Resume Optimization Insights',
                    style: textTheme.title1Bold.copyWith(color: textPrimary),
                  ),
                  SizedBox(height: context.h(8)),
                  context.text(
                    'Track your resume evaluations and discover tailored recommendations to improve your ATS score and job matching.',
                    style: textTheme.bodyRegular.copyWith(
                      color: isDark ? AppColors.grey400 : AppColors.grey800,
                    ),
                  ),
                  SizedBox(height: context.h(20)),
                  _buildStartButton(context, isDark, textTheme),
                  SizedBox(height: context.h(20)),
                ],
              ),
            ),
            Expanded(
              child: state.isLoadingReports
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.lightBlue500))
                  : state.reports.isEmpty
                      ? _buildEmptyState(context, isDark, textTheme)
                      : _buildReportsList(
                          context, state.reports, isDark, textTheme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool isDark, AppTextTheme textTheme,
      Color textPrimary) {
    return Padding(
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
                    color: AppColors.lightBlue500, size: context.icon(40)),
              ),
            ),
          ),
          SizedBox(width: context.w(48)),
        ],
      ),
    );
  }

  Widget _buildStartButton(
      BuildContext context, bool isDark, AppTextTheme textTheme) {
    final btnColor = isDark ? AppColors.lightBlue500 : AppColors.lightBlue700;
    return SizedBox(
      width: double.infinity,
      height: context.h(52),
      child: ElevatedButton.icon(
        onPressed: () => _showUploadDialog(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: btnColor,
          foregroundColor: isDark ? AppColors.blue900 : AppColors.grey50,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(context.r(50))),
          elevation: 0,
        ),
        icon: Icon(Icons.add, size: context.icon(20)),
        label: context.text(
          'Start Resume Optimization',
          style: textTheme.title2Bold
              .copyWith(color: isDark ? AppColors.blue900 : AppColors.grey50),
        ),
      ),
    );
  }

  Widget _buildEmptyState(
      BuildContext context, bool isDark, AppTextTheme textTheme) {
    final iconBg = isDark
        ? AppColors.lightBlue900.withOpacity(0.3)
        : AppColors.lightBlue100;
    final iconColor = isDark ? AppColors.lightBlue400 : AppColors.lightBlue700;
    final textPrimary = isDark ? AppColors.grey100 : AppColors.blue900;
    final textMuted = isDark ? AppColors.grey100 : AppColors.grey800;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: context.w(80),
            height: context.w(80),
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(Icons.description_outlined,
                color: iconColor, size: context.icon(40)),
          ),
          SizedBox(height: context.h(20)),
          context.text('No resume insights yet.',
              style: textTheme.title2Bold.copyWith(color: textPrimary)),
          SizedBox(height: context.h(8)),
          context.text(
            'Start your first optimization to receive\npersonalized recommendations!',
            style: textTheme.bodyRegular.copyWith(color: textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildReportsList(BuildContext context,
      List<ResumeReportSummary> reports, bool isDark, AppTextTheme textTheme) {
    return ListView.separated(
      padding: EdgeInsets.symmetric(
          horizontal: context.w(20), vertical: context.h(4)),
      physics: const BouncingScrollPhysics(),
      itemCount: reports.length,
      separatorBuilder: (_, __) => SizedBox(height: context.h(12)),
      itemBuilder: (context, index) => _ReportCard(
        report: reports[index],
        isDark: isDark,
        textTheme: textTheme,
        onViewDetails: () =>
            context.push('/report-details/${reports[index].reportId}'),
        onDelete: () => _confirmDelete(context, reports[index]),
      ),
    );
  }

  void _showUploadDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const OptimizationUploadDialog(),
    );
  }

  void _confirmDelete(BuildContext context, ResumeReportSummary report) {
    showDialog(
      context: context,
      builder: (_) => DeleteConfirmationDialog(
        onConfirm: () => ref
            .read(resumeOptimizationProvider.notifier)
            .deleteReport(report.reportId),
      ),
    );
  }
}

// ── Report Card ───────────────────────────────────────────────────────────────

class _ReportCard extends StatelessWidget {
  final ResumeReportSummary report;
  final bool isDark;
  final AppTextTheme textTheme;
  final VoidCallback onViewDetails;
  final VoidCallback onDelete;

  const _ReportCard({
    required this.report,
    required this.isDark,
    required this.textTheme,
    required this.onViewDetails,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? AppColors.blue700 : AppColors.grey50;
    final borderColor =
        isDark ? AppColors.blue400.withOpacity(0.4) : AppColors.grey300;
    final textPrimary = isDark ? AppColors.grey50 : AppColors.blue900;
    final scoreColor = isDark ? AppColors.grey100 : AppColors.blue900;
    final labelColor = isDark ? AppColors.grey100 : AppColors.blue900;
    final btnColor = isDark ? AppColors.lightBlue500 : AppColors.lightBlue700;
    final dateColor = isDark ? AppColors.grey500 : AppColors.grey700;

    return Container(
      padding: EdgeInsets.all(context.w(16)),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(context.r(12)),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? AppColors.darkshadow
                : AppColors.lightshadow.withOpacity(0.12),
            blurRadius: 4,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          context.text(
            report.cvName,
            style: textTheme.title2Bold.copyWith(color: textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: context.h(10)),

          // Scores
          _buildScoresGrid(context, labelColor, scoreColor),

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

          SizedBox(height: context.h(14)),

          // Actions
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: context.h(38),
                  child: ElevatedButton(
                    onPressed: onViewDetails,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: btnColor,
                      foregroundColor:
                          isDark ? AppColors.blue900 : AppColors.grey50,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(context.r(50))),
                      elevation: 0,
                      padding: EdgeInsets.zero,
                    ),
                    child: context.text(
                      'View Details',
                      style: textTheme.bodyBold.copyWith(
                          color: isDark ? AppColors.blue900 : AppColors.grey50),
                    ),
                  ),
                ),
              ),
              SizedBox(width: context.w(10)),
              Container(width: 1, height: context.h(38), color: borderColor),
              SizedBox(width: context.w(10)),

              // Delete button
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  width: context.w(38),
                  height: context.h(38),
                  decoration: BoxDecoration(
                    color: AppColors.red500,
                    borderRadius: BorderRadius.circular(context.r(50)),
                  ),
                  child: Center(
                    child: ColorFiltered(
                      colorFilter: const ColorFilter.mode(
                          AppColors.grey50, BlendMode.srcIn),
                      child: Image.asset(
                        'assets/icons/icon_delete.png',
                        width: context.icon(18),
                        height: context.icon(18),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScoresGrid(
      BuildContext context, Color labelColor, Color scoreColor) {
    // All scores
    final items = [
      ('ATS Score:', '${report.atsScore} %'),
      ('Quality Score:', '${report.contentQualityScore} %'),
      if (report.jobMatchScore != null)
        ('Job Match Score:', '${report.jobMatchScore} %'),
    ];

    final rows = <Widget>[];
    for (int i = 0; i < items.length; i += 2) {
      rows.add(Row(
        children: [
          Expanded(
              child: _scoreItem(
                  context, items[i].$1, items[i].$2, labelColor, scoreColor)),
          if (i + 1 < items.length)
            Expanded(
                child: _scoreItem(context, items[i + 1].$1, items[i + 1].$2,
                    labelColor, scoreColor)),
        ],
      ));
      if (i + 2 < items.length) rows.add(SizedBox(height: context.h(4)));
    }
    return Column(children: rows);
  }

  Widget _scoreItem(BuildContext context, String label, String value,
      Color labelColor, Color scoreColor) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label ',
            style: context.responsiveText(
                textTheme.bodyRegular.copyWith(color: labelColor)),
          ),
          TextSpan(
            text: value,
            style: context
                .responsiveText(textTheme.bodyBold.copyWith(color: scoreColor)),
          ),
        ],
      ),
    );
  }
}

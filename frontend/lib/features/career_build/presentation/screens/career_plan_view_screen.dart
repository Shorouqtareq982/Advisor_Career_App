import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../providers/career_build_provider.dart';
import '../widgets/plan_week_card.dart';

class CareerPlanViewScreen extends ConsumerWidget {
  final String planId;

  const CareerPlanViewScreen({super.key, required this.planId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(careerBuildProvider.notifier);
    final state = ref.watch(careerBuildProvider);

    final plan = notifier.getPlanById(planId);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (plan != null && !plan.isViewed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifier.markPlanViewed(plan.id);
      });
    }

    if (plan == null) {
      return _PlanNotFoundScreen(isDark: isDark);
    }

    final bottomPad = MediaQuery.of(context).padding.bottom;
    final overviewBg = isDark ? const Color(0xFF111A38) : AppColors.grey50;
    final overviewBorder =
        isDark ? const Color(0xFF2A8AA2).withOpacity(0.25) : Colors.transparent;
    final headingColor = isDark ? AppColors.grey50 : AppColors.blue900;
    final labelColor = isDark ? AppColors.grey200 : AppColors.blue900;
    final bodyColor = isDark ? AppColors.grey300 : AppColors.grey800;
    final subColor = isDark ? AppColors.grey400 : const Color(0xFF868686);
    final dotColor = isDark ? AppColors.grey50 : AppColors.blue900;

    return Scaffold(
      backgroundColor: isDark ? AppColors.blue900 : AppColors.textDark,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(
            left: context.w(16),
            right: context.w(16),
            top: context.h(10),
            bottom: context.h(20) + bottomPad,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: context.w(24),
                  height: context.w(24),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => context.go('/career-build/plans'),
                    icon: Icon(
                      Icons.arrow_back_ios_new,
                      size: context.icon(18),
                      color: isDark ? AppColors.grey50 : AppColors.blue900,
                    ),
                  ),
                ),
              ),
              SizedBox(height: context.h(6)),
              Center(
                child: Image.asset(
                  'assets/images/branding/logo.png',
                  height: context.h(50),
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(height: context.h(10)),
              Text(
                plan.title,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: context.sp(19).clamp(17.0, 20.0),
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: isDark ? AppColors.grey50 : AppColors.blue900,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: context.h(12)),
              Container(
                padding: EdgeInsets.all(context.w(16)),
                decoration: BoxDecoration(
                  color: overviewBg,
                  borderRadius: BorderRadius.circular(context.r(16)),
                  border: Border.all(color: overviewBorder),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withOpacity(0.18)
                          : AppColors.lightshadow,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Plan Overview',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: context.sp(19).clamp(17.0, 20.0),
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        color: headingColor,
                      ),
                    ),
                    SizedBox(height: context.h(10)),
                    _OverviewLine(
                      label: 'Career Track',
                      value: plan.title,
                      labelColor: labelColor,
                      bodyColor: bodyColor,
                    ),
                    SizedBox(height: context.h(8)),
                    _OverviewLine(
                      label: 'Learning Duration',
                      value: '${plan.weeks} weeks',
                      labelColor: labelColor,
                      bodyColor: bodyColor,
                    ),
                    if (plan.availableHoursPerWeek > 0) ...[
                      SizedBox(height: context.h(8)),
                      _OverviewLine(
                        label: 'Weekly Time',
                        value: '${plan.availableHoursPerWeek} hrs/week',
                        labelColor: labelColor,
                        bodyColor: bodyColor,
                      ),
                    ],
                    if (plan.planningMode.trim().isNotEmpty) ...[
                      SizedBox(height: context.h(8)),
                      _OverviewLine(
                        label: 'Planning Mode',
                        value: _prettyText(plan.planningMode),
                        labelColor: labelColor,
                        bodyColor: bodyColor,
                      ),
                    ],
                    if (plan.studyIntensity.trim().isNotEmpty) ...[
                      SizedBox(height: context.h(8)),
                      _OverviewLine(
                        label: 'Study Intensity',
                        value: _prettyText(plan.studyIntensity),
                        labelColor: labelColor,
                        bodyColor: bodyColor,
                      ),
                    ],
                    if (plan.planSummary.trim().isNotEmpty) ...[
                      SizedBox(height: context.h(12)),
                      Text(
                        plan.planSummary,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: context.sp(12).clamp(11.0, 13.0),
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                          color: bodyColor,
                        ),
                      ),
                    ],
                    if (plan.improvementSummary.trim().isNotEmpty) ...[
                      SizedBox(height: context.h(10)),
                      Text(
                        plan.improvementSummary,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: context.sp(12).clamp(11.0, 13.0),
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                          color: subColor,
                        ),
                      ),
                    ],
                    if (plan.skillsIncluded.isNotEmpty) ...[
                      SizedBox(height: context.h(14)),
                      Text(
                        'Skills Included',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: context.sp(13).clamp(12.0, 14.0),
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          color: labelColor,
                        ),
                      ),
                      SizedBox(height: context.h(8)),
                      Wrap(
                        spacing: context.w(16),
                        runSpacing: context.h(8),
                        children: plan.skillsIncluded.map((s) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: context.w(6),
                                height: context.w(6),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: dotColor,
                                ),
                              ),
                              SizedBox(width: context.w(6)),
                              Text(
                                s,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: context.sp(13).clamp(12.0, 14.0),
                                  fontWeight: FontWeight.w500,
                                  height: 1.2,
                                  color: bodyColor,
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: context.h(16)),
              if (plan.roadmap.isEmpty)
                _EmptyRoadmapCard(isDark: isDark)
              else
                ...plan.roadmap.map(
                  (w) => Padding(
                    padding: EdgeInsets.only(bottom: context.h(16)),
                    child: PlanWeekCard(week: w),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanNotFoundScreen extends StatelessWidget {
  final bool isDark;

  const _PlanNotFoundScreen({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDark ? AppColors.blue900 : AppColors.textDark,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(context.w(18)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: context.icon(42),
                  color: isDark ? AppColors.grey400 : AppColors.grey700,
                ),
                SizedBox(height: context.h(12)),
                Text(
                  'Plan not found',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: context.sp(17).clamp(15.0, 18.0),
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.grey50 : AppColors.blue900,
                  ),
                ),
                SizedBox(height: context.h(8)),
                Text(
                  'This plan may have been deleted or was not loaded from local cache.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: context.sp(13).clamp(12.0, 14.0),
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                    color: isDark ? AppColors.grey400 : AppColors.grey800,
                  ),
                ),
                SizedBox(height: context.h(18)),
                SizedBox(
                  height: context.h(44),
                  child: ElevatedButton(
                    onPressed: () => context.go('/career-build/plans'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF268299),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                    child: Text(
                      'Back to Plans',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: context.sp(14).clamp(13.0, 15.0),
                        fontWeight: FontWeight.w700,
                      ),
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
}

class _OverviewLine extends StatelessWidget {
  final String label;
  final String value;
  final Color labelColor;
  final Color bodyColor;

  const _OverviewLine({
    required this.label,
    required this.value,
    required this.labelColor,
    required this.bodyColor,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: context.sp(13).clamp(12.0, 14.0),
          fontWeight: FontWeight.w500,
          height: 1.25,
          color: bodyColor,
        ),
        children: [
          TextSpan(
            text: '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: labelColor,
            ),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }
}

class _EmptyRoadmapCard extends StatelessWidget {
  final bool isDark;

  const _EmptyRoadmapCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.w(14)),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111A38) : AppColors.grey50,
        borderRadius: BorderRadius.circular(context.r(14)),
        border: Border.all(
          color: isDark ? const Color(0xFF2A8AA2) : AppColors.grey300,
        ),
      ),
      child: Text(
        'No weekly roadmap was saved for this plan.',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: context.sp(12).clamp(11.0, 13.0),
          fontWeight: FontWeight.w600,
          height: 1.35,
          color: isDark ? AppColors.grey300 : AppColors.grey800,
        ),
      ),
    );
  }
}

String _prettyText(String raw) {
  final s = raw.replaceAll('_', ' ').trim();
  if (s.isEmpty) return raw;
  return s
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

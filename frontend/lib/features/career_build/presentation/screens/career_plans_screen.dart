import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../../../home/presentation/widgets/home_bottom_nav.dart';
import '../providers/career_build_provider.dart';
import '../widgets/delete_plan_dialog.dart';

class CareerPlansScreen extends ConsumerWidget {
  const CareerPlansScreen({super.key});

  void _backToHome(BuildContext context) => context.go('/home');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(careerBuildProvider);
    final notifier = ref.read(careerBuildProvider.notifier);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    const figmaTeal = Color(0xFF268299);

    return Scaffold(
      backgroundColor: isDark ? AppColors.blue900 : AppColors.textDark,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: context.w(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: context.h(10)),
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: context.w(24),
                  height: context.w(24),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => _backToHome(context),
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
              SizedBox(height: context.h(6)),
              Text(
                'My Career Plans',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: context.sp(19).clamp(17.0, 20.0),
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: isDark ? AppColors.grey50 : AppColors.blue900,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: context.h(6)),
              Text(
                'Manage and track all your learning journeys',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: context.sp(16).clamp(14.0, 16.0),
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                  color: isDark ? AppColors.grey400 : AppColors.grey800,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: context.h(18)),
              SizedBox(
                width: double.infinity,
                height: context.h(40),
                child: ElevatedButton.icon(
                  onPressed: () {
                    notifier.resetWizard();
                    context.go('/career-build/create/step-1');
                  },
                  icon: Icon(Icons.add, size: context.icon(18)),
                  label: Text(
                    'Create New Plan',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: context.sp(13).clamp(12.0, 14.0),
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: figmaTeal,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                ),
              ),
              if (state.backendError != null) ...[
                SizedBox(height: context.h(10)),
                _InlineMessage(
                  message: state.backendError!,
                  isDark: isDark,
                  isError: true,
                ),
              ],
              if (state.successMessage != null) ...[
                SizedBox(height: context.h(10)),
                _InlineMessage(
                  message: state.successMessage!,
                  isDark: isDark,
                  isError: false,
                ),
              ],
              SizedBox(height: context.h(16)),
              Expanded(
                child: state.plans.isEmpty
                    ? _EmptyState(isDark: isDark)
                    : RefreshIndicator(
                        color: figmaTeal,
                        onRefresh: () async {
                          await notifier.loadCachedPlans();
                        },
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: EdgeInsets.only(bottom: context.h(18)),
                          itemBuilder: (context, index) {
                            final plan = state.plans[index];

                            return _PlanCard(
                              planTitle: plan.title,
                              isNew: !plan.isViewed,
                              skills: plan.skillsIncluded,
                              weeks: plan.weeks,
                              months: plan.months,
                              createdAt: plan.createdAt,
                              planningMode: plan.planningMode,
                              studyIntensity: plan.studyIntensity,
                              availableHoursPerWeek: plan.availableHoursPerWeek,
                              summary: plan.planSummary,
                              onView: () {
                                notifier.markPlanViewed(plan.id);
                                context.go('/career-build/plans/${plan.id}');
                              },
                              onDelete: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => DeletePlanDialog(
                                    onDelete: () {
                                      notifier.deletePlanOptimistic(plan.id);
                                      Navigator.pop(context);
                                    },
                                  ),
                                );
                              },
                            );
                          },
                          separatorBuilder: (_, __) =>
                              SizedBox(height: context.h(16)),
                          itemCount: state.plans.length,
                        ),
                      ),
              ),
              SizedBox(height: context.h(8)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const HomeBottomNav(currentRoute: '/home'),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  final String message;
  final bool isDark;
  final bool isError;

  const _InlineMessage({
    required this.message,
    required this.isDark,
    required this.isError,
  });

  @override
  Widget build(BuildContext context) {
    final color = isError
        ? (isDark ? AppColors.red300 : AppColors.red600)
        : const Color(0xFF22C55E);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.w(10)),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.13 : 0.08),
        borderRadius: BorderRadius.circular(context.r(12)),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Text(
        message,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: context.sp(12).clamp(11.0, 13.0),
          fontWeight: FontWeight.w600,
          height: 1.3,
          color: color,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isDark;
  const _EmptyState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: context.h(28)),
        Center(
          child: Image.asset(
            'assets/images/career_build/no_plan.png',
            width: context.w(110),
            height: context.w(110),
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
            isAntiAlias: true,
          ),
        ),
        SizedBox(height: context.h(14)),
        Text(
          'No career plans yet',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: context.sp(16).clamp(14.0, 16.0),
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: isDark ? AppColors.grey50 : AppColors.blue900,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: context.h(8)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: context.w(18)),
          child: Text(
            'Start your first backend-generated plan to build the skills for your target career',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: context.sp(16).clamp(14.0, 16.0),
              fontWeight: FontWeight.w500,
              height: 1.25,
              color: isDark ? AppColors.grey400 : AppColors.grey800,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String planTitle;
  final bool isNew;
  final List<String> skills;
  final int weeks;
  final int months;
  final DateTime createdAt;
  final String planningMode;
  final String studyIntensity;
  final int availableHoursPerWeek;
  final String summary;
  final VoidCallback onView;
  final VoidCallback onDelete;

  const _PlanCard({
    required this.planTitle,
    required this.isNew,
    required this.skills,
    required this.weeks,
    required this.months,
    required this.createdAt,
    required this.planningMode,
    required this.studyIntensity,
    required this.availableHoursPerWeek,
    required this.summary,
    required this.onView,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    const figmaTeal = Color(0xFF268299);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final btnH = context.h(36).clamp(36.0, 40.0);

    final cardBg = isDark ? const Color(0xFF111A38) : AppColors.grey50;
    final cardBorder =
        isDark ? const Color(0xFF2A8AA2).withOpacity(0.25) : Colors.transparent;
    final titleColor = isDark ? AppColors.grey50 : AppColors.blue900;
    final labelColor = isDark ? AppColors.grey200 : AppColors.blue900;
    final bodyColor = isDark ? AppColors.grey300 : AppColors.grey800;
    final dateColor = isDark ? AppColors.grey400 : const Color(0xFF4F4F4F);
    final dotColor = isDark ? AppColors.grey50 : AppColors.blue900;

    return Container(
      padding: EdgeInsets.all(context.w(14)),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(context.r(8)),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color:
                isDark ? Colors.black.withOpacity(0.18) : AppColors.lightshadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  planTitle,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: context.sp(19).clamp(17.0, 20.0),
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    color: titleColor,
                  ),
                ),
              ),
              if (isNew)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.w(8),
                    vertical: context.h(4),
                  ),
                  decoration: BoxDecoration(
                    color: figmaTeal,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Text(
                    'New',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: context.sp(11).clamp(10.0, 12.0),
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          if (summary.trim().isNotEmpty) ...[
            SizedBox(height: context.h(8)),
            Text(
              summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: context.sp(12).clamp(11.0, 13.0),
                fontWeight: FontWeight.w500,
                height: 1.35,
                color: bodyColor,
              ),
            ),
          ],
          SizedBox(height: context.h(10)),
          Text(
            'Skills Included',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: context.sp(13).clamp(12.0, 14.0),
              fontWeight: FontWeight.w500,
              height: 1.2,
              color: labelColor,
            ),
          ),
          SizedBox(height: context.h(8)),
          Wrap(
            spacing: context.w(16),
            runSpacing: context.h(8),
            children: skills.take(3).map((s) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Dot(color: dotColor),
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
          SizedBox(height: context.h(10)),
          Row(
            children: [
              Icon(Icons.schedule, size: context.icon(16), color: labelColor),
              SizedBox(width: context.w(8)),
              Text(
                'Learning Duration',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: context.sp(13).clamp(12.0, 14.0),
                  fontWeight: FontWeight.w400,
                  height: 1.2,
                  color: labelColor,
                ),
              ),
            ],
          ),
          SizedBox(height: context.h(8)),
          Wrap(
            spacing: context.w(16),
            runSpacing: context.h(8),
            children: [
              _DurationChip(
                text: '$weeks weeks',
                dotColor: dotColor,
                textColor: bodyColor,
              ),
              if (months > 0)
                _DurationChip(
                  text: '$months months',
                  dotColor: dotColor,
                  textColor: bodyColor,
                ),
              if (availableHoursPerWeek > 0)
                _DurationChip(
                  text: '$availableHoursPerWeek hrs/week',
                  dotColor: dotColor,
                  textColor: bodyColor,
                ),
            ],
          ),
          if (planningMode.trim().isNotEmpty ||
              studyIntensity.trim().isNotEmpty) ...[
            SizedBox(height: context.h(10)),
            Wrap(
              spacing: context.w(8),
              runSpacing: context.h(8),
              children: [
                if (planningMode.trim().isNotEmpty)
                  _MetaPill(text: _prettyText(planningMode), isDark: isDark),
                if (studyIntensity.trim().isNotEmpty)
                  _MetaPill(text: _prettyText(studyIntensity), isDark: isDark),
              ],
            ),
          ],
          SizedBox(height: context.h(10)),
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: context.icon(16),
                color: labelColor,
              ),
              SizedBox(width: context.w(8)),
              Text(
                _formatDate(createdAt),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: context.sp(13).clamp(12.0, 14.0),
                  fontWeight: FontWeight.w400,
                  height: 1.2,
                  color: dateColor,
                ),
              ),
            ],
          ),
          SizedBox(height: context.h(12)),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: btnH,
                  child: ElevatedButton(
                    onPressed: onView,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: figmaTeal,
                      foregroundColor: const Color(0xFFF8F8F8),
                      elevation: 0,
                      minimumSize: Size(double.infinity, btnH),
                      padding: EdgeInsets.symmetric(
                        vertical: context.h(10),
                        horizontal: context.w(16),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                    child: Text(
                      'View Plan',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: context.sp(13).clamp(12.0, 14.0),
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: context.w(10)),
              Container(
                width: context.w(2),
                height: btnH,
                decoration: BoxDecoration(
                  color: figmaTeal,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: context.w(10)),
              SizedBox(
                width: context.w(53),
                height: btnH,
                child: ElevatedButton(
                  onPressed: onDelete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD03430),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: Size(context.w(53), btnH),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                  child: Icon(Icons.delete, size: context.icon(18)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DurationChip extends StatelessWidget {
  final String text;
  final Color dotColor;
  final Color textColor;

  const _DurationChip({
    required this.text,
    required this.dotColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Dot(size: 6, color: dotColor),
        SizedBox(width: context.w(6)),
        Text(
          text,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: context.sp(13).clamp(12.0, 14.0),
            fontWeight: FontWeight.w500,
            height: 1.2,
            color: textColor,
          ),
        ),
      ],
    );
  }
}

class _MetaPill extends StatelessWidget {
  final String text;
  final bool isDark;

  const _MetaPill({
    required this.text,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    const figmaTeal = Color(0xFF268299);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.w(10),
        vertical: context.h(6),
      ),
      decoration: BoxDecoration(
        color: figmaTeal.withOpacity(isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: figmaTeal.withOpacity(0.30)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: context.sp(11).clamp(10.0, 12.0),
          fontWeight: FontWeight.w800,
          color: isDark ? AppColors.grey50 : AppColors.blue900,
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final double size;
  final Color color;

  const _Dot({
    this.size = 6,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

String _formatDate(DateTime dt) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
}

String _prettyText(String raw) {
  final s = raw.replaceAll('_', ' ').trim();
  if (s.isEmpty) return raw;
  return s
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

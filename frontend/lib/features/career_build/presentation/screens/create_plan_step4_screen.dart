import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../../data/models/career_build_models.dart';
import '../providers/career_build_provider.dart';
import '../widgets/career_build_step_indicator.dart';
import '../widgets/plan_week_card.dart';

class CreatePlanStep4Screen extends ConsumerStatefulWidget {
  const CreatePlanStep4Screen({super.key});

  @override
  ConsumerState<CreatePlanStep4Screen> createState() =>
      _CreatePlanStep4ScreenState();
}

class _CreatePlanStep4ScreenState extends ConsumerState<CreatePlanStep4Screen> {
  void _back(BuildContext context) => context.go('/career-build/create/step-3');

  Future<void> _openRegenerateDialog(BuildContext context) async {
    final selected = await showDialog<List<String>>(
      context: context,
      builder: (_) => const _RegenerationIntentsDialog(),
    );

    if (selected == null || selected.isEmpty) return;

    final notifier = ref.read(careerBuildProvider.notifier);

    // Backend /regenerate-plan receives feedback_intents as the exact final list.
    // Replace the previous selection instead of toggling, so stale/unchecked
    // intents are not sent and the request stays valid for the backend schema.
    notifier.setRegenerationIntents(selected);

    final ok = await notifier.regeneratePreviewPlan();

    if (!mounted) return;

    if (!ok) {
      final err = ref.read(careerBuildProvider).regenerationError ??
          'We could not regenerate the plan right now. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err)),
      );
    }
  }

  Future<void> _save(BuildContext context) async {
    final ok = await ref.read(careerBuildProvider.notifier).saveGeneratedPlan();

    if (!mounted) return;

    final state = ref.read(careerBuildProvider);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(state.successMessage ?? 'Plan saved successfully')),
      );
      context.go('/career-build/plans');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.backendError ?? 'Could not save plan.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(careerBuildProvider);
    final notifier = ref.read(careerBuildProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const figmaTeal = Color(0xFF268299);

    final plan = state.backendPlan;
    final previewWeeks = notifier.getPreviewRoadmap();
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    final skills = plan?.usedLearningTargets
            .map((e) => e['skill_name']?.toString() ?? '')
            .where((e) => e.trim().isNotEmpty)
            .take(4)
            .toList() ??
        state.userSkills.map((e) => e.title).take(4).toList();

    final overviewBg = isDark ? const Color(0xFF111A38) : AppColors.grey50;
    final overviewBorder =
        isDark ? const Color(0xFF2A8AA2).withOpacity(0.25) : Colors.transparent;
    final headingColor = isDark ? AppColors.grey50 : AppColors.blue900;
    final labelColor = isDark ? AppColors.grey200 : AppColors.blue900;
    final bodyColor = isDark ? AppColors.grey300 : AppColors.grey800;
    final subTextColor = isDark ? AppColors.grey400 : const Color(0xFF868686);
    final dotColor = isDark ? AppColors.grey50 : AppColors.blue900;

    final showBlockingLoader = state.isRegenerationLoading || state.isSaving;

    return Scaffold(
      backgroundColor: isDark ? AppColors.blue900 : AppColors.textDark,
      body: Stack(
        children: [
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.w(16),
                        vertical: context.h(10),
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
                                onPressed: showBlockingLoader
                                    ? null
                                    : () => _back(context),
                                icon: Icon(
                                  Icons.arrow_back_ios_new,
                                  size: context.icon(18),
                                  color: isDark
                                      ? AppColors.grey50
                                      : AppColors.blue900,
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
                            'Career Build',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: context.sp(19).clamp(17.0, 20.0),
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                              color:
                                  isDark ? AppColors.grey50 : AppColors.blue900,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: context.h(6)),
                          Text(
                            'Create a personalized learning plan for your\ncareer',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: context.sp(14).clamp(13.0, 16.0),
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                              color: isDark
                                  ? AppColors.grey400
                                  : AppColors.grey800,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: context.h(18)),
                          const CareerBuildStepIndicator(
                            currentStep: 4,
                            totalSteps: 4,
                          ),
                          SizedBox(height: context.h(18)),
                          Text(
                            'Your Career Plan is Ready',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: context.sp(19).clamp(17.0, 20.0),
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                              color:
                                  isDark ? AppColors.grey50 : AppColors.blue900,
                            ),
                          ),
                          SizedBox(height: context.h(6)),
                          Text(
                            plan == null
                                ? 'No generated plan found.'
                                : 'Explore your personalized weekly roadmap below.',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: context.sp(16).clamp(14.0, 16.0),
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                              color: subTextColor,
                            ),
                          ),
                          if (state.regenerationError != null) ...[
                            SizedBox(height: context.h(8)),
                            _MessageText(
                              message: state.regenerationError!,
                              isDark: isDark,
                              isError: true,
                            ),
                          ],
                          if (state.backendError != null) ...[
                            SizedBox(height: context.h(8)),
                            _MessageText(
                              message: state.backendError!,
                              isDark: isDark,
                              isError: true,
                            ),
                          ],
                          if (state.successMessage != null) ...[
                            SizedBox(height: context.h(8)),
                            _MessageText(
                              message: state.successMessage!,
                              isDark: isDark,
                              isError: false,
                            ),
                          ],
                          SizedBox(height: context.h(10)),
                          Align(
                            alignment: Alignment.centerRight,
                            child: SizedBox(
                              width: context.w(168),
                              height: context.h(36),
                              child: ElevatedButton.icon(
                                onPressed: plan == null || showBlockingLoader
                                    ? null
                                    : () => _openRegenerateDialog(context),
                                icon:
                                    Icon(Icons.refresh, size: context.icon(16)),
                                label: Text(
                                  'Regenerate Plan',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: context.sp(12).clamp(11.0, 13.0),
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
                                  padding: EdgeInsets.symmetric(
                                    horizontal: context.w(14),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: context.h(14)),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(context.w(16)),
                            decoration: BoxDecoration(
                              color: overviewBg,
                              borderRadius:
                                  BorderRadius.circular(context.r(16)),
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
                                  value: plan?.trackName ??
                                      state.trackInput.trim(),
                                  labelColor: labelColor,
                                  bodyColor: bodyColor,
                                ),
                                SizedBox(height: context.h(8)),
                                _OverviewLine(
                                  label: 'Duration',
                                  value:
                                      '${plan?.durationWeeks ?? state.totalRequestedWeeks} weeks',
                                  labelColor: labelColor,
                                  bodyColor: bodyColor,
                                ),
                                SizedBox(height: context.h(8)),
                                _OverviewLine(
                                  label: 'Hours / Week',
                                  value:
                                      '${plan?.availableHoursPerWeek ?? state.weeklyStudyHours} hrs/week',
                                  labelColor: labelColor,
                                  bodyColor: bodyColor,
                                ),
                                if ((plan?.planningMode ?? '').isNotEmpty) ...[
                                  SizedBox(height: context.h(8)),
                                  _OverviewLine(
                                    label: 'Planning Mode',
                                    value: _prettyText(plan!.planningMode),
                                    labelColor: labelColor,
                                    bodyColor: bodyColor,
                                  ),
                                ],
                                if ((plan?.studyIntensity ?? '')
                                    .isNotEmpty) ...[
                                  SizedBox(height: context.h(8)),
                                  _OverviewLine(
                                    label: 'Study Intensity',
                                    value: _prettyText(plan!.studyIntensity),
                                    labelColor: labelColor,
                                    bodyColor: bodyColor,
                                  ),
                                ],
                                if ((plan?.planSummary ?? '').isNotEmpty) ...[
                                  SizedBox(height: context.h(12)),
                                  Text(
                                    plan!.planSummary,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize:
                                          context.sp(12).clamp(11.0, 13.0),
                                      fontWeight: FontWeight.w500,
                                      height: 1.35,
                                      color: bodyColor,
                                    ),
                                  ),
                                ],
                                if ((plan?.improvementSummary ?? '')
                                    .isNotEmpty) ...[
                                  SizedBox(height: context.h(10)),
                                  Text(
                                    plan!.improvementSummary,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize:
                                          context.sp(12).clamp(11.0, 13.0),
                                      fontWeight: FontWeight.w600,
                                      height: 1.35,
                                      color: subTextColor,
                                    ),
                                  ),
                                ],
                                if (skills.isNotEmpty) ...[
                                  SizedBox(height: context.h(12)),
                                  Text(
                                    'Skills Included',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize:
                                          context.sp(13).clamp(12.0, 14.0),
                                      fontWeight: FontWeight.w700,
                                      height: 1.2,
                                      color: labelColor,
                                    ),
                                  ),
                                  SizedBox(height: context.h(8)),
                                  Wrap(
                                    spacing: context.w(16),
                                    runSpacing: context.h(8),
                                    children: skills.map((s) {
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
                                              fontSize: context
                                                  .sp(13)
                                                  .clamp(12.0, 14.0),
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
                          if (previewWeeks.isEmpty)
                            _EmptyPlanCard(isDark: isDark)
                          else
                            ...previewWeeks.map(
                              (w) => Padding(
                                padding: EdgeInsets.only(bottom: context.h(16)),
                                child: PlanWeekCard(week: w),
                              ),
                            ),
                          SizedBox(height: context.h(18)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              SizedBox(
                                width: context.w(110),
                                height: context.h(48),
                                child: OutlinedButton(
                                  onPressed: showBlockingLoader
                                      ? null
                                      : () => _back(context),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: figmaTeal,
                                    side: const BorderSide(
                                      color: figmaTeal,
                                      width: 1,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(50),
                                    ),
                                  ),
                                  child: Text(
                                    'Back',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w600,
                                      fontSize:
                                          context.sp(14).clamp(13.0, 15.0),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: context.w(110),
                                height: context.h(48),
                                child: ElevatedButton(
                                  onPressed: plan == null || showBlockingLoader
                                      ? null
                                      : () => _save(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: figmaTeal,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(50),
                                    ),
                                  ),
                                  child: state.isSaving
                                      ? SizedBox(
                                          width: context.w(18),
                                          height: context.w(18),
                                          child:
                                              const CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          'Save',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontWeight: FontWeight.w600,
                                            fontSize: context
                                                .sp(14)
                                                .clamp(13.0, 15.0),
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: context.h(16) + bottomSafe),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (showBlockingLoader)
            Container(
              color: Colors.black.withOpacity(0.30),
              child: Center(
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: context.w(24)),
                  padding: EdgeInsets.all(context.w(20)),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF111A38) : Colors.white,
                    borderRadius: BorderRadius.circular(context.r(16)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: context.w(42),
                        height: context.w(42),
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: figmaTeal,
                        ),
                      ),
                      SizedBox(height: context.h(18)),
                      Text(
                        state.isSaving
                            ? 'Saving Your Plan'
                            : 'Regenerating Your Plan',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: context.sp(19).clamp(17.0, 20.0),
                          fontWeight: FontWeight.w700,
                          color: headingColor,
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: context.h(10)),
                      Text(
                        state.isSaving
                            ? 'We are saving your plan to your account.'
                            : 'Please wait while we update your plan based on your feedback. This may take several minutes, so keep the app open until it finishes.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: context.sp(14).clamp(13.0, 15.0),
                          fontWeight: FontWeight.w500,
                          color: subTextColor,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
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

class _EmptyPlanCard extends StatelessWidget {
  final bool isDark;

  const _EmptyPlanCard({required this.isDark});

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
        'No weekly plan was returned. Please go back and generate the plan again.',
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

class _MessageText extends StatelessWidget {
  final String message;
  final bool isDark;
  final bool isError;

  const _MessageText({
    required this.message,
    required this.isDark,
    required this.isError,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: context.sp(12).clamp(11.0, 13.0),
        fontWeight: FontWeight.w600,
        color: isError
            ? (isDark ? AppColors.red300 : AppColors.red600)
            : const Color(0xFF22C55E),
      ),
    );
  }
}

class _RegenerationIntentsDialog extends ConsumerStatefulWidget {
  const _RegenerationIntentsDialog();

  @override
  ConsumerState<_RegenerationIntentsDialog> createState() =>
      _RegenerationIntentsDialogState();
}

class _RegenerationIntentsDialogState
    extends ConsumerState<_RegenerationIntentsDialog> {
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {
      ...ref.read(careerBuildProvider).selectedRegenerationIntentValues,
    };
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(careerBuildProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final intents = state.regenerationIntents;

    final dialogBg = isDark ? const Color(0xFF111A38) : Colors.white;
    final titleColor = isDark ? AppColors.grey50 : AppColors.blue900;
    final bodyColor = isDark ? AppColors.grey300 : AppColors.grey800;
    final borderColor =
        isDark ? const Color(0xFF2A8AA2).withOpacity(0.35) : Colors.transparent;

    return Dialog(
      backgroundColor: dialogBg,
      insetPadding: EdgeInsets.symmetric(horizontal: context.w(18)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.r(24)),
        side: BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.w(18),
          vertical: context.h(18),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: context.h(620)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Regenerate Plan',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: context.sp(20).clamp(18.0, 22.0),
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  color: titleColor,
                ),
              ),
              SizedBox(height: context.h(10)),
              Text(
                'Select what you want to improve, and we will update the plan based on your feedback.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: context.sp(14).clamp(12.0, 15.0),
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                  color: bodyColor,
                ),
              ),
              SizedBox(height: context.h(16)),
              if (intents.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: context.h(18)),
                  child: Text(
                    'No regeneration options were loaded. Please try again later.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: context.sp(13).clamp(12.0, 14.0),
                      fontWeight: FontWeight.w600,
                      color: bodyColor,
                    ),
                  ),
                )
              else
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: intents.map((intent) {
                        final selected = _selected.contains(intent.value);

                        return Padding(
                          padding: EdgeInsets.only(bottom: context.h(10)),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(context.r(14)),
                            onTap: () {
                              setState(() {
                                if (selected) {
                                  _selected.remove(intent.value);
                                } else {
                                  _selected.add(intent.value);
                                }
                              });
                            },
                            child: Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(context.w(14)),
                              decoration: BoxDecoration(
                                color: selected
                                    ? const Color(0xFF268299).withOpacity(0.12)
                                    : Colors.transparent,
                                borderRadius:
                                    BorderRadius.circular(context.r(14)),
                                border: Border.all(
                                  color: selected
                                      ? const Color(0xFF268299)
                                      : (isDark
                                          ? AppColors.grey700
                                          : AppColors.grey300),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Checkbox(
                                    value: selected,
                                    onChanged: (_) {
                                      setState(() {
                                        if (selected) {
                                          _selected.remove(intent.value);
                                        } else {
                                          _selected.add(intent.value);
                                        }
                                      });
                                    },
                                    activeColor: const Color(0xFF268299),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding:
                                          EdgeInsets.only(top: context.h(4)),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            intent.display,
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: context
                                                  .sp(14)
                                                  .clamp(13.0, 15.0),
                                              fontWeight: FontWeight.w700,
                                              color: titleColor,
                                            ),
                                          ),
                                          SizedBox(height: context.h(4)),
                                          Text(
                                            intent.description,
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: context
                                                  .sp(12)
                                                  .clamp(11.0, 13.0),
                                              fontWeight: FontWeight.w500,
                                              color: bodyColor,
                                              height: 1.25,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              SizedBox(height: context.h(8)),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: context.h(44),
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark
                              ? const Color(0xFF1C2647)
                              : AppColors.grey200,
                          foregroundColor:
                              isDark ? AppColors.grey50 : AppColors.grey800,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: context.sp(14).clamp(13.0, 15.0),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: context.w(12)),
                  Expanded(
                    child: SizedBox(
                      height: context.h(44),
                      child: ElevatedButton(
                        onPressed: _selected.isEmpty
                            ? null
                            : () => Navigator.pop(
                                  context,
                                  _selected.toList(),
                                ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF268299),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                        ),
                        child: Text(
                          'Regenerate',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: context.sp(14).clamp(13.0, 15.0),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../providers/career_build_provider.dart';
import '../widgets/career_build_step_indicator.dart';

class CreatePlanStep3Screen extends ConsumerStatefulWidget {
  const CreatePlanStep3Screen({super.key});

  @override
  ConsumerState<CreatePlanStep3Screen> createState() =>
      _CreatePlanStep3ScreenState();
}

class _CreatePlanStep3ScreenState extends ConsumerState<CreatePlanStep3Screen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(careerBuildProvider.notifier).fetchSuggestedTimelineOnce();
    });
  }

  void _back(BuildContext context) => context.go('/career-build/create/step-2');

  Future<void> _generate(BuildContext context) async {
    final notifier = ref.read(careerBuildProvider.notifier);
    final ok = await notifier.generatePlanFromTimeline();

    if (!mounted) return;

    if (ok) {
      notifier.setStep(4);
      context.go('/career-build/create/step-4');
      return;
    }

    final state = ref.read(careerBuildProvider);
    final error = _friendlyBackendError(
      state.backendError ??
          state.timelineError ??
          'We could not generate the plan right now. Please try again.',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(careerBuildProvider);
    final notifier = ref.read(careerBuildProvider.notifier);

    final timeData = state.confirmedTime ?? state.timePreview;
    final guidance = timeData?.timeGuidance;
    final isBusy = state.isTimelineLoading || state.isGenerating;
    final isInitialTimelineLoading =
        state.isTimelineLoading && state.timePreview == null;

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
                              width: context.w(28),
                              height: context.w(28),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                onPressed: isBusy ? null : () => _back(context),
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
                            currentStep: 3,
                            totalSteps: 4,
                          ),
                          SizedBox(height: context.h(18)),
                          Text(
                            'Choose your learning timeline',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: context.sp(16).clamp(14.0, 17.0),
                              fontWeight: FontWeight.w800,
                              color:
                                  isDark ? AppColors.grey50 : AppColors.blue900,
                            ),
                          ),
                          SizedBox(height: context.h(8)),
                          Text(
                            'The first range is a preview from the backend. The final warning and suggestions are calculated by the backend when you generate the plan.',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: context.sp(13).clamp(12.0, 13.0),
                              fontWeight: FontWeight.w400,
                              height: 1.3,
                              color: isDark
                                  ? AppColors.grey400
                                  : AppColors.grey700,
                            ),
                          ),
                          if (isInitialTimelineLoading) ...[
                            SizedBox(height: context.h(18)),
                            _LoadingCard(
                              title: 'Loading time guidance...',
                              message:
                                  'We are calculating the recommended timeline for your selected skills.',
                              isDark: isDark,
                            ),
                          ],
                          if (guidance != null) ...[
                            SizedBox(height: context.h(14)),
                            _GuidanceRangesCard(
                              minimumWeeks: guidance.minimumWeeks,
                              suitableWeeks: guidance.suitableWeeks,
                              maximumWeeks: guidance.maximumWeeks,
                              studyIntensity: guidance.studyIntensity,
                              isDark: isDark,
                            ),
                          ],
                          if ((timeData?.guidanceMessage ?? '')
                              .trim()
                              .isNotEmpty) ...[
                            SizedBox(height: context.h(10)),
                            _GuidanceMessageCard(
                              message: timeData!.guidanceMessage!,
                              note: timeData.note ?? '',
                              isDark: isDark,
                            ),
                          ],
                          SizedBox(height: context.h(14)),
                          _TimelineRow(
                            label: 'Weeks',
                            value: state.weeks,
                            suffix: 'weeks',
                            enabled: !isBusy,
                            onInc: notifier.incWeeks,
                            onDec: notifier.decWeeks,
                          ),
                          SizedBox(height: context.h(12)),
                          _TimelineRow(
                            label: 'Hours',
                            value: state.weeklyStudyHours,
                            suffix: 'hrs/week',
                            enabled: !isBusy,
                            onInc: notifier.incWeeklyStudyHours,
                            onDec: notifier.decWeeklyStudyHours,
                          ),
                          if (state.isTimelineLoading &&
                              state.timePreview != null) ...[
                            SizedBox(height: context.h(10)),
                            _InlineInfoText(
                              text: 'Updating backend validation...',
                              isDark: isDark,
                            ),
                          ],
                          if (state.timelineFeedbackTitle != null) ...[
                            SizedBox(height: context.h(12)),
                            _FeedbackCard(
                              title: state.timelineFeedbackTitle!,
                              message: state.timelineFeedbackMessage ?? '',
                              hint: state.timelineFeedbackHint ?? '',
                              isDark: isDark,
                              color: state.timelineFeedbackColor ??
                                  const Color(0xFF268299),
                              icon: state.timelineFeedbackIcon ??
                                  Icons.schedule_rounded,
                            ),
                          ],
                          if (state.hoursFeedbackTitle != null) ...[
                            SizedBox(height: context.h(12)),
                            _FeedbackCard(
                              title: state.hoursFeedbackTitle!,
                              message: state.hoursFeedbackMessage ?? '',
                              hint: state.hoursFeedbackHint ?? '',
                              isDark: isDark,
                              color: state.hoursFeedbackColor ??
                                  const Color(0xFF268299),
                              icon: state.hoursFeedbackIcon ??
                                  Icons.schedule_rounded,
                            ),
                          ],
                          if (state.timelineError != null) ...[
                            SizedBox(height: context.h(10)),
                            _ErrorText(
                              message:
                                  _friendlyBackendError(state.timelineError!),
                              isDark: isDark,
                            ),
                          ],
                          if (state.backendError != null) ...[
                            SizedBox(height: context.h(10)),
                            _ErrorText(
                              message:
                                  _friendlyBackendError(state.backendError!),
                              isDark: isDark,
                            ),
                          ],
                          if (state.timelineChanged) ...[
                            SizedBox(height: context.h(14)),
                            Align(
                              alignment: Alignment.centerRight,
                              child: _ResetButton(
                                enabled: !isBusy,
                                onTap: notifier.resetTimelineToSuggested,
                              ),
                            ),
                          ],
                          SizedBox(height: context.h(24)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              SizedBox(
                                width: context.w(110),
                                height: context.h(48),
                                child: OutlinedButton(
                                  onPressed:
                                      isBusy ? null : () => _back(context),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.lightBlue700,
                                    side: const BorderSide(
                                      color: AppColors.lightBlue700,
                                      width: 1,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(50),
                                    ),
                                    backgroundColor: Colors.transparent,
                                    elevation: 0,
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
                                width: context.w(116),
                                height: context.h(48),
                                child: ElevatedButton(
                                  onPressed:
                                      isBusy ? null : () => _generate(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.lightBlue700,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(50),
                                    ),
                                  ),
                                  child: isBusy
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
                                          'Generate',
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
                          SizedBox(height: context.h(14)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (state.isGenerating)
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
                      CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.lightBlue700,
                      ),
                      SizedBox(height: context.h(14)),
                      Text(
                        'Preparing your career plan...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: context.sp(15).clamp(14.0, 16.0),
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.grey50 : AppColors.blue900,
                        ),
                      ),
                      SizedBox(height: context.h(8)),
                      Text(
                        'Please wait while your personalized roadmap is being prepared. This may take a few minutes, so keep the app open.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: context.sp(12).clamp(11.0, 13.0),
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                          color: isDark ? AppColors.grey400 : AppColors.grey700,
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

class _GuidanceRangesCard extends StatelessWidget {
  final int minimumWeeks;
  final int suitableWeeks;
  final int maximumWeeks;
  final String studyIntensity;
  final bool isDark;

  const _GuidanceRangesCard({
    required this.minimumWeeks,
    required this.suitableWeeks,
    required this.maximumWeeks,
    required this.studyIntensity,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF111A38) : AppColors.grey50;
    final border =
        isDark ? const Color(0xFF2A8AA2).withOpacity(0.25) : AppColors.grey300;
    final titleColor = isDark ? AppColors.grey50 : AppColors.blue900;
    final bodyColor = isDark ? AppColors.grey300 : AppColors.grey800;

    return Container(
      padding: EdgeInsets.all(context.w(14)),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(context.r(14)),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recommended Time Guidance',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: context.sp(14).clamp(13.0, 15.0),
              fontWeight: FontWeight.w800,
              color: titleColor,
            ),
          ),
          SizedBox(height: context.h(6)),
          Text(
            'Preview range based on the current selected skills. Warnings below update from the backend when you change weeks or hours.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: context.sp(12).clamp(11.0, 13.0),
              fontWeight: FontWeight.w500,
              height: 1.35,
              color: bodyColor,
            ),
          ),
          SizedBox(height: context.h(10)),
          Row(
            children: [
              Expanded(
                child: _RangeItem(
                  title: 'Minimum',
                  value: '$minimumWeeks',
                  subtitle: 'weeks',
                  color: const Color(0xFFFF4D4F),
                  isDark: isDark,
                ),
              ),
              SizedBox(width: context.w(8)),
              Expanded(
                child: _RangeItem(
                  title: 'Suitable',
                  value: '$suitableWeeks',
                  subtitle: 'weeks',
                  color: const Color(0xFF22C55E),
                  isDark: isDark,
                ),
              ),
              SizedBox(width: context.w(8)),
              Expanded(
                child: _RangeItem(
                  title: 'Maximum',
                  value: '$maximumWeeks',
                  subtitle: 'weeks',
                  color: const Color(0xFF2196F3),
                  isDark: isDark,
                ),
              ),
            ],
          ),
          if (studyIntensity.trim().isNotEmpty) ...[
            SizedBox(height: context.h(10)),
            Text(
              'Study intensity: ${_prettyText(studyIntensity)}',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: context.sp(12).clamp(11.0, 13.0),
                fontWeight: FontWeight.w600,
                color: bodyColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RangeItem extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final bool isDark;

  const _RangeItem({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.w(8),
        vertical: context.h(10),
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(context.r(12)),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: context.sp(10).clamp(9.0, 11.0),
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          SizedBox(height: context.h(4)),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: context.sp(18).clamp(16.0, 20.0),
              fontWeight: FontWeight.w900,
              color: isDark ? AppColors.grey50 : AppColors.blue900,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: context.sp(10).clamp(9.0, 11.0),
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.grey400 : AppColors.grey700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GuidanceMessageCard extends StatelessWidget {
  final String message;
  final String note;
  final bool isDark;

  const _GuidanceMessageCard({
    required this.message,
    required this.note,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark
        ? const Color(0xFF111A38)
        : const Color(0xFF268299).withOpacity(0.08);
    final border = isDark
        ? const Color(0xFF2A8AA2).withOpacity(0.35)
        : const Color(0xFF268299).withOpacity(0.25);
    final titleColor = isDark ? AppColors.grey50 : AppColors.blue900;
    final bodyColor = isDark ? AppColors.grey300 : AppColors.grey800;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.w(14)),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(context.r(14)),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Timeline Recommendation',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: context.sp(13).clamp(12.0, 14.0),
              fontWeight: FontWeight.w800,
              color: titleColor,
            ),
          ),
          SizedBox(height: context.h(8)),
          Text(
            message.replaceAll('\\n', '\n'),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: context.sp(12).clamp(11.0, 13.0),
              fontWeight: FontWeight.w600,
              height: 1.35,
              color: bodyColor,
            ),
          ),
          if (note.trim().isNotEmpty) ...[
            SizedBox(height: context.h(8)),
            Text(
              note,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: context.sp(11).clamp(10.0, 12.0),
                fontWeight: FontWeight.w500,
                height: 1.35,
                color: isDark ? AppColors.grey400 : AppColors.grey700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  final String title;
  final String message;
  final bool isDark;

  const _LoadingCard({
    required this.title,
    required this.message,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.w(14)),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111A38) : AppColors.grey50,
        borderRadius: BorderRadius.circular(context.r(14)),
        border: Border.all(
          color: isDark
              ? const Color(0xFF2A8AA2).withOpacity(0.25)
              : AppColors.grey300,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: context.w(22),
            height: context.w(22),
            child: const CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF268299),
            ),
          ),
          SizedBox(width: context.w(12)),
          Expanded(
            child: Text(
              '$title\n$message',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: context.sp(12).clamp(11.0, 13.0),
                fontWeight: FontWeight.w600,
                height: 1.35,
                color: isDark ? AppColors.grey300 : AppColors.grey800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineInfoText extends StatelessWidget {
  final String text;
  final bool isDark;

  const _InlineInfoText({required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: context.sp(12).clamp(11.0, 13.0),
        fontWeight: FontWeight.w600,
        color: isDark ? AppColors.grey400 : AppColors.grey700,
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  final String message;
  final bool isDark;

  const _ErrorText({
    required this.message,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: context.sp(12).clamp(11.0, 13.0),
        fontWeight: FontWeight.w700,
        color: isDark ? AppColors.red300 : AppColors.red600,
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final String label;
  final int value;
  final String suffix;
  final bool enabled;
  final VoidCallback onInc;
  final VoidCallback onDec;

  const _TimelineRow({
    required this.label,
    required this.value,
    required this.suffix,
    required this.enabled,
    required this.onInc,
    required this.onDec,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final fieldBg = isDark ? const Color(0xFF111A38) : const Color(0xFFF8F8F8);
    final fieldBorder =
        isDark ? const Color(0xFF2A8AA2) : const Color(0xFF268299);
    final textColor = isDark ? AppColors.grey50 : const Color(0xFF0F111D);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: context.w(56),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: context.sp(16).clamp(14.0, 16.0),
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.grey50 : AppColors.blue900,
            ),
          ),
        ),
        SizedBox(width: context.w(8)),
        Expanded(
          child: Container(
            height: context.h(44),
            padding: EdgeInsets.symmetric(horizontal: context.w(14)),
            decoration: BoxDecoration(
              color: fieldBg,
              borderRadius: BorderRadius.circular(context.r(8)),
              border: Border.all(color: fieldBorder, width: 1),
            ),
            child: Row(
              children: [
                Text(
                  '$value',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: context.sp(14).clamp(12.0, 15.0),
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const Spacer(),
                Text(
                  suffix,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: context.sp(11).clamp(10.0, 12.0),
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
                SizedBox(width: context.w(8)),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    InkWell(
                      onTap: enabled ? onInc : null,
                      child: Icon(
                        Icons.keyboard_arrow_up_rounded,
                        size: context.icon(18),
                        color: enabled ? textColor : textColor.withOpacity(0.4),
                      ),
                    ),
                    InkWell(
                      onTap: enabled ? onDec : null,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: context.icon(18),
                        color: enabled ? textColor : textColor.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ResetButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _ResetButton({
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF268299);

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Container(
          height: context.h(34),
          padding: EdgeInsets.symmetric(horizontal: context.w(16)),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(50),
          ),
          child: Center(
            child: Text(
              'Reset to Recommended',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: context.sp(12).clamp(11.0, 13.0),
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final String title;
  final String message;
  final String hint;
  final bool isDark;
  final Color color;
  final IconData icon;

  const _FeedbackCard({
    required this.title,
    required this.message,
    required this.hint,
    required this.isDark,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark
        ? Color.alphaBlend(color.withOpacity(0.12), const Color(0xFF111A38))
        : color.withOpacity(0.08);
    final border = color.withOpacity(isDark ? 0.55 : 0.28);
    final bodyColor = isDark ? AppColors.grey200 : AppColors.grey800;
    final hintColor = isDark ? AppColors.grey400 : AppColors.grey700;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.w(14)),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(context.r(14)),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: context.icon(22), color: color),
          SizedBox(width: context.w(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: context.sp(14).clamp(13.0, 15.0),
                    fontWeight: FontWeight.w800,
                    color: color,
                    height: 1.25,
                  ),
                ),
                if (message.trim().isNotEmpty) ...[
                  SizedBox(height: context.h(6)),
                  Text(
                    message,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: context.sp(12).clamp(11.0, 13.0),
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                      color: bodyColor,
                    ),
                  ),
                ],
                if (hint.trim().isNotEmpty) ...[
                  SizedBox(height: context.h(8)),
                  Text(
                    'Hint: $hint',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: context.sp(12).clamp(11.0, 13.0),
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                      color: hintColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _friendlyBackendError(String raw) {
  final text = raw.trim();
  final lower = text.toLowerCase();

  if (lower.contains('422') ||
      lower.contains('unprocessable') ||
      lower.contains('validation')) {
    return 'Timeline validation failed. Please go back to Skills, confirm your selected skills, then try Generate again.';
  }

  if (lower.contains('timeout')) {
    return 'The plan is taking longer than expected. Please keep the app open and try again if it does not finish.';
  }

  if (lower.contains('connection')) {
    return 'Could not connect to the plan service. Make sure the server is running and your phone is on the same Wi-Fi.';
  }

  return text.replaceFirst('Exception: ', '');
}

String _prettyText(String raw) {
  final s = raw.replaceAll('_', ' ').trim();
  if (s.isEmpty) return raw;
  return s
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

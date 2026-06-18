import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../providers/career_build_provider.dart';
import '../widgets/career_build_step_indicator.dart';

class CreatePlanStep2Screen extends ConsumerStatefulWidget {
  const CreatePlanStep2Screen({super.key});

  @override
  ConsumerState<CreatePlanStep2Screen> createState() =>
      _CreatePlanStep2ScreenState();
}

class _CreatePlanStep2ScreenState extends ConsumerState<CreatePlanStep2Screen> {
  void _back(BuildContext context) => context.go('/career-build/create/step-1');

  Future<void> _next(BuildContext context) async {
    final notifier = ref.read(careerBuildProvider.notifier);
    final ok = await notifier.confirmSkillsAndGoNext();

    if (!mounted) return;

    if (ok) {
      context.go('/career-build/create/step-3');
    } else {
      final error = ref.read(careerBuildProvider).backendError ??
          'Please select at least one skill.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(careerBuildProvider);
    final notifier = ref.read(careerBuildProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final fit = state.analysis?.fitAnalysis;
    final warnings = fit?.warnings ?? const <String>[];
    final missingCore = fit?.missingCoreSkills ?? const <String>[];
    final skillsToLearn = state.userSkills
        .where((s) => s.status == 'missing' || s.status == 'partial')
        .toList();
    final currentCvSkills =
        state.userSkills.where((s) => s.status == 'has').toList();

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
                                onPressed: state.isConfirmSkillsLoading
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
                            currentStep: 2,
                            totalSteps: 4,
                          ),
                          SizedBox(height: context.h(18)),
                          if (state.analysis != null) ...[
                            _AnalysisSummaryCard(
                              trackName: state.analysis!.trackName,
                              detectedLevel: state.analysis!.detectedLevel,
                              requiredLevel: state.analysis!.requiredLevel,
                              fitStatus: fit?.fitStatus,
                              fitScore: fit?.fitScore,
                              canGeneratePlan: fit?.canGeneratePlan,
                              isDark: isDark,
                            ),
                            SizedBox(height: context.h(14)),
                          ],
                          if (warnings.isNotEmpty ||
                              missingCore.isNotEmpty) ...[
                            _WarningsCard(
                              warnings: warnings,
                              missingCoreSkills: missingCore,
                              isDark: isDark,
                            ),
                            SizedBox(height: context.h(14)),
                          ],
                          Text(
                            'Skills You Need to Learn',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: context.sp(14).clamp(13.0, 15.0),
                              fontWeight: FontWeight.w700,
                              color:
                                  isDark ? AppColors.grey50 : AppColors.blue900,
                            ),
                          ),
                          SizedBox(height: context.h(6)),
                          Text(
                            'These are required track skills that your CV shows as missing or below the required level. Select the skills you want included in your learning plan.',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: context.sp(12).clamp(11.0, 13.0),
                              fontWeight: FontWeight.w500,
                              height: 1.25,
                              color: isDark
                                  ? AppColors.grey400
                                  : AppColors.grey800,
                            ),
                          ),
                          SizedBox(height: context.h(10)),
                          _SelectableMissingChipsWrap(
                            skills: skillsToLearn,
                            onToggle: (s) {
                              notifier.toggleSkillSelection(s.id);
                            },
                          ),
                          SizedBox(height: context.h(18)),
                          Text(
                            'Current Skills From CV',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: context.sp(14).clamp(13.0, 15.0),
                              fontWeight: FontWeight.w700,
                              color:
                                  isDark ? AppColors.grey50 : AppColors.blue900,
                            ),
                          ),
                          SizedBox(height: context.h(6)),
                          Text(
                            'These are required track skills that were detected in your CV. You can include them for improvement and adjust your current level if needed.',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: context.sp(12).clamp(11.0, 13.0),
                              fontWeight: FontWeight.w500,
                              height: 1.25,
                              color: isDark
                                  ? AppColors.grey400
                                  : AppColors.grey800,
                            ),
                          ),
                          SizedBox(height: context.h(12)),
                          if (currentCvSkills.isEmpty)
                            _EmptyCurrentSkillsCard(isDark: isDark)
                          else
                            ...currentCvSkills.map(
                              (s) => Padding(
                                padding: EdgeInsets.only(bottom: context.h(12)),
                                child: _SkillLevelPicker(
                                  skill: s,
                                  value: s.level,
                                  onToggleSelected: () {
                                    notifier.toggleSkillSelection(s.id);
                                  },
                                  onPickLevel: (lvl) {
                                    if (lvl == null) return;
                                    notifier.setSkillLevel(
                                      skillId: s.id,
                                      level: lvl,
                                    );
                                  },
                                  onNotSure: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'No worries — pick your best estimate. You can change it later.',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          if (state.backendError != null) ...[
                            SizedBox(height: context.h(10)),
                            _ErrorBox(
                              message: state.backendError!,
                              isDark: isDark,
                            ),
                          ],
                          SizedBox(height: context.h(18)),
                          FigmaBackNextButtons(
                            isLoading: state.isConfirmSkillsLoading,
                            onBack: () => _back(context),
                            onNext: () => _next(context),
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
          if (state.isConfirmSkillsLoading)
            Container(
              color: Colors.black.withOpacity(0.18),
              child: Center(
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: context.w(24)),
                  padding: EdgeInsets.all(context.w(18)),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF111A38) : Colors.white,
                    borderRadius: BorderRadius.circular(context.r(16)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFF268299),
                      ),
                      SizedBox(height: context.h(14)),
                      Text(
                        'Confirming your skills...',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: context.sp(15).clamp(14.0, 16.0),
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.grey50 : AppColors.blue900,
                        ),
                      ),
                      SizedBox(height: context.h(8)),
                      Text(
                        'We are updating your skill gaps and preparing the timeline guidance.',
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

class _AnalysisSummaryCard extends StatelessWidget {
  final String trackName;
  final String detectedLevel;
  final String requiredLevel;
  final String? fitStatus;
  final double? fitScore;
  final bool? canGeneratePlan;
  final bool isDark;

  const _AnalysisSummaryCard({
    required this.trackName,
    required this.detectedLevel,
    required this.requiredLevel,
    required this.fitStatus,
    required this.fitScore,
    required this.canGeneratePlan,
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
            trackName,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: context.sp(15).clamp(14.0, 16.0),
              fontWeight: FontWeight.w800,
              color: titleColor,
            ),
          ),
          SizedBox(height: context.h(8)),
          Wrap(
            spacing: context.w(8),
            runSpacing: context.h(8),
            children: [
              _MiniInfoChip(
                label: 'Detected: ${_prettyText(detectedLevel)}',
                isDark: isDark,
              ),
              _MiniInfoChip(
                label: 'Required: ${_prettyText(requiredLevel)}',
                isDark: isDark,
              ),
              if (fitStatus != null && fitStatus!.trim().isNotEmpty)
                _MiniInfoChip(
                  label:
                      'Fit: ${_prettyText(fitStatus!)}${fitScore == null ? '' : ' (${fitScore!.toStringAsFixed(1)}%)'}',
                  isDark: isDark,
                ),
            ],
          ),
          if (canGeneratePlan == false) ...[
            SizedBox(height: context.h(10)),
            Text(
              'Your profile is currently far from this track. The backend will generate a foundation recovery plan that focuses on the most important missing foundations first.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: context.sp(12).clamp(11.0, 13.0),
                fontWeight: FontWeight.w600,
                height: 1.35,
                color: bodyColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniInfoChip extends StatelessWidget {
  final String label;
  final bool isDark;

  const _MiniInfoChip({
    required this.label,
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
        border: Border.all(color: figmaTeal.withOpacity(0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: context.sp(11).clamp(10.0, 12.0),
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.grey50 : AppColors.blue900,
        ),
      ),
    );
  }
}

class _WarningsCard extends StatelessWidget {
  final List<String> warnings;
  final List<String> missingCoreSkills;
  final bool isDark;

  const _WarningsCard({
    required this.warnings,
    required this.missingCoreSkills,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final allItems = [
      ...warnings,
      if (missingCoreSkills.isNotEmpty)
        'Missing core skills: ${missingCoreSkills.join(', ')}',
    ];

    return Container(
      padding: EdgeInsets.all(context.w(14)),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFFF4C430).withOpacity(0.10)
            : const Color(0xFFF4C430).withOpacity(0.13),
        borderRadius: BorderRadius.circular(context.r(14)),
        border: Border.all(
          color: const Color(0xFFF4C430).withOpacity(0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: const Color(0xFFF4C430),
                size: context.icon(18),
              ),
              SizedBox(width: context.w(8)),
              Text(
                'Track Fit Notes',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: context.sp(14).clamp(13.0, 15.0),
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.grey50 : AppColors.blue900,
                ),
              ),
            ],
          ),
          SizedBox(height: context.h(8)),
          ...allItems.map(
            (w) => Padding(
              padding: EdgeInsets.only(bottom: context.h(6)),
              child: Text(
                '• $w',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: context.sp(12).clamp(11.0, 13.0),
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  color: isDark ? AppColors.grey200 : AppColors.grey800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  final bool isDark;

  const _ErrorBox({
    required this.message,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.w(12)),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.red300.withOpacity(0.10)
            : AppColors.red600.withOpacity(0.08),
        borderRadius: BorderRadius.circular(context.r(12)),
        border: Border.all(
          color: isDark
              ? AppColors.red300.withOpacity(0.35)
              : AppColors.red600.withOpacity(0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: context.icon(18),
            color: isDark ? AppColors.red300 : AppColors.red600,
          ),
          SizedBox(width: context.w(8)),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: context.sp(12).clamp(11.0, 13.0),
                fontWeight: FontWeight.w600,
                height: 1.35,
                color: isDark ? AppColors.red300 : AppColors.red600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySkillsCard extends StatelessWidget {
  final bool isDark;

  const _EmptySkillsCard({required this.isDark});

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
        'No reviewable skills were returned. Please go back and analyze your CV again.',
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

class _EmptyCurrentSkillsCard extends StatelessWidget {
  final bool isDark;

  const _EmptyCurrentSkillsCard({required this.isDark});

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
        'No current skills were confidently detected from your CV for this track.',
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

class _SelectableMissingChipsWrap extends StatelessWidget {
  final List<SkillUiModel> skills;
  final ValueChanged<SkillUiModel> onToggle;

  const _SelectableMissingChipsWrap({
    required this.skills,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const figmaTeal = Color(0xFF268299);

    if (skills.isEmpty) {
      return Text(
        'No missing or partial skills were returned. Your CV may already match the selected track requirements.',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: context.sp(12).clamp(11.0, 13.0),
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.grey400 : AppColors.grey700,
        ),
      );
    }

    return Wrap(
      spacing: context.w(8),
      runSpacing: context.h(8),
      children: skills.map((s) {
        final isSelected = s.selected;

        return InkWell(
          onTap: () => onToggle(s),
          borderRadius: BorderRadius.circular(context.r(24)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.symmetric(
              horizontal: context.w(10),
              vertical: context.h(8),
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? figmaTeal
                  : (isDark ? const Color(0xFF111A38) : AppColors.grey50),
              borderRadius: BorderRadius.circular(context.r(24)),
              border: Border.all(
                color: isSelected
                    ? figmaTeal
                    : (isDark ? const Color(0xFF2A8AA2) : AppColors.grey300),
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: figmaTeal.withOpacity(0.22),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : const [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (s.isCore) ...[
                  Icon(
                    Icons.star_rounded,
                    size: context.icon(14),
                    color: isSelected ? Colors.white : const Color(0xFFF4C430),
                  ),
                  SizedBox(width: context.w(4)),
                ],
                Text(
                  s.title,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: context.sp(12).clamp(11.0, 13.0),
                    color: isSelected
                        ? Colors.white
                        : (isDark ? AppColors.grey50 : AppColors.blue900),
                  ),
                ),
                SizedBox(width: context.w(6)),
                Icon(
                  isSelected ? Icons.check : Icons.add,
                  size: context.icon(16),
                  color: isSelected
                      ? Colors.white
                      : (isDark ? AppColors.grey50 : AppColors.blue900),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class FigmaBackNextButtons extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onNext;
  final bool isLoading;

  const FigmaBackNextButtons({
    super.key,
    required this.onBack,
    required this.onNext,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    const figmaTeal = Color(0xFF268299);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SizedBox(
          width: context.w(110),
          height: context.h(48),
          child: OutlinedButton(
            onPressed: isLoading ? null : onBack,
            style: OutlinedButton.styleFrom(
              foregroundColor: figmaTeal,
              side: const BorderSide(color: figmaTeal, width: 1),
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
                fontSize: context.sp(14).clamp(13.0, 15.0),
              ),
            ),
          ),
        ),
        SizedBox(
          width: context.w(110),
          height: context.h(48),
          child: ElevatedButton(
            onPressed: isLoading ? null : onNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: figmaTeal,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50),
              ),
            ),
            child: isLoading
                ? SizedBox(
                    width: context.w(18),
                    height: context.w(18),
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Next',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: context.sp(14).clamp(13.0, 15.0),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _SkillLevelPicker extends StatefulWidget {
  final SkillUiModel skill;
  final SkillLevel? value;
  final ValueChanged<SkillLevel?> onPickLevel;
  final VoidCallback onNotSure;
  final VoidCallback onToggleSelected;

  const _SkillLevelPicker({
    required this.skill,
    required this.value,
    required this.onPickLevel,
    required this.onNotSure,
    required this.onToggleSelected,
  });

  @override
  State<_SkillLevelPicker> createState() => _SkillLevelPickerState();
}

class _SkillLevelPickerState extends State<_SkillLevelPicker> {
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _fieldKey = GlobalKey();
  OverlayEntry? _overlay;

  @override
  void dispose() {
    _hide();
    super.dispose();
  }

  RenderBox? _fieldRenderBox() {
    final ctx = _fieldKey.currentContext;
    if (ctx == null) return null;
    return ctx.findRenderObject() as RenderBox?;
  }

  double _fieldWidth(BuildContext context) {
    final box = _fieldRenderBox();
    if (box == null) return MediaQuery.of(context).size.width;
    return box.size.width;
  }

  bool _shouldShowAbove(BuildContext context, double overlayHeight) {
    final box = _fieldRenderBox();
    if (box == null) return false;

    final topLeft = box.localToGlobal(Offset.zero);
    final fieldTop = topLeft.dy;
    final fieldBottom = topLeft.dy + box.size.height;

    final mq = MediaQuery.of(context);
    final screenH = mq.size.height;
    final paddingTop = mq.padding.top;
    final paddingBottom = mq.padding.bottom;

    final spaceAbove = fieldTop - paddingTop;
    final spaceBelow = (screenH - paddingBottom) - fieldBottom;

    if (spaceBelow >= overlayHeight) return false;
    if (spaceAbove >= overlayHeight) return true;
    return spaceAbove > spaceBelow;
  }

  void _show() {
    if (_overlay != null) return;

    _overlay = OverlayEntry(
      builder: (overlayContext) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final width = _fieldWidth(overlayContext);
        final levels = SkillLevel.values;
        final maxH = context.h(260);

        final itemH = context.h(44);
        final desiredH = (levels.length + 1) * itemH + context.h(16);
        final overlayH = desiredH > maxH ? maxH : desiredH;

        final showAbove = _shouldShowAbove(overlayContext, overlayH);
        final offset = showAbove
            ? Offset(0, -(overlayH + context.h(8)))
            : Offset(0, context.h(52));

        final bg = isDark ? const Color(0xFF111A38) : const Color(0xFFF8F8F8);
        final border =
            isDark ? const Color(0xFF2A8AA2) : const Color(0xFF268299);
        final textColor = isDark ? AppColors.grey50 : const Color(0xFF111827);

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: _hide,
                behavior: HitTestBehavior.translucent,
              ),
            ),
            Positioned(
              width: width,
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: offset,
                child: Material(
                  color: Colors.transparent,
                  elevation: 10,
                  child: Container(
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(context.r(8)),
                      border: Border.all(color: border, width: 1.5),
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: maxH),
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          vertical: context.h(8),
                          horizontal: context.w(16),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ...levels.map((lvl) {
                              return InkWell(
                                onTap: () {
                                  widget.onPickLevel(lvl);
                                  _hide();
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.symmetric(
                                    vertical: context.h(12),
                                  ),
                                  child: Text(
                                    lvl.label,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w500,
                                      fontSize:
                                          context.sp(16).clamp(14.0, 18.0),
                                      color: textColor,
                                    ),
                                  ),
                                ),
                              );
                            }),
                            InkWell(
                              onTap: () {
                                widget.onNotSure();
                                _hide();
                              },
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(
                                  vertical: context.h(12),
                                ),
                                child: Text(
                                  'Not sure',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w500,
                                    fontSize: context.sp(16).clamp(14.0, 18.0),
                                    color: textColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context, rootOverlay: true).insert(_overlay!);
  }

  void _hide() {
    _overlay?.remove();
    _overlay = null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final fieldBg = isDark ? const Color(0xFF111A38) : const Color(0xFFF8F8F8);
    final fieldBorder =
        isDark ? const Color(0xFF2A8AA2) : const Color(0xFFACACAC);
    final textColor = isDark ? AppColors.grey50 : const Color(0xFF111827);
    final hintColor = isDark ? AppColors.grey400 : const Color(0xFF6B7280);
    final arrowColor = isDark ? AppColors.grey200 : const Color(0xFF111827);

    return Container(
      padding: EdgeInsets.all(context.w(12)),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111A38) : AppColors.grey50,
        borderRadius: BorderRadius.circular(context.r(14)),
        border: Border.all(
          color: widget.skill.selected
              ? const Color(0xFF268299)
              : (isDark ? const Color(0xFF2A8AA2) : AppColors.grey300),
          width: widget.skill.selected ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: widget.skill.selected,
                onChanged: (_) => widget.onToggleSelected(),
                activeColor: const Color(0xFF268299),
              ),
              Expanded(
                child: Text(
                  widget.skill.title,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: context.sp(12).clamp(11.0, 13.0),
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.grey200 : AppColors.blue900,
                  ),
                ),
              ),
              if (widget.skill.isCore)
                Icon(
                  Icons.star_rounded,
                  size: context.icon(18),
                  color: const Color(0xFFF4C430),
                ),
            ],
          ),
          SizedBox(height: context.h(4)),
          Wrap(
            spacing: context.w(8),
            runSpacing: context.h(6),
            children: [
              _SmallSkillMeta(
                label: 'Status: ${_prettyText(widget.skill.status)}',
                isDark: isDark,
              ),
              _SmallSkillMeta(
                label:
                    'Required level: ${_prettyText(widget.skill.requiredLevel)}',
                isDark: isDark,
              ),
              if (widget.skill.gapScore > 0)
                _SmallSkillMeta(
                  label:
                      'Gap: ${(widget.skill.gapScore * 100).toStringAsFixed(0)}%',
                  isDark: isDark,
                ),
            ],
          ),
          SizedBox(height: context.h(10)),
          CompositedTransformTarget(
            link: _layerLink,
            child: InkWell(
              onTap: _show,
              borderRadius: BorderRadius.circular(context.r(8)),
              child: Container(
                key: _fieldKey,
                height: context.h(48),
                padding: EdgeInsets.symmetric(horizontal: context.w(16)),
                decoration: BoxDecoration(
                  color: fieldBg,
                  borderRadius: BorderRadius.circular(context.r(8)),
                  border: Border.all(color: fieldBorder, width: 1),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.value == null
                            ? 'Select Level'
                            : widget.value!.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: context.sp(14).clamp(13.0, 16.0),
                          fontWeight: FontWeight.w500,
                          color: widget.value == null ? hintColor : textColor,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: arrowColor,
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

class _SmallSkillMeta extends StatelessWidget {
  final String label;
  final bool isDark;

  const _SmallSkillMeta({
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.w(8),
        vertical: context.h(5),
      ),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF2A8AA2).withOpacity(0.12)
            : const Color(0xFF268299).withOpacity(0.08),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: context.sp(10).clamp(9.0, 11.0),
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.grey200 : AppColors.blue900,
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

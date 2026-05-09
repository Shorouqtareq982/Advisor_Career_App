import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../providers/ai_portfolio_provider.dart';

class PortfolioAboutMeCard extends ConsumerStatefulWidget {
  final bool initiallyExpanded;
  final bool isSelected;
  final VoidCallback? onSelected;

  const PortfolioAboutMeCard({
    super.key,
    this.initiallyExpanded = false,
    this.isSelected = false,
    this.onSelected,
  });

  @override
  ConsumerState<PortfolioAboutMeCard> createState() =>
      _PortfolioAboutMeCardState();
}

class _PortfolioAboutMeCardState extends ConsumerState<PortfolioAboutMeCard> {
  late bool isExpanded;

  final _summaryController = TextEditingController();
  final _coreStrengthsController = TextEditingController();
  final _careerFocusController = TextEditingController();
  final _industriesController = TextEditingController();

  static const _lightCardColor = Color(0xFFF8F8F8);
  static const _darkCardColor = Color(0xFF131A3B);
  static const _lightBorderColor = Color(0xFF686868);
  static const _darkBorderColor = Color(0xFFB8BCC8);
  static const _sectionShadow = BoxShadow(
    color: Color(0x40000000),
    offset: Offset(4, 4),
    blurRadius: 4,
    spreadRadius: 0,
  );

  @override
  void initState() {
    super.initState();
    isExpanded = widget.initiallyExpanded;

    final aboutMe = ref.read(aiPortfolioProvider).aboutMe;
    _summaryController.text = aboutMe.professionalSummary;
  }

  @override
  void didUpdateWidget(covariant PortfolioAboutMeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initiallyExpanded != oldWidget.initiallyExpanded) {
      isExpanded = widget.initiallyExpanded;
    }
  }

  @override
  void dispose() {
    _summaryController.dispose();
    _coreStrengthsController.dispose();
    _careerFocusController.dispose();
    _industriesController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() => isExpanded = !isExpanded);
    widget.onSelected?.call();
  }

  void _addItemsFromController({
    required TextEditingController controller,
    required void Function(String value) onAdd,
  }) {
    final raw = controller.text.trim();
    if (raw.isEmpty) return;

    final parts =
        raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    for (final item in parts) {
      onAdd(item);
    }
    controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiPortfolioProvider);
    final notifier = ref.read(aiPortfolioProvider.notifier);
    final aboutMe = state.aboutMe;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardColor = isDark ? _darkCardColor : _lightCardColor;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F111D);
    final subtitleColor =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF686868);
    final borderColor = isDark ? _darkBorderColor : _lightBorderColor;

    if (_summaryController.text != aboutMe.professionalSummary) {
      _summaryController.value = TextEditingValue(
        text: aboutMe.professionalSummary,
        selection: TextSelection.collapsed(
          offset: aboutMe.professionalSummary.length,
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: double.infinity,
      padding: EdgeInsets.all(context.w(16)),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(context.r(8)),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: const [_sectionShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(context.r(8)),
            onTap: _toggleExpanded,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'About Me',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: context.sp(16).clamp(15.0, 16.0),
                          color: titleColor,
                        ),
                      ),
                      SizedBox(height: context.h(6)),
                      Text(
                        'Tell your professional story',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                          fontSize: context.sp(13).clamp(12.0, 13.0),
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: titleColor,
                  size: context.w(28),
                ),
              ],
            ),
          ),
          if (isExpanded) ...[
            SizedBox(height: context.h(18)),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(context.w(12)),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF1A2145) : const Color(0xFFEBEBEB),
                borderRadius: BorderRadius.circular(context.r(8)),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFFB8BCC8)
                      : const Color(0xFFACACAC),
                  width: 1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x24000000),
                    offset: Offset(2, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AboutMeMultilineField(
                    label: 'Professional Summary',
                    controller: _summaryController,
                    hintText:
                        'Tell your story briefly — what you do, what\ndrives you, and what makes you unique.\n(2–4 sentences)',
                    onChanged: notifier.updateAboutSummary,
                  ),
                  SizedBox(height: context.h(16)),
                  _YearsOfExperienceField(
                    value: aboutMe.yearsOfExperience,
                    onIncrement: () => notifier.updateAboutYearsOfExperience(
                      aboutMe.yearsOfExperience + 1,
                    ),
                    onDecrement: () => notifier.updateAboutYearsOfExperience(
                      aboutMe.yearsOfExperience > 0
                          ? aboutMe.yearsOfExperience - 1
                          : 0,
                    ),
                  ),
                  SizedBox(height: context.h(16)),
                  _ChipInputField(
                    label: 'Core Strengths',
                    hintText: 'e.g. Problem Solving, Creativity',
                    controller: _coreStrengthsController,
                    values: aboutMe.coreStrengths,
                    onAdd: () => _addItemsFromController(
                      controller: _coreStrengthsController,
                      onAdd: notifier.addAboutCoreStrength,
                    ),
                    onRemove: notifier.removeAboutCoreStrength,
                  ),
                  SizedBox(height: context.h(14)),
                  _ChipInputField(
                    label: 'Career Focus (Optional)',
                    hintText: 'e.g. UI/UX Design, Data Analysis',
                    controller: _careerFocusController,
                    values: aboutMe.careerFocus,
                    onAdd: () => _addItemsFromController(
                      controller: _careerFocusController,
                      onAdd: notifier.addAboutCareerFocus,
                    ),
                    onRemove: notifier.removeAboutCareerFocus,
                  ),
                  SizedBox(height: context.h(14)),
                  _ChipInputField(
                    label: 'Industries Worked In (Optional)',
                    hintText: 'e.g. Healthcare, E-commerce',
                    controller: _industriesController,
                    values: aboutMe.industriesWorkedIn,
                    onAdd: () => _addItemsFromController(
                      controller: _industriesController,
                      onAdd: notifier.addAboutIndustry,
                    ),
                    onRemove: notifier.removeAboutIndustry,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AboutMeMultilineField extends StatelessWidget {
  final String label;
  final String hintText;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _AboutMeMultilineField({
    required this.label,
    required this.hintText,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _FieldShell(
      label: label,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        maxLines: 4,
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
          fontSize: context.sp(13).clamp(12.0, 13.0),
          color: isDark ? Colors.white : const Color(0xFF0F111D),
          height: 1.2,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
            fontSize: context.sp(13).clamp(12.0, 13.0),
            color: isDark ? const Color(0xFFB5B5C3) : const Color(0xFF8E8E8E),
            height: 1.2,
          ),
          isDense: true,
          filled: true,
          fillColor: isDark ? const Color(0xFF131A3B) : const Color(0xFFF8F8F8),
          contentPadding: EdgeInsets.symmetric(
            horizontal: context.w(14),
            vertical: context.h(14),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(context.r(8)),
            borderSide: BorderSide(
              color: isDark ? const Color(0xFFB8BCC8) : const Color(0xFFACACAC),
              width: 1,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(context.r(8)),
            borderSide: BorderSide(
              color: isDark ? const Color(0xFFB8BCC8) : const Color(0xFFACACAC),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(context.r(8)),
            borderSide: const BorderSide(
              color: Color(0xFF268299),
              width: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _YearsOfExperienceField extends StatelessWidget {
  final int value;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _YearsOfExperienceField({
    required this.value,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _FieldShell(
      label: 'Years of Experience',
      child: Container(
        height: context.h(40),
        padding: EdgeInsets.symmetric(horizontal: context.w(14)),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131A3B) : const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(context.r(8)),
          border: Border.all(
            color: const Color(0xFF29C5F6),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '$value',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  fontSize: context.sp(13).clamp(12.0, 13.0),
                  color: isDark ? Colors.white : const Color(0xFF0F111D),
                ),
              ),
            ),
            SizedBox(
              width: context.w(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  InkWell(
                    onTap: onIncrement,
                    child: Icon(
                      Icons.keyboard_arrow_up,
                      size: 18,
                      color: isDark ? Colors.white : const Color(0xFF0F111D),
                    ),
                  ),
                  InkWell(
                    onTap: onDecrement,
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      size: 18,
                      color: isDark ? Colors.white : const Color(0xFF0F111D),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: context.w(8)),
            Text(
              'Years',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                fontSize: context.sp(11).clamp(11.0, 11.0),
                color: isDark ? Colors.white : const Color(0xFF0F111D),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipInputField extends StatelessWidget {
  final String label;
  final String hintText;
  final TextEditingController controller;
  final List<String> values;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  const _ChipInputField({
    required this.label,
    required this.hintText,
    required this.controller,
    required this.values,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldShell(
          label: label,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: context.h(32),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF131A3B)
                        : const Color(0xFFF8F8F8),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFFB8BCC8)
                          : const Color(0xFFACACAC),
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: controller,
                    onSubmitted: (_) => onAdd(),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                      fontSize: context.sp(13).clamp(12.0, 13.0),
                      color: isDark ? Colors.white : const Color(0xFF0F111D),
                    ),
                    decoration: InputDecoration(
                      hintText: hintText,
                      hintStyle: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                        fontSize: context.sp(13).clamp(12.0, 13.0),
                        color: isDark
                            ? const Color(0xFFB5B5C3)
                            : const Color(0xFF8E8E8E),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: context.w(14),
                        vertical: context.h(8),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: context.w(8)),
              InkWell(
                onTap: onAdd,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: context.w(36),
                  height: context.h(32),
                  decoration: BoxDecoration(
                    color: AppColors.lightBlue700,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.add,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (values.isNotEmpty) ...[
          SizedBox(height: context.h(8)),
          Wrap(
            spacing: context.w(10),
            runSpacing: context.h(8),
            children: values.map((item) {
              return Container(
                height: context.h(32),
                padding: EdgeInsets.symmetric(
                  horizontal: context.w(16),
                  vertical: context.h(8),
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF268299),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: const Color(0xFF268299),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                        fontSize: context.sp(13).clamp(12.0, 13.0),
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: context.w(8)),
                    InkWell(
                      onTap: () => onRemove(item),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

class _FieldShell extends StatelessWidget {
  final String label;
  final Widget child;

  const _FieldShell({
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: context.w(4), bottom: context.h(6)),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
              fontSize: context.sp(11).clamp(11.0, 11.0),
              color: isDark ? Colors.white : const Color(0xFF0F111D),
              height: 1.2,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

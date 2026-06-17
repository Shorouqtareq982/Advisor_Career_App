import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../providers/ai_portfolio_provider.dart';
import 'portfolio_text_field.dart';

class EducationSection extends ConsumerStatefulWidget {
  final bool initiallyExpanded;
  final bool isSelected;
  final VoidCallback? onSelected;

  const EducationSection({
    super.key,
    this.initiallyExpanded = false,
    this.isSelected = false,
    this.onSelected,
  });

  @override
  ConsumerState<EducationSection> createState() => _EducationSectionState();
}

class _EducationSectionState extends ConsumerState<EducationSection> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  void didUpdateWidget(covariant EducationSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initiallyExpanded != oldWidget.initiallyExpanded) {
      _isExpanded = widget.initiallyExpanded;
    }
  }

  void _toggleExpanded() {
    final notifier = ref.read(aiPortfolioProvider.notifier);
    setState(() => _isExpanded = !_isExpanded);
    notifier.toggleEducationExpanded();
    widget.onSelected?.call();
  }

  void _addEducation() {
    final notifier = ref.read(aiPortfolioProvider.notifier);
    notifier.addEducationEntry();
    setState(() {
      _isExpanded = true;
    });
    widget.onSelected?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(aiPortfolioProvider);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: double.infinity,
      padding: EdgeInsets.all(context.w(16)),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131A3B) : const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(context.r(8)),
        border: Border.all(
          color: isDark ? const Color(0xFFB8BCC8) : const Color(0xFF686868),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            offset: Offset(4, 4),
            blurRadius: 4,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: _toggleExpanded,
            borderRadius: BorderRadius.circular(context.r(8)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Education',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: context.sp(16).clamp(15.0, 16.0),
                          color:
                              isDark ? Colors.white : const Color(0xFF0F111D),
                        ),
                      ),
                      SizedBox(height: context.h(6)),
                      Text(
                        'Your academic background',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                          fontSize: context.sp(13).clamp(12.0, 13.0),
                          color: isDark
                              ? const Color(0xFF9CA3AF)
                              : const Color(0xFF686868),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _isExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: context.w(24),
                  color: isDark ? Colors.white : const Color(0xFF0F111D),
                ),
              ],
            ),
          ),
          if (_isExpanded) ...[
            SizedBox(height: context.h(16)),
            if (state.educationEntries.isEmpty)
              _DashedAddButton(
                label: 'Add Education',
                onTap: _addEducation,
              )
            else ...[
              ...List.generate(
                state.educationEntries.length,
                (index) => Padding(
                  padding: EdgeInsets.only(
                    bottom: index == state.educationEntries.length - 1
                        ? context.h(16)
                        : context.h(12),
                  ),
                  child: _EducationEntryCard(
                    entry: state.educationEntries[index],
                    index: index,
                  ),
                ),
              ),
              _DashedAddButton(
                label: 'Add Education',
                onTap: _addEducation,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _EducationEntryCard extends ConsumerStatefulWidget {
  final EducationEntryModel entry;
  final int index;

  const _EducationEntryCard({
    required this.entry,
    required this.index,
  });

  @override
  ConsumerState<_EducationEntryCard> createState() =>
      _EducationEntryCardState();
}

class _EducationEntryCardState extends ConsumerState<_EducationEntryCard> {
  late bool _isExpanded;

  late final TextEditingController _institutionController;
  late final TextEditingController _degreeController;
  late final TextEditingController _fieldController;
  late final TextEditingController _locationController;
  late final TextEditingController _gpaController;
  late final TextEditingController _descriptionController;

  final TextEditingController _minorController = TextEditingController();
  final TextEditingController _courseworkController = TextEditingController();

  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  late final List<String> _years = _generateYears();

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.entry.isExpanded;

    _institutionController =
        TextEditingController(text: widget.entry.institutionName);
    _degreeController = TextEditingController(text: widget.entry.degree);
    _fieldController = TextEditingController(text: widget.entry.fieldOfStudy);
    _locationController = TextEditingController(text: widget.entry.location);
    _gpaController = TextEditingController(text: widget.entry.gpa);
    _descriptionController =
        TextEditingController(text: widget.entry.description);
  }

  @override
  void didUpdateWidget(covariant _EducationEntryCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.entry.isExpanded != widget.entry.isExpanded) {
      _isExpanded = widget.entry.isExpanded;
    }

    _syncController(_institutionController, widget.entry.institutionName);
    _syncController(_degreeController, widget.entry.degree);
    _syncController(_fieldController, widget.entry.fieldOfStudy);
    _syncController(_locationController, widget.entry.location);
    _syncController(_gpaController, widget.entry.gpa);
    _syncController(_descriptionController, widget.entry.description);
  }

  void _syncController(TextEditingController controller, String value) {
    if (controller.text != value) {
      controller.value = controller.value.copyWith(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
        composing: TextRange.empty,
      );
    }
  }

  List<String> _generateYears() {
    final currentYear = DateTime.now().year;
    const earliestYear = 1950;
    final latestYear = currentYear + 5;

    return List.generate(
      latestYear - earliestYear + 1,
      (index) => (latestYear - index).toString(),
    );
  }

  @override
  void dispose() {
    _institutionController.dispose();
    _degreeController.dispose();
    _fieldController.dispose();
    _locationController.dispose();
    _gpaController.dispose();
    _descriptionController.dispose();
    _minorController.dispose();
    _courseworkController.dispose();
    super.dispose();
  }

  void _addMinor() {
    final notifier = ref.read(aiPortfolioProvider.notifier);
    final value = _minorController.text.trim();
    if (value.isEmpty) return;

    notifier.addEducationMinor(widget.entry.id, value);
    _minorController.clear();
  }

  void _removeMinor(String value) {
    ref.read(aiPortfolioProvider.notifier).removeEducationMinor(
          widget.entry.id,
          value,
        );
  }

  void _addCoursework() {
    final notifier = ref.read(aiPortfolioProvider.notifier);
    final value = _courseworkController.text.trim();
    if (value.isEmpty) return;

    notifier.addEducationCoursework(widget.entry.id, value);
    _courseworkController.clear();
  }

  void _removeCoursework(String value) {
    ref.read(aiPortfolioProvider.notifier).removeEducationCoursework(
          widget.entry.id,
          value,
        );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notifier = ref.read(aiPortfolioProvider.notifier);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.w(12)),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2145) : const Color(0xFFEBEBEB),
        borderRadius: BorderRadius.circular(context.r(8)),
        border: Border.all(
          color: isDark ? const Color(0xFFB8BCC8) : const Color(0xFFACACAC),
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
          InkWell(
            onTap: () {
              notifier.toggleEducationEntry(widget.entry.id);
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(context.r(8)),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Education Entry ${widget.index + 1}',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: context.sp(16).clamp(15.0, 16.0),
                      color: isDark ? Colors.white : const Color(0xFF0F111D),
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => notifier.removeEducationEntry(widget.entry.id),
                  borderRadius: BorderRadius.circular(context.r(8)),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(
                      Icons.delete_outline,
                      color: Color(0xFFD03430),
                      size: 18,
                    ),
                  ),
                ),
                SizedBox(width: context.w(8)),
                Icon(
                  _isExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: context.w(20),
                  color: isDark ? Colors.white : const Color(0xFF0F111D),
                ),
              ],
            ),
          ),
          if (_isExpanded) ...[
            SizedBox(height: context.h(12)),
            PortfolioTextField(
              label: 'Institution Name',
              hintText: 'e.g. University of Alexandria',
              initialValue: widget.entry.institutionName,
              controller: _institutionController,
              onChanged: (value) => notifier.updateEducationInstitutionName(
                  widget.entry.id, value),
            ),
            SizedBox(height: context.h(12)),
            PortfolioTextField(
              label: 'Degree',
              hintText: 'e.g. Bachelor of Science',
              initialValue: widget.entry.degree,
              controller: _degreeController,
              onChanged: (value) =>
                  notifier.updateEducationDegree(widget.entry.id, value),
            ),
            SizedBox(height: context.h(12)),
            PortfolioTextField(
              label: 'Field of Study',
              hintText: 'e.g. Computer Science',
              initialValue: widget.entry.fieldOfStudy,
              controller: _fieldController,
              onChanged: (value) =>
                  notifier.updateEducationFieldOfStudy(widget.entry.id, value),
            ),
            SizedBox(height: context.h(12)),
            PortfolioTextField(
              label: 'Location',
              hintText: 'e.g. Alex, Egypt',
              initialValue: widget.entry.location,
              controller: _locationController,
              onChanged: (value) =>
                  notifier.updateEducationLocation(widget.entry.id, value),
            ),
            SizedBox(height: context.h(12)),
            Row(
              children: [
                Expanded(
                  child: _DateField(
                    label: 'Start Date',
                    monthValue: widget.entry.startMonth,
                    yearValue: widget.entry.startYear,
                    monthItems: _months,
                    yearItems: _years,
                    onMonthChanged: (value) => notifier
                        .updateEducationStartMonth(widget.entry.id, value),
                    onYearChanged: (value) => notifier.updateEducationStartYear(
                        widget.entry.id, value),
                  ),
                ),
                SizedBox(width: context.w(8)),
                Expanded(
                  child: widget.entry.currentlyStudying
                      ? const _PresentDateField(label: 'End Date')
                      : _DateField(
                          label: 'End Date',
                          monthValue: widget.entry.endMonth,
                          yearValue: widget.entry.endYear,
                          monthItems: _months,
                          yearItems: _years,
                          onMonthChanged: (value) => notifier
                              .updateEducationEndMonth(widget.entry.id, value),
                          onYearChanged: (value) => notifier
                              .updateEducationEndYear(widget.entry.id, value),
                        ),
                ),
              ],
            ),
            SizedBox(height: context.h(12)),
            InkWell(
              onTap: () => notifier.updateEducationCurrentlyStudying(
                widget.entry.id,
                !widget.entry.currentlyStudying,
              ),
              child: Row(
                children: [
                  _CustomCheckbox(value: widget.entry.currentlyStudying),
                  SizedBox(width: context.w(8)),
                  Text(
                    'Currently Studying',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                      fontSize: context.sp(13).clamp(12.0, 13.0),
                      color: isDark ? Colors.white : const Color(0xFF0F111D),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: context.h(12)),
            PortfolioTextField(
              label: 'GPA (Optional)',
              hintText: 'Only include if above 3.0',
              initialValue: widget.entry.gpa,
              controller: _gpaController,
              onChanged: (value) =>
                  notifier.updateEducationGpa(widget.entry.id, value),
            ),
            SizedBox(height: context.h(12)),
            _InlineAddField(
              label: 'Minor (Optional)',
              hintText: 'e.g. Data Science',
              controller: _minorController,
              onAdd: _addMinor,
            ),
            if (widget.entry.minors.isNotEmpty) ...[
              SizedBox(height: context.h(8)),
              _ChipWrap(
                items: widget.entry.minors,
                onRemove: _removeMinor,
              ),
            ],
            SizedBox(height: context.h(12)),
            _InlineAddField(
              label: 'Relevant Coursework (Optional)',
              hintText: 'e.g. Machine Learning, UX Design',
              controller: _courseworkController,
              onAdd: _addCoursework,
            ),
            if (widget.entry.coursework.isNotEmpty) ...[
              SizedBox(height: context.h(8)),
              _ChipWrap(
                items: widget.entry.coursework,
                onRemove: _removeCoursework,
              ),
            ],
            SizedBox(height: context.h(12)),
            PortfolioTextField(
              label: 'Description / Highlights (Optional)',
              hintText:
                  'Achievements, honors, projects, or\nanything that adds value (e.g. Graduation\nproject, awards, exchange programs...)',
              initialValue: widget.entry.description,
              controller: _descriptionController,
              onChanged: (value) =>
                  notifier.updateEducationDescription(widget.entry.id, value),
              maxLines: 4,
            ),
          ],
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final String? monthValue;
  final String? yearValue;
  final List<String> monthItems;
  final List<String> yearItems;
  final ValueChanged<String?> onMonthChanged;
  final ValueChanged<String?> onYearChanged;

  const _DateField({
    required this.label,
    required this.monthValue,
    required this.yearValue,
    required this.monthItems,
    required this.yearItems,
    required this.onMonthChanged,
    required this.onYearChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: label),
        SizedBox(height: context.h(6)),
        Row(
          children: [
            Expanded(
              child: _DateDropdown(
                hint: 'MM',
                value: monthValue,
                items: monthItems,
                onChanged: onMonthChanged,
              ),
            ),
            SizedBox(width: context.w(8)),
            Expanded(
              child: _DateDropdown(
                hint: 'YYYY',
                value: yearValue,
                items: yearItems,
                onChanged: onYearChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PresentDateField extends StatelessWidget {
  final String label;

  const _PresentDateField({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: label),
        SizedBox(height: context.h(6)),
        Container(
          height: context.h(32),
          padding: EdgeInsets.symmetric(horizontal: context.w(12)),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF131A3B)
                : const Color(0xFFF8F8F8),
            borderRadius: BorderRadius.circular(context.r(8)),
            border: Border.all(
              color: AppColors.lightBlue700,
              width: 1,
            ),
          ),
          child: Text(
            'Present',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
              fontSize: context.sp(13).clamp(12.0, 13.0),
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : const Color(0xFF0F111D),
            ),
          ),
        ),
      ],
    );
  }
}

class _DateDropdown extends StatelessWidget {
  final String hint;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _DateDropdown({
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  Future<void> _showOptions(BuildContext context) async {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        renderBox.localToGlobal(Offset.zero, ancestor: overlay),
        renderBox.localToGlobal(
          renderBox.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    final selected = await showMenu<String>(
      context: context,
      position: position,
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF131A3B)
          : const Color(0xFFF8F8F8),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(
          color: AppColors.lightBlue700,
          width: 1,
        ),
      ),
      items: items
          .map(
            (item) => PopupMenuItem<String>(
              value: item,
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                item,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : const Color(0xFF0F111D),
                ),
              ),
            ),
          )
          .toList(),
    );

    if (selected != null) {
      onChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayText = value ?? hint;

    return InkWell(
      onTap: () => _showOptions(context),
      borderRadius: BorderRadius.circular(context.r(8)),
      child: Container(
        height: context.h(32),
        padding: EdgeInsets.symmetric(horizontal: context.w(8)),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131A3B) : const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(context.r(8)),
          border: Border.all(
            color: AppColors.lightBlue700,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                displayText,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  fontSize: context.sp(13).clamp(12.0, 13.0),
                  color: isDark ? Colors.white : const Color(0xFF0F111D),
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: context.w(18),
              color: isDark ? Colors.white : const Color(0xFF0F111D),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineAddField extends StatelessWidget {
  final String label;
  final String hintText;
  final TextEditingController controller;
  final VoidCallback onAdd;

  const _InlineAddField({
    required this.label,
    required this.hintText,
    required this.controller,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: label),
        SizedBox(height: context.h(6)),
        Row(
          children: [
            Expanded(
              child: Container(
                height: context.h(32),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF131A3B)
                      : const Color(0xFFF8F8F8),
                  borderRadius: BorderRadius.circular(context.r(8)),
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
                    fontWeight: FontWeight.w400,
                    fontSize: context.sp(13).clamp(12.0, 13.0),
                    color: isDark ? Colors.white : const Color(0xFF0F111D),
                  ),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      fontSize: context.sp(13).clamp(12.0, 13.0),
                      color: isDark
                          ? const Color(0xFFB5B5C3)
                          : const Color(0xFF8E8E8E),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: context.w(12),
                      vertical: context.h(8),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: context.w(8)),
            InkWell(
              onTap: onAdd,
              borderRadius: BorderRadius.circular(context.r(8)),
              child: Container(
                width: context.w(36),
                height: context.h(32),
                decoration: BoxDecoration(
                  color: AppColors.lightBlue700,
                  borderRadius: BorderRadius.circular(context.r(8)),
                ),
                child: const Center(
                  child: Icon(
                    Icons.add,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ChipWrap extends StatelessWidget {
  final List<String> items;
  final ValueChanged<String> onRemove;

  const _ChipWrap({
    required this.items,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: context.w(8),
      runSpacing: context.h(8),
      children: items.map((item) {
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: context.w(12),
            vertical: context.h(6),
          ),
          decoration: BoxDecoration(
            color: AppColors.lightBlue700,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.lightBlue700,
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
                  fontSize: context.sp(12).clamp(11.0, 12.0),
                  color: Colors.white,
                ),
              ),
              SizedBox(width: context.w(6)),
              InkWell(
                onTap: () => onRemove(item),
                child: Icon(
                  Icons.close,
                  size: context.w(14),
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _CustomCheckbox extends StatelessWidget {
  final bool value;

  const _CustomCheckbox({
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: context.w(16),
      height: context.w(16),
      decoration: BoxDecoration(
        color: value
            ? const Color(0xFF268299)
            : (isDark ? const Color(0xFF131A3B) : const Color(0xFFF8F8F8)),
        borderRadius: BorderRadius.circular(context.r(4)),
        border: Border.all(
          color: const Color(0xFF268299),
          width: 1.5,
        ),
      ),
      child: value
          ? Icon(
              Icons.check,
              size: context.w(12),
              color: Colors.white,
            )
          : null,
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;

  const _FieldLabel({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Text(
      label,
      style: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w500,
        fontSize: context.sp(11).clamp(10.0, 11.0),
        color: isDark ? Colors.white : const Color(0xFF0F111D),
      ),
    );
  }
}

class _DashedAddButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DashedAddButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: AppColors.lightBlue700,
        radius: context.r(8),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.r(8)),
        child: Container(
          height: context.h(51),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add,
                size: context.w(16),
                color: AppColors.lightBlue700,
              ),
              SizedBox(width: context.w(8)),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: context.sp(16).clamp(15.0, 16.0),
                  color: AppColors.lightBlue700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  const _DashedBorderPainter({
    required this.color,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const dashWidth = 4.0;
    const dashSpace = 4.0;

    final rRect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rRect);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}

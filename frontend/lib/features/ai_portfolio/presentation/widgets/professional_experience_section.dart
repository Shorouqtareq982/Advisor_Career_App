import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../providers/ai_portfolio_provider.dart';

class ProfessionalExperienceSection extends ConsumerWidget {
  final bool isSelected;
  final VoidCallback? onSelected;

  const ProfessionalExperienceSection({
    super.key,
    this.isSelected = false,
    this.onSelected,
  });

  static const Color _lightCardColor = Color(0xFFF8F8F8);
  static const Color _darkCardColor = Color(0xFF131A3B);
  static const Color _lightBorderColor = Color(0xFF686868);
  static const Color _darkBorderColor = Color(0xFFB8BCC8);
  static const BoxShadow _sectionShadow = BoxShadow(
    color: Color(0x40000000),
    offset: Offset(4, 4),
    blurRadius: 4,
    spreadRadius: 0,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(aiPortfolioProvider);
    final notifier = ref.read(aiPortfolioProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: double.infinity,
      padding: EdgeInsets.all(context.w(16)),
      decoration: BoxDecoration(
        color: isDark ? _darkCardColor : _lightCardColor,
        borderRadius: BorderRadius.circular(context.r(8)),
        border: Border.all(
          color: isDark ? _darkBorderColor : _lightBorderColor,
          width: 1,
        ),
        boxShadow: const [_sectionShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(
            title: 'Professional Experience',
            subtitle: 'Where you worked and what you achieved',
            isExpanded: state.isProfessionalExperienceExpanded,
            onTap: () {
              onSelected?.call();
              notifier.toggleProfessionalExperienceExpanded();
            },
          ),
          if (state.isProfessionalExperienceExpanded) ...[
            SizedBox(height: context.h(16)),
            if (state.professionalExperienceEntries.isEmpty)
              _AddExperienceButton(
                onTap: notifier.addProfessionalExperienceEntry,
              )
            else ...[
              ...List.generate(
                state.professionalExperienceEntries.length,
                (index) => Padding(
                  padding: EdgeInsets.only(
                    bottom:
                        index == state.professionalExperienceEntries.length - 1
                            ? context.h(16)
                            : context.h(12),
                  ),
                  child: _ExperienceEntryCard(
                    index: index,
                    entry: state.professionalExperienceEntries[index],
                  ),
                ),
              ),
              _AddExperienceButton(
                onTap: notifier.addProfessionalExperienceEntry,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isExpanded;
  final VoidCallback onTap;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.r(8)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: context.sp(16).clamp(15.0, 16.0),
                    color: isDark ? Colors.white : const Color(0xFF0F111D),
                  ),
                ),
                SizedBox(height: context.h(6)),
                Text(
                  subtitle,
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
            isExpanded
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            color: isDark ? Colors.white : const Color(0xFF0F111D),
            size: context.w(28),
          ),
        ],
      ),
    );
  }
}

class _ExperienceEntryCard extends ConsumerWidget {
  final int index;
  final ProfessionalExperienceEntryModel entry;

  const _ExperienceEntryCard({
    required this.index,
    required this.entry,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(aiPortfolioProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          Row(
            children: [
              Expanded(
                child: Text(
                  'Experience Entry ${index + 1}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: context.sp(16).clamp(15.0, 16.0),
                    color: isDark ? Colors.white : const Color(0xFF0F111D),
                  ),
                ),
              ),
              InkWell(
                onTap: () =>
                    notifier.removeProfessionalExperienceEntry(entry.id),
                borderRadius: BorderRadius.circular(8),
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
              InkWell(
                onTap: () =>
                    notifier.toggleProfessionalExperienceEntry(entry.id),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    entry.isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: isDark ? Colors.white : const Color(0xFF0F111D),
                    size: context.w(20),
                  ),
                ),
              ),
            ],
          ),
          if (entry.isExpanded) ...[
            SizedBox(height: context.h(12)),
            _FieldLabel(label: 'Job Title'),
            SizedBox(height: context.h(6)),
            _EntryTextField(
              hintText: 'e.g. Senior UX Designer',
              initialValue: entry.jobTitle,
              onChanged: (value) =>
                  notifier.updateProfessionalExperienceJobTitle(
                entry.id,
                value,
              ),
            ),
            SizedBox(height: context.h(12)),
            _FieldLabel(label: 'Company Name'),
            SizedBox(height: context.h(6)),
            _EntryTextField(
              hintText: 'e.g. Tech Company Inc',
              initialValue: entry.companyName,
              onChanged: (value) =>
                  notifier.updateProfessionalExperienceCompanyName(
                entry.id,
                value,
              ),
            ),
            SizedBox(height: context.h(12)),
            _FieldLabel(label: 'Location'),
            SizedBox(height: context.h(6)),
            _EntryTextField(
              hintText: 'e.g. Alex, Egypt',
              initialValue: entry.location,
              onChanged: (value) =>
                  notifier.updateProfessionalExperienceLocation(
                entry.id,
                value,
              ),
            ),
            SizedBox(height: context.h(12)),
            _FieldLabel(label: 'Company URL (Optional)'),
            SizedBox(height: context.h(6)),
            _EntryTextField(
              hintText: 'e.g. https://company.com',
              initialValue: entry.companyUrl,
              onChanged: (value) =>
                  notifier.updateProfessionalExperienceCompanyUrl(
                entry.id,
                value,
              ),
            ),
            SizedBox(height: context.h(16)),
            Row(
              children: [
                Expanded(
                  child: _DateField(
                    label: 'Start Date',
                    monthValue: entry.startMonth,
                    yearValue: entry.startYear,
                    onMonthChanged: (value) =>
                        notifier.updateProfessionalExperienceStartMonth(
                      entry.id,
                      value,
                    ),
                    onYearChanged: (value) =>
                        notifier.updateProfessionalExperienceStartYear(
                      entry.id,
                      value,
                    ),
                  ),
                ),
                SizedBox(width: context.w(8)),
                Expanded(
                  child: entry.currentlyWorkingHere
                      ? const _PresentDateField(label: 'End Date')
                      : _DateField(
                          label: 'End Date',
                          monthValue: entry.endMonth,
                          yearValue: entry.endYear,
                          enabled: true,
                          onMonthChanged: (value) =>
                              notifier.updateProfessionalExperienceEndMonth(
                            entry.id,
                            value,
                          ),
                          onYearChanged: (value) =>
                              notifier.updateProfessionalExperienceEndYear(
                            entry.id,
                            value,
                          ),
                        ),
                ),
              ],
            ),
            SizedBox(height: context.h(12)),
            InkWell(
              onTap: () =>
                  notifier.updateProfessionalExperienceCurrentlyWorkingHere(
                entry.id,
                !entry.currentlyWorkingHere,
              ),
              child: Row(
                children: [
                  _CustomCheckbox(
                    value: entry.currentlyWorkingHere,
                  ),
                  SizedBox(width: context.w(8)),
                  Text(
                    'Currently working here',
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
            _FieldLabel(label: 'Description / Achievements'),
            SizedBox(height: context.h(6)),
            _EntryTextField(
              hintText:
                  'Describe your responsibilities,\nachievements, and impact...',
              initialValue: entry.description,
              maxLines: 3,
              minLines: 3,
              onChanged: (value) =>
                  notifier.updateProfessionalExperienceDescription(
                entry.id,
                value,
              ),
            ),
          ],
        ],
      ),
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

class _EntryTextField extends StatelessWidget {
  final String hintText;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final int maxLines;
  final int? minLines;

  const _EntryTextField({
    required this.hintText,
    required this.initialValue,
    required this.onChanged,
    this.maxLines = 1,
    this.minLines,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextFormField(
      initialValue: initialValue,
      onChanged: onChanged,
      maxLines: maxLines,
      minLines: minLines,
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
          fontWeight: FontWeight.w400,
          fontSize: context.sp(13).clamp(12.0, 13.0),
          color: isDark ? const Color(0xFFB5B5C3) : const Color(0xFF8E8E8E),
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF131A3B) : const Color(0xFFF8F8F8),
        contentPadding: EdgeInsets.symmetric(
          horizontal: context.w(12),
          vertical: context.h(10),
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
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(
            color: Color(0xFF268299),
            width: 1,
          ),
        ),
      ),
    );
  }
}

class _DateField extends ConsumerWidget {
  final String label;
  final String? monthValue;
  final String? yearValue;
  final bool enabled;
  final ValueChanged<String?> onMonthChanged;
  final ValueChanged<String?> onYearChanged;

  const _DateField({
    required this.label,
    required this.monthValue,
    required this.yearValue,
    required this.onMonthChanged,
    required this.onYearChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(aiPortfolioProvider.notifier);

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
                enabled: enabled,
                items: AIPortfolioNotifier.professionalExperienceMonths,
                onChanged: onMonthChanged,
              ),
            ),
            SizedBox(width: context.w(8)),
            Expanded(
              child: _DateDropdown(
                hint: 'YYYY',
                value: yearValue,
                enabled: enabled,
                items: notifier.professionalExperienceYears,
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
            color: const Color(0xFFF8F8F8),
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
              color: const Color(0xFF0F111D),
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
  final bool enabled;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _DateDropdown({
    required this.hint,
    required this.value,
    required this.enabled,
    required this.items,
    required this.onChanged,
  });

  Future<void> _showOptions(BuildContext context) async {
    if (!enabled) return;

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
      color: const Color(0xFFF8F8F8),
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
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF0F111D),
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
    final textColor = enabled
        ? (isDark ? Colors.white : const Color(0xFF0F111D))
        : const Color(0xFF9CA3AF);

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
            color: enabled ? AppColors.lightBlue700 : const Color(0xFF5B6075),
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
                  color: textColor,
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: context.w(18),
              color: textColor,
            ),
          ],
        ),
      ),
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

class _AddExperienceButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddExperienceButton({
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
                'Add Experience',
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

  _DashedBorderPainter({
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

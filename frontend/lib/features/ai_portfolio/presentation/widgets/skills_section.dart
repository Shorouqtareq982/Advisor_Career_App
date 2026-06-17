import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../providers/ai_portfolio_provider.dart';

class SkillsSection extends ConsumerStatefulWidget {
  final bool initiallyExpanded;
  final bool isSelected;
  final VoidCallback? onSelected;

  const SkillsSection({
    super.key,
    this.initiallyExpanded = false,
    this.isSelected = false,
    this.onSelected,
  });

  @override
  ConsumerState<SkillsSection> createState() => _SkillsSectionState();
}

class _SkillsSectionState extends ConsumerState<SkillsSection> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  void didUpdateWidget(covariant SkillsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initiallyExpanded != oldWidget.initiallyExpanded) {
      _isExpanded = widget.initiallyExpanded;
    }
  }

  void _toggleExpand() {
    setState(() => _isExpanded = !_isExpanded);
    widget.onSelected?.call();
    ref.read(aiPortfolioProvider.notifier).toggleSkillsExpanded();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiPortfolioProvider);
    final notifier = ref.read(aiPortfolioProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final skills = state.portfolio.skills;

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
            onTap: _toggleExpand,
            borderRadius: BorderRadius.circular(context.r(8)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Skills & Expertise',
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
                        'Showcase your expertise',
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
            if (skills.isEmpty)
              _DashedAddButton(
                label: 'Add Skill',
                onTap: notifier.addSkill,
              )
            else ...[
              ...List.generate(
                skills.length,
                (index) => Padding(
                  padding: EdgeInsets.only(
                    bottom: index == skills.length - 1
                        ? context.h(16)
                        : context.h(12),
                  ),
                  child: _SkillEntryCard(
                    index: index,
                    skillId: skills[index].id,
                  ),
                ),
              ),
              _DashedAddButton(
                label: 'Add Skill',
                onTap: notifier.addSkill,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _SkillEntryCard extends ConsumerStatefulWidget {
  final int index;
  final String skillId;

  const _SkillEntryCard({
    required this.index,
    required this.skillId,
  });

  @override
  ConsumerState<_SkillEntryCard> createState() => _SkillEntryCardState();
}

class _SkillEntryCardState extends ConsumerState<_SkillEntryCard> {
  bool _isExpanded = true;

  static const List<String> _categories = [
    'UI/UX Design',
    'Computer Vision',
    'Tools & Technologies',
    'Web Development',
    'Mobile Development',
    'Soft Skills',
  ];

  static const List<String> _levels = [
    'Beginner',
    'Intermediate',
    'Advanced',
    'Expert',
  ];

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiPortfolioProvider);
    final notifier = ref.read(aiPortfolioProvider.notifier);
    final skill =
        state.portfolio.skills.firstWhere((s) => s.id == widget.skillId);
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
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(context.r(8)),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Skill Entry ${widget.index + 1}',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: context.sp(16).clamp(15.0, 16.0),
                      color: isDark ? Colors.white : const Color(0xFF0F111D),
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => notifier.deleteSkill(widget.skillId),
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
            _SkillTextField(
              label: 'Skill Name',
              hintText: 'e.g. Figma, Python, User Research',
              initialValue: skill.skillName,
              onChanged: (value) => notifier.updateSkill(
                id: widget.skillId,
                skillName: value,
              ),
            ),
            SizedBox(height: context.h(12)),
            _SkillDropdownField(
              label: 'Category',
              hintText: 'Select category',
              items: _categories,
              value: skill.category,
              onChanged: (value) => notifier.updateSkill(
                id: widget.skillId,
                category: value,
              ),
            ),
            SizedBox(height: context.h(12)),
            _SkillDropdownField(
              label: 'Proficiency (Optional)',
              hintText: 'Enter Proficiency',
              items: _levels,
              value: skill.proficiency,
              onChanged: (value) => notifier.updateSkill(
                id: widget.skillId,
                proficiency: value,
              ),
            ),
            SizedBox(height: context.h(12)),
            _YearsStepperField(
              value: skill.yearsOfExperience,
              onIncrement: () => notifier.updateSkill(
                id: widget.skillId,
                yearsOfExperience: skill.yearsOfExperience + 1,
              ),
              onDecrement: () => notifier.updateSkill(
                id: widget.skillId,
                yearsOfExperience: skill.yearsOfExperience > 0
                    ? skill.yearsOfExperience - 1
                    : 0,
              ),
            ),
            SizedBox(height: context.h(12)),
            _SkillTextField(
              label: 'Description (Optional)',
              hintText: 'How did you use this skill?',
              initialValue: skill.description,
              onChanged: (value) => notifier.updateSkill(
                id: widget.skillId,
                description: value,
              ),
              maxLines: 4,
            ),
          ],
        ],
      ),
    );
  }
}

class _SkillTextField extends StatelessWidget {
  final String label;
  final String hintText;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final int maxLines;

  const _SkillTextField({
    required this.label,
    required this.hintText,
    required this.initialValue,
    required this.onChanged,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
            fontSize: context.sp(11).clamp(11.0, 11.0),
            color: isDark ? Colors.white : const Color(0xFF0F111D),
          ),
        ),
        SizedBox(height: context.h(6)),
        TextFormField(
          initialValue: initialValue,
          onChanged: onChanged,
          maxLines: maxLines,
          minLines: maxLines > 1 ? maxLines : 1,
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
              color: isDark ? const Color(0xFFB5B5C3) : const Color(0xFF8E8E8E),
            ),
            filled: true,
            fillColor:
                isDark ? const Color(0xFF131A3B) : const Color(0xFFF8F8F8),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(
              horizontal: context.w(14),
              vertical: context.h(10),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(context.r(8)),
              borderSide: BorderSide(
                color:
                    isDark ? const Color(0xFFB8BCC8) : const Color(0xFFACACAC),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(context.r(8)),
              borderSide: const BorderSide(
                color: AppColors.lightBlue700,
                width: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SkillDropdownField extends StatelessWidget {
  final String label;
  final String hintText;
  final List<String> items;
  final String value;
  final ValueChanged<String> onChanged;

  const _SkillDropdownField({
    required this.label,
    required this.hintText,
    required this.items,
    required this.value,
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

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final selected = await showMenu<String>(
      context: context,
      position: position,
      color: isDark ? const Color(0xFF131A3B) : const Color(0xFFF8F8F8),
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
                  color: isDark ? Colors.white : const Color(0xFF0F111D),
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
    final displayText = value.isEmpty ? hintText : value;
    final displayColor = value.isEmpty
        ? (isDark ? const Color(0xFFB5B5C3) : const Color(0xFF8E8E8E))
        : (isDark ? Colors.white : const Color(0xFF0F111D));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
            fontSize: context.sp(11).clamp(11.0, 11.0),
            color: isDark ? Colors.white : const Color(0xFF0F111D),
          ),
        ),
        SizedBox(height: context.h(6)),
        InkWell(
          onTap: () => _showOptions(context),
          borderRadius: BorderRadius.circular(context.r(8)),
          child: Container(
            height: context.h(40),
            padding: EdgeInsets.symmetric(horizontal: context.w(12)),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131A3B) : const Color(0xFFF8F8F8),
              borderRadius: BorderRadius.circular(context.r(8)),
              border: Border.all(
                color:
                    isDark ? const Color(0xFFB8BCC8) : const Color(0xFFACACAC),
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
                      fontWeight: FontWeight.w400,
                      fontSize: context.sp(13).clamp(12.0, 13.0),
                      color: displayColor,
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
        ),
      ],
    );
  }
}

class _YearsStepperField extends StatelessWidget {
  final int value;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _YearsStepperField({
    required this.value,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Years of Experience (Optional)',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
            fontSize: context.sp(11).clamp(11.0, 11.0),
            color: isDark ? Colors.white : const Color(0xFF0F111D),
          ),
        ),
        SizedBox(height: context.h(6)),
        Container(
          height: context.h(40),
          padding: EdgeInsets.symmetric(horizontal: context.w(14)),
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
      ],
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
                'Add Skill',
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

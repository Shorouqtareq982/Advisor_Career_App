import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../providers/ai_portfolio_provider.dart';
import 'project_entry_card.dart';

class ProjectsSection extends ConsumerWidget {
  final bool isSelected;
  final VoidCallback? onSelected;

  const ProjectsSection({
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
          _ProjectsHeader(
            isExpanded: state.isProjectsExpanded,
            onTap: () {
              onSelected?.call();
              notifier.toggleProjectsExpanded();
            },
          ),
          if (state.isProjectsExpanded) ...[
            SizedBox(height: context.h(16)),
            if (state.projectEntries.isEmpty)
              _AddProjectButton(
                onTap: notifier.addProjectEntry,
              )
            else ...[
              ...List.generate(
                state.projectEntries.length,
                (index) => Padding(
                  padding: EdgeInsets.only(bottom: context.h(12)),
                  child: ProjectEntryCard(
                    index: index,
                    entry: state.projectEntries[index],
                  ),
                ),
              ),
              _AddProjectButton(
                onTap: notifier.addProjectEntry,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ProjectsHeader extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onTap;

  const _ProjectsHeader({
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
                  'Projects',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: context.sp(16).clamp(15.0, 16.0),
                    color: isDark ? Colors.white : const Color(0xFF0F111D),
                  ),
                ),
                SizedBox(height: context.h(6)),
                Text(
                  'Showcase your best work',
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
            size: context.w(24),
            color: isDark ? Colors.white : const Color(0xFF0F111D),
          ),
        ],
      ),
    );
  }
}

class _AddProjectButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddProjectButton({
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
                'Add Project',
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

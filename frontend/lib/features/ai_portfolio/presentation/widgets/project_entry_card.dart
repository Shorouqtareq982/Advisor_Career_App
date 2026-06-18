import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../providers/ai_portfolio_provider.dart';
import 'portfolio_adaptive_image.dart';
import 'portfolio_text_field.dart';

class ProjectEntryCard extends ConsumerStatefulWidget {
  final int index;
  final ProjectEntryModel entry;

  const ProjectEntryCard({
    super.key,
    required this.index,
    required this.entry,
  });

  @override
  ConsumerState<ProjectEntryCard> createState() => _ProjectEntryCardState();
}

class _ProjectEntryCardState extends ConsumerState<ProjectEntryCard> {
  late final TextEditingController _toolsController;

  @override
  void initState() {
    super.initState();
    _toolsController = TextEditingController();
  }

  @override
  void dispose() {
    _toolsController.dispose();
    super.dispose();
  }

  void _handleAddTool() {
    final raw = _toolsController.text.trim();
    if (raw.isEmpty) return;

    ref.read(aiPortfolioProvider.notifier).addProjectTool(
          widget.entry.id,
          raw,
        );
    _toolsController.clear();
  }

  @override
  Widget build(BuildContext context) {
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
                  'Project Entry ${widget.index + 1}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: context.sp(16).clamp(15.0, 16.0),
                    color: isDark ? Colors.white : const Color(0xFF0F111D),
                  ),
                ),
              ),
              InkWell(
                onTap: () => notifier.removeProjectEntry(widget.entry.id),
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
                onTap: () => notifier.toggleProjectEntry(widget.entry.id),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    widget.entry.isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: isDark ? Colors.white : const Color(0xFF0F111D),
                    size: context.w(20),
                  ),
                ),
              ),
            ],
          ),
          if (widget.entry.isExpanded) ...[
            SizedBox(height: context.h(12)),
            PortfolioTextField(
              label: 'Project Title',
              hintText: 'e.g. E-commerce Platform',
              initialValue: widget.entry.title,
              onChanged: (value) =>
                  notifier.updateProjectTitle(widget.entry.id, value),
            ),
            SizedBox(height: context.h(12)),
            PortfolioTextField(
              label: 'Project Category (Optional)',
              hintText: 'e.g. Web Design, Mobile App',
              initialValue: widget.entry.category,
              onChanged: (value) =>
                  notifier.updateProjectCategory(widget.entry.id, value),
            ),
            SizedBox(height: context.h(12)),
            PortfolioTextField(
              label: 'Short Description',
              hintText:
                  'Brief overview of the project, your role,\nand the outcome',
              initialValue: widget.entry.shortDescription,
              onChanged: (value) => notifier.updateProjectShortDescription(
                widget.entry.id,
                value,
              ),
              maxLines: 3,
            ),
            SizedBox(height: context.h(12)),
            _FieldLabel(label: 'Tools & Technologies'),
            SizedBox(height: context.h(6)),
            Row(
              children: [
                Expanded(
                  child: _InlineTextField(
                    controller: _toolsController,
                    hintText: 'e.g. React, Figma, Firebase',
                    onSubmitted: (_) => _handleAddTool(),
                  ),
                ),
                SizedBox(width: context.w(8)),
                InkWell(
                  onTap: _handleAddTool,
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
            if (widget.entry.tools.isNotEmpty) ...[
              SizedBox(height: context.h(8)),
              Wrap(
                spacing: context.w(8),
                runSpacing: context.h(8),
                children: widget.entry.tools.map((tool) {
                  return _ToolChip(
                    label: tool,
                    onRemove: () =>
                        notifier.removeProjectTool(widget.entry.id, tool),
                  );
                }).toList(),
              ),
            ],
            SizedBox(height: context.h(12)),
            _FieldLabel(label: 'Project Links (Optional)'),
            SizedBox(height: context.h(6)),
            if (widget.entry.links.isNotEmpty) ...[
              ...List.generate(
                widget.entry.links.length,
                (index) => Padding(
                  padding: EdgeInsets.only(
                    bottom: index == widget.entry.links.length - 1
                        ? context.h(8)
                        : context.h(10),
                  ),
                  child: _ProjectLinkEntryCard(
                    projectId: widget.entry.id,
                    link: widget.entry.links[index],
                  ),
                ),
              ),
            ],
            _AddLinkButton(
              onTap: () => notifier.addProjectLink(widget.entry.id),
            ),
            SizedBox(height: context.h(12)),
            PortfolioTextField(
              label: 'Key Outcomes / Results (Optional)',
              hintText:
                  'e.g. Increased conversion by 30%,\nreduced load time by 50%...',
              initialValue: widget.entry.keyOutcomes,
              onChanged: (value) =>
                  notifier.updateProjectKeyOutcomes(widget.entry.id, value),
              maxLines: 3,
            ),
            SizedBox(height: context.h(12)),
            _ProjectUploadBox(
              label: 'Thumbnail / Cover Image (Optional)',
              filePath: widget.entry.coverImagePath,
              fileName: widget.entry.coverImageName,
              onTap: () => notifier.pickProjectCoverImage(widget.entry.id),
              onRemove: () => notifier.removeProjectCoverImage(widget.entry.id),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProjectLinkEntryCard extends ConsumerWidget {
  final String projectId;
  final ProjectLinkEntryModel link;

  const _ProjectLinkEntryCard({
    required this.projectId,
    required this.link,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(aiPortfolioProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.w(12)),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131A3B) : const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(context.r(8)),
        border: Border.all(
          color: isDark ? const Color(0xFFB8BCC8) : const Color(0xFFACACAC),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Link Entry',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: context.sp(16).clamp(15.0, 16.0),
                    color: isDark ? Colors.white : const Color(0xFF0F111D),
                  ),
                ),
              ),
              InkWell(
                onTap: () => notifier.removeProjectLink(projectId, link.id),
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
                onTap: () => notifier.toggleProjectLink(projectId, link.id),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    link.isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: isDark ? Colors.white : const Color(0xFF0F111D),
                    size: context.w(20),
                  ),
                ),
              ),
            ],
          ),
          if (link.isExpanded) ...[
            SizedBox(height: context.h(12)),
            PortfolioTextField(
              label: 'Link Label',
              hintText: 'e.g. Live App, GitHub, Case Study, Figma',
              initialValue: link.label,
              onChanged: (value) =>
                  notifier.updateProjectLinkLabel(projectId, link.id, value),
            ),
            SizedBox(height: context.h(12)),
            PortfolioTextField(
              label: 'URL',
              hintText: 'https://...',
              initialValue: link.url,
              onChanged: (value) =>
                  notifier.updateProjectLinkUrl(projectId, link.id, value),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProjectUploadBox extends StatelessWidget {
  final String label;
  final String? filePath;
  final String? fileName;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _ProjectUploadBox({
    required this.label,
    required this.filePath,
    required this.fileName,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F111D);
    final mutedColor =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF686868);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: label),
        SizedBox(height: context.h(6)),
        CustomPaint(
          painter: _DashedBorderPainter(
            color: isDark ? const Color(0xFFB8BCC8) : const Color(0xFFACACAC),
            radius: context.r(8),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(context.r(8)),
            child: Container(
              width: double.infinity,
              constraints: BoxConstraints(minHeight: context.h(44)),
              padding: EdgeInsets.symmetric(
                horizontal: context.w(12),
                vertical: context.h(10),
              ),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF131A3B) : const Color(0xFFF8F8F8),
                borderRadius: BorderRadius.circular(context.r(8)),
              ),
              child: filePath == null
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.file_upload_outlined,
                          size: context.w(16),
                          color: textColor,
                        ),
                        SizedBox(width: context.w(8)),
                        Flexible(
                          child: Text(
                            'click to upload',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w500,
                              fontSize: context.sp(13).clamp(12.0, 13.0),
                              color: textColor,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        SizedBox(
                          width: context.w(28),
                          height: context.w(28),
                          child: PortfolioAdaptiveImage(
                            imagePath: filePath,
                            width: context.w(28),
                            height: context.w(28),
                            fit: BoxFit.cover,
                            borderRadius: BorderRadius.circular(context.r(4)),
                            placeholder: Container(
                              color: isDark
                                  ? const Color(0xFF1A2145)
                                  : const Color(0xFFE0E0E0),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.image_outlined,
                                size: context.w(14),
                                color: mutedColor,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: context.w(10)),
                        Expanded(
                          child: Text(
                            fileName ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w500,
                              fontSize: context.sp(12).clamp(11.0, 12.0),
                              color: mutedColor,
                            ),
                          ),
                        ),
                        SizedBox(width: context.w(8)),
                        InkWell(
                          onTap: onRemove,
                          child: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Color(0xFFD03430),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InlineTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onSubmitted;

  const _InlineTextField({
    required this.controller,
    required this.hintText,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: context.h(32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131A3B) : const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(context.r(8)),
        border: Border.all(
          color: isDark ? const Color(0xFFB8BCC8) : const Color(0xFFACACAC),
          width: 1,
        ),
      ),
      child: TextField(
        controller: controller,
        onSubmitted: onSubmitted,
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
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: context.w(12),
            vertical: context.h(8),
          ),
        ),
      ),
    );
  }
}

class _ToolChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _ToolChip({
    required this.label,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
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
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                fontSize: context.sp(12).clamp(11.0, 12.0),
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(width: context.w(6)),
          InkWell(
            onTap: onRemove,
            child: Icon(
              Icons.close,
              size: context.w(14),
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddLinkButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddLinkButton({
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
          height: context.h(36),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add,
                size: context.w(14),
                color: AppColors.lightBlue700,
              ),
              SizedBox(width: context.w(8)),
              Text(
                'Add Link',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: context.sp(13).clamp(12.0, 13.0),
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

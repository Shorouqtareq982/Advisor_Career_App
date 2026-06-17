import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../providers/ai_portfolio_provider.dart';
import 'portfolio_text_field.dart';

class ContactSection extends ConsumerStatefulWidget {
  final bool initiallyExpanded;
  final bool isSelected;
  final VoidCallback? onSelected;

  const ContactSection({
    super.key,
    this.initiallyExpanded = false,
    this.isSelected = false,
    this.onSelected,
  });

  @override
  ConsumerState<ContactSection> createState() => _ContactSectionState();
}

class _ContactSectionState extends ConsumerState<ContactSection> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  void didUpdateWidget(covariant ContactSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initiallyExpanded != oldWidget.initiallyExpanded) {
      _isExpanded = widget.initiallyExpanded;
    }
  }

  void _toggleExpanded() {
    setState(() => _isExpanded = !_isExpanded);
    widget.onSelected?.call();
    ref.read(aiPortfolioProvider.notifier).toggleContactExpanded();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiPortfolioProvider);
    final notifier = ref.read(aiPortfolioProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                        'Contact',
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
                        'Let people reach you',
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
                  PortfolioTextField(
                    label: 'Email',
                    hintText: 'Enter Email',
                    initialValue: state.contactEmail,
                    onChanged: notifier.updateContactEmail,
                  ),
                  SizedBox(height: context.h(12)),
                  _PhoneField(
                    phoneCode: state.contactPhoneCode,
                    initialValue: state.contactPhoneNumber,
                    onChanged: notifier.updateContactPhoneNumber,
                  ),
                  SizedBox(height: context.h(12)),
                  PortfolioTextField(
                    label: 'Location (Optional)',
                    hintText: 'e.g. Alex, Egypt',
                    initialValue: state.contactLocation,
                    onChanged: notifier.updateContactLocation,
                  ),
                  SizedBox(height: context.h(12)),
                  Text(
                    'Links (Optional)',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: context.sp(16).clamp(15.0, 16.0),
                      color: isDark ? Colors.white : const Color(0xFF0F111D),
                    ),
                  ),
                  SizedBox(height: context.h(6)),
                  Text(
                    'Best for portfolio preview: LinkedIn, GitHub, WhatsApp',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                      fontSize: context.sp(13).clamp(12.0, 13.0),
                      color: isDark
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF686868),
                    ),
                  ),
                  SizedBox(height: context.h(10)),
                  Wrap(
                    spacing: context.w(8),
                    runSpacing: context.h(8),
                    children: [
                      _QuickLinkChip(
                        label: 'LinkedIn',
                        isDark: isDark,
                        onTap: () => notifier.addContactLink('LinkedIn'),
                      ),
                      _QuickLinkChip(
                        label: 'GitHub',
                        isDark: isDark,
                        onTap: () => notifier.addContactLink('GitHub'),
                      ),
                      _QuickLinkChip(
                        label: 'WhatsApp',
                        isDark: isDark,
                        onTap: () => notifier.addContactLink('WhatsApp'),
                      ),
                    ],
                  ),
                  SizedBox(height: context.h(12)),
                  if (state.contactLinks.isNotEmpty) ...[
                    ...List.generate(
                      state.contactLinks.length,
                      (index) => Padding(
                        padding: EdgeInsets.only(
                          bottom: index == state.contactLinks.length - 1
                              ? context.h(12)
                              : context.h(10),
                        ),
                        child: _LinkEntryCard(
                          value: state.contactLinks[index],
                          onDelete: () => notifier
                              .removeContactLink(state.contactLinks[index]),
                        ),
                      ),
                    ),
                  ],
                  _AddLinkField(
                    onAdd: (value) => notifier.addContactLink(
                      _normalizeContactLink(value),
                    ),
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

class _PhoneField extends StatelessWidget {
  final String phoneCode;
  final String initialValue;
  final ValueChanged<String> onChanged;

  const _PhoneField({
    required this.phoneCode,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Phone Number (Optional)',
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
          padding: EdgeInsets.symmetric(horizontal: context.w(10)),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131A3B) : const Color(0xFFF8F8F8),
            borderRadius: BorderRadius.circular(context.r(8)),
            border: Border.all(
              color: isDark ? const Color(0xFFB8BCC8) : const Color(0xFFACACAC),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: context.w(20),
                height: context.w(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(context.r(2)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(context.r(2)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(color: const Color(0xFFCE1126)),
                      Align(
                        alignment: Alignment.center,
                        child: Container(
                          height: context.w(7),
                          color: Colors.white,
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          height: context.w(7),
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: context.w(6)),
              Text(
                phoneCode,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                  fontSize: context.sp(13).clamp(12.0, 13.0),
                  color: isDark ? Colors.white : const Color(0xFF0F111D),
                ),
              ),
              SizedBox(width: context.w(8)),
              Container(
                width: 1,
                height: context.h(18),
                color:
                    isDark ? const Color(0xFFB8BCC8) : const Color(0xFFACACAC),
              ),
              SizedBox(width: context.w(10)),
              Expanded(
                child: TextFormField(
                  initialValue: initialValue,
                  onChanged: onChanged,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    fontSize: context.sp(13).clamp(12.0, 13.0),
                    color: isDark ? Colors.white : const Color(0xFF0F111D),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter Phone Number',
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
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LinkEntryCard extends StatelessWidget {
  final String value;
  final VoidCallback onDelete;

  const _LinkEntryCard({
    required this.value,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
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
      child: Row(
        children: [
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                fontSize: context.sp(13).clamp(12.0, 13.0),
                color: isDark ? Colors.white : const Color(0xFF0F111D),
              ),
            ),
          ),
          SizedBox(width: context.w(8)),
          InkWell(
            onTap: onDelete,
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
        ],
      ),
    );
  }
}

class _QuickLinkChip extends StatelessWidget {
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _QuickLinkChip({
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? const Color(0xFF131A3B) : const Color(0xFFF8F8F8),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: context.w(12),
            vertical: context.h(7),
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.lightBlue700,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: context.sp(12).clamp(11.0, 12.0),
              color: AppColors.lightBlue700,
            ),
          ),
        ),
      ),
    );
  }
}

class _AddLinkField extends StatefulWidget {
  final ValueChanged<String> onAdd;

  const _AddLinkField({
    required this.onAdd,
  });

  @override
  State<_AddLinkField> createState() => _AddLinkFieldState();
}

class _AddLinkFieldState extends State<_AddLinkField> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    widget.onAdd(value);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: AppColors.lightBlue700,
        radius: context.r(8),
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.w(10),
          vertical: context.h(6),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                onSubmitted: (_) => _submit(),
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  hintText: 'Add Link or type LinkedIn / GitHub / WhatsApp',
                  border: InputBorder.none,
                  isDense: true,
                  hintStyle: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                    fontSize: context.sp(14).clamp(13.0, 14.0),
                    color: AppColors.lightBlue700,
                  ),
                ),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  fontSize: context.sp(14).clamp(13.0, 14.0),
                  color: AppColors.lightBlue700,
                ),
              ),
            ),
            InkWell(
              onTap: _submit,
              borderRadius: BorderRadius.circular(context.r(8)),
              child: Icon(
                Icons.add,
                size: context.w(18),
                color: AppColors.lightBlue700,
              ),
            ),
          ],
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

String _normalizeContactLink(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return trimmed;

  final lower = trimmed.toLowerCase();

  if (lower == 'linkedin' || lower.contains('linkedin.com')) {
    return 'LinkedIn';
  }

  if (lower == 'github' || lower.contains('github.com')) {
    return 'GitHub';
  }

  if (lower == 'whatsapp' ||
      lower.contains('wa.me') ||
      lower.contains('whatsapp.com') ||
      lower.contains('whats app')) {
    return 'WhatsApp';
  }

  return trimmed;
}

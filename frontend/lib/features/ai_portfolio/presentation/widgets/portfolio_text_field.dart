import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';

class PortfolioTextField extends StatefulWidget {
  final String label;
  final String hintText;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final int maxLines;
  final TextEditingController? controller;

  const PortfolioTextField({
    super.key,
    required this.label,
    required this.hintText,
    required this.initialValue,
    required this.onChanged,
    this.maxLines = 1,
    this.controller,
  });

  @override
  State<PortfolioTextField> createState() => _PortfolioTextFieldState();
}

class _PortfolioTextFieldState extends State<PortfolioTextField> {
  late final TextEditingController _internalController;

  TextEditingController get _effectiveController =>
      widget.controller ?? _internalController;

  @override
  void initState() {
    super.initState();
    _internalController = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant PortfolioTextField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.controller == null &&
        oldWidget.initialValue != widget.initialValue &&
        _internalController.text != widget.initialValue) {
      _internalController.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _internalController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
            fontSize: context.sp(11).clamp(11.0, 11.0),
            color: isDark ? Colors.white : const Color(0xFF0F111D),
          ),
        ),
        SizedBox(height: context.h(6)),
        TextFormField(
          controller: _effectiveController,
          onChanged: widget.onChanged,
          maxLines: widget.maxLines,
          minLines: widget.maxLines > 1 ? widget.maxLines : 1,
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w400,
            fontSize: context.sp(13).clamp(12.0, 13.0),
            color: isDark ? Colors.white : const Color(0xFF0F111D),
          ),
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
              fontSize: context.sp(13).clamp(12.0, 13.0),
              color: isDark ? const Color(0xFFB5B5C3) : const Color(0xFF8E8E8E),
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF131A3B) : AppColors.grey50,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(
              horizontal: context.w(14),
              vertical: context.h(10),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(context.r(8)),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFFB8BCC8) : AppColors.grey600,
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../../../../core/theme/app_text_theme.dart';

class CustomTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hintText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final String? prefixText;
  final void Function(String)? onChanged;
  final String? errorText;
  final bool enabled;
  final bool useTheme;
  final Color? overrideBgColor;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.textInputAction,
    this.onFieldSubmitted,
    this.inputFormatters,
    this.prefixText,
    this.onChanged,
    this.errorText,
    this.enabled = true,
    this.useTheme = false,
    this.overrideBgColor,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _isFocused = false;
  String? _internalError;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  String? get _displayError {
    if (widget.errorText != null) return widget.errorText;
    return _internalError;
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        widget.useTheme && Theme.of(context).brightness == Brightness.dark;
    final textTheme = context.appTextTheme;

    Color getBorderColor() {
      if (_displayError != null) return AppColors.red600;
      if (_isFocused) {
        return isDark ? AppColors.lightBlue500 : AppColors.lightBlue700;
      }
      return widget.useTheme
          ? (isDark ? AppColors.blue400 : AppColors.grey600)
          : AppColors.grey600;
    }

    Color getFillColor() {
      if (!widget.enabled) return AppColors.grey50.withOpacity(0.5);
      if (widget.overrideBgColor != null) return widget.overrideBgColor!;
      return widget.useTheme
          ? (isDark ? const Color(0xFF1E2D4A) : AppColors.grey50)
          : AppColors.grey50;
    }

    Color getIconColor() {
      if (!widget.enabled) return AppColors.grey700.withOpacity(0.5);
      if (_isFocused) {
        return isDark ? AppColors.lightBlue500 : AppColors.lightBlue700;
      }
      return widget.useTheme
          ? (isDark ? AppColors.blue200 : AppColors.grey700)
          : AppColors.grey700;
    }

    Color getLabelColor() {
      if (!widget.enabled) return AppColors.blue900.withOpacity(0.5);
      return widget.useTheme
          ? (isDark ? AppColors.grey200 : AppColors.blue900)
          : AppColors.blue900;
    }

    Color getTextColor() {
      return widget.useTheme
          ? (isDark ? AppColors.grey50 : AppColors.blue900)
          : AppColors.blue900;
    }

    final borderColor = getBorderColor();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: context.h(56),
          child: TextFormField(
            controller: widget.controller,
            focusNode: _focusNode,
            obscureText: widget.obscureText,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            inputFormatters: widget.inputFormatters,
            enabled: widget.enabled,
            onChanged: (value) {
              if (_internalError != null) {
                setState(() => _internalError = null);
              }
              widget.onChanged?.call(value);
            },
            onFieldSubmitted: widget.onFieldSubmitted,
            style: context.responsiveText(
              textTheme.bodyRegular.copyWith(
                color: widget.enabled
                    ? getTextColor()
                    : getTextColor().withOpacity(0.5),
              ),
            ),
            decoration: InputDecoration(
              labelText: widget.label,
              labelStyle: context.responsiveText(
                textTheme.captionMedium.copyWith(color: getLabelColor()),
              ),
              floatingLabelBehavior: FloatingLabelBehavior.always,
              floatingLabelStyle: context.responsiveText(
                textTheme.captionMedium.copyWith(color: getLabelColor()),
              ),
              hintText: widget.hintText,
              hintStyle: context.responsiveText(
                textTheme.bodyRegular.copyWith(
                  color: widget.enabled
                      ? AppColors.grey700
                      : AppColors.grey700.withOpacity(0.5),
                ),
              ),
              prefixIcon: widget.prefixIcon != null
                  ? Icon(widget.prefixIcon,
                      color: getIconColor(), size: context.icon(20))
                  : null,
              prefixText: widget.prefixText,
              prefixStyle: context.responsiveText(
                textTheme.bodyMedium.copyWith(color: getTextColor()),
              ),
              suffixIcon: widget.suffixIcon,
              filled: true,
              fillColor: getFillColor(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: context.w(16),
                vertical: context.h(14),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(context.r(50)),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(context.r(50)),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(context.r(50)),
                borderSide: BorderSide(
                  color:
                      isDark ? AppColors.lightBlue500 : AppColors.lightBlue700,
                  width: 1.5,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(context.r(50)),
                borderSide: const BorderSide(color: AppColors.red600),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(context.r(50)),
                borderSide: const BorderSide(color: AppColors.red600),
              ),
              errorStyle: const TextStyle(height: 0, fontSize: 0),
              errorText: null,
            ),
            validator: (value) {
              if (!widget.enabled) return null;
              final error = widget.validator?.call(value);
              if (mounted) setState(() => _internalError = error);
              return error;
            },
          ),
        ),
        if (_displayError != null && widget.enabled)
          Padding(
            padding: EdgeInsets.only(left: context.w(16), top: context.h(6)),
            child: Row(
              children: [
                Icon(Icons.error_outline,
                    color: AppColors.red600, size: context.icon(14)),
                SizedBox(width: context.w(4)),
                Expanded(
                  child: context.text(
                    _displayError!,
                    style: textTheme.captionRegular
                        .copyWith(color: AppColors.red600),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

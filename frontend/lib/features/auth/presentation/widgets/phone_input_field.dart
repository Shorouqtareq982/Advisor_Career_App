import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../shared/models/country_model.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../../../../core/theme/app_text_theme.dart';
import 'country_selector.dart';

class PhoneInputField extends StatefulWidget {
  final TextEditingController controller;
  final Country selectedCountry;
  final ValueChanged<Country> onCountryChanged;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;
  final void Function(String)? onChanged;
  final String label;
  final String? errorText;
  final bool enabled;
  final bool useTheme;
  final Color? overrideBgColor;
  final Color? overrideEnabledBorderColor;
  final Color? overrideDisabledBorderColor;
  final double? overrideBorderRadius;
  final double? overrideBorderWidth;
  final Color? overrideTextColor;
  final Color? overrideLabelColor;
  final bool hideLabelAbove;

  const PhoneInputField({
    super.key,
    required this.controller,
    required this.selectedCountry,
    required this.onCountryChanged,
    this.validator,
    this.textInputAction,
    this.onFieldSubmitted,
    this.onChanged,
    this.label = 'Phone Number',
    this.errorText,
    this.enabled = true,
    this.useTheme = false,
    this.overrideBgColor,
    this.overrideEnabledBorderColor,
    this.overrideDisabledBorderColor,
    this.overrideBorderRadius,
    this.overrideBorderWidth,
    this.overrideTextColor,
    this.overrideLabelColor,
    this.hideLabelAbove = false,
  });

  @override
  State<PhoneInputField> createState() => PhoneInputFieldState();
}

class PhoneInputFieldState extends State<PhoneInputField> {
  bool _isFocused = false;
  String? _internalError;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) setState(() => _isFocused = _focusNode.hasFocus);
    });
    widget.controller.addListener(() {
      if (_internalError != null && mounted) {
        setState(() => _internalError = null);
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  String getFullPhoneNumber() {
    final phone = widget.controller.text.trim();
    final countryCode = widget.selectedCountry.dialCode;
    if (phone.isEmpty) return '';
    final cleanPhone = phone.replaceFirst(RegExp(r'^0+'), '');
    return '$countryCode$cleanPhone';
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
    final hasError = _displayError != null;

    final fillColor = widget.overrideBgColor ??
        (widget.useTheme
            ? (isDark ? const Color(0xFF1E2D4A) : AppColors.grey50)
            : AppColors.grey50);

    final enabledBorderColor = widget.overrideEnabledBorderColor ??
        (isDark ? AppColors.lightBlue500 : AppColors.lightBlue700);

    final disabledBorderColor = widget.overrideDisabledBorderColor ??
        (widget.useTheme
            ? (isDark ? AppColors.blue400 : AppColors.grey600)
            : AppColors.grey600);

    final textColor = widget.overrideTextColor ??
        (widget.useTheme
            ? (isDark ? AppColors.grey50 : AppColors.blue900)
            : AppColors.blue900);

    final labelColor = widget.overrideLabelColor ??
        (widget.useTheme
            ? (isDark ? AppColors.grey200 : AppColors.blue900)
            : AppColors.blue900);

    Color getBorderColor() {
      if (hasError) return AppColors.red600;
      if (_isFocused) return enabledBorderColor;
      return disabledBorderColor;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        InputDecorator(
          decoration: InputDecoration(
            labelText: widget.label,
            labelStyle: context.responsiveText(
              textTheme.captionMedium.copyWith(
                color: hasError ? AppColors.red600 : labelColor,
              ),
            ),
            floatingLabelBehavior: FloatingLabelBehavior.always,
            floatingLabelStyle: context.responsiveText(
              textTheme.captionMedium.copyWith(
                color: hasError ? AppColors.red600 : labelColor,
              ),
            ),
            filled: true,
            fillColor: fillColor,
            contentPadding: EdgeInsets.symmetric(
              horizontal: context.w(16),
              vertical: context.h(14),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                  context.r(widget.overrideBorderRadius ?? 50)),
              borderSide: BorderSide(color: getBorderColor()),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                  context.r(widget.overrideBorderRadius ?? 50)),
              borderSide: BorderSide(color: getBorderColor()),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                  context.r(widget.overrideBorderRadius ?? 50)),
              borderSide: BorderSide(
                color: enabledBorderColor,
                width: widget.overrideBorderWidth ?? 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                  context.r(widget.overrideBorderRadius ?? 50)),
              borderSide: const BorderSide(color: AppColors.red600),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                  context.r(widget.overrideBorderRadius ?? 50)),
              borderSide: const BorderSide(color: AppColors.red600),
            ),
            errorStyle: const TextStyle(height: 0, fontSize: 0),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Opacity(
                opacity: widget.enabled ? 1.0 : 0.45,
                child: CountrySelector(
                  selectedCountry: widget.selectedCountry,
                  onCountryChanged: (country) {
                    widget.onCountryChanged(country);
                    widget.controller.clear();
                    if (_internalError != null) {
                      setState(() => _internalError = null);
                    }
                  },
                  useTheme: widget.useTheme,
                ),
              ),
              Container(
                width: 1,
                height: context.h(24),
                color: isDark ? AppColors.blue400 : AppColors.grey600,
                margin: EdgeInsets.symmetric(horizontal: context.w(8)),
              ),
              Expanded(
                child: TextFormField(
                  enabled: widget.enabled,
                  controller: widget.controller,
                  focusNode: _focusNode,
                  keyboardType: TextInputType.phone,
                  textInputAction: widget.textInputAction,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(
                        widget.selectedCountry.phoneLength),
                  ],
                  style: context.responsiveText(
                    textTheme.bodyRegular.copyWith(
                      color: widget.enabled
                          ? textColor
                          : textColor.withOpacity(0.45),
                    ),
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                    hintText: 'Phone number',
                    hintStyle: context.responsiveText(
                      textTheme.bodyRegular.copyWith(color: AppColors.grey700),
                    ),
                    errorStyle: const TextStyle(height: 0, fontSize: 0),
                    errorText: null,
                  ),
                  onChanged: (value) {
                    if (_internalError != null) {
                      setState(() => _internalError = null);
                    }
                    widget.onChanged?.call(value);
                    setState(() {});
                  },
                  onFieldSubmitted: widget.onFieldSubmitted,
                  validator: (value) {
                    if (!widget.enabled) return null;
                    if (value == null || value.isEmpty) {
                      const error = 'Phone number is required';
                      setState(() => _internalError = error);
                      return error;
                    }
                    if (value.length != widget.selectedCountry.phoneLength) {
                      final error =
                          'Must be exactly ${widget.selectedCountry.phoneLength} digits';
                      setState(() => _internalError = error);
                      return error;
                    }
                    if (widget.validator != null) {
                      final error = widget.validator!(value);
                      setState(() => _internalError = error);
                      return error;
                    }
                    return null;
                  },
                ),
              ),
            ],
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

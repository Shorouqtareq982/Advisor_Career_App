import 'package:flutter/material.dart';
import '../../../../shared/models/country_model.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../../../../core/theme/app_text_theme.dart';

class CountrySelector extends StatelessWidget {
  final Country selectedCountry;
  final ValueChanged<Country> onCountryChanged;
  final bool useTheme;

  const CountrySelector({
    super.key,
    required this.selectedCountry,
    required this.onCountryChanged,
    this.useTheme = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = context.appTextTheme;

    Color getTextColor() {
      return useTheme
          ? (isDark ? AppColors.grey200 : AppColors.blue900)
          : AppColors.blue900;
    }

    Color getIconColor() {
      return useTheme
          ? (isDark ? Colors.grey.shade400 : AppColors.blue900)
          : AppColors.blue900;
    }

    return InkWell(
      onTap: () => _showCountryPicker(context),
      borderRadius: BorderRadius.circular(context.r(8)),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: context.h(4)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selectedCountry.flag,
              style: TextStyle(fontSize: context.sp(20)),
            ),
            SizedBox(width: context.w(4)),
            Flexible(
              child: context.text(
                selectedCountry.dialCode,
                style: textTheme.bodyMedium.copyWith(
                  color: getTextColor(),
                ),
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              color: getIconColor(),
              size: context.w(18),
            ),
          ],
        ),
      ),
    );
  }

  void _showCountryPicker(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = context.appTextTheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: useTheme
          ? (isDark ? const Color(0xFF1E1E2F) : AppColors.grey50)
          : AppColors.grey50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(context.r(20)),
        ),
      ),
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: EdgeInsets.symmetric(horizontal: context.w(16)),
          child: Column(
            children: [
              SizedBox(height: context.h(12)),
              // Drag handle
              Container(
                width: context.w(40),
                height: context.h(4),
                decoration: BoxDecoration(
                  color: useTheme
                      ? (isDark
                          ? Colors.grey.shade700
                          : AppColors.grey600.withOpacity(0.3))
                      : AppColors.grey600.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(context.r(2)),
                ),
              ),
              SizedBox(height: context.h(16)),
              // Title
              context.text(
                'Select Country',
                style: textTheme.title1Bold.copyWith(
                  color: useTheme
                      ? (isDark ? AppColors.grey50 : AppColors.blue900)
                      : AppColors.blue900,
                ),
              ),
              SizedBox(height: context.h(16)),
              // Countries list
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: Countries.all.length,
                  itemBuilder: (context, index) {
                    final country = Countries.all[index];
                    final isSelected = country.code == selectedCountry.code;

                    return ListTile(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: context.w(12),
                        vertical: context.h(4),
                      ),
                      leading: Container(
                        width: context.w(40),
                        height: context.h(40),
                        alignment: Alignment.center,
                        child: Text(
                          country.flag,
                          style: TextStyle(fontSize: context.sp(28)),
                        ),
                      ),
                      title: context.text(
                        country.name,
                        style: textTheme.bodyMedium.copyWith(
                          color: useTheme
                              ? (isDark ? AppColors.grey50 : AppColors.blue900)
                              : AppColors.blue900,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      trailing: context.text(
                        country.dialCode,
                        style: textTheme.bodyMedium.copyWith(
                          color: isSelected
                              ? AppColors.lightBlue700
                              : (useTheme
                                  ? (isDark
                                      ? Colors.grey.shade400
                                      : AppColors.grey800)
                                  : AppColors.grey800),
                        ),
                      ),
                      selected: isSelected,
                      selectedTileColor:
                          AppColors.lightBlue700.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(context.r(12)),
                      ),
                      onTap: () {
                        onCountryChanged(country);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
              SizedBox(height: context.h(16)),
            ],
          ),
        ),
      ),
    );
  }
}

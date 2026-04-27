import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';

class JobRatingWidget extends StatelessWidget {
  final int? selectedRating; // 1, 2, or 3
  final ValueChanged<int> onRatingSelected;

  const JobRatingWidget({
    super.key,
    required this.selectedRating,
    required this.onRatingSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        final rating = index + 1;
        return Padding(
          padding: EdgeInsets.only(right: index < 2 ? context.w(8) : 0),
          child: _RatingItem(
            rating: rating,
            isSelected: selectedRating == rating,
            isDark: isDark,
            onTap: () => onRatingSelected(rating),
          ),
        );
      }),
    );
  }
}

class _RatingItem extends StatelessWidget {
  final int rating;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _RatingItem({
    required this.rating,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  IconData get _faceIcon {
    switch (rating) {
      case 1:
        return Icons.sentiment_dissatisfied_outlined;
      case 2:
        return Icons.sentiment_neutral_outlined;
      case 3:
        return Icons.sentiment_satisfied_outlined;
      default:
        return Icons.sentiment_neutral_outlined;
    }
  }

  Color get _selectedBgColor {
    // Match Figma: teal/dark for dark mode, light blue for light mode
    return AppColors.lightBlue700;
  }

  Color get _selectedIconColor {
    switch (rating) {
      case 1:
        return AppColors.red400;
      case 2:
        return AppColors.orange400;
      case 3:
        return AppColors.green500;
      default:
        return AppColors.grey500;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = isSelected
        ? _selectedBgColor
        : (isDark ? AppColors.blue400 : AppColors.grey200);

    final iconColor = isSelected
        ? _selectedIconColor
        : (isDark ? AppColors.grey400 : AppColors.grey600);

    final borderColor = isSelected ? _selectedIconColor : Colors.transparent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: context.w(72),
        padding: EdgeInsets.symmetric(vertical: context.h(10)),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(context.r(12)),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2 : 0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _faceIcon,
              color: iconColor,
              size: context.icon(22),
            ),
            SizedBox(height: context.h(4)),
            Text(
              '$rating',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: context.sp(12),
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.grey300 : AppColors.grey700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

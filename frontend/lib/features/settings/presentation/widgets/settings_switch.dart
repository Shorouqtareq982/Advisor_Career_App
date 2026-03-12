import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class SettingsSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const SettingsSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final scale = (w * 0.004).clamp(0.85, 1.10);

        return Transform.scale(
          scale: scale,
          child: Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.lightBlue700,
            activeTrackColor: AppColors.lightBlue700.withOpacity(0.5),
            inactiveTrackColor: isDark
                ? Colors.grey.shade700
                : AppColors.grey800.withOpacity(0.3),
          ),
        );
      },
    );
  }
}

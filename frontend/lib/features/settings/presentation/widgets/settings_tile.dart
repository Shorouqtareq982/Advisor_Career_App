import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? titleColor;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;

        final padH = (w * 0.035).clamp(12.0, 18.0);
        final padV = (w * 0.030).clamp(10.0, 14.0);
        final r = (w * 0.03).clamp(8.0, 14.0);

        final iconSize = (w * 0.055).clamp(18.0, 22.0);
        final titleSize = (w * 0.038).clamp(14.0, 16.5);
        final subSize = (w * 0.032).clamp(12.0, 14.0);
        final gap = (w * 0.03).clamp(10.0, 14.0);

        return Padding(
          padding: EdgeInsets.only(bottom: (w * 0.02).clamp(6.0, 10.0)),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(r),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E2F) : AppColors.grey50,
                borderRadius: BorderRadius.circular(r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: iconSize,
                    color: onTap != null
                        ? AppColors.lightBlue700
                        : (isDark ? Colors.grey.shade400 : AppColors.grey800),
                  ),
                  SizedBox(width: gap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: titleSize,
                            fontWeight: FontWeight.w600,
                            color: titleColor ??
                                (isDark ? AppColors.grey50 : AppColors.blue900),
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: subSize,
                              fontWeight: FontWeight.w400,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : AppColors.grey800,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                  if (onTap != null && trailing == null)
                    Icon(
                      Icons.arrow_forward_ios,
                      size: (w * 0.045).clamp(14.0, 18.0),
                      color: isDark ? Colors.grey.shade400 : AppColors.grey800,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

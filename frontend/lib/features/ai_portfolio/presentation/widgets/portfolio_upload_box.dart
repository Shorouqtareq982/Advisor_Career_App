import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';

class PortfolioUploadBox extends StatelessWidget {
  final String? fileName;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const PortfolioUploadBox({
    super.key,
    required this.fileName,
    required this.onTap,
    required this.onRemove,
  });

  static const _basePath = 'assets/images/ai_protifilo';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F111D);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Resume / CV',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
            fontSize: context.sp(11).clamp(11.0, 11.0),
            color: textColor,
          ),
        ),
        SizedBox(height: context.h(8)),
        if (fileName == null)
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(context.r(8)),
            child: Container(
              width: double.infinity,
              constraints: BoxConstraints(minHeight: context.h(152)),
              padding: EdgeInsets.symmetric(
                horizontal: context.w(16),
                vertical: context.h(24),
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131A3B) : AppColors.grey50,
                borderRadius: BorderRadius.circular(context.r(8)),
                border: Border.all(
                  color: isDark ? const Color(0xFFB8BCC8) : AppColors.grey600,
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    '$_basePath/upload.png',
                    width: context.w(40),
                    height: context.w(40),
                    color: textColor,
                  ),
                  SizedBox(height: context.h(8)),
                  Text(
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
                  SizedBox(height: context.h(8)),
                  Text(
                    'Supported formats: PDF, DOCX (max 10 MB)',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      fontSize: context.sp(11).clamp(11.0, 11.0),
                      color:
                          isDark ? const Color(0xFF9CA3AF) : AppColors.grey800,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: context.w(12),
              vertical: context.h(14),
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131A3B) : AppColors.grey50,
              borderRadius: BorderRadius.circular(context.r(8)),
              border: Border.all(
                color: isDark ? const Color(0xFFB8BCC8) : AppColors.grey600,
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  '$_basePath/upload.png',
                  width: context.w(26),
                  height: context.w(26),
                  color: textColor,
                ),
                SizedBox(height: context.h(8)),
                GestureDetector(
                  onTap: onTap,
                  child: Text(
                    'click to Change',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                      fontSize: context.sp(12).clamp(11.0, 12.0),
                      color: textColor,
                    ),
                  ),
                ),
                SizedBox(height: context.h(8)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: onRemove,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 16,
                        color: Color(0xFFE53935),
                      ),
                    ),
                    SizedBox(width: context.w(4)),
                    Flexible(
                      child: Text(
                        fileName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                          fontSize: context.sp(10).clamp(10.0, 10.0),
                          color: isDark
                              ? const Color(0xFF9CA3AF)
                              : AppColors.grey800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import 'portfolio_adaptive_image.dart';

class PortfolioUploadTile extends StatelessWidget {
  final String label;
  final String? filePath;
  final String? fileName;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final bool isImage;

  const PortfolioUploadTile({
    super.key,
    required this.label,
    required this.filePath,
    required this.fileName,
    required this.onTap,
    required this.onRemove,
    this.isImage = true,
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
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
            fontSize: context.sp(11).clamp(11.0, 11.0),
            color: textColor,
          ),
        ),
        SizedBox(height: context.h(8)),
        if (filePath == null)
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(context.r(8)),
            child: Container(
              height: context.h(40),
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131A3B) : AppColors.grey50,
                borderRadius: BorderRadius.circular(context.r(8)),
                border: Border.all(
                  color: isDark ? const Color(0xFFB8BCC8) : AppColors.grey600,
                  width: 1,
                ),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      '$_basePath/up.png',
                      width: context.w(16),
                      height: context.w(16),
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
                ),
              ),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: context.w(10),
              vertical: context.h(8),
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131A3B) : AppColors.grey50,
              borderRadius: BorderRadius.circular(context.r(8)),
              border: Border.all(
                color: isDark ? const Color(0xFFB8BCC8) : AppColors.grey600,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                if (isImage)
                  SizedBox(
                    width: context.w(34),
                    height: context.w(34),
                    child: PortfolioAdaptiveImage(
                      imagePath: filePath,
                      width: context.w(34),
                      height: context.w(34),
                      fit: BoxFit.cover,
                      borderRadius: BorderRadius.circular(context.r(6)),
                      placeholder: Container(
                        color: AppColors.grey100,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.image_outlined,
                          size: context.w(16),
                          color: textColor,
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    width: context.w(34),
                    height: context.w(34),
                    decoration: BoxDecoration(
                      color: AppColors.grey100,
                      borderRadius: BorderRadius.circular(context.r(6)),
                    ),
                    child: Center(
                      child: Image.asset(
                        '$_basePath/upload.png',
                        width: context.w(18),
                        height: context.w(18),
                        color: textColor,
                      ),
                    ),
                  ),
                SizedBox(width: context.w(10)),
                Expanded(
                  child: GestureDetector(
                    onTap: onTap,
                    child: Text(
                      fileName?.isNotEmpty == true
                          ? fileName!
                          : 'click to Change',
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
                ),
                IconButton(
                  onPressed: onRemove,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Color(0xFFE53935),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

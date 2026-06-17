import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';

class AIPortfolioSectionDetailsScreen extends StatelessWidget {
  final String title;
  final String subtitle;

  const AIPortfolioSectionDetailsScreen({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.blue900 : AppColors.textDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: context.w(16),
            vertical: context.h(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: Icon(
                  Icons.arrow_back_ios_new,
                  color: isDark ? AppColors.grey50 : AppColors.blue900,
                ),
              ),
              SizedBox(height: context.h(12)),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(context.w(16)),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF131A3B)
                      : const Color(0xFFF8F8F8),
                  borderRadius: BorderRadius.circular(context.r(8)),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFFB8BCC8)
                        : const Color(0xFF686868),
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
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: context.sp(16).clamp(15.0, 16.0),
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppColors.grey50
                                  : const Color(0xFF0F111D),
                            ),
                          ),
                          SizedBox(height: context.h(6)),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: context.sp(13).clamp(12.0, 13.0),
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? const Color(0xFF9CA3AF)
                                  : const Color(0xFF686868),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: context.w(28),
                      color:
                          isDark ? AppColors.grey50 : const Color(0xFF0F111D),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

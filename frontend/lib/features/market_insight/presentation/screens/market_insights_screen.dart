import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../../../../shared/widgets/background_curves.dart';

class MarketInsightsScreen extends StatelessWidget {
  const MarketInsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blue500,
      body: Stack(
        children: [
          const BackgroundCurves(),

          // App logo
          Positioned(
            top: context.h(60),
            child: SizedBox(
              width: context.screenWidth,
              child: const Center(
                child: AppLogo(),
              ),
            ),
          ),

          // White container
          Positioned(
            top: context.h(180),
            left: 0,
            right: 0,
            child: Container(
              height: context.screenHeight - context.h(180),
              decoration: BoxDecoration(
                color: AppColors.grey50,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(context.r(50)),
                ),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.w(24),
                    vertical: context.h(30),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with back button and title
                      Row(
                        children: [
                          InkWell(
                            onTap: () => context.pop(),
                            borderRadius: BorderRadius.circular(context.r(8)),
                            child: Container(
                              padding: EdgeInsets.all(context.w(8)),
                              child: Icon(
                                Icons.arrow_back_ios_new,
                                color: AppColors.blue900,
                                size: context.icon(20),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                'Market Insights',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: context.sp(20),
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.blue900,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: context.w(40)),
                        ],
                      ),

                      SizedBox(height: context.h(40)),

                      // Coming Soon Content
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: context.w(150),
                              height: context.w(150),
                              decoration: BoxDecoration(
                                color: AppColors.lightBlue700.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.trending_up_outlined,
                                color: AppColors.lightBlue700,
                                size: context.icon(80),
                              ),
                            ),
                            SizedBox(height: context.h(24)),
                            Text(
                              'Coming Soon!',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: context.sp(28),
                                fontWeight: FontWeight.w700,
                                color: AppColors.lightBlue700,
                              ),
                            ),
                            SizedBox(height: context.h(16)),
                            Text(
                              'Get real-time market trends, salary insights, and in-demand skills data.\n\nStay tuned!',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: context.sp(16),
                                color: AppColors.grey800,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

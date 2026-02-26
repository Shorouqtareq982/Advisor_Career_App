import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_text_theme.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/background_curves.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../../../../core/extensions/responsive_extension.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final textTheme = context.appTextTheme;

    final buttonHeight = screenHeight * 0.045.clamp(0.0, 52.0);

    return Scaffold(
      backgroundColor: AppColors.blue500,
      body: Stack(
        children: [
          const BackgroundCurves(),

          // اللوجو
          Positioned(
            top: screenHeight * 0.06,
            left: 0,
            right: 0,
            child: const Center(
              child: AppLogo(),
            ),
          ),

          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: context.contentConstraints,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: context.contentHorizontalPadding,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(height: screenHeight * 0.15),

                        // Welcome to Growza
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            text: 'Welcome to ',
                            style: context.responsiveText(
                              textTheme.h5Bold
                                  .copyWith(color: AppColors.grey200),
                            ),
                            children: [
                              TextSpan(
                                text: 'Growza',
                                style: context.responsiveText(
                                  textTheme.h5Bold
                                      .copyWith(color: AppColors.purple500),
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: screenHeight * 0.02),

                        // Description
                        context.text(
                          AppStrings.welcomeDescription,
                          style: textTheme.bodyMedium.copyWith(
                            color: AppColors.grey200,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        SizedBox(height: screenHeight * 0.08),

                        // Buttons
                        Column(
                          children: [
                            CustomButton(
                              text: AppStrings.signIn,
                              onPressed: () => context.go('/sign-in'),
                              height: buttonHeight,
                              backgroundColor: AppColors.lightBlue500,
                              textColor: AppColors.blue500,
                            ),
                            SizedBox(height: screenHeight * 0.02),
                            CustomButton(
                              text: AppStrings.signUp,
                              onPressed: () => context.go('/sign-up'),
                              height: buttonHeight,
                              backgroundColor: AppColors.grey50,
                              textColor: AppColors.blue500,
                            ),
                          ],
                        ),

                        SizedBox(height: screenHeight * 0.02),
                      ],
                    ),
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

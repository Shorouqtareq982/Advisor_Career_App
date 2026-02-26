import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class BackgroundCurves extends StatelessWidget {
  const BackgroundCurves({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Stack(
      children: [
        // Top purple curve - positioned at top covering full width
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Image.asset(
            'assets/images/top_curve.png',
            width: size.width,
            height: size.height * 0.4,
            fit: BoxFit.fill,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: size.height * 0.4,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topRight,
                    radius: 1.5,
                    colors: [
                      AppColors.purple500.withOpacity(0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Bottom cyan curve
        Positioned(
          bottom: 0,
          left: size.width * 0.2,
          right: 0,
          child: Image.asset(
            'assets/images/Bottom_curve.png',
            width: size.width,
            height: size.height * 0.2,
            fit: BoxFit.fill,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: size.height * 0.2,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.bottomLeft,
                    radius: 1.5,
                    colors: [
                      AppColors.lightBlue500.withOpacity(0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

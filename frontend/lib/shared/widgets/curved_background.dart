import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/constants/app_colors.dart';

class CurvedBackground extends StatelessWidget {
  final Widget child;
  final bool showLogo;

  const CurvedBackground({
    super.key,
    required this.child,
    this.showLogo = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background with curves
        Container(
          width: double.infinity,
          height: double.infinity,
          child: CustomPaint(painter: _CurvedBackgroundPainter()),
        ),

        // Logo at top
        if (showLogo)
          Positioned(
            top: 50,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: SvgPicture.asset(
                    'assets/images/logo.svg',
                    fit: BoxFit.contain,
                    colorFilter: const ColorFilter.mode(
                      AppColors.primary,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
            ),
          ),

        // Content
        child,
      ],
    );
  }
}

class _CurvedBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Top purple section
    final purplePaint = Paint()
      ..color = AppColors.purple
      ..style = PaintingStyle.fill;

    final purplePath = Path();
    purplePath.moveTo(0, 0);
    purplePath.lineTo(size.width, 0);
    purplePath.lineTo(size.width, size.height * 0.35);

    purplePath.quadraticBezierTo(
      size.width * 0.5,
      size.height * 0.42,
      0,
      size.height * 0.35,
    );
    purplePath.close();

    canvas.drawPath(purplePath, purplePaint);

    // Bottom navy/teal section
    final navyPaint = Paint()
      ..color = AppColors.navyDark
      ..style = PaintingStyle.fill;

    final navyPath = Path();
    navyPath.moveTo(0, size.height * 0.35);

    navyPath.quadraticBezierTo(
      size.width * 0.5,
      size.height * 0.42,
      size.width,
      size.height * 0.35,
    );

    navyPath.lineTo(size.width, size.height * 0.65);

    navyPath.quadraticBezierTo(
      size.width * 0.5,
      size.height * 0.72,
      0,
      size.height * 0.65,
    );

    navyPath.close();

    canvas.drawPath(navyPath, navyPaint);

    // Bottom teal section
    final tealPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;

    final tealPath = Path();
    tealPath.moveTo(0, size.height * 0.65);

    tealPath.quadraticBezierTo(
      size.width * 0.5,
      size.height * 0.72,
      size.width,
      size.height * 0.65,
    );

    tealPath.lineTo(size.width, size.height);
    tealPath.lineTo(0, size.height);
    tealPath.close();

    canvas.drawPath(tealPath, tealPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

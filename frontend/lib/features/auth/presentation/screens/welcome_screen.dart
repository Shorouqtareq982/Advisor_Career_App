import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../config/routes/app_router.dart';

/// 🏠 Welcome Screen - شاشة الترحيب
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ========================================
          // Background Waves (الخلفيات الملونة)
          // ========================================
          _buildBackgroundWaves(),

          // ========================================
          // Content (المحتوى الأساسي)
          // ========================================
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // ========================================
                  // Logo (اللوجو)
                  // ========================================
                  _buildLogo(),

                  const SizedBox(height: 40),

                  // ========================================
                  // Welcome Text (النص الترحيبي)
                  // ========================================
                  _buildWelcomeText(),

                  const SizedBox(height: 88),

                  // ========================================
                  // Buttons (الأزرار)
                  // ========================================
                  _buildButtons(context),

                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========================================
  // Background Waves
  // ========================================
  Widget _buildBackgroundWaves() {
    return Stack(
      children: [
        // Top Purple Wave
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: CustomPaint(
            size: const Size(375, 293),
            painter: TopWavePainter(),
          ),
        ),

        // Bottom Aqua Wave
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: CustomPaint(
            size: const Size(375, 157),
            painter: BottomWavePainter(),
          ),
        ),
      ],
    );
  }

  // ========================================
  // Logo
  // ========================================
  Widget _buildLogo() {
    return Container(
      width: 121.76,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(60),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
    );
  }

  // ========================================
  // Welcome Text
  // ========================================
  Widget _buildWelcomeText() {
    return Column(
      children: [
        // العنوان الرئيسي
        RichText(
          textAlign: TextAlign.center,
          text: const TextSpan(
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 23,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: AppColors.textLight,
            ),
            children: [
              TextSpan(text: 'Welcome to '),
              TextSpan(
                text: 'Growza',
                style: TextStyle(color: AppColors.primary),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // النص الثانوي
        const Text(
          'Empower your career with AI-driven insights and smart job recommendations.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.2,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // ========================================
  // Buttons
  // ========================================
  Widget _buildButtons(BuildContext context) {
    return Column(
      children: [
        // Sign In Button
        CustomButton(
          text: 'Sign In',
          isPrimary: true,
          onPressed: () {
            // Navigate to login screen using GoRouter
            context.push(AppRouter.login);
          },
        ),

        const SizedBox(height: 24),

        // Sign Up Button
        CustomButton(
          text: 'Sign Up',
          isPrimary: false,
          onPressed: () {
            // Navigate to register screen using GoRouter
            context.push(AppRouter.register);
          },
        ),
      ],
    );
  }
}

// ========================================
// Top Wave Painter (الموجة البنفسجية العليا)
// ========================================
class TopWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.secondary
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(0, size.height * 0.7)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.85,
        size.width * 0.5,
        size.height * 0.8,
      )
      ..quadraticBezierTo(
        size.width * 0.75,
        size.height * 0.75,
        size.width,
        size.height * 0.6,
      )
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ========================================
// Bottom Wave Painter (الموجة الأزرق السفلى)
// ========================================
class BottomWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, size.height * 0.4)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.2,
        size.width * 0.5,
        size.height * 0.3,
      )
      ..quadraticBezierTo(
        size.width * 0.75,
        size.height * 0.4,
        size.width,
        size.height * 0.2,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

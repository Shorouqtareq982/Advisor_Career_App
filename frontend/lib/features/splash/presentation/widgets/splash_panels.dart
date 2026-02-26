import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class SplashPanels extends StatelessWidget {
  final double topTranslateY;
  final double bottomTranslateY;
  final double screenHeight;
  final double joinY;
  final double notchDepth;

  const SplashPanels({
    super.key,
    required this.topTranslateY,
    required this.bottomTranslateY,
    required this.screenHeight,
    required this.joinY,
    required this.notchDepth,
  });

  @override
  Widget build(BuildContext context) {
    const overlap = 2.0;

    return Stack(
      children: [
        Positioned.fill(child: Container(color: AppColors.blue500)),
        Positioned.fill(
          child: Transform.translate(
            offset: Offset(0, bottomTranslateY),
            child: ClipPath(
              clipper: _BottomShapeClipper(joinY: joinY, depth: notchDepth),
              child: Container(color: AppColors.lightBlue500),
            ),
          ),
        ),
        Positioned.fill(
          child: Transform.translate(
            offset: Offset(0, topTranslateY),
            child: ClipPath(
              clipper: _TopShapeClipper(joinY: joinY, depth: notchDepth),
              child: Container(color: AppColors.purple500),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: joinY - overlap,
          height: overlap * 2,
          child: const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _TopShapeClipper extends CustomClipper<Path> {
  final double joinY;
  final double depth;

  _TopShapeClipper({required this.joinY, required this.depth});

  @override
  Path getClip(Size size) {
    final mid = size.width / 2;

    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, joinY)
      ..lineTo(mid, joinY + depth)
      ..lineTo(0, joinY)
      ..close();
  }

  @override
  bool shouldReclip(covariant _TopShapeClipper oldClipper) =>
      oldClipper.joinY != joinY || oldClipper.depth != depth;
}

class _BottomShapeClipper extends CustomClipper<Path> {
  final double joinY;
  final double depth;

  _BottomShapeClipper({required this.joinY, required this.depth});

  @override
  Path getClip(Size size) {
    final mid = size.width / 2;

    return Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, joinY)
      ..lineTo(mid, joinY - depth)
      ..lineTo(0, joinY)
      ..close();
  }

  @override
  bool shouldReclip(covariant _BottomShapeClipper oldClipper) =>
      oldClipper.joinY != joinY || oldClipper.depth != depth;
}

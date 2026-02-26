import 'package:flutter/material.dart';
import '../../core/extensions/responsive_extension.dart';

class AppLogo extends StatelessWidget {
  final double? size;
  final double? top;
  final double? left;
  final double? right;
  final double? bottom;

  const AppLogo({
    super.key,
    this.size,
    this.top,
    this.left,
    this.right,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final logoSize = size ?? context.logo(105);

    final widget = SizedBox(
      width: logoSize,
      height: logoSize,
      child: Image.asset(
        'assets/images/logo.png',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Icon(
            Icons.person_outline,
            size: logoSize * 0.5,
            color: Colors.grey,
          );
        },
      ),
    );

    if (top != null || left != null || right != null || bottom != null) {
      return Positioned(
        top: top,
        left: left,
        right: right,
        bottom: bottom,
        child: widget,
      );
    }

    return widget;
  }
}

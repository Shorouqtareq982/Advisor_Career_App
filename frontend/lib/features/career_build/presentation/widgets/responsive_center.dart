// lib/features/career_build/presentation/widgets/responsive_center.dart
import 'package:flutter/material.dart';
import '../../../../core/extensions/responsive_extension.dart';

class ResponsiveCenter extends StatelessWidget {
  final Widget child;

  const ResponsiveCenter({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: context.contentConstraints,
        child: child,
      ),
    );
  }
}

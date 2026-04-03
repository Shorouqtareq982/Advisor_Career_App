// This screen is referenced in the router but the upload flow is handled
// via the dialog on ResumeOptimizationScreen.
// We keep this as a redirect to avoid router errors.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class StartOptimizationScreen extends StatelessWidget {
  const StartOptimizationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.go('/resume-optimization');
    });
    return const SizedBox.shrink();
  }
}

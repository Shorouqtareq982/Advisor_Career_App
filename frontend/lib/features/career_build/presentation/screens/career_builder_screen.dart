import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/career_build_provider.dart';
import 'career_plans_screen.dart';

class CareerBuilderScreen extends ConsumerWidget {
  const CareerBuilderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(careerBuildProvider);
    return const CareerPlansScreen();
  }
}

// lib/features/job_matching/presentation/screens/job_preferences_gate.dart
//
// Entry point for /jobs route.
// Logic:
// - Preferences complete? → RecommendedJobsScreen
// - Preferences incomplete? → JobPreferencesScreen (fromJobMatching: true)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'job_preferences_screen.dart';
import 'recommended_jobs_screen.dart';

class JobPreferencesGate extends ConsumerWidget {
  const JobPreferencesGate({super.key});

  /// Preferences are "complete" when these fields are all filled:
  /// jobTitle, workType (≥1), workLocation (≥1), jobPlatforms (≥1), cvUrl
  bool _isComplete(dynamic user) {
    if (user == null) return false;
    final hasTitle = (user.jobTitle as String?)?.isNotEmpty == true;
    final hasWorkType = (user.workType as List?)?.isNotEmpty == true;
    final hasWorkLoc = (user.workLocation as List?)?.isNotEmpty == true;
    final hasPlatforms = (user.jobPlatforms as List?)?.isNotEmpty == true;
    final hasCv = (user.cvUrl as String?)?.isNotEmpty == true;
    return hasTitle && hasWorkType && hasWorkLoc && hasPlatforms && hasCv;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

    if (_isComplete(user)) {
      return const RecommendedJobsScreen();
    }

    return const JobPreferencesScreen(fromJobMatching: true);
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ROUTES TO ADD IN app_router.dart
// ════════════════════════════════════════════════════════════════════════════
//
// Replace the existing /jobs route with:
//
// // ── Job Matching ─────────────────────────────────────────────────────
// import '../../features/job_matching/presentation/screens/job_preferences_gate.dart';
// import '../../features/job_matching/presentation/screens/job_preferences_screen.dart';
// import '../../features/job_matching/presentation/screens/recommended_jobs_screen.dart';
// import '../../features/job_matching/presentation/screens/job_details_screen.dart';
// import '../../features/job_matching/domain/entities/job_entity.dart';
//
// GoRoute(
//   path: '/jobs',
//   name: 'jobs',
//   builder: (context, state) => const JobPreferencesGate(),
// ),
// GoRoute(
//   path: '/job-preferences',
//   name: 'job-preferences',
//   builder: (context, state) {
//     final fromJobMatching =
//         (state.extra as Map<String, dynamic>?)?['fromJobMatching'] as bool? ?? false;
//     return JobPreferencesScreen(fromJobMatching: fromJobMatching);
//   },
// ),
// GoRoute(
//   path: '/recommended-jobs',
//   name: 'recommended-jobs',
//   builder: (context, state) => const RecommendedJobsScreen(),
// ),
// GoRoute(
//   path: '/job-details',
//   name: 'job-details',
//   builder: (context, state) {
//     final job = state.extra as JobEntity;
//     return JobDetailsScreen(job: job);
//   },
// ),
//
// Also: In recommended_jobs_screen.dart, the filter icon should navigate to:
//   context.push('/job-preferences', extra: {'fromJobMatching': false})

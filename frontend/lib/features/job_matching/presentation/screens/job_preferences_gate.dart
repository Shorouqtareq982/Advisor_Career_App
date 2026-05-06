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

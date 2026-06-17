import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/job_matching_provider.dart';
import 'job_preferences_screen.dart';
import 'recommended_jobs_screen.dart';

class JobPreferencesGate extends ConsumerStatefulWidget {
  const JobPreferencesGate({super.key});

  @override
  ConsumerState<JobPreferencesGate> createState() => _JobPreferencesGateState();
}

class _JobPreferencesGateState extends ConsumerState<JobPreferencesGate> {
  bool _checking = true;
  bool _hasUsedBefore = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    String? userId = ref.read(authProvider).user?.id;
    for (int i = 0; i < 10 && userId == null; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      userId = ref.read(authProvider).user?.id;
    }

    final notifier = ref.read(jobMatchingProvider.notifier);
    if (userId != null) {
      notifier.setUserId(userId);
    }

    final usedBefore = await notifier.hasUsedJobMatchingBefore();
    if (!mounted) return;
    setState(() {
      _hasUsedBefore = usedBefore;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _hasUsedBefore
        ? const RecommendedJobsScreen()
        : const JobPreferencesScreen(fromJobMatching: true);
  }
}

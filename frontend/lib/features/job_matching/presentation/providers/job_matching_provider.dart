import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../alerts/data/datasources/alerts_local_datasource.dart';
import '../../data/repositories/job_matching_repository.dart';
import '../../domain/entities/job_entity.dart';

String _kSaved(String uid) => 'jm_saved_$uid';
String _kResults(String uid) => 'jm_results_$uid';
String _kUsed(String uid) => 'jm_used_$uid';

enum JobMatchingStatus { idle, loading, success, error }

class JobMatchingState {
  final List<JobEntity> recommendedJobs;
  final List<JobEntity> savedJobs;
  final JobMatchingStatus recommendedStatus;
  final JobMatchingStatus savedStatus;
  final String? errorMessage;
  final List<String> jobTitles;
  final List<Map<String, String>> countries;

  const JobMatchingState({
    this.recommendedJobs = const [],
    this.savedJobs = const [],
    this.recommendedStatus = JobMatchingStatus.idle,
    this.savedStatus = JobMatchingStatus.idle,
    this.errorMessage,
    this.jobTitles = const [],
    this.countries = const [],
  });

  JobMatchingState copyWith({
    List<JobEntity>? recommendedJobs,
    List<JobEntity>? savedJobs,
    JobMatchingStatus? recommendedStatus,
    JobMatchingStatus? savedStatus,
    String? errorMessage,
    bool clearError = false,
    List<String>? jobTitles,
    List<Map<String, String>>? countries,
  }) {
    return JobMatchingState(
      recommendedJobs: recommendedJobs ?? this.recommendedJobs,
      savedJobs: savedJobs ?? this.savedJobs,
      recommendedStatus: recommendedStatus ?? this.recommendedStatus,
      savedStatus: savedStatus ?? this.savedStatus,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      jobTitles: jobTitles ?? this.jobTitles,
      countries: countries ?? this.countries,
    );
  }
}

class JobMatchingNotifier extends StateNotifier<JobMatchingState> {
  final JobMatchingRepository _repository;

  String? _userId;
  final Set<String> _savedIds = {};
  bool _persistenceLoaded = false;

  JobMatchingNotifier(this._repository) : super(const JobMatchingState());

  void setUserId(String userId) {
    if (_userId == userId) return;
    _userId = userId;
    _persistenceLoaded = false;
    _savedIds.clear();
  }

  Future<void> _ensureLoaded() async {
    if (_persistenceLoaded || _userId == null) return;
    _persistenceLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_kSaved(_userId!)) ?? [];
      _savedIds.addAll(saved);

      // 1. حاول تجيب من الـ local cache أولاً (سريع)
      final resultsRaw = prefs.getString(_kResults(_userId!));
      if (resultsRaw != null && state.recommendedJobs.isEmpty) {
        final list = jsonDecode(resultsRaw) as List;
        final jobs =
            list.map((e) => _jobFromJson(e as Map<String, dynamic>)).toList();
        state = state.copyWith(
          recommendedJobs: _applyLocalState(jobs),
          recommendedStatus: JobMatchingStatus.success,
        );
        return; // عندنا cache محلي، مش محتاجين السيرفر
      }

      // 2. لو مفيش cache محلي (بعد uninstall مثلاً)، اجيب من السيرفر
      if (state.recommendedJobs.isEmpty) {
        final serverResults = await _repository.getMatchResults();
        if (serverResults.isNotEmpty) {
          final merged = _applyLocalState(serverResults);
          // احفظهم محلياً عشان المرة الجاية تبقى سريعة
          await _persistResults(merged);
          state = state.copyWith(
            recommendedJobs: merged,
            recommendedStatus: JobMatchingStatus.success,
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _persistSaved() async {
    if (_userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kSaved(_userId!), _savedIds.toList());
    } catch (_) {}
  }

  Future<void> _persistResults(List<JobEntity> jobs) async {
    if (_userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = jobs.map(_jobToJson).toList();
      await prefs.setString(_kResults(_userId!), jsonEncode(list));
    } catch (_) {}
  }

  /// بتسجّل إن اليوزر استخدم الفيتشر دي قبل كده، عشان صفحة الـ
  /// preferences متظهرله غير أول مرة بس لما يدخل من الهوم.
  Future<void> _markUsed() async {
    if (_userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kUsed(_userId!), true);
    } catch (_) {}
  }

  Future<bool> hasUsedJobMatchingBefore() async {
    if (_userId == null) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      // Check local flag first (fast)
      final localFlag = prefs.getBool(_kUsed(_userId!));
      if (localFlag == true) return true;
      // Check if results cached locally
      if (prefs.containsKey(_kResults(_userId!))) return true;
      // Fallback: check cloud (saved jobs exist = used before)
      final usedInCloud = await _repository.hasUsedJobMatchingInCloud(_userId!);
      if (usedInCloud) {
        // Cache locally for next time
        await prefs.setBool(_kUsed(_userId!), true);
      }
      return usedInCloud;
    } catch (_) {
      return false;
    }
  }

  List<JobEntity> _applyLocalState(List<JobEntity> jobs) {
    return jobs
        .map((job) => job.copyWith(isSaved: _savedIds.contains(job.id)))
        .toList();
  }

  Future<void> loadDropdowns() async {
    try {
      final titles = await _repository.getJobTitles();
      final countries = await _repository.getCountries();
      state = state.copyWith(jobTitles: titles, countries: countries);
    } catch (_) {}
  }

  Future<void> matchJobs({
    required String jobTitle,
    required String jobType,
    required String country,
    required String workMode,
    required File cvFile,
  }) async {
    state = state.copyWith(
      recommendedStatus: JobMatchingStatus.loading,
      clearError: true,
    );

    try {
      await _ensureLoaded();

      final jobs = await _repository.matchJobs(
        jobTitle: jobTitle,
        jobType: jobType,
        country: country,
        workMode: workMode,
        cvFile: cvFile,
      );

      final merged = _applyLocalState(jobs);
      await _persistResults(merged);
      await _markUsed();

      state = state.copyWith(
        recommendedJobs: merged,
        recommendedStatus: JobMatchingStatus.success,
      );
    } catch (e) {
      state = state.copyWith(
        recommendedStatus: JobMatchingStatus.error,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<void> loadSavedJobs() async {
    state = state.copyWith(savedStatus: JobMatchingStatus.loading);
    try {
      await _ensureLoaded();

      List<JobEntity> saved = await _repository.getSavedJobs();

      if (saved.isEmpty) {
        saved = state.recommendedJobs
            .where((j) => _savedIds.contains(j.id))
            .toList();
      }

      for (final j in saved) _savedIds.add(j.id);
      await _persistSaved();

      state = state.copyWith(
        savedJobs: _applyLocalState(saved),
        savedStatus: JobMatchingStatus.success,
      );
    } catch (e) {
      state = state.copyWith(
        savedStatus: JobMatchingStatus.error,
        errorMessage: 'Failed to load saved jobs.',
      );
    }
  }

  Future<void> toggleSave(String jobId) async {
    await _ensureLoaded();
    final wasSaved = _savedIds.contains(jobId);

    if (wasSaved) {
      _savedIds.remove(jobId);
    } else {
      _savedIds.add(jobId);
    }
    await _persistSaved();

    final updatedRec = state.recommendedJobs.map((j) {
      if (j.id == jobId) return j.copyWith(isSaved: !wasSaved);
      return j;
    }).toList();

    List<JobEntity> updatedSaved = List.from(state.savedJobs);
    if (wasSaved) {
      updatedSaved.removeWhere((j) => j.id == jobId);
    } else {
      final job = state.recommendedJobs.firstWhere(
        (j) => j.id == jobId,
        orElse: () => state.savedJobs.firstWhere(
          (j) => j.id == jobId,
          orElse: () => _emptyJob(jobId),
        ),
      );
      if (job.id.isNotEmpty) updatedSaved.add(job.copyWith(isSaved: true));
    }

    state = state.copyWith(
      recommendedJobs: updatedRec,
      savedJobs: updatedSaved,
    );

    if (wasSaved) {
      _repository.unsaveJob(jobId);
    } else {
      final job = updatedRec.firstWhere(
        (j) => j.id == jobId,
        orElse: () => _emptyJob(jobId),
      );
      if (job.id.isNotEmpty) _repository.saveJob(job);
    }
  }

  void matchJobsInBackground({
    required String jobTitle,
    required String jobType,
    required String country,
    required String workMode,
    required File cvFile,
    VoidCallback? onSuccess,
  }) {
    _runMatchInBackground(
      jobTitle: jobTitle,
      jobType: jobType,
      country: country,
      workMode: workMode,
      cvFile: cvFile,
      onSuccess: onSuccess,
    );
  }

  Future<void> _runMatchInBackground({
    required String jobTitle,
    required String jobType,
    required String country,
    required String workMode,
    required File cvFile,
    VoidCallback? onSuccess,
  }) async {
    state = state.copyWith(
      recommendedStatus: JobMatchingStatus.loading,
      clearError: true,
    );

    try {
      await _ensureLoaded();

      final jobs = await _repository.matchJobs(
        jobTitle: jobTitle,
        jobType: jobType,
        country: country,
        workMode: workMode,
        cvFile: cvFile,
      );

      final merged = _applyLocalState(jobs);
      await _repository.saveMatchResults(merged);
      await _markUsed();

      state = state.copyWith(
        recommendedJobs: merged,
        recommendedStatus: JobMatchingStatus.success,
      );

      await _sendResultsNotification(jobTitle);
      await _addResultsAlert(jobTitle: jobTitle, count: merged.length);

      onSuccess?.call();
    } catch (e) {
      state = state.copyWith(
        recommendedStatus: JobMatchingStatus.error,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );

      await _sendErrorNotification();
    }
  }

  Future<void> _sendResultsNotification(String jobTitle) async {
    try {
      await NotificationService.instance.showJobResultsReady(
        jobTitle: jobTitle,
      );
    } catch (_) {
      try {
        await NotificationService.instance.showCustomNotification(
          title: 'Your Job Matches Are Ready! 🎉',
          body:
              'We found the best $jobTitle opportunities for you. Tap to see results.',
        );
      } catch (_) {}
    }
  }

  /// بتظهر زي تنبيهات الموك إنترفيو وخطط الكاريير في صفحة Alerts
  Future<void> _addResultsAlert({
    required String jobTitle,
    required int count,
  }) async {
    try {
      await AlertsStore.instance.addJobMatchingAlert(
        jobTitle: jobTitle,
        matchCount: count,
      );
    } catch (_) {}
  }

  Future<void> _sendErrorNotification() async {
    try {
      await NotificationService.instance.showCustomNotification(
        title: 'Job Search Failed',
        body: 'Something went wrong. Please try searching again.',
      );
    } catch (_) {}
  }

  Future<void> resetResults() async {
    if (_userId != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_kResults(_userId!));
      } catch (_) {}
    }
    state = state.copyWith(
      recommendedJobs: [],
      recommendedStatus: JobMatchingStatus.idle,
      clearError: true,
    );
  }

  JobEntity _emptyJob(String id) => JobEntity(
        id: id,
        title: '',
        company: '',
        location: '',
        workType: '',
        workLocation: '',
        postedAt: DateTime.now(),
      );

  Map<String, dynamic> _jobToJson(JobEntity j) => {
        'id': j.id,
        'title': j.title,
        'company': j.company,
        'location': j.location,
        'workType': j.workType,
        'workLocation': j.workLocation,
        'jobUrl': j.jobUrl,
        'jobDescription': j.jobDescription,
        'postedAt': j.postedAt.toIso8601String(),
        'rank': j.rank,
        'matchScore': j.matchScore,
        'explanation': j.explanation,
      };

  JobEntity _jobFromJson(Map<String, dynamic> m) => JobEntity(
        id: m['id'] as String? ?? '',
        title: m['title'] as String? ?? '',
        company: m['company'] as String? ?? '',
        location: m['location'] as String? ?? '',
        workType: m['workType'] as String? ?? '',
        workLocation: m['workLocation'] as String? ?? '',
        jobUrl: m['jobUrl'] as String?,
        jobDescription: m['jobDescription'] as String?,
        postedAt:
            DateTime.tryParse(m['postedAt'] as String? ?? '') ?? DateTime.now(),
        rank: m['rank'] as int?,
        matchScore: (m['matchScore'] as num?)?.toDouble(),
        explanation: m['explanation'] as String?,
      );
}

final jobMatchingRepositoryProvider = Provider<JobMatchingRepository>(
  (ref) => JobMatchingRepository(),
);

final jobMatchingProvider =
    StateNotifierProvider<JobMatchingNotifier, JobMatchingState>(
  (ref) => JobMatchingNotifier(ref.read(jobMatchingRepositoryProvider)),
);

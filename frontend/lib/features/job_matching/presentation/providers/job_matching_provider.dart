// lib/features/job_matching/presentation/providers/job_matching_provider.dart

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/repositories/job_matching_repository.dart';
import '../../domain/entities/job_entity.dart';

// ─── Per-user SharedPreferences keys ─────────────────────────────────────────
// كل key بيتضمن الـ userId عشان كل يوزر عنده data مستقلة
String _kSeen(String uid) => 'jm_seen_$uid';
String _kSaved(String uid) => 'jm_saved_$uid';
String _kRated(String uid) => 'jm_rated_$uid';

// ─── State ────────────────────────────────────────────────────────────────────

enum JobMatchingStatus { idle, loading, success, error }

class JobMatchingState {
  final List<JobEntity> recommendedJobs;
  final List<JobEntity> savedJobs;
  final JobMatchingStatus recommendedStatus;
  final JobMatchingStatus savedStatus;
  final String? errorMessage;

  const JobMatchingState({
    this.recommendedJobs = const [],
    this.savedJobs = const [],
    this.recommendedStatus = JobMatchingStatus.idle,
    this.savedStatus = JobMatchingStatus.idle,
    this.errorMessage,
  });

  JobMatchingState copyWith({
    List<JobEntity>? recommendedJobs,
    List<JobEntity>? savedJobs,
    JobMatchingStatus? recommendedStatus,
    JobMatchingStatus? savedStatus,
    String? errorMessage,
    bool clearError = false,
  }) {
    return JobMatchingState(
      recommendedJobs: recommendedJobs ?? this.recommendedJobs,
      savedJobs: savedJobs ?? this.savedJobs,
      recommendedStatus: recommendedStatus ?? this.recommendedStatus,
      savedStatus: savedStatus ?? this.savedStatus,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class JobMatchingNotifier extends StateNotifier<JobMatchingState> {
  final JobMatchingRepository _repository;

  /// User ID — must be set before loading jobs
  String? _userId;

  final Set<String> _seenIds = {};
  final Set<String> _savedIds = {};
  final Map<String, int> _ratings = {};

  bool _persistenceLoaded = false;

  JobMatchingNotifier(this._repository) : super(const JobMatchingState());

  // ── Set current user ──────────────────────────────────────────────────────
  /// Call this once after login / on provider init
  void setUserId(String userId) {
    if (_userId == userId) return; // same user, nothing to reset
    _userId = userId;
    _persistenceLoaded = false;
    _seenIds.clear();
    _savedIds.clear();
    _ratings.clear();
  }

  // ── Load persisted data ───────────────────────────────────────────────────
  Future<void> _ensureLoaded() async {
    if (_persistenceLoaded || _userId == null) return;
    _persistenceLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();

      final seen = prefs.getStringList(_kSeen(_userId!)) ?? [];
      _seenIds.addAll(seen);

      final saved = prefs.getStringList(_kSaved(_userId!)) ?? [];
      _savedIds.addAll(saved);

      final raw = prefs.getString(_kRated(_userId!));
      if (raw != null) {
        final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        map.forEach((k, v) => _ratings[k] = v as int);
      }
    } catch (_) {}
  }

  Future<void> _persistSeen() async {
    if (_userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kSeen(_userId!), _seenIds.toList());
    } catch (_) {}
  }

  Future<void> _persistSaved() async {
    if (_userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kSaved(_userId!), _savedIds.toList());
    } catch (_) {}
  }

  Future<void> _persistRatings() async {
    if (_userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kRated(_userId!), jsonEncode(_ratings));
    } catch (_) {}
  }

  // ── Merge API jobs with local state ───────────────────────────────────────
  List<JobEntity> _merge(List<JobEntity> apiJobs) {
    return apiJobs
        .map((job) => job.copyWith(
              isNew: !_seenIds.contains(job.id),
              isSaved: _savedIds.contains(job.id),
              userRating: _ratings[job.id],
            ))
        .toList();
  }

  // ── Load recommended jobs ─────────────────────────────────────────────────
  Future<void> loadRecommendedJobs() async {
    state = state.copyWith(
      recommendedStatus: JobMatchingStatus.loading,
      clearError: true,
    );
    try {
      await _ensureLoaded();
      final jobs = await _repository.getRecommendedJobs();
      state = state.copyWith(
        recommendedJobs: _merge(jobs),
        recommendedStatus: JobMatchingStatus.success,
      );
    } catch (e) {
      state = state.copyWith(
        recommendedStatus: JobMatchingStatus.error,
        errorMessage: 'Failed to load jobs. Please try again.',
      );
    }
  }

  // ── Load saved jobs ───────────────────────────────────────────────────────
  Future<void> loadSavedJobs() async {
    state = state.copyWith(savedStatus: JobMatchingStatus.loading);
    try {
      await _ensureLoaded();

      List<JobEntity> saved = [];
      try {
        saved = await _repository.getSavedJobs();
      } catch (_) {}

      // Fallback: build from recommended + local saved IDs
      if (saved.isEmpty) {
        saved = state.recommendedJobs
            .where((j) => _savedIds.contains(j.id))
            .toList();
      }

      for (final j in saved) _savedIds.add(j.id);
      await _persistSaved();

      state = state.copyWith(
        savedJobs: _merge(saved),
        savedStatus: JobMatchingStatus.success,
      );
    } catch (e) {
      state = state.copyWith(
        savedStatus: JobMatchingStatus.error,
        errorMessage: 'Failed to load saved jobs.',
      );
    }
  }

  // ── Toggle save ───────────────────────────────────────────────────────────
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
          orElse: () => _empty(jobId),
        ),
      );
      if (job.id.isNotEmpty) updatedSaved.add(job.copyWith(isSaved: true));
    }

    state = state.copyWith(
      recommendedJobs: updatedRec,
      savedJobs: updatedSaved,
    );

    // API (fire and forget)
    wasSaved ? _repository.unsaveJob(jobId) : _repository.saveJob(jobId);
  }

  // ── Rate ──────────────────────────────────────────────────────────────────
  Future<void> rateJob({required String jobId, required int rating}) async {
    await _ensureLoaded();
    final current = _ratings[jobId];
    final newRating = current == rating ? null : rating; // toggle

    if (newRating == null) {
      _ratings.remove(jobId);
    } else {
      _ratings[jobId] = newRating;
    }
    await _persistRatings();

    final updated = state.recommendedJobs.map((j) {
      if (j.id != jobId) return j;
      return newRating == null
          ? j.copyWith(clearRating: true)
          : j.copyWith(userRating: newRating);
    }).toList();
    state = state.copyWith(recommendedJobs: updated);

    if (newRating != null) {
      _repository.rateJob(jobId: jobId, rating: newRating);
    }
  }

  // ── Mark seen ─────────────────────────────────────────────────────────────
  Future<void> markJobSeen(String jobId) async {
    if (_seenIds.contains(jobId)) return;
    await _ensureLoaded();
    _seenIds.add(jobId);
    await _persistSeen();

    final updated = state.recommendedJobs.map((j) {
      if (j.id == jobId) return j.copyWith(isNew: false);
      return j;
    }).toList();
    state = state.copyWith(recommendedJobs: updated);

    _repository.markJobSeen(jobId);
  }

  JobEntity _empty(String id) => JobEntity(
        id: id,
        title: '',
        company: '',
        location: '',
        workType: '',
        workLocation: '',
        postedAt: DateTime.now(),
      );
}

// ─── Providers ────────────────────────────────────────────────────────────────

final jobMatchingRepositoryProvider = Provider<JobMatchingRepository>(
  (ref) => JobMatchingRepository(),
);

final jobMatchingProvider =
    StateNotifierProvider<JobMatchingNotifier, JobMatchingState>(
  (ref) => JobMatchingNotifier(ref.read(jobMatchingRepositoryProvider)),
);

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../data/datasources/interview_roles.dart';
import '../../data/repositories/mock_interview_repository_impl.dart';
import '../../../mock_interview/presentation/providers/notification_helper.dart';
import '../../../alerts/data/datasources/alerts_local_datasource.dart';
import '../../domain/entities/interview_entities.dart';
import '../../core/errors/interview_validators.dart';
import '../../core/errors/interview_exceptions.dart';

// ─── Enums ────────────────────────────────────────────────────────────────────

enum InterviewSessionStatus {
  idle,
  starting,
  active,
  paused,
  finished,
  uploading,
  error,
}

enum FeedbackLoadStatus { idle, loading, success, error }

// ─── State ────────────────────────────────────────────────────────────────────

class MockInterviewState {
  final List<InterviewFeedbackSummary> feedbackList;
  final FeedbackLoadStatus feedbackStatus;
  final InterviewSessionEntity? session;
  final InterviewSessionStatus sessionStatus;
  final int currentQuestionIndex;
  final int remainingSeconds;
  final List<int>? audioBytes;
  final bool isLoadingAudio;
  final bool waitingForAudio;
  final InterviewFeedbackDetailEntity? feedbackDetail;
  final bool isLoadingDetail;
  final double uploadProgress;
  final InterviewException? error;
  final String? languagePreferred;
  final List<IncompleteSessionEntity> incompleteSessions;
  final bool isLoadingIncomplete;
  final bool hasNoInternet;

  const MockInterviewState({
    this.feedbackList = const [],
    this.feedbackStatus = FeedbackLoadStatus.idle,
    this.session,
    this.sessionStatus = InterviewSessionStatus.idle,
    this.currentQuestionIndex = 0,
    this.remainingSeconds = 45,
    this.audioBytes,
    this.isLoadingAudio = false,
    this.waitingForAudio = false,
    this.feedbackDetail,
    this.isLoadingDetail = false,
    this.uploadProgress = 0.0,
    this.error,
    this.languagePreferred,
    this.incompleteSessions = const [],
    this.isLoadingIncomplete = false,
    this.hasNoInternet = false,
  });

  MockInterviewState copyWith({
    List<InterviewFeedbackSummary>? feedbackList,
    FeedbackLoadStatus? feedbackStatus,
    InterviewSessionEntity? session,
    InterviewSessionStatus? sessionStatus,
    int? currentQuestionIndex,
    int? remainingSeconds,
    List<int>? audioBytes,
    bool? isLoadingAudio,
    bool? waitingForAudio,
    InterviewFeedbackDetailEntity? feedbackDetail,
    bool? isLoadingDetail,
    double? uploadProgress,
    InterviewException? error,
    String? languagePreferred,
    bool clearError = false,
    bool clearSession = false,
    bool clearAudio = false,
    bool clearDetail = false,
    bool clearLanguage = false,
    List<IncompleteSessionEntity>? incompleteSessions,
    bool? isLoadingIncomplete,
    bool? hasNoInternet,
  }) {
    return MockInterviewState(
      feedbackList: feedbackList ?? this.feedbackList,
      feedbackStatus: feedbackStatus ?? this.feedbackStatus,
      session: clearSession ? null : (session ?? this.session),
      sessionStatus: sessionStatus ?? this.sessionStatus,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      audioBytes: clearAudio ? null : (audioBytes ?? this.audioBytes),
      isLoadingAudio: isLoadingAudio ?? this.isLoadingAudio,
      waitingForAudio: waitingForAudio ?? this.waitingForAudio,
      feedbackDetail:
          clearDetail ? null : (feedbackDetail ?? this.feedbackDetail),
      isLoadingDetail: isLoadingDetail ?? this.isLoadingDetail,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      error: clearError ? null : (error ?? this.error),
      languagePreferred:
          clearLanguage ? null : (languagePreferred ?? this.languagePreferred),
      incompleteSessions: incompleteSessions ?? this.incompleteSessions,
      isLoadingIncomplete: isLoadingIncomplete ?? this.isLoadingIncomplete,
      hasNoInternet: hasNoInternet ?? this.hasNoInternet,
    );
  }
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class MockInterviewNotifier extends StateNotifier<MockInterviewState> {
  final MockInterviewRepositoryImpl _repo;
  Timer? _questionTimer;
  final Set<String> _completedPolling = {};
  StreamSubscription? _connectivitySubscription;

  static const String _notifiedSessionsKey = 'notified_interview_sessions';

  MockInterviewNotifier(this._repo) : super(const MockInterviewState()) {
    _listenToConnectivity();
  }

  void _listenToConnectivity() {
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection) {
        retryPendingUploads();
      }
    });
  }

  // ── Load Feedback List ─────────────────────────────────────────────────────

  Future<void> loadFeedbackList() async {
    retryPendingUploads();
    state = state.copyWith(
      feedbackStatus: FeedbackLoadStatus.loading,
      clearError: true,
    );

    try {
      final sessions = await _repo.getLocalSessions();

      final Set<String> seenIds = {};
      final uniqueSessions = <Map<String, dynamic>>[];
      for (final s in sessions) {
        final id = s['session_id'] as String;
        if (!seenIds.contains(id)) {
          seenIds.add(id);
          uniqueSessions.add(s);
        }
      }

      final localSummaries = uniqueSessions
          .map((s) => InterviewFeedbackSummary(
                sessionId: s['session_id'] as String,
                roleName: s['role_name'] as String,
                sessionType: (s['session_type'] as String) == 'technical'
                    ? InterviewSessionType.technical
                    : InterviewSessionType.behavioral,
                createdAt: DateTime.tryParse(s['created_at'] as String) ??
                    DateTime.now(),
                languagePreferred: s['language_preferred'] as String?,
              ))
          .toList();

      state = state.copyWith(
        feedbackList: localSummaries,
        feedbackStatus: FeedbackLoadStatus.success,
      );

      _verifyWithServerInBackground(uniqueSessions);
    } catch (e) {
      state = state.copyWith(
        feedbackStatus: FeedbackLoadStatus.error,
        error: _parseError(e),
      );
    }
  }

// ── Retry Pending Uploads ──────────────────────────────────────────────────

  Future<void> retryPendingUploads() async {
    try {
      final pending = await _repo.getPendingUploads();
      if (pending.isEmpty) return;

      for (final p in pending) {
        final sessionId = p['session_id'] as String;
        final filePath = p['file_path'] as String;
        final roleName = p['role_name'] as String;
        final sessionType = (p['session_type'] as String) == 'technical'
            ? InterviewSessionType.technical
            : InterviewSessionType.behavioral;
        final blobUrl = p['blob_url'] as String;
        final sasToken = p['sas_token'] as String;
        final languagePreferred = p['language_preferred'] as String?;

        final file = File(filePath);
        if (!await file.exists()) {
          await _repo.removePendingUpload(sessionId);
          await _repo.deleteLocalSession(sessionId);
          continue;
        }

        try {
          await _repo.uploadToAzure(
            file: file,
            blobUrl: blobUrl,
            sasToken: sasToken,
            sessionType: sessionType,
          );

          await _repo.notifyUploadComplete(
            sessionId: sessionId,
            blobUrl: blobUrl,
            languagePreferred: languagePreferred,
          );

          await _repo.removePendingUpload(sessionId);

          _pollForReport(
            sessionId: sessionId,
            roleName: roleName,
            sessionType: sessionType,
          );
        } catch (_) {}
      }
    } catch (_) {}
  }

  // ── Load Incomplete Sessions ───────────────────────────────────────────────

  Future<void> loadIncompleteSessions() async {
    state = state.copyWith(isLoadingIncomplete: true);
    try {
      final sessions = await _repo.getIncompleteSessions();
      state = state.copyWith(
        incompleteSessions: sessions,
        isLoadingIncomplete: false,
      );
    } catch (_) {
      state = state.copyWith(isLoadingIncomplete: false);
    }
  }

// ── Save Current Session As Incomplete ────────────────────────────────────

  Future<void> saveAsIncomplete({
    required String roleName,
    required String? recordingPath,
  }) async {
    final session = state.session;
    if (session == null) return;

    await _repo.saveIncompleteSession(
      sessionId: session.sessionId,
      roleName: roleName,
      sessionType: session.sessionType,
      blobUrl: session.blobUrl,
      sasToken: session.sasToken,
      lastQuestionIndex: state.currentQuestionIndex,
      questions: session.questions,
      recordingPath: recordingPath,
      languagePreferred: state.languagePreferred,
    );

    await loadIncompleteSessions();
  }

// ── Update Incomplete Session Progress ────────────────────────────────────

  Future<void> updateIncompleteProgress({
    required String sessionId,
    required int questionIndex,
    String? recordingPath,
  }) async {
    await _repo.updateIncompleteSessionProgress(
      sessionId: sessionId,
      lastQuestionIndex: questionIndex,
      recordingPath: recordingPath,
    );
  }

// ── Resume Incomplete Session ─────────────────────────────────────────────

  Future<void> resumeIncompleteSession(
      IncompleteSessionEntity incomplete) async {
    _questionTimer?.cancel();

    final session = InterviewSessionEntity(
      sessionId: incomplete.sessionId,
      sasToken: incomplete.sasToken,
      blobUrl: incomplete.blobUrl,
      sasExpiresAt: DateTime.now().add(const Duration(hours: 1)),
      questions: incomplete.questions,
      sessionType: incomplete.sessionType,
    );

    state = state.copyWith(
      session: session,
      sessionStatus: InterviewSessionStatus.active,
      currentQuestionIndex: incomplete.lastQuestionIndex,
      remainingSeconds: 45,
      languagePreferred: incomplete.languagePreferred,
      clearError: true,
      clearAudio: true,
      waitingForAudio: false,
      hasNoInternet: false,
    );
  }

// ── Delete Incomplete Session ─────────────────────────────────────────────

  Future<void> deleteIncompleteSession(String sessionId) async {
    await _repo.deleteIncompleteSession(sessionId);
    final updated = state.incompleteSessions
        .where((s) => s.sessionId != sessionId)
        .toList();
    state = state.copyWith(incompleteSessions: updated);
  }

// ── Set No Internet ───────────────────────────────────────────────────────

  void setNoInternet(bool value) {
    state = state.copyWith(hasNoInternet: value);
  }

  // ── Verify With Server ─────────────────────────────────────────────────────

  Future<void> _verifyWithServerInBackground(
      List<Map<String, dynamic>> sessions) async {
    try {
      final futures = sessions.map((s) async {
        final sessionId = s['session_id'] as String;
        final sessionType = s['session_type'] as String? ?? '';
        try {
          String report;
          if (sessionType == 'technical') {
            report = await _repo.getTechnicalReport(sessionId);
          } else {
            report = await _repo.getBehavioralReport(sessionId);
          }
          if (_isReportReady(report)) {
            return s;
          } else {
            final pendingUploads = await _repo.getPendingUploads();
            final isPending =
                pendingUploads.any((p) => p['session_id'] == sessionId);
            if (isPending) return s;

            await _repo.deleteLocalSession(sessionId);
            return null;
          }
        } on SocketException {
          return s;
        } on HttpException {
          return s;
        } catch (_) {
          return s;
        }
      });

      final results = await Future.wait(futures);
      final verifiedSessions =
          results.whereType<Map<String, dynamic>>().toList();

      final summaries = verifiedSessions
          .map((s) => InterviewFeedbackSummary(
                sessionId: s['session_id'] as String,
                roleName: s['role_name'] as String,
                sessionType: (s['session_type'] as String) == 'technical'
                    ? InterviewSessionType.technical
                    : InterviewSessionType.behavioral,
                createdAt: DateTime.tryParse(s['created_at'] as String) ??
                    DateTime.now(),
                languagePreferred: s['language_preferred'] as String?,
              ))
          .toList();

      if (mounted) {
        state = state.copyWith(feedbackList: summaries);
      }
    } catch (_) {}
  }

  bool _isReportReady(String report) {
    final trimmed = report.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed == '{}') return false;
    if (trimmed == 'null') return false;
    if (trimmed == '""') return false;
    return trimmed.length > 10;
  }

  // ── Load Feedback Detail ───────────────────────────────────────────────────

  Future<void> loadFeedbackDetail(String sessionId) async {
    state = state.copyWith(isLoadingDetail: true, clearError: true);
    try {
      final sessions = await _repo.getLocalSessions();

      final session = sessions.firstWhere(
        (s) => s['session_id'] == sessionId,
        orElse: () => {},
      );

      final roleName = session['role_name'] as String? ?? '';
      final sessionTypeStr = session['session_type'] as String? ?? '';
      final languagePreferred = session['language_preferred'] as String?;

      String? behavioralReport;
      String? technicalReport;
      InterviewSessionType sessionType;

      if (sessionTypeStr == 'technical') {
        sessionType = InterviewSessionType.technical;
        technicalReport = await _repo.getTechnicalReport(sessionId);
      } else if (sessionTypeStr == 'behavioral') {
        sessionType = InterviewSessionType.behavioral;
        behavioralReport = await _repo.getBehavioralReport(sessionId);
      } else {
        sessionType = InterviewSessionType.technical;
        technicalReport = await _repo.getTechnicalReport(sessionId);
        if (!_isReportReady(technicalReport)) {
          technicalReport = null;
          sessionType = InterviewSessionType.behavioral;
          behavioralReport = await _repo.getBehavioralReport(sessionId);
        }
      }

      final report = behavioralReport ?? technicalReport ?? '';

      if (!_isReportReady(report)) {
        final detail = InterviewFeedbackDetailEntity(
          sessionId: sessionId,
          roleName: roleName,
          sessionType: sessionType,
          createdAt:
              DateTime.tryParse(session['created_at'] as String? ?? '') ??
                  DateTime.now(),
          strongPoints: [],
          areasForImprovement: [],
          suggestions: '',
          languagePreferred: languagePreferred,
        );
        state = state.copyWith(feedbackDetail: detail, isLoadingDetail: false);
        return;
      }
      final strongPoints = ReportParser.extractStrengths(report);

      final areasForImprovement = ReportParser.extractWeaknesses(report);
      final suggestions = ReportParser.extractSuggestions(report);

      final detail = InterviewFeedbackDetailEntity(
        sessionId: sessionId,
        roleName: roleName,
        sessionType: sessionType,
        createdAt: DateTime.tryParse(session['created_at'] as String? ?? '') ??
            DateTime.now(),
        strongPoints: strongPoints,
        areasForImprovement: areasForImprovement,
        suggestions: suggestions,
        behavioralReport: behavioralReport,
        technicalReport: technicalReport,
        languagePreferred: languagePreferred,
      );

      state = state.copyWith(feedbackDetail: detail, isLoadingDetail: false);
    } catch (e) {
      state = state.copyWith(
        isLoadingDetail: false,
        error: _parseError(e),
      );
    }
  }

  // ── Background Polling ─────────────────────────────────────────────────────

  Future<void> _pollForReport({
    required String sessionId,
    required String roleName,
    required InterviewSessionType sessionType,
    int maxAttempts = 30,
    int intervalSeconds = 15,
  }) async {
    if (_completedPolling.contains(sessionId)) return;
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      if (state.feedbackList.any((f) => f.sessionId == sessionId)) return;
      await Future.delayed(Duration(seconds: intervalSeconds));

      try {
        String report;
        if (sessionType == InterviewSessionType.technical) {
          report = await _repo.getTechnicalReport(sessionId);
        } else {
          report = await _repo.getBehavioralReport(sessionId);
        }

        if (_isReportReady(report)) {
          _completedPolling.add(sessionId);
          final sessions = await _repo.getLocalSessions();
          final sessionData = sessions.firstWhere(
            (s) => s['session_id'] == sessionId,
            orElse: () => {},
          );

          if (sessionData.isEmpty) {
            await _repo.saveSessionLocally(
              sessionId: sessionId,
              roleName: roleName,
              sessionType: sessionType,
            );
          }
          await _sendNotificationOnce(
            sessionId: sessionId,
            roleName: roleName,
            sessionType: sessionType,
          );

          final alreadyInList = state.feedbackList.any(
            (f) => f.sessionId == sessionId,
          );
          if (!alreadyInList) {
            final sessions2 = await _repo.getLocalSessions();
            final sessionData2 = sessions2.firstWhere(
              (s) => s['session_id'] == sessionId,
              orElse: () => {},
            );
            if (sessionData2.isNotEmpty) {
              final newSummary = InterviewFeedbackSummary(
                sessionId: sessionId,
                roleName: roleName,
                sessionType: sessionType,
                createdAt: DateTime.tryParse(
                      sessionData2['created_at'] as String? ?? '',
                    ) ??
                    DateTime.now(),
                languagePreferred:
                    sessionData2['language_preferred'] as String?,
              );
              state = state.copyWith(
                feedbackList: [newSummary, ...state.feedbackList],
              );
            }
          }
          return;
        }
      } catch (_) {}
    }
    _completedPolling.add(sessionId);

    await _repo.deleteLocalSession(sessionId);
  }

  // ── Notification ──────────────────────────────────────────────────────────

  Future<void> _sendNotificationOnce({
    required String sessionId,
    required String roleName,
    required InterviewSessionType sessionType,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notified = prefs.getStringList(_notifiedSessionsKey) ?? [];
      if (notified.contains(sessionId)) return;

      await NotificationHelper.showFeedbackReady(
        roleName: roleName,
        sessionId: sessionId,
      );

      await AlertsStore.instance.addInterviewFeedbackAlert(
        roleName: roleName,
        sessionId: sessionId,
        sessionType: sessionType == InterviewSessionType.technical
            ? 'technical'
            : 'behavioral',
      );

      notified.add(sessionId);
      await prefs.setStringList(_notifiedSessionsKey, notified);
    } catch (_) {}
  }

  // ── Delete Feedback ────────────────────────────────────────────────────────

  Future<void> deleteFeedback(String sessionId) async {
    try {
      await _repo.deleteLocalSession(sessionId);

      final prefs = await SharedPreferences.getInstance();
      final notified = prefs.getStringList(_notifiedSessionsKey) ?? [];
      notified.remove(sessionId);
      await prefs.setStringList(_notifiedSessionsKey, notified);

      final updated =
          state.feedbackList.where((f) => f.sessionId != sessionId).toList();
      state = state.copyWith(feedbackList: updated);
    } catch (e) {
      state = state.copyWith(error: _parseError(e));
    }
  }

  // ── Start Session ──────────────────────────────────────────────────────────

  Future<void> startSession({
    required String roleName,
    required String roleId,
    required InterviewSessionType sessionType,
    String? languagePreferred,
  }) async {
    final connectivity = await Connectivity().checkConnectivity();
    final hasInternet = connectivity.any((r) => r != ConnectivityResult.none);

    if (!hasInternet) {
      state = state.copyWith(
        sessionStatus: InterviewSessionStatus.error,
        error: InterviewException.noInternet(),
      );
      return;
    }
    state = state.copyWith(
      sessionStatus: InterviewSessionStatus.starting,
      clearError: true,
      currentQuestionIndex: 0,
      languagePreferred: languagePreferred,
    );

    try {
      InterviewValidators.requireRoleSelected(
          roleId.isNotEmpty ? roleId : null);
      final userId = Supabase.instance.client.auth.currentUser?.id ?? '';

      InterviewSessionEntity session;
      if (sessionType == InterviewSessionType.behavioral) {
        session = await _repo.startBehavioralSession(
          roleName: roleName,
          userId: userId,
          languagePreferred: languagePreferred,
        );
      } else {
        session = await _repo.startTechnicalSession(
          roleName: roleName,
          userId: userId,
          languagePreferred: languagePreferred,
        );
      }

      state = state.copyWith(
        session: session,
        sessionStatus: InterviewSessionStatus.active,
        remainingSeconds: 45,
        waitingForAudio: true,
      );

      if (session.questions.isNotEmpty) {
        await _loadQuestionAudio(
          session.questions.first.questionId,
          languagePreferred: languagePreferred,
        );
      }
    } on InterviewException catch (e) {
      state = state.copyWith(
        sessionStatus: InterviewSessionStatus.error,
        error: e,
      );
    } catch (e) {
      state = state.copyWith(
        sessionStatus: InterviewSessionStatus.error,
        error: InterviewValidators.fromNetworkError(e),
      );
    }
  }

  // ── Timer ──────────────────────────────────────────────────────────────────

  void startQuestionTimer() {
    _questionTimer?.cancel();
    state = state.copyWith(waitingForAudio: false);
    _questionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.sessionStatus != InterviewSessionStatus.active) {
        _questionTimer?.cancel();
        return;
      }
      final remaining = state.remainingSeconds - 1;
      if (remaining <= 0) {
        _questionTimer?.cancel();
        _advanceQuestion();
      } else {
        state = state.copyWith(remainingSeconds: remaining);
      }
    });
  }

  // ── Advance Question ───────────────────────────────────────────────────────

  void _advanceQuestion() {
    final session = state.session;
    if (session == null) return;
    final nextIndex = state.currentQuestionIndex + 1;

    if (nextIndex >= session.questions.length) {
      _questionTimer?.cancel();
      state = state.copyWith(
        sessionStatus: InterviewSessionStatus.finished,
        remainingSeconds: 0,
        waitingForAudio: false,
      );
      return;
    }

    state = state.copyWith(
      currentQuestionIndex: nextIndex,
      remainingSeconds: 45,
      clearAudio: true,
      waitingForAudio: true,
    );
    _loadQuestionAudio(
      session.questions[nextIndex].questionId,
      languagePreferred: state.languagePreferred,
    );
  }

  // ── Load Audio ─────────────────────────────────────────────────────────────

  Future<void> _loadQuestionAudio(
    String questionId, {
    String? languagePreferred,
  }) async {
    state = state.copyWith(isLoadingAudio: true);
    try {
      final bytes = await _repo.getQuestionAudio(
        questionId,
        languagePreferred: languagePreferred,
      );
      if (bytes.isEmpty) {
        state = state.copyWith(isLoadingAudio: false, waitingForAudio: false);
        startQuestionTimer();
        return;
      }
      state = state.copyWith(audioBytes: bytes, isLoadingAudio: false);
    } catch (_) {
      state = state.copyWith(isLoadingAudio: false, waitingForAudio: false);
      startQuestionTimer();
    }
  }

  // ── Pause / Resume ─────────────────────────────────────────────────────────

  void pauseInterview() {
    _questionTimer?.cancel();
    state = state.copyWith(sessionStatus: InterviewSessionStatus.paused);
  }

  void resumeInterview() {
    state = state.copyWith(sessionStatus: InterviewSessionStatus.active);
  }

  void skipToNext() {
    _questionTimer?.cancel();
    _advanceQuestion();
  }

  void restartInterview() {
    _questionTimer?.cancel();
    final session = state.session;
    if (session == null) return;
    state = state.copyWith(
      sessionStatus: InterviewSessionStatus.active,
      currentQuestionIndex: 0,
      remainingSeconds: 45,
      clearAudio: true,
      waitingForAudio: true,
    );
    if (session.questions.isNotEmpty) {
      _loadQuestionAudio(
        session.questions.first.questionId,
        languagePreferred: state.languagePreferred,
      );
    }
  }

  // ── Upload & Notify ────────────────────────────────────────────────────────

  Future<void> uploadAndNotify({
    required File mediaFile,
    required String roleName,
  }) async {
    final session = state.session;
    if (session == null) return;

    final sessionId = session.sessionId;
    final blobUrl = session.blobUrl;
    final sasToken = session.sasToken;
    final sessionType = session.sessionType;
    final languagePreferred = state.languagePreferred;

    state = state.copyWith(
      sessionStatus: InterviewSessionStatus.uploading,
      uploadProgress: 0.0,
    );

    try {
      //  Validate session + SAS token
      InterviewValidators.requireActiveSession(session);

      await InterviewValidators.requireValidFile(
        mediaFile,
        isVideo: session.sessionType == InterviewSessionType.behavioral,
      );

      await _repo.uploadToAzure(
        file: mediaFile,
        blobUrl: blobUrl,
        sasToken: sasToken,
        sessionType: sessionType,
      );

      state = state.copyWith(uploadProgress: 0.8);

      await _repo.notifyUploadComplete(
        sessionId: sessionId,
        blobUrl: blobUrl,
        languagePreferred: languagePreferred,
      );

      await _repo.saveSessionLocally(
        sessionId: sessionId,
        roleName: roleName,
        sessionType: sessionType,
        languagePreferred: languagePreferred,
      );

      state = state.copyWith(
        sessionStatus: InterviewSessionStatus.finished,
        uploadProgress: 1.0,
      );

      _pollForReport(
        sessionId: sessionId,
        roleName: roleName,
        sessionType: sessionType,
      );
    } on InterviewException catch (e) {
      state = state.copyWith(
        sessionStatus: InterviewSessionStatus.error,
        error: e,
      );
    } catch (e) {
      final exception = InterviewValidators.fromNetworkError(e);

      if (exception.type == InterviewErrorType.noInternet ||
          exception.type == InterviewErrorType.timeout) {
        await _repo.savePendingUpload(
          sessionId: sessionId,
          filePath: mediaFile.path,
          roleName: roleName,
          sessionType: sessionType,
          blobUrl: blobUrl,
          sasToken: sasToken,
          languagePreferred: languagePreferred,
        );

        await _repo.saveSessionLocally(
          sessionId: sessionId,
          roleName: roleName,
          sessionType: sessionType,
          languagePreferred: languagePreferred,
        );
      }

      state = state.copyWith(
        sessionStatus: InterviewSessionStatus.error,
        error: exception,
      );
    }
  }

  // ── Reset ──────────────────────────────────────────────────────────────────

  void resetSession() {
    _questionTimer?.cancel();
    state = state.copyWith(
      clearSession: true,
      sessionStatus: InterviewSessionStatus.idle,
      currentQuestionIndex: 0,
      clearAudio: true,
      clearError: true,
      clearLanguage: true,
      uploadProgress: 0.0,
      waitingForAudio: false,
    );
  }

  void clearFeedbackDetail() => state = state.copyWith(clearDetail: true);

  InterviewRole? findRole(String jobTitle) =>
      InterviewRoles.findByName(jobTitle);

  InterviewException _parseError(Object e) {
    if (e is InterviewException) return e;
    return InterviewValidators.fromNetworkError(e);
  }

  @override
  void dispose() {
    _questionTimer?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────

final mockInterviewRepositoryProvider = Provider<MockInterviewRepositoryImpl>(
  (ref) => MockInterviewRepositoryImpl(),
);

final mockInterviewProvider =
    StateNotifierProvider<MockInterviewNotifier, MockInterviewState>(
  (ref) => MockInterviewNotifier(
    ref.read(mockInterviewRepositoryProvider),
  ),
);

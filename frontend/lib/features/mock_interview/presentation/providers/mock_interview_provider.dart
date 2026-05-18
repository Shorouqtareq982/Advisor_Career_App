import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/datasources/interview_roles.dart';
import '../../data/repositories/mock_interview_repository_impl.dart';
import '../../../mock_interview/presentation/providers/notification_helper.dart';
import '../../../alerts/data/datasources/alerts_local_datasource.dart';
import '../../domain/entities/interview_entities.dart';
import '../../data/models/interview_models.dart' hide ReportParser;

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
  final String? errorMessage;
  final String? languagePreferred;

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
    this.errorMessage,
    this.languagePreferred,
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
    String? errorMessage,
    String? languagePreferred,
    bool clearError = false,
    bool clearSession = false,
    bool clearAudio = false,
    bool clearDetail = false,
    bool clearLanguage = false,
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
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      languagePreferred:
          clearLanguage ? null : (languagePreferred ?? this.languagePreferred),
    );
  }
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class MockInterviewNotifier extends StateNotifier<MockInterviewState> {
  final MockInterviewRepositoryImpl _repo;
  Timer? _questionTimer;
  final Set<String> _completedPolling = {};

  static const String _notifiedSessionsKey = 'notified_interview_sessions';

  MockInterviewNotifier(this._repo) : super(const MockInterviewState());

  // ── Load Feedback List ─────────────────────────────────────────────────────

  Future<void> loadFeedbackList() async {
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

      // ← اعرض اللي محفوظ locally فورًا (offline-first)
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

      // ← verify من السيرفر في background بدون ما تمسح حاجة لو فشل
      _verifyWithServerInBackground(uniqueSessions);
    } catch (e) {
      state = state.copyWith(
        feedbackStatus: FeedbackLoadStatus.error,
        errorMessage: _parseError(e),
      );
    }
  }

  // ── Verify With Server ─────────────────────────────────────────────────────
  // FIX: لو الريبورت فاضي، امسح الـ session من Supabase والـ cache مش بس من الليست

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
            return s; // ريبورت جاهز: احتفظ
          } else {
            // FIX: ريبورت فاضي = session مش مكتملة، امسحها فعلياً
            await _repo.deleteLocalSession(sessionId);
            return null;
          }
        } on SocketException {
          return s; // مفيش نت: احتفظ
        } on HttpException {
          return s; // server error: احتفظ
        } catch (_) {
          return s; // أي error غير متوقع: احتفظ (safe default)
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

  // FIX: helper يتحقق إن الريبورت فيه محتوى حقيقي
  bool _isReportReady(String report) {
    final trimmed = report.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed == '{}') return false;
    if (trimmed == 'null') return false;
    if (trimmed == '""') return false;
    // لازم يكون فيه على الأقل نص حقيقي (أكتر من 10 حروف)
    return trimmed.length > 10;
  }

  // ── Load Feedback Detail ───────────────────────────────────────────────────

  Future<void> loadFeedbackDetail(String sessionId) async {
    state = state.copyWith(isLoadingDetail: true, clearError: true);
    try {
      final sessions = await _repo.getLocalSessions();

      // مؤقت للـ debug
      print('🔍 sessions found: ${sessions.length}');
      print('🔍 looking for: $sessionId');
      print('🔍 all ids: ${sessions.map((s) => s['session_id']).toList()}');

      final session = sessions.firstWhere(
        (s) => s['session_id'] == sessionId,
        orElse: () => {},
      );

      print('🔍 session found: $session');

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
        // النوع مش معروف، جرب technical الأول
        sessionType = InterviewSessionType.technical;
        technicalReport = await _repo.getTechnicalReport(sessionId);
        if (!_isReportReady(technicalReport)) {
          technicalReport = null;
          sessionType = InterviewSessionType.behavioral;
          behavioralReport = await _repo.getBehavioralReport(sessionId);
        }
      }

      final report = behavioralReport ?? technicalReport ?? '';
      print('🔍 report length: ${report.length}');
      print('🔍 report ready: ${_isReportReady(report)}');
      print(
          '🔍 report preview: ${report.substring(0, report.length > 100 ? 100 : report.length)}');
      final strongPoints = ReportParser.extractStrengths(report);
      print('🔍 strongPoints: $strongPoints');

      // FIX: لو الريبورت لسه مش جاهز، حط detail فاضي (pending state)
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
        errorMessage: _parseError(e),
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

        // FIX: استخدم _isReportReady بدل report.isNotEmpty
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
      state = state.copyWith(errorMessage: _parseError(e));
    }
  }

  // ── Start Session ──────────────────────────────────────────────────────────

  Future<void> startSession({
    required String roleName,
    required String roleId,
    required InterviewSessionType sessionType,
    String? languagePreferred,
  }) async {
    state = state.copyWith(
      sessionStatus: InterviewSessionStatus.starting,
      clearError: true,
      currentQuestionIndex: 0,
      languagePreferred: languagePreferred,
    );

    try {
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
    } catch (e) {
      state = state.copyWith(
        sessionStatus: InterviewSessionStatus.error,
        errorMessage: _parseError(e),
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
    _loadQuestionAudioAndNotify(
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

  Future<void> _loadQuestionAudioAndNotify(
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
    // ← امسح الـ startQuestionTimer من هنا خالص
    // الـ UI هو اللي هيقرر يشغّل الـ timer بعد ما الصوت يخلص
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

      // حفظ الـ session بس بعد ما الـ upload ينجح فعلاً
      await _repo.saveSessionLocally(
        sessionId: sessionId,
        roleName: roleName,
        sessionType: sessionType,
        languagePreferred: languagePreferred,
      );

      // FIX: حوّل لـ finished فوراً بعد الـ notify، مش بعد الـ processing
      state = state.copyWith(
        sessionStatus: InterviewSessionStatus.finished,
        uploadProgress: 1.0,
      );

      // الـ polling يحصل في background بدون ما يأثر على الـ UI
      _pollForReport(
        sessionId: sessionId,
        roleName: roleName,
        sessionType: sessionType,
      );
    } catch (e) {
      state = state.copyWith(
        sessionStatus: InterviewSessionStatus.error,
        errorMessage: _parseError(e),
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

  String _parseError(Object e) {
    final msg = e.toString();
    if (msg.contains('SocketException') ||
        msg.contains('Failed host lookup') ||
        msg.contains('Connection refused')) {
      return 'No internet connection. Please check your network.';
    }
    if (msg.contains('TimeoutException') || msg.contains('timed out')) {
      return 'Connection timed out. Please try again.';
    }
    if (msg.contains('401') || msg.contains('Unauthorized')) {
      return 'Session expired. Please sign in again.';
    }
    if (msg.contains('404')) return 'Session not found.';
    if (msg.contains('500')) return 'Server error. Please try again later.';
    return 'Something went wrong. Please try again.';
  }

  @override
  void dispose() {
    _questionTimer?.cancel();
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

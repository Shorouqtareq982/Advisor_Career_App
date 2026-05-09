import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/interview_roles.dart';
import '../../data/repositories/mock_interview_repository_impl.dart';
import '../../domain/entities/interview_entities.dart';
import '../../domain/repositories/mock_interview_repository.dart';

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
  // Feedback list
  final List<InterviewFeedbackSummary> feedbackList;
  final FeedbackLoadStatus feedbackStatus;

  // Current session
  final InterviewSessionEntity? session;
  final InterviewSessionStatus sessionStatus;

  // Current question index (0-based)
  final int currentQuestionIndex;

  // Timer
  final int remainingSeconds;

  // Current question audio bytes
  final List<int>? audioBytes;
  final bool isLoadingAudio;

  // Feedback detail
  final InterviewFeedbackDetailEntity? feedbackDetail;
  final bool isLoadingDetail;

  // Upload progress
  final double uploadProgress;

  final String? errorMessage;

  const MockInterviewState({
    this.feedbackList = const [],
    this.feedbackStatus = FeedbackLoadStatus.idle,
    this.session,
    this.sessionStatus = InterviewSessionStatus.idle,
    this.currentQuestionIndex = 0,
    this.remainingSeconds = 30,
    this.audioBytes,
    this.isLoadingAudio = false,
    this.feedbackDetail,
    this.isLoadingDetail = false,
    this.uploadProgress = 0.0,
    this.errorMessage,
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
    InterviewFeedbackDetailEntity? feedbackDetail,
    bool? isLoadingDetail,
    double? uploadProgress,
    String? errorMessage,
    bool clearError = false,
    bool clearSession = false,
    bool clearAudio = false,
    bool clearDetail = false,
  }) {
    return MockInterviewState(
      feedbackList: feedbackList ?? this.feedbackList,
      feedbackStatus: feedbackStatus ?? this.feedbackStatus,
      session: clearSession ? null : (session ?? this.session),
      sessionStatus: sessionStatus ?? this.sessionStatus,
      currentQuestionIndex:
          currentQuestionIndex ?? this.currentQuestionIndex,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      audioBytes: clearAudio ? null : (audioBytes ?? this.audioBytes),
      isLoadingAudio: isLoadingAudio ?? this.isLoadingAudio,
      feedbackDetail:
          clearDetail ? null : (feedbackDetail ?? this.feedbackDetail),
      isLoadingDetail: isLoadingDetail ?? this.isLoadingDetail,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class MockInterviewNotifier extends StateNotifier<MockInterviewState> {
  final MockInterviewRepository _repo;

  Timer? _questionTimer;

  MockInterviewNotifier(this._repo) : super(const MockInterviewState());

  // ── Feedback List ──────────────────────────────────────────────────────────

  Future<void> loadFeedbackList() async {
    state = state.copyWith(
        feedbackStatus: FeedbackLoadStatus.loading, clearError: true);
    try {
      final list = await _repo.getFeedbackList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      state = state.copyWith(
          feedbackList: list, feedbackStatus: FeedbackLoadStatus.success);
    } catch (e) {
      state = state.copyWith(
        feedbackStatus: FeedbackLoadStatus.error,
        errorMessage: _parseError(e),
      );
    }
  }

  // ── Feedback Detail ────────────────────────────────────────────────────────

  Future<void> loadFeedbackDetail(String sessionId) async {
    state = state.copyWith(isLoadingDetail: true, clearError: true);
    try {
      final detail = await _repo.getFeedbackDetail(sessionId);
      state =
          state.copyWith(feedbackDetail: detail, isLoadingDetail: false);
    } catch (e) {
      state = state.copyWith(
        isLoadingDetail: false,
        errorMessage: _parseError(e),
      );
    }
  }

  // ── Delete Feedback ────────────────────────────────────────────────────────

  Future<void> deleteFeedback(String sessionId) async {
    try {
      await _repo.deleteFeedback(sessionId);
      final updated = state.feedbackList
          .where((f) => f.sessionId != sessionId)
          .toList();
      state = state.copyWith(feedbackList: updated);
    } catch (e) {
      state = state.copyWith(errorMessage: _parseError(e));
    }
  }

  // ── Start Session ──────────────────────────────────────────────────────────

  Future<void> startSession({
    required String roleName,
    required String roleId,
  }) async {
    state = state.copyWith(
      sessionStatus: InterviewSessionStatus.starting,
      clearError: true,
      currentQuestionIndex: 0,
    );
    try {
      final session = await _repo.startSession(
          roleName: roleName, roleId: roleId);
      state = state.copyWith(
        session: session,
        sessionStatus: InterviewSessionStatus.active,
        remainingSeconds:
            session.questions.isNotEmpty
                ? session.questions.first.durationSeconds
                : 30,
      );
      // Load audio for first question
      if (session.questions.isNotEmpty) {
        _loadQuestionAudio(session.questions.first.questionId);
      }
      _startQuestionTimer();
    } catch (e) {
      state = state.copyWith(
        sessionStatus: InterviewSessionStatus.error,
        errorMessage: _parseError(e),
      );
    }
  }

  // ── Question Timer ─────────────────────────────────────────────────────────

  void _startQuestionTimer() {
    _questionTimer?.cancel();
    _questionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.sessionStatus != InterviewSessionStatus.active) return;
      final remaining = state.remainingSeconds - 1;
      if (remaining <= 0) {
        _questionTimer?.cancel();
        _advanceQuestion();
      } else {
        state = state.copyWith(remainingSeconds: remaining);
      }
    });
  }

  void _advanceQuestion() {
    final session = state.session;
    if (session == null) return;

    final nextIndex = state.currentQuestionIndex + 1;
    if (nextIndex >= session.questions.length) {
      // All questions done
      state = state.copyWith(
        sessionStatus: InterviewSessionStatus.finished,
      );
      return;
    }

    final nextQuestion = session.questions[nextIndex];
    state = state.copyWith(
      currentQuestionIndex: nextIndex,
      remainingSeconds: nextQuestion.durationSeconds,
      clearAudio: true,
    );
    _loadQuestionAudio(nextQuestion.questionId);
    _startQuestionTimer();
  }

  // ── Pause / Resume ─────────────────────────────────────────────────────────

  void pauseInterview() {
    _questionTimer?.cancel();
    state = state.copyWith(sessionStatus: InterviewSessionStatus.paused);
  }

  void resumeInterview() {
    state = state.copyWith(sessionStatus: InterviewSessionStatus.active);
    _startQuestionTimer();
  }

  // ── Restart ────────────────────────────────────────────────────────────────

  void restartInterview() {
    _questionTimer?.cancel();
    final session = state.session;
    if (session == null) return;
    state = state.copyWith(
      sessionStatus: InterviewSessionStatus.active,
      currentQuestionIndex: 0,
      remainingSeconds: session.questions.isNotEmpty
          ? session.questions.first.durationSeconds
          : 30,
      clearAudio: true,
    );
    if (session.questions.isNotEmpty) {
      _loadQuestionAudio(session.questions.first.questionId);
    }
    _startQuestionTimer();
  }

  // ── Load Audio ─────────────────────────────────────────────────────────────

  Future<void> _loadQuestionAudio(String questionId) async {
    state = state.copyWith(isLoadingAudio: true);
    try {
      final bytes = await _repo.getQuestionAudio(questionId);
      state = state.copyWith(audioBytes: bytes, isLoadingAudio: false);
    } catch (e) {
      // Audio failure is non-fatal — question text still shows
      state = state.copyWith(isLoadingAudio: false);
    }
  }

  // ── Upload & Notify ────────────────────────────────────────────────────────

  Future<void> uploadAndNotify({required File videoFile}) async {
    final session = state.session;
    if (session == null) return;

    state = state.copyWith(
      sessionStatus: InterviewSessionStatus.uploading,
      uploadProgress: 0.0,
    );
    try {
      final videoUrl = await _repo.uploadVideoToAzure(
        videoFile: videoFile,
        sasToken: session.sasToken,
        sessionId: session.sessionId,
      );
      await _repo.notifyUploadComplete(
        sessionId: session.sessionId,
        videoUrl: videoUrl,
      );
      state = state.copyWith(
        sessionStatus: InterviewSessionStatus.finished,
        uploadProgress: 1.0,
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
      uploadProgress: 0.0,
    );
  }

  void clearFeedbackDetail() {
    state = state.copyWith(clearDetail: true);
  }

  // ── Role matching ──────────────────────────────────────────────────────────

  /// Finds matching role — returns null if not supported
  InterviewRole? findRole(String jobTitle) =>
      InterviewRoles.findByName(jobTitle);

  // ── Error parser ───────────────────────────────────────────────────────────

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

final mockInterviewRepositoryProvider = Provider<MockInterviewRepository>(
  (ref) => MockInterviewRepositoryImpl(),
);

final mockInterviewProvider =
    StateNotifierProvider<MockInterviewNotifier, MockInterviewState>(
  (ref) => MockInterviewNotifier(
    ref.read(mockInterviewRepositoryProvider),
  ),
);

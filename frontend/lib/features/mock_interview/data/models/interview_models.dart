import '../../domain/entities/interview_entities.dart';

// ─── Session Model ────────────────────────────────────────────────────────────

class InterviewSessionModel {
  final String sessionId;
  final String roleName;
  final String sasToken;
  final List<InterviewQuestionModel> questions;

  const InterviewSessionModel({
    required this.sessionId,
    required this.roleName,
    required this.sasToken,
    required this.questions,
  });

  factory InterviewSessionModel.fromJson(Map<String, dynamic> json) {
    final rawQuestions = json['questions'] as List<dynamic>? ?? [];
    return InterviewSessionModel(
      sessionId: json['session_id'] as String? ?? '',
      roleName: json['role_name'] as String? ?? '',
      sasToken: json['sas_token'] as String? ?? '',
      questions: rawQuestions
          .map(
              (q) => InterviewQuestionModel.fromJson(q as Map<String, dynamic>))
          .toList(),
    );
  }

  InterviewSessionEntity toEntity() => InterviewSessionEntity(
        sessionId: sessionId,
        roleName: roleName,
        sasToken: sasToken,
        questions: questions.map((q) => q.toEntity()).toList(),
      );
}

// ─── Question Model ───────────────────────────────────────────────────────────

class InterviewQuestionModel {
  final String questionId;
  final String questionText;
  final int orderIndex;
  final int durationSeconds;

  const InterviewQuestionModel({
    required this.questionId,
    required this.questionText,
    required this.orderIndex,
    this.durationSeconds = 30,
  });

  factory InterviewQuestionModel.fromJson(Map<String, dynamic> json) =>
      InterviewQuestionModel(
        questionId: json['question_id'] as String? ?? '',
        questionText: json['question_text'] as String? ?? '',
        orderIndex: json['order_index'] as int? ?? 0,
        durationSeconds: json['duration_seconds'] as int? ?? 30,
      );

  InterviewQuestionEntity toEntity() => InterviewQuestionEntity(
        questionId: questionId,
        questionText: questionText,
        orderIndex: orderIndex,
        durationSeconds: durationSeconds,
      );
}

// ─── Feedback Summary Model ───────────────────────────────────────────────────

class InterviewFeedbackSummaryModel {
  final String sessionId;
  final String roleName;
  final int score;
  final String recommendation;
  final DateTime createdAt;

  const InterviewFeedbackSummaryModel({
    required this.sessionId,
    required this.roleName,
    required this.score,
    required this.recommendation,
    required this.createdAt,
  });

  factory InterviewFeedbackSummaryModel.fromJson(Map<String, dynamic> json) =>
      InterviewFeedbackSummaryModel(
        sessionId: json['session_id'] as String? ?? '',
        roleName: json['role_name'] as String? ?? '',
        score: json['score'] as int? ?? 0,
        recommendation: json['recommendation'] as String? ?? '',
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
            : DateTime.now(),
      );

  InterviewFeedbackSummary toEntity() => InterviewFeedbackSummary(
        sessionId: sessionId,
        roleName: roleName,
        score: score,
        recommendation: recommendation,
        createdAt: createdAt,
      );
}

// ─── Feedback Detail Model ────────────────────────────────────────────────────

class InterviewFeedbackDetailModel {
  final String sessionId;
  final String roleName;
  final int score;
  final String recommendation;
  final List<String> strongPoints;
  final List<String> areasForImprovement;
  final String suggestions;
  final DateTime createdAt;

  const InterviewFeedbackDetailModel({
    required this.sessionId,
    required this.roleName,
    required this.score,
    required this.recommendation,
    required this.strongPoints,
    required this.areasForImprovement,
    required this.suggestions,
    required this.createdAt,
  });

  factory InterviewFeedbackDetailModel.fromJson(Map<String, dynamic> json) =>
      InterviewFeedbackDetailModel(
        sessionId: json['session_id'] as String? ?? '',
        roleName: json['role_name'] as String? ?? '',
        score: json['score'] as int? ?? 0,
        recommendation: json['recommendation'] as String? ?? '',
        strongPoints: _toList(json['strong_points']),
        areasForImprovement: _toList(json['areas_for_improvement']),
        suggestions: json['suggestions'] as String? ?? '',
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
            : DateTime.now(),
      );

  InterviewFeedbackDetailEntity toEntity() => InterviewFeedbackDetailEntity(
        sessionId: sessionId,
        roleName: roleName,
        score: score,
        recommendation: recommendation,
        strongPoints: strongPoints,
        areasForImprovement: areasForImprovement,
        suggestions: suggestions,
        createdAt: createdAt,
      );
}

List<String> _toList(dynamic value) {
  if (value == null) return [];
  if (value is List) return value.map((e) => e.toString()).toList();
  return [];
}

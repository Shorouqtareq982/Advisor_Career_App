import '../../domain/entities/interview_entities.dart';

// ─── Question Model ───────────────────────────────────────────────────────────

class InterviewQuestionModel {
  final String questionId;
  final String questionText;

  const InterviewQuestionModel({
    required this.questionId,
    required this.questionText,
  });

  factory InterviewQuestionModel.fromJson(Map<String, dynamic> json) =>
      InterviewQuestionModel(
        questionId: json['question_id'] as String? ?? '',
        questionText: json['question_text'] as String? ?? '',
      );

  InterviewQuestionEntity toEntity() => InterviewQuestionEntity(
        questionId: questionId,
        questionText: questionText,
      );
}

// ─── Session Response Model ───────────────────────────────────────────────────

class InterviewSessionModel {
  final String sessionId;
  final String sasToken;
  final String blobUrl;
  final DateTime sasExpiresAt;
  final List<InterviewQuestionModel> questions;

  const InterviewSessionModel({
    required this.sessionId,
    required this.sasToken,
    required this.blobUrl,
    required this.sasExpiresAt,
    required this.questions,
  });

  factory InterviewSessionModel.fromJson(Map<String, dynamic> json) {
    final rawQuestions = json['questions'] as List<dynamic>? ?? [];
    return InterviewSessionModel(
      sessionId: json['session_id']?.toString() ?? '',
      sasToken: json['sas_token'] as String? ?? '',
      blobUrl: json['blob_url'] as String? ?? '',
      sasExpiresAt: json['sas_expires_at'] != null
          ? DateTime.tryParse(json['sas_expires_at'].toString()) ??
              DateTime.now().add(const Duration(hours: 1))
          : DateTime.now().add(const Duration(hours: 1)),
      questions: rawQuestions
          .map(
              (q) => InterviewQuestionModel.fromJson(q as Map<String, dynamic>))
          .toList(),
    );
  }

  InterviewSessionEntity toEntity(InterviewSessionType sessionType) =>
      InterviewSessionEntity(
        sessionId: sessionId,
        sasToken: sasToken,
        blobUrl: blobUrl,
        sasExpiresAt: sasExpiresAt,
        questions: questions.map((q) => q.toEntity()).toList(),
        sessionType: sessionType,
      );
}

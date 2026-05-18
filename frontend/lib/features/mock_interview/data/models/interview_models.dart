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

// ─── Report Parser ────────────────────────────────────────────────────────────
// **Strengths**
// - bullet 1
// - bullet 2
//
// **Weaknesses**
// - bullet 1
// - bullet 2
//
// **Suggestions**
// - suggestion 1
// - suggestion 2

class ReportParser {
  // ← English
  static List<String> extractStrengths(String report) =>
      _extractSection(report, ['Strengths', 'نقاط القوة']);

  static List<String> extractWeaknesses(String report) =>
      _extractSection(report, ['Weaknesses', 'نقاط الضعف']);

  static String extractSuggestions(String report) =>
      _extractSectionText(report, ['Suggestions', 'التوصيات', 'الاقتراحات']);

  static List<String> _extractSection(String report, List<String> headings) {
    for (final heading in headings) {
      final pattern = RegExp(
        r'\*{1,2}' +
            RegExp.escape(heading) +
            r'\*{1,2}\s*\n(.*?)(?=\n\s*\*{1,2}|\s*$)',
        dotAll: true,
        caseSensitive: false,
      );
      final match = pattern.firstMatch(report);
      if (match != null) {
        return match
            .group(1)!
            .split('\n')
            .map((l) => l.trim().replaceFirst(RegExp(r'^[-•*]\s*'), ''))
            .where((l) => l.isNotEmpty)
            .toList();
      }
    }
    return [];
  }

  static String _extractSectionText(String report, List<String> headings) {
    for (final heading in headings) {
      final pattern = RegExp(
        r'\*{1,2}' +
            RegExp.escape(heading) +
            r'\*{1,2}\s*\n(.*?)(?=\n\s*\*{1,2}|\s*$)',
        dotAll: true,
        caseSensitive: false,
      );
      final match = pattern.firstMatch(report);
      if (match != null) {
        return match
            .group(1)!
            .split('\n')
            .map((l) => l.trim().replaceFirst(RegExp(r'^[-•*]\s*'), ''))
            .where((l) => l.isNotEmpty)
            .join('\n');
      }
    }
    return '';
  }
}

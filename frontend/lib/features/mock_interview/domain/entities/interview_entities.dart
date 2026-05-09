// ─── Interview Session Entity ─────────────────────────────────────────────────

class InterviewSessionEntity {
  final String sessionId;
  final String roleName;
  final String sasToken;
  final List<InterviewQuestionEntity> questions;

  const InterviewSessionEntity({
    required this.sessionId,
    required this.roleName,
    required this.sasToken,
    required this.questions,
  });
}

// ─── Interview Question Entity ────────────────────────────────────────────────

class InterviewQuestionEntity {
  final String questionId;
  final String questionText;
  final int orderIndex;
  final int durationSeconds;

  const InterviewQuestionEntity({
    required this.questionId,
    required this.questionText,
    required this.orderIndex,
    this.durationSeconds = 30,
  });
}

// ─── Interview Feedback Summary Entity ───────────────────────────────────────

class InterviewFeedbackSummary {
  final String sessionId;
  final String roleName;
  final int score;
  final String recommendation;
  final DateTime createdAt;

  const InterviewFeedbackSummary({
    required this.sessionId,
    required this.roleName,
    required this.score,
    required this.recommendation,
    required this.createdAt,
  });
}

// ─── Interview Feedback Detail Entity ────────────────────────────────────────

class InterviewFeedbackDetailEntity {
  final String sessionId;
  final String roleName;
  final int score;
  final String recommendation;
  final List<String> strongPoints;
  final List<String> areasForImprovement;
  final String suggestions;
  final DateTime createdAt;

  const InterviewFeedbackDetailEntity({
    required this.sessionId,
    required this.roleName,
    required this.score,
    required this.recommendation,
    required this.strongPoints,
    required this.areasForImprovement,
    required this.suggestions,
    required this.createdAt,
  });
}

// ─── Available Roles ──────────────────────────────────────────────────────────

class InterviewRole {
  final String roleId;
  final String roleName;

  const InterviewRole({required this.roleId, required this.roleName});
}

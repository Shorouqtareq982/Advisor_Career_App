// ─── Session Types ────────────────────────────────────────────────────────────

enum InterviewSessionType { behavioral, technical }

// ─── Interview Question Entity ────────────────────────────────────────────────

class InterviewQuestionEntity {
  final String questionId;
  final String questionText;

  const InterviewQuestionEntity({
    required this.questionId,
    required this.questionText,
  });
}

// ─── Interview Session Entity ─────────────────────────────────────────────────

class InterviewSessionEntity {
  final String sessionId;
  final String sasToken;
  final String blobUrl;
  final DateTime sasExpiresAt;
  final List<InterviewQuestionEntity> questions;
  final InterviewSessionType sessionType;

  const InterviewSessionEntity({
    required this.sessionId,
    required this.sasToken,
    required this.blobUrl,
    required this.sasExpiresAt,
    required this.questions,
    required this.sessionType,
  });
}

// ─── Interview Feedback Summary Entity ───────────────────────────────────────

class InterviewFeedbackSummary {
  final String sessionId;
  final String roleName;
  final InterviewSessionType sessionType;
  final DateTime createdAt;
  final int? score;
  final String recommendation;
  final String? languagePreferred;

  const InterviewFeedbackSummary({
    required this.sessionId,
    required this.roleName,
    required this.sessionType,
    required this.createdAt,
    this.score,
    this.recommendation = '',
    this.languagePreferred,
  });
}

// ─── Interview Feedback Detail Entity ────────────────────────────────────────

class InterviewFeedbackDetailEntity {
  final String sessionId;
  final String roleName;
  final InterviewSessionType sessionType;
  final DateTime createdAt;
  final int? score;
  final String recommendation;
  final List<String> strongPoints;
  final List<String> areasForImprovement;
  final String suggestions;
  final String? behavioralReport;
  final String? technicalReport;
  final String? languagePreferred;

  const InterviewFeedbackDetailEntity({
    required this.sessionId,
    required this.roleName,
    required this.sessionType,
    required this.createdAt,
    this.score,
    this.recommendation = '',
    required this.strongPoints,
    required this.areasForImprovement,
    required this.suggestions,
    this.behavioralReport,
    this.technicalReport,
    this.languagePreferred,
  });
}

// ─── Available Roles ──────────────────────────────────────────────────────────

class InterviewRole {
  final String roleId;
  final String roleName;

  const InterviewRole({required this.roleId, required this.roleName});
}

// ─── Report Parser ────────────────────────────────────────────────────────────

class ReportParser {
  static List<String> extractStrengths(String report) {
    return _extractSection(
      report,
      englishHeaders: ['**Strengths**', '## Strengths', '# Strengths'],
      arabicHeaders: ['**نقاط القوة**', '## نقاط القوة'],
    );
  }

  /// يستخرج نقاط الضعف - يفهم English و Arabic
  static List<String> extractWeaknesses(String report) {
    return _extractSection(
      report,
      englishHeaders: ['**Weaknesses**', '## Weaknesses', '# Weaknesses'],
      arabicHeaders: ['**نقاط الضعف**', '## نقاط الضعف'],
    );
  }

  static String extractSuggestions(String report) {
    final items = _extractSection(
      report,
      englishHeaders: ['**Suggestions**', '## Suggestions', '# Suggestions'],
      arabicHeaders: [
        '**التوصيات**',
        '## التوصيات',
        '**اقتراحات**',
        '## اقتراحات'
      ],
    );
    return items.join('\n');
  }

  static List<String> _extractSection(
    String report, {
    required List<String> englishHeaders,
    required List<String> arabicHeaders,
  }) {
    if (report.trim().isEmpty) return [];

    final allHeaders = [...englishHeaders, ...arabicHeaders];
    final lines = report.split('\n');
    final items = <String>[];
    bool inSection = false;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final trimmedClean =
          trimmed.replaceAll('**', '').replaceAll('#', '').trim();

      final isTargetHeader = allHeaders.any((h) {
        final hClean = h.replaceAll('**', '').replaceAll('#', '').trim();
        return trimmedClean == hClean;
      });

      if (isTargetHeader) {
        inSection = true;
        continue;
      }

      if (inSection) {
        if (trimmed.startsWith('- ') ||
            trimmed.startsWith('• ') ||
            trimmed.startsWith('* ')) {
          final content = trimmed.substring(2).trim();
          if (content.isNotEmpty) items.add(content);
          continue;
        }

        final isOtherHeader = (trimmed.startsWith('**') &&
                trimmed.endsWith('**') &&
                trimmed.length > 4) ||
            trimmed.startsWith('#');
        if (isOtherHeader) break;
      }
    }

    return items;
  }
}

// ─── Incomplete Session Entity ────────────────────────────────────────────────

class IncompleteSessionEntity {
  final String sessionId;
  final String roleName;
  final InterviewSessionType sessionType;
  final String blobUrl;
  final String sasToken;
  final DateTime savedAt;
  final int lastQuestionIndex;
  final List<InterviewQuestionEntity> questions;
  final String? recordingPath;
  final String? languagePreferred;

  const IncompleteSessionEntity({
    required this.sessionId,
    required this.roleName,
    required this.sessionType,
    required this.blobUrl,
    required this.sasToken,
    required this.savedAt,
    required this.lastQuestionIndex,
    required this.questions,
    this.recordingPath,
    this.languagePreferred,
  });
}

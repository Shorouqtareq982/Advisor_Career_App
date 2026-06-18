// ── Single matched job ─────────────────────────────────────────────────────

class MatchedJobEntity {
  final int rank;
  final String jobTitle;
  final String company;
  final String location;
  final String workMode;
  final String jobType;
  final String link;
  final String descriptionPreview;
  final double matchScore;
  final String explanation;

  // local state
  final bool isSaved;
  final String? savedJobId; // ID من الداتا بيز لو اتحفظ

  const MatchedJobEntity({
    required this.rank,
    required this.jobTitle,
    required this.company,
    required this.location,
    required this.workMode,
    required this.jobType,
    required this.link,
    required this.descriptionPreview,
    required this.matchScore,
    required this.explanation,
    this.isSaved = false,
    this.savedJobId,
  });

  factory MatchedJobEntity.fromJson(Map<String, dynamic> json) {
    return MatchedJobEntity(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      jobTitle: json['job_title']?.toString() ?? '',
      company: json['company']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      workMode: json['work_mode']?.toString() ?? '',
      jobType: json['job_type']?.toString() ?? '',
      link: json['link']?.toString() ?? '',
      descriptionPreview: json['description_preview']?.toString() ?? '',
      matchScore: (json['match_score'] as num?)?.toDouble() ?? 0.0,
      explanation: json['explanation']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJobData() => {
        'rank': rank,
        'job_title': jobTitle,
        'company': company,
        'location': location,
        'work_mode': workMode,
        'job_type': jobType,
        'link': link,
        'description_preview': descriptionPreview,
        'match_score': matchScore,
        'explanation': explanation,
      };

  MatchedJobEntity copyWith({
    bool? isSaved,
    String? savedJobId,
    bool clearSavedId = false,
  }) {
    return MatchedJobEntity(
      rank: rank,
      jobTitle: jobTitle,
      company: company,
      location: location,
      workMode: workMode,
      jobType: jobType,
      link: link,
      descriptionPreview: descriptionPreview,
      matchScore: matchScore,
      explanation: explanation,
      isSaved: isSaved ?? this.isSaved,
      savedJobId: clearSavedId ? null : (savedJobId ?? this.savedJobId),
    );
  }
}

// ── Full match result from API ─────────────────────────────────────────────

class MatchResultEntity {
  final bool success;
  final List<MatchedJobEntity> matches;
  final String? message;
  final String? error;

  const MatchResultEntity({
    required this.success,
    required this.matches,
    this.message,
    this.error,
  });

  factory MatchResultEntity.fromJson(Map<String, dynamic> json) {
    final matchesList = json['matches'] as List<dynamic>? ?? [];
    return MatchResultEntity(
      success: json['success'] as bool? ?? false,
      matches: matchesList
          .map((e) => MatchedJobEntity.fromJson(e as Map<String, dynamic>))
          .toList(),
      message: json['message']?.toString(),
      error: json['error']?.toString(),
    );
  }
}

// ── Saved job from DB ──────────────────────────────────────────────────────

class SavedJobEntity {
  final String id;
  final String userId;
  final Map<String, dynamic> jobData;
  final DateTime savedAt;

  const SavedJobEntity({
    required this.id,
    required this.userId,
    required this.jobData,
    required this.savedAt,
  });

  factory SavedJobEntity.fromJson(Map<String, dynamic> json) {
    return SavedJobEntity(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      jobData: json['job_data'] as Map<String, dynamic>? ?? {},
      savedAt: DateTime.tryParse(json['saved_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  MatchedJobEntity toMatchedJob() {
    return MatchedJobEntity.fromJson(jobData).copyWith(
      isSaved: true,
      savedJobId: id,
    );
  }
}

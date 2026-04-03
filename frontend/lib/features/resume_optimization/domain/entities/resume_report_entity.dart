class ResumeReportEntity {
  final String reportId;
  final String cvName;
  final int atsScore;
  final int contentQualityScore;
  final int? jobMatchScore;
  final DateTime createdAt;
  final SectionAnalysisEntity sectionAnalysis;
  final JobAlignmentEntity? jobAlignment;
  final IndustryKeywordEntity industryKeyword;
  final List<String> atsIssues;
  final List<String> improvementTips;

  const ResumeReportEntity({
    required this.reportId,
    required this.cvName,
    required this.atsScore,
    required this.contentQualityScore,
    this.jobMatchScore,
    required this.createdAt,
    required this.sectionAnalysis,
    this.jobAlignment,
    required this.industryKeyword,
    required this.atsIssues,
    required this.improvementTips,
  });

  ResumeReportEntity copyWith({String? cvName}) {
    return ResumeReportEntity(
      reportId: reportId,
      cvName: cvName ?? this.cvName,
      atsScore: atsScore,
      contentQualityScore: contentQualityScore,
      jobMatchScore: jobMatchScore,
      createdAt: createdAt,
      sectionAnalysis: sectionAnalysis,
      jobAlignment: jobAlignment,
      industryKeyword: industryKeyword,
      atsIssues: atsIssues,
      improvementTips: improvementTips,
    );
  }

  Map<String, dynamic> toJson() => {
        'reportId': reportId,
        'cvName': cvName,
        'atsScore': atsScore,
        'contentQualityScore': contentQualityScore,
        'jobMatchScore': jobMatchScore,
        'createdAt': createdAt.toIso8601String(),
        'sectionAnalysis': sectionAnalysis.toJson(),
        'jobAlignment': jobAlignment?.toJson(),
        'industryKeyword': industryKeyword.toJson(),
        'atsIssues': atsIssues,
        'improvementTips': improvementTips,
      };

  factory ResumeReportEntity.fromJson(Map<String, dynamic> j) =>
      ResumeReportEntity(
        reportId: j['reportId'] as String,
        cvName: j['cvName'] as String,
        atsScore: j['atsScore'] as int,
        contentQualityScore: j['contentQualityScore'] as int,
        jobMatchScore: j['jobMatchScore'] as int?,
        createdAt: DateTime.parse(j['createdAt'] as String),
        sectionAnalysis: SectionAnalysisEntity.fromJson(j['sectionAnalysis']),
        jobAlignment: j['jobAlignment'] != null
            ? JobAlignmentEntity.fromJson(j['jobAlignment'])
            : null,
        industryKeyword: IndustryKeywordEntity.fromJson(j['industryKeyword']),
        atsIssues: List<String>.from(j['atsIssues']),
        improvementTips: List<String>.from(j['improvementTips']),
      );
}

class PassNotesEntity {
  final bool pass;
  final String notes;

  const PassNotesEntity({required this.pass, required this.notes});

  Map<String, dynamic> toJson() => {'pass': pass, 'notes': notes};

  factory PassNotesEntity.fromJson(Map<String, dynamic> j) =>
      PassNotesEntity(pass: j['pass'] as bool, notes: j['notes'] as String);
}

class SectionAnalysisEntity {
  final int overallSectionScore;
  final PassNotesEntity contactInfo;
  final PassNotesEntity workExperience;
  final PassNotesEntity education;
  final PassNotesEntity skills;
  final PassNotesEntity additionalSections;

  const SectionAnalysisEntity({
    required this.overallSectionScore,
    required this.contactInfo,
    required this.workExperience,
    required this.education,
    required this.skills,
    required this.additionalSections,
  });

  Map<String, dynamic> toJson() => {
        'overallSectionScore': overallSectionScore,
        'contactInfo': contactInfo.toJson(),
        'workExperience': workExperience.toJson(),
        'education': education.toJson(),
        'skills': skills.toJson(),
        'additionalSections': additionalSections.toJson(),
      };

  factory SectionAnalysisEntity.fromJson(Map<String, dynamic> j) =>
      SectionAnalysisEntity(
        overallSectionScore: j['overallSectionScore'] as int,
        contactInfo: PassNotesEntity.fromJson(j['contactInfo']),
        workExperience: PassNotesEntity.fromJson(j['workExperience']),
        education: PassNotesEntity.fromJson(j['education']),
        skills: PassNotesEntity.fromJson(j['skills']),
        additionalSections: PassNotesEntity.fromJson(j['additionalSections']),
      );
}

class JobAlignmentEntity {
  final int matchScore;
  final List<String> matchedSkills;
  final List<String> missingSkills;
  final List<String> matchedExperience;
  final List<String> missingExperience;
  final List<String> matchedKeywords;
  final List<String> missingKeywords;

  const JobAlignmentEntity({
    required this.matchScore,
    required this.matchedSkills,
    required this.missingSkills,
    required this.matchedExperience,
    required this.missingExperience,
    required this.matchedKeywords,
    required this.missingKeywords,
  });

  Map<String, dynamic> toJson() => {
        'matchScore': matchScore,
        'matchedSkills': matchedSkills,
        'missingSkills': missingSkills,
        'matchedExperience': matchedExperience,
        'missingExperience': missingExperience,
        'matchedKeywords': matchedKeywords,
        'missingKeywords': missingKeywords,
      };

  factory JobAlignmentEntity.fromJson(Map<String, dynamic> j) =>
      JobAlignmentEntity(
        matchScore: j['matchScore'] as int,
        matchedSkills: List<String>.from(j['matchedSkills']),
        missingSkills: List<String>.from(j['missingSkills']),
        matchedExperience: List<String>.from(j['matchedExperience']),
        missingExperience: List<String>.from(j['missingExperience']),
        matchedKeywords: List<String>.from(j['matchedKeywords']),
        missingKeywords: List<String>.from(j['missingKeywords']),
      );
}

class IndustryKeywordEntity {
  final List<String> recommendedKeywords;
  final List<String> suggestions;

  const IndustryKeywordEntity({
    required this.recommendedKeywords,
    required this.suggestions,
  });

  Map<String, dynamic> toJson() => {
        'recommendedKeywords': recommendedKeywords,
        'suggestions': suggestions,
      };

  factory IndustryKeywordEntity.fromJson(Map<String, dynamic> j) =>
      IndustryKeywordEntity(
        recommendedKeywords: List<String>.from(j['recommendedKeywords']),
        suggestions: List<String>.from(j['suggestions']),
      );
}

// Summary model used in the list screen
class ResumeReportSummary {
  final String reportId;
  final String cvName;
  final int atsScore;
  final int contentQualityScore;
  final int? jobMatchScore;
  final DateTime createdAt;

  const ResumeReportSummary({
    required this.reportId,
    required this.cvName,
    required this.atsScore,
    required this.contentQualityScore,
    this.jobMatchScore,
    required this.createdAt,
  });
}

extension ResumeReportSummaryX on ResumeReportSummary {
  ResumeReportSummary copyWith({
    String? reportId,
    String? cvName,
    int? atsScore,
    int? contentQualityScore,
    int? jobMatchScore,
    DateTime? createdAt,
  }) {
    return ResumeReportSummary(
      reportId: reportId ?? this.reportId,
      cvName: cvName ?? this.cvName,
      atsScore: atsScore ?? this.atsScore,
      contentQualityScore: contentQualityScore ?? this.contentQualityScore,
      jobMatchScore: jobMatchScore ?? this.jobMatchScore,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

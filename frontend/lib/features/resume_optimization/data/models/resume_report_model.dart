import '../../domain/entities/resume_report_entity.dart';

class PassNotesModel {
  final bool pass;
  final String notes;

  const PassNotesModel({required this.pass, required this.notes});

  factory PassNotesModel.fromJson(Map<String, dynamic> json) => PassNotesModel(
        pass: json['Pass'] as bool? ?? false,
        notes: json['Notes'] as String? ?? '',
      );

  PassNotesEntity toEntity() => PassNotesEntity(pass: pass, notes: notes);
}

class SectionAnalysisModel {
  final int overallSectionScore;
  final PassNotesModel contactInfo;
  final PassNotesModel workExperience;
  final PassNotesModel education;
  final PassNotesModel skills;
  final PassNotesModel additionalSections;

  const SectionAnalysisModel({
    required this.overallSectionScore,
    required this.contactInfo,
    required this.workExperience,
    required this.education,
    required this.skills,
    required this.additionalSections,
  });

  factory SectionAnalysisModel.fromJson(Map<String, dynamic> json) =>
      SectionAnalysisModel(
        overallSectionScore: json['Overall_Section_Score'] as int? ?? 0,
        contactInfo: PassNotesModel.fromJson(
            json['Contact_Info'] as Map<String, dynamic>? ?? {}),
        workExperience: PassNotesModel.fromJson(
            json['Work_Experience'] as Map<String, dynamic>? ?? {}),
        education: PassNotesModel.fromJson(
            json['Education'] as Map<String, dynamic>? ?? {}),
        skills: PassNotesModel.fromJson(
            json['Skills'] as Map<String, dynamic>? ?? {}),
        additionalSections: PassNotesModel.fromJson(
            json['Additional_Sections'] as Map<String, dynamic>? ?? {}),
      );

  SectionAnalysisEntity toEntity() => SectionAnalysisEntity(
        overallSectionScore: overallSectionScore,
        contactInfo: contactInfo.toEntity(),
        workExperience: workExperience.toEntity(),
        education: education.toEntity(),
        skills: skills.toEntity(),
        additionalSections: additionalSections.toEntity(),
      );
}

class JobAlignmentModel {
  final int matchScore;
  final List<String> matchedSkills;
  final List<String> missingSkills;
  final List<String> matchedExperience;
  final List<String> missingExperience;
  final List<String> matchedKeywords;
  final List<String> missingKeywords;

  const JobAlignmentModel({
    required this.matchScore,
    required this.matchedSkills,
    required this.missingSkills,
    required this.matchedExperience,
    required this.missingExperience,
    required this.matchedKeywords,
    required this.missingKeywords,
  });

  factory JobAlignmentModel.fromJson(Map<String, dynamic> json) {
    final skillsAnalysis =
        json['Skills_Analysis'] as Map<String, dynamic>? ?? {};
    final expAlignment =
        json['Experience_Alignment'] as Map<String, dynamic>? ?? {};
    final keywordAnalysis =
        json['Keyword_Analysis'] as Map<String, dynamic>? ?? {};

    return JobAlignmentModel(
      matchScore: json['Match_Score'] as int? ?? 0,
      matchedSkills: _toList(skillsAnalysis['Matched_Skills']),
      missingSkills: _toList(skillsAnalysis['Missing_Skills']),
      matchedExperience: _toList(expAlignment['Matched_Experience']),
      missingExperience: _toList(expAlignment['Missing_Experience']),
      matchedKeywords: _toList(keywordAnalysis['Matched_Keywords']),
      missingKeywords: _toList(keywordAnalysis['Missing_Keywords']),
    );
  }

  JobAlignmentEntity toEntity() => JobAlignmentEntity(
        matchScore: matchScore,
        matchedSkills: matchedSkills,
        missingSkills: missingSkills,
        matchedExperience: matchedExperience,
        missingExperience: missingExperience,
        matchedKeywords: matchedKeywords,
        missingKeywords: missingKeywords,
      );
}

class IndustryKeywordModel {
  final List<String> recommendedKeywords;
  final List<String> suggestions;

  const IndustryKeywordModel({
    required this.recommendedKeywords,
    required this.suggestions,
  });

  factory IndustryKeywordModel.fromJson(Map<String, dynamic> json) =>
      IndustryKeywordModel(
        recommendedKeywords: _toList(json['Recommended_Keywords']),
        suggestions: _toList(json['Suggestions']),
      );

  IndustryKeywordEntity toEntity() => IndustryKeywordEntity(
        recommendedKeywords: recommendedKeywords,
        suggestions: suggestions,
      );
}

List<String> _toList(dynamic value) {
  if (value == null) return [];
  if (value is List) return value.map((e) => e.toString()).toList();
  return [];
}

String _extractDisplayName(Map<String, dynamic> json) {
  // 1. Job title from job_postings (only if JD was provided)
  final jobPostings = json['job_postings'] as Map<String, dynamic>?;
  if (jobPostings != null) {
    final jobTitle = jobPostings['job_title'] as String?;
    if (jobTitle != null && jobTitle.trim().isNotEmpty) {
      return jobTitle.trim();
    }
  }

  final cvObj = json['cv'] as Map<String, dynamic>?;
  if (cvObj != null) {
    // 2. Original filename
    final filename = cvObj['original_filename'] as String?;
    if (filename != null && filename.trim().isNotEmpty) {
      final nameOnly = filename.contains('.')
          ? filename.substring(0, filename.lastIndexOf('.'))
          : filename;
      final cleaned =
          nameOnly.startsWith('cv_') ? nameOnly.substring(3) : nameOnly;
      final display = cleaned.replaceAll('_', ' ').replaceAll('-', ' ').trim();
      if (display.isNotEmpty) return _toTitleCase(display);
    }
  }

  return 'Resume';
}

String _toTitleCase(String input) {
  return input.split(' ').map((word) {
    if (word.isEmpty) return word;
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }).join(' ');
}

/// Parses creation date from generated_at field
DateTime _parseDate(Map<String, dynamic> json) {
  final raw = json['generated_at'] as String?;
  if (raw != null && raw.isNotEmpty) {
    return DateTime.tryParse(raw)?.toLocal() ?? DateTime.now();
  }
  return DateTime.now();
}

// ─── Full report model — GET /report/{report_id} ──────────────────────────────

class ResumeReportModel {
  final String reportId;
  final String cvName;
  final int atsScore;
  final int contentQualityScore;
  final SectionAnalysisModel sectionAnalysis;
  final JobAlignmentModel? jobAlignment;
  final IndustryKeywordModel industryKeyword;
  final List<String> atsIssues;
  final List<String> improvementTips;
  final DateTime createdAt;

  const ResumeReportModel({
    required this.reportId,
    required this.cvName,
    required this.atsScore,
    required this.contentQualityScore,
    required this.sectionAnalysis,
    this.jobAlignment,
    required this.industryKeyword,
    required this.atsIssues,
    required this.improvementTips,
    required this.createdAt,
  });

  factory ResumeReportModel.fromJson(Map<String, dynamic> json) {
    final analysis = json['analysis'] as Map<String, dynamic>? ?? json;
    final atsAnalysis =
        analysis['ATS_Readability_Analysis'] as Map<String, dynamic>? ?? {};
    final contentAnalysis =
        analysis['Content_Quality_Analysis'] as Map<String, dynamic>? ?? {};
    final jobAlignmentJson = analysis['Job_Alignment'] as Map<String, dynamic>?;

    return ResumeReportModel(
      reportId: json['report_id'] as String? ?? '',
      cvName: _extractDisplayName(json),
      atsScore: atsAnalysis['Score'] as int? ?? 0,
      contentQualityScore: contentAnalysis['Score'] as int? ?? 0,
      sectionAnalysis: SectionAnalysisModel.fromJson(
        analysis['Section_Analysis'] as Map<String, dynamic>? ?? {},
      ),
      jobAlignment: jobAlignmentJson != null
          ? JobAlignmentModel.fromJson(jobAlignmentJson)
          : null,
      industryKeyword: IndustryKeywordModel.fromJson(
        analysis['Industry_Keyword_Optimization'] as Map<String, dynamic>? ??
            {},
      ),
      atsIssues: _toList(analysis['ATS_Issues']),
      improvementTips: _toList(analysis['Improvement_Tips']),
      createdAt: _parseDate(json),
    );
  }

  ResumeReportEntity toEntity() => ResumeReportEntity(
        reportId: reportId,
        cvName: cvName,
        atsScore: atsScore,
        contentQualityScore: contentQualityScore,
        jobMatchScore: jobAlignment?.matchScore,
        createdAt: createdAt,
        sectionAnalysis: sectionAnalysis.toEntity(),
        jobAlignment: jobAlignment?.toEntity(),
        industryKeyword: industryKeyword.toEntity(),
        atsIssues: atsIssues,
        improvementTips: improvementTips,
      );
}

// ─── Summary model — GET /reports ────────────────────────────────────────────

class ResumeReportSummaryModel {
  final String reportId;
  final String cvName;
  final int atsScore;
  final int contentQualityScore;
  final int? jobMatchScore;
  final DateTime createdAt;

  const ResumeReportSummaryModel({
    required this.reportId,
    required this.cvName,
    required this.atsScore,
    required this.contentQualityScore,
    this.jobMatchScore,
    required this.createdAt,
  });

  factory ResumeReportSummaryModel.fromJson(Map<String, dynamic> json) {
    final analysis = json['analysis'] as Map<String, dynamic>? ?? {};
    final atsAnalysis =
        analysis['ATS_Readability_Analysis'] as Map<String, dynamic>? ?? {};
    final contentAnalysis =
        analysis['Content_Quality_Analysis'] as Map<String, dynamic>? ?? {};
    final sectionAnalysis =
        analysis['Section_Analysis'] as Map<String, dynamic>? ?? {};
    final jobAlignment = analysis['Job_Alignment'] as Map<String, dynamic>?;

    return ResumeReportSummaryModel(
      reportId: json['report_id'] as String? ?? '',
      cvName: _extractDisplayName(json),
      atsScore: atsAnalysis['Score'] as int? ?? 0,
      contentQualityScore: contentAnalysis['Score'] as int? ?? 0,
      jobMatchScore: jobAlignment?['Match_Score'] as int?,
      createdAt: _parseDate(json),
    );
  }

  ResumeReportSummary toEntity() => ResumeReportSummary(
        reportId: reportId,
        cvName: cvName,
        atsScore: atsScore,
        contentQualityScore: contentQualityScore,
        jobMatchScore: jobMatchScore,
        createdAt: createdAt,
      );
}

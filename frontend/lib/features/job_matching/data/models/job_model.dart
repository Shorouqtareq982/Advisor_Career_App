import '../../domain/entities/job_entity.dart';

class JobModel {
  final String id;
  final String title;
  final String company;
  final String location;
  final String workType;
  final String workLocation;
  final String? jobUrl;
  final String? jobDescription;
  final List<String> requiredSkills;
  final DateTime postedAt;
  final bool isSaved;
  final bool isNew;
  final int? rank;
  final double? matchScore;
  final String? explanation;

  const JobModel({
    required this.id,
    required this.title,
    required this.company,
    required this.location,
    required this.workType,
    required this.workLocation,
    this.jobUrl,
    this.jobDescription,
    this.requiredSkills = const [],
    required this.postedAt,
    this.isSaved = false,
    this.isNew = true,
    this.rank,
    this.matchScore,
    this.explanation,
  });

  /// Parse one item from /match-jobs → matches list
  /// Backend shape: { rank, job_title, company, location, work_mode,
  ///                  job_type, link, description_preview,
  ///                  match_score, explanation }
  factory JobModel.fromMatchJson(Map<String, dynamic> json) {
    final rankVal = json['rank'] as int? ?? 0;
    return JobModel(
      id: 'match_$rankVal',
      title: json['job_title'] as String? ?? '',
      company: json['company'] as String? ?? '',
      location: json['location'] as String? ?? '',
      workType: json['job_type'] as String? ?? '',
      workLocation: json['work_mode'] as String? ?? '',
      jobUrl: json['link'] as String?,
      jobDescription: json['description_preview'] as String?,
      requiredSkills: const [],
      postedAt: DateTime.now(),
      isSaved: false,
      isNew: true,
      rank: rankVal,
      matchScore: (json['match_score'] as num?)?.toDouble(),
      explanation: json['explanation'] as String?,
    );
  }

  /// Parse a row from Supabase saved_jobs table
  /// Row shape: { id, user_id, job_data: { ... }, saved_at }
  factory JobModel.fromSavedJson(Map<String, dynamic> json) {
    final jobData = json['job_data'] as Map<String, dynamic>? ?? {};
    final rankVal = jobData['rank'] as int? ?? 0;
    return JobModel(
      id: json['id'] as String? ?? 'saved_$rankVal',
      title: jobData['job_title'] as String? ?? '',
      company: jobData['company'] as String? ?? '',
      location: jobData['location'] as String? ?? '',
      workType: jobData['job_type'] as String? ?? '',
      workLocation: jobData['work_mode'] as String? ?? '',
      jobUrl: jobData['link'] as String?,
      jobDescription: jobData['description_preview'] as String?,
      requiredSkills: const [],
      postedAt: json['saved_at'] != null
          ? DateTime.tryParse(json['saved_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      isSaved: true,
      isNew: false,
      rank: rankVal,
      matchScore: (jobData['match_score'] as num?)?.toDouble(),
      explanation: jobData['explanation'] as String?,
    );
  }

  /// Parse من job_match_results table في Supabase
  factory JobModel.fromResultJson(Map<String, dynamic> json, String rowId) {
    final rankVal = json['rank'] as int? ?? 0;
    return JobModel(
      id: rowId.isNotEmpty ? rowId : 'result_$rankVal',
      title: json['job_title'] as String? ?? '',
      company: json['company'] as String? ?? '',
      location: json['location'] as String? ?? '',
      workType: json['job_type'] as String? ?? '',
      workLocation: json['work_mode'] as String? ?? '',
      jobUrl: json['link'] as String?,
      jobDescription: json['description_preview'] as String?,
      postedAt: DateTime.now(),
      rank: rankVal,
      matchScore: (json['match_score'] as num?)?.toDouble(),
      explanation: json['explanation'] as String?,
    );
  }

  /// Build job_data payload for POST /job-matching/
  Map<String, dynamic> toSavePayload() => {
        'rank': rank,
        'job_title': title,
        'company': company,
        'location': location,
        'job_type': workType,
        'work_mode': workLocation,
        'link': jobUrl,
        'description_preview': jobDescription,
        'match_score': matchScore,
        'explanation': explanation,
      };

  JobEntity toEntity() => JobEntity(
        id: id,
        title: title,
        company: company,
        location: location,
        workType: workType,
        workLocation: workLocation,
        jobUrl: jobUrl,
        jobDescription: jobDescription,
        requiredSkills: requiredSkills,
        postedAt: postedAt,
        isSaved: isSaved,
        isNew: isNew,
        rank: rank,
        matchScore: matchScore,
        explanation: explanation,
      );
}

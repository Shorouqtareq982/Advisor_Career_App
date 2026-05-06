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
  final String postedAt; // ISO string from API
  final bool isSaved;
  final bool isNew;
  final int? userRating;

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
    this.userRating,
  });

  factory JobModel.fromJson(Map<String, dynamic> json) {
    return JobModel(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      company: json['company'] as String? ?? '',
      location: json['location'] as String? ?? '',
      workType: json['work_type'] as String? ?? '',
      workLocation: json['work_location'] as String? ?? '',
      jobUrl: json['job_url'] as String?,
      jobDescription: json['job_description'] as String?,
      requiredSkills: (json['required_skills'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      postedAt:
          json['posted_at'] as String? ?? DateTime.now().toIso8601String(),
      isSaved: json['is_saved'] as bool? ?? false,
      isNew: json['is_new'] as bool? ?? true,
      userRating: json['user_rating'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'company': company,
        'location': location,
        'work_type': workType,
        'work_location': workLocation,
        'job_url': jobUrl,
        'job_description': jobDescription,
        'required_skills': requiredSkills,
        'posted_at': postedAt,
        'is_saved': isSaved,
        'is_new': isNew,
        'user_rating': userRating,
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
        postedAt: DateTime.tryParse(postedAt) ?? DateTime.now(),
        isSaved: isSaved,
        isNew: isNew,
        userRating: userRating,
      );
}

class JobEntity {
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

  const JobEntity({
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

  JobEntity copyWith({
    String? id,
    String? title,
    String? company,
    String? location,
    String? workType,
    String? workLocation,
    String? jobUrl,
    String? jobDescription,
    List<String>? requiredSkills,
    DateTime? postedAt,
    bool? isSaved,
    bool? isNew,
    int? rank,
    double? matchScore,
    String? explanation,
  }) {
    return JobEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      company: company ?? this.company,
      location: location ?? this.location,
      workType: workType ?? this.workType,
      workLocation: workLocation ?? this.workLocation,
      jobUrl: jobUrl ?? this.jobUrl,
      jobDescription: jobDescription ?? this.jobDescription,
      requiredSkills: requiredSkills ?? this.requiredSkills,
      postedAt: postedAt ?? this.postedAt,
      isSaved: isSaved ?? this.isSaved,
      isNew: isNew ?? this.isNew,
      rank: rank ?? this.rank,
      matchScore: matchScore ?? this.matchScore,
      explanation: explanation ?? this.explanation,
    );
  }
}

class PortfolioTemplateModel {
  final int id;
  final String name;
  final String description;
  final String thumbnailUrl;
  final String filePath;
  final String? content;

  const PortfolioTemplateModel({
    required this.id,
    required this.name,
    required this.description,
    required this.thumbnailUrl,
    required this.filePath,
    this.content,
  });

  factory PortfolioTemplateModel.fromJson(Map<String, dynamic> json) {
    return PortfolioTemplateModel(
      id: int.tryParse((json['id'] ?? 0).toString()) ?? 0,
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      thumbnailUrl: (json['thumbnail_url'] ?? '').toString(),
      filePath: (json['file_path'] ?? '').toString(),
      content: json['content']?.toString(),
    );
  }
}

class PortfolioImageUploadResponseModel {
  final String fileUrl;
  final String publicId;

  const PortfolioImageUploadResponseModel({
    required this.fileUrl,
    required this.publicId,
  });

  factory PortfolioImageUploadResponseModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return PortfolioImageUploadResponseModel(
      fileUrl: (json['file_url'] ?? '').toString(),
      publicId: (json['public_id'] ?? '').toString(),
    );
  }
}

class PortfolioExperienceModel {
  final String jobTitle;
  final String company;
  final String location;
  final String period;
  final String description;

  const PortfolioExperienceModel({
    this.jobTitle = '',
    this.company = '',
    this.location = '',
    this.period = '',
    this.description = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'job_title': jobTitle,
      'company': company,
      'location': location,
      'period': period,
      'description': description,
    };
  }

  factory PortfolioExperienceModel.fromJson(Map<String, dynamic> json) {
    return PortfolioExperienceModel(
      jobTitle: (json['job_title'] ?? '').toString(),
      company: (json['company'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      period: (json['period'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
    );
  }
}

class PortfolioEducationModel {
  final String degree;
  final String field;
  final String institution;
  final String location;
  final String period;
  final String description;

  const PortfolioEducationModel({
    this.degree = '',
    this.field = '',
    this.institution = '',
    this.location = '',
    this.period = '',
    this.description = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'degree': degree,
      'field': field,
      'institution': institution,
      'location': location,
      'period': period,
      'description': description,
    };
  }

  factory PortfolioEducationModel.fromJson(Map<String, dynamic> json) {
    return PortfolioEducationModel(
      degree: (json['degree'] ?? '').toString(),
      field: (json['field'] ?? '').toString(),
      institution: (json['institution'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      period: (json['period'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
    );
  }
}

class PortfolioProjectModel {
  final String name;
  final String description;
  final String technologies;
  final String link;

  const PortfolioProjectModel({
    this.name = '',
    this.description = '',
    this.technologies = '',
    this.link = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'technologies': technologies,
      'link': link,
    };
  }

  factory PortfolioProjectModel.fromJson(Map<String, dynamic> json) {
    return PortfolioProjectModel(
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      technologies: (json['technologies'] ?? '').toString(),
      link: (json['link'] ?? '').toString(),
    );
  }
}

class AIPortfolioRequestModel {
  final String name;
  final String title;
  final String about;
  final String email;
  final String phone;
  final String location;
  final String github;
  final String linkedin;
  final String twitter;
  final int selectedTemplate;
  final List<String> skills;
  final List<String> languages;
  final List<PortfolioExperienceModel> experiences;
  final List<PortfolioEducationModel> education;
  final List<PortfolioProjectModel> projects;
  final String? profileImageUrl;

  const AIPortfolioRequestModel({
    this.name = '',
    this.title = '',
    this.about = '',
    this.email = '',
    this.phone = '',
    this.location = '',
    this.github = '',
    this.linkedin = '',
    this.twitter = '',
    this.selectedTemplate = 1,
    this.skills = const [],
    this.languages = const [],
    this.experiences = const [],
    this.education = const [],
    this.projects = const [],
    this.profileImageUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'title': title,
      'about': about,
      'email': email,
      'phone': phone,
      'location': location,
      'github': github,
      'linkedin': linkedin,
      'twitter': twitter,
      'selected_template': selectedTemplate,
      'skills': skills,
      'languages': languages,
      'experiences': experiences.map((e) => e.toJson()).toList(),
      'education': education.map((e) => e.toJson()).toList(),
      'projects': projects.map((e) => e.toJson()).toList(),
      'profile_image_url': profileImageUrl,
    };
  }

  factory AIPortfolioRequestModel.fromJson(Map<String, dynamic> json) {
    return AIPortfolioRequestModel(
      name: (json['name'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      about: (json['about'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      github: (json['github'] ?? '').toString(),
      linkedin: (json['linkedin'] ?? '').toString(),
      twitter: (json['twitter'] ?? '').toString(),
      selectedTemplate:
          int.tryParse((json['selected_template'] ?? 1).toString()) ?? 1,
      skills: (json['skills'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      languages: (json['languages'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      experiences: (json['experiences'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (item) => PortfolioExperienceModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
      education: (json['education'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (item) => PortfolioEducationModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
      projects: (json['projects'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (item) => PortfolioProjectModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
      profileImageUrl: json['profile_image_url']?.toString(),
    );
  }
}

class AIPortfolioResponseModel {
  final String id;
  final String userId;
  final String title;
  final int templateIndex;
  final AIPortfolioRequestModel data;
  final bool isPublished;
  final String? publicSlug;
  final String? publicUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AIPortfolioResponseModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.templateIndex,
    required this.data,
    required this.isPublished,
    this.publicSlug,
    this.publicUrl,
    this.createdAt,
    this.updatedAt,
  });

  factory AIPortfolioResponseModel.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];

    return AIPortfolioResponseModel(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      templateIndex:
          int.tryParse((json['template_index'] ?? 1).toString()) ?? 1,
      data: rawData is Map
          ? AIPortfolioRequestModel.fromJson(
              Map<String, dynamic>.from(rawData),
            )
          : const AIPortfolioRequestModel(),
      isPublished: json['is_published'] == true,
      publicSlug: json['public_slug']?.toString(),
      publicUrl: json['public_url']?.toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
      updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()),
    );
  }
}

class AIPortfolioSummaryModel {
  final String id;
  final String title;
  final int templateIndex;
  final bool isPublished;
  final String? publicSlug;
  final String? publicUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AIPortfolioSummaryModel({
    required this.id,
    required this.title,
    required this.templateIndex,
    required this.isPublished,
    this.publicSlug,
    this.publicUrl,
    this.createdAt,
    this.updatedAt,
  });

  factory AIPortfolioSummaryModel.fromJson(Map<String, dynamic> json) {
    return AIPortfolioSummaryModel(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      templateIndex:
          int.tryParse((json['template_index'] ?? 0).toString()) ?? 0,
      isPublished: json['is_published'] == true,
      publicSlug: json['public_slug']?.toString(),
      publicUrl: json['public_url']?.toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
      updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()),
    );
  }
}

class LastSavedPortfolioDataModel {
  final AIPortfolioRequestModel? data;

  const LastSavedPortfolioDataModel({
    required this.data,
  });

  factory LastSavedPortfolioDataModel.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];

    return LastSavedPortfolioDataModel(
      data: rawData is Map
          ? AIPortfolioRequestModel.fromJson(
              Map<String, dynamic>.from(rawData),
            )
          : null,
    );
  }
}

class AIPortfolioActionResponseModel {
  final bool success;
  final String message;

  const AIPortfolioActionResponseModel({
    required this.success,
    required this.message,
  });

  factory AIPortfolioActionResponseModel.fromJson(Map<String, dynamic> json) {
    return AIPortfolioActionResponseModel(
      success: json['success'] == true,
      message: (json['message'] ?? '').toString(),
    );
  }
}

class AIPortfolioPdfExportResponseModel {
  final String pdfUrl;

  const AIPortfolioPdfExportResponseModel({
    required this.pdfUrl,
  });

  factory AIPortfolioPdfExportResponseModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return AIPortfolioPdfExportResponseModel(
      pdfUrl: (json['pdf_url'] ?? '').toString(),
    );
  }
}

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/datasources/ai_portfolio_remote_datasource.dart';
import '../../data/models/ai_portfolio_model.dart';
import '../../data/repositories/ai_portfolio_repository_impl.dart';
import '../../domain/entities/ai_portfolio_entity.dart';
import '../../domain/entities/portfolio_skill_entity.dart';
import '../../domain/repositories/ai_portfolio_repository.dart';

enum PortfolioTab { edit, designs, preview, settings }

enum PortfolioTemplateType {
  design1,
  design2,
  design3,
  design4,
}

enum PortfolioSectionKey {
  cover,
  aboutMe,
  professionalExperience,
  projects,
  skills,
  education,
  contact,
}

class ProfessionalExperienceEntryModel {
  final String id;
  final String jobTitle;
  final String companyName;
  final String location;
  final String companyUrl;
  final String? startMonth;
  final String? startYear;
  final String? endMonth;
  final String? endYear;
  final bool currentlyWorkingHere;
  final String description;
  final bool isExpanded;

  const ProfessionalExperienceEntryModel({
    required this.id,
    this.jobTitle = '',
    this.companyName = '',
    this.location = '',
    this.companyUrl = '',
    this.startMonth,
    this.startYear,
    this.endMonth,
    this.endYear,
    this.currentlyWorkingHere = false,
    this.description = '',
    this.isExpanded = true,
  });

  ProfessionalExperienceEntryModel copyWith({
    String? id,
    String? jobTitle,
    String? companyName,
    String? location,
    String? companyUrl,
    String? startMonth,
    String? startYear,
    String? endMonth,
    String? endYear,
    bool? currentlyWorkingHere,
    String? description,
    bool? isExpanded,
    bool clearEndDate = false,
  }) {
    return ProfessionalExperienceEntryModel(
      id: id ?? this.id,
      jobTitle: jobTitle ?? this.jobTitle,
      companyName: companyName ?? this.companyName,
      location: location ?? this.location,
      companyUrl: companyUrl ?? this.companyUrl,
      startMonth: startMonth ?? this.startMonth,
      startYear: startYear ?? this.startYear,
      endMonth: clearEndDate ? null : (endMonth ?? this.endMonth),
      endYear: clearEndDate ? null : (endYear ?? this.endYear),
      currentlyWorkingHere: currentlyWorkingHere ?? this.currentlyWorkingHere,
      description: description ?? this.description,
      isExpanded: isExpanded ?? this.isExpanded,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'jobTitle': jobTitle,
        'companyName': companyName,
        'location': location,
        'companyUrl': companyUrl,
        'startMonth': startMonth,
        'startYear': startYear,
        'endMonth': endMonth,
        'endYear': endYear,
        'currentlyWorkingHere': currentlyWorkingHere,
        'description': description,
      };

  factory ProfessionalExperienceEntryModel.fromJson(Map<String, dynamic> json) {
    return ProfessionalExperienceEntryModel(
      id: (json['id'] ?? DateTime.now().microsecondsSinceEpoch).toString(),
      jobTitle: (json['jobTitle'] ?? json['job_title'] ?? '').toString(),
      companyName: (json['companyName'] ?? json['company'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      companyUrl: (json['companyUrl'] ?? '').toString(),
      startMonth: json['startMonth']?.toString(),
      startYear: json['startYear']?.toString(),
      endMonth: json['endMonth']?.toString(),
      endYear: json['endYear']?.toString(),
      currentlyWorkingHere: json['currentlyWorkingHere'] == true,
      description: (json['description'] ?? '').toString(),
      isExpanded: false,
    );
  }
}

class ProjectLinkEntryModel {
  final String id;
  final String label;
  final String url;
  final bool isExpanded;

  const ProjectLinkEntryModel({
    required this.id,
    this.label = '',
    this.url = '',
    this.isExpanded = true,
  });

  ProjectLinkEntryModel copyWith({
    String? id,
    String? label,
    String? url,
    bool? isExpanded,
  }) {
    return ProjectLinkEntryModel(
      id: id ?? this.id,
      label: label ?? this.label,
      url: url ?? this.url,
      isExpanded: isExpanded ?? this.isExpanded,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'url': url,
      };

  factory ProjectLinkEntryModel.fromJson(Map<String, dynamic> json) {
    return ProjectLinkEntryModel(
      id: (json['id'] ?? DateTime.now().microsecondsSinceEpoch).toString(),
      label: (json['label'] ?? '').toString(),
      url: (json['url'] ?? json['link'] ?? '').toString(),
      isExpanded: false,
    );
  }
}

class ProjectEntryModel {
  final String id;
  final String title;
  final String category;
  final String shortDescription;
  final List<String> tools;
  final List<ProjectLinkEntryModel> links;
  final String keyOutcomes;
  final String? coverImagePath;
  final String? coverImageName;
  final bool isExpanded;

  const ProjectEntryModel({
    required this.id,
    this.title = '',
    this.category = '',
    this.shortDescription = '',
    this.tools = const [],
    this.links = const [],
    this.keyOutcomes = '',
    this.coverImagePath,
    this.coverImageName,
    this.isExpanded = true,
  });

  ProjectEntryModel copyWith({
    String? id,
    String? title,
    String? category,
    String? shortDescription,
    List<String>? tools,
    List<ProjectLinkEntryModel>? links,
    String? keyOutcomes,
    String? coverImagePath,
    String? coverImageName,
    bool? isExpanded,
    bool clearCoverImage = false,
  }) {
    return ProjectEntryModel(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      shortDescription: shortDescription ?? this.shortDescription,
      tools: tools ?? this.tools,
      links: links ?? this.links,
      keyOutcomes: keyOutcomes ?? this.keyOutcomes,
      coverImagePath:
          clearCoverImage ? null : (coverImagePath ?? this.coverImagePath),
      coverImageName:
          clearCoverImage ? null : (coverImageName ?? this.coverImageName),
      isExpanded: isExpanded ?? this.isExpanded,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'shortDescription': shortDescription,
        'tools': tools,
        'links': links.map((e) => e.toJson()).toList(),
        'keyOutcomes': keyOutcomes,
        'coverImagePath': coverImagePath,
        'coverImageName': coverImageName,
      };

  factory ProjectEntryModel.fromJson(Map<String, dynamic> json) {
    final link = (json['link'] ?? '').toString();

    return ProjectEntryModel(
      id: (json['id'] ?? DateTime.now().microsecondsSinceEpoch).toString(),
      title: (json['title'] ?? json['name'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      shortDescription:
          (json['shortDescription'] ?? json['description'] ?? '').toString(),
      tools: json['tools'] is List
          ? (json['tools'] as List<dynamic>).map((e) => e.toString()).toList()
          : (json['technologies'] ?? '')
              .toString()
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
      links: link.trim().isEmpty
          ? const []
          : [
              ProjectLinkEntryModel(
                id: DateTime.now().microsecondsSinceEpoch.toString(),
                label: 'Project',
                url: link,
                isExpanded: false,
              ),
            ],
      keyOutcomes: (json['keyOutcomes'] ?? '').toString(),
      coverImagePath: json['coverImagePath']?.toString(),
      coverImageName: json['coverImageName']?.toString(),
      isExpanded: false,
    );
  }
}

class EducationEntryModel {
  final String id;
  final String institutionName;
  final String degree;
  final String fieldOfStudy;
  final String location;
  final String? startMonth;
  final String? startYear;
  final String? endMonth;
  final String? endYear;
  final bool currentlyStudying;
  final String gpa;
  final List<String> minors;
  final List<String> coursework;
  final String description;
  final bool isExpanded;

  const EducationEntryModel({
    required this.id,
    this.institutionName = '',
    this.degree = '',
    this.fieldOfStudy = '',
    this.location = '',
    this.startMonth,
    this.startYear,
    this.endMonth,
    this.endYear,
    this.currentlyStudying = false,
    this.gpa = '',
    this.minors = const [],
    this.coursework = const [],
    this.description = '',
    this.isExpanded = true,
  });

  EducationEntryModel copyWith({
    String? id,
    String? institutionName,
    String? degree,
    String? fieldOfStudy,
    String? location,
    String? startMonth,
    String? startYear,
    String? endMonth,
    String? endYear,
    bool? currentlyStudying,
    String? gpa,
    List<String>? minors,
    List<String>? coursework,
    String? description,
    bool? isExpanded,
    bool clearEndDate = false,
  }) {
    return EducationEntryModel(
      id: id ?? this.id,
      institutionName: institutionName ?? this.institutionName,
      degree: degree ?? this.degree,
      fieldOfStudy: fieldOfStudy ?? this.fieldOfStudy,
      location: location ?? this.location,
      startMonth: startMonth ?? this.startMonth,
      startYear: startYear ?? this.startYear,
      endMonth: clearEndDate ? null : (endMonth ?? this.endMonth),
      endYear: clearEndDate ? null : (endYear ?? this.endYear),
      currentlyStudying: currentlyStudying ?? this.currentlyStudying,
      gpa: gpa ?? this.gpa,
      minors: minors ?? this.minors,
      coursework: coursework ?? this.coursework,
      description: description ?? this.description,
      isExpanded: isExpanded ?? this.isExpanded,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'institutionName': institutionName,
        'degree': degree,
        'fieldOfStudy': fieldOfStudy,
        'location': location,
        'startMonth': startMonth,
        'startYear': startYear,
        'endMonth': endMonth,
        'endYear': endYear,
        'currentlyStudying': currentlyStudying,
        'gpa': gpa,
        'minors': minors,
        'coursework': coursework,
        'description': description,
      };

  factory EducationEntryModel.fromJson(Map<String, dynamic> json) {
    return EducationEntryModel(
      id: (json['id'] ?? DateTime.now().microsecondsSinceEpoch).toString(),
      institutionName:
          (json['institutionName'] ?? json['institution'] ?? '').toString(),
      degree: (json['degree'] ?? '').toString(),
      fieldOfStudy: (json['fieldOfStudy'] ?? json['field'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      startMonth: json['startMonth']?.toString(),
      startYear: json['startYear']?.toString(),
      endMonth: json['endMonth']?.toString(),
      endYear: json['endYear']?.toString(),
      currentlyStudying: json['currentlyStudying'] == true,
      gpa: (json['gpa'] ?? '').toString(),
      minors: (json['minors'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      coursework: (json['coursework'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      description: (json['description'] ?? '').toString(),
      isExpanded: false,
    );
  }
}

class AboutMeModel {
  final String professionalSummary;
  final int yearsOfExperience;
  final List<String> coreStrengths;
  final List<String> careerFocus;
  final List<String> industriesWorkedIn;

  const AboutMeModel({
    this.professionalSummary = '',
    this.yearsOfExperience = 0,
    this.coreStrengths = const [],
    this.careerFocus = const [],
    this.industriesWorkedIn = const [],
  });

  AboutMeModel copyWith({
    String? professionalSummary,
    int? yearsOfExperience,
    List<String>? coreStrengths,
    List<String>? careerFocus,
    List<String>? industriesWorkedIn,
  }) {
    return AboutMeModel(
      professionalSummary: professionalSummary ?? this.professionalSummary,
      yearsOfExperience: yearsOfExperience ?? this.yearsOfExperience,
      coreStrengths: coreStrengths ?? this.coreStrengths,
      careerFocus: careerFocus ?? this.careerFocus,
      industriesWorkedIn: industriesWorkedIn ?? this.industriesWorkedIn,
    );
  }
}

class PortfolioTemplatePreviewData {
  final String fullName;
  final String professionalTitle;
  final String shortValueStatement;
  final String location;
  final String? profileImagePath;
  final String? coverImagePath;
  final bool showViewMyWork;
  final bool showDownloadCv;
  final bool showContactMe;
  final String aboutSummary;
  final int yearsOfExperience;
  final List<String> coreStrengths;
  final List<String> careerFocus;
  final List<String> industriesWorkedIn;
  final List<PortfolioSkillEntity> skills;
  final List<ProfessionalExperienceEntryModel> professionalExperienceEntries;
  final List<ProjectEntryModel> projectEntries;
  final List<EducationEntryModel> educationEntries;
  final String contactEmail;
  final String contactPhoneCode;
  final String contactPhoneNumber;
  final String contactLocation;
  final List<String> contactLinks;

  const PortfolioTemplatePreviewData({
    required this.fullName,
    required this.professionalTitle,
    required this.shortValueStatement,
    required this.location,
    required this.profileImagePath,
    required this.coverImagePath,
    required this.showViewMyWork,
    required this.showDownloadCv,
    required this.showContactMe,
    required this.aboutSummary,
    required this.yearsOfExperience,
    required this.coreStrengths,
    required this.careerFocus,
    required this.industriesWorkedIn,
    required this.skills,
    required this.professionalExperienceEntries,
    required this.projectEntries,
    required this.educationEntries,
    required this.contactEmail,
    required this.contactPhoneCode,
    required this.contactPhoneNumber,
    required this.contactLocation,
    required this.contactLinks,
  });
}

class AIPortfolioState {
  final AIPortfolioEntity portfolio;
  final PortfolioTab currentTab;

  final bool canGoNext;
  final bool canNavigateTabs;
  final bool canPreview;

  final bool isLoading;
  final bool isSaving;
  final bool isDeleting;
  final bool isResetting;
  final bool isUploadingProfileImage;
  final bool isLoadingTemplates;
  final bool isLoadingPreview;
  final bool isPublishing;
  final bool isUnpublishing;
  final bool isExportingPdf;

  final String? portfolioId;
  final bool isPublished;
  final String publicUrl;
  final String pdfUrl;
  final String previewHtml;
  final String? errorMessage;

  final List<PortfolioTemplateModel> templates;
  final List<AIPortfolioSummaryModel> userPortfolios;

  final bool isCoverExpanded;
  final bool isProfessionalExperienceExpanded;
  final bool isProjectsExpanded;
  final bool isSkillsExpanded;
  final bool isEducationExpanded;
  final bool isContactExpanded;

  final List<ProfessionalExperienceEntryModel> professionalExperienceEntries;
  final List<ProjectEntryModel> projectEntries;
  final List<EducationEntryModel> educationEntries;

  final String contactEmail;
  final String contactPhoneCode;
  final String contactPhoneNumber;
  final String contactLocation;
  final List<String> contactLinks;

  final AboutMeModel aboutMe;

  final bool showViewMyWorkButton;
  final bool showDownloadCvButton;
  final bool showContactMeButton;

  final PortfolioTemplateType? selectedTemplate;
  final bool hasSelectedTemplate;

  const AIPortfolioState({
    required this.portfolio,
    this.currentTab = PortfolioTab.edit,
    this.canGoNext = false,
    this.canNavigateTabs = false,
    this.canPreview = false,
    this.isLoading = false,
    this.isSaving = false,
    this.isDeleting = false,
    this.isResetting = false,
    this.isUploadingProfileImage = false,
    this.isLoadingTemplates = false,
    this.isLoadingPreview = false,
    this.isPublishing = false,
    this.isUnpublishing = false,
    this.isExportingPdf = false,
    this.portfolioId,
    this.isPublished = false,
    this.publicUrl = '',
    this.pdfUrl = '',
    this.previewHtml = '',
    this.errorMessage,
    this.templates = const [],
    this.userPortfolios = const [],
    this.isCoverExpanded = false,
    this.isProfessionalExperienceExpanded = false,
    this.isProjectsExpanded = false,
    this.isSkillsExpanded = false,
    this.isEducationExpanded = false,
    this.isContactExpanded = false,
    this.professionalExperienceEntries = const [],
    this.projectEntries = const [],
    this.educationEntries = const [],
    this.contactEmail = '',
    this.contactPhoneCode = '+02',
    this.contactPhoneNumber = '',
    this.contactLocation = '',
    this.contactLinks = const [],
    this.aboutMe = const AboutMeModel(),
    this.showViewMyWorkButton = true,
    this.showDownloadCvButton = false,
    this.showContactMeButton = false,
    this.selectedTemplate,
    this.hasSelectedTemplate = false,
  });

  AIPortfolioState copyWith({
    AIPortfolioEntity? portfolio,
    PortfolioTab? currentTab,
    bool? canGoNext,
    bool? canNavigateTabs,
    bool? canPreview,
    bool? isLoading,
    bool? isSaving,
    bool? isDeleting,
    bool? isResetting,
    bool? isUploadingProfileImage,
    bool? isLoadingTemplates,
    bool? isLoadingPreview,
    bool? isPublishing,
    bool? isUnpublishing,
    bool? isExportingPdf,
    String? portfolioId,
    bool? isPublished,
    String? publicUrl,
    String? pdfUrl,
    String? previewHtml,
    String? errorMessage,
    List<PortfolioTemplateModel>? templates,
    List<AIPortfolioSummaryModel>? userPortfolios,
    bool? isCoverExpanded,
    bool? isProfessionalExperienceExpanded,
    bool? isProjectsExpanded,
    bool? isSkillsExpanded,
    bool? isEducationExpanded,
    bool? isContactExpanded,
    List<ProfessionalExperienceEntryModel>? professionalExperienceEntries,
    List<ProjectEntryModel>? projectEntries,
    List<EducationEntryModel>? educationEntries,
    String? contactEmail,
    String? contactPhoneCode,
    String? contactPhoneNumber,
    String? contactLocation,
    List<String>? contactLinks,
    AboutMeModel? aboutMe,
    bool? showViewMyWorkButton,
    bool? showDownloadCvButton,
    bool? showContactMeButton,
    PortfolioTemplateType? selectedTemplate,
    bool? hasSelectedTemplate,
    bool clearPortfolioId = false,
    bool clearSelectedTemplate = false,
    bool clearErrorMessage = false,
  }) {
    return AIPortfolioState(
      portfolio: portfolio ?? this.portfolio,
      currentTab: currentTab ?? this.currentTab,
      canGoNext: canGoNext ?? this.canGoNext,
      canNavigateTabs: canNavigateTabs ?? this.canNavigateTabs,
      canPreview: canPreview ?? this.canPreview,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isDeleting: isDeleting ?? this.isDeleting,
      isResetting: isResetting ?? this.isResetting,
      isUploadingProfileImage:
          isUploadingProfileImage ?? this.isUploadingProfileImage,
      isLoadingTemplates: isLoadingTemplates ?? this.isLoadingTemplates,
      isLoadingPreview: isLoadingPreview ?? this.isLoadingPreview,
      isPublishing: isPublishing ?? this.isPublishing,
      isUnpublishing: isUnpublishing ?? this.isUnpublishing,
      isExportingPdf: isExportingPdf ?? this.isExportingPdf,
      portfolioId: clearPortfolioId ? null : (portfolioId ?? this.portfolioId),
      isPublished: isPublished ?? this.isPublished,
      publicUrl: publicUrl ?? this.publicUrl,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      previewHtml: previewHtml ?? this.previewHtml,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      templates: templates ?? this.templates,
      userPortfolios: userPortfolios ?? this.userPortfolios,
      isCoverExpanded: isCoverExpanded ?? this.isCoverExpanded,
      isProfessionalExperienceExpanded: isProfessionalExperienceExpanded ??
          this.isProfessionalExperienceExpanded,
      isProjectsExpanded: isProjectsExpanded ?? this.isProjectsExpanded,
      isSkillsExpanded: isSkillsExpanded ?? this.isSkillsExpanded,
      isEducationExpanded: isEducationExpanded ?? this.isEducationExpanded,
      isContactExpanded: isContactExpanded ?? this.isContactExpanded,
      professionalExperienceEntries:
          professionalExperienceEntries ?? this.professionalExperienceEntries,
      projectEntries: projectEntries ?? this.projectEntries,
      educationEntries: educationEntries ?? this.educationEntries,
      contactEmail: contactEmail ?? this.contactEmail,
      contactPhoneCode: contactPhoneCode ?? this.contactPhoneCode,
      contactPhoneNumber: contactPhoneNumber ?? this.contactPhoneNumber,
      contactLocation: contactLocation ?? this.contactLocation,
      contactLinks: contactLinks ?? this.contactLinks,
      aboutMe: aboutMe ?? this.aboutMe,
      showViewMyWorkButton: showViewMyWorkButton ?? this.showViewMyWorkButton,
      showDownloadCvButton: showDownloadCvButton ?? this.showDownloadCvButton,
      showContactMeButton: showContactMeButton ?? this.showContactMeButton,
      selectedTemplate: clearSelectedTemplate
          ? null
          : (selectedTemplate ?? this.selectedTemplate),
      hasSelectedTemplate: hasSelectedTemplate ?? this.hasSelectedTemplate,
    );
  }

  factory AIPortfolioState.initial() {
    return AIPortfolioState(
      portfolio: AIPortfolioEntity.initial(),
    );
  }
}

class AIPortfolioNotifier extends StateNotifier<AIPortfolioState> {
  final AIPortfolioRepository _repository;
  final ImagePicker _imagePicker = ImagePicker();

  AIPortfolioNotifier({
    AIPortfolioRepository? repository,
  })  : _repository = repository ??
            AIPortfolioRepositoryImpl(
              remoteDataSource: AIPortfolioRemoteDataSource(),
            ),
        super(AIPortfolioState.initial()) {
    _recalculateProgress();
    Future.microtask(loadTemplates);
  }

  static const List<String> professionalExperienceMonths = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const List<String> skillCategories = [
    'UI/UX Design',
    'Computer Vision',
    'Tools & Technologies',
    'Web Development',
    'Mobile Development',
    'Soft Skills',
  ];

  static const List<String> skillProficiencies = [
    'Beginner',
    'Intermediate',
    'Advanced',
    'Expert',
  ];

  List<String> get professionalExperienceYears {
    final currentYear = DateTime.now().year;
    const earliestYear = 1950;
    final latestYear = currentYear + 5;

    return List.generate(
      latestYear - earliestYear + 1,
      (index) => (latestYear - index).toString(),
    );
  }

  int get selectedTemplateId {
    switch (state.selectedTemplate) {
      case PortfolioTemplateType.design1:
        return 1;
      case PortfolioTemplateType.design2:
        return 2;
      case PortfolioTemplateType.design3:
        return 3;
      case PortfolioTemplateType.design4:
        return 4;
      case null:
        return 1;
    }
  }

  bool get hasPreviewableTemplate =>
      state.selectedTemplate != null && state.hasSelectedTemplate;

  PortfolioTemplateType _templateTypeFromId(int id) {
    switch (id) {
      case 1:
        return PortfolioTemplateType.design1;
      case 2:
        return PortfolioTemplateType.design2;
      case 3:
        return PortfolioTemplateType.design3;
      case 4:
        return PortfolioTemplateType.design4;
      default:
        return PortfolioTemplateType.design1;
    }
  }

  Future<void> loadTemplates() async {
    state = state.copyWith(
      isLoadingTemplates: true,
      clearErrorMessage: true,
    );

    try {
      final templates = await _repository.getTemplates();

      state = state.copyWith(
        templates: templates,
        isLoadingTemplates: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingTemplates: false,
        errorMessage: e.toString(),
      );
    }
  }

  void goToTab(PortfolioTab tab) {
    if (tab == PortfolioTab.edit) {
      state = state.copyWith(currentTab: tab);
      return;
    }

    if (!state.canNavigateTabs) return;
    if (tab == PortfolioTab.preview && !state.canPreview) return;
    if (tab == PortfolioTab.settings && !state.canPreview) return;

    state = state.copyWith(currentTab: tab);
  }

  void goBackToDesigns() {
    state = state.copyWith(currentTab: PortfolioTab.designs);
  }

  void toggleCoverExpanded() {
    state = state.copyWith(isCoverExpanded: !state.isCoverExpanded);
  }

  void toggleProfessionalExperienceExpanded() {
    state = state.copyWith(
      isProfessionalExperienceExpanded: !state.isProfessionalExperienceExpanded,
    );
  }

  void toggleProjectsExpanded() {
    state = state.copyWith(isProjectsExpanded: !state.isProjectsExpanded);
  }

  void toggleSkillsExpanded() {
    state = state.copyWith(isSkillsExpanded: !state.isSkillsExpanded);
  }

  void toggleEducationExpanded() {
    state = state.copyWith(isEducationExpanded: !state.isEducationExpanded);
  }

  void toggleContactExpanded() {
    state = state.copyWith(isContactExpanded: !state.isContactExpanded);
  }

  void updateFullName(String value) {
    _setCover(state.portfolio.cover.copyWith(fullName: value));
  }

  void updateProfessionalTitle(String value) {
    _setCover(state.portfolio.cover.copyWith(professionalTitle: value));
  }

  void updateShortValueStatement(String value) {
    _setCover(state.portfolio.cover.copyWith(shortValueStatement: value));
  }

  void updateLocation(String value) {
    _setCover(state.portfolio.cover.copyWith(location: value));
  }

  Future<void> pickProfileImage() async {
    final file = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    _setCover(
      state.portfolio.cover.copyWith(
        profileImagePath: file.path,
        profileImageName: file.name,
      ),
    );

    state = state.copyWith(
      isUploadingProfileImage: true,
      clearErrorMessage: true,
    );

    try {
      final bytes = await file.readAsBytes();

      final uploaded = await _repository.uploadImage(
        bytes: bytes,
        fileName: file.name,
      );

      _setCover(
        state.portfolio.cover.copyWith(
          profileImagePath: file.path,
          profileImageName: file.name,
          profileImageUrl: uploaded.fileUrl,
          profileImagePublicId: uploaded.publicId,
        ),
      );

      state = state.copyWith(isUploadingProfileImage: false);
    } catch (e) {
      state = state.copyWith(
        isUploadingProfileImage: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> pickCoverImage() async {
    final file = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    _setCover(
      state.portfolio.cover.copyWith(
        coverImagePath: file.path,
        coverImageName: file.name,
      ),
    );
  }

  Future<void> pickResumeFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
      withData: kIsWeb,
    );

    if (result == null || result.files.isEmpty) return;

    final picked = result.files.first;
    String? storedResumePath = picked.path;

    if (kIsWeb) {
      final bytes = picked.bytes;
      if (bytes == null || bytes.isEmpty) return;

      final mimeType = _resumeMimeType(picked.extension);
      final encoded = base64Encode(bytes);
      storedResumePath = 'data:$mimeType;base64,$encoded';
    }

    if (storedResumePath == null || storedResumePath.trim().isEmpty) return;

    _setCover(
      state.portfolio.cover.copyWith(
        resumePath: storedResumePath,
        resumeFileName: picked.name,
      ),
    );
  }

  String _resumeMimeType(String? extension) {
    switch ((extension ?? '').toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }

  void removeProfileImage() {
    _setCover(state.portfolio.cover.copyWith(clearProfileImage: true));
  }

  void removeCoverImage() {
    _setCover(state.portfolio.cover.copyWith(clearCoverImage: true));
  }

  void removeResumeFile() {
    _setCover(state.portfolio.cover.copyWith(clearResume: true));
  }

  void setViewMyWorkEnabled(bool value) {
    state = state.copyWith(showViewMyWorkButton: value);
    _recalculateProgress();
  }

  void setDownloadCvEnabled(bool value) {
    state = state.copyWith(showDownloadCvButton: value);
    _recalculateProgress();
  }

  void setContactMeEnabled(bool value) {
    state = state.copyWith(showContactMeButton: value);
    _recalculateProgress();
  }

  void updateAboutSummary(String value) {
    state = state.copyWith(
      aboutMe: state.aboutMe.copyWith(professionalSummary: value),
    );
    _recalculateProgress();
  }

  void updateAboutYearsOfExperience(int value) {
    state = state.copyWith(
      aboutMe: state.aboutMe.copyWith(yearsOfExperience: value),
    );
    _recalculateProgress();
  }

  void addAboutCoreStrength(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    if (state.aboutMe.coreStrengths.contains(trimmed)) return;

    state = state.copyWith(
      aboutMe: state.aboutMe.copyWith(
        coreStrengths: [...state.aboutMe.coreStrengths, trimmed],
      ),
    );
    _recalculateProgress();
  }

  void removeAboutCoreStrength(String value) {
    state = state.copyWith(
      aboutMe: state.aboutMe.copyWith(
        coreStrengths:
            state.aboutMe.coreStrengths.where((item) => item != value).toList(),
      ),
    );
    _recalculateProgress();
  }

  void addAboutCareerFocus(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    if (state.aboutMe.careerFocus.contains(trimmed)) return;

    state = state.copyWith(
      aboutMe: state.aboutMe.copyWith(
        careerFocus: [...state.aboutMe.careerFocus, trimmed],
      ),
    );
    _recalculateProgress();
  }

  void removeAboutCareerFocus(String value) {
    state = state.copyWith(
      aboutMe: state.aboutMe.copyWith(
        careerFocus:
            state.aboutMe.careerFocus.where((item) => item != value).toList(),
      ),
    );
    _recalculateProgress();
  }

  void addAboutIndustry(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    if (state.aboutMe.industriesWorkedIn.contains(trimmed)) return;

    state = state.copyWith(
      aboutMe: state.aboutMe.copyWith(
        industriesWorkedIn: [...state.aboutMe.industriesWorkedIn, trimmed],
      ),
    );
    _recalculateProgress();
  }

  void removeAboutIndustry(String value) {
    state = state.copyWith(
      aboutMe: state.aboutMe.copyWith(
        industriesWorkedIn: state.aboutMe.industriesWorkedIn
            .where((item) => item != value)
            .toList(),
      ),
    );
    _recalculateProgress();
  }

  void addSkill() {
    final skills = [...state.portfolio.skills];

    skills.add(
      PortfolioSkillEntity.empty(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
      ),
    );

    _setPortfolio(state.portfolio.copyWith(skills: skills));
    state = state.copyWith(isSkillsExpanded: true);
  }

  void updateSkill({
    required String id,
    String? skillName,
    String? category,
    String? proficiency,
    int? yearsOfExperience,
    String? description,
  }) {
    final updated = state.portfolio.skills.map((skill) {
      if (skill.id != id) return skill;

      return skill.copyWith(
        skillName: skillName,
        category: category,
        proficiency: proficiency,
        yearsOfExperience: yearsOfExperience,
        description: description,
      );
    }).toList();

    _setPortfolio(state.portfolio.copyWith(skills: updated));
  }

  void deleteSkill(String id) {
    final updated = state.portfolio.skills.where((s) => s.id != id).toList();
    _setPortfolio(state.portfolio.copyWith(skills: updated));
  }

  void addProfessionalExperienceEntry() {
    final newEntry = ProfessionalExperienceEntryModel(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      isExpanded: true,
    );

    state = state.copyWith(
      isProfessionalExperienceExpanded: true,
      professionalExperienceEntries: [
        ...state.professionalExperienceEntries,
        newEntry,
      ],
    );

    _recalculateProgress();
  }

  void removeProfessionalExperienceEntry(String id) {
    state = state.copyWith(
      professionalExperienceEntries: state.professionalExperienceEntries
          .where((entry) => entry.id != id)
          .toList(),
    );

    _recalculateProgress();
  }

  void toggleProfessionalExperienceEntry(String id) {
    state = state.copyWith(
      professionalExperienceEntries:
          state.professionalExperienceEntries.map((entry) {
        if (entry.id != id) return entry;
        return entry.copyWith(isExpanded: !entry.isExpanded);
      }).toList(),
    );
  }

  void updateProfessionalExperienceJobTitle(String id, String value) {
    _updateProfessionalExperienceEntry(
      id,
      (entry) => entry.copyWith(jobTitle: value),
    );
  }

  void updateProfessionalExperienceCompanyName(String id, String value) {
    _updateProfessionalExperienceEntry(
      id,
      (entry) => entry.copyWith(companyName: value),
    );
  }

  void updateProfessionalExperienceLocation(String id, String value) {
    _updateProfessionalExperienceEntry(
      id,
      (entry) => entry.copyWith(location: value),
    );
  }

  void updateProfessionalExperienceCompanyUrl(String id, String value) {
    _updateProfessionalExperienceEntry(
      id,
      (entry) => entry.copyWith(companyUrl: value),
    );
  }

  void updateProfessionalExperienceStartMonth(String id, String? value) {
    _updateProfessionalExperienceEntry(
      id,
      (entry) => entry.copyWith(startMonth: value),
    );
  }

  void updateProfessionalExperienceStartYear(String id, String? value) {
    _updateProfessionalExperienceEntry(
      id,
      (entry) => entry.copyWith(startYear: value),
    );
  }

  void updateProfessionalExperienceEndMonth(String id, String? value) {
    _updateProfessionalExperienceEntry(
      id,
      (entry) => entry.copyWith(endMonth: value),
    );
  }

  void updateProfessionalExperienceEndYear(String id, String? value) {
    _updateProfessionalExperienceEntry(
      id,
      (entry) => entry.copyWith(endYear: value),
    );
  }

  void updateProfessionalExperienceCurrentlyWorkingHere(String id, bool value) {
    _updateProfessionalExperienceEntry(
      id,
      (entry) => entry.copyWith(
        currentlyWorkingHere: value,
        clearEndDate: value,
      ),
    );
  }

  void updateProfessionalExperienceDescription(String id, String value) {
    _updateProfessionalExperienceEntry(
      id,
      (entry) => entry.copyWith(description: value),
    );
  }

  void _updateProfessionalExperienceEntry(
    String id,
    ProfessionalExperienceEntryModel Function(
      ProfessionalExperienceEntryModel entry,
    ) update,
  ) {
    state = state.copyWith(
      professionalExperienceEntries:
          state.professionalExperienceEntries.map((entry) {
        if (entry.id != id) return entry;
        return update(entry);
      }).toList(),
    );

    _recalculateProgress();
  }

  void addProjectEntry() {
    final newEntry = ProjectEntryModel(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      isExpanded: true,
    );

    state = state.copyWith(
      isProjectsExpanded: true,
      projectEntries: [...state.projectEntries, newEntry],
    );

    _recalculateProgress();
  }

  void removeProjectEntry(String id) {
    state = state.copyWith(
      projectEntries:
          state.projectEntries.where((entry) => entry.id != id).toList(),
    );

    _recalculateProgress();
  }

  void toggleProjectEntry(String id) {
    state = state.copyWith(
      projectEntries: state.projectEntries.map((entry) {
        if (entry.id != id) return entry;
        return entry.copyWith(isExpanded: !entry.isExpanded);
      }).toList(),
    );
  }

  void updateProjectTitle(String id, String value) {
    _updateProjectEntry(id, (entry) => entry.copyWith(title: value));
  }

  void updateProjectCategory(String id, String value) {
    _updateProjectEntry(id, (entry) => entry.copyWith(category: value));
  }

  void updateProjectShortDescription(String id, String value) {
    _updateProjectEntry(id, (entry) => entry.copyWith(shortDescription: value));
  }

  void updateProjectKeyOutcomes(String id, String value) {
    _updateProjectEntry(id, (entry) => entry.copyWith(keyOutcomes: value));
  }

  void addProjectTool(String id, String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;

    _updateProjectEntry(id, (entry) {
      if (entry.tools.contains(trimmed)) return entry;
      return entry.copyWith(tools: [...entry.tools, trimmed]);
    });
  }

  void removeProjectTool(String id, String tool) {
    _updateProjectEntry(
      id,
      (entry) => entry.copyWith(
        tools: entry.tools.where((item) => item != tool).toList(),
      ),
    );
  }

  void addProjectLink(String projectId) {
    final newLink = ProjectLinkEntryModel(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      isExpanded: true,
    );

    _updateProjectEntry(
      projectId,
      (entry) => entry.copyWith(links: [...entry.links, newLink]),
    );
  }

  void removeProjectLink(String projectId, String linkId) {
    _updateProjectEntry(
      projectId,
      (entry) => entry.copyWith(
        links: entry.links.where((link) => link.id != linkId).toList(),
      ),
    );
  }

  void toggleProjectLink(String projectId, String linkId) {
    _updateProjectEntry(
      projectId,
      (entry) => entry.copyWith(
        links: entry.links.map((link) {
          if (link.id != linkId) return link;
          return link.copyWith(isExpanded: !link.isExpanded);
        }).toList(),
      ),
    );
  }

  void updateProjectLinkLabel(String projectId, String linkId, String value) {
    _updateProjectEntry(
      projectId,
      (entry) => entry.copyWith(
        links: entry.links.map((link) {
          if (link.id != linkId) return link;
          return link.copyWith(label: value);
        }).toList(),
      ),
    );
  }

  void updateProjectLinkUrl(String projectId, String linkId, String value) {
    _updateProjectEntry(
      projectId,
      (entry) => entry.copyWith(
        links: entry.links.map((link) {
          if (link.id != linkId) return link;
          return link.copyWith(url: value);
        }).toList(),
      ),
    );
  }

  Future<void> pickProjectCoverImage(String id) async {
    final file = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    _updateProjectEntry(
      id,
      (entry) => entry.copyWith(
        coverImagePath: file.path,
        coverImageName: file.name,
      ),
    );
  }

  void removeProjectCoverImage(String id) {
    _updateProjectEntry(id, (entry) => entry.copyWith(clearCoverImage: true));
  }

  void _updateProjectEntry(
    String id,
    ProjectEntryModel Function(ProjectEntryModel entry) update,
  ) {
    state = state.copyWith(
      projectEntries: state.projectEntries.map((entry) {
        if (entry.id != id) return entry;
        return update(entry);
      }).toList(),
    );

    _recalculateProgress();
  }

  void addEducationEntry() {
    final newEntry = EducationEntryModel(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      isExpanded: true,
    );

    state = state.copyWith(
      isEducationExpanded: true,
      educationEntries: [...state.educationEntries, newEntry],
    );

    _recalculateProgress();
  }

  void removeEducationEntry(String id) {
    state = state.copyWith(
      educationEntries:
          state.educationEntries.where((entry) => entry.id != id).toList(),
    );

    _recalculateProgress();
  }

  void toggleEducationEntry(String id) {
    state = state.copyWith(
      educationEntries: state.educationEntries.map((entry) {
        if (entry.id != id) return entry;
        return entry.copyWith(isExpanded: !entry.isExpanded);
      }).toList(),
    );
  }

  void updateEducationInstitutionName(String id, String value) {
    _updateEducationEntry(id, (entry) {
      return entry.copyWith(institutionName: value);
    });
  }

  void updateEducationDegree(String id, String value) {
    _updateEducationEntry(id, (entry) => entry.copyWith(degree: value));
  }

  void updateEducationFieldOfStudy(String id, String value) {
    _updateEducationEntry(id, (entry) {
      return entry.copyWith(fieldOfStudy: value);
    });
  }

  void updateEducationLocation(String id, String value) {
    _updateEducationEntry(id, (entry) => entry.copyWith(location: value));
  }

  void updateEducationStartMonth(String id, String? value) {
    _updateEducationEntry(id, (entry) => entry.copyWith(startMonth: value));
  }

  void updateEducationStartYear(String id, String? value) {
    _updateEducationEntry(id, (entry) => entry.copyWith(startYear: value));
  }

  void updateEducationEndMonth(String id, String? value) {
    _updateEducationEntry(id, (entry) => entry.copyWith(endMonth: value));
  }

  void updateEducationEndYear(String id, String? value) {
    _updateEducationEntry(id, (entry) => entry.copyWith(endYear: value));
  }

  void updateEducationCurrentlyStudying(String id, bool value) {
    _updateEducationEntry(
      id,
      (entry) => entry.copyWith(
        currentlyStudying: value,
        clearEndDate: value,
      ),
    );
  }

  void updateEducationGpa(String id, String value) {
    _updateEducationEntry(id, (entry) => entry.copyWith(gpa: value));
  }

  void updateEducationDescription(String id, String value) {
    _updateEducationEntry(id, (entry) => entry.copyWith(description: value));
  }

  void addEducationMinor(String id, String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;

    _updateEducationEntry(id, (entry) {
      if (entry.minors.contains(trimmed)) return entry;
      return entry.copyWith(minors: [...entry.minors, trimmed]);
    });
  }

  void removeEducationMinor(String id, String value) {
    _updateEducationEntry(
      id,
      (entry) => entry.copyWith(
        minors: entry.minors.where((item) => item != value).toList(),
      ),
    );
  }

  void addEducationCoursework(String id, String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;

    _updateEducationEntry(id, (entry) {
      if (entry.coursework.contains(trimmed)) return entry;
      return entry.copyWith(coursework: [...entry.coursework, trimmed]);
    });
  }

  void removeEducationCoursework(String id, String value) {
    _updateEducationEntry(
      id,
      (entry) => entry.copyWith(
        coursework: entry.coursework.where((item) => item != value).toList(),
      ),
    );
  }

  void _updateEducationEntry(
    String id,
    EducationEntryModel Function(EducationEntryModel entry) update,
  ) {
    state = state.copyWith(
      educationEntries: state.educationEntries.map((entry) {
        if (entry.id != id) return entry;
        return update(entry);
      }).toList(),
    );

    _recalculateProgress();
  }

  void updateContactEmail(String value) {
    state = state.copyWith(contactEmail: value);
    _recalculateProgress();
  }

  void updateContactPhoneCode(String value) {
    state = state.copyWith(contactPhoneCode: value);
    _recalculateProgress();
  }

  void updateContactPhoneNumber(String value) {
    state = state.copyWith(contactPhoneNumber: value);
    _recalculateProgress();
  }

  void updateContactLocation(String value) {
    state = state.copyWith(contactLocation: value);
    _recalculateProgress();
  }

  void addContactLink(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;

    final exists = state.contactLinks.any(
      (link) => link.toLowerCase() == trimmed.toLowerCase(),
    );

    if (exists) return;

    state = state.copyWith(
      contactLinks: [...state.contactLinks, trimmed],
    );

    _recalculateProgress();
  }

  void removeContactLink(String value) {
    state = state.copyWith(
      contactLinks: state.contactLinks.where((link) => link != value).toList(),
    );

    _recalculateProgress();
  }

  void selectTemplate(PortfolioTemplateType template) {
    state = state.copyWith(
      selectedTemplate: template,
      hasSelectedTemplate: true,
      canPreview: true,
      canNavigateTabs: true,

      // Force the backend preview to be regenerated with the newly selected template.
      previewHtml: '',
      pdfUrl: '',

      // Any existing published URL may still point to an older rendered template.
      publicUrl: '',
      isPublished: false,
      clearErrorMessage: true,
    );

    _recalculateProgress();
  }

  void clearSelectedTemplate() {
    state = state.copyWith(
      clearSelectedTemplate: true,
      hasSelectedTemplate: false,
      canPreview: false,
      currentTab: PortfolioTab.designs,
    );

    _recalculateProgress();
  }

  void onNext() {
    if (state.currentTab == PortfolioTab.edit) {
      if (!state.canGoNext) return;

      state = state.copyWith(
        currentTab: PortfolioTab.designs,
        canNavigateTabs: true,
      );
      return;
    }

    if (state.currentTab == PortfolioTab.designs) {
      if (!state.hasSelectedTemplate) return;

      state = state.copyWith(
        currentTab: PortfolioTab.preview,
        canPreview: true,
        canNavigateTabs: true,
      );
    }
  }

  AIPortfolioRequestModel buildBackendRequest() {
    final cover = state.portfolio.cover;

    final profileUrl = (cover.profileImageUrl ?? '').trim().isNotEmpty
        ? cover.profileImageUrl
        : ((cover.profileImagePath ?? '').startsWith('http')
            ? cover.profileImagePath
            : null);

    final email = state.contactEmail.trim();
    final phone = [
      state.contactPhoneCode.trim(),
      state.contactPhoneNumber.trim(),
    ].where((e) => e.isNotEmpty).join(' ');

    final location = state.contactLocation.trim().isNotEmpty
        ? state.contactLocation.trim()
        : cover.location.trim();

    return AIPortfolioRequestModel(
      name: cover.fullName.trim(),
      title: cover.professionalTitle.trim(),
      about: state.aboutMe.professionalSummary.trim().isNotEmpty
          ? state.aboutMe.professionalSummary.trim()
          : cover.shortValueStatement.trim(),
      email: email,
      phone: phone,
      location: location,
      github: _extractLink('github'),
      linkedin: _extractLink('linkedin'),
      twitter: _extractLink('twitter'),
      selectedTemplate: selectedTemplateId,
      skills: state.portfolio.skills
          .map((e) => e.skillName.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      languages: const [],
      experiences: state.professionalExperienceEntries
          .where((entry) =>
              entry.jobTitle.trim().isNotEmpty ||
              entry.companyName.trim().isNotEmpty)
          .map(
            (entry) => PortfolioExperienceModel(
              jobTitle: entry.jobTitle.trim(),
              company: entry.companyName.trim(),
              location: entry.location.trim(),
              period: _experiencePeriod(entry),
              description: entry.description.trim(),
            ),
          )
          .toList(),
      education: state.educationEntries
          .where((entry) =>
              entry.institutionName.trim().isNotEmpty ||
              entry.degree.trim().isNotEmpty ||
              entry.fieldOfStudy.trim().isNotEmpty)
          .map(
            (entry) => PortfolioEducationModel(
              degree: entry.degree.trim(),
              field: entry.fieldOfStudy.trim(),
              institution: entry.institutionName.trim(),
              location: entry.location.trim(),
              period: _educationPeriod(entry),
              description: entry.description.trim(),
            ),
          )
          .toList(),
      projects: state.projectEntries
          .where((entry) => entry.title.trim().isNotEmpty)
          .map(
            (entry) => PortfolioProjectModel(
              name: entry.title.trim(),
              description: entry.shortDescription.trim().isNotEmpty
                  ? entry.shortDescription.trim()
                  : entry.keyOutcomes.trim(),
              technologies: entry.tools.join(', '),
              link: entry.links.isNotEmpty ? entry.links.first.url.trim() : '',
            ),
          )
          .toList(),
      profileImageUrl: profileUrl,
    );
  }

  String _extractLink(String keyword) {
    for (final link in state.contactLinks) {
      final lower = link.toLowerCase();
      if (lower.contains(keyword) && lower.startsWith('http')) {
        return link.trim();
      }
    }
    return '';
  }

  String _experiencePeriod(ProfessionalExperienceEntryModel entry) {
    final start = [
      if ((entry.startMonth ?? '').trim().isNotEmpty) entry.startMonth,
      if ((entry.startYear ?? '').trim().isNotEmpty) entry.startYear,
    ].whereType<String>().join(' ');

    final end = entry.currentlyWorkingHere
        ? 'Present'
        : [
            if ((entry.endMonth ?? '').trim().isNotEmpty) entry.endMonth,
            if ((entry.endYear ?? '').trim().isNotEmpty) entry.endYear,
          ].whereType<String>().join(' ');

    if (start.isEmpty && end.isEmpty) return '';
    if (start.isEmpty) return end;
    if (end.isEmpty) return start;
    return '$start - $end';
  }

  String _educationPeriod(EducationEntryModel entry) {
    final start = [
      if ((entry.startMonth ?? '').trim().isNotEmpty) entry.startMonth,
      if ((entry.startYear ?? '').trim().isNotEmpty) entry.startYear,
    ].whereType<String>().join(' ');

    final end = entry.currentlyStudying
        ? 'Present'
        : [
            if ((entry.endMonth ?? '').trim().isNotEmpty) entry.endMonth,
            if ((entry.endYear ?? '').trim().isNotEmpty) entry.endYear,
          ].whereType<String>().join(' ');

    if (start.isEmpty && end.isEmpty) return '';
    if (start.isEmpty) return end;
    if (end.isEmpty) return start;
    return '$start - $end';
  }

  Future<AIPortfolioResponseModel?> savePortfolioToBackend() async {
    state = state.copyWith(
      isSaving: true,
      clearErrorMessage: true,
    );

    try {
      final request = buildBackendRequest();

      final response =
          state.portfolioId == null || state.portfolioId!.trim().isEmpty
              ? await _repository.createPortfolio(request)
              : await _repository.updatePortfolio(
                  portfolioId: state.portfolioId!,
                  request: request,
                );

      state = state.copyWith(
        isSaving: false,
        portfolioId: response.id,
        isPublished: response.isPublished,
        publicUrl: response.publicUrl ?? state.publicUrl,
        selectedTemplate: _templateTypeFromId(response.templateIndex),
        hasSelectedTemplate: true,
      );

      return response;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: e.toString(),
      );
      return null;
    }
  }

  Future<void> loadPreviewHtmlFromBackend() async {
    state = state.copyWith(
      isLoadingPreview: true,
      previewHtml: '',
      clearErrorMessage: true,
    );

    try {
      final saved = await savePortfolioToBackend();
      final id = saved?.id ?? state.portfolioId;

      if (id == null || id.trim().isEmpty) {
        throw Exception('Portfolio was not saved correctly.');
      }

      final html = await _repository.previewPortfolio(id);

      state = state.copyWith(
        previewHtml: html,
        isLoadingPreview: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingPreview: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> publishPortfolio() async {
    state = state.copyWith(
      isPublishing: true,
      publicUrl: '',
      clearErrorMessage: true,
    );

    try {
      final saved = await savePortfolioToBackend();
      final id = saved?.id ?? state.portfolioId;

      if (id == null || id.trim().isEmpty) {
        throw Exception('Portfolio was not saved correctly.');
      }

      final url = await _repository.publishPortfolio(id);

      await Future.delayed(const Duration(seconds: 30));

      state = state.copyWith(
        isPublishing: false,
        isPublished: true,
        publicUrl: url,
      );
    } catch (e) {
      state = state.copyWith(
        isPublishing: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> unpublishPortfolio() async {
    final id = state.portfolioId;

    if (id == null || id.trim().isEmpty) return;

    state = state.copyWith(
      isUnpublishing: true,
      clearErrorMessage: true,
    );

    try {
      final result = await _repository.unpublishPortfolio(id);

      state = state.copyWith(
        isUnpublishing: false,
        isPublished: result.success ? false : state.isPublished,
        publicUrl: result.success ? '' : state.publicUrl,
        errorMessage: result.success ? null : result.message,
        clearErrorMessage: result.success,
      );
    } catch (e) {
      state = state.copyWith(
        isUnpublishing: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> exportPortfolioPdf() async {
    state = state.copyWith(
      isExportingPdf: true,
      clearErrorMessage: true,
    );

    try {
      final saved = await savePortfolioToBackend();
      final id = saved?.id ?? state.portfolioId;

      if (id == null || id.trim().isEmpty) {
        throw Exception('Portfolio was not saved correctly.');
      }

      final result = await _repository.exportPortfolioPdf(id);

      state = state.copyWith(
        isExportingPdf: false,
        pdfUrl: result.pdfUrl,
      );
    } catch (e) {
      state = state.copyWith(
        isExportingPdf: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> deletePortfolioFromBackend() async {
    final id = state.portfolioId;

    if (id == null || id.trim().isEmpty) {
      resetPortfolio();
      return;
    }

    state = state.copyWith(
      isDeleting: true,
      clearErrorMessage: true,
    );

    try {
      final result = await _repository.deletePortfolio(id);

      if (result.success) {
        resetPortfolio();
      } else {
        state = state.copyWith(
          isDeleting: false,
          errorMessage: result.message,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isDeleting: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> loadUserPortfolios() async {
    state = state.copyWith(
      isLoading: true,
      clearErrorMessage: true,
    );

    try {
      final list = await _repository.getUserPortfolios();

      state = state.copyWith(
        isLoading: false,
        userPortfolios: list,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> loadPortfolioById(String portfolioId) async {
    state = state.copyWith(
      isLoading: true,
      clearErrorMessage: true,
    );

    try {
      final response = await _repository.getPortfolio(portfolioId);

      _applyBackendData(
        data: response.data,
        portfolioId: response.id,
        isPublished: response.isPublished,
        publicUrl: response.publicUrl ?? '',
      );

      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> loadLastSavedPortfolioData() async {
    state = state.copyWith(
      isLoading: true,
      clearErrorMessage: true,
    );

    try {
      final result = await _repository.getLastSavedPortfolioData();

      if (result.data != null) {
        _applyBackendData(
          data: result.data!,
          portfolioId: null,
          isPublished: false,
          publicUrl: '',
        );
      }

      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  void _applyBackendData({
    required AIPortfolioRequestModel data,
    required String? portfolioId,
    required bool isPublished,
    required String publicUrl,
  }) {
    final skills = data.skills
        .map(
          (skill) => PortfolioSkillEntity(
            id: DateTime.now().microsecondsSinceEpoch.toString() + skill,
            skillName: skill,
            category: '',
            proficiency: '',
            yearsOfExperience: 0,
            description: '',
          ),
        )
        .toList();

    final experiences = data.experiences
        .map(
          (e) => ProfessionalExperienceEntryModel(
            id: DateTime.now().microsecondsSinceEpoch.toString() + e.jobTitle,
            jobTitle: e.jobTitle,
            companyName: e.company,
            location: e.location,
            description: e.description,
            isExpanded: false,
          ),
        )
        .toList();

    final projects = data.projects
        .map(
          (p) => ProjectEntryModel(
            id: DateTime.now().microsecondsSinceEpoch.toString() + p.name,
            title: p.name,
            shortDescription: p.description,
            tools: p.technologies
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList(),
            links: p.link.trim().isEmpty
                ? const []
                : [
                    ProjectLinkEntryModel(
                      id: DateTime.now().microsecondsSinceEpoch.toString(),
                      label: 'Project',
                      url: p.link,
                      isExpanded: false,
                    ),
                  ],
            isExpanded: false,
          ),
        )
        .toList();

    final education = data.education
        .map(
          (e) => EducationEntryModel(
            id: DateTime.now().microsecondsSinceEpoch.toString() + e.degree,
            institutionName: e.institution,
            degree: e.degree,
            fieldOfStudy: e.field,
            location: e.location,
            description: e.description,
            isExpanded: false,
          ),
        )
        .toList();

    final selectedTemplate = _templateTypeFromId(data.selectedTemplate);

    state = state.copyWith(
      portfolio: AIPortfolioEntity(
        cover: PortfolioCoverEntity(
          fullName: data.name,
          professionalTitle: data.title,
          shortValueStatement: data.about,
          location: data.location,
          profileImagePath: data.profileImageUrl,
          profileImageUrl: data.profileImageUrl,
        ),
        skills: skills,
      ),
      portfolioId: portfolioId,
      isPublished: isPublished,
      publicUrl: publicUrl,
      aboutMe: AboutMeModel(professionalSummary: data.about),
      contactEmail: data.email,
      contactPhoneCode: '',
      contactPhoneNumber: data.phone,
      contactLocation: data.location,
      contactLinks: [
        if (data.github.trim().isNotEmpty) data.github,
        if (data.linkedin.trim().isNotEmpty) data.linkedin,
        if (data.twitter.trim().isNotEmpty) data.twitter,
      ],
      professionalExperienceEntries: experiences,
      projectEntries: projects,
      educationEntries: education,
      selectedTemplate: selectedTemplate,
      hasSelectedTemplate: true,
      canNavigateTabs: true,
      canPreview: true,
    );

    _recalculateProgress();
  }

  PortfolioTemplatePreviewData buildTemplatePreviewData() {
    final cover = state.portfolio.cover;

    return PortfolioTemplatePreviewData(
      fullName:
          cover.fullName.trim().isEmpty ? 'Your Name' : cover.fullName.trim(),
      professionalTitle: cover.professionalTitle.trim().isEmpty
          ? 'Professional Title'
          : cover.professionalTitle.trim(),
      shortValueStatement: cover.shortValueStatement.trim().isEmpty
          ? 'Write a short statement about your value.'
          : cover.shortValueStatement.trim(),
      location: cover.location.trim().isEmpty
          ? state.contactLocation
          : cover.location,
      profileImagePath: cover.profileImagePath ?? cover.profileImageUrl,
      coverImagePath: cover.coverImagePath,
      showViewMyWork: state.showViewMyWorkButton,
      showDownloadCv: state.showDownloadCvButton,
      showContactMe: state.showContactMeButton,
      aboutSummary: state.aboutMe.professionalSummary.trim().isEmpty
          ? 'No professional summary added yet.'
          : state.aboutMe.professionalSummary.trim(),
      yearsOfExperience: state.aboutMe.yearsOfExperience,
      coreStrengths: List<String>.from(state.aboutMe.coreStrengths),
      careerFocus: List<String>.from(state.aboutMe.careerFocus),
      industriesWorkedIn: List<String>.from(state.aboutMe.industriesWorkedIn),
      skills: List<PortfolioSkillEntity>.from(state.portfolio.skills),
      professionalExperienceEntries:
          List<ProfessionalExperienceEntryModel>.from(
        state.professionalExperienceEntries,
      ),
      projectEntries: List<ProjectEntryModel>.from(state.projectEntries),
      educationEntries: List<EducationEntryModel>.from(state.educationEntries),
      contactEmail: state.contactEmail,
      contactPhoneCode: state.contactPhoneCode,
      contactPhoneNumber: state.contactPhoneNumber,
      contactLocation: state.contactLocation,
      contactLinks: List<String>.from(state.contactLinks),
    );
  }

  void resetPortfolio() {
    state = AIPortfolioState.initial().copyWith(
      currentTab: PortfolioTab.edit,
      canNavigateTabs: false,
      canPreview: false,
      canGoNext: false,
      professionalExperienceEntries: const [],
      projectEntries: const [],
      educationEntries: const [],
      contactEmail: '',
      contactPhoneCode: '+02',
      contactPhoneNumber: '',
      contactLocation: '',
      contactLinks: const [],
      aboutMe: const AboutMeModel(),
      showViewMyWorkButton: true,
      showDownloadCvButton: false,
      showContactMeButton: false,
      hasSelectedTemplate: false,
      publicUrl: '',
      pdfUrl: '',
      previewHtml: '',
      isPublished: false,
      clearPortfolioId: true,
      clearSelectedTemplate: true,
      clearErrorMessage: true,
      templates: state.templates,
    );

    _recalculateProgress();
  }

  void deletePortfolio() {
    resetPortfolio();
  }

  void _setCover(PortfolioCoverEntity cover) {
    _setPortfolio(state.portfolio.copyWith(cover: cover));
  }

  void _setPortfolio(AIPortfolioEntity portfolio) {
    state = state.copyWith(portfolio: portfolio);
    _recalculateProgress();
  }

  void _recalculateProgress() {
    final canGoNext = _isPortfolioReadyForDesignSelection();
    final canNavigateTabs = canGoNext || state.currentTab != PortfolioTab.edit;
    final canPreview = canGoNext &&
        state.hasSelectedTemplate &&
        state.selectedTemplate != null;

    state = state.copyWith(
      canGoNext: canGoNext,
      canNavigateTabs: canNavigateTabs,
      canPreview: canPreview,
    );
  }

  bool _isPortfolioReadyForDesignSelection() {
    return _isCoverValid() &&
        _isAboutMeValid() &&
        _isExperienceValid() &&
        _isProjectsValid() &&
        _isSkillsValid() &&
        _isEducationValid() &&
        _isContactValid();
  }

  bool _isCoverValid() {
    final cover = state.portfolio.cover;

    final hasUploadedProfile =
        (cover.profileImageUrl ?? '').trim().isNotEmpty ||
            (cover.profileImagePath ?? '').trim().isNotEmpty;

    return cover.fullName.trim().isNotEmpty &&
        cover.professionalTitle.trim().isNotEmpty &&
        hasUploadedProfile;
  }

  bool _isAboutMeValid() {
    return state.aboutMe.professionalSummary.trim().isNotEmpty ||
        state.aboutMe.coreStrengths.isNotEmpty;
  }

  bool _isExperienceValid() {
    if (state.professionalExperienceEntries.isEmpty) return false;

    return state.professionalExperienceEntries.any((entry) {
      return entry.jobTitle.trim().isNotEmpty &&
          entry.companyName.trim().isNotEmpty;
    });
  }

  bool _isProjectsValid() {
    if (state.projectEntries.isEmpty) return false;

    return state.projectEntries.any((entry) {
      return entry.title.trim().isNotEmpty;
    });
  }

  bool _isSkillsValid() {
    if (state.portfolio.skills.isEmpty) return false;

    return state.portfolio.skills.any((skill) {
      return skill.skillName.trim().isNotEmpty;
    });
  }

  bool _isEducationValid() {
    if (state.educationEntries.isEmpty) return false;

    return state.educationEntries.any((entry) {
      return entry.institutionName.trim().isNotEmpty &&
          (entry.degree.trim().isNotEmpty ||
              entry.fieldOfStudy.trim().isNotEmpty);
    });
  }

  bool _isContactValid() {
    return state.contactEmail.trim().isNotEmpty ||
        state.contactPhoneNumber.trim().isNotEmpty;
  }
}

final aiPortfolioProvider =
    StateNotifierProvider<AIPortfolioNotifier, AIPortfolioState>(
  (ref) => AIPortfolioNotifier(),
);

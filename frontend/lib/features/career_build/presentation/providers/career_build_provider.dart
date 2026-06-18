import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/app_notification_service.dart';
import '../../../../core/services/career_build_cache_service.dart';
import '../../data/models/career_build_models.dart';
import '../../data/repositories/career_build_repository_impl.dart';
import '../../../alerts/data/datasources/alerts_local_datasource.dart';

/// ----------------------------
/// UI MODELS
/// ----------------------------

class CourseLinkUiModel {
  final String id;
  final String title;
  final String url;
  final String providerKey;

  final String type;
  final String snippet;
  final String duration;
  final int? youtubeDurationMinutes;

  const CourseLinkUiModel({
    required this.id,
    required this.title,
    required this.url,
    this.providerKey = 'external',
    this.type = 'external',
    this.snippet = '',
    this.duration = '',
    this.youtubeDurationMinutes,
  });

  CourseLinkUiModel copyWith({
    String? id,
    String? title,
    String? url,
    String? providerKey,
    String? type,
    String? snippet,
    String? duration,
    int? youtubeDurationMinutes,
  }) {
    return CourseLinkUiModel(
      id: id ?? this.id,
      title: title ?? this.title,
      url: url ?? this.url,
      providerKey: providerKey ?? this.providerKey,
      type: type ?? this.type,
      snippet: snippet ?? this.snippet,
      duration: duration ?? this.duration,
      youtubeDurationMinutes:
          youtubeDurationMinutes ?? this.youtubeDurationMinutes,
    );
  }
}

class PlanWeekUiModel {
  final int weekNumber;
  final String title;
  final String goal;
  final List<String> focusPoints;
  final String skillTag;

  /// legacy fallback
  final String? courseUrl;

  /// backend-friendly resources
  final List<CourseLinkUiModel> courseLinks;

  /// backend fields
  final String planSummary;
  final List<String> focusSkills;
  final String topic;
  final String description;
  final List<String> learningOutcomes;
  final String expectedLevelAfterWeek;
  final List<String> whatToStudy;
  final List<String> howToStudy;
  final Map<String, dynamic> timeSplit;

  const PlanWeekUiModel({
    required this.weekNumber,
    required this.title,
    required this.goal,
    required this.focusPoints,
    required this.skillTag,
    this.courseUrl,
    this.courseLinks = const [],
    this.planSummary = '',
    this.focusSkills = const [],
    this.topic = '',
    this.description = '',
    this.learningOutcomes = const [],
    this.expectedLevelAfterWeek = '',
    this.whatToStudy = const [],
    this.howToStudy = const [],
    this.timeSplit = const {},
  });

  PlanWeekUiModel copyWith({
    int? weekNumber,
    String? title,
    String? goal,
    List<String>? focusPoints,
    String? skillTag,
    String? courseUrl,
    List<CourseLinkUiModel>? courseLinks,
    String? planSummary,
    List<String>? focusSkills,
    String? topic,
    String? description,
    List<String>? learningOutcomes,
    String? expectedLevelAfterWeek,
    List<String>? whatToStudy,
    List<String>? howToStudy,
    Map<String, dynamic>? timeSplit,
  }) {
    return PlanWeekUiModel(
      weekNumber: weekNumber ?? this.weekNumber,
      title: title ?? this.title,
      goal: goal ?? this.goal,
      focusPoints: focusPoints ?? this.focusPoints,
      skillTag: skillTag ?? this.skillTag,
      courseUrl: courseUrl ?? this.courseUrl,
      courseLinks: courseLinks ?? this.courseLinks,
      planSummary: planSummary ?? this.planSummary,
      focusSkills: focusSkills ?? this.focusSkills,
      topic: topic ?? this.topic,
      description: description ?? this.description,
      learningOutcomes: learningOutcomes ?? this.learningOutcomes,
      expectedLevelAfterWeek:
          expectedLevelAfterWeek ?? this.expectedLevelAfterWeek,
      whatToStudy: whatToStudy ?? this.whatToStudy,
      howToStudy: howToStudy ?? this.howToStudy,
      timeSplit: timeSplit ?? this.timeSplit,
    );
  }
}

class CareerPlanUiModel {
  final String id;
  final String title;
  final bool isViewed;
  final List<String> skillsIncluded;
  final int weeks;
  final int months;
  final DateTime createdAt;
  final List<PlanWeekUiModel> roadmap;

  final int? backendPlanId;
  final String planSummary;
  final String improvementSummary;
  final String planningMode;
  final String studyIntensity;
  final int availableHoursPerWeek;
  final CareerPlanModel? backendPlan;

  CareerPlanUiModel({
    required this.id,
    required this.title,
    required this.isViewed,
    this.skillsIncluded = const [],
    this.weeks = 3,
    this.months = 0,
    DateTime? createdAt,
    this.roadmap = const [],
    this.backendPlanId,
    this.planSummary = '',
    this.improvementSummary = '',
    this.planningMode = '',
    this.studyIntensity = '',
    this.availableHoursPerWeek = 0,
    this.backendPlan,
  }) : createdAt = createdAt ?? DateTime.now();

  CareerPlanUiModel copyWith({
    String? id,
    String? title,
    bool? isViewed,
    List<String>? skillsIncluded,
    int? weeks,
    int? months,
    DateTime? createdAt,
    List<PlanWeekUiModel>? roadmap,
    int? backendPlanId,
    String? planSummary,
    String? improvementSummary,
    String? planningMode,
    String? studyIntensity,
    int? availableHoursPerWeek,
    CareerPlanModel? backendPlan,
  }) {
    return CareerPlanUiModel(
      id: id ?? this.id,
      title: title ?? this.title,
      isViewed: isViewed ?? this.isViewed,
      skillsIncluded: skillsIncluded ?? this.skillsIncluded,
      weeks: weeks ?? this.weeks,
      months: months ?? this.months,
      createdAt: createdAt ?? this.createdAt,
      roadmap: roadmap ?? this.roadmap,
      backendPlanId: backendPlanId ?? this.backendPlanId,
      planSummary: planSummary ?? this.planSummary,
      improvementSummary: improvementSummary ?? this.improvementSummary,
      planningMode: planningMode ?? this.planningMode,
      studyIntensity: studyIntensity ?? this.studyIntensity,
      availableHoursPerWeek:
          availableHoursPerWeek ?? this.availableHoursPerWeek,
      backendPlan: backendPlan ?? this.backendPlan,
    );
  }
}

enum SkillLevel { none, beginner, intermediate, advanced }

extension SkillLevelX on SkillLevel {
  String get label {
    switch (this) {
      case SkillLevel.none:
        return 'None';
      case SkillLevel.beginner:
        return 'Beginner';
      case SkillLevel.intermediate:
        return 'Intermediate';
      case SkillLevel.advanced:
        return 'Advanced';
    }
  }

  String get backendValue {
    switch (this) {
      case SkillLevel.none:
        return 'none';
      case SkillLevel.beginner:
        return 'beginner';
      case SkillLevel.intermediate:
        return 'intermediate';
      case SkillLevel.advanced:
        return 'advanced';
    }
  }

  static SkillLevel? fromLabel(String? label) {
    if (label == null) return null;
    final v = label.trim().toLowerCase();
    if (v == 'none') return SkillLevel.none;
    if (v == 'beginner') return SkillLevel.beginner;
    if (v == 'intermediate') return SkillLevel.intermediate;
    if (v == 'advanced') return SkillLevel.advanced;
    return null;
  }
}

/// Kept only for backward compatibility with old screens.
/// New regenerate flow uses RegenerationIntentModel from backend.
enum RegenerationLevel {
  beginner,
  intermediate,
  advanced,
  expert,
}

extension RegenerationLevelX on RegenerationLevel {
  String get label {
    switch (this) {
      case RegenerationLevel.beginner:
        return 'Beginner';
      case RegenerationLevel.intermediate:
        return 'Intermediate';
      case RegenerationLevel.advanced:
        return 'Advanced';
      case RegenerationLevel.expert:
        return 'Expert';
    }
  }

  String get description {
    switch (this) {
      case RegenerationLevel.beginner:
        return 'A lighter pace with stronger foundations and more introductory resources.';
      case RegenerationLevel.intermediate:
        return 'A balanced roadmap for learners with some prior exposure.';
      case RegenerationLevel.advanced:
        return 'A faster roadmap with deeper practice and more demanding resources.';
      case RegenerationLevel.expert:
        return 'A highly accelerated roadmap focused on advanced depth and application.';
    }
  }

  String get mappedIntent {
    switch (this) {
      case RegenerationLevel.beginner:
        return 'simpler_basics';
      case RegenerationLevel.intermediate:
        return 'more_practical';
      case RegenerationLevel.advanced:
        return 'more_advanced';
      case RegenerationLevel.expert:
        return 'faster_progress';
    }
  }
}

class SkillUiModel {
  final String id;
  final String title;
  final SkillLevel? level;

  final int? skillId;
  final String status;
  final String requiredLevel;
  final bool isCore;
  final bool selected;
  final double gapScore;

  const SkillUiModel({
    required this.id,
    required this.title,
    this.level,
    this.skillId,
    this.status = '',
    this.requiredLevel = 'beginner',
    this.isCore = false,
    this.selected = true,
    this.gapScore = 0,
  });

  SkillUiModel copyWith({
    String? id,
    String? title,
    SkillLevel? level,
    bool clearLevel = false,
    int? skillId,
    String? status,
    String? requiredLevel,
    bool? isCore,
    bool? selected,
    double? gapScore,
  }) {
    return SkillUiModel(
      id: id ?? this.id,
      title: title ?? this.title,
      level: clearLevel ? null : (level ?? this.level),
      skillId: skillId ?? this.skillId,
      status: status ?? this.status,
      requiredLevel: requiredLevel ?? this.requiredLevel,
      isCore: isCore ?? this.isCore,
      selected: selected ?? this.selected,
      gapScore: gapScore ?? this.gapScore,
    );
  }
}

/// ----------------------------
/// STATE
/// ----------------------------

class CareerBuildState {
  final List<CareerPlanUiModel> plans;

  // Backend
  final List<CareerTrackModel> tracks;
  final CareerTrackModel? selectedTrack;
  final PlatformFile? cvPlatformFile;
  final CareerAnalysisModel? analysis;
  final CareerTimeResponseModel? timePreview;
  final CareerTimeResponseModel? confirmedTime;
  final CareerPlanModel? backendPlan;
  final SavePlanResponseModel? saveResponse;
  final List<RegenerationIntentModel> regenerationIntents;
  final List<String> selectedRegenerationIntentValues;

  // Loading
  final bool isTracksLoading;
  final bool isAnalyzeLoading;
  final bool isConfirmSkillsLoading;
  final bool isGenerating;
  final bool isSaving;
  final String? backendError;
  final String? successMessage;

  // Wizard
  final int currentStep;

  // Step-1
  final String trackInput;

  // CV
  final String? cvFileName;
  final String? cvFilePath;

  // Step-2
  final List<String> missingSkills;
  final List<SkillUiModel> userSkills;

  // Step-3
  final bool isTimelineLoading;
  final String? timelineError;
  final int? suggestedWeeks;
  final int? suggestedMonths;
  final int weeks;
  final int months;

  // weekly study hours + feedback
  final int weeklyStudyHours;
  final String? timelineFeedbackTitle;
  final String? timelineFeedbackMessage;
  final String? timelineFeedbackHint;
  final Color? timelineFeedbackColor;
  final IconData? timelineFeedbackIcon;
  final String? hoursFeedbackTitle;
  final String? hoursFeedbackMessage;
  final String? hoursFeedbackHint;
  final Color? hoursFeedbackColor;
  final IconData? hoursFeedbackIcon;

  // Step-4 regenerate
  final RegenerationLevel? selectedRegenerationLevel;
  final bool isRegenerationLoading;
  final String? regenerationError;
  final List<PlanWeekUiModel> regeneratedPreviewRoadmap;

  const CareerBuildState({
    this.plans = const [],
    this.tracks = const [],
    this.selectedTrack,
    this.cvPlatformFile,
    this.analysis,
    this.timePreview,
    this.confirmedTime,
    this.backendPlan,
    this.saveResponse,
    this.regenerationIntents = const [],
    this.selectedRegenerationIntentValues = const [],
    this.isTracksLoading = false,
    this.isAnalyzeLoading = false,
    this.isConfirmSkillsLoading = false,
    this.isGenerating = false,
    this.isSaving = false,
    this.backendError,
    this.successMessage,
    this.currentStep = 1,
    this.trackInput = '',
    this.cvFileName,
    this.cvFilePath,
    this.missingSkills = const [],
    this.userSkills = const [],
    this.isTimelineLoading = false,
    this.timelineError,
    this.suggestedWeeks,
    this.suggestedMonths,
    this.weeks = 6,
    this.months = 0,
    this.weeklyStudyHours = 6,
    this.timelineFeedbackTitle,
    this.timelineFeedbackMessage,
    this.timelineFeedbackHint,
    this.timelineFeedbackColor,
    this.timelineFeedbackIcon,
    this.hoursFeedbackTitle,
    this.hoursFeedbackMessage,
    this.hoursFeedbackHint,
    this.hoursFeedbackColor,
    this.hoursFeedbackIcon,
    this.selectedRegenerationLevel,
    this.isRegenerationLoading = false,
    this.regenerationError,
    this.regeneratedPreviewRoadmap = const [],
  });

  bool get hasPlans => plans.isNotEmpty;

  bool get fitHasWarnings =>
      (analysis?.fitAnalysis?.warnings ?? const []).isNotEmpty ||
      (analysis?.fitAnalysis?.missingCoreSkills ?? const []).isNotEmpty;

  List<String> get fitWarnings => analysis?.fitAnalysis?.warnings ?? const [];

  List<String> get missingCoreSkillNames =>
      analysis?.fitAnalysis?.missingCoreSkills ?? const [];

  bool get canGeneratePlanFromFit =>
      analysis?.fitAnalysis?.canGeneratePlan ?? true;

  String get fitStatus => analysis?.fitAnalysis?.fitStatus ?? '';

  double get fitScore => analysis?.fitAnalysis?.fitScore ?? 0;

  bool get timelineChanged {
    final baseWeeks = suggestedWeeks ?? 6;
    return weeks != baseWeeks;
  }

  bool get hasRegeneratedPreview => regeneratedPreviewRoadmap.isNotEmpty;

  bool get hasBackendPlan => backendPlan != null;

  bool get isBusy =>
      isTracksLoading ||
      isAnalyzeLoading ||
      isConfirmSkillsLoading ||
      isTimelineLoading ||
      isGenerating ||
      isRegenerationLoading ||
      isSaving;

  int get totalRequestedWeeks => weeks;

  CareerBuildState copyWith({
    List<CareerPlanUiModel>? plans,
    List<CareerTrackModel>? tracks,
    CareerTrackModel? selectedTrack,
    bool clearSelectedTrack = false,
    PlatformFile? cvPlatformFile,
    bool clearCvPlatformFile = false,
    CareerAnalysisModel? analysis,
    bool clearAnalysis = false,
    CareerTimeResponseModel? timePreview,
    bool clearTimePreview = false,
    CareerTimeResponseModel? confirmedTime,
    bool clearConfirmedTime = false,
    CareerPlanModel? backendPlan,
    bool clearBackendPlan = false,
    SavePlanResponseModel? saveResponse,
    bool clearSaveResponse = false,
    List<RegenerationIntentModel>? regenerationIntents,
    List<String>? selectedRegenerationIntentValues,
    bool clearSelectedRegenerationIntentValues = false,
    bool? isTracksLoading,
    bool? isAnalyzeLoading,
    bool? isConfirmSkillsLoading,
    bool? isGenerating,
    bool? isSaving,
    String? backendError,
    bool clearBackendError = false,
    String? successMessage,
    bool clearSuccessMessage = false,
    int? currentStep,
    String? trackInput,
    String? cvFileName,
    String? cvFilePath,
    bool clearCv = false,
    List<String>? missingSkills,
    List<SkillUiModel>? userSkills,
    bool? isTimelineLoading,
    String? timelineError,
    int? suggestedWeeks,
    int? suggestedMonths,
    int? weeks,
    int? months,
    int? weeklyStudyHours,
    String? timelineFeedbackTitle,
    String? timelineFeedbackMessage,
    String? timelineFeedbackHint,
    Color? timelineFeedbackColor,
    IconData? timelineFeedbackIcon,
    String? hoursFeedbackTitle,
    String? hoursFeedbackMessage,
    String? hoursFeedbackHint,
    Color? hoursFeedbackColor,
    IconData? hoursFeedbackIcon,
    bool clearTimelineFeedback = false,
    bool clearHoursFeedback = false,
    bool clearTimelineError = false,
    RegenerationLevel? selectedRegenerationLevel,
    bool preserveSelectedRegenerationLevel = true,
    bool? isRegenerationLoading,
    String? regenerationError,
    bool clearRegenerationError = false,
    List<PlanWeekUiModel>? regeneratedPreviewRoadmap,
    bool clearRegeneratedPreviewRoadmap = false,
  }) {
    return CareerBuildState(
      plans: plans ?? this.plans,
      tracks: tracks ?? this.tracks,
      selectedTrack:
          clearSelectedTrack ? null : (selectedTrack ?? this.selectedTrack),
      cvPlatformFile:
          clearCvPlatformFile ? null : (cvPlatformFile ?? this.cvPlatformFile),
      analysis: clearAnalysis ? null : (analysis ?? this.analysis),
      timePreview: clearTimePreview ? null : (timePreview ?? this.timePreview),
      confirmedTime:
          clearConfirmedTime ? null : (confirmedTime ?? this.confirmedTime),
      backendPlan: clearBackendPlan ? null : (backendPlan ?? this.backendPlan),
      saveResponse:
          clearSaveResponse ? null : (saveResponse ?? this.saveResponse),
      regenerationIntents: regenerationIntents ?? this.regenerationIntents,
      selectedRegenerationIntentValues: clearSelectedRegenerationIntentValues
          ? const []
          : (selectedRegenerationIntentValues ??
              this.selectedRegenerationIntentValues),
      isTracksLoading: isTracksLoading ?? this.isTracksLoading,
      isAnalyzeLoading: isAnalyzeLoading ?? this.isAnalyzeLoading,
      isConfirmSkillsLoading:
          isConfirmSkillsLoading ?? this.isConfirmSkillsLoading,
      isGenerating: isGenerating ?? this.isGenerating,
      isSaving: isSaving ?? this.isSaving,
      backendError:
          clearBackendError ? null : (backendError ?? this.backendError),
      successMessage:
          clearSuccessMessage ? null : (successMessage ?? this.successMessage),
      currentStep: currentStep ?? this.currentStep,
      trackInput: trackInput ?? this.trackInput,
      cvFileName: clearCv ? null : (cvFileName ?? this.cvFileName),
      cvFilePath: clearCv ? null : (cvFilePath ?? this.cvFilePath),
      missingSkills: missingSkills ?? this.missingSkills,
      userSkills: userSkills ?? this.userSkills,
      isTimelineLoading: isTimelineLoading ?? this.isTimelineLoading,
      timelineError:
          clearTimelineError ? null : (timelineError ?? this.timelineError),
      suggestedWeeks: suggestedWeeks ?? this.suggestedWeeks,
      suggestedMonths: suggestedMonths ?? this.suggestedMonths,
      weeks: weeks ?? this.weeks,
      months: months ?? this.months,
      weeklyStudyHours: weeklyStudyHours ?? this.weeklyStudyHours,
      timelineFeedbackTitle: clearTimelineFeedback
          ? null
          : (timelineFeedbackTitle ?? this.timelineFeedbackTitle),
      timelineFeedbackMessage: clearTimelineFeedback
          ? null
          : (timelineFeedbackMessage ?? this.timelineFeedbackMessage),
      timelineFeedbackHint: clearTimelineFeedback
          ? null
          : (timelineFeedbackHint ?? this.timelineFeedbackHint),
      timelineFeedbackColor: clearTimelineFeedback
          ? null
          : (timelineFeedbackColor ?? this.timelineFeedbackColor),
      timelineFeedbackIcon: clearTimelineFeedback
          ? null
          : (timelineFeedbackIcon ?? this.timelineFeedbackIcon),
      hoursFeedbackTitle: clearHoursFeedback
          ? null
          : (hoursFeedbackTitle ?? this.hoursFeedbackTitle),
      hoursFeedbackMessage: clearHoursFeedback
          ? null
          : (hoursFeedbackMessage ?? this.hoursFeedbackMessage),
      hoursFeedbackHint: clearHoursFeedback
          ? null
          : (hoursFeedbackHint ?? this.hoursFeedbackHint),
      hoursFeedbackColor: clearHoursFeedback
          ? null
          : (hoursFeedbackColor ?? this.hoursFeedbackColor),
      hoursFeedbackIcon: clearHoursFeedback
          ? null
          : (hoursFeedbackIcon ?? this.hoursFeedbackIcon),
      selectedRegenerationLevel: preserveSelectedRegenerationLevel
          ? (selectedRegenerationLevel ?? this.selectedRegenerationLevel)
          : selectedRegenerationLevel,
      isRegenerationLoading:
          isRegenerationLoading ?? this.isRegenerationLoading,
      regenerationError: clearRegenerationError
          ? null
          : (regenerationError ?? this.regenerationError),
      regeneratedPreviewRoadmap: clearRegeneratedPreviewRoadmap
          ? const []
          : (regeneratedPreviewRoadmap ?? this.regeneratedPreviewRoadmap),
    );
  }
}

/// ----------------------------
/// NOTIFIER
/// ----------------------------

class CareerBuildNotifier extends Notifier<CareerBuildState> {
  static const Set<String> _allowedRegenerationIntents = {
    'more_advanced',
    'more_practical',
    'less_repetition',
    'focus_selected_skills',
    'faster_progress',
    'simpler_basics',
  };

  List<String> _cleanRegenerationIntentValues(List<String> values) {
    return values
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .where(_allowedRegenerationIntents.contains)
        .toSet()
        .toList();
  }

  final CareerBuildRepositoryImpl _repo = CareerBuildRepositoryImpl();
  final CareerBuildCacheService _cache = CareerBuildCacheService();
  Timer? _timelineValidationDebounce;

  @override
  CareerBuildState build() {
    ref.onDispose(() {
      _timelineValidationDebounce?.cancel();
    });

    Future.microtask(() async {
      await loadCachedPlans();
      await loadTracks(force: true);
      await loadRegenerationIntents();
    });

    return const CareerBuildState(plans: []);
  }

  // ----------------------------
  // Backend loading
  // ----------------------------

  Future<void> loadTracks({bool force = false}) async {
    if (state.isTracksLoading) return;

    // لو التراكات موجودة بالفعل، متعمليش request جديد إلا لو الصفحة طلبت force.
    // ده مهم عشان Step 1 يقدر يعمل reload لو القائمة فاضية أو حصل refresh.
    if (!force && state.tracks.isNotEmpty) return;

    state = state.copyWith(
      isTracksLoading: true,
      clearBackendError: true,
    );

    try {
      final tracks = await _repo.getTracks();

      state = state.copyWith(
        tracks: tracks,
        isTracksLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isTracksLoading: false,
        backendError: _cleanError(e),
      );
    }
  }

  Future<void> loadRegenerationIntents() async {
    try {
      final intents = await _repo.getRegenerationIntents();

      // The UI endpoint may return more labels, but /regenerate-plan accepts
      // only the enum values supported by the backend request schema.
      final safeIntents = intents
          .where((intent) =>
              _allowedRegenerationIntents.contains(intent.value.trim()))
          .toList();

      state = state.copyWith(regenerationIntents: safeIntents);
    } catch (e) {
      state = state.copyWith(backendError: _cleanError(e));
    }
  }

  Future<void> loadCachedPlans() async {
    final cached = await _cache.getSavedPlans();

    final plans = cached.map((json) {
      final backendJson = Map<String, dynamic>.from(json['backend_plan'] ?? {});
      CareerPlanModel? backend;

      if (backendJson.isNotEmpty) {
        try {
          backend = CareerPlanModel.fromJson(backendJson);
        } catch (_) {
          backend = null;
        }
      }

      if (backend != null) {
        return _planUiFromBackend(
          backend,
          id: json['local_id']?.toString(),
          isViewed: json['is_viewed'] == true,
          backendPlanId: json['plan_id'] is int ? json['plan_id'] : null,
          createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
        );
      }

      return CareerPlanUiModel(
        id: json['local_id']?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        title: json['title']?.toString() ?? 'Career Plan',
        isViewed: json['is_viewed'] == true,
        weeks: json['weeks'] is int ? json['weeks'] : 0,
        months: json['months'] is int ? json['months'] : 0,
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
            DateTime.now(),
      );
    }).toList();

    state = state.copyWith(plans: plans);
  }

  // ----------------------------
  // Plans
  // ----------------------------

  void seedMockPlans() {
    // Disabled after backend integration.
    // Keep method to avoid breaking old EntryScreen calls.
  }

  CareerPlanUiModel? getPlanById(String id) {
    try {
      return state.plans.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<bool> saveGeneratedPlan() async {
    final backendPlan = state.backendPlan;
    final analysis = state.analysis;

    if (backendPlan == null || analysis == null) {
      state = state.copyWith(
        backendError: 'No generated plan found to save.',
      );
      return false;
    }

    state = state.copyWith(
      isSaving: true,
      clearBackendError: true,
      clearSuccessMessage: true,
    );

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;

      if (userId == null || userId.trim().isEmpty) {
        throw Exception('User is not logged in.');
      }

      // Important:
      // Refresh confirmed skills before saving so the backend has the latest
      // selected required skills cached before /save-plan is called.
      await _refreshBackendCacheBeforeSave();

      final refreshedAnalysis = state.analysis ?? analysis;

      final saveResponse = await _repo.savePlan(
        userId: userId,
        cvId: refreshedAnalysis.cvId,
        trackId: refreshedAnalysis.trackId,
      );

      final localPlan = _planUiFromBackend(
        backendPlan,
        backendPlanId: saveResponse.planId,
        isViewed: false,
        createdAt: DateTime.tryParse(saveResponse.createdAt),
      );

      final updated = [localPlan, ...state.plans];

      state = state.copyWith(
        plans: updated,
        saveResponse: saveResponse,
        isSaving: false,
        successMessage: saveResponse.message.isEmpty
            ? 'Plan saved successfully'
            : saveResponse.message,
      );

      await _cache.addSavedPlan({
        'local_id': localPlan.id,
        'plan_id': saveResponse.planId,
        'title': localPlan.title,
        'weeks': localPlan.weeks,
        'months': 0,
        'created_at': localPlan.createdAt.toIso8601String(),
        'is_viewed': localPlan.isViewed,
        'backend_plan': backendPlan.toJson(),
      });

      return true;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        backendError: _cleanError(e),
      );
      return false;
    }
  }

  void createPlanFromWizard() {
    final backendPlan = state.backendPlan;

    if (backendPlan != null) {
      final localPlan = _planUiFromBackend(backendPlan);
      state = state.copyWith(plans: [localPlan, ...state.plans]);

      _cache.addSavedPlan({
        'local_id': localPlan.id,
        'title': localPlan.title,
        'weeks': localPlan.weeks,
        'months': localPlan.months,
        'created_at': localPlan.createdAt.toIso8601String(),
        'is_viewed': localPlan.isViewed,
        'backend_plan': backendPlan.toJson(),
      });

      return;
    }

    final title = state.trackInput.trim().isEmpty
        ? 'Career Plan'
        : state.trackInput.trim();

    final skills = _deriveSkillsIncluded();

    final newPlan = CareerPlanUiModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      isViewed: false,
      skillsIncluded: skills,
      weeks: state.totalRequestedWeeks,
      months: 0,
      createdAt: DateTime.now(),
      roadmap: getPreviewRoadmap(),
    );

    state = state.copyWith(plans: [newPlan, ...state.plans]);
  }

  List<String> _deriveSkillsIncluded() {
    if (state.backendPlan != null) {
      final backendSkills = state.backendPlan!.usedLearningTargets
          .map((e) => e['skill_name']?.toString() ?? '')
          .where((e) => e.trim().isNotEmpty)
          .toList();

      if (backendSkills.isNotEmpty) {
        return backendSkills.take(3).toList();
      }
    }

    final fromMissing =
        state.missingSkills.where((e) => e.trim().isNotEmpty).toList();

    final fromUser = state.userSkills
        .map((e) => e.title)
        .where((e) => e.trim().isNotEmpty)
        .toList();

    final merged = <String>[];
    for (final s in [...fromUser, ...fromMissing]) {
      if (!merged.contains(s)) merged.add(s);
      if (merged.length == 3) break;
    }

    return merged;
  }

  void markPlanViewed(String id) {
    final updated = state.plans
        .map((p) => p.id == id ? p.copyWith(isViewed: true) : p)
        .toList();

    state = state.copyWith(plans: updated);
  }

  CareerPlanUiModel? deletePlanOptimistic(String id) {
    CareerPlanUiModel? removed;
    final updated = <CareerPlanUiModel>[];

    for (final p in state.plans) {
      if (p.id == id) {
        removed = p;
      } else {
        updated.add(p);
      }
    }

    state = state.copyWith(plans: updated);
    _cache.deleteSavedPlan(id);

    return removed;
  }

  void undoDelete(CareerPlanUiModel plan) {
    state = state.copyWith(plans: [plan, ...state.plans]);
  }

  // ----------------------------
  // Wizard Step 1
  // ----------------------------

  void setStep(int step) => state = state.copyWith(currentStep: step);

  void commitTrack(String raw) {
    final text = raw.trim();

    CareerTrackModel? matched;
    for (final track in state.tracks) {
      if (track.trackName.toLowerCase() == text.toLowerCase()) {
        matched = track;
        break;
      }
    }

    state = state.copyWith(
      trackInput: text,
      selectedTrack: matched,
      clearAnalysis: true,
      clearTimePreview: true,
      clearConfirmedTime: true,
      clearBackendPlan: true,
      clearRegeneratedPreviewRoadmap: true,
      clearRegenerationError: true,
      clearBackendError: true,
      selectedRegenerationLevel: null,
      preserveSelectedRegenerationLevel: false,
      clearSelectedRegenerationIntentValues: true,
    );
  }

  void selectTrack(CareerTrackModel track) {
    state = state.copyWith(
      selectedTrack: track,
      trackInput: track.trackName,
      clearAnalysis: true,
      clearTimePreview: true,
      clearConfirmedTime: true,
      clearBackendPlan: true,
      clearRegeneratedPreviewRoadmap: true,
      clearRegenerationError: true,
      clearBackendError: true,
      clearSelectedRegenerationIntentValues: true,
    );
  }

  void setCvPlatformFile(PlatformFile file) {
    state = state.copyWith(
      cvPlatformFile: file,
      cvFileName: file.name,
      cvFilePath: file.path,
      clearAnalysis: true,
      clearTimePreview: true,
      clearConfirmedTime: true,
      clearBackendPlan: true,
      clearBackendError: true,
    );
  }

  void setCvFile({required String name, required String path}) {
    state = state.copyWith(
      cvFileName: name,
      cvFilePath: path,
      clearAnalysis: true,
      clearTimePreview: true,
      clearConfirmedTime: true,
      clearBackendPlan: true,
      clearBackendError: true,
    );
  }

  void clearCv() {
    state = state.copyWith(
      clearCv: true,
      clearCvPlatformFile: true,
      clearAnalysis: true,
      clearTimePreview: true,
      clearConfirmedTime: true,
      clearBackendPlan: true,
      missingSkills: const [],
      userSkills: const [],
    );
  }

  Future<bool> analyzeCvAndGoNext() async {
    final selectedTrack = state.selectedTrack;
    final file = state.cvPlatformFile;

    if (selectedTrack == null) {
      state = state.copyWith(backendError: 'Please select a career track.');
      return false;
    }

    if (file == null) {
      state = state.copyWith(backendError: 'Please upload your CV first.');
      return false;
    }

    state = state.copyWith(
      isAnalyzeLoading: true,
      clearBackendError: true,
      clearSuccessMessage: true,
    );

    try {
      final analysis = await _repo.analyzeCv(
        cvFile: file,
        trackId: selectedTrack.trackId,
      );

      var userSkills = _buildStep2SkillsFromAnalysis(analysis);
      userSkills = _ensureAtLeastOneCurrentSkillSelected(userSkills);

      final selectedIds = userSkills
          .where((s) => s.selected)
          .map((s) => s.skillId)
          .whereType<int>()
          .where((id) => id > 0)
          .toList();

      if (selectedIds.isEmpty && userSkills.isNotEmpty) {
        final firstSelectable = userSkills
            .where((s) => s.status == 'missing' || s.status == 'partial')
            .map((s) => s.skillId)
            .whereType<int>()
            .where((id) => id > 0)
            .take(3)
            .toList();

        userSkills = userSkills
            .map((s) => firstSelectable.contains(s.skillId)
                ? s.copyWith(selected: true)
                : s)
            .toList();
      }

      state = state.copyWith(
        isAnalyzeLoading: false,
        analysis: analysis,
        missingSkills: userSkills
            .where((s) => s.status == 'missing' || s.status == 'partial')
            .map((e) => e.title)
            .toList(),
        userSkills: userSkills,
        currentStep: 2,
        selectedRegenerationIntentValues: const [],
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isAnalyzeLoading: false,
        backendError: _cleanError(e),
      );
      return false;
    }
  }

  // ----------------------------
  // Wizard Step 2
  // ----------------------------

  void seedMockStep2Data() {
    // Disabled after backend integration.
    // Method kept to avoid breaking old screen calls.
  }

  void toggleSkillSelection(String skillId) {
    final updated = state.userSkills.map((s) {
      if (s.id != skillId) return s;
      return s.copyWith(selected: !s.selected);
    }).toList();

    state = state.copyWith(
      userSkills: updated,
      clearRegeneratedPreviewRoadmap: true,
      clearRegenerationError: true,
      clearBackendPlan: true,
      clearSelectedRegenerationIntentValues: true,
    );
  }

  void setSkillLevel({required String skillId, required SkillLevel level}) {
    final updated = state.userSkills
        .map((s) => s.id == skillId ? s.copyWith(level: level) : s)
        .toList();

    state = state.copyWith(
      userSkills: updated,
      clearRegeneratedPreviewRoadmap: true,
      clearRegenerationError: true,
      clearBackendPlan: true,
      selectedRegenerationLevel: null,
      preserveSelectedRegenerationLevel: false,
      clearSelectedRegenerationIntentValues: true,
    );
  }

  Future<bool> confirmSkillsAndGoNext() async {
    final analysis = state.analysis;

    if (analysis == null) {
      state = state.copyWith(
        backendError: 'CV analysis is missing. Please analyze your CV again.',
      );
      return false;
    }

    final workingSkills =
        _ensureAtLeastOneCurrentSkillSelected(state.userSkills);
    final selectedSkillIds = _selectedSkillIdsForBackend(workingSkills);

    if (selectedSkillIds.isEmpty) {
      state = state.copyWith(
        backendError: 'Please select at least one skill to build your plan.',
      );
      return false;
    }

    // Backend rule:
    // selected_skill_ids = skills the user wants included in the learning plan.
    // skill_overrides = current/analyzed skills only.
    // Do not send overrides for missing/partial skills, otherwise the backend may
    // recalculate them as existing "has" skills.
    // Also do not send level none for current skills because save-plan rejects
    // confirmed_level=none.
    final skillOverrides = _skillOverridesForBackend(workingSkills);

    state = state.copyWith(
      userSkills: workingSkills,
      isConfirmSkillsLoading: true,
      clearBackendError: true,
    );

    try {
      final confirmed = await _repo.confirmSkills(
        cvId: analysis.cvId,
        trackId: analysis.trackId,
        selectedSkillIds: selectedSkillIds,
        skillOverrides: skillOverrides,
      );

      final reviewableSkills = confirmed.reviewableSkills.isNotEmpty
          ? confirmed.reviewableSkills
          : [
              ...confirmed.recommendedSkills,
              ...confirmed.ownedSkills,
            ];

      final updatedUserSkills = _ensureAtLeastOneCurrentSkillSelected(
        _buildStep2SkillsFromAnalysis(
          confirmed,
          preserveSkills: state.userSkills,
        ),
      );

      state = state.copyWith(
        isConfirmSkillsLoading: false,
        analysis: confirmed,
        userSkills: updatedUserSkills,
        missingSkills: updatedUserSkills
            .where((s) => s.status == 'missing' || s.status == 'partial')
            .map((e) => e.title)
            .toList(),
        currentStep: 3,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isConfirmSkillsLoading: false,
        backendError: _cleanError(e),
      );
      return false;
    }
  }

  // ----------------------------
  // Step-3 Timeline logic
  // ----------------------------

  Future<void> fetchSuggestedTimelineOnce() async {
    if (state.isTimelineLoading) return;
    if (state.timePreview != null) return;

    final analysis = state.analysis;
    if (analysis == null) return;

    state = state.copyWith(
      isTimelineLoading: true,
      clearTimelineError: true,
      clearBackendError: true,
    );

    try {
      final preview = await _repo.confirmTimePreview(
        cvId: analysis.cvId,
        trackId: analysis.trackId,
      );

      final guidance = preview.timeGuidance;
      final suitableWeeks = guidance?.suitableWeeks ?? 6;
      final defaultHours =
          preview.availableHoursPerWeek > 0 ? preview.availableHoursPerWeek : 6;

      state = state.copyWith(
        isTimelineLoading: false,
        timePreview: preview,
        suggestedWeeks: suitableWeeks,
        suggestedMonths: 0,
        weeks: suitableWeeks,
        months: 0,
        weeklyStudyHours: defaultHours,
        clearTimelineFeedback: true,
      );

      _evaluateTimelineFeedback();
      _evaluateHours();
    } catch (e) {
      state = state.copyWith(
        isTimelineLoading: false,
        timelineError: _cleanError(e),
      );
    }
  }

  int _clampMin1(int v) => v < 1 ? 1 : v;
  int _clampMin0(int v) => v < 0 ? 0 : v;

  void setWeeks(int v) {
    state = state.copyWith(
      weeks: _clampMin1(v),
      months: 0,
      clearRegeneratedPreviewRoadmap: true,
      clearRegenerationError: true,
      clearBackendPlan: true,
      clearConfirmedTime: true,
      clearTimelineFeedback: true,
      clearBackendError: true,
      clearTimelineError: true,
    );

    _scheduleTimeValidation();
  }

  void setMonths(int v) {
    // Months are no longer part of the backend timeline flow.
    state = state.copyWith(months: 0);
  }

  void setWeeklyStudyHours(int v) {
    state = state.copyWith(
      weeklyStudyHours: _clampMin1(v),
      months: 0,
      clearRegeneratedPreviewRoadmap: true,
      clearRegenerationError: true,
      clearBackendPlan: true,
      clearConfirmedTime: true,
      clearTimelineFeedback: true,
      clearBackendError: true,
      clearTimelineError: true,
    );

    _evaluateHours();
    _scheduleTimeValidation();
  }

  void incWeeks() => setWeeks(state.weeks + 1);
  void decWeeks() => setWeeks(state.weeks - 1);

  void incMonths() => setMonths(0);
  void decMonths() => setMonths(0);

  void incWeeklyStudyHours() => setWeeklyStudyHours(state.weeklyStudyHours + 1);
  void decWeeklyStudyHours() => setWeeklyStudyHours(state.weeklyStudyHours - 1);

  void resetTimelineToSuggested() {
    final sw = state.suggestedWeeks ?? 6;
    final defaultHours = state.timePreview?.availableHoursPerWeek ?? 6;

    state = state.copyWith(
      weeks: sw,
      months: 0,
      weeklyStudyHours: defaultHours,
      clearRegeneratedPreviewRoadmap: true,
      clearRegenerationError: true,
      clearBackendPlan: true,
      clearBackendError: true,
      clearTimelineError: true,
    );

    _evaluateHours();
    _scheduleTimeValidation();
  }

  Future<bool> confirmTimeOnly({bool showLoading = true}) async {
    final analysis = state.analysis;

    if (analysis == null) {
      state = state.copyWith(
        backendError:
            'Skill confirmation is missing. Please go back and confirm skills.',
      );
      return false;
    }

    final requestedWeeks = state.totalRequestedWeeks;

    if (showLoading) {
      state = state.copyWith(
        isTimelineLoading: true,
        clearTimelineError: true,
        clearBackendError: true,
      );
    } else {
      state = state.copyWith(
        clearTimelineError: true,
        clearBackendError: true,
      );
    }

    try {
      final confirmed = await _repo.confirmTime(
        cvId: analysis.cvId,
        trackId: analysis.trackId,
        requestedWeeks: requestedWeeks,
        availableHoursPerWeek: state.weeklyStudyHours,
      );

      final confirmedGuidance = confirmed.timeGuidance;

      state = state.copyWith(
        isTimelineLoading: false,
        confirmedTime: confirmed,
        suggestedWeeks:
            confirmedGuidance?.suitableWeeks ?? state.suggestedWeeks,
        suggestedMonths: 0,
        months: 0,
      );

      _applyRealismFeedback(confirmed);
      _evaluateHours();

      return true;
    } catch (e) {
      state = state.copyWith(
        isTimelineLoading: false,
        timelineError: _cleanError(e),
      );
      return false;
    }
  }

  Future<bool> generatePlanFromTimeline() async {
    final analysis = state.analysis;

    if (analysis == null) {
      state = state.copyWith(
        backendError: 'CV analysis is missing. Please start again.',
      );
      return false;
    }

    final timeOk = await confirmTimeOnly();
    if (!timeOk) return false;

    state = state.copyWith(
      isGenerating: true,
      clearBackendError: true,
      clearSuccessMessage: true,
      clearRegeneratedPreviewRoadmap: true,
      clearSelectedRegenerationIntentValues: true,
    );

    try {
      final plan = await _repo.generatePlan(
        cvId: analysis.cvId,
        trackId: analysis.trackId,
        durationWeeks: state.totalRequestedWeeks,
        availableHoursPerWeek: state.weeklyStudyHours,
      );

      final roadmap = _mapBackendWeeksToUi(plan);
      await _cache.saveLatestPlan(plan.toJson());

      state = state.copyWith(
        isGenerating: false,
        backendPlan: plan,
        regeneratedPreviewRoadmap: roadmap,
        currentStep: 4,
        successMessage: 'Your career plan is ready.',
      );

      await AppNotificationService.instance.showCareerPlanGenerated();

      await AlertsStore.instance.addCareerPlanAlert(
        planTitle: plan.trackName.isEmpty ? 'Career Plan' : plan.trackName,
        planId: DateTime.now().millisecondsSinceEpoch.toString(),
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isGenerating: false,
        backendError: _cleanError(e),
      );
      return false;
    }
  }

  void _scheduleTimeValidation() {
    final analysis = state.analysis;
    if (analysis == null ||
        state.isGenerating ||
        state.isConfirmSkillsLoading) {
      return;
    }

    _timelineValidationDebounce?.cancel();
    _timelineValidationDebounce = Timer(const Duration(milliseconds: 650), () {
      confirmTimeOnly(showLoading: false);
    });
  }

  void _evaluateTimelineFeedback() {
    final guidance =
        state.confirmedTime?.timeGuidance ?? state.timePreview?.timeGuidance;
    final totalWeeks = state.totalRequestedWeeks;

    if (guidance == null) {
      return;
    }

    if (totalWeeks < guidance.minimumWeeks) {
      state = state.copyWith(
        timelineFeedbackTitle: 'Time Is Too Short',
        timelineFeedbackMessage:
            'The selected duration may be too short for your goal.',
        timelineFeedbackHint:
            'Try at least ${guidance.minimumWeeks} weeks, or reduce your selected skills.',
        timelineFeedbackColor: const Color(0xFFFF4D4F),
        timelineFeedbackIcon: Icons.close_rounded,
      );
    } else if (totalWeeks < guidance.suitableWeeks) {
      state = state.copyWith(
        timelineFeedbackTitle: 'Tight Timeline',
        timelineFeedbackMessage:
            'This timeline is possible, but it may feel intensive.',
        timelineFeedbackHint:
            'The recommended duration is around ${guidance.suitableWeeks} weeks.',
        timelineFeedbackColor: const Color(0xFFF4C430),
        timelineFeedbackIcon: Icons.warning_amber_rounded,
      );
    } else if (totalWeeks <= guidance.maximumWeeks) {
      state = state.copyWith(
        timelineFeedbackTitle: 'Good Time Range',
        timelineFeedbackMessage: 'Your selected duration looks reasonable.',
        timelineFeedbackHint: 'This should support a balanced study plan.',
        timelineFeedbackColor: const Color(0xFF22C55E),
        timelineFeedbackIcon: Icons.check_circle_rounded,
      );
    } else {
      state = state.copyWith(
        timelineFeedbackTitle: 'Flexible Timeline',
        timelineFeedbackMessage:
            'You’ve selected more time than the minimum needed.',
        timelineFeedbackHint:
            'This gives more room for deeper learning and practice.',
        timelineFeedbackColor: const Color(0xFF2196F3),
        timelineFeedbackIcon: Icons.info_rounded,
      );
    }
  }

  void _applyRealismFeedback(CareerTimeResponseModel confirmed) {
    final realism = confirmed.realism;
    if (realism == null) {
      _evaluateTimelineFeedback();
      return;
    }

    final warnings = realism.warnings;
    final suggestions = realism.suggestions;
    final zone = realism.zone.toLowerCase().trim();

    late Color color;
    late IconData icon;
    late String title;
    late String defaultMessage;
    late String defaultHint;

    if (!realism.isRealistic ||
        zone == 'below_minimum' ||
        zone == 'too_short' ||
        realism.adjustment.toLowerCase().trim() == 'unrealistic_too_short') {
      color = const Color(0xFFFF4D4F);
      icon = Icons.close_rounded;
      title = 'Time Is Too Short';
      defaultMessage = 'The selected duration may be too short for your goal.';
      defaultHint = 'Try adding more weeks or reducing your selected skills.';
    } else if (zone == 'minimum' ||
        zone == 'tight' ||
        zone == 'very_tight' ||
        realism.adjustment.toLowerCase().contains('tight')) {
      color = const Color(0xFFF4C430);
      icon = Icons.warning_amber_rounded;
      title = 'Tight Timeline';
      defaultMessage = 'This timeline is possible, but it may feel intensive.';
      defaultHint =
          'You can continue, but the plan may focus on essentials first.';
    } else if (zone == 'suitable' || zone == 'recommended') {
      color = const Color(0xFF22C55E);
      icon = Icons.check_circle_rounded;
      title = 'Good Time Range';
      defaultMessage = 'Your selected duration looks reasonable.';
      defaultHint = 'This should support a balanced study plan.';
    } else {
      color = const Color(0xFF2196F3);
      icon = Icons.info_rounded;
      title = 'Flexible Timeline';
      defaultMessage = 'You’ve selected more time than the minimum needed.';
      defaultHint = 'This gives more room for deeper learning and practice.';
    }

    state = state.copyWith(
      timelineFeedbackTitle: title,
      timelineFeedbackMessage:
          warnings.isNotEmpty ? warnings.join('\n') : defaultMessage,
      timelineFeedbackHint:
          suggestions.isNotEmpty ? suggestions.join('\n') : defaultHint,
      timelineFeedbackColor: color,
      timelineFeedbackIcon: icon,
    );
  }

  void _evaluateHours() {
    final h = state.weeklyStudyHours;

    if (h <= 5) {
      state = state.copyWith(
        hoursFeedbackTitle: 'Limited Weekly Time',
        hoursFeedbackMessage: 'Your weekly study time is quite limited.',
        hoursFeedbackHint:
            'Make sure your sessions are focused and consistent.',
        hoursFeedbackColor: const Color(0xFFF4C430),
        hoursFeedbackIcon: Icons.warning_amber_rounded,
      );
    } else if (h >= 20) {
      state = state.copyWith(
        hoursFeedbackTitle: 'Strong Weekly Availability',
        hoursFeedbackMessage:
            'You have enough weekly time for steady progress.',
        hoursFeedbackHint:
            'This can support deeper learning and faster growth.',
        hoursFeedbackColor: const Color(0xFF22C55E),
        hoursFeedbackIcon: Icons.fitness_center_rounded,
      );
    } else {
      state = state.copyWith(clearHoursFeedback: true);
    }
  }

  // ----------------------------
  // Step-4 regenerate logic
  // ----------------------------

  void selectRegenerationLevel(RegenerationLevel level) {
    final cleaned = _cleanRegenerationIntentValues([level.mappedIntent]);

    state = state.copyWith(
      selectedRegenerationLevel: level,
      selectedRegenerationIntentValues: cleaned,
      clearRegenerationError: true,
    );
  }

  void setRegenerationIntents(List<String> values) {
    state = state.copyWith(
      selectedRegenerationIntentValues: _cleanRegenerationIntentValues(values),
      clearRegenerationError: true,
    );
  }

  void toggleRegenerationIntent(String value) {
    final cleanValue = value.trim();
    if (!_allowedRegenerationIntents.contains(cleanValue)) return;

    final current = [...state.selectedRegenerationIntentValues];

    if (current.contains(cleanValue)) {
      current.remove(cleanValue);
    } else {
      current.add(cleanValue);
    }

    state = state.copyWith(
      selectedRegenerationIntentValues: _cleanRegenerationIntentValues(current),
      clearRegenerationError: true,
    );
  }

  void clearRegenerationSelection() {
    state = state.copyWith(
      selectedRegenerationLevel: null,
      preserveSelectedRegenerationLevel: false,
      clearRegenerationError: true,
      clearSelectedRegenerationIntentValues: true,
    );
  }

  Future<bool> regeneratePreviewPlan() async {
    final plan = state.backendPlan;
    final analysis = state.analysis;

    if (plan == null || analysis == null) {
      state = state.copyWith(
        regenerationError: 'Generate a plan first before regenerating it.',
      );
      return false;
    }

    final cleanFeedbackIntents = _cleanRegenerationIntentValues(
      state.selectedRegenerationIntentValues,
    );

    if (cleanFeedbackIntents.isEmpty) {
      state = state.copyWith(
        regenerationError: 'Please select a valid regeneration option.',
      );
      return false;
    }

    state = state.copyWith(
      isRegenerationLoading: true,
      clearRegenerationError: true,
      clearBackendError: true,
    );

    try {
      final regenerated = await _repo.regeneratePlan(
        cvId: analysis.cvId,
        trackId: analysis.trackId,
        previousPlan: plan.toJson(),
        feedbackIntents: cleanFeedbackIntents,
      );

      final roadmap = _mapBackendWeeksToUi(regenerated);
      await _cache.saveLatestPlan(regenerated.toJson());

      state = state.copyWith(
        isRegenerationLoading: false,
        backendPlan: regenerated,
        regeneratedPreviewRoadmap: roadmap,
        successMessage: 'Plan regenerated successfully.',
      );

      await AppNotificationService.instance.showCareerPlanRegenerated();

      await AlertsStore.instance.addCareerPlanRegeneratedAlert(
        planTitle: regenerated.trackName.isEmpty
            ? 'Career Plan'
            : regenerated.trackName,
        planId: DateTime.now().millisecondsSinceEpoch.toString(),
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isRegenerationLoading: false,
        regenerationError: _cleanError(e),
      );
      return false;
    }
  }

  Future<void> _refreshBackendCacheBeforeSave() async {
    final analysis = state.analysis;
    if (analysis == null) return;

    final workingSkills =
        _ensureAtLeastOneCurrentSkillSelected(state.userSkills);

    var selectedSkillIds = _selectedSkillIdsForBackend(workingSkills);

    // Extra frontend safety:
    // If selected ids are still empty, take any valid selected/current/gap skill.
    if (selectedSkillIds.isEmpty) {
      selectedSkillIds = workingSkills
          .where((s) {
            final id = s.skillId ?? 0;
            if (id <= 0) return false;

            final status = s.status.trim().toLowerCase();
            final isGap = status == 'missing' || status == 'partial';
            final isCurrent = status == 'has';

            return s.selected || isGap || isCurrent;
          })
          .map((s) => s.skillId)
          .whereType<int>()
          .where((id) => id > 0)
          .toSet()
          .toList();
    }

    if (selectedSkillIds.isEmpty) {
      throw Exception(
        'Please go back to Skills and select at least one required skill before saving.',
      );
    }

    final confirmedSkills = await _repo.confirmSkills(
      cvId: analysis.cvId,
      trackId: analysis.trackId,
      selectedSkillIds: selectedSkillIds,
      skillOverrides: _skillOverridesForBackend(workingSkills),
    );

    final updatedSkills = _ensureAtLeastOneCurrentSkillSelected(
      _buildStep2SkillsFromAnalysis(
        confirmedSkills,
        preserveSkills: workingSkills,
      ),
    );

    state = state.copyWith(
      analysis: confirmedSkills,
      userSkills: updatedSkills,
      missingSkills: updatedSkills
          .where((s) => s.status == 'missing' || s.status == 'partial')
          .map((e) => e.title)
          .toList(),
    );
  }

  // ----------------------------
  // Helpers
  // ----------------------------

  void resetWizard() {
    state = state.copyWith(
      currentStep: 1,
      trackInput: '',
      clearSelectedTrack: true,
      clearCv: true,
      clearCvPlatformFile: true,
      clearAnalysis: true,
      clearTimePreview: true,
      clearConfirmedTime: true,
      clearBackendPlan: true,
      clearSaveResponse: true,
      missingSkills: const [],
      userSkills: const [],
      isTimelineLoading: false,
      isAnalyzeLoading: false,
      isConfirmSkillsLoading: false,
      isGenerating: false,
      isSaving: false,
      timelineError: null,
      suggestedWeeks: null,
      suggestedMonths: null,
      weeks: 6,
      months: 0,
      weeklyStudyHours: 6,
      clearTimelineFeedback: true,
      clearHoursFeedback: true,
      clearTimelineError: true,
      isRegenerationLoading: false,
      clearRegenerationError: true,
      clearRegeneratedPreviewRoadmap: true,
      selectedRegenerationLevel: null,
      preserveSelectedRegenerationLevel: false,
      clearSelectedRegenerationIntentValues: true,
      clearBackendError: true,
      clearSuccessMessage: true,
    );
  }

  List<PlanWeekUiModel> getPreviewRoadmap() {
    if (state.regeneratedPreviewRoadmap.isNotEmpty) {
      return state.regeneratedPreviewRoadmap;
    }

    if (state.backendPlan != null) {
      return _mapBackendWeeksToUi(state.backendPlan!);
    }

    return const [];
  }

  bool _hasCurrentSelected(List<SkillUiModel> skills) {
    return skills.any(
      (s) =>
          s.status == 'has' &&
          s.selected &&
          s.skillId != null &&
          s.skillId! > 0,
    );
  }

  List<SkillUiModel> _ensureAtLeastOneCurrentSkillSelected(
    List<SkillUiModel> skills,
  ) {
    if (_hasCurrentSelected(skills)) return skills;

    final firstCurrentIndex = skills.indexWhere(
      (s) => s.status == 'has' && s.skillId != null && s.skillId! > 0,
    );

    if (firstCurrentIndex == -1) return skills;

    return [
      for (int i = 0; i < skills.length; i++)
        if (i == firstCurrentIndex)
          skills[i].copyWith(
            selected: true,
            level: skills[i].level == null || skills[i].level == SkillLevel.none
                ? (SkillLevelX.fromLabel(skills[i].requiredLevel) ??
                    SkillLevel.beginner)
                : skills[i].level,
          )
        else
          skills[i],
    ];
  }

  List<int> _selectedSkillIdsForBackend(List<SkillUiModel> skills) {
    return skills
        .where((s) {
          final id = s.skillId ?? 0;
          if (id <= 0) return false;

          final status = s.status.trim().toLowerCase();
          final isGap = status == 'missing' || status == 'partial';
          final isCurrent = status == 'has';

          // This matches the backend flow:
          // - selected gaps are learning targets.
          // - current CV skills must remain in the confirmed skill context,
          //   otherwise /confirm-time can cache level_used = none and /save-plan fails.
          return (s.selected && isGap) || isCurrent;
        })
        .map((s) => s.skillId)
        .whereType<int>()
        .where((id) => id > 0)
        .toSet()
        .toList();
  }

  List<Map<String, dynamic>> _skillOverridesForBackend(
    List<SkillUiModel> skills,
  ) {
    return skills
        .where((s) =>
            s.skillId != null &&
            s.skillId! > 0 &&
            s.status.trim().toLowerCase() == 'has')
        .map((s) {
      final levelValue = s.level?.backendValue;

      return {
        'skill_id': s.skillId,
        // /save-plan rejects confirmed_level=none. Current CV skills with
        // empty/none level are sent as beginner, matching backend fallback.
        'level': (levelValue == null || levelValue == 'none')
            ? 'beginner'
            : levelValue,
      };
    }).toList();
  }

  List<SkillUiModel> _buildStep2SkillsFromAnalysis(
    CareerAnalysisModel analysis, {
    List<SkillUiModel> preserveSkills = const [],
  }) {
    // Backend source of truth for status/current level is skill_gaps.
    // reviewable_skills is UI-friendly, but skill_gaps is more reliable for
    // deciding whether a skill is missing/partial/has.
    final gapById = <int, Map<String, dynamic>>{};

    for (final gap in analysis.skillGaps) {
      final id = int.tryParse((gap['skill_id'] ?? '').toString()) ?? 0;
      if (id > 0) {
        gapById[id] = gap;
      }
    }

    final backendSkills = analysis.reviewableSkills.isNotEmpty
        ? analysis.reviewableSkills
        : [
            ...analysis.recommendedSkills,
            ...analysis.ownedSkills,
          ];

    final previousById = <int, SkillUiModel>{
      for (final skill in preserveSkills)
        if (skill.skillId != null && skill.skillId! > 0) skill.skillId!: skill,
    };

    final previousByName = <String, SkillUiModel>{
      for (final skill in preserveSkills)
        _normalizeSkillName(skill.title): skill,
    };

    final result = <SkillUiModel>[];
    final seenIds = <int>{};
    final seenNames = <String>{};

    for (final backendSkill in backendSkills) {
      final gap = gapById[backendSkill.skillId];

      var mapped = gap == null
          ? _skillUiFromBackend(backendSkill)
          : _skillUiFromGap(gap, backendSkill: backendSkill);

      final previous = previousById[mapped.skillId] ??
          previousByName[_normalizeSkillName(mapped.title)];

      if (previous != null) {
        mapped = mapped.copyWith(
          selected: previous.selected,
          level: previous.level ?? mapped.level,
        );
      }

      final normalized = _normalizeSkillName(mapped.title);
      final id = mapped.skillId ?? 0;

      if (normalized.isEmpty) continue;
      if (id > 0 && seenIds.contains(id)) continue;
      if (seenNames.contains(normalized)) continue;

      result.add(mapped);
      if (id > 0) seenIds.add(id);
      seenNames.add(normalized);
    }

    // Safety: if backend returns a skill in skill_gaps but not in reviewable_skills,
    // still show it in Step 2 so the UI stays consistent with backend state.
    for (final gap in analysis.skillGaps) {
      final id = int.tryParse((gap['skill_id'] ?? '').toString()) ?? 0;
      final name = (gap['skill_name'] ?? '').toString();
      final normalized = _normalizeSkillName(name);

      if (id <= 0 || normalized.isEmpty) continue;
      if (seenIds.contains(id) || seenNames.contains(normalized)) continue;

      var mapped = _skillUiFromGap(gap);
      final previous = previousById[id] ?? previousByName[normalized];

      if (previous != null) {
        mapped = mapped.copyWith(
          selected: previous.selected,
          level: previous.level ?? mapped.level,
        );
      }

      result.add(mapped);
      seenIds.add(id);
      seenNames.add(normalized);
    }

    return result;
  }

  SkillUiModel _skillUiFromGap(
    Map<String, dynamic> gap, {
    CareerSkillModel? backendSkill,
  }) {
    final id = int.tryParse(
          (gap['skill_id'] ?? backendSkill?.skillId ?? 0).toString(),
        ) ??
        0;

    final name =
        (gap['skill_name'] ?? backendSkill?.skillName ?? '').toString();

    final status = (gap['status'] ?? backendSkill?.status ?? '')
        .toString()
        .trim()
        .toLowerCase();

    final requiredLevel =
        (gap['required_level'] ?? backendSkill?.requiredLevel ?? 'beginner')
            .toString();

    final currentLevel = (gap['current_level'] ??
            backendSkill?.currentLevel ??
            backendSkill?.detectedLevel ??
            'none')
        .toString();

    final isCoreRaw = gap['is_core'] ?? backendSkill?.isCore ?? false;
    final isCore = isCoreRaw == true ||
        isCoreRaw.toString().trim().toLowerCase() == 'true';

    final gapScore =
        double.tryParse((gap['gap_score'] ?? '0').toString()) ?? 0.0;

    final isGap = status == 'missing' || status == 'partial';
    final isCurrent = status == 'has';

    SkillLevel? level;
    if (isCurrent) {
      level = SkillLevelX.fromLabel(currentLevel) ??
          SkillLevelX.fromLabel(requiredLevel) ??
          SkillLevel.beginner;

      if (level == SkillLevel.none) {
        level = SkillLevel.beginner;
      }
    }

    return SkillUiModel(
      id: id.toString(),
      title: name,
      skillId: id,
      status: status,
      requiredLevel: requiredLevel,
      isCore: isCore,
      selected: isGap || isCurrent,
      gapScore: gapScore,
      level: level,
    );
  }

  String _normalizeSkillName(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  SkillUiModel _skillUiFromBackend(CareerSkillModel skill) {
    final status = skill.status.trim().toLowerCase();
    final isGap = status == 'missing' || status == 'partial';
    final isCurrent = status == 'has';

    SkillLevel? resolvedLevel;
    if (isCurrent) {
      resolvedLevel = SkillLevelX.fromLabel(skill.currentLevel) ??
          SkillLevelX.fromLabel(skill.detectedLevel) ??
          SkillLevelX.fromLabel(skill.requiredLevel) ??
          SkillLevel.beginner;

      if (resolvedLevel == SkillLevel.none) {
        resolvedLevel = SkillLevel.beginner;
      }
    }

    return SkillUiModel(
      id: skill.skillId.toString(),
      title: skill.skillName,
      skillId: skill.skillId,
      status: status,
      requiredLevel: skill.requiredLevel,
      isCore: skill.isCore,
      selected:
          isGap || isCurrent || skill.selectedByUser || skill.selectedByDefault,
      gapScore: 0,
      level: resolvedLevel,
    );
  }

  CareerPlanUiModel _planUiFromBackend(
    CareerPlanModel plan, {
    String? id,
    int? backendPlanId,
    bool isViewed = false,
    DateTime? createdAt,
  }) {
    final skills = plan.usedLearningTargets
        .map((e) => e['skill_name']?.toString() ?? '')
        .where((e) => e.trim().isNotEmpty)
        .take(3)
        .toList();

    return CareerPlanUiModel(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: plan.trackName.isEmpty ? 'Career Plan' : plan.trackName,
      isViewed: isViewed,
      skillsIncluded: skills,
      weeks: plan.durationWeeks,
      months: 0,
      createdAt: createdAt ?? DateTime.now(),
      roadmap: _mapBackendWeeksToUi(plan),
      backendPlanId: backendPlanId,
      planSummary: plan.planSummary,
      improvementSummary: plan.improvementSummary,
      planningMode: plan.planningMode,
      studyIntensity: plan.studyIntensity,
      availableHoursPerWeek: plan.availableHoursPerWeek,
      backendPlan: plan,
    );
  }

  List<PlanWeekUiModel> _mapBackendWeeksToUi(CareerPlanModel plan) {
    return plan.weeklyBreakdown.map((week) {
      final resources = week.resources.map((r) {
        return CourseLinkUiModel(
          id: '${week.weekNumber}-${r.type}-${r.title.hashCode}-${r.url.hashCode}',
          title: r.title,
          url: r.url,
          providerKey: r.type,
          type: r.type,
          snippet: r.snippet,
          duration: r.duration,
          youtubeDurationMinutes: r.youtubeDurationMinutes,
        );
      }).toList();

      return PlanWeekUiModel(
        weekNumber: week.weekNumber,
        title: week.topic,
        goal: week.description,
        focusPoints: week.learningOutcomes,
        skillTag: week.focusSkills.join(', '),
        courseLinks: resources,
        planSummary: plan.planSummary,
        focusSkills: week.focusSkills,
        topic: week.topic,
        description: week.description,
        learningOutcomes: week.learningOutcomes,
        expectedLevelAfterWeek: week.expectedLevelAfterWeek,
        whatToStudy: week.studyGuide.whatToStudy,
        howToStudy: week.studyGuide.howToStudy,
        timeSplit: week.studyGuide.timeSplit,
      );
    }).toList();
  }

  String _cleanError(Object e) {
    final raw = e.toString().replaceFirst('Exception: ', '').trim();
    final lower = raw.toLowerCase();

    if (lower.contains('invalid level_enum') ||
        lower.contains('confirmed_level=none') ||
        lower.contains('confirmed_level = none')) {
      return 'Could not save the plan because the backend returned an invalid confirmed level. Go back to Skills, keep at least one Current Skill selected, then generate the plan again.';
    }

    if (lower.contains('400') || lower.contains('bad request')) {
      return 'Could not complete this request. Please review your selected skills and timeline, then try again.';
    }

    if (lower.contains('422') ||
        lower.contains('unprocessable') ||
        lower.contains('validation')) {
      return 'Timeline validation failed. Please go back to Skills, confirm your selected skills, then try Generate again.';
    }

    if (lower.contains('timeout')) {
      return 'The backend did not finish before the app timeout. Keep the backend running and try again. The plan generation can take several minutes for long roadmaps.';
    }

    if (lower.contains('connection')) {
      return 'Could not reach the backend. Make sure the backend is running and your phone is on the same Wi-Fi.';
    }

    return raw;
  }
}

final careerBuildProvider =
    NotifierProvider<CareerBuildNotifier, CareerBuildState>(
  CareerBuildNotifier.new,
);

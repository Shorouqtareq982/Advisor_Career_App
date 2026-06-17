int _asInt(dynamic value, {int fallback = 0}) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

double _asDouble(dynamic value, {double fallback = 0}) {
  if (value == null) return fallback;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

bool _asBool(dynamic value, {bool fallback = false}) {
  if (value == null) return fallback;
  if (value is bool) return value;
  if (value is String) {
    final v = value.toLowerCase().trim();
    if (v == 'true') return true;
    if (v == 'false') return false;
  }
  return fallback;
}

String _asString(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  return value.toString();
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _asMapList(dynamic value) {
  if (value is! List) return <Map<String, dynamic>>[];

  return value
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}

List<String> _asStringList(dynamic value) {
  if (value is! List) return <String>[];
  return value.map((e) => e.toString()).toList();
}

List<int> _asIntList(dynamic value) {
  if (value is! List) return <int>[];
  return value.map((e) => _asInt(e)).where((e) => e != 0).toList();
}

class CareerTrackModel {
  final int trackId;
  final String trackName;
  final String description;

  const CareerTrackModel({
    required this.trackId,
    required this.trackName,
    required this.description,
  });

  factory CareerTrackModel.fromJson(Map<String, dynamic> json) {
    return CareerTrackModel(
      trackId: _asInt(json['track_id']),
      trackName: _asString(json['track_name']),
      description: _asString(json['description']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'track_id': trackId,
      'track_name': trackName,
      'description': description,
    };
  }
}

class RegenerationIntentModel {
  final String value;
  final String display;
  final String description;

  const RegenerationIntentModel({
    required this.value,
    required this.display,
    required this.description,
  });

  factory RegenerationIntentModel.fromJson(Map<String, dynamic> json) {
    final value = _asString(json['value'] ?? json['intent']);
    final display = _asString(
      json['display'] ?? json['display_name'] ?? json['label'] ?? json['name'],
      fallback: value,
    );

    return RegenerationIntentModel(
      value: value,
      display: display,
      description: _asString(json['description'] ?? json['instruction']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'display': display,
      'description': description,
    };
  }
}

class CareerSkillModel {
  final int skillId;
  final String skillName;
  final String status;
  final String? detectedLevel;
  final String currentLevel;
  final String requiredLevel;
  final String targetLevel;
  final String learningMode;
  final String targetReason;
  final double confidence;
  final bool needsUserInput;
  final bool selectedByDefault;
  final bool selectedByUser;
  final bool isCore;
  final int requiredWeeks;
  final int importanceWeight;

  const CareerSkillModel({
    required this.skillId,
    required this.skillName,
    required this.status,
    required this.detectedLevel,
    required this.currentLevel,
    required this.requiredLevel,
    required this.targetLevel,
    required this.learningMode,
    required this.targetReason,
    required this.confidence,
    required this.needsUserInput,
    required this.selectedByDefault,
    required this.selectedByUser,
    required this.isCore,
    required this.requiredWeeks,
    required this.importanceWeight,
  });

  factory CareerSkillModel.fromJson(Map<String, dynamic> json) {
    final detected = json['detected_level'];
    final status = _asString(json['status']).toLowerCase().trim();

    String resolvedCurrentLevel() {
      final explicitCurrent = _asString(json['current_level']);
      if (explicitCurrent.trim().isNotEmpty) {
        return explicitCurrent;
      }

      // Missing/partial skills are learning gaps.
      // Do not treat detected_level as the user's current level unless backend
      // explicitly sends current_level.
      if (status == 'missing' || status == 'partial') {
        return 'none';
      }

      return _asString(json['detected_level'], fallback: 'none');
    }

    return CareerSkillModel(
      skillId: _asInt(json['skill_id']),
      skillName: _asString(json['skill_name']),
      status: status,
      detectedLevel: detected == null ? null : detected.toString(),
      currentLevel: resolvedCurrentLevel(),
      requiredLevel: _asString(json['required_level'], fallback: 'beginner'),
      targetLevel: _asString(
        json['target_level'] ?? json['suggested_target_level'],
        fallback: _asString(json['required_level'], fallback: 'beginner'),
      ),
      learningMode: _asString(json['learning_mode']),
      targetReason: _asString(json['target_reason']),
      confidence: _asDouble(json['confidence']),
      needsUserInput: _asBool(json['needs_user_input']),
      selectedByDefault: _asBool(json['selected_by_default']),
      selectedByUser: _asBool(json['selected_by_user']),
      isCore: _asBool(json['is_core'], fallback: true),
      requiredWeeks: _asInt(json['required_weeks']),
      importanceWeight: _asInt(
        json['importance_weight'] ?? json['importance'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'skill_id': skillId,
      'skill_name': skillName,
      'status': status,
      'detected_level': detectedLevel,
      'current_level': currentLevel,
      'required_level': requiredLevel,
      'target_level': targetLevel,
      'learning_mode': learningMode,
      'target_reason': targetReason,
      'confidence': confidence,
      'needs_user_input': needsUserInput,
      'selected_by_default': selectedByDefault,
      'selected_by_user': selectedByUser,
      'is_core': isCore,
      'required_weeks': requiredWeeks,
      'importance_weight': importanceWeight,
    };
  }
}

class FitAnalysisModel {
  final String fitStatus;
  final double fitScore;
  final bool canGeneratePlan;
  final List<String> warnings;
  final List<String> missingCoreSkills;

  const FitAnalysisModel({
    required this.fitStatus,
    required this.fitScore,
    required this.canGeneratePlan,
    required this.warnings,
    required this.missingCoreSkills,
  });

  factory FitAnalysisModel.fromJson(Map<String, dynamic> json) {
    return FitAnalysisModel(
      fitStatus: _asString(json['fit_status']),
      fitScore: _asDouble(json['fit_score']),
      canGeneratePlan: _asBool(json['can_generate_plan'], fallback: true),
      warnings: _asStringList(json['warnings']),
      missingCoreSkills: _asStringList(json['missing_core_skills']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fit_status': fitStatus,
      'fit_score': fitScore,
      'can_generate_plan': canGeneratePlan,
      'warnings': warnings,
      'missing_core_skills': missingCoreSkills,
    };
  }
}

class CareerAnalysisModel {
  final String status;
  final String cvId;
  final int trackId;
  final String trackName;
  final String detectedLevel;
  final String requiredLevel;
  final double levelConfidence;
  final String levelReasoning;
  final List<int> selectedSkillIds;
  final List<CareerSkillModel> recommendedSkills;
  final List<CareerSkillModel> ownedSkills;
  final List<CareerSkillModel> reviewableSkills;
  final List<Map<String, dynamic>> skillGaps;
  final Map<String, dynamic> detectedSkillLevels;
  final FitAnalysisModel? fitAnalysis;
  final Map<String, dynamic> rawJson;

  const CareerAnalysisModel({
    required this.status,
    required this.cvId,
    required this.trackId,
    required this.trackName,
    required this.detectedLevel,
    required this.requiredLevel,
    required this.levelConfidence,
    required this.levelReasoning,
    required this.selectedSkillIds,
    required this.recommendedSkills,
    required this.ownedSkills,
    required this.reviewableSkills,
    required this.skillGaps,
    required this.detectedSkillLevels,
    required this.fitAnalysis,
    required this.rawJson,
  });

  factory CareerAnalysisModel.fromJson(Map<String, dynamic> json) {
    final raw = _asMap(json['raw']);

    return CareerAnalysisModel(
      status: _asString(json['status']),
      cvId: _asString(json['cv_id']),
      trackId: _asInt(json['track_id']),
      trackName: _asString(json['track_name']),
      detectedLevel: _asString(json['detected_level']),
      requiredLevel: _asString(json['required_level']),
      levelConfidence: _asDouble(json['level_confidence']),
      levelReasoning: _asString(json['level_reasoning']),
      selectedSkillIds: _asIntList(json['selected_skill_ids']),
      recommendedSkills: (_asMapList(json['recommended_skills']))
          .map(CareerSkillModel.fromJson)
          .toList(),
      ownedSkills: (_asMapList(json['owned_skills']))
          .map(CareerSkillModel.fromJson)
          .toList(),
      reviewableSkills: (_asMapList(
        json['reviewable_skills'] ?? raw['reviewable_skills'],
      )).map(CareerSkillModel.fromJson).toList(),
      skillGaps: _asMapList(json['skill_gaps'] ?? raw['skill_gaps']),
      detectedSkillLevels: _asMap(
        json['detected_skill_levels'] ?? raw['detected_skill_levels'],
      ),
      fitAnalysis: (json['fit_analysis'] ?? raw['fit_analysis']) == null
          ? null
          : FitAnalysisModel.fromJson(
              _asMap(json['fit_analysis'] ?? raw['fit_analysis']),
            ),
      rawJson: Map<String, dynamic>.from(json),
    );
  }

  Map<String, dynamic> toJson() {
    return rawJson;
  }
}

class TimeGuidanceModel {
  final int minimumWeeks;
  final int suitableWeeks;
  final int maximumWeeks;
  final String studyIntensity;
  final Map<String, dynamic> minimumBreakdown;
  final Map<String, dynamic> suitableBreakdown;
  final Map<String, dynamic> maximumBreakdown;

  const TimeGuidanceModel({
    required this.minimumWeeks,
    required this.suitableWeeks,
    required this.maximumWeeks,
    required this.studyIntensity,
    required this.minimumBreakdown,
    required this.suitableBreakdown,
    required this.maximumBreakdown,
  });

  factory TimeGuidanceModel.fromJson(Map<String, dynamic> json) {
    return TimeGuidanceModel(
      minimumWeeks: _asInt(json['minimum_weeks']),
      suitableWeeks: _asInt(json['suitable_weeks']),
      maximumWeeks: _asInt(json['maximum_weeks']),
      studyIntensity: _asString(json['study_intensity']),
      minimumBreakdown: _asMap(json['minimum_weeks_breakdown']),
      suitableBreakdown: _asMap(json['suitable_weeks_breakdown']),
      maximumBreakdown: _asMap(json['maximum_weeks_breakdown']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'minimum_weeks': minimumWeeks,
      'suitable_weeks': suitableWeeks,
      'maximum_weeks': maximumWeeks,
      'study_intensity': studyIntensity,
      'minimum_weeks_breakdown': minimumBreakdown,
      'suitable_weeks_breakdown': suitableBreakdown,
      'maximum_weeks_breakdown': maximumBreakdown,
    };
  }
}

class RealismModel {
  final bool isRealistic;
  final String adjustment;
  final String zone;
  final int requestedWeeks;
  final int availableHoursPerWeek;
  final String studyIntensity;
  final int calculatedMinimumWeeks;
  final int calculatedSuitableWeeks;
  final int calculatedMaximumWeeks;
  final List<String> warnings;
  final List<String> suggestions;

  const RealismModel({
    required this.isRealistic,
    required this.adjustment,
    required this.zone,
    required this.requestedWeeks,
    required this.availableHoursPerWeek,
    required this.studyIntensity,
    required this.calculatedMinimumWeeks,
    required this.calculatedSuitableWeeks,
    required this.calculatedMaximumWeeks,
    required this.warnings,
    required this.suggestions,
  });

  factory RealismModel.fromJson(Map<String, dynamic> json) {
    return RealismModel(
      isRealistic: _asBool(json['is_realistic'], fallback: true),
      adjustment: _asString(json['adjustment']),
      zone: _asString(json['zone']),
      requestedWeeks: _asInt(json['requested_weeks']),
      availableHoursPerWeek: _asInt(json['available_hours_per_week']),
      studyIntensity: _asString(json['study_intensity']),
      calculatedMinimumWeeks: _asInt(json['calculated_minimum_weeks']),
      calculatedSuitableWeeks: _asInt(json['calculated_suitable_weeks']),
      calculatedMaximumWeeks: _asInt(json['calculated_maximum_weeks']),
      warnings: _asStringList(json['warnings']),
      suggestions: _asStringList(json['suggestions']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'is_realistic': isRealistic,
      'adjustment': adjustment,
      'zone': zone,
      'requested_weeks': requestedWeeks,
      'available_hours_per_week': availableHoursPerWeek,
      'study_intensity': studyIntensity,
      'calculated_minimum_weeks': calculatedMinimumWeeks,
      'calculated_suitable_weeks': calculatedSuitableWeeks,
      'calculated_maximum_weeks': calculatedMaximumWeeks,
      'warnings': warnings,
      'suggestions': suggestions,
    };
  }
}

class CareerTimeResponseModel {
  final String status;
  final String cvId;
  final int trackId;
  final String trackName;
  final String detectedLevel;
  final int availableHoursPerWeek;
  final int requestedWeeks;
  final List<int> selectedSkillIds;
  final List<Map<String, dynamic>> confirmedLearningTargets;
  final List<Map<String, dynamic>> suggestedTargets;
  final RealismModel? realism;
  final TimeGuidanceModel? timeGuidance;
  final String? guidanceMessage;
  final String? note;
  final Map<String, dynamic> rawJson;

  const CareerTimeResponseModel({
    required this.status,
    required this.cvId,
    required this.trackId,
    required this.trackName,
    required this.detectedLevel,
    required this.availableHoursPerWeek,
    required this.requestedWeeks,
    required this.selectedSkillIds,
    required this.confirmedLearningTargets,
    required this.suggestedTargets,
    required this.realism,
    required this.timeGuidance,
    required this.guidanceMessage,
    required this.note,
    required this.rawJson,
  });

  factory CareerTimeResponseModel.fromJson(Map<String, dynamic> json) {
    return CareerTimeResponseModel(
      status: _asString(json['status']),
      cvId: _asString(json['cv_id']),
      trackId: _asInt(json['track_id']),
      trackName: _asString(json['track_name']),
      detectedLevel: _asString(json['detected_level']),
      availableHoursPerWeek: _asInt(
        json['available_hours_per_week'] ?? json['guidance_hours_per_week'],
      ),
      requestedWeeks: _asInt(json['requested_weeks']),
      selectedSkillIds: _asIntList(json['selected_skill_ids']),
      confirmedLearningTargets: _asMapList(json['confirmed_learning_targets']),
      suggestedTargets: _asMapList(json['suggested_targets']),
      realism: json['realism'] == null
          ? null
          : RealismModel.fromJson(_asMap(json['realism'])),
      timeGuidance: json['time_guidance'] == null
          ? null
          : TimeGuidanceModel.fromJson(_asMap(json['time_guidance'])),
      guidanceMessage: json['guidance_message']?.toString(),
      note: json['note']?.toString(),
      rawJson: Map<String, dynamic>.from(json),
    );
  }

  Map<String, dynamic> toJson() {
    return rawJson;
  }
}

class GenerationMetadataModel {
  final Map<String, dynamic> rawJson;
  final bool regenerated;
  final List<String> feedbackIntents;
  final String regenerationMode;
  final bool twoStageLlm;
  final String zone;
  final String effectiveUserLevel;
  final bool canGeneratePlan;
  final bool resourcePersonalization;
  final bool cumulativeMode;
  final bool smartResourceSequencing;
  final bool globalResourceDedupe;
  final bool weeklyResourceContract;
  final bool parallelGeneration;
  final int maxLlmParallel;
  final int maxResourceParallel;
  final Map<String, dynamic> providerHealth;

  const GenerationMetadataModel({
    required this.rawJson,
    required this.regenerated,
    required this.feedbackIntents,
    required this.regenerationMode,
    required this.twoStageLlm,
    required this.zone,
    required this.effectiveUserLevel,
    required this.canGeneratePlan,
    required this.resourcePersonalization,
    required this.cumulativeMode,
    required this.smartResourceSequencing,
    required this.globalResourceDedupe,
    required this.weeklyResourceContract,
    required this.parallelGeneration,
    required this.maxLlmParallel,
    required this.maxResourceParallel,
    required this.providerHealth,
  });

  factory GenerationMetadataModel.fromJson(Map<String, dynamic> json) {
    return GenerationMetadataModel(
      rawJson: Map<String, dynamic>.from(json),
      regenerated: _asBool(json['regenerated']),
      feedbackIntents: _asStringList(json['feedback_intents']),
      regenerationMode: _asString(json['regeneration_mode']),
      twoStageLlm: _asBool(json['two_stage_llm']),
      zone: _asString(json['zone']),
      effectiveUserLevel: _asString(json['effective_user_level']),
      canGeneratePlan: _asBool(json['can_generate_plan'], fallback: true),
      resourcePersonalization: _asBool(json['resource_personalization']),
      cumulativeMode: _asBool(json['cumulative_mode']),
      smartResourceSequencing: _asBool(json['smart_resource_sequencing']),
      globalResourceDedupe: _asBool(json['global_resource_dedupe']),
      weeklyResourceContract: _asBool(json['weekly_resource_contract']),
      parallelGeneration: _asBool(json['parallel_generation']),
      maxLlmParallel: _asInt(json['max_llm_parallel']),
      maxResourceParallel: _asInt(json['max_resource_parallel']),
      providerHealth: _asMap(json['provider_health']),
    );
  }

  Map<String, dynamic> toJson() => Map<String, dynamic>.from(rawJson);
}

class CareerPlanModel {
  final Map<String, dynamic> rawJson;
  final String status;
  final String? cvId;
  final int trackId;
  final String trackName;
  final int durationWeeks;
  final int availableHoursPerWeek;
  final String planningMode;
  final String studyIntensity;
  final String currentAverageLevel;
  final String finalExpectedLevel;
  final String planSummary;
  final String improvementSummary;
  final List<Map<String, dynamic>> usedLearningTargets;
  final List<Map<String, dynamic>> deferredLearningTargets;
  final Map<String, dynamic> latestDetectedSkillLevels;
  final GenerationMetadataModel? generationMetadata;
  final List<CareerWeekModel> weeklyBreakdown;

  const CareerPlanModel({
    required this.rawJson,
    required this.status,
    required this.cvId,
    required this.trackId,
    required this.trackName,
    required this.durationWeeks,
    required this.availableHoursPerWeek,
    required this.planningMode,
    required this.studyIntensity,
    required this.currentAverageLevel,
    required this.finalExpectedLevel,
    required this.planSummary,
    required this.improvementSummary,
    required this.usedLearningTargets,
    required this.deferredLearningTargets,
    required this.latestDetectedSkillLevels,
    required this.generationMetadata,
    required this.weeklyBreakdown,
  });

  factory CareerPlanModel.fromJson(Map<String, dynamic> json) {
    final weeks = _asMapList(json['weekly_breakdown']);

    return CareerPlanModel(
      rawJson: Map<String, dynamic>.from(json),
      status: _asString(json['status']),
      cvId: json['cv_id']?.toString(),
      trackId: _asInt(json['track_id']),
      trackName: _asString(json['track_name']),
      durationWeeks: _asInt(json['duration_weeks']),
      availableHoursPerWeek: _asInt(json['available_hours_per_week']),
      planningMode: _asString(json['planning_mode']),
      studyIntensity: _asString(json['study_intensity']),
      currentAverageLevel: _asString(json['current_average_level']),
      finalExpectedLevel: _asString(json['final_expected_level']),
      planSummary: _asString(
        json['plan_summary'],
        fallback: 'Your personalized learning plan is ready.',
      ),
      improvementSummary: _asString(json['improvement_summary']),
      usedLearningTargets: _asMapList(json['used_learning_targets']),
      deferredLearningTargets: _asMapList(json['deferred_learning_targets']),
      latestDetectedSkillLevels: _asMap(json['latest_detected_skill_levels']),
      generationMetadata: json['generation_metadata'] == null
          ? null
          : GenerationMetadataModel.fromJson(
              _asMap(json['generation_metadata']),
            ),
      weeklyBreakdown: weeks.map((e) => CareerWeekModel.fromJson(e)).toList(),
    );
  }

  bool get isRegenerated => generationMetadata?.regenerated ?? false;

  bool get isFallbackLike {
    final summary = planSummary.toLowerCase();
    final improvement = improvementSummary.toLowerCase();
    return summary.contains('fallback') ||
        improvement.contains('fallback') ||
        summary.contains('adapts the original plan');
  }

  Map<String, dynamic> toJson() {
    final copy = Map<String, dynamic>.from(rawJson);

    copy['status'] = status;
    copy['cv_id'] = cvId;
    copy['track_id'] = trackId;
    copy['track_name'] = trackName;
    copy['duration_weeks'] = durationWeeks;
    copy['available_hours_per_week'] = availableHoursPerWeek;
    copy['planning_mode'] = planningMode;
    copy['study_intensity'] = studyIntensity;
    copy['current_average_level'] = currentAverageLevel;
    copy['final_expected_level'] = finalExpectedLevel;
    copy['plan_summary'] = planSummary;
    copy['improvement_summary'] = improvementSummary;
    copy['used_learning_targets'] = usedLearningTargets;
    copy['deferred_learning_targets'] = deferredLearningTargets;
    copy['latest_detected_skill_levels'] = latestDetectedSkillLevels;
    copy['generation_metadata'] = generationMetadata?.toJson();
    copy['weekly_breakdown'] = weeklyBreakdown.map((e) => e.toJson()).toList();

    return copy;
  }
}

class CareerWeekModel {
  final int weekNumber;
  final List<String> focusSkills;
  final String topic;
  final String description;
  final List<String> learningOutcomes;
  final String expectedLevelAfterWeek;
  final StudyGuideModel studyGuide;
  final List<ResourceModel> resources;
  final Map<String, dynamic> resourceValidationReport;

  const CareerWeekModel({
    required this.weekNumber,
    required this.focusSkills,
    required this.topic,
    required this.description,
    required this.learningOutcomes,
    required this.expectedLevelAfterWeek,
    required this.studyGuide,
    required this.resources,
    required this.resourceValidationReport,
  });

  factory CareerWeekModel.fromJson(Map<String, dynamic> json) {
    final focusSkills = _asStringList(json['focus_skills']);
    final topic = _asString(
      json['topic'],
      fallback: focusSkills.isNotEmpty ? '${focusSkills.first} practice' : '',
    );

    return CareerWeekModel(
      weekNumber: _asInt(json['week_number']),
      focusSkills: focusSkills,
      topic: topic,
      description: _asString(
        json['description'],
        fallback: topic.isEmpty ? '' : 'Work on $topic with guided practice.',
      ),
      learningOutcomes: _asStringList(json['learning_outcomes']),
      expectedLevelAfterWeek: _asString(json['expected_level_after_week']),
      studyGuide: StudyGuideModel.fromJson(_asMap(json['study_guide'])),
      resources: _asMapList(json['resources'])
          .map((e) => ResourceModel.fromJson(e))
          .toList(),
      resourceValidationReport: _asMap(json['resource_validation_report']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'week_number': weekNumber,
      'focus_skills': focusSkills,
      'topic': topic,
      'description': description,
      'learning_outcomes': learningOutcomes,
      'expected_level_after_week': expectedLevelAfterWeek,
      'study_guide': studyGuide.toJson(),
      'resources': resources.map((e) => e.toJson()).toList(),
      'resource_validation_report': resourceValidationReport,
    };
  }
}

class StudyGuideModel {
  final List<String> whatToStudy;
  final List<String> howToStudy;
  final Map<String, dynamic> timeSplit;

  const StudyGuideModel({
    required this.whatToStudy,
    required this.howToStudy,
    required this.timeSplit,
  });

  factory StudyGuideModel.fromJson(Map<String, dynamic> json) {
    return StudyGuideModel(
      whatToStudy: _asStringList(json['what_to_study']),
      howToStudy: _asStringList(json['how_to_study']),
      timeSplit: _asMap(json['time_split']),
    );
  }

  bool get isEmpty =>
      whatToStudy.isEmpty && howToStudy.isEmpty && timeSplit.isEmpty;

  Map<String, dynamic> toJson() {
    return {
      'what_to_study': whatToStudy,
      'how_to_study': howToStudy,
      'time_split': timeSplit,
    };
  }
}

class ResourceModel {
  final String title;
  final String url;
  final String type;
  final String snippet;
  final String duration;
  final int? youtubeDurationMinutes;
  final String? channelTitle;
  final String queryContext;
  final String sourceProvider;
  final String sourceDomain;
  final bool isOfficial;
  final bool isPractical;
  final bool wasFallback;
  final bool durationVerified;
  final double score;

  const ResourceModel({
    required this.title,
    required this.url,
    required this.type,
    required this.snippet,
    required this.duration,
    required this.youtubeDurationMinutes,
    required this.channelTitle,
    required this.queryContext,
    required this.sourceProvider,
    required this.sourceDomain,
    required this.isOfficial,
    required this.isPractical,
    required this.wasFallback,
    required this.durationVerified,
    required this.score,
  });

  factory ResourceModel.fromJson(Map<String, dynamic> json) {
    final ytMinutes = json['youtube_duration_minutes'];

    return ResourceModel(
      title: _asString(json['title'], fallback: 'Untitled Resource'),
      url: _asString(json['url']),
      type: _asString(json['type'], fallback: 'resource'),
      snippet: _asString(json['snippet']),
      duration: _asString(
        json['duration'],
        fallback: ytMinutes == null ? '' : '${_asInt(ytMinutes)} min',
      ),
      youtubeDurationMinutes: ytMinutes == null ? null : _asInt(ytMinutes),
      channelTitle: json['channel_title']?.toString(),
      queryContext: _asString(json['query_context']),
      sourceProvider: _asString(json['source_provider']),
      sourceDomain: _asString(json['source_domain']),
      isOfficial: _asBool(json['is_official']),
      isPractical: _asBool(json['is_practical']),
      wasFallback: _asBool(json['was_fallback']),
      durationVerified: _asBool(json['duration_verified']),
      score: _asDouble(json['score']),
    );
  }

  String get displayDuration {
    if (type.toLowerCase() == 'youtube' &&
        youtubeDurationMinutes != null &&
        youtubeDurationMinutes! > 0) {
      return '$youtubeDurationMinutes min';
    }
    return duration;
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'url': url,
      'type': type,
      'snippet': snippet,
      'duration': duration,
      'youtube_duration_minutes': youtubeDurationMinutes,
      'channel_title': channelTitle,
      'query_context': queryContext,
      'source_provider': sourceProvider,
      'source_domain': sourceDomain,
      'is_official': isOfficial,
      'is_practical': isPractical,
      'was_fallback': wasFallback,
      'duration_verified': durationVerified,
      'score': score,
    };
  }
}

class SavePlanResponseModel {
  final String status;
  final int planId;
  final String message;
  final String createdAt;
  final int availableHoursPerWeek;
  final int weeksSaved;
  final int skillsSaved;

  const SavePlanResponseModel({
    required this.status,
    required this.planId,
    required this.message,
    required this.createdAt,
    required this.availableHoursPerWeek,
    required this.weeksSaved,
    required this.skillsSaved,
  });

  factory SavePlanResponseModel.fromJson(Map<String, dynamic> json) {
    return SavePlanResponseModel(
      status: _asString(json['status']),
      planId: _asInt(json['plan_id']),
      message: _asString(json['message']),
      createdAt: _asString(json['created_at']),
      availableHoursPerWeek: _asInt(json['available_hours_per_week']),
      weeksSaved: _asInt(json['weeks_saved']),
      skillsSaved: _asInt(json['skills_saved']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'plan_id': planId,
      'message': message,
      'created_at': createdAt,
      'available_hours_per_week': availableHoursPerWeek,
      'weeks_saved': weeksSaved,
      'skills_saved': skillsSaved,
    };
  }
}

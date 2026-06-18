import 'package:file_picker/file_picker.dart';

import '../datasources/career_build_remote_datasource.dart';
import '../models/career_build_models.dart';

class CareerBuildRepositoryImpl {
  final CareerBuildRemoteDataSource remote;

  CareerBuildRepositoryImpl({CareerBuildRemoteDataSource? remote})
      : remote = remote ?? CareerBuildRemoteDataSource();

  Future<List<CareerTrackModel>> getTracks() {
    return remote.getTracks();
  }

  Future<List<RegenerationIntentModel>> getRegenerationIntents() {
    return remote.getRegenerationIntents();
  }

  Future<CareerAnalysisModel> analyzeCv({
    required PlatformFile cvFile,
    required int trackId,
  }) {
    return remote.analyzeCv(
      cvFile: cvFile,
      trackId: trackId,
    );
  }

  Future<CareerAnalysisModel> confirmSkills({
    required String cvId,
    required int trackId,
    required List<int> selectedSkillIds,
    required List<Map<String, dynamic>> skillOverrides,
  }) {
    return remote.confirmSkills(
      cvId: cvId,
      trackId: trackId,
      selectedSkillIds: selectedSkillIds,
      skillOverrides: skillOverrides,
    );
  }

  Future<CareerTimeResponseModel> confirmTimePreview({
    required String cvId,
    required int trackId,
  }) {
    return remote.confirmTimePreview(
      cvId: cvId,
      trackId: trackId,
    );
  }

  Future<CareerTimeResponseModel> confirmTime({
    required String cvId,
    required int trackId,
    required int requestedWeeks,
    required int availableHoursPerWeek,
  }) {
    return remote.confirmTime(
      cvId: cvId,
      trackId: trackId,
      requestedWeeks: requestedWeeks,
      availableHoursPerWeek: availableHoursPerWeek,
    );
  }

  Future<CareerPlanModel> generatePlan({
    required String cvId,
    required int trackId,
    required int durationWeeks,
    required int availableHoursPerWeek,
  }) {
    return remote.generatePlan(
      cvId: cvId,
      trackId: trackId,
      durationWeeks: durationWeeks,
      availableHoursPerWeek: availableHoursPerWeek,
    );
  }

  Future<CareerPlanModel> regeneratePlan({
    required String cvId,
    required int trackId,
    required Map<String, dynamic> previousPlan,
    required List<String> feedbackIntents,
  }) {
    return remote.regeneratePlan(
      cvId: cvId,
      trackId: trackId,
      previousPlan: previousPlan,
      feedbackIntents: feedbackIntents,
    );
  }

  Future<SavePlanResponseModel> savePlan({
    required String userId,
    required String cvId,
    required int trackId,
  }) {
    return remote.savePlan(
      userId: userId,
      cvId: cvId,
      trackId: trackId,
    );
  }
}

import 'dart:io';
import '../../domain/entities/interview_entities.dart';

abstract class MockInterviewRepository {
  Future<InterviewSessionEntity> startBehavioralSession({
    required String roleName,
    required String userId,
    String? languagePreferred,
  });

  Future<InterviewSessionEntity> startTechnicalSession({
    required String roleName,
    required String userId,
    String? languagePreferred,
  });

  Future<List<int>> getQuestionAudio(
    String questionId, {
    String? languagePreferred,
  });

  Future<void> notifyUploadComplete({
    required String sessionId,
    required String blobUrl,
    String? languagePreferred,
  });

  Future<String> getBehavioralReport(String sessionId);
  Future<String> getTechnicalReport(String sessionId);

  Future<void> uploadToAzure({
    required File file,
    required String blobUrl,
    required String sasToken,
    required InterviewSessionType sessionType,
  });

  Future<void> saveSessionLocally({
    required String sessionId,
    required String roleName,
    required InterviewSessionType sessionType,
    String? languagePreferred,
  });

  Future<List<Map<String, dynamic>>> getLocalSessions();
  Future<void> deleteLocalSession(String sessionId);
}

import 'dart:io';
import '../entities/interview_entities.dart';

abstract class MockInterviewRepository {
  /// POST /sessions/start
  Future<InterviewSessionEntity> startSession({
    required String roleName,
    required String roleId,
  });

  /// GET /questions/{q_id}/audio-stream
  /// Returns raw bytes of the audio
  Future<List<int>> getQuestionAudio(String questionId);

  /// POST /behavioural/notify-upload
  Future<void> notifyUploadComplete({
    required String sessionId,
    required String videoUrl,
  });

  /// GET /interviews/feedback  (list)
  Future<List<InterviewFeedbackSummary>> getFeedbackList();

  /// GET /interviews/feedback/{session_id}
  Future<InterviewFeedbackDetailEntity> getFeedbackDetail(String sessionId);

  /// DELETE /interviews/feedback/{session_id}
  Future<void> deleteFeedback(String sessionId);

  /// Upload video to Azure using SAS token
  Future<String> uploadVideoToAzure({
    required File videoFile,
    required String sasToken,
    required String sessionId,
  });
}

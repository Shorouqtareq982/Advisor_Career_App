import 'dart:io';
import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/entities/interview_entities.dart';
import '../../domain/repositories/mock_interview_repository.dart';
import '../models/interview_models.dart';

class MockInterviewRepositoryImpl implements MockInterviewRepository {
  final Dio _dio = apiClient.dio;

  static const String _base = '/api/v1/mock_interview';

  // ─── Start Session ─────────────────────────────────────────────────────────

  @override
  Future<InterviewSessionEntity> startSession({
    required String roleName,
    required String roleId,
  }) async {
    final response = await _dio.post(
      '$_base/sessions/start',
      data: {
        'role_name': roleName,
        'role_id': roleId,
      },
    );
    return InterviewSessionModel.fromJson(
      response.data as Map<String, dynamic>,
    ).toEntity();
  }

  // ─── Get Question Audio ────────────────────────────────────────────────────

  @override
  Future<List<int>> getQuestionAudio(String questionId) async {
    final response = await _dio.get<List<int>>(
      '$_base/questions/$questionId/audio-stream',
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data ?? [];
  }

  // ─── Notify Upload Complete ────────────────────────────────────────────────

  @override
  Future<void> notifyUploadComplete({
    required String sessionId,
    required String videoUrl,
  }) async {
    await _dio.post(
      '$_base/behavioural/notify-upload',
      data: {
        'session_id': sessionId,
        'video_url': videoUrl,
      },
    );
  }

  // ─── Get Feedback List ─────────────────────────────────────────────────────

  @override
  Future<List<InterviewFeedbackSummary>> getFeedbackList() async {
    final response = await _dio.get('$_base/interviews/feedback');
    final List<dynamic> data = response.data as List<dynamic>? ?? [];
    return data
        .map((item) => InterviewFeedbackSummaryModel.fromJson(
              item as Map<String, dynamic>,
            ).toEntity())
        .toList();
  }

  // ─── Get Feedback Detail ───────────────────────────────────────────────────

  @override
  Future<InterviewFeedbackDetailEntity> getFeedbackDetail(
      String sessionId) async {
    final response = await _dio.get('$_base/interviews/feedback/$sessionId');
    return InterviewFeedbackDetailModel.fromJson(
      response.data as Map<String, dynamic>,
    ).toEntity();
  }

  // ─── Delete Feedback ───────────────────────────────────────────────────────

  @override
  Future<void> deleteFeedback(String sessionId) async {
    await _dio.delete('$_base/interviews/feedback/$sessionId');
  }

  // ─── Upload Video to Azure ─────────────────────────────────────────────────
  // Uses the SAS token from the session to upload directly to Azure Blob Storage
  // This bypasses the backend and uploads directly from the app
  @override
  Future<String> uploadVideoToAzure({
    required File videoFile,
    required String sasToken,
    required String sessionId,
  }) async {
    // SAS token URL format: https://<account>.blob.core.windows.net/<container>/<blob>?<sas>
    // We upload using PUT request with the SAS URL
    final fileName =
        'interview_${sessionId}_${DateTime.now().millisecondsSinceEpoch}.mp4';

    // Build the blob URL with SAS token
    // The sasToken should be the full URL with SAS query params
    final uploadUrl = sasToken.contains('?')
        ? '${sasToken.split('?')[0]}/$fileName?${sasToken.split('?')[1]}'
        : '$sasToken/$fileName';

    final fileBytes = await videoFile.readAsBytes();

    final azureDio = Dio();
    await azureDio.put(
      uploadUrl,
      data: Stream.fromIterable(fileBytes.map((e) => [e])),
      options: Options(
        headers: {
          'x-ms-blob-type': 'BlockBlob',
          'Content-Type': 'video/mp4',
          'Content-Length': fileBytes.length,
        },
      ),
    );

    // Return the blob URL (without SAS for storage)
    return uploadUrl.split('?')[0];
  }
}

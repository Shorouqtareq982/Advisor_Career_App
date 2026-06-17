import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/entities/interview_entities.dart';
import '../models/interview_models.dart';
import '../../domain/repositories/mock_interview_repository.dart';

class MockInterviewRepositoryImpl implements MockInterviewRepository {
  final Dio _dio = apiClient.dio;

  static const String _base = '/api/v1/mock-interview';
  String get _cacheKey {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'guest';
    return 'mock_interview_sessions_$userId';
  }

  // ─── Start Behavioral Session ──────────────────────────────────────
  Future<InterviewSessionEntity> startBehavioralSession({
    required String roleName,
    required String userId,
    String? languagePreferred,
  }) async {
    final response = await _dio.post(
      '$_base/sessions/start/behavioral',
      data: {
        'role_name': roleName,
        'user_id': userId,
        if (languagePreferred != null) 'language_preferred': languagePreferred,
      },
    );
    return InterviewSessionModel.fromJson(
      response.data as Map<String, dynamic>,
    ).toEntity(InterviewSessionType.behavioral);
  }

  // ─── Start Technical Session  ───────────────────────────────────
  Future<InterviewSessionEntity> startTechnicalSession({
    required String roleName,
    required String userId,
    String? languagePreferred,
  }) async {
    final response = await _dio.post(
      '$_base/sessions/start/technical',
      data: {
        'role_name': roleName,
        'user_id': userId,
        if (languagePreferred != null) 'language_preferred': languagePreferred,
      },
    );
    return InterviewSessionModel.fromJson(
      response.data as Map<String, dynamic>,
    ).toEntity(InterviewSessionType.technical);
  }

  // ─── Get Question Audio ────────────────────────────────────────────────────
  Future<List<int>> getQuestionAudio(
    String questionId, {
    String? languagePreferred,
  }) async {
    final response = await _dio.get<List<int>>(
      '$_base/questions/$questionId/audio-stream',
      queryParameters: languagePreferred != null
          ? {'language_preferred': languagePreferred}
          : null,
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data ?? [];
  }

  // ─── Notify Upload Complete ────────────────────────────────────────────────
  Future<void> notifyUploadComplete({
    required String sessionId,
    required String blobUrl,
    String? languagePreferred,
  }) async {
    await _dio.post(
      '$_base/notify-upload',
      data: {
        'session_id': sessionId,
        'blob_url': blobUrl,
        if (languagePreferred != null) 'language_preferred': languagePreferred,
      },
    );
  }

  // ─── Get Behavioral Report ─────────────────────────────────────────────────
  Future<String> getBehavioralReport(String sessionId) async {
    final response = await _dio.get<dynamic>(
      '$_base/analysis/$sessionId/behavioral-report',
      options: Options(responseType: ResponseType.plain),
    );
    final raw = response.data?.toString() ?? '';
    if (raw.startsWith('"') && raw.endsWith('"')) {
      return jsonDecode(raw) as String;
    }
    return raw;
  }

  // ─── Get Technical Report ──────────────────────────────────────────────────
  Future<String> getTechnicalReport(String sessionId) async {
    final response = await _dio.get<dynamic>(
      '$_base/analysis/$sessionId/technical-report',
      options: Options(responseType: ResponseType.plain),
    );
    final raw = response.data?.toString() ?? '';
    if (raw.startsWith('"') && raw.endsWith('"')) {
      return jsonDecode(raw) as String;
    }
    return raw;
  }

  // ─── Upload to Azure Blob ──────────────────────────────────────────────────
  Future<void> uploadToAzure({
    required File file,
    required String blobUrl,
    required String sasToken,
    required InterviewSessionType sessionType,
  }) async {
    final isVideo = sessionType == InterviewSessionType.behavioral;
    final contentType = isVideo ? 'video/mp4' : 'audio/mpeg';

    final uploadUrl =
        blobUrl.contains('?') ? '$blobUrl&$sasToken' : '$blobUrl?$sasToken';

    final fileBytes = await file.readAsBytes();

    final azureDio = Dio();
    await azureDio.put(
      uploadUrl,
      data: Stream.fromIterable(fileBytes.map((e) => [e])),
      options: Options(
        headers: {
          'x-ms-blob-type': 'BlockBlob',
          'Content-Type': contentType,
          'Content-Length': fileBytes.length,
        },
        sendTimeout: const Duration(minutes: 5),
        receiveTimeout: const Duration(minutes: 2),
      ),
    );
  }

  // ─── Local Cache for Sessions ──────────────────────────────────────────────

  Future<void> saveSessionLocally({
    required String sessionId,
    required String roleName,
    required InterviewSessionType sessionType,
    String? languagePreferred,
  }) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;

    if (userId != null) {
      try {
        await Supabase.instance.client.from('interview_sessions').upsert({
          'session_id': sessionId,
          'user_id': userId,
          'role_name': roleName,
          'session_type': sessionType.name,
          'created_at': DateTime.now().toIso8601String(),
          if (languagePreferred != null)
            'language_preferred': languagePreferred,
        });
      } catch (e) {
        debugPrint('Supabase session save failed: $e');
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    final List<Map<String, dynamic>> sessions = raw != null
        ? List<Map<String, dynamic>>.from(jsonDecode(raw) as List)
        : [];
    sessions.removeWhere((s) => s['session_id'] == sessionId);
    sessions.insert(0, {
      'session_id': sessionId,
      'role_name': roleName,
      'session_type': sessionType.name,
      'created_at': DateTime.now().toIso8601String(),
      if (languagePreferred != null) 'language_preferred': languagePreferred,
    });
    await prefs.setString(_cacheKey, jsonEncode(sessions));
  }

  Future<List<Map<String, dynamic>>> getLocalSessions() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;

    if (userId != null) {
      try {
        final response = await Supabase.instance.client
            .from('interview_sessions')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false);

        final sessions = List<Map<String, dynamic>>.from(response as List);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_cacheKey, jsonEncode(sessions));

        return sessions;
      } catch (e) {
        debugPrint('Supabase fetch failed, falling back to cache: $e');
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(raw) as List);
  }

  Future<void> deleteLocalSession(String sessionId) async {
    try {
      await Supabase.instance.client
          .from('interview_sessions')
          .delete()
          .eq('session_id', sessionId);
    } catch (e) {
      debugPrint('Supabase delete failed: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return;
    final sessions = List<Map<String, dynamic>>.from(jsonDecode(raw) as List);
    sessions.removeWhere((s) => s['session_id'] == sessionId);
    await prefs.setString(_cacheKey, jsonEncode(sessions));
  }

  // ─── Pending Upload Cache ──────────────────────────────────────────────────

  static const String _pendingUploadsKey = 'pending_uploads';

  Future<void> savePendingUpload({
    required String sessionId,
    required String filePath,
    required String roleName,
    required InterviewSessionType sessionType,
    required String blobUrl,
    required String sasToken,
    String? languagePreferred,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingUploadsKey);
    final List<Map<String, dynamic>> pending = raw != null
        ? List<Map<String, dynamic>>.from(jsonDecode(raw) as List)
        : [];

    pending.removeWhere((p) => p['session_id'] == sessionId);
    pending.add({
      'session_id': sessionId,
      'file_path': filePath,
      'role_name': roleName,
      'session_type': sessionType.name,
      'blob_url': blobUrl,
      'sas_token': sasToken,
      if (languagePreferred != null) 'language_preferred': languagePreferred,
      'created_at': DateTime.now().toIso8601String(),
    });

    await prefs.setString(_pendingUploadsKey, jsonEncode(pending));
  }

  Future<List<Map<String, dynamic>>> getPendingUploads() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingUploadsKey);
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(raw) as List);
  }

  Future<void> removePendingUpload(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingUploadsKey);
    if (raw == null) return;
    final pending = List<Map<String, dynamic>>.from(jsonDecode(raw) as List);
    pending.removeWhere((p) => p['session_id'] == sessionId);
    await prefs.setString(_pendingUploadsKey, jsonEncode(pending));
  }

  // ─── Incomplete Sessions ───────────────────────────────────────────────────────

  static const String _incompleteSessionsKey = 'incomplete_sessions';

  Future<void> saveIncompleteSession({
    required String sessionId,
    required String roleName,
    required InterviewSessionType sessionType,
    required String blobUrl,
    required String sasToken,
    required int lastQuestionIndex,
    required List<InterviewQuestionEntity> questions,
    String? recordingPath,
    String? languagePreferred,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_incompleteSessionsKey);
    final List<Map<String, dynamic>> sessions = raw != null
        ? List<Map<String, dynamic>>.from(jsonDecode(raw) as List)
        : [];

    sessions.removeWhere((s) => s['session_id'] == sessionId);
    sessions.insert(0, {
      'session_id': sessionId,
      'role_name': roleName,
      'session_type': sessionType.name,
      'blob_url': blobUrl,
      'sas_token': sasToken,
      'saved_at': DateTime.now().toIso8601String(),
      'last_question_index': lastQuestionIndex,
      'questions': questions
          .map((q) => {
                'question_id': q.questionId,
                'question_text': q.questionText,
              })
          .toList(),
      if (recordingPath != null) 'recording_path': recordingPath,
      if (languagePreferred != null) 'language_preferred': languagePreferred,
    });

    await prefs.setString(_incompleteSessionsKey, jsonEncode(sessions));
  }

  Future<List<IncompleteSessionEntity>> getIncompleteSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_incompleteSessionsKey);
    if (raw == null) return [];

    final List<Map<String, dynamic>> sessions =
        List<Map<String, dynamic>>.from(jsonDecode(raw) as List);

    return sessions.map((s) {
      final rawQuestions = s['questions'] as List<dynamic>? ?? [];
      return IncompleteSessionEntity(
        sessionId: s['session_id'] as String,
        roleName: s['role_name'] as String,
        sessionType: (s['session_type'] as String) == 'technical'
            ? InterviewSessionType.technical
            : InterviewSessionType.behavioral,
        blobUrl: s['blob_url'] as String,
        sasToken: s['sas_token'] as String,
        savedAt: DateTime.tryParse(s['saved_at'] as String) ?? DateTime.now(),
        lastQuestionIndex: s['last_question_index'] as int? ?? 0,
        questions: rawQuestions
            .map((q) => InterviewQuestionEntity(
                  questionId: q['question_id'] as String,
                  questionText: q['question_text'] as String,
                ))
            .toList(),
        recordingPath: s['recording_path'] as String?,
        languagePreferred: s['language_preferred'] as String?,
      );
    }).toList();
  }

  Future<void> deleteIncompleteSession(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_incompleteSessionsKey);
    if (raw == null) return;
    final sessions = List<Map<String, dynamic>>.from(jsonDecode(raw) as List);
    sessions.removeWhere((s) => s['session_id'] == sessionId);
    await prefs.setString(_incompleteSessionsKey, jsonEncode(sessions));
  }

  Future<void> updateIncompleteSessionProgress({
    required String sessionId,
    required int lastQuestionIndex,
    String? recordingPath,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_incompleteSessionsKey);
    if (raw == null) return;
    final sessions = List<Map<String, dynamic>>.from(jsonDecode(raw) as List);
    final index = sessions.indexWhere((s) => s['session_id'] == sessionId);
    if (index == -1) return;
    sessions[index]['last_question_index'] = lastQuestionIndex;
    if (recordingPath != null)
      sessions[index]['recording_path'] = recordingPath;
    await prefs.setString(_incompleteSessionsKey, jsonEncode(sessions));
  }
}

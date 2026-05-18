import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/entities/interview_entities.dart';
import '../models/interview_models.dart';

class MockInterviewRepositoryImpl {
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
}

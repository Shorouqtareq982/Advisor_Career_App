import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../models/career_build_models.dart';

class CareerBuildRemoteDataSource {
  final _api = apiClient;

  static const Duration _normalReceiveTimeout = Duration(minutes: 5);
  static const Duration _analysisReceiveTimeout = Duration(minutes: 10);
  static const Duration _planReceiveTimeout = Duration(minutes: 30);
  static const Duration _sendTimeout = Duration(minutes: 5);

  Options _jsonOptions({
    Duration receiveTimeout = _normalReceiveTimeout,
    Duration sendTimeout = _sendTimeout,
  }) {
    return Options(
      contentType: Headers.jsonContentType,
      sendTimeout: sendTimeout,
      receiveTimeout: receiveTimeout,
    );
  }

  Options _formOptions({
    Duration receiveTimeout = _normalReceiveTimeout,
    Duration sendTimeout = _sendTimeout,
  }) {
    return Options(
      contentType: Headers.formUrlEncodedContentType,
      sendTimeout: sendTimeout,
      receiveTimeout: receiveTimeout,
    );
  }

  Options _multipartOptions({
    Duration receiveTimeout = _analysisReceiveTimeout,
    Duration sendTimeout = _sendTimeout,
  }) {
    return Options(
      contentType: 'multipart/form-data',
      sendTimeout: sendTimeout,
      receiveTimeout: receiveTimeout,
    );
  }

  String _extractBackendError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;

      if (data is Map) {
        final detail = data['detail'] ?? data['error'] ?? data['message'];
        if (detail != null && detail.toString().trim().isNotEmpty) {
          return detail.toString();
        }
      }

      if (data is String && data.trim().isNotEmpty) {
        return data;
      }

      if (error.message != null && error.message!.trim().isNotEmpty) {
        return error.message!;
      }

      final status = error.response?.statusCode;
      if (status != null) {
        return 'Backend request failed with status $status.';
      }
    }

    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (e) {
      throw Exception(_extractBackendError(e));
    }
  }

  Future<List<CareerTrackModel>> getTracks() async {
    return _guard(() async {
      final res = await _api.get(ApiConstants.careerTracks);
      final data = res.data is Map
          ? Map<String, dynamic>.from(res.data)
          : <String, dynamic>{};
      final list = data['tracks'] as List? ?? const [];

      return list
          .map((e) => CareerTrackModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    });
  }

  Future<List<RegenerationIntentModel>> getRegenerationIntents() async {
    return _guard(() async {
      final res = await _api.get(ApiConstants.careerRegenerationIntents);
      final data = res.data is Map
          ? Map<String, dynamic>.from(res.data)
          : <String, dynamic>{};
      final list = data['available_intents'] as List? ?? const [];

      return list
          .map((e) =>
              RegenerationIntentModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    });
  }

  Future<CareerAnalysisModel> analyzeCv({
    required PlatformFile cvFile,
    required int trackId,
  }) async {
    return _guard(() async {
      final MultipartFile multipartFile;

      if (cvFile.bytes != null) {
        multipartFile =
            MultipartFile.fromBytes(cvFile.bytes!, filename: cvFile.name);
      } else if (cvFile.path != null && cvFile.path!.isNotEmpty) {
        multipartFile =
            await MultipartFile.fromFile(cvFile.path!, filename: cvFile.name);
      } else {
        throw Exception('Selected CV file is invalid.');
      }

      final res = await _api.post(
        ApiConstants.careerAnalyze,
        data: FormData.fromMap({
          'cv_file': multipartFile,
          'track_id': trackId,
        }),
        options: _multipartOptions(),
      );

      return CareerAnalysisModel.fromJson(Map<String, dynamic>.from(res.data));
    });
  }

  Future<CareerAnalysisModel> confirmSkills({
    required String cvId,
    required int trackId,
    required List<int> selectedSkillIds,
    required List<Map<String, dynamic>> skillOverrides,
  }) async {
    return _guard(() async {
      final res = await _api.post(
        ApiConstants.careerConfirmSkills,
        data: {
          'cv_id': cvId,
          'track_id': trackId,
          'selected_skill_ids': selectedSkillIds,
          'skill_overrides': skillOverrides,
        },
        options: _jsonOptions(),
      );

      return CareerAnalysisModel.fromJson(Map<String, dynamic>.from(res.data));
    });
  }

  Future<CareerTimeResponseModel> confirmTimePreview({
    required String cvId,
    required int trackId,
  }) async {
    return _guard(() async {
      final res = await _api.post(
        ApiConstants.careerConfirmTimePreview,
        data: {
          'cv_id': cvId,
          'track_id': trackId,
        },
        options: _formOptions(),
      );

      return CareerTimeResponseModel.fromJson(
          Map<String, dynamic>.from(res.data));
    });
  }

  Future<CareerTimeResponseModel> confirmTime({
    required String cvId,
    required int trackId,
    required int requestedWeeks,
    required int availableHoursPerWeek,
  }) async {
    return _guard(() async {
      final res = await _api.post(
        ApiConstants.careerConfirmTime,
        data: {
          'cv_id': cvId,
          'track_id': trackId,
          'requested_weeks': requestedWeeks,
          'available_hours_per_week': availableHoursPerWeek,
        },
        options: _jsonOptions(),
      );

      return CareerTimeResponseModel.fromJson(
          Map<String, dynamic>.from(res.data));
    });
  }

  Future<CareerPlanModel> generatePlan({
    required String cvId,
    required int trackId,
    required int durationWeeks,
    required int availableHoursPerWeek,
  }) async {
    return _guard(() async {
      final res = await _api.post(
        ApiConstants.careerGeneratePlan,
        data: {
          'cv_id': cvId,
          'track_id': trackId,
          'duration_weeks': durationWeeks,
          'available_hours_per_week': availableHoursPerWeek,
        },
        options: _jsonOptions(receiveTimeout: _planReceiveTimeout),
      );

      return CareerPlanModel.fromJson(Map<String, dynamic>.from(res.data));
    });
  }

  Future<CareerPlanModel> regeneratePlan({
    required String cvId,
    required int trackId,
    required Map<String, dynamic> previousPlan,
    required List<String> feedbackIntents,
  }) async {
    return _guard(() async {
      final res = await _api.post(
        ApiConstants.careerRegeneratePlan,
        data: {
          'cv_id': cvId,
          'track_id': trackId,
          'previous_plan': previousPlan,
          'feedback_intents': feedbackIntents,
          'regeneration_mode': 'full',
        },
        options: _jsonOptions(receiveTimeout: _planReceiveTimeout),
      );

      return CareerPlanModel.fromJson(Map<String, dynamic>.from(res.data));
    });
  }

  Future<SavePlanResponseModel> savePlan({
    required String userId,
    required String cvId,
    required int trackId,
  }) async {
    return _guard(() async {
      final res = await _api.post(
        ApiConstants.careerSavePlan,
        data: {
          'user_id': userId,
          'cv_id': cvId,
          'track_id': trackId,
        },
        options: _jsonOptions(),
      );

      return SavePlanResponseModel.fromJson(
          Map<String, dynamic>.from(res.data));
    });
  }
}

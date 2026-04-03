import 'dart:io';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../models/resume_report_model.dart';
import '../../domain/entities/resume_report_entity.dart';

class ResumeOptimizationRepository {
  final Dio _dio = apiClient.dio;

  /// POST /api/v1/cv_optimization/analyze
  /// Backend returns analysis directly (no report_id in response),
  /// so we fetch /reports after analysis to get the latest report_id.
  Future<Map<String, dynamic>> analyzeCV({
    required File cvFile,
    String? jobDescription,
  }) async {
    final fileName = cvFile.path.split('/').last;

    final formData = FormData.fromMap({
      'cv_file': await MultipartFile.fromFile(
        cvFile.path,
        filename: fileName,
      ),
      if (jobDescription != null && jobDescription.trim().isNotEmpty)
        'jd_text': jobDescription.trim(),
    });

    // Step 1: Run analysis (backend returns analysis body, no report_id)
    await _dio.post(
      '${ApiConstants.baseUrl}/api/v1/cv_optimization/analyze',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
        receiveTimeout: const Duration(seconds: 120),
        sendTimeout: const Duration(seconds: 60),
      ),
    );

    // Step 2: Fetch reports list to get the newly created report_id
    final reportsResponse = await _dio.get(
      '${ApiConstants.baseUrl}/api/v1/cv_optimization/reports',
    );
    final List<dynamic> reports = reportsResponse.data as List<dynamic>? ?? [];
    if (reports.isEmpty) return {};

    // First item = newest report
    final latest = reports.first as Map<String, dynamic>;
    return {'report_id': latest['report_id']};
  }

  /// GET /api/v1/cv_optimization/report/{report_id}
  Future<ResumeReportEntity> getReport(String reportId) async {
    final response = await _dio.get(
      '${ApiConstants.baseUrl}/api/v1/cv_optimization/report/$reportId',
    );

    final model = ResumeReportModel.fromJson(
      response.data as Map<String, dynamic>,
    );
    return model.toEntity();
  }

  /// GET /api/v1/cv_optimization/reports
  Future<List<ResumeReportSummary>> getUserReports() async {
    final response = await _dio.get(
      '${ApiConstants.baseUrl}/api/v1/cv_optimization/reports',
    );

    final List<dynamic> data = response.data as List<dynamic>? ?? [];
    return data
        .map((item) => ResumeReportSummaryModel.fromJson(
              item as Map<String, dynamic>,
            ).toEntity())
        .toList();
  }

  /// DELETE /api/v1/cv_optimization/report/{report_id}
  Future<void> deleteReport(String reportId) async {
    await _dio.delete(
      '${ApiConstants.baseUrl}/api/v1/cv_optimization/report/$reportId',
    );
  }
}

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../models/job_model.dart';
import '../../domain/entities/job_entity.dart';

class JobMatchingRepository {
  final Dio _dio = apiClient.dio;

  // ── Get job titles for dropdown ────────────────────────────────────────────
  Future<List<String>> getJobTitles() async {
    try {
      final response = await _dio.get(
        '${ApiConstants.baseUrl}${ApiConstants.jobMatchingJobTitles}',
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return List<String>.from(data['job_titles'] as List? ?? []);
      }
      return _fallbackJobTitles;
    } catch (_) {
      return _fallbackJobTitles;
    }
  }

  // ── Get countries for dropdown ─────────────────────────────────────────────
  Future<List<Map<String, String>>> getCountries() async {
    try {
      final response = await _dio.get(
        '${ApiConstants.baseUrl}${ApiConstants.jobMatchingCountries}',
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return (data['countries'] as List? ?? [])
            .map((e) => Map<String, String>.from(e as Map))
            .toList();
      }
      return _fallbackCountries;
    } catch (_) {
      return _fallbackCountries;
    }
  }

  // ── Match jobs ─────────────────────────────────────────────────────────────
  /// POST multipart/form-data to /job-matching/match-jobs
  /// Returns top 5 matched jobs with scores and explanations.
  Future<List<JobEntity>> matchJobs({
    required String jobTitle,
    required String jobType, // "Full-time" / "Part-time"
    required String country, // Country name e.g. "Egypt"
    required String workMode, // "Remote" / "Onsite" / "Hybrid"
    required File cvFile,
  }) async {
    final formData = FormData.fromMap({
      'job_title': jobTitle,
      'job_type': jobType,
      'country': country,
      'work_mode': workMode,
      'cv_file': await MultipartFile.fromFile(
        cvFile.path,
        filename: cvFile.path.split('/').last,
      ),
    });

    final response = await _dio.post(
      '${ApiConstants.baseUrl}${ApiConstants.jobMatchingMatchJobs}',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
        // Override global timeout — LLM analysis can take up to 3 min
        sendTimeout: const Duration(minutes: 2),
        receiveTimeout: const Duration(minutes: 6),
      ),
    );

    final data = response.data as Map<String, dynamic>;
    if (data['success'] == true) {
      final matches = data['matches'] as List? ?? [];
      return matches
          .map((e) =>
              JobModel.fromMatchJson(e as Map<String, dynamic>).toEntity())
          .toList();
    }

    throw Exception(data['error'] ?? data['message'] ?? 'Job matching failed');
  }

  // ── Get saved jobs ─────────────────────────────────────────────────────────
  Future<List<JobEntity>> getSavedJobs() async {
    try {
      final response = await _dio.get(
        '${ApiConstants.baseUrl}${ApiConstants.jobMatchingSaved}',
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final saved = data['saved_jobs'] as List? ?? [];
        return saved
            .map((e) =>
                JobModel.fromSavedJson(e as Map<String, dynamic>).toEntity())
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ── Save a job ─────────────────────────────────────────────────────────────
  /// POST /job-matching/ with { job_data: {...} }
  // job_matching_repository.dart
  Future<String?> saveJob(JobEntity job) async {
    try {
      final payload = JobModel(
        id: job.id,
        title: job.title,
        company: job.company,
        location: job.location,
        workType: job.workType,
        workLocation: job.workLocation,
        jobUrl: job.jobUrl,
        jobDescription: job.jobDescription,
        postedAt: job.postedAt,
        rank: job.rank,
        matchScore: job.matchScore,
        explanation: job.explanation,
      ).toSavePayload();

      final response = await _dio.post(
        '${ApiConstants.baseUrl}${ApiConstants.jobMatchingSaved}',
        data: {'job_data': payload},
      );
      final data = response.data as Map<String, dynamic>;
      return data['id'] as String?; // ✅ رجّع الـ UUID الحقيقي
    } catch (_) {
      return null;
    }
  }

  // ── Unsave a job ───────────────────────────────────────────────────────────
  /// DELETE /job-matching/{job_id}
  Future<void> unsaveJob(String jobId) async {
    try {
      await _dio.delete(
        '${ApiConstants.baseUrl}${ApiConstants.jobMatchingDeleteSaved(jobId)}',
      );
    } catch (_) {}
  }

  Future<bool> hasUsedJobMatchingInCloud(String userId) async {
    try {
      final res = await _dio.get(
        '${ApiConstants.baseUrl}${ApiConstants.jobMatchingSaved}',
      );
      final data = res.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final saved = data['saved_jobs'] as List? ?? [];
        return saved.isNotEmpty;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ── Save match results to server ──────────────────────────────────────────
  Future<void> saveMatchResults(List<JobEntity> jobs) async {
    try {
      final results = jobs
          .map((j) => {
                'rank': j.rank,
                'job_title': j.title,
                'company': j.company,
                'location': j.location,
                'job_type': j.workType,
                'work_mode': j.workLocation,
                'link': j.jobUrl,
                'description_preview': j.jobDescription,
                'match_score': j.matchScore,
                'explanation': j.explanation,
              })
          .toList();

      await _dio.post(
        '${ApiConstants.baseUrl}${ApiConstants.jobMatchingResults}',
        data: {'results': results},
      );
    } catch (e) {
      // silent fail — الـ local cache هيكون موجود
      debugPrint('Failed to save results to server: $e');
    }
  }

// ── Get match results from server ─────────────────────────────────────────
  Future<List<JobEntity>> getMatchResults() async {
    try {
      final response = await _dio.get(
        '${ApiConstants.baseUrl}${ApiConstants.jobMatchingResults}',
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final results = data['results'] as List? ?? [];
        return results.map((e) {
          final jobData = e['job_data'] as Map<String, dynamic>? ?? {};
          return JobModel.fromResultJson(jobData, e['id'] as String? ?? '')
              .toEntity();
        }).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Failed to get results from server: $e');
      return [];
    }
  }

  // ── Fallback data ──────────────────────────────────────────────────────────
  static const List<String> _fallbackJobTitles = [
    'Data Analyst',
    'Machine Learning Engineer',
    'AI Engineer',
    'BI Engineer',
    'Data Engineer',
    'Backend Engineer',
    'Frontend Engineer',
    'Full Stack Engineer',
    'Software Engineer',
    'Mobile Engineer',
    'DevOps Engineer',
    'Cloud Engineer',
    'Cybersecurity Engineer',
    'Database Engineer',
    'Network Engineer',
  ];

  static const List<Map<String, String>> _fallbackCountries = [
    {'code': 'EG', 'name': 'Egypt'},
    {'code': 'SA', 'name': 'Saudi Arabia'},
    {'code': 'AE', 'name': 'United Arab Emirates'},
    {'code': 'KW', 'name': 'Kuwait'},
    {'code': 'US', 'name': 'United States'},
  ];
}

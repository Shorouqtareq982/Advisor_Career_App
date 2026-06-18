import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/constants/api_constants.dart';
import '../models/market_insights_models.dart';

class MarketInsightsRemoteDataSource {
  late final Dio _dio;

  MarketInsightsRemoteDataSource({Dio? dio}) {
    _dio = dio ??
        Dio(
          BaseOptions(
            baseUrl: ApiConstants.baseUrl,
            connectTimeout: ApiConstants.connectionTimeout,
            sendTimeout: ApiConstants.sendTimeout,
            receiveTimeout: ApiConstants.receiveTimeout,
            headers: const {
              'Accept': ApiConstants.contentType,
              'Content-Type': ApiConstants.contentType,
            },
          ),
        );

    _dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseHeader: false,
        responseBody: true,
        error: true,
        logPrint: (object) => debugPrint('[MARKET API] $object'),
      ),
    );
  }

  Future<List<String>> getJobs() async {
    try {
      debugPrint('[MARKET API] GET ${ApiConstants.marketJobs}');
      final response = await _dio.get(ApiConstants.marketJobs);
      final data = response.data;
      debugPrint('[MARKET API] jobs response: $data');
      if (data is Map<String, dynamic>)
        return MarketJobsResponse.fromJson(data).jobs;
      return [];
    } on DioException catch (e) {
      debugPrint('[MARKET API] getJobs DioException: ${e.message}');
      debugPrint('[MARKET API] getJobs status: ${e.response?.statusCode}');
      debugPrint('[MARKET API] getJobs response: ${e.response?.data}');
      rethrow;
    } catch (e) {
      debugPrint('[MARKET API] getJobs error: $e');
      rethrow;
    }
  }

  Future<MarketRunResponse> runBatch({
    int batchSize = 5,
    bool reset = false,
    bool asyncRun = false,
  }) async {
    try {
      debugPrint('[MARKET API] POST ${ApiConstants.marketRun}');
      final response = await _dio.post(
        ApiConstants.marketRun,
        queryParameters: {
          'batch_size': batchSize,
          'reset': reset,
          'async_run': asyncRun,
        },
      );
      final data = response.data;
      debugPrint('[MARKET API] runBatch response: $data');
      if (data is Map<String, dynamic>) return MarketRunResponse.fromJson(data);
      return const MarketRunResponse(status: '');
    } on DioException catch (e) {
      debugPrint('[MARKET API] runBatch DioException: ${e.message}');
      debugPrint('[MARKET API] runBatch status: ${e.response?.statusCode}');
      debugPrint('[MARKET API] runBatch response: ${e.response?.data}');
      rethrow;
    } catch (e) {
      debugPrint('[MARKET API] runBatch error: $e');
      rethrow;
    }
  }

  Future<MarketRunResponse> runJob(String job) async {
    try {
      final cleanJob = job.trim();
      debugPrint(
          '[MARKET API] POST ${ApiConstants.marketRunJob}?job=$cleanJob');
      final response = await _dio.post(
        ApiConstants.marketRunJob,
        queryParameters: {'job': cleanJob},
      );
      final data = response.data;
      debugPrint('[MARKET API] runJob response: $data');
      if (data is Map<String, dynamic>) return MarketRunResponse.fromJson(data);
      return const MarketRunResponse(status: '');
    } on DioException catch (e) {
      debugPrint('[MARKET API] runJob DioException: ${e.message}');
      debugPrint('[MARKET API] runJob status: ${e.response?.statusCode}');
      debugPrint('[MARKET API] runJob response: ${e.response?.data}');
      rethrow;
    } catch (e) {
      debugPrint('[MARKET API] runJob error: $e');
      rethrow;
    }
  }

  Future<MarketJobStatus> getJobStatus() async {
    try {
      debugPrint('[MARKET API] GET ${ApiConstants.marketJobStatus}');
      final response = await _dio.get(ApiConstants.marketJobStatus);
      final data = response.data;
      debugPrint('[MARKET API] jobStatus response: $data');
      if (data is Map<String, dynamic>) return MarketJobStatus.fromJson(data);
      return const MarketJobStatus(
          job: '', done: false, loading: false, rows: 0);
    } on DioException catch (e) {
      debugPrint('[MARKET API] getJobStatus DioException: ${e.message}');
      debugPrint('[MARKET API] getJobStatus status: ${e.response?.statusCode}');
      debugPrint('[MARKET API] getJobStatus response: ${e.response?.data}');
      rethrow;
    } catch (e) {
      debugPrint('[MARKET API] getJobStatus error: $e');
      rethrow;
    }
  }

  Future<MarketInsightsData> getMarketAnalytics({
    required String job,
    int? fallbackRows,
  }) async {
    try {
      final cleanJob = job.trim();
      debugPrint(
          '[MARKET API] GET ${ApiConstants.marketAnalytics}?job=$cleanJob');
      final response = await _dio.get(
        ApiConstants.marketAnalytics,
        queryParameters: {'job': cleanJob},
      );
      final data = response.data;
      debugPrint('[MARKET API] marketAnalytics response: $data');
      if (data is Map<String, dynamic>) {
        return MarketInsightsData.fromAnalyticsJson(
          data,
          fallbackJobTitle: cleanJob,
          fallbackRows: fallbackRows,
        );
      }
      throw Exception('Invalid market analytics response');
    } on DioException catch (e) {
      debugPrint('[MARKET API] marketAnalytics DioException: ${e.message}');
      debugPrint(
          '[MARKET API] marketAnalytics status: ${e.response?.statusCode}');
      debugPrint('[MARKET API] marketAnalytics response: ${e.response?.data}');
      rethrow;
    } catch (e) {
      debugPrint('[MARKET API] marketAnalytics error: $e');
      rethrow;
    }
  }

  Future<MarketSystemStatus> getSystemStatus() async {
    try {
      debugPrint('[MARKET API] GET ${ApiConstants.marketStatus}');
      final response = await _dio.get(ApiConstants.marketStatus);
      final data = response.data;
      debugPrint('[MARKET API] systemStatus response: $data');
      if (data is Map<String, dynamic>)
        return MarketSystemStatus.fromJson(data);
      return const MarketSystemStatus(
        jobIndex: 0,
        lastRun: null,
        totalJobs: 0,
        scrapingRunning: false,
        batchRunning: false,
      );
    } on DioException catch (e) {
      debugPrint('[MARKET API] getSystemStatus DioException: ${e.message}');
      debugPrint(
          '[MARKET API] getSystemStatus status: ${e.response?.statusCode}');
      debugPrint('[MARKET API] getSystemStatus response: ${e.response?.data}');
      rethrow;
    } catch (e) {
      debugPrint('[MARKET API] getSystemStatus error: $e');
      rethrow;
    }
  }

  Future<MarketRunResponse> resetJob(String job) async {
    try {
      final cleanJob = job.trim();
      debugPrint(
          '[MARKET API] POST ${ApiConstants.marketResetJob}?job=$cleanJob');
      final response = await _dio.post(
        ApiConstants.marketResetJob,
        queryParameters: {'job': cleanJob},
      );
      final data = response.data;
      debugPrint('[MARKET API] resetJob response: $data');
      if (data is Map<String, dynamic>) return MarketRunResponse.fromJson(data);
      return const MarketRunResponse(status: '');
    } on DioException catch (e) {
      debugPrint('[MARKET API] resetJob DioException: ${e.message}');
      debugPrint('[MARKET API] resetJob status: ${e.response?.statusCode}');
      debugPrint('[MARKET API] resetJob response: ${e.response?.data}');
      rethrow;
    } catch (e) {
      debugPrint('[MARKET API] resetJob error: $e');
      rethrow;
    }
  }

  Future<String> resetSystem() async {
    try {
      debugPrint('[MARKET API] POST ${ApiConstants.marketReset}');
      final response = await _dio.post(ApiConstants.marketReset);
      final data = response.data;
      debugPrint('[MARKET API] resetSystem response: $data');
      if (data is Map<String, dynamic>)
        return data['message']?.toString() ?? '';
      return '';
    } on DioException catch (e) {
      debugPrint('[MARKET API] resetSystem DioException: ${e.message}');
      debugPrint('[MARKET API] resetSystem status: ${e.response?.statusCode}');
      debugPrint('[MARKET API] resetSystem response: ${e.response?.data}');
      rethrow;
    } catch (e) {
      debugPrint('[MARKET API] resetSystem error: $e');
      rethrow;
    }
  }
}

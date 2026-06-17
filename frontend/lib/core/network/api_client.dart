import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/api_constants.dart';
import 'interceptors/auth_interceptor.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  late final Dio dio;
  final SupabaseClient _supabase = Supabase.instance.client;

  void init() {
    dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(minutes: 2),
      receiveTimeout: const Duration(minutes: 6),
      headers: {
        'Content-Type': ApiConstants.contentType,
        'Accept': ApiConstants.accept,
      },
    ));

    dio.interceptors.add(AuthInterceptor(_supabase));

    dio.interceptors.add(LogInterceptor(
      request: true,
      requestHeader: true,
      requestBody: true,
      responseHeader: true,
      responseBody: true,
      error: true,
    ));
  }

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      return await dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      return await dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      return await dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Exception _handleError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return Exception('Connection timeout. Please try again.');

      case DioExceptionType.badResponse:
        if (error.response?.statusCode == 401) {
          return Exception('Unauthorized: Please login again.');
        } else if (error.response?.statusCode == 403) {
          return Exception('Forbidden: You don\'t have permission.');
        } else if (error.response?.statusCode == 404) {
          return Exception('Not found.');
        } else if (error.response?.statusCode == 500) {
          return Exception('Server error. Please try again later.');
        }
        return Exception(
            'Error: ${error.response?.data['message'] ?? error.message}');

      case DioExceptionType.cancel:
        return Exception('Request cancelled.');

      case DioExceptionType.connectionError:
        return Exception('No internet connection.');

      default:
        return Exception('Something went wrong. Please try again.');
    }
  }

  Future<bool> verifyToken() async {
    try {
      final response = await post(ApiConstants.verifyToken);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

final apiClient = ApiClient();

import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../constants/api_constants.dart';

class AuthInterceptor extends Interceptor {
  final SupabaseClient _supabase;

  AuthInterceptor(this._supabase);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    final session = _supabase.auth.currentSession;
    final token = session?.accessToken;

    print(' [AuthInterceptor] Token found: ${token != null}');

    if (token != null) {
      options.headers[ApiConstants.authorization] =
          '${ApiConstants.bearer} $token';
      print('[AuthInterceptor] Token added to request: ${options.path}');
    } else {
      print('AuthInterceptor] No token found for request: ${options.path}');
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      print('[AuthInterceptor] Token expired or invalid (401)');

      // _refreshToken();
    }

    handler.next(err);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    print(
      '📡 [AuthInterceptor] Response ${response.statusCode}: ${response.requestOptions.path}',
    );
    handler.next(response);
  }

  Future<void> _refreshToken() async {
    try {
      final refreshToken = _supabase.auth.currentSession?.refreshToken;
      if (refreshToken != null) {}
    } catch (e) {
      print('[AuthInterceptor] Error refreshing token: $e');
    }
  }
}

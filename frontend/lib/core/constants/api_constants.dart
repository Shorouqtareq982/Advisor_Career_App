class ApiConstants {
  // Base URL
  static const String baseUrl = 'http://192.168.1.18:8000';

  // Auth endpoints
  static const String verifyToken = '/auth/verify';

  // CV Optimization endpoints
  static const String cvOptimization = '/api/v1/cv_optimization';
  static const String analyze = '$cvOptimization/analyze';
  static const String analyzeSaved = '$cvOptimization/analyze/'; // + cv_id
  static const String reports = '$cvOptimization/reports';
  static const String report = '$cvOptimization/report'; // + /{report_id}

  // Headers
  static const String authorization = 'Authorization';
  static const String bearer = 'Bearer';
  static const String contentType = 'application/json';
  static const String accept = 'application/json';

  // Timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(minutes: 2);
  static const Duration receiveTimeout = Duration(minutes: 2);
}

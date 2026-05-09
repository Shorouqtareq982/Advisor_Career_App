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

  // ===============================
  // Career Builder
  // ===============================
  static const String careerBuilder = '/api/v1/career';

  static const String careerTracks = '$careerBuilder/tracks';
  static const String careerAnalyze = '$careerBuilder/analyze';
  static const String careerConfirmSkills = '$careerBuilder/confirm-skills';
  static const String careerConfirmTimePreview =
      '$careerBuilder/confirm-time-preview';
  static const String careerConfirmTime = '$careerBuilder/confirm-time';
  static const String careerGeneratePlan = '$careerBuilder/generate-plan';
  static const String careerRegeneratePlan = '$careerBuilder/regenerate-plan';
  static const String careerRegenerationIntents =
      '$careerBuilder/regeneration-intents';
  static const String careerSavePlan = '$careerBuilder/save-plan';

  // (اختياري لو عندك endpoint)
  static const String careerGetPlans = '$careerBuilder/plans';

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

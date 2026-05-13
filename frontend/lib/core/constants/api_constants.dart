class ApiConstants {
  // Base URL
  static const String baseUrl = 'http://192.168.1.7:8000';

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
  static const String careerGetPlans = '$careerBuilder/plans';

  // ===============================
  // AI Portfolio
  // ===============================
  static const String aiPortfolio = '/api/v1/portfolio';

  static const String portfolioTemplates = '$aiPortfolio/templates';

  static String portfolioPreviewTemplate(int templateId) {
    return '$aiPortfolio/preview_template/$templateId';
  }

  static const String portfolioUploadImage = '$aiPortfolio/upload-image';

  static const String portfolioCreate = '$aiPortfolio/';

  static String portfolioById(String portfolioId) {
    return '$aiPortfolio/$portfolioId';
  }

  static String portfolioPreview(String portfolioId) {
    return '$aiPortfolio/preview/$portfolioId';
  }

  static const String userPortfolios = '$aiPortfolio/user/';

  static const String lastSavedPortfolioData = '$aiPortfolio/last_saved_data';

  static String publishPortfolio(String portfolioId) {
    return '$aiPortfolio/$portfolioId/publish';
  }

  static String unpublishPortfolio(String portfolioId) {
    return '$aiPortfolio/$portfolioId/unpublish';
  }

  static String exportPortfolioPdf(String portfolioId) {
    return '$aiPortfolio/$portfolioId/export/pdf';
  }

  // ===============================
  // Market Insights
  // ===============================
  static const String marketInsights = '/api/v1/market';

  static const String marketJobs = '$marketInsights/jobs';
  static const String marketRun = '$marketInsights/run';
  static const String marketRunJob = '$marketInsights/run-job';
  static const String marketStatus = '$marketInsights/status';
  static const String marketJobStatus = '$marketInsights/job-status';
  static const String marketReset = '$marketInsights/reset';
  static const String marketResetJob = '$marketInsights/reset-job';

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

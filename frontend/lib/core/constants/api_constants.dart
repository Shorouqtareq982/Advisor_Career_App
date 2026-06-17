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
  // Mock Interview
  // ===============================
  static const String mockInterview = '/api/v1/mock-interview';

  static const String mockInterviewStartBehavioral =
      '$mockInterview/sessions/start/behavioral';
  static const String mockInterviewStartTechnical =
      '$mockInterview/sessions/start/technical';
  static const String mockInterviewNotifyUpload =
      '$mockInterview/notify-upload';

  static String mockInterviewAudioStream(String questionId) =>
      '$mockInterview/questions/$questionId/audio-stream';

  static String mockInterviewBehavioralReport(String sessionId) =>
      '$mockInterview/analysis/$sessionId/behavioral-report';

  static String mockInterviewTechnicalReport(String sessionId) =>
      '$mockInterview/analysis/$sessionId/technical-report';

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
  static const String marketAnalytics = '$marketInsights/market';

  // ===============================
  // Job Matching
  // ===============================
  static const String jobMatching = '/api/v1/job-matching';

  /// POST multipart/form-data → returns top 5 matched jobs
  static const String jobMatchingMatchJobs = '$jobMatching/match-jobs';

  /// GET  → list of saved jobs  |  POST → save a job
  static const String jobMatchingSaved = '$jobMatching/';

  /// DELETE /job-matching/{job_id}
  static String jobMatchingDeleteSaved(String jobId) => '$jobMatching/$jobId';

  /// GET → list of job titles for dropdown
  static const String jobMatchingJobTitles = '$jobMatching/job-titles';

  /// GET → list of countries for dropdown
  static const String jobMatchingCountries = '$jobMatching/countries';

  /// GET → جيب نتايج الماتش  |  POST → احفظ نتايج الماتش
  static const String jobMatchingResults = '$jobMatching/results';

  // Headers
  static const String authorization = 'Authorization';
  static const String bearer = 'Bearer';
  static const String contentType = 'application/json';
  static const String accept = 'application/json';

  // Timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(minutes: 2);
  static const Duration receiveTimeout = Duration(minutes: 6);
}

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/market_insights_remote_datasource.dart';
import '../../data/models/market_insights_models.dart';

final marketInsightsRemoteDataSourceProvider =
    Provider<MarketInsightsRemoteDataSource>(
  (ref) => MarketInsightsRemoteDataSource(),
);

final marketInsightsProvider =
    StateNotifierProvider<MarketInsightsNotifier, MarketInsightsState>(
  (ref) {
    final remoteDataSource = ref.watch(marketInsightsRemoteDataSourceProvider);
    return MarketInsightsNotifier(remoteDataSource);
  },
);

class MarketInsightsState {
  final String query;
  final List<String> jobs;
  final bool showSuggestions;
  final bool isLoadingJobs;
  final bool isSubmitting;
  final bool isRefreshing;
  final bool isPolling;
  final bool isLoadingAnalytics;
  final String? errorMessage;
  final int animationSeed;
  final MarketInsightsData? data;
  final MarketJobStatus? jobStatus;
  final MarketSystemStatus? systemStatus;

  const MarketInsightsState({
    this.query = '',
    this.jobs = const [],
    this.showSuggestions = false,
    this.isLoadingJobs = false,
    this.isSubmitting = false,
    this.isRefreshing = false,
    this.isPolling = false,
    this.isLoadingAnalytics = false,
    this.errorMessage,
    this.animationSeed = 0,
    this.data,
    this.jobStatus,
    this.systemStatus,
  });

  bool get hasData => data != null;

  bool get isBusy =>
      isSubmitting || isRefreshing || isPolling || isLoadingAnalytics;

  List<String> get filteredSuggestions {
    final trimmed = query.trim().toLowerCase();

    if (trimmed.isEmpty) return jobs;

    final startsWithMatches =
        jobs.where((item) => item.toLowerCase().startsWith(trimmed)).toList();

    final containsMatches = jobs
        .where(
          (item) =>
              item.toLowerCase().contains(trimmed) &&
              !startsWithMatches.contains(item),
        )
        .toList();

    return [...startsWithMatches, ...containsMatches];
  }

  MarketInsightsState copyWith({
    String? query,
    List<String>? jobs,
    bool? showSuggestions,
    bool? isLoadingJobs,
    bool? isSubmitting,
    bool? isRefreshing,
    bool? isPolling,
    bool? isLoadingAnalytics,
    String? errorMessage,
    bool clearError = false,
    int? animationSeed,
    MarketInsightsData? data,
    bool clearData = false,
    MarketJobStatus? jobStatus,
    MarketSystemStatus? systemStatus,
  }) {
    return MarketInsightsState(
      query: query ?? this.query,
      jobs: jobs ?? this.jobs,
      showSuggestions: showSuggestions ?? this.showSuggestions,
      isLoadingJobs: isLoadingJobs ?? this.isLoadingJobs,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isPolling: isPolling ?? this.isPolling,
      isLoadingAnalytics: isLoadingAnalytics ?? this.isLoadingAnalytics,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      animationSeed: animationSeed ?? this.animationSeed,
      data: clearData ? null : (data ?? this.data),
      jobStatus: jobStatus ?? this.jobStatus,
      systemStatus: systemStatus ?? this.systemStatus,
    );
  }
}

class MarketInsightsNotifier extends StateNotifier<MarketInsightsState> {
  final MarketInsightsRemoteDataSource _remoteDataSource;

  MarketInsightsNotifier(this._remoteDataSource)
      : super(const MarketInsightsState()) {
    loadJobs();
    loadSystemStatus();
  }

  Future<void> loadJobs() async {
    debugPrint('[MARKET PROVIDER] loadJobs started');

    state = state.copyWith(
      isLoadingJobs: true,
      clearError: true,
    );

    try {
      final jobs = await _remoteDataSource.getJobs();
      debugPrint('[MARKET PROVIDER] loadJobs success: ${jobs.length} jobs');

      state = state.copyWith(
        jobs: jobs.isEmpty ? _fallbackBackendTracks : jobs,
        isLoadingJobs: false,
        clearError: true,
      );
    } catch (e) {
      debugPrint('[MARKET PROVIDER] loadJobs error: $e');

      state = state.copyWith(
        jobs: _fallbackBackendTracks,
        isLoadingJobs: false,
        errorMessage:
            'Could not load tracks from server. Showing default tracks. Error: $e',
      );
    }
  }

  Future<void> loadSystemStatus() async {
    try {
      final systemStatus = await _remoteDataSource.getSystemStatus();
      state = state.copyWith(systemStatus: systemStatus);
    } catch (e) {
      debugPrint('[MARKET PROVIDER] loadSystemStatus ignored error: $e');
    }
  }

  void resetForEntry() {
    debugPrint('[MARKET PROVIDER] resetForEntry');

    state = state.copyWith(
      query: '',
      showSuggestions: false,
      isSubmitting: false,
      isRefreshing: false,
      isPolling: false,
      isLoadingAnalytics: false,
      clearData: true,
      clearError: true,
    );

    if (state.jobs.isEmpty && !state.isLoadingJobs) loadJobs();
  }

  void setQuery(String value) {
    state = state.copyWith(
      query: value,
      showSuggestions: true,
      clearError: true,
    );
  }

  void showSuggestions() {
    if (state.hasData) return;
    if (state.jobs.isEmpty && !state.isLoadingJobs) loadJobs();
    state = state.copyWith(showSuggestions: true);
  }

  void hideSuggestions() {
    state = state.copyWith(showSuggestions: false);
  }

  void selectSuggestion(String title) {
    debugPrint('[MARKET PROVIDER] selected suggestion: $title');
    state = state.copyWith(
      query: title,
      showSuggestions: false,
      clearError: true,
    );
  }

  Future<void> submit() async {
    final query = state.query.trim();
    debugPrint('[MARKET PROVIDER] submit pressed with query="$query"');

    if (query.isEmpty || state.isBusy) return;

    state = state.copyWith(
      isSubmitting: true,
      isPolling: false,
      isLoadingAnalytics: false,
      showSuggestions: false,
      clearData: true,
      clearError: true,
    );

    try {
      final runResponse = await _remoteDataSource.runJob(query);
      debugPrint(
        '[MARKET PROVIDER] runJob success: '
        'status=${runResponse.status}, job=${runResponse.job}',
      );

      state = state.copyWith(
        isSubmitting: false,
        isPolling: true,
        clearError: true,
      );

      await _pollJobStatus(fallbackJobTitle: query);
    } catch (e) {
      debugPrint('[MARKET PROVIDER] runJob failed: $e');
      state = state.copyWith(
        isSubmitting: false,
        isPolling: false,
        isLoadingAnalytics: false,
        errorMessage: 'Could not start market insights. Error: $e',
      );
    }
  }

  Future<void> refresh() async {
    final currentData = state.data;
    final currentQuery = currentData?.jobTitle.trim().isNotEmpty == true
        ? currentData!.jobTitle
        : state.query.trim();

    debugPrint('[MARKET PROVIDER] refresh pressed with query="$currentQuery"');

    if (currentQuery.isEmpty || state.isBusy) return;

    state = state.copyWith(
      isRefreshing: true,
      isPolling: false,
      isLoadingAnalytics: false,
      clearError: true,
    );

    try {
      final resetResponse = await _remoteDataSource.resetJob(currentQuery);
      debugPrint(
        '[MARKET PROVIDER] resetJob success: '
        'status=${resetResponse.status}, job=${resetResponse.job}',
      );

      final runResponse = await _remoteDataSource.runJob(currentQuery);
      debugPrint(
        '[MARKET PROVIDER] runJob after reset success: '
        'status=${runResponse.status}, job=${runResponse.job}',
      );

      state = state.copyWith(
        isRefreshing: false,
        isPolling: true,
        clearError: true,
      );

      await _pollJobStatus(fallbackJobTitle: currentQuery);
    } catch (e) {
      debugPrint('[MARKET PROVIDER] refresh failed: $e');
      state = state.copyWith(
        isRefreshing: false,
        isPolling: false,
        isLoadingAnalytics: false,
        errorMessage: 'Could not refresh market insights. Error: $e',
      );
    }
  }

  Future<void> _pollJobStatus({required String fallbackJobTitle}) async {
    const maxAttempts = 120;
    const delay = Duration(seconds: 2);

    debugPrint('[MARKET PROVIDER] polling started for "$fallbackJobTitle"');

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      if (!mounted) return;

      try {
        final status = await _remoteDataSource.getJobStatus();
        debugPrint(
          '[MARKET PROVIDER] poll #$attempt: '
          'job=${status.job}, done=${status.done}, '
          'loading=${status.loading}, rows=${status.rows}',
        );

        if (!mounted) return;

        state = state.copyWith(
          jobStatus: status,
          clearError: true,
        );

        if (status.done && !status.loading) {
          final safeStatus = MarketJobStatus(
            job: status.job.trim().isEmpty ? fallbackJobTitle : status.job,
            done: status.done,
            loading: status.loading,
            rows: status.rows,
          );

          await _loadAnalyticsAfterCrawler(
            status: safeStatus,
            fallbackJobTitle: fallbackJobTitle,
          );

          await loadSystemStatus();
          return;
        }

        await Future.delayed(delay);
      } catch (e) {
        debugPrint('[MARKET PROVIDER] polling failed: $e');
        if (!mounted) return;

        state = state.copyWith(
          isPolling: false,
          isLoadingAnalytics: false,
          errorMessage: 'Could not read job status. Error: $e',
        );
        return;
      }
    }

    if (!mounted) return;

    state = state.copyWith(
      isPolling: false,
      isLoadingAnalytics: false,
      errorMessage: 'Market insights is taking longer than expected.',
    );
  }

  Future<void> _loadAnalyticsAfterCrawler({
    required MarketJobStatus status,
    required String fallbackJobTitle,
  }) async {
    if (!mounted) return;

    state = state.copyWith(
      isPolling: false,
      isLoadingAnalytics: true,
      jobStatus: status,
      clearError: true,
    );

    try {
      final analytics = await _remoteDataSource.getMarketAnalytics(
        job: status.job.trim().isEmpty ? fallbackJobTitle : status.job,
        fallbackRows: status.rows,
      );

      if (!mounted) return;

      state = state.copyWith(
        isLoadingAnalytics: false,
        animationSeed: state.animationSeed + 1,
        jobStatus: status,
        data: analytics,
        clearError: true,
      );

      debugPrint(
        '[MARKET PROVIDER] analytics loaded: '
        'job=${analytics.jobTitle}, '
        'jobs=${analytics.jobOpenings}, '
        'skills=${analytics.topSkills.length}, '
        'govs=${analytics.topGovernorates.length}, '
        'months=${analytics.yearlyDemand.length}',
      );
    } catch (e) {
      debugPrint('[MARKET PROVIDER] analytics failed: $e');
      if (!mounted) return;

      state = state.copyWith(
        isLoadingAnalytics: false,
        animationSeed: state.animationSeed + 1,
        jobStatus: status,
        data: MarketInsightsData.fromJobStatus(status),
        errorMessage:
            'Crawler finished, but analytics could not be loaded. Error: $e',
      );
    }
  }

  void changeRole() {
    debugPrint('[MARKET PROVIDER] changeRole');

    state = state.copyWith(
      query: '',
      clearData: true,
      showSuggestions: false,
      isSubmitting: false,
      isRefreshing: false,
      isPolling: false,
      isLoadingAnalytics: false,
      clearError: true,
    );
  }
}

const List<String> _fallbackBackendTracks = [
  'Backend Development',
  'Frontend Development',
  'Full Stack Development',
  'Mobile Development',
  'Data Science & Analytics',
  'DevOps & Cloud Engineering',
  'System Architecture',
  'Network Engineering',
  'Cybersecurity',
  'Quality Assurance & Testing',
  'IT Support & Administration',
  'Research & Development',
  'Hardware Engineering',
  'IT Management & Leadership',
  'AI Engineering',
  'Machine Learning Engineering',
  'Data Engineering',
  'Business Intelligence',
  'Product Management - Tech',
  'UI/UX Design',
  'Game Development',
  'Embedded Systems & IoT',
  'AR/VR & Spatial Computing',
  'Cloud Architecture',
  'AI Research',
  'Quantitative Finance & FinTech',
  'Digital Marketing & Analytics',
  'Data Governance & Quality',
  'Automation & Scripting',
  'Robotics Engineering',
  'Game AI & Simulation',
  'Technical Writing',
  'Low-Code / No-Code Development',
];

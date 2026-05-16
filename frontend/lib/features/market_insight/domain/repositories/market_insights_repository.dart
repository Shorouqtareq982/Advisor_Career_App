import '../../data/models/market_insights_models.dart';

abstract class MarketInsightsRepository {
  Future<List<String>> getJobs();

  Future<MarketRunResponse> runBatch({
    int batchSize,
    bool reset,
    bool asyncRun,
  });

  Future<MarketRunResponse> runJob(String job);

  Future<MarketJobStatus> getJobStatus();

  Future<MarketInsightsData> getMarketAnalytics({
    required String job,
    int? fallbackRows,
  });

  Future<MarketSystemStatus> getSystemStatus();

  Future<MarketRunResponse> resetJob(String job);

  Future<String> resetSystem();
}

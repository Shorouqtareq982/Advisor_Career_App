import '../../domain/repositories/market_insights_repository.dart';
import '../datasources/market_insights_remote_datasource.dart';
import '../models/market_insights_models.dart';

class MarketInsightsRepositoryImpl implements MarketInsightsRepository {
  final MarketInsightsRemoteDataSource remoteDataSource;

  const MarketInsightsRepositoryImpl({
    required this.remoteDataSource,
  });

  @override
  Future<List<String>> getJobs() {
    return remoteDataSource.getJobs();
  }

  @override
  Future<MarketRunResponse> runBatch({
    int batchSize = 5,
    bool reset = false,
    bool asyncRun = false,
  }) {
    return remoteDataSource.runBatch(
      batchSize: batchSize,
      reset: reset,
      asyncRun: asyncRun,
    );
  }

  @override
  Future<MarketRunResponse> runJob(String job) {
    return remoteDataSource.runJob(job);
  }

  @override
  Future<MarketJobStatus> getJobStatus() {
    return remoteDataSource.getJobStatus();
  }

  @override
  Future<MarketInsightsData> getMarketAnalytics({
    required String job,
    int? fallbackRows,
  }) {
    return remoteDataSource.getMarketAnalytics(
      job: job,
      fallbackRows: fallbackRows,
    );
  }

  @override
  Future<MarketSystemStatus> getSystemStatus() {
    return remoteDataSource.getSystemStatus();
  }

  @override
  Future<MarketRunResponse> resetJob(String job) {
    return remoteDataSource.resetJob(job);
  }

  @override
  Future<String> resetSystem() {
    return remoteDataSource.resetSystem();
  }
}

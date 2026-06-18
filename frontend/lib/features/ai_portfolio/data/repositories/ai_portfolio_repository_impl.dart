import 'dart:typed_data';

import '../../domain/repositories/ai_portfolio_repository.dart';
import '../datasources/ai_portfolio_remote_datasource.dart';
import '../models/ai_portfolio_model.dart';

class AIPortfolioRepositoryImpl implements AIPortfolioRepository {
  final AIPortfolioRemoteDataSource remoteDataSource;

  const AIPortfolioRepositoryImpl({
    required this.remoteDataSource,
  });

  @override
  Future<List<PortfolioTemplateModel>> getTemplates() {
    return remoteDataSource.getTemplates();
  }

  @override
  Future<String> previewTemplate(int templateId) {
    return remoteDataSource.previewTemplate(templateId);
  }

  @override
  Future<PortfolioImageUploadResponseModel> uploadImage({
    required Uint8List bytes,
    required String fileName,
  }) {
    return remoteDataSource.uploadImage(
      bytes: bytes,
      fileName: fileName,
    );
  }

  @override
  Future<AIPortfolioResponseModel> createPortfolio(
    AIPortfolioRequestModel request,
  ) {
    return remoteDataSource.createPortfolio(request);
  }

  @override
  Future<AIPortfolioResponseModel> updatePortfolio({
    required String portfolioId,
    required AIPortfolioRequestModel request,
  }) {
    return remoteDataSource.updatePortfolio(
      portfolioId: portfolioId,
      request: request,
    );
  }

  @override
  Future<AIPortfolioResponseModel> getPortfolio(String portfolioId) {
    return remoteDataSource.getPortfolio(portfolioId);
  }

  @override
  Future<AIPortfolioActionResponseModel> deletePortfolio(String portfolioId) {
    return remoteDataSource.deletePortfolio(portfolioId);
  }

  @override
  Future<List<AIPortfolioSummaryModel>> getUserPortfolios() {
    return remoteDataSource.getUserPortfolios();
  }

  @override
  Future<LastSavedPortfolioDataModel> getLastSavedPortfolioData() {
    return remoteDataSource.getLastSavedPortfolioData();
  }

  @override
  Future<String> previewPortfolio(String portfolioId) {
    return remoteDataSource.previewPortfolio(portfolioId);
  }

  @override
  Future<String> publishPortfolio(String portfolioId) {
    return remoteDataSource.publishPortfolio(portfolioId);
  }

  @override
  Future<AIPortfolioActionResponseModel> unpublishPortfolio(
    String portfolioId,
  ) {
    return remoteDataSource.unpublishPortfolio(portfolioId);
  }

  @override
  Future<AIPortfolioPdfExportResponseModel> exportPortfolioPdf(
    String portfolioId,
  ) {
    return remoteDataSource.exportPortfolioPdf(portfolioId);
  }
}

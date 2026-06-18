import 'dart:typed_data';

import '../../data/models/ai_portfolio_model.dart';

abstract class AIPortfolioRepository {
  Future<List<PortfolioTemplateModel>> getTemplates();

  Future<String> previewTemplate(int templateId);

  Future<PortfolioImageUploadResponseModel> uploadImage({
    required Uint8List bytes,
    required String fileName,
  });

  Future<AIPortfolioResponseModel> createPortfolio(
    AIPortfolioRequestModel request,
  );

  Future<AIPortfolioResponseModel> updatePortfolio({
    required String portfolioId,
    required AIPortfolioRequestModel request,
  });

  Future<AIPortfolioResponseModel> getPortfolio(String portfolioId);

  Future<AIPortfolioActionResponseModel> deletePortfolio(String portfolioId);

  Future<List<AIPortfolioSummaryModel>> getUserPortfolios();

  Future<LastSavedPortfolioDataModel> getLastSavedPortfolioData();

  Future<String> previewPortfolio(String portfolioId);

  Future<String> publishPortfolio(String portfolioId);

  Future<AIPortfolioActionResponseModel> unpublishPortfolio(
    String portfolioId,
  );

  Future<AIPortfolioPdfExportResponseModel> exportPortfolioPdf(
    String portfolioId,
  );
}

import '../../data/models/ai_portfolio_model.dart';
import '../repositories/ai_portfolio_repository.dart';

class SaveCoverSectionUseCase {
  final AIPortfolioRepository repository;

  const SaveCoverSectionUseCase(this.repository);

  Future<AIPortfolioResponseModel> call({
    required AIPortfolioRequestModel request,
    String? portfolioId,
  }) {
    if (portfolioId == null || portfolioId.trim().isEmpty) {
      return repository.createPortfolio(request);
    }

    return repository.updatePortfolio(
      portfolioId: portfolioId,
      request: request,
    );
  }
}

import '../repositories/ai_portfolio_repository.dart';

class DeletePortfolioUseCase {
  final AIPortfolioRepository repository;

  const DeletePortfolioUseCase(this.repository);

  Future<bool> call(String portfolioId) async {
    final result = await repository.deletePortfolio(portfolioId);
    return result.success;
  }
}

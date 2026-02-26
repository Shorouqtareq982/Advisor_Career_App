import '../entities/alert_entity.dart';
import '../repositories/alerts_repository.dart';

class GetAlerts {
  final AlertsRepository repo;
  GetAlerts(this.repo);

  Future<List<AlertEntity>> call() => repo.getAlerts();
}

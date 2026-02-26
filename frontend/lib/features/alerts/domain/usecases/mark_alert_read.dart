import '../entities/alert_entity.dart';
import '../repositories/alerts_repository.dart';

class MarkAlertRead {
  final AlertsRepository repo;
  MarkAlertRead(this.repo);

  Future<List<AlertEntity>> call(String id) => repo.markRead(id);
}

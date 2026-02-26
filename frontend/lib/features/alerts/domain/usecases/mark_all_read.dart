import '../entities/alert_entity.dart';
import '../repositories/alerts_repository.dart';

class MarkAllRead {
  final AlertsRepository repo;
  MarkAllRead(this.repo);

  Future<List<AlertEntity>> call() => repo.markAllRead();
}

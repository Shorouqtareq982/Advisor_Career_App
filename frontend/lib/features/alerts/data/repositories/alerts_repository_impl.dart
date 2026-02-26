import '../../domain/entities/alert_entity.dart';
import '../../domain/repositories/alerts_repository.dart';
import '../datasources/alerts_local_datasource.dart';

class AlertsRepositoryImpl implements AlertsRepository {
  final AlertsLocalDataSource local;
  AlertsRepositoryImpl(this.local);

  @override
  Future<List<AlertEntity>> getAlerts() => local.fetchAlerts();

  @override
  Future<List<AlertEntity>> markAllRead() => local.markAllRead();

  @override
  Future<List<AlertEntity>> markRead(String id) => local.markRead(id);
}

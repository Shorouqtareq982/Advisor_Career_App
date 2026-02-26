import '../entities/alert_entity.dart';

abstract class AlertsRepository {
  Future<List<AlertEntity>> getAlerts();
  Future<List<AlertEntity>> markAllRead();
  Future<List<AlertEntity>> markRead(String id);
}

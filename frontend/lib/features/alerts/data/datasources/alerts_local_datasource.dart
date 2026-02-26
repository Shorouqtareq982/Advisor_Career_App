import '../../domain/entities/alert_entity.dart';
import '../models/alert_model.dart';

abstract class AlertsLocalDataSource {
  Future<List<AlertModel>> fetchAlerts();
  Future<List<AlertModel>> markAllRead();
  Future<List<AlertModel>> markRead(String id);

  //     optional: عشان تختبري "مرن"
  Future<List<AlertModel>> addAlert(AlertModel alert);
}

class AlertsLocalDataSourceImpl implements AlertsLocalDataSource {
  final List<AlertModel> _cache = [
    AlertModel(
      id: '1',
      title: 'Resume Optimization',
      body: 'Your resume has been optimized with AI suggestions',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      isRead: false,
      type: AlertType.resume,
    ),
    AlertModel(
      id: '2',
      title: 'Job Matches Updated',
      body: '12 new jobs match your profile - Senior Developer at Tech Corp',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      isRead: false,
      type: AlertType.jobs,
    ),
    AlertModel(
      id: '3',
      title: 'Interview feedback',
      body: 'AI feedback on your recent interview is available',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      isRead: false,
      type: AlertType.interview,
    ),
    AlertModel(
      id: '4',
      title: 'Career Plan',
      body: 'View your next steps and growth recommendations',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      isRead: true,
      type: AlertType.plan,
    ),
  ];

  @override
  Future<List<AlertModel>> fetchAlerts() async {
    await Future.delayed(const Duration(milliseconds: 120));
    _cache.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List<AlertModel>.from(_cache);
  }

  @override
  Future<List<AlertModel>> markAllRead() async {
    for (int i = 0; i < _cache.length; i++) {
      _cache[i] = _cache[i].copyWith(isRead: true);
    }
    return fetchAlerts();
  }

  @override
  Future<List<AlertModel>> markRead(String id) async {
    final idx = _cache.indexWhere((a) => a.id == id);
    if (idx != -1) {
      _cache[idx] = _cache[idx].copyWith(isRead: true);
    }
    return fetchAlerts();
  }

  @override
  Future<List<AlertModel>> addAlert(AlertModel alert) async {
    _cache.add(alert);
    return fetchAlerts();
  }
}

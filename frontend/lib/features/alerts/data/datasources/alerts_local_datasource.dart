import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/alert_entity.dart';
import '../models/alert_model.dart';
import 'dart:async';

class AlertsNotifier {
  AlertsNotifier._();
  static final AlertsNotifier instance = AlertsNotifier._();

  final _controller = StreamController<void>.broadcast();
  Stream<void> get onAlertsChanged => _controller.stream;

  void notify() => _controller.add(null);

  void dispose() => _controller.close();
}

abstract class AlertsLocalDataSource {
  Future<List<AlertModel>> fetchAlerts();
  Future<List<AlertModel>> markAllRead();
  Future<List<AlertModel>> markRead(String id);
  Future<List<AlertModel>> addAlert(AlertModel alert);
}

class AlertsLocalDataSourceImpl implements AlertsLocalDataSource {
  static const String _cacheKey = 'growza_alerts_cache';
  final SupabaseClient _supabase = Supabase.instance.client;

  String? get _userId => _supabase.auth.currentUser?.id;

  // ─── Supabase ────────────────────────────────────────────────────────────────

  Future<List<AlertModel>> _fetchFromSupabase() async {
    final uid = _userId;
    if (uid == null) return [];
    final res = await _supabase
        .from('user_alerts')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false);
    return (res as List)
        .map((e) => AlertModel.fromSupabase(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _upsertToSupabase(AlertModel alert) async {
    final uid = _userId;
    if (uid == null) return;
    await _supabase.from('user_alerts').upsert({
      'id': alert.id,
      'user_id': uid,
      'title': alert.title,
      'body': alert.body,
      'type': alert.type.toString().split('.').last,
      'route': alert.route,
      'is_read': alert.isRead,
      'created_at': alert.createdAt.toIso8601String(),
    });
  }

  Future<void> _markReadInSupabase(String id) async {
    final uid = _userId;
    if (uid == null) return;
    await _supabase
        .from('user_alerts')
        .update({'is_read': true})
        .eq('id', id)
        .eq('user_id', uid);
  }

  Future<void> _markAllReadInSupabase() async {
    final uid = _userId;
    if (uid == null) return;
    await _supabase
        .from('user_alerts')
        .update({'is_read': true}).eq('user_id', uid);
  }

  // ─── Cache (SharedPreferences fallback) ──────────────────────

  Future<List<AlertModel>> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.trim().isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      final alerts = list
          .whereType<Map<String, dynamic>>()
          .map(AlertModel.fromJson)
          .toList();

      alerts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return alerts;
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveCache(List<AlertModel> alerts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKey,
        jsonEncode(alerts.map((a) => a.toJson()).toList()),
      );
    } catch (_) {}
  }

// ─── Public API ───────────────────────────────────────────────

  @override
  Future<List<AlertModel>> fetchAlerts() async {
    try {
      final alerts = await _fetchFromSupabase();
      alerts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      await _saveCache(alerts);
      return alerts;
    } catch (_) {
      return _loadCache();
    }
  }

  @override
  Future<List<AlertModel>> markAllRead() async {
    try {
      await _markAllReadInSupabase();
    } catch (_) {}
    final cached = await _loadCache();
    final updated = cached.map((a) => a.copyWith(isRead: true)).toList();
    await _saveCache(updated);
    return fetchAlerts();
  }

  @override
  Future<List<AlertModel>> markRead(String id) async {
    try {
      await _markReadInSupabase(id);
    } catch (_) {}
    final cached = await _loadCache();
    final updated =
        cached.map((a) => a.id == id ? a.copyWith(isRead: true) : a).toList();
    await _saveCache(updated);
    return fetchAlerts();
  }

  @override
  Future<List<AlertModel>> addAlert(AlertModel alert) async {
    final cached = await _loadCache();
    if (cached.any((a) => a.id == alert.id)) return fetchAlerts();

    try {
      await _upsertToSupabase(alert);
    } catch (_) {
      cached.insert(0, alert);
      cached.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      await _saveCache(cached);
      AlertsNotifier.instance.notify();
      return cached;
    }
    AlertsNotifier.instance.notify();
    return fetchAlerts();
  }
}

// ─── Global helper ────────────────────────────────────────────────────────────

class AlertsStore {
  AlertsStore._();
  static final AlertsStore instance = AlertsStore._();
  final AlertsLocalDataSourceImpl _ds = AlertsLocalDataSourceImpl();

  Future<void> addInterviewFeedbackAlert({
    required String roleName,
    required String sessionId,
    String sessionType = 'technical',
  }) async {
    final alert = AlertModel(
      id: 'interview_$sessionId',
      title: 'Interview Feedback Ready',
      body: 'Your $roleName interview feedback is now available. Tap to view.',
      createdAt: DateTime.now().toUtc(),
      isRead: false,
      type: AlertType.interview,
      route: '/interview-feedback-detail',
    );
    await _ds.addAlert(alert);
  }

  Future<void> addCareerPlanAlert({
    required String planTitle,
    required String planId,
  }) async {
    final alert = AlertModel(
      id: 'plan_$planId',
      title: 'Career Plan Ready',
      body: 'Your "$planTitle" career plan has been generated. Tap to view.',
      createdAt: DateTime.now().toUtc(),
      isRead: false,
      type: AlertType.plan,
      route: '/career-build/plans',
    );
    await _ds.addAlert(alert);
  }

  Future<void> addCareerPlanRegeneratedAlert({
    required String planTitle,
    required String planId,
  }) async {
    final alert = AlertModel(
      id: 'plan_regen_${planId}_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Career Plan Updated',
      body: 'Your "$planTitle" career plan has been regenerated successfully.',
      createdAt: DateTime.now().toUtc(),
      isRead: false,
      type: AlertType.plan,
    );
    await _ds.addAlert(alert);
  }
}

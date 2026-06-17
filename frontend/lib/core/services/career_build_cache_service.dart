import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CareerBuildCacheService {
  static const String _latestPlanKey = 'career_build_latest_plan';
  static const String _plansKey = 'career_build_saved_plans';

  Future<void> saveLatestPlan(Map<String, dynamic> planJson) async {
    final prefs = await SharedPreferences.getInstance();
    final copy = Map<String, dynamic>.from(planJson);
    copy['cached_at'] = DateTime.now().toIso8601String();

    await prefs.setString(_latestPlanKey, jsonEncode(copy));
  }

  Future<Map<String, dynamic>?> getLatestPlan() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_latestPlanKey);

    if (raw == null || raw.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return null;
    } catch (_) {
      await prefs.remove(_latestPlanKey);
      return null;
    }
  }

  Future<void> clearLatestPlan() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_latestPlanKey);
  }

  // اسم قديم البروفيدر بيناديه
  Future<void> addSavedPlan(Map<String, dynamic> planJson) async {
    await addOrUpdateSavedPlan(planJson);
  }

  // اسم جديد
  Future<void> addOrUpdateSavedPlan(Map<String, dynamic> planJson) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getSavedPlans();

    final copy = Map<String, dynamic>.from(planJson);
    final planId = copy['plan_id']?.toString();
    final localId = copy['local_id']?.toString();

    current.removeWhere((e) {
      final ePlanId = e['plan_id']?.toString();
      final eLocalId = e['local_id']?.toString();

      final samePlanId =
          planId != null && planId.isNotEmpty && ePlanId == planId;
      final sameLocalId =
          localId != null && localId.isNotEmpty && eLocalId == localId;

      return samePlanId || sameLocalId;
    });

    copy['saved_at'] = DateTime.now().toIso8601String();

    current.insert(0, copy);

    await prefs.setString(_plansKey, jsonEncode(current));
  }

  Future<List<Map<String, dynamic>>> getSavedPlans() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_plansKey);

    if (raw == null || raw.trim().isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      await prefs.remove(_plansKey);
      return [];
    }
  }

  // دي رجعناها positional عشان البروفيدر عندك بينادي deleteSavedPlan(id)
  Future<void> deleteSavedPlan(String localId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getSavedPlans();

    current.removeWhere((e) {
      final eLocalId = e['local_id']?.toString();
      final ePlanId = e['plan_id']?.toString();

      return eLocalId == localId || ePlanId == localId;
    });

    await prefs.setString(_plansKey, jsonEncode(current));
  }

  Future<void> deleteSavedPlanByIds({
    String? planId,
    String? localId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getSavedPlans();

    current.removeWhere((e) {
      final ePlanId = e['plan_id']?.toString();
      final eLocalId = e['local_id']?.toString();

      final samePlanId =
          planId != null && planId.isNotEmpty && ePlanId == planId;
      final sameLocalId =
          localId != null && localId.isNotEmpty && eLocalId == localId;

      return samePlanId || sameLocalId;
    });

    await prefs.setString(_plansKey, jsonEncode(current));
  }

  Future<void> moveLatestToSaved() async {
    final latest = await getLatestPlan();
    if (latest == null) return;

    await addOrUpdateSavedPlan(latest);
    await clearLatestPlan();
  }

  Future<void> clearCareerBuildCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_latestPlanKey);
    await prefs.remove(_plansKey);
  }
}

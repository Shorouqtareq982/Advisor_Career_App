import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class AppNotificationService {
  AppNotificationService._();

  static final AppNotificationService instance = AppNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _careerPlanChannel =
      AndroidNotificationChannel(
    'career_plan_updates',
    'Career Plan Updates',
    description: 'Notifications when career plans are generated or regenerated',
    importance: Importance.high,
  );

  Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    const settings = InitializationSettings(
      android: androidInit,
    );

    await _plugin.initialize(settings);

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(_careerPlanChannel);
    await androidPlugin?.requestNotificationsPermission();
  }

  Future<void> showCareerPlanGenerated() async {
    await _show(
      id: 1001,
      title: 'Your career plan is ready 🎯',
      body:
          'Your personalized roadmap has been generated. Open it now to review your weeks and resources.',
    );
  }

  Future<void> showCareerPlanRegenerated() async {
    await _show(
      id: 1002,
      title: 'Your updated plan is ready ✨',
      body:
          'We regenerated your roadmap based on your feedback. Open it now to review the changes.',
    );
  }

  Future<void> _show({
    required int id,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'career_plan_updates',
      'Career Plan Updates',
      channelDescription:
          'Notifications when career plans are generated or regenerated',
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'Career plan update',
    );

    const details = NotificationDetails(
      android: androidDetails,
    );

    await _plugin.show(
      id,
      title,
      body,
      details,
    );
  }
}

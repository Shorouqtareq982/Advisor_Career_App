import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'interview_feedback';
  static const _channelName = 'Interview Feedback';
  static const _channelDescription =
      'Notifications when your interview feedback is ready';

  static const _prefNotificationsEnabled = 'notifications_enabled';

  static bool _launchHandled = false;

  // ── Navigation callback ────────────────────────────────────────────────────
  static void Function(String payload)? onNotificationTapCallback;

  static final List<String> _pendingPayloads = [];

  static void setCallback(void Function(String payload) callback) {
    onNotificationTapCallback = callback;
    if (_pendingPayloads.isNotEmpty) {
      final pending = List<String>.from(_pendingPayloads);
      _pendingPayloads.clear();
      for (final payload in pending) {
        Future.microtask(() => callback(payload));
      }
    }
  }

  // ── Init ───────────────────────────────────────────────────────────────────

  Future<void> init() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
      onDidReceiveBackgroundNotificationResponse: _onNotificationTapBackground,
    );

    // ── Create high-importance channel with sound ──────────────────────────
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // ── Handle notification tap that launched the app (cold launch) ────────
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true && !_launchHandled) {
      _launchHandled = true;
      final payload = launchDetails!.notificationResponse?.payload ?? 'alerts';

      Future.delayed(const Duration(milliseconds: 1500), () {
        _dispatchPayload(payload);
      });
    }
  }

  static void _dispatchPayload(String payload) {
    if (onNotificationTapCallback != null) {
      onNotificationTapCallback!(payload);
    } else {
      _pendingPayloads.add(payload);
    }
  }

  // ── Permissions ────────────────────────────────────────────────────────────

  Future<void> requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // ── Toggle (Settings screen) ───────────────────────────────────────────────

  Future<void> toggleNotifications(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefNotificationsEnabled, enabled);

    if (!enabled) {
      await _plugin.cancelAll();
    }
  }

  Future<bool> isNotificationsEnabled() async {
    final systemGranted = await isSystemPermissionGranted();
    if (!systemGranted) return false;

    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefNotificationsEnabled) ?? true;
  }

  Future<bool> isSystemPermissionGranted() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      return await androidPlugin.areNotificationsEnabled() ?? false;
    }

    return true;
  }

  // ── Show notifications ─────────────────────────────────────────────────────

  Future<void> showInterviewFeedbackReady({
    required String roleName,
    required String sessionId,
  }) async {
    if (!await isNotificationsEnabled()) return;
    await _showNotification(
      title: 'Interview Feedback Ready! 🎉',
      body: 'Your $roleName interview feedback is now available.',
      payload: 'interview_feedback:$sessionId',
    );
  }

  Future<void> showCustomNotification({
    required String title,
    required String body,
  }) async {
    if (!await isNotificationsEnabled()) return;
    await _showNotification(title: title, body: body, payload: 'alerts');
  }

  // ── Private ────────────────────────────────────────────────────────────────

  Future<void> _showNotification({
    required String title,
    required String body,
    String payload = 'alerts',
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      fullScreenIntent: false,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  static bool _isHandlingTap = false;

  void _onNotificationTap(NotificationResponse response) {
    if (_isHandlingTap) return;
    _isHandlingTap = true;

    final payload = response.payload ?? '';

    Future.delayed(const Duration(milliseconds: 300), () {
      _dispatchPayload(payload);
    });

    Future.delayed(const Duration(seconds: 1), () {
      _isHandlingTap = false;
    });
  }
}

@pragma('vm:entry-point')
void _onNotificationTapBackground(NotificationResponse response) {
  debugPrint('Notification tapped (background): ${response.payload}');
}

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

  // ── Cold-launch payload (التطبيق كان مقفول وفتح بسبب تاب على إشعار) ────────
  // بيتخزن من غير أي تأخير، والسبلاش سكرين هي اللي تستهلكه وقت ما تقرر
  // تنتقل لأي صفحة، عشان ميحصلش تعارض بينها وبين أي navigation تاني.
  static String? _pendingLaunchPayload;
  static bool _launchPayloadConsumed = false;

  /// لازم تتنادى مرة واحدة من السبلاش سكرين قبل ما تقرر تروح فين.
  /// لو ترجع غير null، يبقى التطبيق فتح من تاب على إشعار ولسه محدش
  /// تعامل مع ده.
  static String? consumeLaunchPayload() {
    if (_launchPayloadConsumed || _pendingLaunchPayload == null) return null;
    _launchPayloadConsumed = true;
    final payload = _pendingLaunchPayload;
    _pendingLaunchPayload = null;
    return payload;
  }

  // ── Navigation callback (للتاب وقت ما الابليكيشن شغالة فعلاً) ──────────────
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
    // مهم: متعملش أي navigation أو delay هنا. خزّن الـ payload بس،
    // والسبلاش سكرين هي اللي تقرر تروح فين وقتها، عشان مفيش تعارض.
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      _pendingLaunchPayload =
          launchDetails!.notificationResponse?.payload ?? 'alerts';
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

  Future<void> showJobResultsReady({
    required String jobTitle,
  }) async {
    if (!await isNotificationsEnabled()) return;
    await _showNotification(
      title: 'Your Job Matches Are Ready! ',
      body:
          'We found the best $jobTitle opportunities for you. Tap to see results.',
      payload: 'job_results', // ← تأكد الـ payload ده
    );
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
    debugPrint('Notification tapped with payload: $payload'); // للـ debug

    Future.delayed(const Duration(milliseconds: 300), () {
      _dispatchPayload(payload);
    });

    Future.delayed(const Duration(seconds: 2), () {
      // ← قلّل من 1 لـ 2 عشان أأمن
      _isHandlingTap = false;
    });
  }
}

@pragma('vm:entry-point')
void _onNotificationTapBackground(NotificationResponse response) {
  debugPrint('Notification tapped (background): ${response.payload}');
}

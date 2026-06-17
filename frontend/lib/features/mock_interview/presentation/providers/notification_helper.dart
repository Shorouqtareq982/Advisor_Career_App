import 'package:growza/core/services/notification_service.dart';

class NotificationHelper {
  static Future<void> showFeedbackReady({
    required String roleName,
    required String sessionId,
  }) async {
    await NotificationService.instance.showInterviewFeedbackReady(
      roleName: roleName,
      sessionId: sessionId,
    );
  }
}

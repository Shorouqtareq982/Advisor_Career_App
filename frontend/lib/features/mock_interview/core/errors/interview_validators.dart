import 'dart:io';
import 'interview_exceptions.dart';

// ─── Interview Validators ─────────────────────────────────────────────────────
// Usage:
//   InterviewValidators.requireRoleSelected(_selectedRole);
//   InterviewValidators.requireValidFile(file, sessionType: sessionType);
//   InterviewValidators.requireActiveSession(state.session, state.sasExpiresAt);

class InterviewValidators {
  InterviewValidators._();

  // ── Session Validators ────────────────────────────────────────────────────

  static void requireRoleSelected(Object? selectedRole) {
    if (selectedRole == null) {
      throw InterviewException.noRoleSelected();
    }
  }

  static void requireActiveSession(Object? session) {
    if (session == null) {
      throw InterviewException.sessionNotFound();
    }
  }

  static void requireValidSasToken(DateTime sasExpiresAt) {
    if (DateTime.now().isAfter(sasExpiresAt)) {
      throw InterviewException.sessionExpired();
    }
  }

  static void requireSessionReady({
    required Object? session,
    required DateTime? sasExpiresAt,
  }) {
    requireActiveSession(session);
  }

  // ── File / Upload Validators ───────────────────────────────────────────────

  static const int _maxVideoMb = 200;
  static const int _maxAudioMb = 50;

  static Future<void> requireValidFile(
    File file, {
    required bool isVideo,
  }) async {
    // File exists?
    if (!await file.exists()) {
      throw InterviewException.uploadFailed();
    }

    // File not empty?
    final length = await file.length();
    if (length == 0) {
      throw InterviewException.uploadFailed();
    }

    // File size within limit?
    final maxMb = isVideo ? _maxVideoMb : _maxAudioMb;
    final sizeMb = length ~/ (1024 * 1024);
    if (sizeMb > maxMb) {
      throw InterviewException.fileTooLarge(maxMb: maxMb);
    }

    // File format check by extension
    final path = file.path.toLowerCase();
    final validExtensions = isVideo
        ? ['.mp4', '.mov', '.avi', '.mkv']
        : ['.mp3', '.aac', '.m4a', '.wav', '.ogg'];

    final hasValidExtension = validExtensions.any((ext) => path.endsWith(ext));

    if (!hasValidExtension) {
      throw InterviewException.invalidFileFormat();
    }
  }

  // ── Network Error Parser ───────────────────────────────────────────────────

  static InterviewException fromNetworkError(Object error) {
    final msg = error.toString().toLowerCase();

    // No internet
    if (msg.contains('socketexception') ||
        msg.contains('failed host lookup') ||
        msg.contains('connection refused') ||
        msg.contains('network is unreachable') ||
        msg.contains('no address associated')) {
      return InterviewException.noInternet();
    }

    // Timeout
    if (msg.contains('timeoutexception') ||
        msg.contains('timed out') ||
        msg.contains('connection timeout') ||
        msg.contains('receive timeout') ||
        msg.contains('send timeout')) {
      return InterviewException.timeout();
    }

    // Auth
    if (msg.contains('401') || msg.contains('unauthorized')) {
      return InterviewException.unauthorized();
    }

    // Not found
    if (msg.contains('404')) {
      return InterviewException.notFound();
    }

    // Server errors
    if (msg.contains('500') ||
        msg.contains('502') ||
        msg.contains('503') ||
        msg.contains('internal server error')) {
      return InterviewException.serverError(
        _extractStatusCode(msg),
      );
    }

    // Azure / Storage
    if (msg.contains('azure') ||
        msg.contains('blob') ||
        msg.contains('storage')) {
      return InterviewException.storageUnavailable();
    }

    // Already an InterviewException → re-throw as-is
    if (error is InterviewException) return error;

    return InterviewException.unknown(error);
  }

  static int? _extractStatusCode(String msg) {
    final match = RegExp(r'\b(4\d{2}|5\d{2})\b').firstMatch(msg);
    return match != null ? int.tryParse(match.group(0)!) : null;
  }

  // ── Report Validators ─────────────────────────────────────────────────────

  static void requireReportReady(String report) {
    final trimmed = report.trim();
    if (trimmed.isEmpty ||
        trimmed == '{}' ||
        trimmed == 'null' ||
        trimmed == '""' ||
        trimmed.length < 10) {
      throw InterviewException.reportNotReady();
    }
  }

  // ── Permissions ───────────────────────────────────────────────────────────

  static void requireCameraPermission(bool isGranted) {
    if (!isGranted) throw InterviewException.cameraPermissionDenied();
  }

  static void requireMicrophonePermission(bool isGranted) {
    if (!isGranted) throw InterviewException.microphonePermissionDenied();
  }
}

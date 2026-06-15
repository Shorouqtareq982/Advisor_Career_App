import 'package:flutter/material.dart';
import 'interview_exceptions.dart';

// ─── Interview Error Widgets ─────────────────────────────────────────────────

// ─── Color constants  ──────────────────

class _IC {
  static const red = Color(0xFFEF4444);
  static const orange = Color(0xFFF97316);
  static const blue = Color(0xFF38BDF8);
  static const green = Color(0xFF22C55E);
  static const grey50 = Color(0xFFF9FAFB);
  static const grey300 = Color(0xFFD1D5DB);
  static const grey700 = Color(0xFF374151);
  static const grey800 = Color(0xFF1F2937);
  static const blue700 = Color(0xFF1E3A5F);
  static const blue900 = Color(0xFF0D1B2A);
}

// ─── 1. Error Banner (inline, above content) ──────────────────────────────────

class InterviewErrorBanner extends StatelessWidget {
  final String message;
  final InterviewErrorType? type;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;

  const InterviewErrorBanner({
    super.key,
    required this.message,
    this.type,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
  });

  factory InterviewErrorBanner.fromException(
    InterviewException exception, {
    Key? key,
    VoidCallback? onAction,
    VoidCallback? onDismiss,
  }) =>
      InterviewErrorBanner(
        key: key,
        message: exception.userMessage,
        type: exception.type,
        actionLabel: exception.actionLabel,
        onAction: onAction,
        onDismiss: onDismiss,
      );

  @override
  Widget build(BuildContext context) {
    final color = _colorForType(type);
    final icon = _iconForType(type);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    color: _IC.grey50,
                    fontSize: 13,
                    height: 1.45,
                    fontFamily: 'Inter',
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: onAction,
                    child: Text(
                      actionLabel!,
                      style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                        decoration: TextDecoration.underline,
                        decorationColor: color,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onDismiss != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onDismiss,
              child: Icon(Icons.close_rounded, color: _IC.grey300, size: 18),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── 2. Error Card (full empty-state style) ───────────────────────────────────

class InterviewErrorCard extends StatelessWidget {
  final String message;
  final InterviewErrorType? type;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isDark;

  const InterviewErrorCard({
    super.key,
    required this.message,
    this.type,
    this.actionLabel,
    this.onAction,
    this.isDark = true,
  });

  factory InterviewErrorCard.fromException(
    InterviewException exception, {
    Key? key,
    VoidCallback? onAction,
    bool isDark = true,
  }) =>
      InterviewErrorCard(
        key: key,
        message: exception.userMessage,
        type: exception.type,
        actionLabel: exception.actionLabel,
        onAction: onAction,
        isDark: isDark,
      );

  @override
  Widget build(BuildContext context) {
    final color = _colorForType(type);
    final icon = _iconForType(type);
    final textPrimary = isDark ? _IC.grey50 : _IC.blue900;
    final textMuted = isDark ? _IC.grey300 : _IC.grey700;
    final iconBg = color.withOpacity(0.12);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 34),
            ),
            const SizedBox(height: 20),

            // Message
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textMuted,
                fontSize: 14,
                height: 1.6,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 24),

            // CTA button
            if (actionLabel != null && onAction != null)
              SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: onAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                  child: Text(
                    actionLabel!,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── 3. SnackBar Helper ───────────────────────────────────────────────────────

class InterviewErrorSnackbar {
  InterviewErrorSnackbar._();

  /// showError(context, exception) → red snackbar
  static void showError(
    BuildContext context,
    InterviewException exception, {
    VoidCallback? onAction,
  }) {
    _show(
      context,
      message: exception.userMessage,
      type: exception.type,
      actionLabel: exception.actionLabel,
      onAction: onAction,
    );
  }

  /// showMessage(context, msg) → neutral info snackbar
  static void showMessage(BuildContext context, String message) {
    _show(context, message: message);
  }

  static void _show(
    BuildContext context, {
    required String message,
    InterviewErrorType? type,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final color = _colorForType(type);
    final icon = _iconForType(type);

    // Take only first line for snackbar (keep it short)
    final displayMsg = message.split('\n').first;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: const Color(0xFF1A2535),
          content: Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  displayMsg,
                  style: const TextStyle(
                    color: _IC.grey50,
                    fontSize: 13,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ],
          ),
          action: actionLabel != null && onAction != null
              ? SnackBarAction(
                  label: actionLabel,
                  textColor: color,
                  onPressed: onAction,
                )
              : null,
        ),
      );
  }
}

// ─── 4. Inline Field Error (for dialogs like SelectJobDialog) ─────────────────

class InterviewFieldError extends StatelessWidget {
  final String? message;

  const InterviewFieldError({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    if (message == null || message!.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: _IC.red, size: 14),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              message!,
              style: const TextStyle(
                color: _IC.red,
                fontSize: 12,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

Color _colorForType(InterviewErrorType? type) {
  if (type == null) return _IC.red;
  switch (type) {
    case InterviewErrorType.noInternet:
    case InterviewErrorType.timeout:
      return _IC.orange;

    case InterviewErrorType.reportNotReady:
      return _IC.blue;

    case InterviewErrorType.noRoleSelected:
    case InterviewErrorType.cameraPermissionDenied:
    case InterviewErrorType.microphonePermissionDenied:
      return _IC.orange;

    default:
      return _IC.red;
  }
}

IconData _iconForType(InterviewErrorType? type) {
  if (type == null) return Icons.error_outline_rounded;
  switch (type) {
    case InterviewErrorType.noInternet:
      return Icons.wifi_off_rounded;
    case InterviewErrorType.timeout:
      return Icons.timer_off_outlined;
    case InterviewErrorType.unauthorized:
      return Icons.lock_outline_rounded;
    case InterviewErrorType.notFound:
    case InterviewErrorType.sessionNotFound:
      return Icons.search_off_rounded;
    case InterviewErrorType.sessionExpired:
      return Icons.hourglass_disabled_rounded;
    case InterviewErrorType.sessionAlreadyActive:
      return Icons.videocam_outlined;
    case InterviewErrorType.fileTooLarge:
      return Icons.folder_off_outlined;
    case InterviewErrorType.uploadFailed:
    case InterviewErrorType.storageUnavailable:
      return Icons.cloud_off_rounded;
    case InterviewErrorType.reportNotReady:
      return Icons.hourglass_top_rounded;
    case InterviewErrorType.cameraPermissionDenied:
      return Icons.videocam_off_rounded;
    case InterviewErrorType.microphonePermissionDenied:
      return Icons.mic_off_rounded;
    case InterviewErrorType.noRoleSelected:
      return Icons.work_off_outlined;
    default:
      return Icons.error_outline_rounded;
  }
}

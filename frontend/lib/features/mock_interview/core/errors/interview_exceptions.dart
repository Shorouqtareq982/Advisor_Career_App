// ─── Interview Exception Types ────────────────────────────────────────────────
//
// Usage:
//   throw InterviewException.noInternet();
//   throw InterviewException.sessionExpired();
//   throw InterviewException.fileTooLarge(maxMb: 100);
//
// In the notifier, catch with:
//   on InterviewException catch (e) { state = state.copyWith(errorMessage: e.userMessage, errorType: e.type); }

enum InterviewErrorType {
  // Network
  noInternet,
  timeout,
  serverError,
  unauthorized,
  notFound,

  // Session
  noRoleSelected,
  sessionExpired,
  sessionNotFound,
  sessionAlreadyActive,

  // Upload
  fileTooLarge,
  invalidFileFormat,
  uploadFailed,
  storageUnavailable,

  // Report
  reportNotReady,
  reportParsingFailed,

  // Permissions
  cameraPermissionDenied,
  microphonePermissionDenied,

  // Generic
  unknown,
}

class InterviewException implements Exception {
  final InterviewErrorType type;
  final String userMessage; // ← shown to user
  final String? technicalDetail; // ← for logs only
  final String?
      actionLabel; // ← CTA button label (e.g. "Retry", "Go to Settings")
  final InterviewErrorAction? action;

  const InterviewException({
    required this.type,
    required this.userMessage,
    this.technicalDetail,
    this.actionLabel,
    this.action,
  });

  // ── Network ───────────────────────────────────────────────────────────────

  factory InterviewException.noInternet() => const InterviewException(
        type: InterviewErrorType.noInternet,
        userMessage:
            'No internet connection.\nDon\'t worry — once your connection returns, we will retry to upload your session.',
        // ← شيلي الـ actionLabel والـ action
      );

  factory InterviewException.timeout() => const InterviewException(
        type: InterviewErrorType.timeout,
        userMessage: 'The request took too long.\nPlease try again.',
        actionLabel: 'Retry',
        action: InterviewErrorAction.retry,
      );

  factory InterviewException.serverError([int? statusCode]) =>
      InterviewException(
        type: InterviewErrorType.serverError,
        userMessage:
            'Something went wrong on our end.\nPlease try again in a moment.',
        technicalDetail: statusCode != null ? 'HTTP $statusCode' : null,
        actionLabel: 'Retry',
        action: InterviewErrorAction.retry,
      );

  factory InterviewException.unauthorized() => const InterviewException(
        type: InterviewErrorType.unauthorized,
        userMessage: 'Your session has expired.\nPlease sign in again.',
        actionLabel: 'Sign In',
        action: InterviewErrorAction.signIn,
      );

  factory InterviewException.notFound() => const InterviewException(
        type: InterviewErrorType.notFound,
        userMessage:
            'This session could not be found.\nIt may have been deleted.',
        actionLabel: 'Go Back',
        action: InterviewErrorAction.goBack,
      );

  // ── Session ───────────────────────────────────────────────────────────────

  factory InterviewException.noRoleSelected() => const InterviewException(
        type: InterviewErrorType.noRoleSelected,
        userMessage: 'Please select a job title to continue.',
      );

  factory InterviewException.sessionExpired() => const InterviewException(
        type: InterviewErrorType.sessionExpired,
        userMessage:
            'Your interview session has expired.\nPlease start a new one.',
        actionLabel: 'Start New',
        action: InterviewErrorAction.startNew,
      );

  factory InterviewException.sessionNotFound() => const InterviewException(
        type: InterviewErrorType.sessionNotFound,
        userMessage:
            'Interview session not found.\nPlease start a new interview.',
        actionLabel: 'Start New',
        action: InterviewErrorAction.startNew,
      );

  factory InterviewException.sessionAlreadyActive() => const InterviewException(
        type: InterviewErrorType.sessionAlreadyActive,
        userMessage:
            'You already have an active interview.\nPlease finish or leave it first.',
        actionLabel: 'Continue',
        action: InterviewErrorAction.continueSession,
      );

  // ── Upload ────────────────────────────────────────────────────────────────

  factory InterviewException.fileTooLarge({required int maxMb}) =>
      InterviewException(
        type: InterviewErrorType.fileTooLarge,
        userMessage:
            'Recording is too large (max ${maxMb}MB).\nPlease try a shorter session.',
      );

  factory InterviewException.invalidFileFormat() => const InterviewException(
        type: InterviewErrorType.invalidFileFormat,
        userMessage: 'Recording format is not supported.\nPlease try again.',
        actionLabel: 'Retry',
        action: InterviewErrorAction.retry,
      );

  factory InterviewException.uploadFailed() => const InterviewException(
        type: InterviewErrorType.uploadFailed,
        userMessage:
            'Failed to upload your recording.\nDon\'t worry — when your connection returns, we\'ll resume uploading and analyzing your session.',
        actionLabel: 'Retry',
        action: InterviewErrorAction.retry,
      );

  factory InterviewException.storageUnavailable() => const InterviewException(
        type: InterviewErrorType.storageUnavailable,
        userMessage:
            'Storage is temporarily unavailable.\nPlease try again in a few minutes.',
        actionLabel: 'Retry',
        action: InterviewErrorAction.retry,
      );

  // ── Report ────────────────────────────────────────────────────────────────

  factory InterviewException.reportNotReady() => const InterviewException(
        type: InterviewErrorType.reportNotReady,
        userMessage:
            "Your feedback is still being prepared.\nWe'll notify you when it's ready.",
        actionLabel: 'Check Again',
        action: InterviewErrorAction.retry,
      );

  factory InterviewException.reportParsingFailed() => const InterviewException(
        type: InterviewErrorType.reportParsingFailed,
        userMessage: 'Could not load feedback details.\nPlease try again.',
        actionLabel: 'Retry',
        action: InterviewErrorAction.retry,
      );

  // ── Permissions ───────────────────────────────────────────────────────────

  factory InterviewException.cameraPermissionDenied() =>
      const InterviewException(
        type: InterviewErrorType.cameraPermissionDenied,
        userMessage:
            'Camera access is required for behavioral interviews.\nPlease enable it in Settings.',
        actionLabel: 'Open Settings',
        action: InterviewErrorAction.openSettings,
      );

  factory InterviewException.microphonePermissionDenied() =>
      const InterviewException(
        type: InterviewErrorType.microphonePermissionDenied,
        userMessage:
            'Microphone access is required to record your answers.\nPlease enable it in Settings.',
        actionLabel: 'Open Settings',
        action: InterviewErrorAction.openSettings,
      );

  // ── Generic ───────────────────────────────────────────────────────────────

  factory InterviewException.unknown([Object? original]) => InterviewException(
        type: InterviewErrorType.unknown,
        userMessage: 'Something went wrong.\nPlease try again.',
        technicalDetail: original?.toString(),
        actionLabel: 'Retry',
        action: InterviewErrorAction.retry,
      );

  @override
  String toString() => 'InterviewException(${type.name}): $userMessage'
      '${technicalDetail != null ? ' [$technicalDetail]' : ''}';
}

// ─── Action the UI should take when error CTA is tapped ──────────────────────

enum InterviewErrorAction {
  retry,
  signIn,
  goBack,
  startNew,
  continueSession,
  openSettings,
  dismiss,
}

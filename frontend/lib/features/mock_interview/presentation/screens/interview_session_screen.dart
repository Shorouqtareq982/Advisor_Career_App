import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../../../../core/theme/app_text_theme.dart';
import '../providers/mock_interview_provider.dart';
import '../widgets/mock_interview_dialogs.dart';

class InterviewSessionScreen extends ConsumerStatefulWidget {
  final String roleName;
  final String roleId;

  const InterviewSessionScreen({
    super.key,
    required this.roleName,
    required this.roleId,
  });

  @override
  ConsumerState<InterviewSessionScreen> createState() =>
      _InterviewSessionScreenState();
}

class _InterviewSessionScreenState
    extends ConsumerState<InterviewSessionScreen> {
  CameraController? _cameraController;
  bool _cameraEnabled = true;
  bool _micEnabled = true;
  bool _isInitializingCamera = false;

  // Video recording
  File? _recordedVideo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _requestPermissionsAndInit();
    });
  }

  Future<void> _requestPermissionsAndInit() async {
    final camera = await Permission.camera.request();
    final mic = await Permission.microphone.request();

    if (camera.isGranted && mic.isGranted) {
      await _initCamera();
      if (mounted) {
        ref.read(mockInterviewProvider.notifier).startSession(
          roleName: widget.roleName,
          roleId: widget.roleId,
        );
        _startRecording();
      }
    } else {
      // Handle denied permissions
      if (!camera.isGranted) _showCameraDialog();
      if (!mic.isGranted) _showMicDialog();
    }
  }

  Future<void> _initCamera() async {
    setState(() => _isInitializingCamera = true);
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      // Prefer front camera
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        // Only record audio from microphone (not system audio)
        enableAudio: true,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();
      if (mounted) setState(() => _isInitializingCamera = false);
    } catch (e) {
      setState(() => _isInitializingCamera = false);
    }
  }

  Future<void> _startRecording() async {
    try {
      await _cameraController?.startVideoRecording();
    } catch (_) {}
  }

  Future<void> _stopRecording() async {
    try {
      final file = await _cameraController?.stopVideoRecording();
      if (file != null) {
        _recordedVideo = File(file.path);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(mockInterviewProvider);
    final textTheme = context.appTextTheme;

    // React to session finishing
    ref.listen<MockInterviewState>(mockInterviewProvider, (prev, next) {
      if (next.sessionStatus == InterviewSessionStatus.finished &&
          prev?.sessionStatus != InterviewSessionStatus.finished) {
        _onSessionFinished();
      }
    });

    final bgColor = isDark ? AppColors.blue900 : const Color(0xFF1A1A2E);
    final session = state.session;
    final currentQuestion = session != null &&
            state.currentQuestionIndex < session.questions.length
        ? session.questions[state.currentQuestionIndex]
        : null;

    return WillPopScope(
      onWillPop: () async {
        _showLeaveDialog();
        return false;
      },
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: Column(
            children: [
              // ── Top bar: timer + back ──────────────────────────────
              _buildTopBar(context, state, isDark, textTheme),

              // ── Camera preview area ───────────────────────────────
              Expanded(
                child: Stack(
                  children: [
                    // Robot / AI avatar placeholder (full width)
                    _buildAIAvatar(context),

                    // User camera (bottom-right overlay)
                    Positioned(
                      right: context.w(16),
                      bottom: context.h(120),
                      child: _buildUserCamera(context),
                    ),

                    // Question text (center bottom)
                    if (currentQuestion != null)
                      Positioned(
                        left: context.w(20),
                        right: context.w(64),
                        bottom: context.h(60),
                        child: _buildQuestionText(
                            context, currentQuestion.questionText,
                            isDark, textTheme),
                      ),
                  ],
                ),
              ),

              // ── Bottom controls ───────────────────────────────────
              _buildBottomControls(context, state, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, MockInterviewState state,
      bool isDark, AppTextTheme textTheme) {
    final totalSecs = state.remainingSeconds;
    final mins = totalSecs ~/ 60;
    final secs = totalSecs % 60;
    final timeStr =
        '${mins.toString().padLeft(2, '0')}m ${secs.toString().padLeft(2, '0')}s';

    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: context.w(16), vertical: context.h(12)),
      child: Row(
        children: [
          GestureDetector(
            onTap: _showLeaveDialog,
            child: Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: context.icon(20)),
          ),
          const Spacer(),
          Row(
            children: [
              Icon(Icons.timer_outlined,
                  color: Colors.white, size: context.icon(18)),
              SizedBox(width: context.w(4)),
              context.text(timeStr,
                  style:
                      textTheme.title2Bold.copyWith(color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAIAvatar(BuildContext context) {
    // Robot avatar — uses asset if available
    return Center(
      child: Image.asset(
        'assets/images/mock_interview/ai_robot.png',
        width: context.w(260),
        errorBuilder: (_, __, ___) => Icon(
          Icons.smart_toy_outlined,
          color: AppColors.lightBlue400,
          size: context.icon(120),
        ),
      ),
    );
  }

  Widget _buildUserCamera(BuildContext context) {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return Container(
        width: context.w(90),
        height: context.h(110),
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(context.r(12)),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.lightBlue500),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(context.r(12)),
      child: SizedBox(
        width: context.w(90),
        height: context.h(110),
        child: CameraPreview(_cameraController!),
      ),
    );
  }

  Widget _buildQuestionText(BuildContext context, String question,
      bool isDark, AppTextTheme textTheme) {
    return context.text(
      '"$question"',
      style: textTheme.title2Regular.copyWith(
        color: Colors.white,
        shadows: [
          Shadow(
              blurRadius: 8,
              color: Colors.black.withOpacity(0.6),
              offset: const Offset(0, 2))
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildBottomControls(
      BuildContext context, MockInterviewState state, bool isDark) {
    return Container(
      color: Colors.black.withOpacity(0.3),
      padding: EdgeInsets.symmetric(
          horizontal: context.w(24), vertical: context.h(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Camera toggle
          _ControlButton(
            icon: _cameraEnabled
                ? Icons.videocam_rounded
                : Icons.videocam_off_rounded,
            color: _cameraEnabled
                ? AppColors.lightBlue500
                : AppColors.grey600,
            onTap: _toggleCamera,
          ),

          // Mic toggle
          _ControlButton(
            icon: _micEnabled
                ? Icons.mic_rounded
                : Icons.mic_off_rounded,
            color: _micEnabled
                ? AppColors.lightBlue500
                : AppColors.grey600,
            onTap: _toggleMic,
          ),

          // Pause
          _ControlButton(
            icon: Icons.pause_rounded,
            color: AppColors.grey600,
            onTap: _showPauseDialog,
          ),

          // More options (...)
          _ControlButton(
            icon: Icons.more_horiz_rounded,
            color: AppColors.grey600,
            onTap: () {},
          ),

          // End call
          _ControlButton(
            icon: Icons.call_end_rounded,
            color: AppColors.red500,
            onTap: _showLeaveDialog,
          ),
        ],
      ),
    );
  }

  // ── Toggle camera ──────────────────────────────────────────────────────────

  Future<void> _toggleCamera() async {
    if (_cameraEnabled) {
      // Turning off — show dialog, pause session
      ref.read(mockInterviewProvider.notifier).pauseInterview();
      setState(() => _cameraEnabled = false);
      _showCameraDialog();
    } else {
      setState(() => _cameraEnabled = true);
      ref.read(mockInterviewProvider.notifier).resumeInterview();
    }
  }

  // ── Toggle mic ─────────────────────────────────────────────────────────────

  void _toggleMic() {
    if (_micEnabled) {
      ref.read(mockInterviewProvider.notifier).pauseInterview();
      setState(() => _micEnabled = false);
      _showMicDialog();
    } else {
      setState(() => _micEnabled = true);
      ref.read(mockInterviewProvider.notifier).resumeInterview();
    }
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────

  void _showPauseDialog() {
    ref.read(mockInterviewProvider.notifier).pauseInterview();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PauseDialog(
        onGoHome: _showLeaveDialog,
        onRestart: _showRestartDialog,
        onResume: () =>
            ref.read(mockInterviewProvider.notifier).resumeInterview(),
      ),
    );
  }

  void _showLeaveDialog() {
    ref.read(mockInterviewProvider.notifier).pauseInterview();
    showDialog(
      context: context,
      builder: (_) => LeaveInterviewDialog(
        onLeave: () {
          ref.read(mockInterviewProvider.notifier).resetSession();
          context.go('/home');
        },
      ),
    ).then((_) {
      // If dialog dismissed without leaving, resume
      if (ref.read(mockInterviewProvider).sessionStatus ==
          InterviewSessionStatus.paused) {
        ref.read(mockInterviewProvider.notifier).resumeInterview();
      }
    });
  }

  void _showRestartDialog() {
    showDialog(
      context: context,
      builder: (_) => RestartInterviewDialog(
        onRestart: () =>
            ref.read(mockInterviewProvider.notifier).restartInterview(),
      ),
    );
  }

  void _showCameraDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CameraRequiredDialog(
        onEnableCamera: () {
          setState(() => _cameraEnabled = true);
          ref.read(mockInterviewProvider.notifier).resumeInterview();
        },
        onGoHome: _showLeaveDialog,
      ),
    );
  }

  void _showMicDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => MicrophoneRequiredDialog(
        onEnableMic: () {
          setState(() => _micEnabled = true);
          ref.read(mockInterviewProvider.notifier).resumeInterview();
        },
        onGoHome: _showLeaveDialog,
      ),
    );
  }

  // ── Session finished ───────────────────────────────────────────────────────

  Future<void> _onSessionFinished() async {
    await _stopRecording();

    if (_recordedVideo != null) {
      ref
          .read(mockInterviewProvider.notifier)
          .uploadAndNotify(videoFile: _recordedVideo!);
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => InterviewCompletedDialog(
        onGotIt: () {
          ref.read(mockInterviewProvider.notifier).resetSession();
          context.go('/mock-interview');
        },
      ),
    );
  }
}

// ─── Control Button ───────────────────────────────────────────────────────────

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: context.w(48),
        height: context.w(48),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: context.icon(22)),
      ),
    );
  }
}

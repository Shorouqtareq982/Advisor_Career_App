import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:video_compress/video_compress.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../../../../core/theme/app_text_theme.dart';
import '../../domain/entities/interview_entities.dart';
import '../providers/mock_interview_provider.dart';
import '../widgets/mock_interview_dialogs.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  INTRO SCREEN
// ═══════════════════════════════════════════════════════════════════════════

class InterviewIntroScreen extends StatelessWidget {
  final String roleName;
  final InterviewSessionType sessionType;
  final VoidCallback onStart;

  const InterviewIntroScreen({
    super.key,
    required this.roleName,
    required this.sessionType,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = context.appTextTheme;
    final isBehavioral = sessionType == InterviewSessionType.behavioral;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.w(24),
            vertical: context.h(20),
          ),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => context.pop(),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: context.icon(20),
                  ),
                ),
              ),
              const Spacer(),
              Image.asset(
                'assets/images/mock_interview/ai_robot.png',
                width: context.w(160),
                errorBuilder: (_, __, ___) => Icon(
                  Icons.smart_toy_outlined,
                  color: AppColors.lightBlue400,
                  size: context.icon(100),
                ),
              ),
              SizedBox(height: context.h(24)),
              context.text(
                'Ready for your\n$roleName Interview?',
                style: textTheme.h5Bold.copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: context.h(8)),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.w(12),
                  vertical: context.h(4),
                ),
                decoration: BoxDecoration(
                  color: isBehavioral
                      ? AppColors.lightBlue600
                      : AppColors.purple500,
                  borderRadius: BorderRadius.circular(context.r(20)),
                ),
                child: context.text(
                  isBehavioral ? 'Behavioral Interview' : 'Technical Interview',
                  style: textTheme.captionBold.copyWith(color: Colors.white),
                ),
              ),
              SizedBox(height: context.h(32)),
              Container(
                padding: EdgeInsets.all(context.w(20)),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(context.r(16)),
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                ),
                child: Column(
                  children: [
                    _InfoRow(
                      icon: Icons.help_outline_rounded,
                      text: 'Multiple questions',
                      sub: 'prepared for you',
                    ),
                    Divider(
                      color: Colors.white.withOpacity(0.1),
                      height: context.h(20),
                    ),
                    _InfoRow(
                      icon: Icons.timer_outlined,
                      text: '45 seconds',
                      sub: 'per question to answer',
                    ),
                    Divider(
                      color: Colors.white.withOpacity(0.1),
                      height: context.h(20),
                    ),
                    _InfoRow(
                      icon: isBehavioral
                          ? Icons.videocam_rounded
                          : Icons.mic_rounded,
                      text: isBehavioral
                          ? 'Camera + Microphone'
                          : 'Microphone only',
                      sub: isBehavioral
                          ? 'video will be recorded'
                          : 'audio will be recorded',
                    ),
                    Divider(
                      color: Colors.white.withOpacity(0.1),
                      height: context.h(20),
                    ),
                    _InfoRow(
                      icon: Icons.psychology_outlined,
                      text: 'AI Analysis',
                      sub: 'feedback ready after interview',
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: context.h(56),
                child: ElevatedButton(
                  onPressed: onStart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.lightBlue500,
                    foregroundColor: AppColors.blue900,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(context.r(50)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      context.text(
                        "Let's Start",
                        style: textTheme.title2Bold.copyWith(
                          color: AppColors.blue900,
                        ),
                      ),
                      SizedBox(width: context.w(8)),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: AppColors.blue900,
                        size: context.icon(20),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: context.h(16)),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final String sub;

  const _InfoRow({required this.icon, required this.text, required this.sub});

  @override
  Widget build(BuildContext context) {
    final textTheme = context.appTextTheme;
    return Row(
      children: [
        Container(
          width: context.w(40),
          height: context.w(40),
          decoration: BoxDecoration(
            color: AppColors.lightBlue500.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: AppColors.lightBlue400,
            size: context.icon(20),
          ),
        ),
        SizedBox(width: context.w(12)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            context.text(
              text,
              style: textTheme.bodyBold.copyWith(color: Colors.white),
            ),
            context.text(
              sub,
              style: textTheme.captionRegular.copyWith(color: Colors.white60),
            ),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  INTERVIEW SESSION SCREEN
// ═══════════════════════════════════════════════════════════════════════════

class InterviewSessionScreen extends ConsumerStatefulWidget {
  final String roleName;
  final String roleId;
  final InterviewSessionType sessionType;
  final String? languagePreferred; // ← NEW

  const InterviewSessionScreen({
    super.key,
    required this.roleName,
    required this.roleId,
    required this.sessionType,
    this.languagePreferred, // ← NEW
  });

  @override
  ConsumerState<InterviewSessionScreen> createState() =>
      _InterviewSessionScreenState();
}

class _InterviewSessionScreenState
    extends ConsumerState<InterviewSessionScreen> {
  bool _showIntro = true;

  CameraController? _cameraController;
  bool _cameraEnabled = true;
  bool _micEnabled = true;

  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _audioRecordingPath;

  final AudioPlayer _ttsPlayer = AudioPlayer();

  File? _recordedFile;

  bool get _isBehavioral =>
      widget.sessionType == InterviewSessionType.behavioral;

  bool _sessionFinishedHandled = false;

  @override
  void dispose() {
    _cameraController?.dispose();
    _audioRecorder.dispose();
    _ttsPlayer.dispose();
    super.dispose();
  }

  Future<void> _startInterview() async {
    setState(() => _showIntro = false);
    await _requestPermissions();
    if (_isBehavioral) {
      await _initCamera();
      await _startVideoRecording();
    } else {
      await _startAudioRecording();
    }
    if (mounted) {
      ref.read(mockInterviewProvider.notifier).startSession(
            roleName: widget.roleName,
            roleId: widget.roleId,
            sessionType: widget.sessionType,
            languagePreferred: widget.languagePreferred, // ← NEW
          );
    }
  }

  Future<void> _requestPermissions() async {
    await Permission.camera.request();
    await Permission.microphone.request();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: true,
      );
      await _cameraController!.initialize();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _startVideoRecording() async {
    try {
      await _cameraController?.startVideoRecording();
    } catch (_) {}
  }

  Future<void> _stopVideoRecording() async {
    try {
      final xfile = await _cameraController?.stopVideoRecording();
      if (xfile != null) {
        final info = await VideoCompress.compressVideo(
          xfile.path,
          quality: VideoQuality.LowQuality,
          deleteOrigin: true,
          includeAudio: true,
        );
        _recordedFile = info?.file ?? File(xfile.path);
      }
    } catch (_) {}
  }

  Future<void> _startAudioRecording() async {
    try {
      final dir = await getTemporaryDirectory();
      _audioRecordingPath =
          '${dir.path}/interview_${DateTime.now().millisecondsSinceEpoch}.mp3';
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100,
          androidConfig: AndroidRecordConfig(
            audioSource: AndroidAudioSource.voiceCommunication,
          ),
        ),
        path: _audioRecordingPath!,
      );
    } catch (_) {}
  }

  Future<void> _stopAudioRecording() async {
    try {
      await _audioRecorder.stop();
      if (_audioRecordingPath != null) {
        _recordedFile = File(_audioRecordingPath!);
      }
    } catch (_) {}
  }

  // ── TTS ────────────────────────────────────────────────────────────────────

  bool _ttsPlaybackPaused = false;

  Future<void> _playQuestionAudio(List<int> bytes) async {
    try {
      _ttsPlaybackPaused = false;

      if (_isBehavioral) {
        await _cameraController?.pauseVideoRecording();
      } else {
        await _audioRecorder.pause();
      }

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/tts_${DateTime.now().millisecondsSinceEpoch}.mp3',
      );
      await file.writeAsBytes(bytes);
      await _ttsPlayer.setFilePath(file.path);
      await _ttsPlayer.play();

      await _ttsPlayer.playerStateStream.firstWhere(
        (s) {
          if (s.processingState == ProcessingState.completed ||
              s.processingState == ProcessingState.idle) return true;
          if (_ttsPlaybackPaused) return true;
          return false;
        },
      );
    } catch (_) {
    } finally {
      if (mounted && !_ttsPlaybackPaused) {
        if (_isBehavioral) {
          await _cameraController?.resumeVideoRecording();
        } else {
          await _audioRecorder.resume();
        }

        final currentStatus = ref.read(mockInterviewProvider).sessionStatus;
        if (currentStatus == InterviewSessionStatus.active ||
            currentStatus == InterviewSessionStatus.paused) {
          ref.read(mockInterviewProvider.notifier).startQuestionTimer();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return InterviewIntroScreen(
        roleName: widget.roleName,
        sessionType: widget.sessionType,
        onStart: _startInterview,
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(mockInterviewProvider);
    final textTheme = context.appTextTheme;

    ref.listen<MockInterviewState>(mockInterviewProvider, (prev, next) {
      if (next.sessionStatus == InterviewSessionStatus.finished &&
          prev?.sessionStatus != InterviewSessionStatus.finished &&
          !_sessionFinishedHandled) {
        _onSessionFinished();
      }
      if (next.audioBytes != null &&
          next.audioBytes != prev?.audioBytes &&
          next.audioBytes!.isNotEmpty) {
        _playQuestionAudio(next.audioBytes!);
      }
    });

    final session = state.session;
    final currentQuestion =
        session != null && state.currentQuestionIndex < session.questions.length
            ? session.questions[state.currentQuestionIndex]
            : null;
    final totalQuestions = session?.questions.length ?? 0;
    final progress = totalQuestions > 0 ? state.remainingSeconds / 45.0 : 0.0;

    return WillPopScope(
      onWillPop: () async {
        _showLeaveDialog();
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1B2A),
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(context, state, textTheme),
              _buildProgressBar(context, state, progress),
              Expanded(
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      bottom: context.h(200),
                      child: Center(
                        child: Image.asset(
                          'assets/images/mock_interview/ai_robot.png',
                          width: context.w(200),
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.smart_toy_outlined,
                            color: AppColors.lightBlue400,
                            size: context.icon(100),
                          ),
                        ),
                      ),
                    ),
                    if (_isBehavioral)
                      Positioned(
                        right: context.w(16),
                        top: context.h(16),
                        child: _buildUserCamera(context),
                      ),
                    if (!_isBehavioral)
                      Positioned(
                        right: context.w(16),
                        top: context.h(16),
                        child: Container(
                          width: context.w(56),
                          height: context.w(56),
                          decoration: BoxDecoration(
                            color: AppColors.purple500.withOpacity(0.85),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white24,
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            Icons.mic_rounded,
                            color: Colors.white,
                            size: context.icon(26),
                          ),
                        ),
                      ),
                    Positioned(
                      left: context.w(16),
                      right: context.w(16),
                      bottom: context.h(8),
                      child: _buildQuestionCard(
                        context,
                        state,
                        currentQuestion,
                        textTheme,
                      ),
                    ),
                  ],
                ),
              ),
              _buildBottomControls(context, state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    MockInterviewState state,
    AppTextTheme textTheme,
  ) {
    final session = state.session;
    final total = session?.questions.length ?? 0;
    final current = state.currentQuestionIndex + 1;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.w(16),
        vertical: context.h(12),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _showLeaveDialog,
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: context.icon(20),
            ),
          ),
          const Spacer(),
          Column(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.w(10),
                  vertical: context.h(4),
                ),
                decoration: BoxDecoration(
                  color: _isBehavioral
                      ? AppColors.lightBlue600
                      : AppColors.purple500,
                  borderRadius: BorderRadius.circular(context.r(20)),
                ),
                child: context.text(
                  _isBehavioral ? 'Behavioral' : 'Technical',
                  style: textTheme.captionBold.copyWith(color: Colors.white),
                ),
              ),
              // ── Language badge ────────────────────────────────────────
              if (widget.languagePreferred != null) ...[
                SizedBox(height: context.h(4)),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.w(8),
                    vertical: context.h(2),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(context.r(12)),
                  ),
                  child: context.text(
                    widget.languagePreferred == 'ar' ? '🇪🇬 AR' : '🇬🇧 EN',
                    style: textTheme.captionRegular.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              context.text(
                'Q $current / $total',
                style: textTheme.captionBold.copyWith(color: Colors.white70),
              ),
              Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    color: state.remainingSeconds <= 10
                        ? AppColors.red400
                        : Colors.white,
                    size: context.icon(14),
                  ),
                  SizedBox(width: context.w(2)),
                  context.text(
                    '${state.remainingSeconds}s',
                    style: textTheme.bodyBold.copyWith(
                      color: state.remainingSeconds <= 10
                          ? AppColors.red400
                          : Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(
    BuildContext context,
    MockInterviewState state,
    double progress,
  ) {
    final isLow = state.remainingSeconds <= 10;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.w(16),
        vertical: context.h(4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(context.r(4)),
        child: LinearProgressIndicator(
          value: state.waitingForAudio ? null : progress.clamp(0.0, 1.0),
          minHeight: context.h(4),
          backgroundColor: Colors.white.withOpacity(0.15),
          valueColor: AlwaysStoppedAnimation<Color>(
            isLow ? AppColors.red400 : AppColors.lightBlue500,
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionCard(
    BuildContext context,
    MockInterviewState state,
    InterviewQuestionEntity? currentQuestion,
    AppTextTheme textTheme,
  ) {
    if (state.sessionStatus == InterviewSessionStatus.starting ||
        state.session == null) {
      return Container(
        padding: EdgeInsets.all(context.w(20)),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(context.r(20)),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: context.w(18),
              height: context.w(18),
              child: const CircularProgressIndicator(
                color: AppColors.lightBlue400,
                strokeWidth: 2,
              ),
            ),
            SizedBox(width: context.w(12)),
            context.text(
              'Preparing your interview...',
              style: textTheme.bodyRegular.copyWith(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    final isWaiting = state.waitingForAudio || state.isLoadingAudio;

    return Container(
      padding: EdgeInsets.all(context.w(20)),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(context.r(20)),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: context.w(28),
                height: context.w(28),
                decoration: BoxDecoration(
                  color: AppColors.lightBlue500.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.record_voice_over_outlined,
                  color: AppColors.lightBlue400,
                  size: context.icon(14),
                ),
              ),
              SizedBox(width: context.w(8)),
              context.text(
                isWaiting ? 'Loading question...' : 'Question',
                style: textTheme.captionBold.copyWith(
                  color: AppColors.lightBlue400,
                ),
              ),
              if (isWaiting) ...[
                SizedBox(width: context.w(8)),
                SizedBox(
                  width: context.w(12),
                  height: context.w(12),
                  child: const CircularProgressIndicator(
                    color: AppColors.lightBlue400,
                    strokeWidth: 1.5,
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: context.h(12)),
          if (currentQuestion != null)
            context.text(
              currentQuestion.questionText,
              style: textTheme.title2Bold.copyWith(
                color: Colors.white,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          SizedBox(height: context.h(8)),
        ],
      ),
    );
  }

  Widget _buildUserCamera(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return Container(
        width: context.w(80),
        height: context.h(100),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(context.r(12)),
          border: Border.all(color: Colors.white24),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: AppColors.lightBlue500,
            strokeWidth: 2,
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(context.r(12)),
      child: Container(
        width: context.w(80),
        height: context.h(100),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white24),
          borderRadius: BorderRadius.circular(context.r(12)),
        ),
        child: CameraPreview(_cameraController!),
      ),
    );
  }

  Widget _buildBottomControls(BuildContext context, MockInterviewState state) {
    return Container(
      color: Colors.black.withOpacity(0.5),
      padding: EdgeInsets.symmetric(
        horizontal: context.w(24),
        vertical: context.h(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (_isBehavioral)
            _ControlButton(
              icon: _cameraEnabled
                  ? Icons.videocam_rounded
                  : Icons.videocam_off_rounded,
              color: _cameraEnabled ? AppColors.lightBlue500 : Colors.white24,
              onTap: _toggleCamera,
            ),
          _ControlButton(
            icon: _micEnabled ? Icons.mic_rounded : Icons.mic_off_rounded,
            color: _micEnabled ? AppColors.lightBlue500 : Colors.white24,
            onTap: _toggleMic,
          ),
          _ControlButton(
            icon: Icons.pause_rounded,
            color: Colors.white24,
            onTap: _showPauseDialog,
          ),
          if (state.sessionStatus == InterviewSessionStatus.active &&
              !state.waitingForAudio)
            _ControlButton(
              icon: Icons.skip_next_rounded,
              color: AppColors.lightBlue600,
              onTap: () =>
                  ref.read(mockInterviewProvider.notifier).skipToNext(),
            ),
          _ControlButton(
            icon: Icons.call_end_rounded,
            color: AppColors.red500,
            onTap: _showLeaveDialog,
          ),
        ],
      ),
    );
  }

  void _toggleCamera() {
    if (_cameraEnabled) {
      _ttsPlaybackPaused = true;
      _ttsPlayer.pause();
      ref.read(mockInterviewProvider.notifier).pauseInterview();
      setState(() => _cameraEnabled = false);
      _showCameraDialog();
    } else {
      _ttsPlaybackPaused = false;
      setState(() => _cameraEnabled = true);
      _ttsPlayer.play();
      ref.read(mockInterviewProvider.notifier).resumeInterview();
    }
  }

  void _toggleMic() {
    if (_micEnabled) {
      _ttsPlaybackPaused = true;
      _ttsPlayer.pause();
      ref.read(mockInterviewProvider.notifier).pauseInterview();
      setState(() => _micEnabled = false);
      _showMicDialog();
    } else {
      _ttsPlaybackPaused = false;
      setState(() => _micEnabled = true);
      _ttsPlayer.play();
      ref.read(mockInterviewProvider.notifier).resumeInterview();
    }
  }

  void _showPauseDialog() {
    _ttsPlaybackPaused = true;
    _ttsPlayer.pause();
    ref.read(mockInterviewProvider.notifier).pauseInterview();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PauseDialog(
        onGoHome: _showLeaveDialog,
        onRestart: _showRestartDialog,
        onResume: () {
          _ttsPlaybackPaused = false;
          ref.read(mockInterviewProvider.notifier).resumeInterview();

          final playerState = _ttsPlayer.processingState;
          if (playerState == ProcessingState.ready ||
              playerState == ProcessingState.buffering ||
              playerState == ProcessingState.loading) {
            _ttsPlayer.play();
          } else {
            Future.microtask(() {
              if (mounted) {
                ref.read(mockInterviewProvider.notifier).startQuestionTimer();
              }
            });
          }
        },
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

  Future<void> _onSessionFinished() async {
    if (_sessionFinishedHandled) return;
    _sessionFinishedHandled = true;

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const ProcessingDialog(),
      );
    }

    if (_isBehavioral) {
      await _stopVideoRecording();
    } else {
      await _stopAudioRecording();
    }

    if (_recordedFile != null) {
      await ref.read(mockInterviewProvider.notifier).uploadAndNotify(
            mediaFile: _recordedFile!,
            roleName: widget.roleName,
          );
    }

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => InterviewCompletedDialog(
          onGoHome: () {
            ref.read(mockInterviewProvider.notifier).resetSession();
            context.go('/home');
          },
          onStartNew: () {
            ref.read(mockInterviewProvider.notifier).resetSession();
            context.go('/mock-interview');
          },
        ),
      );
    }
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
        width: context.w(52),
        height: context.w(52),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: context.icon(22)),
      ),
    );
  }
}

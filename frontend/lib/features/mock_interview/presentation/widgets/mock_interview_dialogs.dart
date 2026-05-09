import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../../../../core/theme/app_text_theme.dart';
import '../../data/datasources/interview_roles.dart';
import '../../domain/entities/interview_entities.dart';

// ─── Shared helpers ───────────────────────────────────────────────────────────

Widget _buildDialog({
  required BuildContext context,
  required bool isDark,
  required Widget child,
}) {
  return Dialog(
    backgroundColor: isDark ? AppColors.blue700 : AppColors.grey50,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(context.r(16)),
    ),
    child: Padding(
      padding: EdgeInsets.all(context.w(24)),
      child: child,
    ),
  );
}

Widget _actionRow({
  required BuildContext context,
  required bool isDark,
  required AppTextTheme textTheme,
  required String cancelLabel,
  required String confirmLabel,
  required Color confirmColor,
  required VoidCallback onCancel,
  required VoidCallback onConfirm,
}) {
  final textPrimary = isDark ? AppColors.grey50 : AppColors.blue900;
  return Row(
    children: [
      Expanded(
        child: SizedBox(
          height: context.h(44),
          child: OutlinedButton(
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: textPrimary,
              side: BorderSide(
                  color: isDark ? AppColors.blue300 : AppColors.grey400),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(context.r(50))),
            ),
            child: context.text(cancelLabel,
                style: textTheme.bodyBold.copyWith(color: textPrimary)),
          ),
        ),
      ),
      SizedBox(width: context.w(12)),
      Expanded(
        child: SizedBox(
          height: context.h(44),
          child: ElevatedButton(
            onPressed: onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: AppColors.grey50,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(context.r(50))),
            ),
            child: context.text(confirmLabel,
                style:
                    textTheme.bodyBold.copyWith(color: AppColors.grey50)),
          ),
        ),
      ),
    ],
  );
}

// ─── 1. Select Job Dialog ─────────────────────────────────────────────────────

class SelectJobDialog extends ConsumerStatefulWidget {
  /// Called with (roleName, roleId) when Start Interview is tapped
  final void Function(String roleName, String roleId) onStart;

  /// If provided, pre-fills the job title (from job matching feature)
  final String? prefilledJobTitle;

  const SelectJobDialog({
    super.key,
    required this.onStart,
    this.prefilledJobTitle,
  });

  @override
  ConsumerState<SelectJobDialog> createState() => _SelectJobDialogState();
}

class _SelectJobDialogState extends ConsumerState<SelectJobDialog> {
  InterviewRole? _selectedRole;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    if (widget.prefilledJobTitle != null) {
      _selectedRole =
          InterviewRoles.findByName(widget.prefilledJobTitle!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = context.appTextTheme;
    final textPrimary = isDark ? AppColors.grey50 : AppColors.blue900;
    final textMuted = isDark ? AppColors.grey300 : AppColors.grey800;
    final cardBg = isDark ? AppColors.blue600 : AppColors.grey100;
    final borderColor =
        isDark ? AppColors.blue400 : AppColors.grey300;

    return Dialog(
      backgroundColor: isDark ? AppColors.blue700 : AppColors.grey50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.r(16)),
      ),
      child: Padding(
        padding: EdgeInsets.all(context.w(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Close button
            Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Icon(Icons.close,
                    color: AppColors.red500, size: context.icon(22)),
              ),
            ),
            SizedBox(height: context.h(4)),
            // Title
            Center(
              child: context.text(
                'Select Job for New Interview',
                style: textTheme.title1Bold.copyWith(color: textPrimary),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: context.h(8)),
            Center(
              child: context.text(
                'Please choose the job you want to take the interview for.',
                style: textTheme.bodyRegular.copyWith(color: textMuted),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: context.h(20)),

            // Dropdown
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(context.r(12)),
                border: Border.all(color: borderColor),
              ),
              padding: EdgeInsets.symmetric(
                  horizontal: context.w(12), vertical: context.h(4)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<InterviewRole>(
                  isExpanded: true,
                  value: _selectedRole,
                  hint: context.text(
                    'e.g.   ML Engineer, UI/UX Designer',
                    style: textTheme.bodyRegular
                        .copyWith(color: AppColors.grey700),
                  ),
                  dropdownColor:
                      isDark ? AppColors.blue600 : AppColors.grey50,
                  icon: Icon(Icons.keyboard_arrow_down_rounded,
                      color: textMuted, size: context.icon(20)),
                  items: InterviewRoles.roles
                      .map((role) => DropdownMenuItem<InterviewRole>(
                            value: role,
                            child: context.text(
                              role.roleName,
                              style: textTheme.bodyRegular
                                  .copyWith(color: textPrimary),
                            ),
                          ))
                      .toList(),
                  onChanged: (role) {
                    setState(() {
                      _selectedRole = role;
                      _errorText = null;
                    });
                  },
                  selectedItemBuilder: (context) => InterviewRoles.roles
                      .map((role) => Align(
                            alignment: Alignment.centerLeft,
                            child: context.text(
                              role.roleName,
                              style: textTheme.bodyRegular
                                  .copyWith(color: textPrimary),
                            ),
                          ))
                      .toList(),
                ),
              ),
            ),

            if (_errorText != null) ...[
              SizedBox(height: context.h(6)),
              context.text(_errorText!,
                  style: textTheme.captionRegular
                      .copyWith(color: AppColors.red500)),
            ],

            SizedBox(height: context.h(24)),

            // Start Interview button
            SizedBox(
              width: double.infinity,
              height: context.h(50),
              child: ElevatedButton(
                onPressed: _handleStart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.lightBlue500,
                  foregroundColor: AppColors.blue700,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(context.r(50))),
                ),
                child: context.text(
                  'Start Interview',
                  style: textTheme.title2Bold
                      .copyWith(color: AppColors.blue700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleStart() {
    if (_selectedRole == null) {
      setState(
          () => _errorText = 'Please select a job title to continue.');
      return;
    }
    Navigator.of(context).pop();
    widget.onStart(_selectedRole!.roleName, _selectedRole!.roleId);
  }
}

// ─── 2. Delete Interview Feedback Dialog ──────────────────────────────────────

class DeleteInterviewFeedbackDialog extends StatelessWidget {
  final VoidCallback onConfirm;

  const DeleteInterviewFeedbackDialog({super.key, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = context.appTextTheme;
    final textPrimary = isDark ? AppColors.grey50 : AppColors.blue900;
    final textMuted = isDark ? AppColors.grey300 : AppColors.grey800;

    return _buildDialog(
      context: context,
      isDark: isDark,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          context.text('Delete Interview Feedback',
              style: textTheme.title2Bold.copyWith(color: textPrimary),
              textAlign: TextAlign.center),
          SizedBox(height: context.h(12)),
          context.text(
            'Are you sure you want to delete this interview feedback? You won\'t be able to recover it later.',
            style: textTheme.bodyRegular.copyWith(color: textMuted),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: context.h(24)),
          _actionRow(
            context: context,
            isDark: isDark,
            textTheme: textTheme,
            cancelLabel: 'Cancel',
            confirmLabel: 'Delete',
            confirmColor: AppColors.red500,
            onCancel: () => Navigator.of(context).pop(),
            onConfirm: () {
              Navigator.of(context).pop();
              onConfirm();
            },
          ),
        ],
      ),
    );
  }
}

// ─── 3. Camera Required Dialog ────────────────────────────────────────────────

class CameraRequiredDialog extends StatelessWidget {
  final VoidCallback onEnableCamera;
  final VoidCallback onGoHome;

  const CameraRequiredDialog({
    super.key,
    required this.onEnableCamera,
    required this.onGoHome,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = context.appTextTheme;
    final textPrimary = isDark ? AppColors.grey50 : AppColors.blue900;
    final textMuted = isDark ? AppColors.grey300 : AppColors.grey800;

    return _buildDialog(
      context: context,
      isDark: isDark,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          context.text('Camera Required',
              style: textTheme.title2Bold.copyWith(color: textPrimary),
              textAlign: TextAlign.center),
          SizedBox(height: context.h(12)),
          context.text(
            'Your camera is turned off.\n\nThe interview is paused and cannot continue until you enable your camera.',
            style: textTheme.bodyRegular.copyWith(color: textMuted),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: context.h(24)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Home
              _CircleIconButton(
                icon: Icons.home_rounded,
                color: AppColors.lightBlue600,
                onTap: () {
                  Navigator.of(context).pop();
                  onGoHome();
                },
              ),
              SizedBox(width: context.w(24)),
              // Enable camera
              _CircleIconButton(
                icon: Icons.videocam_rounded,
                color: AppColors.red400,
                onTap: () {
                  Navigator.of(context).pop();
                  onEnableCamera();
                },
                isDisabled: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── 4. Microphone Required Dialog ───────────────────────────────────────────

class MicrophoneRequiredDialog extends StatelessWidget {
  final VoidCallback onEnableMic;
  final VoidCallback onGoHome;

  const MicrophoneRequiredDialog({
    super.key,
    required this.onEnableMic,
    required this.onGoHome,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = context.appTextTheme;
    final textPrimary = isDark ? AppColors.grey50 : AppColors.blue900;
    final textMuted = isDark ? AppColors.grey300 : AppColors.grey800;

    return _buildDialog(
      context: context,
      isDark: isDark,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          context.text('Microphone Required',
              style: textTheme.title2Bold.copyWith(color: textPrimary),
              textAlign: TextAlign.center),
          SizedBox(height: context.h(12)),
          context.text(
            'Your microphone is turned off.\n\nThe interview is paused and cannot continue until you enable your microphone.',
            style: textTheme.bodyRegular.copyWith(color: textMuted),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: context.h(24)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CircleIconButton(
                icon: Icons.home_rounded,
                color: AppColors.lightBlue600,
                onTap: () {
                  Navigator.of(context).pop();
                  onGoHome();
                },
              ),
              SizedBox(width: context.w(24)),
              _CircleIconButton(
                icon: Icons.mic_off_rounded,
                color: AppColors.red400,
                onTap: () {
                  Navigator.of(context).pop();
                  onEnableMic();
                },
                isDisabled: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── 5. Pause Dialog ──────────────────────────────────────────────────────────

class PauseDialog extends StatelessWidget {
  final VoidCallback onGoHome;
  final VoidCallback onRestart;
  final VoidCallback onResume;

  const PauseDialog({
    super.key,
    required this.onGoHome,
    required this.onRestart,
    required this.onResume,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = context.appTextTheme;
    final textPrimary = isDark ? AppColors.grey50 : AppColors.blue900;
    final dividerColor =
        isDark ? AppColors.blue400.withOpacity(0.4) : AppColors.grey300;
    final bgColor = isDark ? AppColors.blue700 : AppColors.grey50;

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(context.r(16))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: context.w(24), vertical: context.h(16)),
            child: context.text(
              'pause',
              style: textTheme.title2Bold.copyWith(color: textPrimary),
              textAlign: TextAlign.center,
            ),
          ),
          Divider(height: 1, color: dividerColor),
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: context.w(24), vertical: context.h(20)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Home
                _CircleIconButton(
                  icon: Icons.home_rounded,
                  color: AppColors.lightBlue600,
                  onTap: () {
                    Navigator.of(context).pop();
                    onGoHome();
                  },
                ),
                // Restart
                _CircleIconButton(
                  icon: Icons.refresh_rounded,
                  color: AppColors.lightBlue600,
                  onTap: () {
                    Navigator.of(context).pop();
                    onRestart();
                  },
                ),
                // Resume (play)
                _CircleIconButton(
                  icon: Icons.play_arrow_rounded,
                  color: AppColors.lightBlue600,
                  onTap: () {
                    Navigator.of(context).pop();
                    onResume();
                  },
                ),
              ],
            ),
          ),
          Divider(height: 1, color: dividerColor),
          SizedBox(height: context.h(8)),
        ],
      ),
    );
  }
}

// ─── 6. Leave Interview Dialog ────────────────────────────────────────────────

class LeaveInterviewDialog extends StatelessWidget {
  final VoidCallback onLeave;

  const LeaveInterviewDialog({super.key, required this.onLeave});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = context.appTextTheme;
    final textPrimary = isDark ? AppColors.grey50 : AppColors.blue900;
    final textMuted = isDark ? AppColors.grey300 : AppColors.grey800;

    return _buildDialog(
      context: context,
      isDark: isDark,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          context.text('Are you sure you want to leave?',
              style: textTheme.title2Bold.copyWith(color: textPrimary),
              textAlign: TextAlign.center),
          SizedBox(height: context.h(12)),
          context.text(
            'If you exit now, your progress will be lost and we won\'t be able to generate your feedback.',
            style: textTheme.bodyRegular.copyWith(color: textMuted),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: context.h(24)),
          _actionRow(
            context: context,
            isDark: isDark,
            textTheme: textTheme,
            cancelLabel: 'Cancel',
            confirmLabel: 'Leave',
            confirmColor: AppColors.red500,
            onCancel: () => Navigator.of(context).pop(),
            onConfirm: () {
              Navigator.of(context).pop();
              onLeave();
            },
          ),
        ],
      ),
    );
  }
}

// ─── 7. Restart Interview Dialog ──────────────────────────────────────────────

class RestartInterviewDialog extends StatelessWidget {
  final VoidCallback onRestart;

  const RestartInterviewDialog({super.key, required this.onRestart});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = context.appTextTheme;
    final textPrimary = isDark ? AppColors.grey50 : AppColors.blue900;
    final textMuted = isDark ? AppColors.grey300 : AppColors.grey800;

    return _buildDialog(
      context: context,
      isDark: isDark,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          context.text(
              'Are you sure you want to restart this interview?',
              style: textTheme.title2Bold.copyWith(color: textPrimary),
              textAlign: TextAlign.center),
          SizedBox(height: context.h(12)),
          context.text(
            'Your current progress will be lost and a new interview will begin.',
            style: textTheme.bodyRegular.copyWith(color: textMuted),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: context.h(24)),
          _actionRow(
            context: context,
            isDark: isDark,
            textTheme: textTheme,
            cancelLabel: 'Cancel',
            confirmLabel: 'Restart',
            confirmColor: AppColors.red500,
            onCancel: () => Navigator.of(context).pop(),
            onConfirm: () {
              Navigator.of(context).pop();
              onRestart();
            },
          ),
        ],
      ),
    );
  }
}

// ─── 8. Interview Completed Dialog ────────────────────────────────────────────

class InterviewCompletedDialog extends StatelessWidget {
  final VoidCallback onGotIt;

  const InterviewCompletedDialog({super.key, required this.onGotIt});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = context.appTextTheme;
    final textPrimary = isDark ? AppColors.grey50 : AppColors.blue900;
    final textMuted = isDark ? AppColors.grey300 : AppColors.grey800;

    return _buildDialog(
      context: context,
      isDark: isDark,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          context.text('Interview Completed',
              style: textTheme.title2Bold.copyWith(color: textPrimary),
              textAlign: TextAlign.center),
          SizedBox(height: context.h(12)),
          context.text(
            'You\'ll receive an alert once your interview feedback is ready.',
            style: textTheme.bodyRegular.copyWith(color: textMuted),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: context.h(24)),
          SizedBox(
            width: double.infinity,
            height: context.h(50),
            child: ElevatedButton(
              onPressed: onGotIt,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.lightBlue600,
                foregroundColor: AppColors.grey50,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(context.r(50))),
              ),
              child: context.text('Got it',
                  style: textTheme.title2Bold
                      .copyWith(color: AppColors.grey50)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared: Circle Icon Button ───────────────────────────────────────────────

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isDisabled;

  const _CircleIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: context.w(48),
        height: context.w(48),
        decoration: BoxDecoration(
          color: isDisabled ? color.withOpacity(0.3) : color,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: context.icon(22)),
      ),
    );
  }
}

// lib/features/job_matching/presentation/widgets/job_matching_dialogs.dart

import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../../../../core/theme/app_text_theme.dart';

// ─── Preferences Saved Dialog ─────────────────────────────────────────────────

class PreferencesSavedDialog extends StatelessWidget {
  const PreferencesSavedDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = context.appTextTheme;
    final bgColor = isDark ? AppColors.blue700 : AppColors.grey50;
    final textPrimary = isDark ? AppColors.grey50 : AppColors.blue900;
    final textMuted = isDark ? AppColors.grey400 : AppColors.grey700;
    final btnColor = isDark ? AppColors.lightBlue500 : AppColors.lightBlue700;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: context.w(24)),
      child: Container(
        padding: EdgeInsets.all(context.w(24)),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(context.r(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Confetti + checkmark badge
            SizedBox(
              height: context.h(100),
              width: context.w(100),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Scattered dots to mimic confetti
                  ...List.generate(12, (i) {
                    final angles = [
                      0.2,
                      0.8,
                      1.4,
                      2.0,
                      2.6,
                      3.2,
                      3.8,
                      4.4,
                      5.0,
                      5.6,
                      0.5,
                      1.1
                    ];
                    final radii = [
                      38.0,
                      42.0,
                      36.0,
                      40.0,
                      38.0,
                      42.0,
                      36.0,
                      40.0,
                      38.0,
                      42.0,
                      44.0,
                      34.0
                    ];
                    final sizes = [
                      4.0,
                      3.0,
                      5.0,
                      3.0,
                      4.0,
                      3.0,
                      5.0,
                      4.0,
                      3.0,
                      5.0,
                      3.0,
                      4.0
                    ];
                    final angle = angles[i];
                    final radius = radii[i];
                    return Positioned(
                      left: 50 +
                          radius *
                              0.7 *
                              (i % 2 == 0 ? 1 : -1) *
                              (i < 6 ? 0.8 : 1.0),
                      top: 50 +
                          radius *
                              0.5 *
                              (i < 3
                                  ? -1
                                  : i < 6
                                      ? 1
                                      : i < 9
                                          ? -0.5
                                          : 0.5),
                      child: Container(
                        width: sizes[i],
                        height: sizes[i],
                        decoration: BoxDecoration(
                          color: i % 3 == 0
                              ? AppColors.green500
                              : i % 3 == 1
                                  ? AppColors.lightBlue500
                                  : AppColors.green300,
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  }),
                  // Badge
                  Container(
                    width: context.w(64),
                    height: context.w(64),
                    decoration: BoxDecoration(
                      color: AppColors.green700,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      color: AppColors.grey50,
                      size: context.icon(32),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: context.h(16)),

            Text(
              'Preferences saved!',
              style: textTheme.title1Bold.copyWith(color: textPrimary),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: context.h(8)),
            Text(
              "You'll receive a alert when your job recommendations are ready.",
              style: textTheme.bodyRegular.copyWith(color: textMuted),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: context.h(24)),

            SizedBox(
              width: double.infinity,
              height: context.h(48),
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: btnColor,
                  foregroundColor:
                      isDark ? AppColors.blue900 : AppColors.grey50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(context.r(50)),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Got it',
                  style: textTheme.title2Bold.copyWith(
                    color: isDark ? AppColors.blue900 : AppColors.grey50,
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

// ─── AI Career Preparation Dialog ─────────────────────────────────────────────

class AiCareerPreparationDialog extends StatelessWidget {
  final VoidCallback onOptimizeResume;
  final VoidCallback onMockInterview;

  const AiCareerPreparationDialog({
    super.key,
    required this.onOptimizeResume,
    required this.onMockInterview,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = context.appTextTheme;
    final bgColor = isDark ? AppColors.blue700 : AppColors.grey50;
    final textPrimary = isDark ? AppColors.grey50 : AppColors.blue900;
    final textMuted = isDark ? AppColors.grey400 : AppColors.grey700;
    final btnColor = isDark ? AppColors.lightBlue500 : AppColors.lightBlue700;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: context.w(24)),
      child: Container(
        padding: EdgeInsets.all(context.w(24)),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(context.r(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Close button
            Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Icon(
                  Icons.close,
                  color: AppColors.red500,
                  size: context.icon(22),
                ),
              ),
            ),

            SizedBox(height: context.h(4)),

            Text(
              'AI Career Preparation',
              style: textTheme.title1Bold.copyWith(color: textPrimary),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: context.h(8)),
            Text(
              'Choose what you want to improve first:',
              style: textTheme.bodyRegular.copyWith(color: textMuted),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: context.h(24)),

            // Optimize Resume button
            SizedBox(
              width: double.infinity,
              height: context.h(52),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onOptimizeResume();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: btnColor,
                  foregroundColor:
                      isDark ? AppColors.blue900 : AppColors.grey50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(context.r(50)),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Optimize My Resume',
                  style: textTheme.title2Bold.copyWith(
                    color: isDark ? AppColors.blue900 : AppColors.grey50,
                  ),
                ),
              ),
            ),

            SizedBox(height: context.h(12)),

            // AI Mock Interview button
            SizedBox(
              width: double.infinity,
              height: context.h(52),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onMockInterview();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: btnColor,
                  foregroundColor:
                      isDark ? AppColors.blue900 : AppColors.grey50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(context.r(50)),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'AI Mock Interview',
                  style: textTheme.title2Bold.copyWith(
                    color: isDark ? AppColors.blue900 : AppColors.grey50,
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

// ─── AI Interview Confirm Dialog ──────────────────────────────────────────────

class AiInterviewConfirmDialog extends StatelessWidget {
  final VoidCallback onStartInterview;

  const AiInterviewConfirmDialog({
    super.key,
    required this.onStartInterview,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = context.appTextTheme;
    final bgColor = isDark ? AppColors.blue700 : AppColors.grey50;
    final textPrimary = isDark ? AppColors.grey50 : AppColors.blue900;
    final btnColor = isDark ? AppColors.lightBlue500 : AppColors.lightBlue700;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: context.w(24)),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.w(24),
          vertical: context.h(20),
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(context.r(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ready to start the AI interview?',
              style: textTheme.title2Bold.copyWith(color: textPrimary),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: context.h(20)),
            Row(
              children: [
                // Cancel
                Expanded(
                  child: SizedBox(
                    height: context.h(44),
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: isDark ? AppColors.grey400 : AppColors.grey600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(context.r(50)),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: textTheme.bodyMedium.copyWith(
                          color: isDark ? AppColors.grey300 : AppColors.grey700,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: context.w(12)),
                // Start Interview
                Expanded(
                  child: SizedBox(
                    height: context.h(44),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        onStartInterview();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: btnColor,
                        foregroundColor:
                            isDark ? AppColors.blue900 : AppColors.grey50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(context.r(50)),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Start Interview',
                        style: textTheme.bodyBold.copyWith(
                          color: isDark ? AppColors.blue900 : AppColors.grey50,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Resume Upload Dialog (Job Matching version — CV only, no JD field) ───────
// This is a simpler version of OptimizationUploadDialog
// It takes a jobDescription from the job and passes it internally.

class JobMatchingResumeDialog extends StatelessWidget {
  /// Called when user taps "Start Optimization"
  /// Passes the selected CV file path
  final void Function(String cvPath) onStartOptimization;
  final String? currentCvFileName;
  final String? currentCvPath;

  const JobMatchingResumeDialog({
    super.key,
    required this.onStartOptimization,
    this.currentCvFileName,
    this.currentCvPath,
  });

  @override
  Widget build(BuildContext context) {
    // We'll use a StatefulWidget wrapper here
    return _JobMatchingResumeDialogContent(
      onStartOptimization: onStartOptimization,
      currentCvFileName: currentCvFileName,
      currentCvPath: currentCvPath,
    );
  }
}

class _JobMatchingResumeDialogContent extends StatefulWidget {
  final void Function(String cvPath) onStartOptimization;
  final String? currentCvFileName;
  final String? currentCvPath;

  const _JobMatchingResumeDialogContent({
    required this.onStartOptimization,
    this.currentCvFileName,
    this.currentCvPath,
  });

  @override
  State<_JobMatchingResumeDialogContent> createState() =>
      _JobMatchingResumeDialogContentState();
}

class _JobMatchingResumeDialogContentState
    extends State<_JobMatchingResumeDialogContent> {
  String? _filePath;
  String? _fileName;

  @override
  void initState() {
    super.initState();
    _filePath = widget.currentCvPath;
    _fileName = widget.currentCvFileName;
  }

  Future<void> _pickFile() async {
    // file_picker is already in the project
    // import 'package:file_picker/file_picker.dart';
    // We import it at top of the real file
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = context.appTextTheme;
    final bgColor = isDark ? AppColors.blue700 : AppColors.grey50;
    final textPrimary = isDark ? AppColors.grey50 : AppColors.blue900;
    final textMuted = isDark ? AppColors.grey400 : AppColors.grey700;
    final uploadBg =
        isDark ? AppColors.blue600.withOpacity(0.5) : AppColors.grey100;
    final borderColor =
        isDark ? AppColors.blue400.withOpacity(0.5) : AppColors.grey300;
    final btnColor = isDark ? AppColors.lightBlue500 : AppColors.lightBlue700;

    final hasFile = _filePath != null;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: context.w(24)),
      child: Container(
        padding: EdgeInsets.all(context.w(24)),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(context.r(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Resume Optimization',
                    style: textTheme.title1Bold.copyWith(color: textPrimary),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Icon(
                    Icons.close,
                    color: AppColors.red500,
                    size: context.icon(22),
                  ),
                ),
              ],
            ),
            SizedBox(height: context.h(8)),
            Text(
              "Upload your CV and we'll match it automatically with this job description.",
              style: textTheme.bodyRegular.copyWith(color: textMuted),
            ),
            SizedBox(height: context.h(20)),

            Text(
              'Upload CV',
              style: textTheme.bodyBold.copyWith(color: textPrimary),
            ),
            SizedBox(height: context.h(8)),

            // Upload area
            GestureDetector(
              onTap: _pickFile,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: context.h(28)),
                decoration: BoxDecoration(
                  color: uploadBg,
                  borderRadius: BorderRadius.circular(context.r(12)),
                  border: Border.all(
                    color: hasFile ? AppColors.lightBlue500 : borderColor,
                    width: hasFile ? 1.5 : 1,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      hasFile
                          ? Icons.description_outlined
                          : Icons.upload_file_outlined,
                      color: hasFile
                          ? AppColors.lightBlue500
                          : (isDark
                              ? AppColors.lightBlue400
                              : AppColors.lightBlue700),
                      size: context.icon(36),
                    ),
                    SizedBox(height: context.h(8)),
                    Text(
                      hasFile ? 'click to Change' : 'click to upload',
                      style: textTheme.bodyMedium.copyWith(color: textPrimary),
                    ),
                    if (hasFile && _fileName != null) ...[
                      SizedBox(height: context.h(6)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.delete_outline,
                            color: AppColors.red500,
                            size: context.icon(14),
                          ),
                          SizedBox(width: context.w(4)),
                          Text(
                            _fileName!,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: context.sp(12),
                              color: AppColors.red500,
                            ),
                          ),
                        ],
                      ),
                    ] else if (!hasFile) ...[
                      SizedBox(height: context.h(4)),
                      Text(
                        'Supported formats: PDF, DOCX (max 10 MB)',
                        style:
                            textTheme.captionRegular.copyWith(color: textMuted),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            SizedBox(height: context.h(20)),

            // Start button
            SizedBox(
              width: double.infinity,
              height: context.h(52),
              child: ElevatedButton(
                onPressed: _filePath == null
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        widget.onStartOptimization(_filePath!);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: btnColor,
                  foregroundColor:
                      isDark ? AppColors.blue900 : AppColors.grey50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(context.r(50)),
                  ),
                  elevation: 0,
                  disabledBackgroundColor: btnColor.withOpacity(0.4),
                ),
                child: Text(
                  'Start Optimization',
                  style: textTheme.title2Bold.copyWith(
                    color: isDark ? AppColors.blue900 : AppColors.grey50,
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

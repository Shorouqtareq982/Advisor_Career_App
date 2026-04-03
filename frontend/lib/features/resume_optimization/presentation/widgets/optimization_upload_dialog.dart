import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../../../../core/theme/app_text_theme.dart';
import '../providers/resume_optimization_provider.dart';
import 'analysis_pending_dialog.dart';

// ─── Progress Loading Overlay ─────────────────────────────────────────────────

class _AnalysisLoadingOverlay extends ConsumerStatefulWidget {
  final VoidCallback onTimeout;
  final void Function(String errorMessage) onError;

  const _AnalysisLoadingOverlay({
    required this.onTimeout,
    required this.onError,
  });

  @override
  ConsumerState<_AnalysisLoadingOverlay> createState() =>
      _AnalysisLoadingOverlayState();
}

class _AnalysisLoadingOverlayState
    extends ConsumerState<_AnalysisLoadingOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  Timer? _timeoutTimer;
  bool _completing = false;

  static const _maxSeconds = 120;

  @override
  void initState() {
    super.initState();

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _maxSeconds),
      lowerBound: 0.0,
      upperBound: 0.95,
    )..forward();

    _timeoutTimer =
        Timer(const Duration(seconds: _maxSeconds), widget.onTimeout);
  }

  @override
  void dispose() {
    _progressController.dispose();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  /// Success
  void _completeAndClose() {
    if (_completing) return;
    _completing = true;
    _timeoutTimer?.cancel();

    _progressController
        .animateTo(
      1.0,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
    )
        .then((_) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  /// Error: close immediately and pass error message to parent
  void _closeWithError(String errorMessage) {
    if (_completing) return;
    _completing = true;
    _timeoutTimer?.cancel();
    _progressController.stop();

    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onError(errorMessage);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ResumeOptimizationState>(resumeOptimizationProvider,
        (prev, next) {
      if (next.analysisStatus == AnalysisStatus.success) {
        _completeAndClose();
      } else if (next.analysisStatus == AnalysisStatus.error) {
        _closeWithError(
          next.errorMessage ?? 'Something went wrong. Please try again.',
        );
      }
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.blue900 : AppColors.grey50;
    final textColor = isDark ? AppColors.grey50 : AppColors.blue900;
    final subColor = isDark ? AppColors.grey400 : AppColors.grey600;
    final barBg = isDark ? AppColors.blue700 : AppColors.grey200;
    final barFill = isDark ? AppColors.lightBlue500 : AppColors.lightBlue700;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: context.w(32)),
      child: Container(
        padding: EdgeInsets.all(context.w(28)),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(context.r(20)),
        ),
        child: AnimatedBuilder(
          animation: _progressController,
          builder: (context, _) {
            final percent =
                (_progressController.value * 100).round().clamp(0, 100);

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: context.w(56),
                  height: context.w(56),
                  decoration: BoxDecoration(
                    color: barFill.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    percent == 100
                        ? Icons.check_circle_rounded
                        : Icons.auto_awesome_rounded,
                    color: percent == 100 ? AppColors.green500 : barFill,
                    size: context.icon(28),
                  ),
                ),
                SizedBox(height: context.h(20)),
                Text(
                  percent == 100
                      ? 'Analysis Complete!'
                      : 'Analyzing Your Resume...',
                  style: context.appTextTheme.title1Bold
                      .copyWith(color: textColor),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: context.h(8)),
                Text(
                  percent == 100
                      ? 'Opening your report now...'
                      : 'Our AI is reviewing your CV against ATS standards.\nThis usually takes under 2 minutes.',
                  style: context.appTextTheme.bodyRegular
                      .copyWith(color: subColor),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: context.h(28)),
                ClipRRect(
                  borderRadius: BorderRadius.circular(context.r(8)),
                  child: LinearProgressIndicator(
                    value: _progressController.value,
                    minHeight: context.h(10),
                    backgroundColor: barBg,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      percent == 100 ? AppColors.green500 : barFill,
                    ),
                  ),
                ),
                SizedBox(height: context.h(10)),
                Text(
                  '$percent%',
                  style: context.appTextTheme.title2Bold.copyWith(
                    color: percent == 100 ? AppColors.green500 : barFill,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Upload Dialog ─────────────────────────────────────────────────────────────

class OptimizationUploadDialog extends ConsumerStatefulWidget {
  const OptimizationUploadDialog({super.key});

  @override
  ConsumerState<OptimizationUploadDialog> createState() =>
      _OptimizationUploadDialogState();
}

class _OptimizationUploadDialogState
    extends ConsumerState<OptimizationUploadDialog> {
  File? _selectedFile;
  String? _selectedFileName;
  final _jdController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _jdController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx'],
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.size > 10 * 1024 * 1024) {
        if (mounted) {
          _showSnack('File exceeds 10 MB. Please choose a smaller file.');
        }
        return;
      }
      setState(() {
        _selectedFile = File(file.path!);
        _selectedFileName = file.name;
      });
    }
  }

  Future<void> _startOptimization() async {
    if (_selectedFile == null) {
      _showSnack('Please upload your CV first.');
      return;
    }

    setState(() => _isSubmitting = true);

    // Close upload sheet
    if (mounted) Navigator.of(context).pop();
    if (!mounted) return;

    bool timedOut = false;

    // Show progress overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AnalysisLoadingOverlay(
        onTimeout: () {
          timedOut = true;
          if (Navigator.of(context).canPop()) Navigator.of(context).pop();
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const AnalysisPendingDialog(),
          );
        },
        // ← NEW: لما يحصل error، الـ overlay بيتقفل وبيبعت الـ message هنا
        onError: (errorMessage) {
          if (!mounted) return;
          _showErrorSnack(errorMessage);
          ref.read(resumeOptimizationProvider.notifier).resetAnalysisStatus();
        },
      ),
    );

    // Run analysis
    await ref.read(resumeOptimizationProvider.notifier).analyzeCV(
          cvFile: _selectedFile!,
          jobDescription: _jdController.text.trim().isEmpty
              ? null
              : _jdController.text.trim(),
        );

    if (!mounted || timedOut) return;

    final state = ref.read(resumeOptimizationProvider);

    if (state.analysisStatus == AnalysisStatus.success &&
        state.latestReportId != null) {
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      context.push('/report-details/${state.latestReportId}');
      ref.read(resumeOptimizationProvider.notifier).resetAnalysisStatus();
    }
    // error case مش محتاجة تتعامل معاه هنا —
    // الـ onError callback في الـ overlay بيتكلم عنه
  }

  /// Snackbar للـ errors العادية (file size, etc.)
  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.orange500,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Snackbar للـ server/network errors — أحمر مع duration أطول
  void _showErrorSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.grey50, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  color: AppColors.grey50,
                  fontFamily: 'Inter',
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.red600,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = context.appTextTheme;

    final bgColor = isDark ? AppColors.blue700 : AppColors.grey50;
    final textPrimary = isDark ? AppColors.grey50 : AppColors.blue900;
    final textMuted = isDark ? AppColors.grey400 : AppColors.grey700;
    final borderColor =
        isDark ? AppColors.blue400.withOpacity(0.5) : AppColors.grey300;
    final uploadBg =
        isDark ? AppColors.blue600.withOpacity(0.5) : AppColors.grey100;
    final btnColor = isDark ? AppColors.lightBlue500 : AppColors.lightBlue700;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: context.w(12)),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + context.h(24),
        left: context.w(20),
        right: context.w(20),
        top: context.h(8),
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(context.r(20)),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar + Close
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 32),
                Center(
                  child: Container(
                    width: context.w(40),
                    height: context.h(4),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.blue300 : AppColors.grey400,
                      borderRadius: BorderRadius.circular(2),
                    ),
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

            SizedBox(height: context.h(16)),

            context.text(
              'Resume Optimization Options',
              style: textTheme.title1Bold.copyWith(color: textPrimary),
            ),
            SizedBox(height: context.h(8)),
            context.text(
              'Upload your CV for ATS analysis, or add a Job Description for job matching.',
              style: textTheme.bodyRegular.copyWith(color: textMuted),
            ),

            SizedBox(height: context.h(20)),

            context.text(
              'Upload CV',
              style: textTheme.bodyBold.copyWith(color: textPrimary),
            ),
            SizedBox(height: context.h(8)),

            GestureDetector(
              onTap: _pickFile,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: context.h(28)),
                decoration: BoxDecoration(
                  color: uploadBg,
                  borderRadius: BorderRadius.circular(context.r(12)),
                  border: Border.all(
                    color: _selectedFile != null
                        ? AppColors.lightBlue500
                        : borderColor,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _selectedFile != null
                          ? Icons.check_circle_outline
                          : Icons.upload_file_outlined,
                      color: _selectedFile != null
                          ? AppColors.green500
                          : (isDark
                              ? AppColors.lightBlue400
                              : AppColors.lightBlue700),
                      size: context.icon(36),
                    ),
                    SizedBox(height: context.h(8)),
                    context.text(
                      _selectedFileName ?? 'click to upload',
                      style: textTheme.bodyMedium.copyWith(
                        color: _selectedFile != null
                            ? AppColors.green500
                            : textPrimary,
                      ),
                    ),
                    SizedBox(height: context.h(4)),
                    if (_selectedFile == null)
                      context.text(
                        'Supported formats: PDF, DOCX (max 10 MB)',
                        style:
                            textTheme.captionRegular.copyWith(color: textMuted),
                      ),
                  ],
                ),
              ),
            ),

            SizedBox(height: context.h(16)),

            TextField(
              controller: _jdController,
              maxLines: 4,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: context.sp(13),
                color: textPrimary,
              ),
              decoration: InputDecoration(
                labelText: 'Job Description (Optional)',
                hintText: 'Paste the full Job Description here',
                hintStyle: TextStyle(
                  color: textMuted,
                  fontSize: context.sp(12),
                  fontFamily: 'Inter',
                ),
                labelStyle: TextStyle(
                  color: textMuted,
                  fontSize: context.sp(12),
                  fontFamily: 'Inter',
                ),
                filled: true,
                fillColor: uploadBg,
                contentPadding: EdgeInsets.all(context.w(14)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(context.r(12)),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(context.r(12)),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(context.r(12)),
                  borderSide: const BorderSide(color: AppColors.lightBlue500),
                ),
              ),
            ),

            SizedBox(height: context.h(20)),

            SizedBox(
              width: double.infinity,
              height: context.h(52),
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _startOptimization,
                style: ElevatedButton.styleFrom(
                  backgroundColor: btnColor,
                  foregroundColor:
                      isDark ? AppColors.blue900 : AppColors.grey50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(context.r(50)),
                  ),
                  elevation: 0,
                  disabledBackgroundColor: btnColor.withOpacity(0.5),
                ),
                child: _isSubmitting
                    ? SizedBox(
                        width: context.w(22),
                        height: context.w(22),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: isDark ? AppColors.blue900 : AppColors.grey50,
                        ),
                      )
                    : context.text(
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

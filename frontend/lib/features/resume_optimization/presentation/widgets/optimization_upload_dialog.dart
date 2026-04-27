// lib/features/resume_optimization/presentation/widgets/optimization_upload_dialog.dart
// التغيير الرئيسي: الزرار يتفعل لو فيه CV موجود من قبل

import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../../../../core/theme/app_text_theme.dart';
import '../../../../core/utils/file_utils.dart';
import '../providers/resume_optimization_provider.dart';
import 'analysis_pending_dialog.dart';

// ─── Progress Loading Overlay ─────────────────────────────────────────────────
// (نفس الكود القديم — لا تغيير)

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

  void _completeAndClose() {
    if (_completing) return;
    _completing = true;
    _timeoutTimer?.cancel();
    _progressController
        .animateTo(1.0, duration: const Duration(milliseconds: 600))
        .then((_) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

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
  /// ← جديد: لو اليوزر عنده CV مرفوع بالفعل، نعرضه ونفعّل الزرار
  final String? existingCvUrl;
  final String? existingCvFileName;

  const OptimizationUploadDialog({
    super.key,
    this.existingCvUrl,
    this.existingCvFileName,
  });

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

  /// ← جديد: هل بنستخدم الـ CV الموجود من الـ profile؟
  bool _useExistingCv = false;

  @override
  void initState() {
    super.initState();
    // لو فيه CV موجود، نفعّله تلقائياً
    if (widget.existingCvUrl != null && widget.existingCvUrl!.isNotEmpty) {
      _useExistingCv = true;
      _selectedFileName = widget.existingCvFileName ??
          FileUtils.getFileNameFromUrl(widget.existingCvUrl);
    }
  }

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
        if (mounted)
          _showSnack('File exceeds 10 MB. Please choose a smaller file.');
        return;
      }
      setState(() {
        _selectedFile = File(file.path!);
        _selectedFileName = file.name;
        _useExistingCv = false; // اختار ملف جديد → شيل الـ existing flag
      });
    }
  }

  Future<void> _startOptimization() async {
    // ← الحل: الزرار يشتغل لو فيه ملف جديد أو CV موجود
    if (_selectedFile == null && !_useExistingCv) {
      _showSnack('Please upload your CV first.');
      return;
    }

    setState(() => _isSubmitting = true);

    if (mounted) Navigator.of(context).pop();
    if (!mounted) return;

    bool timedOut = false;

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
        onError: (errorMessage) {
          if (!mounted) return;
          _showErrorSnack(errorMessage);
          ref.read(resumeOptimizationProvider.notifier).resetAnalysisStatus();
        },
      ),
    );

    if (_selectedFile != null) {
      // ← رفع ملف جديد (الطريقة القديمة)
      await ref.read(resumeOptimizationProvider.notifier).analyzeCV(
            cvFile: _selectedFile!,
            jobDescription: _jdController.text.trim().isEmpty
                ? null
                : _jdController.text.trim(),
          );
    } else if (_useExistingCv && widget.existingCvUrl != null) {
      // ← استخدام الـ CV الموجود: نعمل download مؤقت ثم analyze
      await _analyzeCvFromUrl(
        cvUrl: widget.existingCvUrl!,
        jobDescription: _jdController.text.trim().isEmpty
            ? null
            : _jdController.text.trim(),
      );
    }

    if (!mounted || timedOut) return;

    final state = ref.read(resumeOptimizationProvider);
    if (state.analysisStatus == AnalysisStatus.success &&
        state.latestReportId != null) {
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      context.push('/report-details/${state.latestReportId}');
      ref.read(resumeOptimizationProvider.notifier).resetAnalysisStatus();
    }
  }

  /// Download CV from URL to temp file then analyze
  Future<void> _analyzeCvFromUrl({
    required String cvUrl,
    String? jobDescription,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = _selectedFileName ?? 'cv_temp.pdf';
      final tempFile = File('${tempDir.path}/$fileName');

      // نشيل الـ ?original= param قبل الـ download
      final downloadUrl = cvUrl.split('?original=').first;

      final dio = Dio();
      await dio.download(downloadUrl, tempFile.path);

      await ref.read(resumeOptimizationProvider.notifier).analyzeCV(
            cvFile: tempFile,
            jobDescription: jobDescription,
          );
    } catch (e) {
      ref.read(resumeOptimizationProvider.notifier);
      // الـ error هيتعامل معاه في الـ overlay listener
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.orange500,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.grey50, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(msg,
                  style: const TextStyle(
                      color: AppColors.grey50, fontFamily: 'Inter')),
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

    // ← هل فيه CV (جديد أو موجود)؟
    final hasCV = _selectedFile != null || _useExistingCv;

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
                  child: Icon(Icons.close,
                      color: AppColors.red500, size: context.icon(22)),
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

            // ── CV Upload Area ──────────────────────────────────────────────
            GestureDetector(
              onTap: _pickFile,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: context.h(28)),
                decoration: BoxDecoration(
                  color: uploadBg,
                  borderRadius: BorderRadius.circular(context.r(12)),
                  border: Border.all(
                    color: hasCV ? AppColors.lightBlue500 : borderColor,
                    width: hasCV ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      hasCV
                          ? Icons.check_circle_outline
                          : Icons.upload_file_outlined,
                      color: hasCV
                          ? AppColors.lightBlue500
                          : (isDark
                              ? AppColors.lightBlue400
                              : AppColors.lightBlue700),
                      size: context.icon(36),
                    ),
                    SizedBox(height: context.h(8)),
                    context.text(
                      hasCV ? 'click to Change' : 'click to upload',
                      style: textTheme.bodyMedium.copyWith(
                        color: hasCV ? AppColors.lightBlue500 : textPrimary,
                      ),
                    ),
                    SizedBox(height: context.h(4)),
                    if (_selectedFileName != null)
                      Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: context.w(16)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delete_outline,
                                color: AppColors.red500,
                                size: context.icon(14)),
                            SizedBox(width: context.w(4)),
                            Flexible(
                              child: Text(
                                _selectedFileName!,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: context.sp(12),
                                  color: AppColors.red500,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
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

            // ── JD Field ────────────────────────────────────────────────────
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
                    fontFamily: 'Inter'),
                labelStyle: TextStyle(
                    color: textMuted,
                    fontSize: context.sp(12),
                    fontFamily: 'Inter'),
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

            // ── Start Button ─────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: context.h(52),
              child: ElevatedButton(
                // ← الحل: يتفعل لو hasCV (ملف جديد أو موجود)
                onPressed:
                    (_isSubmitting || !hasCV) ? null : _startOptimization,
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

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../../../../core/theme/app_text_theme.dart';
import '../../../../core/utils/file_utils.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../resume_optimization/presentation/providers/resume_optimization_provider.dart';
import '../../../resume_optimization/presentation/widgets/analysis_pending_dialog.dart';
import '../../domain/entities/job_entity.dart';
import '../providers/job_matching_provider.dart';
import '../widgets/job_matching_dialogs.dart';

class JobDetailsScreen extends ConsumerStatefulWidget {
  final JobEntity job;

  const JobDetailsScreen({super.key, required this.job});

  @override
  ConsumerState<JobDetailsScreen> createState() => _JobDetailsScreenState();
}

class _JobDetailsScreenState extends ConsumerState<JobDetailsScreen> {
  bool _isSubmitting = false;

  Future<void> _launchJobUrl() async {
    if (widget.job.jobUrl == null) return;
    final uri = Uri.tryParse(widget.job.jobUrl!);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showAiCareerDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => AiCareerPreparationDialog(
        onOptimizeResume: _handleOptimizeResume,
        onMockInterview: _handleMockInterview,
      ),
    );
  }

  void _handleOptimizeResume() {
    final user = ref.read(authProvider).user;
    final cvUrl = user?.cvUrl;

    final cvFileName =
        cvUrl != null ? FileUtils.getFileNameFromUrl(cvUrl) : null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _JobMatchingResumeUploadDialog(
        jobDescription: widget.job.jobDescription,
        currentCvFileName: cvFileName,
        currentCvUrl: cvUrl,
        onStartOptimization: _startOptimizationWithFile,
      ),
    );
  }

  Future<void> _startOptimizationWithFile(File cvFile) async {
    if (!mounted) return;
    setState(() => _isSubmitting = true);

    bool timedOut = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AnalysisOverlay(
        onTimeout: () {
          timedOut = true;
          if (Navigator.of(context).canPop()) Navigator.of(context).pop();
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const AnalysisPendingDialog(),
          );
        },
        onError: (msg) {
          if (!mounted) return;
          _showErrorSnack(msg);
          ref.read(resumeOptimizationProvider.notifier).resetAnalysisStatus();
        },
      ),
    );

    await ref.read(resumeOptimizationProvider.notifier).analyzeCV(
          cvFile: cvFile,
          jobDescription: widget.job.jobDescription,
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

    setState(() => _isSubmitting = false);
  }

  void _handleMockInterview() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => AiInterviewConfirmDialog(
        onStartInterview: () => context.push('/mock-interview'),
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
    final job = widget.job;

    final bgColor = isDark ? AppColors.blue900 : AppColors.grey100;
    final cardBg = isDark ? AppColors.blue700 : AppColors.grey50;
    final cardBorder = isDark ? AppColors.blue400 : AppColors.grey200;
    final textPrimary = isDark ? AppColors.grey50 : AppColors.blue900;
    final textMuted = isDark ? AppColors.grey400 : AppColors.grey700;
    final accentColor =
        isDark ? AppColors.lightBlue500 : AppColors.lightBlue700;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── App bar ──────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: context.w(16), vertical: context.h(12)),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Icon(Icons.arrow_back_ios_new,
                        color: textPrimary, size: context.icon(20)),
                  ),
                  const Spacer(),
                  Image.asset(
                    'assets/images/branding/growza_logo.png',
                    width: context.w(40),
                    height: context.h(40),
                    fit: BoxFit.contain,
                  ),
                  const Spacer(),
                  SizedBox(width: context.icon(20)),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: context.w(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Job header card ──────────────────────────────────
                    Container(
                      padding: EdgeInsets.all(context.w(16)),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(context.r(12)),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(job.title,
                                    style: textTheme.title1Bold
                                        .copyWith(color: textPrimary)),
                              ),
                              GestureDetector(
                                onTap: () => ref
                                    .read(jobMatchingProvider.notifier)
                                    .toggleSave(job.id),
                                child: Icon(
                                  job.isSaved
                                      ? Icons.bookmark
                                      : Icons.bookmark_border,
                                  color: job.isSaved ? accentColor : textMuted,
                                  size: context.icon(22),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: context.h(4)),
                          Text(job.company,
                              style: textTheme.bodyRegular
                                  .copyWith(color: textMuted)),
                          SizedBox(height: context.h(10)),
                          _InfoRow(
                              icon: Icons.location_on_outlined,
                              text: job.location,
                              textMuted: textMuted),
                          SizedBox(height: context.h(4)),
                          _InfoRow(
                              icon: Icons.work_outline,
                              text: '${job.workLocation} • ${job.workType}',
                              textMuted: textMuted),
                          SizedBox(height: context.h(4)),
                          _InfoRow(
                              icon: Icons.calendar_today_outlined,
                              text:
                                  'Posted on ${job.postedAt.day}/${job.postedAt.month}/${job.postedAt.year}',
                              textMuted: textMuted),
                          SizedBox(height: context.h(14)),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: _launchJobUrl,
                                  child: Container(
                                    height: context.h(42),
                                    decoration: BoxDecoration(
                                      color: accentColor,
                                      borderRadius:
                                          BorderRadius.circular(context.r(50)),
                                    ),
                                    alignment: Alignment.center,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text('View Job',
                                            style: textTheme.bodyBold.copyWith(
                                                color: isDark
                                                    ? AppColors.blue900
                                                    : AppColors.grey50)),
                                        SizedBox(width: context.w(6)),
                                        Icon(Icons.open_in_new,
                                            color: isDark
                                                ? AppColors.blue900
                                                : AppColors.grey50,
                                            size: context.icon(16)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: context.w(8)),
                              GestureDetector(
                                onTap: () {
                                  ref
                                      .read(jobMatchingProvider.notifier)
                                      .toggleSave(job.id);
                                  context.pop();
                                },
                                child: Container(
                                  width: context.w(42),
                                  height: context.h(42),
                                  decoration: BoxDecoration(
                                    color: AppColors.red500,
                                    borderRadius:
                                        BorderRadius.circular(context.r(50)),
                                  ),
                                  child: Icon(Icons.delete_outline,
                                      color: AppColors.grey50,
                                      size: context.icon(20)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: context.h(16)),

                    if (job.requiredSkills.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(context.w(16)),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(context.r(12)),
                          border: Border.all(color: cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Required Skills',
                                style: textTheme.title2Bold
                                    .copyWith(color: textPrimary)),
                            SizedBox(height: context.h(10)),
                            Wrap(
                              spacing: context.w(8),
                              runSpacing: context.h(6),
                              children: job.requiredSkills
                                  .map((s) =>
                                      _SkillChip(skill: s, isDark: isDark))
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: context.h(16)),
                    ],

                    if (job.jobDescription != null &&
                        job.jobDescription!.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(context.w(16)),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(context.r(12)),
                          border: Border.all(color: cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Job Description',
                                style: textTheme.title2Bold
                                    .copyWith(color: textPrimary)),
                            SizedBox(height: context.h(10)),
                            Text(job.jobDescription!,
                                style: textTheme.bodyRegular
                                    .copyWith(color: textMuted)),
                          ],
                        ),
                      ),
                      SizedBox(height: context.h(80)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          height: context.h(64),
          padding: EdgeInsets.symmetric(
              horizontal: context.w(16), vertical: context.h(10)),
          decoration: BoxDecoration(
            color: isDark ? AppColors.blue900 : AppColors.grey50,
            border: Border(
              top: BorderSide(
                color: isDark
                    ? AppColors.blue400.withOpacity(0.5)
                    : AppColors.grey200,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _showAiCareerDialog,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.blue700 : AppColors.blue900,
                      borderRadius: BorderRadius.circular(context.r(50)),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('AI Career Preparation',
                            style: textTheme.bodyBold
                                .copyWith(color: AppColors.grey50)),
                        SizedBox(width: context.w(8)),
                        const Text('🚀', style: TextStyle(fontSize: 16)),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: context.w(8)),
              GestureDetector(
                onTap: _launchJobUrl,
                child: Container(
                  width: context.w(44),
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.blue700 : AppColors.blue900,
                    borderRadius: BorderRadius.circular(context.r(50)),
                  ),
                  child: Icon(Icons.open_in_new,
                      color: AppColors.grey50, size: context.icon(20)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color textMuted;

  const _InfoRow({
    required this.icon,
    required this.text,
    required this.textMuted,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: context.icon(14), color: textMuted),
        SizedBox(width: context.w(4)),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
                fontFamily: 'Inter',
                fontSize: context.sp(13),
                color: textMuted),
          ),
        ),
      ],
    );
  }
}

class _SkillChip extends StatelessWidget {
  final String skill;
  final bool isDark;

  const _SkillChip({required this.skill, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: isDark ? AppColors.grey400 : AppColors.grey700,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: context.w(6)),
        Text(
          skill,
          style: TextStyle(
              fontFamily: 'Inter',
              fontSize: context.sp(13),
              color: isDark ? AppColors.grey300 : AppColors.grey800),
        ),
      ],
    );
  }
}

// ─── Resume Upload Dialog ─────────────────────────────────────────────────────

class _JobMatchingResumeUploadDialog extends ConsumerStatefulWidget {
  final String? jobDescription;
  final String? currentCvFileName;
  final String? currentCvUrl;
  final Future<void> Function(File cvFile) onStartOptimization;

  const _JobMatchingResumeUploadDialog({
    this.jobDescription,
    this.currentCvFileName,
    this.currentCvUrl,
    required this.onStartOptimization,
  });

  @override
  ConsumerState<_JobMatchingResumeUploadDialog> createState() =>
      _JobMatchingResumeUploadDialogState();
}

class _JobMatchingResumeUploadDialogState
    extends ConsumerState<_JobMatchingResumeUploadDialog> {
  File? _selectedFile;
  String? _selectedFileName;

  // ── FIX 2: track whether we're using existing CV ──────────────────────────
  bool _useExistingCv = false;

  @override
  void initState() {
    super.initState();
    // لو فيه CV موجود → نفعّله تلقائياً
    if (widget.currentCvUrl != null && widget.currentCvUrl!.isNotEmpty) {
      _useExistingCv = true;
      _selectedFileName = widget.currentCvFileName ?? 'CV.pdf';
    }
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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('File exceeds 10 MB.'),
            backgroundColor: AppColors.orange500,
          ));
        }
        return;
      }
      setState(() {
        _selectedFile = File(file.path!);
        _selectedFileName = file.name;
        _useExistingCv = false; // اختار ملف جديد
      });
    }
  }

  /// لو بنستخدم الـ existing CV URL، نعمل download مؤقت عشان نحوله لـ File
  Future<File?> _downloadExistingCv() async {
    try {
      final cvUrl = widget.currentCvUrl!;
      final tempDir = await getTemporaryDirectory();
      final fileName = _selectedFileName ?? 'cv_temp.pdf';
      final tempFile = File('${tempDir.path}/$fileName');

      // شيل الـ ?original= param
      final downloadUrl = cvUrl.contains('?original=')
          ? cvUrl.split('?original=').first
          : cvUrl;

      final dio = Dio();
      await dio.download(downloadUrl, tempFile.path);
      return tempFile;
    } catch (e) {
      return null;
    }
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

    final hasCV = _selectedFile != null || _useExistingCv;

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text('Resume Optimization',
                      style: textTheme.title1Bold.copyWith(color: textPrimary)),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Icon(Icons.close,
                      color: AppColors.red500, size: context.icon(22)),
                ),
              ],
            ),
            SizedBox(height: context.h(8)),
            Text(
              "Upload your CV and we'll match it automatically with this job description.",
              style: textTheme.bodyRegular.copyWith(color: textMuted),
            ),
            SizedBox(height: context.h(20)),
            Text('Upload CV',
                style: textTheme.bodyBold.copyWith(color: textPrimary)),
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
                    color: hasCV ? AppColors.lightBlue500 : borderColor,
                    width: hasCV ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      hasCV
                          ? Icons.description_outlined
                          : Icons.upload_file_outlined,
                      color: hasCV
                          ? AppColors.lightBlue500
                          : (isDark
                              ? AppColors.lightBlue400
                              : AppColors.lightBlue700),
                      size: context.icon(36),
                    ),
                    SizedBox(height: context.h(8)),
                    Text(
                      hasCV ? 'click to Change' : 'click to upload',
                      style: textTheme.bodyMedium.copyWith(color: textPrimary),
                    ),
                    if (hasCV && _selectedFileName != null) ...[
                      SizedBox(height: context.h(6)),
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
                                    color: AppColors.red500),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (!hasCV) ...[
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
            SizedBox(
              width: double.infinity,
              height: context.h(52),
              child: ElevatedButton(
                // ── FIX 2: يتفعل لو hasCV ──────────────────────────────────
                onPressed: !hasCV
                    ? null
                    : () async {
                        Navigator.of(context).pop();

                        if (_selectedFile != null) {
                          // ملف جديد
                          widget.onStartOptimization(_selectedFile!);
                        } else if (_useExistingCv) {
                          // existing CV → download first
                          final file = await _downloadExistingCv();
                          if (file != null) {
                            widget.onStartOptimization(file);
                          }
                        }
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

// ─── Analysis Overlay ─────────────────────────────────────────────────────────

class _AnalysisOverlay extends ConsumerStatefulWidget {
  final VoidCallback onTimeout;
  final void Function(String errorMessage) onError;

  const _AnalysisOverlay({required this.onTimeout, required this.onError});

  @override
  ConsumerState<_AnalysisOverlay> createState() => _AnalysisOverlayState();
}

class _AnalysisOverlayState extends ConsumerState<_AnalysisOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  bool _completing = false;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 120),
      lowerBound: 0.0,
      upperBound: 0.95,
    )..forward();

    Future.delayed(const Duration(seconds: 120), () {
      if (mounted && !_completing) widget.onTimeout();
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  void _complete() {
    if (_completing) return;
    _completing = true;
    _progressController
        .animateTo(1.0, duration: const Duration(milliseconds: 600))
        .then((_) {
      if (mounted && Navigator.of(context).canPop())
        Navigator.of(context).pop();
    });
  }

  void _closeWithError(String msg) {
    if (_completing) return;
    _completing = true;
    _progressController.stop();
    if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onError(msg));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ResumeOptimizationState>(resumeOptimizationProvider,
        (prev, next) {
      if (next.analysisStatus == AnalysisStatus.success) _complete();
      if (next.analysisStatus == AnalysisStatus.error) {
        _closeWithError(
            next.errorMessage ?? 'Something went wrong. Please try again.');
      }
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.blue900 : AppColors.grey50;
    final textColor = isDark ? AppColors.grey50 : AppColors.blue900;
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
                Icon(Icons.auto_awesome_rounded,
                    color: barFill, size: context.icon(36)),
                SizedBox(height: context.h(16)),
                Text('Analyzing Your Resume...',
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: context.sp(16),
                        fontWeight: FontWeight.w700,
                        color: textColor)),
                SizedBox(height: context.h(20)),
                ClipRRect(
                  borderRadius: BorderRadius.circular(context.r(8)),
                  child: LinearProgressIndicator(
                    value: _progressController.value,
                    minHeight: context.h(10),
                    backgroundColor:
                        isDark ? AppColors.blue700 : AppColors.grey200,
                    valueColor: AlwaysStoppedAnimation<Color>(barFill),
                  ),
                ),
                SizedBox(height: context.h(8)),
                Text('$percent%',
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: context.sp(14),
                        fontWeight: FontWeight.w700,
                        color: barFill)),
              ],
            );
          },
        ),
      ),
    );
  }
}

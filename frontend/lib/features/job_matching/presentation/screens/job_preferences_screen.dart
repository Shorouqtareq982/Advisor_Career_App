// lib/features/job_matching/presentation/screens/job_preferences_screen.dart
//
// نفس البيانات بتاعة career_preferences_screen بالظبط:
// preferredLocation, interestedTracks, jobTitle, workType,
// workLocation, jobPlatforms, jobAlertsFrequency, cvUrl
//
// الفرق الوحيد في التصميم:
// - من job matching: عنوان "Job Preferences" (teal) + subtitle + validation + dialog بعد save
// - من settings (filter icon): عنوان "Job Preferences" (عادي) + snackbar بعد save

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../../../../core/theme/app_text_theme.dart';
import '../../../../core/utils/file_utils.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/job_matching_dialogs.dart';

class JobPreferencesScreen extends ConsumerStatefulWidget {
  /// true  → من job matching flow (validation + "Preferences saved" dialog)
  /// false → من settings filter icon (save عادي + snackbar)
  final bool fromJobMatching;

  const JobPreferencesScreen({
    super.key,
    this.fromJobMatching = false,
  });

  @override
  ConsumerState<JobPreferencesScreen> createState() =>
      _JobPreferencesScreenState();
}

class _JobPreferencesScreenState extends ConsumerState<JobPreferencesScreen> {
  // ── Controllers — نفس career_preferences_screen ────────────────────────────
  final _preferredLocationController = TextEditingController();
  final _interestedTracksController = TextEditingController();
  final _jobTitleController = TextEditingController();

  List<String> _selectedWorkTypes = [];
  List<String> _selectedWorkLocations = [];
  List<String> _selectedJobPlatforms = [];
  String? _selectedAlertFrequency;

  String? _cvFileName;
  File? _cvFile;
  bool _isUploading = false;
  bool _isLoading = false;

  final _workTypeOptions = ['Full-time', 'Part-time'];
  final _workLocationOptions = ['Onsite', 'Remote', 'Hybrid'];
  final _jobPlatformOptions = ['LinkedIn', 'Adzuna', 'Jooble'];
  final _alertFrequencyLabels = ['24 hours', '3 days', '1 week'];

  @override
  void initState() {
    super.initState();
    _loadFromUser();
  }

  @override
  void dispose() {
    _preferredLocationController.dispose();
    _interestedTracksController.dispose();
    _jobTitleController.dispose();
    super.dispose();
  }

  // ── Load same data as career_preferences_screen ────────────────────────────
  void _loadFromUser() {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    _preferredLocationController.text = user.preferredLocation ?? '';
    _interestedTracksController.text = user.interestedTracks ?? '';
    _jobTitleController.text = user.jobTitle ?? '';

    _selectedWorkTypes = List<String>.from(user.workType ?? []);
    _selectedWorkLocations = List<String>.from(user.workLocation ?? []);
    _selectedJobPlatforms = List<String>.from(user.jobPlatforms ?? []);

    final freq = user.jobAlertsFrequency;
    _selectedAlertFrequency = (freq == null || freq.isEmpty) ? null : freq;

    if (user.cvUrl != null && user.cvUrl!.isNotEmpty) {
      _cvFileName = FileUtils.getFileNameFromUrl(user.cvUrl);
    } else {
      _cvFileName = null;
    }

    if (mounted) setState(() {});
  }

  // ── Validation (only when fromJobMatching) ─────────────────────────────────
  String? _validate() {
    final jobTitle = _jobTitleController.text.trim();
    if (jobTitle.isEmpty) return 'Please enter your Job Title';
    if (jobTitle.length < 2) return 'Job Title is too short';

    if (_selectedWorkTypes.isEmpty)
      return 'Please select at least one Work Type';
    if (_selectedWorkLocations.isEmpty)
      return 'Please select at least one Work Location';
    if (_selectedJobPlatforms.isEmpty)
      return 'Please select at least one Job Platform';

    final hasCv = ref.read(authProvider).user?.cvUrl?.isNotEmpty == true ||
        _cvFile != null;
    if (!hasCv) return 'Please upload your CV';

    return null;
  }

  void _showSnack(String msg, {bool isError = false, bool isWarning = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline
                  : isWarning
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline,
              color: AppColors.grey50,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                    fontFamily: 'Inter', color: AppColors.grey50),
              ),
            ),
          ],
        ),
        backgroundColor: isError
            ? AppColors.red600
            : isWarning
                ? AppColors.orange500
                : AppColors.green700,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: isWarning ? 3 : 2),
      ),
    );
  }

  // ── CV ──────────────────────────────────────────────────────────────────────
  Future<void> _pickCV() async {
    try {
      setState(() => _isUploading = true);
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        if (file.lengthSync() > 10 * 1024 * 1024) {
          _showSnack('File exceeds 10 MB.', isWarning: true);
          return;
        }
        setState(() {
          _cvFile = file;
          _cvFileName = result.files.single.name;
        });

        final cvUrl = await ref.read(authProvider.notifier).uploadCV(file);
        if (cvUrl != null && mounted) {
          await ref.read(authProvider.notifier).updateUserProfile(cvUrl: cvUrl);
          await ref.read(authProvider.notifier).refreshUser();
        }
      }
    } catch (e) {
      if (mounted) _showSnack('Failed to upload CV.', isError: true);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ── Save — نفس بيانات career_preferences_screen بالظبط ────────────────────
  Future<void> _handleSave() async {
    if (widget.fromJobMatching) {
      final error = _validate();
      if (error != null) {
        _showSnack(error, isWarning: true);
        return;
      }
    }

    setState(() => _isLoading = true);

    final success = await ref.read(authProvider.notifier).updateUserProfile(
          preferredLocation: _preferredLocationController.text.trim().isEmpty
              ? null
              : _preferredLocationController.text.trim(),
          interestedTracks: _interestedTracksController.text.trim().isEmpty
              ? null
              : _interestedTracksController.text.trim(),
          jobTitle: _jobTitleController.text.trim().isEmpty
              ? null
              : _jobTitleController.text.trim(),
          workType: _selectedWorkTypes.isEmpty ? null : _selectedWorkTypes,
          workLocation:
              _selectedWorkLocations.isEmpty ? null : _selectedWorkLocations,
          jobPlatforms:
              _selectedJobPlatforms.isEmpty ? null : _selectedJobPlatforms,
          jobAlertsFrequency: _selectedAlertFrequency,
        );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!success) {
      _showSnack('Failed to save. Please try again.', isError: true);
      return;
    }

    await ref.read(authProvider.notifier).refreshUser();
    if (!mounted) return;

    if (widget.fromJobMatching) {
      // Show "Preferences saved!" dialog then go to recommended jobs
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const PreferencesSavedDialog(),
      );
      if (mounted) context.go('/recommended-jobs');
    } else {
      // من settings — show dialog أيضاً ثم pop
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const PreferencesSavedDialog(),
      );
      if (mounted) context.pop();
    }
  }

  void _toggle(List<String> list, String item) {
    setState(() {
      list.contains(item) ? list.remove(item) : list.add(item);
    });
  }

  String _freqValue(String label) {
    if (label == '24 hours') return 'daily';
    if (label == '3 days') return '3days';
    return 'weekly';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = context.appTextTheme;
    final user = ref.watch(authProvider).user;
    final hasCV = (user?.cvUrl?.isNotEmpty ?? false) || _cvFile != null;

    final bg = isDark ? AppColors.blue900 : AppColors.grey50;
    final primary = isDark ? AppColors.grey50 : AppColors.blue900;
    final muted = isDark ? AppColors.grey400 : AppColors.grey700;
    final accent = isDark ? AppColors.lightBlue500 : AppColors.lightBlue700;
    final fieldBg = isDark ? AppColors.blue700 : AppColors.grey50;
    final border = isDark ? AppColors.blue400 : AppColors.grey300;

    return Scaffold(
      backgroundColor: bg,
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
                        color: primary, size: context.icon(20)),
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

            // ── Title ────────────────────────────────────────────────────
            Text(
              'Job Preferences',
              style: textTheme.title1Bold.copyWith(
                // teal لما يجي من job matching, عادي لما يجي من settings
                color: widget.fromJobMatching ? accent : primary,
              ),
            ),

            if (widget.fromJobMatching) ...[
              SizedBox(height: context.h(6)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: context.w(24)),
                child: Text(
                  'Pick your preferences, and the AI will show jobs that fit you best',
                  style: textTheme.bodyRegular.copyWith(color: muted),
                  textAlign: TextAlign.center,
                ),
              ),
            ],

            SizedBox(height: context.h(12)),

            // ── Scrollable content ───────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.only(
                  left: context.w(16),
                  right: context.w(16),
                  bottom: MediaQuery.of(context).viewInsets.bottom +
                      MediaQuery.of(context).padding.bottom +
                      context.h(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Job Title ────────────────────────────────────────
                    _field(
                      controller: _jobTitleController,
                      label: 'Job Title',
                      hint: 'e.g.  Data Analyst, ML Engineer, UI/UX Designer',
                      accent: accent,
                      primary: primary,
                      muted: muted,
                      fieldBg: fieldBg,
                      border: border,
                    ),

                    SizedBox(height: context.h(16)),

                    // ── Work Type ────────────────────────────────────────
                    _label('Work Type', primary, textTheme),
                    SizedBox(height: context.h(10)),
                    _chips(
                      options: _workTypeOptions,
                      selected: _selectedWorkTypes,
                      accent: accent,
                      primary: primary,
                      fieldBg: fieldBg,
                      border: border,
                      isDark: isDark,
                      onTap: (o) => _toggle(_selectedWorkTypes, o),
                    ),

                    SizedBox(height: context.h(20)),

                    // ── Work Location ────────────────────────────────────
                    _label('Work Location', primary, textTheme),
                    SizedBox(height: context.h(10)),
                    _chips(
                      options: _workLocationOptions,
                      selected: _selectedWorkLocations,
                      accent: accent,
                      primary: primary,
                      fieldBg: fieldBg,
                      border: border,
                      isDark: isDark,
                      onTap: (o) => _toggle(_selectedWorkLocations, o),
                    ),

                    SizedBox(height: context.h(20)),

                    // ── Job Platforms ────────────────────────────────────
                    _label('Job Platforms', primary, textTheme),
                    SizedBox(height: context.h(10)),
                    _chips(
                      options: _jobPlatformOptions,
                      selected: _selectedJobPlatforms,
                      accent: accent,
                      primary: primary,
                      fieldBg: fieldBg,
                      border: border,
                      isDark: isDark,
                      onTap: (o) => _toggle(_selectedJobPlatforms, o),
                    ),

                    SizedBox(height: context.h(20)),

                    // ── Alert Frequency ──────────────────────────────────
                    _label('Get job alerts every', primary, textTheme),
                    SizedBox(height: context.h(10)),
                    Wrap(
                      spacing: context.w(8),
                      runSpacing: context.h(8),
                      children: _alertFrequencyLabels.map((lbl) {
                        final val = _freqValue(lbl);
                        final selected = _selectedAlertFrequency == val;
                        return _ChipItem(
                          label: lbl,
                          isSelected: selected,
                          isDark: isDark,
                          accent: accent,
                          fieldBg: fieldBg,
                          border: border,
                          primary: primary,
                          onTap: () => setState(() =>
                              _selectedAlertFrequency = selected ? null : val),
                          showIcon: false, // frequency chips — no +/✓ icon
                        );
                      }).toList(),
                    ),

                    SizedBox(height: context.h(20)),

                    // ── Upload CV ────────────────────────────────────────
                    _label('Upload CV', primary, textTheme),
                    SizedBox(height: context.h(10)),
                    _CvUploadArea(
                      fileName: _cvFileName,
                      hasCV: hasCV,
                      isDark: isDark,
                      isUploading: _isUploading,
                      accent: accent,
                      fieldBg: fieldBg,
                      border: border,
                      primary: primary,
                      muted: muted,
                      onTap: _pickCV,
                    ),

                    SizedBox(height: context.h(28)),

                    // ── Save button ──────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: context.h(52),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor:
                              isDark ? AppColors.blue900 : AppColors.grey50,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(context.r(50)),
                          ),
                          elevation: 0,
                          disabledBackgroundColor: accent.withOpacity(0.5),
                        ),
                        child: _isLoading
                            ? SizedBox(
                                width: context.w(22),
                                height: context.w(22),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: isDark
                                      ? AppColors.blue900
                                      : AppColors.grey50,
                                ),
                              )
                            : Text(
                                'save',
                                style: textTheme.title2Bold.copyWith(
                                  color: isDark
                                      ? AppColors.blue900
                                      : AppColors.grey50,
                                ),
                              ),
                      ),
                    ),

                    SizedBox(height: context.h(24)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Widget _label(String text, Color color, AppTextTheme t) => Text(
        text,
        style: t.bodyBold.copyWith(color: color),
      );

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required Color accent,
    required Color primary,
    required Color muted,
    required Color fieldBg,
    required Color border,
  }) {
    return TextField(
      controller: controller,
      style: TextStyle(
          fontFamily: 'Inter', fontSize: context.sp(14), color: primary),
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        hintText: hint,
        hintStyle: TextStyle(
            fontFamily: 'Inter', fontSize: context.sp(13), color: muted),
        labelStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: context.sp(12),
            fontWeight: FontWeight.w500,
            color: accent),
        filled: true,
        fillColor: fieldBg,
        contentPadding: EdgeInsets.symmetric(
            horizontal: context.w(16), vertical: context.h(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(context.r(10)),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(context.r(10)),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
      ),
    );
  }

  Widget _chips({
    required List<String> options,
    required List<String> selected,
    required bool isDark,
    required Color accent,
    required Color primary,
    required Color fieldBg,
    required Color border,
    required ValueChanged<String> onTap,
  }) {
    return Wrap(
      spacing: context.w(8),
      runSpacing: context.h(8),
      children: options
          .map((o) => _ChipItem(
                label: o,
                isSelected: selected.contains(o),
                isDark: isDark,
                accent: accent,
                fieldBg: fieldBg,
                border: border,
                primary: primary,
                onTap: () => onTap(o),
                showIcon: true,
              ))
          .toList(),
    );
  }
}

// ─── Chip Item ────────────────────────────────────────────────────────────────

class _ChipItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isDark;
  final Color accent;
  final Color fieldBg;
  final Color border;
  final Color primary;
  final VoidCallback onTap;
  final bool showIcon;

  const _ChipItem({
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.accent,
    required this.fieldBg,
    required this.border,
    required this.primary,
    required this.onTap,
    required this.showIcon,
  });

  @override
  Widget build(BuildContext context) {
    final textColor =
        isSelected ? (isDark ? AppColors.blue900 : AppColors.grey50) : primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: context.w(16), vertical: context.h(10)),
        decoration: BoxDecoration(
          color: isSelected ? accent : fieldBg,
          borderRadius: BorderRadius.circular(context.r(50)),
          border: Border.all(
            color: isSelected ? accent : border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: context.sp(13),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: textColor,
              ),
            ),
            if (showIcon) ...[
              SizedBox(width: context.w(6)),
              Icon(
                isSelected ? Icons.check : Icons.add,
                size: context.icon(14),
                color: textColor,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── CV Upload Area ───────────────────────────────────────────────────────────

class _CvUploadArea extends StatelessWidget {
  final String? fileName;
  final bool hasCV;
  final bool isDark;
  final bool isUploading;
  final Color accent;
  final Color fieldBg;
  final Color border;
  final Color primary;
  final Color muted;
  final VoidCallback onTap;

  const _CvUploadArea({
    required this.fileName,
    required this.hasCV,
    required this.isDark,
    required this.isUploading,
    required this.accent,
    required this.fieldBg,
    required this.border,
    required this.primary,
    required this.muted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isUploading ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: context.h(24)),
        decoration: BoxDecoration(
          color: fieldBg,
          borderRadius: BorderRadius.circular(context.r(12)),
          border: Border.all(
            color: hasCV ? accent : border,
            width: hasCV ? 1.5 : 1,
          ),
        ),
        child: isUploading
            ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                CircularProgressIndicator(color: accent),
                SizedBox(height: context.h(8)),
                Text('Uploading...',
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: context.sp(13),
                        color: muted)),
              ])
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(
                  hasCV
                      ? Icons.description_outlined
                      : Icons.upload_file_outlined,
                  color: hasCV ? accent : muted,
                  size: context.icon(36),
                ),
                SizedBox(height: context.h(8)),
                Text(
                  hasCV ? 'click to Change' : 'click to upload',
                  style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: context.sp(14),
                      fontWeight: FontWeight.w500,
                      color: primary),
                ),
                if (hasCV && fileName != null) ...[
                  SizedBox(height: context.h(6)),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.delete_outline,
                        color: AppColors.red500, size: context.icon(14)),
                    SizedBox(width: context.w(4)),
                    Text(fileName!,
                        style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: context.sp(12),
                            color: AppColors.red500)),
                  ]),
                ] else if (!hasCV) ...[
                  SizedBox(height: context.h(4)),
                  Text(
                    'Supported formats: PDF, DOCX (max 10 MB)',
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: context.sp(11),
                        color: muted),
                  ),
                ],
              ]),
      ),
    );
  }
}

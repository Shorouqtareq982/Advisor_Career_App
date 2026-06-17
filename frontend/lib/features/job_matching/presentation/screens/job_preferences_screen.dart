import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../../../../core/theme/app_text_theme.dart';
import '../../../../core/utils/file_utils.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/job_matching_provider.dart';
import '../widgets/job_search_dialogs.dart';
import '../widgets/job_matching_dialogs.dart';

class JobPreferencesScreen extends ConsumerStatefulWidget {
  /// true  → from job matching flow (validation required)
  /// false → from settings filter icon
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
  // ── Form state ─────────────────────────────────────────────────────────────
  String? _selectedJobTitle;
  String? _selectedCountry;
  String? _selectedWorkMode; // "Remote" / "Onsite" / "Hybrid"
  String? _selectedJobType; // "Full-time" / "Part-time"

  File? _cvFile;
  String? _cvFileName;
  bool _isUploading = false;
  bool _isLoading = false;

  // Options
  final _workModeOptions = ['Remote', 'Onsite'];
  final _jobTypeOptions = ['Full-time', 'Part-time'];

  @override
  void initState() {
    super.initState();
    _loadDropdowns();
    _prefillFromUser();
  }

  void _loadDropdowns() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final notifier = ref.read(jobMatchingProvider.notifier);
      await notifier.loadDropdowns();
      if (mounted) {
        _tryPrefillJobTitle();
        _tryPrefillCountry(); // ← أضف السطر ده
      }
    });
  }

  /// Prefill job title ONLY after dropdown list is loaded
  /// to avoid DropdownButton assertion error
  void _tryPrefillJobTitle() {
    final user = ref.read(authProvider).user;
    if (user?.jobTitle == null || user!.jobTitle!.isEmpty) return;
    if (_selectedJobTitle != null) return; // already set

    final titles = ref.read(jobMatchingProvider).jobTitles;
    final match = titles.firstWhere(
      (t) => t.toLowerCase() == user.jobTitle!.toLowerCase(),
      orElse: () => '',
    );
    if (match.isNotEmpty && mounted) {
      setState(() => _selectedJobTitle = match);
    }
  }

  void _tryPrefillCountry() {
    final user = ref.read(authProvider).user;
    if (user?.preferredLocation == null || user!.preferredLocation!.isEmpty)
      return;
    if (_selectedCountry != null) return; // already set

    final countries = ref.read(jobMatchingProvider).countries;
    // Try exact match on name
    final match = countries.firstWhere(
      (c) =>
          (c['name'] ?? '').toLowerCase() ==
          user.preferredLocation!.toLowerCase(),
      orElse: () => {},
    );
    if (match.isNotEmpty && mounted) {
      setState(() => _selectedCountry = match['name']);
    }
  }

  void _prefillFromUser() {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    // Job title prefill is deferred to _tryPrefillJobTitle()

    // Pre-fill work type
    if (user.workType.isNotEmpty) {
      final wt = user.workType.first;
      if (_jobTypeOptions.any((o) => o.toLowerCase() == wt.toLowerCase())) {
        _selectedJobType = _jobTypeOptions
            .firstWhere((o) => o.toLowerCase() == wt.toLowerCase());
      }
    }

    // Pre-fill work location
    if (user.workLocation.isNotEmpty) {
      final wl = user.workLocation.first;
      if (_workModeOptions.any((o) => o.toLowerCase() == wl.toLowerCase())) {
        _selectedWorkMode = _workModeOptions
            .firstWhere((o) => o.toLowerCase() == wl.toLowerCase());
      }
    }

    // Pre-fill country from preferredLocation (if saved as country name)
    // Actual matching happens in _tryPrefillCountry() after list loads

    // CV from user profile
    if (user.cvUrl != null && user.cvUrl!.isNotEmpty) {
      _cvFileName = FileUtils.getFileNameFromUrl(user.cvUrl);
    }
  }

  // ── Validation ─────────────────────────────────────────────────────────────
  String? _validate() {
    if (_selectedJobTitle == null || _selectedJobTitle!.isEmpty) {
      return 'Please select a Job Title';
    }
    if (_selectedCountry == null || _selectedCountry!.isEmpty) {
      return 'Please select a Country';
    }
    if (_selectedJobType == null) return 'Please select a Work Type';
    if (_selectedWorkMode == null) return 'Please select a Work Mode';

    final hasCv = _cvFile != null ||
        (ref.read(authProvider).user?.cvUrl?.isNotEmpty ?? false);
    if (!hasCv) return 'Please upload your CV';

    return null;
  }

  // ── CV picker ──────────────────────────────────────────────────────────────
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

        // Also upload to Supabase so it's saved on user profile
        final cvUrl = await ref.read(authProvider.notifier).uploadCV(file);
        if (cvUrl != null && mounted) {
          await ref.read(authProvider.notifier).updateUserProfile(cvUrl: cvUrl);
        }
      }
    } catch (e) {
      if (mounted) _showSnack('Failed to upload CV.', isError: true);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ── Submit ─────────────────────────────────────────────────────────────────
  Future<void> _handleFind() async {
    final error = _validate();
    if (error != null) {
      _showSnack(error, isWarning: true);
      return;
    }

    // Validate CV / resolve file first (before showing dialog)
    setState(() => _isLoading = true);

    // Save preferences to user profile
    await ref.read(authProvider.notifier).updateUserProfile(
          jobTitle: _selectedJobTitle,
          workType: _selectedJobType != null ? [_selectedJobType!] : null,
          workLocation: _selectedWorkMode != null ? [_selectedWorkMode!] : null,
          preferredLocation: _selectedCountry,
        );

    // Resolve CV file
    File? cvFile = _cvFile;
    if (cvFile == null) {
      final cvUrl = ref.read(authProvider).user?.cvUrl;
      if (cvUrl != null && cvUrl.isNotEmpty) {
        cvFile = await _downloadCvToTemp(cvUrl);
      }
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (cvFile == null) {
      _showSnack('Could not load your CV. Please re-upload.', isError: true);
      return;
    }

    // Show "search started" dialog
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const JobSearchStartedDialog(),
    );

    if (!mounted) return;

    final userId = ref.read(authProvider).user?.id;
    if (userId != null) {
      ref.read(jobMatchingProvider.notifier).setUserId(userId);
    }

    final capturedCvFile = cvFile;
    final capturedJobTitle = _selectedJobTitle!;
    final capturedJobType = _selectedJobType!;
    final capturedCountry = _selectedCountry!;
    final capturedWorkMode = _selectedWorkMode!;

    // Fire-and-forget: run in background, show notification when done
    ref.read(jobMatchingProvider.notifier).matchJobsInBackground(
          jobTitle: capturedJobTitle,
          jobType: capturedJobType,
          country: capturedCountry,
          workMode: capturedWorkMode,
          cvFile: capturedCvFile,
          onSuccess: () {
            if (mounted) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => JobResultsReadyDialog(
                  onViewResults: () => context.go('/recommended-jobs'),
                ),
              );
            }
          },
        );

    // Navigate back to home so user isn't stuck waiting
    if (mounted) context.go('/home');
  }

  Future<File?> _downloadCvToTemp(String cvUrl) async {
    try {
      final dio = await _getDio();
      final tmpDir = Directory.systemTemp;
      final fileName = FileUtils.getFileNameFromUrl(cvUrl) ?? 'cv_temp.pdf';
      final tmpFile = File('${tmpDir.path}/$fileName');
      final cleanUrl = cvUrl.contains('?original=')
          ? cvUrl.split('?original=').first
          : cvUrl;
      await dio.download(cleanUrl, tmpFile.path);
      return tmpFile;
    } catch (_) {
      return null;
    }
  }

  // ignore: prefer_constructors_over_static_methods
  dynamic _getDio() async {
    // Use the global apiClient dio to keep auth headers
    // Import path: '../../../../core/network/api_client.dart'
    // Avoid circular import — instantiate fresh Dio here for file download
    // (no auth needed for Supabase storage public URLs)
    final dio = _SimpleDio();
    return dio;
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

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = context.appTextTheme;
    final user = ref.watch(authProvider).user;
    final jobState = ref.watch(jobMatchingProvider);

    final hasCV = _cvFile != null || (user?.cvUrl?.isNotEmpty ?? false);

    final bg = isDark ? AppColors.blue900 : AppColors.grey100;
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
            // ── App bar ────────────────────────────────────────────────────
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

            // ── Title ──────────────────────────────────────────────────────
            Text(
              'Job Preferences',
              style: textTheme.title1Bold.copyWith(
                color: widget.fromJobMatching ? accent : primary,
              ),
            ),

            if (widget.fromJobMatching) ...[
              SizedBox(height: context.h(6)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: context.w(24)),
                child: Text(
                  'Fill in your preferences and upload your CV — our AI will find the best matches for you.',
                  style: textTheme.bodyRegular.copyWith(color: muted),
                  textAlign: TextAlign.center,
                ),
              ),
            ],

            SizedBox(height: context.h(12)),

            // ── Scrollable content ─────────────────────────────────────────
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
                    // ── Job Title dropdown ───────────────────────────────
                    _label('Job Title', primary, textTheme),
                    SizedBox(height: context.h(8)),
                    _buildDropdown(
                      value: _selectedJobTitle,
                      hint: 'Select your job title',
                      items: jobState.jobTitles,
                      accent: accent,
                      primary: primary,
                      muted: muted,
                      fieldBg: fieldBg,
                      border: border,
                      isDark: isDark,
                      onChanged: (v) => setState(() => _selectedJobTitle = v),
                    ),

                    SizedBox(height: context.h(20)),

                    // ── Country dropdown ─────────────────────────────────
                    _label('Country', primary, textTheme),
                    SizedBox(height: context.h(8)),
                    _buildDropdown(
                      value: _selectedCountry,
                      hint: 'Select your country',
                      items: jobState.countries
                          .map((c) => c['name'] ?? '')
                          .where((n) => n.isNotEmpty)
                          .toList(),
                      accent: accent,
                      primary: primary,
                      muted: muted,
                      fieldBg: fieldBg,
                      border: border,
                      isDark: isDark,
                      onChanged: (v) => setState(() => _selectedCountry = v),
                    ),

                    SizedBox(height: context.h(20)),

                    // ── Work Type chips ──────────────────────────────────
                    _label('Work Type', primary, textTheme),
                    SizedBox(height: context.h(10)),
                    _buildChips(
                      options: _jobTypeOptions,
                      selected: _selectedJobType,
                      accent: accent,
                      primary: primary,
                      fieldBg: fieldBg,
                      border: border,
                      isDark: isDark,
                      onTap: (o) => setState(() =>
                          _selectedJobType = o == _selectedJobType ? null : o),
                    ),

                    SizedBox(height: context.h(20)),

                    // ── Work Mode chips ──────────────────────────────────
                    _label('Work Mode', primary, textTheme),
                    SizedBox(height: context.h(10)),
                    _buildChips(
                      options: _workModeOptions,
                      selected: _selectedWorkMode,
                      accent: accent,
                      primary: primary,
                      fieldBg: fieldBg,
                      border: border,
                      isDark: isDark,
                      onTap: (o) => setState(() => _selectedWorkMode =
                          o == _selectedWorkMode ? null : o),
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

                    // ── Find Jobs button ─────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: context.h(52),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleFind,
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
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Find Matching Jobs',
                                    style: textTheme.title2Bold.copyWith(
                                      color: isDark
                                          ? AppColors.blue900
                                          : AppColors.grey50,
                                    ),
                                  ),
                                  SizedBox(width: context.w(8)),
                                  Icon(
                                    Icons.search,
                                    color: isDark
                                        ? AppColors.blue900
                                        : AppColors.grey50,
                                    size: context.icon(20),
                                  ),
                                ],
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

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _label(String text, Color color, AppTextTheme t) =>
      Text(text, style: t.bodyBold.copyWith(color: color));

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required Color accent,
    required Color primary,
    required Color muted,
    required Color fieldBg,
    required Color border,
    required bool isDark,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: context.w(16)),
      decoration: BoxDecoration(
        color: fieldBg,
        borderRadius: BorderRadius.circular(context.r(10)),
        border: Border.all(
          color: value != null ? accent : border,
          width: value != null ? 1.5 : 1.0,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint,
              style: TextStyle(
                  fontFamily: 'Inter', fontSize: context.sp(13), color: muted)),
          isExpanded: true,
          dropdownColor: fieldBg,
          icon: Icon(Icons.keyboard_arrow_down, color: muted),
          style: TextStyle(
              fontFamily: 'Inter', fontSize: context.sp(14), color: primary),
          items: items
              .map((item) => DropdownMenuItem(
                    value: item,
                    child: Text(item),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildChips({
    required List<String> options,
    required String? selected,
    required Color accent,
    required Color primary,
    required Color fieldBg,
    required Color border,
    required bool isDark,
    required ValueChanged<String> onTap,
  }) {
    return Wrap(
      spacing: context.w(8),
      runSpacing: context.h(8),
      children: options.map((o) {
        final isSelected = selected == o;
        return GestureDetector(
          onTap: () => onTap(o),
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
                  o,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: context.sp(13),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? (isDark ? AppColors.blue900 : AppColors.grey50)
                        : primary,
                  ),
                ),
                SizedBox(width: context.w(6)),
                Icon(
                  isSelected ? Icons.check : Icons.add,
                  size: context.icon(14),
                  color: isSelected
                      ? (isDark ? AppColors.blue900 : AppColors.grey50)
                      : primary,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Simple Dio wrapper for downloading CV ────────────────────────────────────
class _SimpleDio {
  Future<void> download(String url, String savePath) async {
    // Use dio from package to download
    // We can't import apiClient here without circular dep,
    // so we create a minimal Dio instance just for downloading.
    // The CV storage URL is public (Supabase storage), no auth needed.
    final dio = _createDio();
    await dio.download(url, savePath);
  }

  dynamic _createDio() {
    // Return a basic Dio. Import is resolved at compile time via dio package.
    // ignore: undefined_prefixes
    return _DioFactory.create();
  }
}

class _DioFactory {
  static dynamic create() {
    // Import 'package:dio/dio.dart' is at the top of this file.
    // This just isolates the instantiation.
    return Dio();
  }
}

// ─── CV Upload Area (same as job_preferences_screen original) ─────────────────
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
                  hasCV ? 'Tap to change' : 'Tap to upload',
                  style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: context.sp(14),
                      fontWeight: FontWeight.w500,
                      color: primary),
                ),
                if (hasCV && fileName != null) ...[
                  SizedBox(height: context.h(6)),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.check_circle_outline,
                        color: accent, size: context.icon(14)),
                    SizedBox(width: context.w(4)),
                    Flexible(
                      child: Text(
                        fileName!,
                        style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: context.sp(12),
                            color: accent),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
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

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dotted_border/dotted_border.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../../../../core/utils/file_utils.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../job_matching/presentation/widgets/job_matching_dialogs.dart';

class CareerPreferencesScreen extends ConsumerStatefulWidget {
  final VoidCallback? onPreferencesSaved;

  const CareerPreferencesScreen({
    super.key,
    this.onPreferencesSaved,
  });

  @override
  ConsumerState<CareerPreferencesScreen> createState() =>
      _CareerPreferencesScreenState();
}

class _CareerPreferencesScreenState
    extends ConsumerState<CareerPreferencesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _formKey = GlobalKey<FormState>();

  final _preferredLocationController = TextEditingController();
  final _interestedTracksController = TextEditingController();
  final _jobTitleController = TextEditingController();

  List<String> _selectedWorkTypes = [];
  List<String> _selectedWorkLocations = [];
  List<String> _selectedJobPlatforms = [];

  String? _selectedAlertFrequency;

  String? _cvFileName;
  bool _isUploading = false;
  bool _isLoading = false;
  bool _isEditing = false;

  final List<String> _workTypeOptions = ['Full-time', 'Part-time'];
  final List<String> _workLocationOptions = ['Onsite', 'Remote', 'Hybrid'];
  final List<String> _jobPlatformOptions = ['LinkedIn', 'Adzuna', 'Jooble'];
  final List<String> _alertFrequencyOptions = ['24 hours', '3 days', '1 week'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 1);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging &&
          _tabController.index == 0 &&
          mounted) {
        context.pushReplacement('/personal-info');
      }
    });
    _loadUserPreferences();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _preferredLocationController.dispose();
    _interestedTracksController.dispose();
    _jobTitleController.dispose();
    super.dispose();
  }

  void _loadUserPreferences() {
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

  // ── CV actions ──────────────────────────────────────────────────────────────
  Future<void> _openCV() async {
    final user = ref.read(authProvider).user;
    if (user?.cvUrl != null && user!.cvUrl!.isNotEmpty) {
      try {
        final success = await FileUtils.openFile(user.cvUrl!);
        if (!success && mounted) {
          _showSnack('Could not open file. No app found to open PDF.',
              isError: true);
        }
      } catch (e) {
        if (mounted) {
          _showSnack('Could not open file: ${e.toString()}', isError: true);
        }
      }
    }
  }

  Future<void> _downloadCV() async {
    final user = ref.read(authProvider).user;
    if (user?.cvUrl != null && user!.cvUrl!.isNotEmpty) {
      try {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => Center(
            child: Container(
              padding: EdgeInsets.all(context.w(20)),
              decoration: BoxDecoration(
                color: isDark ? AppColors.blue700 : AppColors.grey50,
                borderRadius: BorderRadius.circular(context.r(16)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  SizedBox(height: context.h(16)),
                  Text(
                    'Downloading CV...',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: context.sp(14),
                      color: isDark ? AppColors.grey50 : AppColors.blue900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        final success =
            await FileUtils.downloadFile(user.cvUrl!, onProgress: (_) {});
        if (mounted) Navigator.pop(context);
        if (mounted) {
          _showSnack(
            success
                ? 'CV downloaded successfully to Downloads folder'
                : 'Could not download file',
            isError: !success,
          );
        }
      } catch (e) {
        if (mounted) Navigator.pop(context);
        if (mounted) {
          _showSnack('Could not download file: ${e.toString()}', isError: true);
        }
      }
    }
  }

  Future<void> _pickCV() async {
    try {
      setState(() => _isUploading = true);

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final userId = ref.read(authProvider).user?.id;
        if (userId == null) throw Exception('User not logged in');

        setState(() => _cvFileName = result.files.single.name);

        final cvUrl = await ref.read(authProvider.notifier).uploadCV(file);
        if (cvUrl != null && mounted) {
          final success = await ref
              .read(authProvider.notifier)
              .updateUserProfile(cvUrl: cvUrl);
          if (success && mounted) {
            await ref.read(authProvider.notifier).refreshUser();
            _loadUserPreferences();
            if (mounted) {
              _showSnack('CV uploaded successfully!', isError: false);
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Failed to upload CV: ${e.toString()}', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _handleSave() async {
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

    if (success) {
      await ref.read(authProvider.notifier).refreshUser();
      _loadUserPreferences();
      if (!mounted) return;

      setState(() => _isEditing = false);

      if (widget.onPreferencesSaved != null) {
        widget.onPreferencesSaved!();
      } else {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const PreferencesSavedDialog(),
        );
      }
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Inter')),
      backgroundColor: isError ? AppColors.red600 : AppColors.green700,
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.all(context.w(16)),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(context.r(12))),
    ));
  }

  void _toggleSelection(List<String> list, String item) {
    setState(() {
      if (list.contains(item)) {
        list.remove(item);
      } else {
        list.add(item);
      }
    });
  }

  String _freqValueFromLabel(String label) {
    if (label == '24 hours') return 'daily';
    if (label == '3 days') return '3days';
    return 'weekly';
  }

  // ── Chip section ─────────────────────────────────────────────────────────────
  Widget _buildChipSection({
    required String title,
    required List<String> options,
    required List<String> selectedList,
    required Function(String) onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? AppColors.grey50 : AppColors.blue900;
    final fieldBg = isDark ? AppColors.blue700 : AppColors.grey50;
    final viewBorderColor = isDark ? AppColors.blue400 : AppColors.grey600;
    final unselectedTextColor = isDark ? AppColors.grey200 : AppColors.blue900;

    final selectedColor =
        isDark ? AppColors.lightBlue500 : AppColors.lightBlue700;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: context.sp(14),
            fontWeight: FontWeight.w600,
            color: titleColor,
          ),
        ),
        SizedBox(height: context.h(10)),
        Wrap(
          spacing: context.w(8),
          runSpacing: context.h(8),
          children: options.map((option) {
            final isSelected = selectedList.contains(option);
            return GestureDetector(
              onTap: _isEditing ? () => onTap(option) : null,
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: context.w(16), vertical: context.h(8)),
                decoration: BoxDecoration(
                  color: isSelected ? selectedColor : fieldBg,
                  borderRadius: BorderRadius.circular(context.r(50)),
                  border: Border.all(
                    color: isSelected ? selectedColor : viewBorderColor,
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      option,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: context.sp(13),
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected
                            ? Colors.white
                            : _isEditing
                                ? unselectedTextColor
                                : unselectedTextColor.withOpacity(0.45),
                      ),
                    ),
                    if (!isSelected) ...[
                      SizedBox(width: context.w(6)),
                      Icon(
                        Icons.add,
                        size: context.icon(14),
                        color: _isEditing
                            ? unselectedTextColor
                            : unselectedTextColor.withOpacity(0.45),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Figma-style text field ────────────────────────────────────────────────────
  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fieldBg = isDark ? AppColors.blue700 : AppColors.grey50;
    final textColor = isDark ? AppColors.grey50 : AppColors.blue900;
    final viewBorderColor = isDark ? AppColors.blue400 : AppColors.grey600;
    final activeBorderColor =
        isDark ? AppColors.lightBlue500 : AppColors.lightBlue700;
    final borderColor = _isEditing ? activeBorderColor : viewBorderColor;
    final borderWidth = _isEditing ? 1.5 : 1.0;

    final outlineBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(context.r(10.0)),
      borderSide: BorderSide(color: borderColor, width: borderWidth),
    );

    return TextFormField(
      controller: controller,
      readOnly: !_isEditing,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: context.sp(15),
        fontWeight: _isEditing ? FontWeight.w500 : FontWeight.w400,
        color: _isEditing ? textColor : textColor.withOpacity(0.45),
      ),
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        hintText: hint,
        hintStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: context.sp(13),
          color: textColor.withOpacity(0.35),
        ),
        labelStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: context.sp(12),
          fontWeight: FontWeight.w500,
          color: borderColor,
        ),
        filled: true,
        fillColor: fieldBg,
        contentPadding: EdgeInsets.symmetric(
          horizontal: context.w(16),
          vertical: context.h(16),
        ),
        enabledBorder: outlineBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(context.r(10.0)),
          borderSide: BorderSide(color: activeBorderColor, width: 1.5),
        ),
        disabledBorder: outlineBorder,
        errorBorder: outlineBorder,
        focusedErrorBorder: outlineBorder,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final hasCV = user?.cvUrl != null && user!.cvUrl!.isNotEmpty;
    final isLoading = _isLoading || authState.isLoading;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth >= 600;
    final isLargeTablet = screenWidth >= 900;
    final isSmallPhone = screenWidth < 360;
    final isShortScreen = screenHeight < 650;

    final hPad = isLargeTablet
        ? screenWidth * 0.18
        : isTablet
            ? context.w(48)
            : context.w(20);
    final tabFontSize = isTablet
        ? context.sp(15)
        : isSmallPhone
            ? context.sp(12)
            : context.sp(13);

    // ── Adaptive colors ────────────────────────────────────────────────────────
    final titleColor = isDark ? AppColors.grey50 : AppColors.blue900;
    final viewBorderColor = isDark ? AppColors.blue400 : AppColors.grey600;
    final accentColor =
        isDark ? AppColors.lightBlue500 : AppColors.lightBlue700;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final safeBottom = MediaQuery.of(context).padding.bottom;
            final keyboardH = MediaQuery.of(context).viewInsets.bottom;

            return Column(
              children: [
                // ── Top bar ────────────────────────────────────────────────
                Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: hPad,
                      vertical: context.h(isShortScreen ? 10 : 16)),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Icon(Icons.arrow_back_ios_new,
                            color: titleColor, size: context.icon(20)),
                      ),
                      const Spacer(),
                      Image.asset(
                        'assets/images/branding/growza_logo.png',
                        width: context.w(105),
                        height: context.h(40),
                        fit: BoxFit.contain,
                      ),
                      const Spacer(),
                      SizedBox(width: context.icon(20)),
                    ],
                  ),
                ),

                // ── Title + edit icon ───────────────────────────────────────
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  child: Row(
                    children: [
                      SizedBox(width: context.w(36)),
                      Expanded(
                        child: Center(
                          child: Text('Profile',
                              style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: context.sp(20),
                                  fontWeight: FontWeight.w700,
                                  color: titleColor)),
                        ),
                      ),
                      InkWell(
                        onTap: () => setState(() => _isEditing = !_isEditing),
                        borderRadius: BorderRadius.circular(context.r(8)),
                        child: Padding(
                          padding: EdgeInsets.all(context.w(6)),
                          child: Icon(
                            _isEditing ? Icons.close : Icons.edit,
                            color: _isEditing ? AppColors.red600 : accentColor,
                            size: context.icon(20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: context.h(isShortScreen ? 8 : 12)),

                // ── Tab bar ─────────────────────────────────────────────────
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  child: TabBar(
                    controller: _tabController,
                    indicator: UnderlineTabIndicator(
                      borderSide: BorderSide(width: 2.5, color: accentColor),
                      insets: EdgeInsets.zero,
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: accentColor,
                    unselectedLabelColor:
                        isDark ? AppColors.grey400 : AppColors.grey600,
                    labelStyle: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: tabFontSize,
                        fontWeight: FontWeight.w600),
                    unselectedLabelStyle: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: tabFontSize,
                        fontWeight: FontWeight.w400),
                    dividerColor:
                        isDark ? AppColors.blue400 : AppColors.grey300,
                    isScrollable: isSmallPhone,
                    tabs: const [
                      Tab(text: 'Personal Info'),
                      Tab(text: 'Career Preferences'),
                    ],
                  ),
                ),

                SizedBox(height: context.h(16)),

                // ── Scrollable content ──────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.only(
                        left: hPad,
                        right: hPad,
                        bottom: keyboardH + safeBottom + context.h(16)),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Text fields ───────────────────────────────────
                          _buildField(
                              controller: _preferredLocationController,
                              label: 'Preferred Location',
                              hint: 'e.g. Alexandria, Cairo, Remote'),
                          SizedBox(height: context.h(14)),
                          _buildField(
                              controller: _interestedTracksController,
                              label: 'Interested Tracks',
                              hint: 'e.g. UI/UX Design & Machine Learning'),
                          SizedBox(height: context.h(14)),
                          _buildField(
                              controller: _jobTitleController,
                              label: 'Job Title',
                              hint: 'e.g. Data Analyst, ML Engineer'),

                          SizedBox(height: context.h(28)),

                          // ── Work Type ─────────────────────────────────────
                          _buildChipSection(
                              title: 'Work Type',
                              options: _workTypeOptions,
                              selectedList: _selectedWorkTypes,
                              onTap: (i) =>
                                  _toggleSelection(_selectedWorkTypes, i)),
                          SizedBox(height: context.h(22)),

                          // ── Work Location ─────────────────────────────────
                          _buildChipSection(
                              title: 'Work Location',
                              options: _workLocationOptions,
                              selectedList: _selectedWorkLocations,
                              onTap: (i) =>
                                  _toggleSelection(_selectedWorkLocations, i)),
                          SizedBox(height: context.h(22)),

                          // ── Job Platforms ─────────────────────────────────
                          _buildChipSection(
                              title: 'Job Platforms',
                              options: _jobPlatformOptions,
                              selectedList: _selectedJobPlatforms,
                              onTap: (i) =>
                                  _toggleSelection(_selectedJobPlatforms, i)),

                          SizedBox(height: context.h(28)),

                          // ── Alert Frequency ───────────────────────────────
                          Text('Get job alerts every',
                              style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: context.sp(14),
                                  fontWeight: FontWeight.w600,
                                  color: titleColor)),
                          SizedBox(height: context.h(10)),
                          Wrap(
                            spacing: context.w(10),
                            runSpacing: context.h(10),
                            children: _alertFrequencyOptions.map((freq) {
                              final freqValue = _freqValueFromLabel(freq);
                              final isSelected =
                                  _selectedAlertFrequency == freqValue;
                              final fieldBg =
                                  isDark ? AppColors.blue700 : AppColors.grey50;
                              final unselectedText = isDark
                                  ? AppColors.grey200
                                  : AppColors.blue900;
                              final selectedChipColor = isDark
                                  ? AppColors.lightBlue500
                                  : AppColors.lightBlue700;
                              return GestureDetector(
                                onTap: _isEditing
                                    ? () => setState(() {
                                          _selectedAlertFrequency =
                                              isSelected ? null : freqValue;
                                        })
                                    : null,
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: context.w(20),
                                      vertical: context.h(10)),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? selectedChipColor
                                        : fieldBg,
                                    borderRadius:
                                        BorderRadius.circular(context.r(50)),
                                    border: Border.all(
                                      color: isSelected
                                          ? selectedChipColor
                                          : viewBorderColor,
                                      width: isSelected ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: Text(
                                    freq,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: context.sp(13),
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: isSelected
                                          ? Colors.white
                                          : (_isEditing
                                              ? unselectedText
                                              : unselectedText
                                                  .withOpacity(0.45)),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),

                          SizedBox(height: context.h(28)),

                          // ── Upload CV ─────────────────────────────────────
                          Text('Upload CV',
                              style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: context.sp(14),
                                  fontWeight: FontWeight.w600,
                                  color: titleColor)),
                          SizedBox(height: context.h(10)),

                          if (_cvFileName != null || hasCV)
                            _CvCard(
                              fileName: _cvFileName ?? 'CV',
                              fileUrl: user?.cvUrl ?? '',
                              isDark: isDark,
                              isEditing: _isEditing,
                              isUploading: _isUploading,
                              onOpen: _openCV,
                              onDownload: _downloadCV,
                              onEdit: _pickCV,
                            )
                          else if (_isEditing)
                            InkWell(
                              onTap: _isUploading ? null : _pickCV,
                              child: DottedBorder(
                                borderType: BorderType.RRect,
                                radius: Radius.circular(context.r(12)),
                                color: accentColor,
                                dashPattern: const [6, 3],
                                child: Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.symmetric(
                                      horizontal: context.w(24),
                                      vertical: context.h(24)),
                                  decoration: BoxDecoration(
                                    color: accentColor.withOpacity(0.05),
                                    borderRadius:
                                        BorderRadius.circular(context.r(12)),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(Icons.upload_file,
                                          size: context.icon(36),
                                          color: accentColor),
                                      SizedBox(height: context.h(8)),
                                      Text(
                                        _isUploading
                                            ? 'Uploading...'
                                            : 'Tap to upload your CV',
                                        style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: context.sp(15),
                                            fontWeight: FontWeight.w600,
                                            color: accentColor),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                          // ── Save button ───────────────────────────────────
                          if (_isEditing) ...[
                            SizedBox(height: context.h(32)),
                            CustomButton(
                              text: 'Save Preferences',
                              onPressed: _handleSave,
                              isLoading: isLoading,
                              backgroundColor: accentColor,
                              textColor:
                                  isDark ? AppColors.blue700 : Colors.white,
                            ),
                          ],

                          SizedBox(height: context.h(24)),
                        ],
                      ),
                    ),
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

// ─── CV Card ─────────────────────────────────────────────────────────────────
class _CvCard extends StatelessWidget {
  const _CvCard({
    required this.fileName,
    required this.fileUrl,
    required this.isDark,
    required this.isEditing,
    required this.isUploading,
    required this.onOpen,
    required this.onDownload,
    required this.onEdit,
  });

  final String fileName;
  final String fileUrl;
  final bool isDark;
  final bool isEditing;
  final bool isUploading;
  final VoidCallback onOpen;
  final VoidCallback onDownload;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final fieldBg = isDark ? AppColors.blue700 : AppColors.grey50;
    final viewBorderColor = isDark ? AppColors.blue400 : AppColors.grey600;
    final textColor = isDark ? AppColors.grey50 : AppColors.blue900;
    final accentColor =
        isDark ? AppColors.lightBlue500 : AppColors.lightBlue700;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: fieldBg,
        borderRadius: BorderRadius.circular(context.r(12)),
        border: Border.all(color: viewBorderColor, width: 1.0),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(context.w(14)),
            child: Row(
              children: [
                Container(
                  width: context.w(44),
                  height: context.w(44),
                  decoration: BoxDecoration(
                    color: FileUtils.getFileColor(fileUrl).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(context.r(10)),
                  ),
                  child: Icon(FileUtils.getFileIcon(fileUrl),
                      color: FileUtils.getFileColor(fileUrl),
                      size: context.icon(22)),
                ),
                SizedBox(width: context.w(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fileName,
                          style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: context.sp(14),
                              fontWeight: FontWeight.w600,
                              color: textColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      SizedBox(height: context.h(2)),
                      Text(
                          '${FileUtils.getFileExtension(fileUrl).toUpperCase()} Document',
                          style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: context.sp(12),
                              color: textColor.withOpacity(0.45))),
                    ],
                  ),
                ),
                Wrap(
                  spacing: context.w(2),
                  children: [
                    IconButton(
                        onPressed: onOpen,
                        icon: Icon(Icons.visibility,
                            color: accentColor, size: context.icon(20))),
                    IconButton(
                        onPressed: onDownload,
                        icon: Icon(Icons.download,
                            color: accentColor, size: context.icon(20))),
                    if (isEditing)
                      IconButton(
                        onPressed: isUploading ? null : onEdit,
                        icon: isUploading
                            ? SizedBox(
                                width: context.icon(20),
                                height: context.icon(20),
                                child: const CircularProgressIndicator(
                                    strokeWidth: 2))
                            : Icon(Icons.edit,
                                color: accentColor, size: context.icon(20)),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
                horizontal: context.w(14), vertical: context.h(10)),
            decoration: BoxDecoration(
              color: AppColors.green700.withOpacity(0.08),
              borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(context.r(12)),
                  bottomRight: Radius.circular(context.r(12))),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle,
                    color: AppColors.green700, size: context.icon(14)),
                SizedBox(width: context.w(6)),
                Text('CV uploaded successfully',
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: context.sp(12),
                        color: AppColors.green700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

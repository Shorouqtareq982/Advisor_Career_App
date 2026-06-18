import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../providers/career_build_provider.dart';
import '../widgets/career_build_step_indicator.dart';

class CreatePlanStep1Screen extends ConsumerStatefulWidget {
  const CreatePlanStep1Screen({super.key});

  @override
  ConsumerState<CreatePlanStep1Screen> createState() =>
      _CreatePlanStep1ScreenState();
}

class _CreatePlanStep1ScreenState extends ConsumerState<CreatePlanStep1Screen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(careerBuildProvider.notifier).loadTracks();
    });
  }

  Future<void> _pickCvFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'doc', 'docx'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      ref.read(careerBuildProvider.notifier).setCvPlatformFile(file);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not pick the CV file.')),
      );
    }
  }

  void _clearCv() {
    ref.read(careerBuildProvider.notifier).clearCv();
  }

  void _backToPlans(BuildContext context) => context.go('/career-build');

  void _commitTrack(String raw) {
    ref.read(careerBuildProvider.notifier).commitTrack(raw);
  }

  Future<void> _reloadTracks() async {
    await ref.read(careerBuildProvider.notifier).loadTracks();
  }

  Future<void> _next(BuildContext context) async {
    final notifier = ref.read(careerBuildProvider.notifier);
    final ok = await notifier.analyzeCvAndGoNext();

    if (!mounted) return;

    if (ok) {
      context.go('/career-build/create/step-2');
    } else {
      final error = ref.read(careerBuildProvider).backendError ??
          'Please select a track and upload your CV first.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(careerBuildProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final selectedTrack =
        state.trackInput.trim().isEmpty ? null : state.trackInput.trim();

    final trackOptions = state.tracks.map((e) => e.trackName).toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.blue900 : AppColors.textDark,
      body: Stack(
        children: [
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.w(16),
                        vertical: context.h(10),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: SizedBox(
                                width: context.w(24),
                                height: context.w(24),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: state.isAnalyzeLoading
                                      ? null
                                      : () => _backToPlans(context),
                                  icon: Icon(
                                    Icons.arrow_back_ios_new,
                                    size: context.icon(18),
                                    color: isDark
                                        ? AppColors.grey50
                                        : AppColors.blue900,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: context.h(6)),
                            Center(
                              child: Image.asset(
                                'assets/images/branding/logo.png',
                                height: context.h(50),
                                fit: BoxFit.contain,
                              ),
                            ),
                            SizedBox(height: context.h(6)),
                            Text(
                              'Career Build',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: context.sp(19).clamp(17.0, 20.0),
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                                color: isDark
                                    ? AppColors.grey50
                                    : AppColors.blue900,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: context.h(6)),
                            Text(
                              'Create a personalized learning plan for your\ncareer',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: context.sp(14).clamp(13.0, 16.0),
                                fontWeight: FontWeight.w500,
                                height: 1.2,
                                color: isDark
                                    ? AppColors.grey400
                                    : AppColors.grey800,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: context.h(18)),
                            const CareerBuildStepIndicator(
                              currentStep: 1,
                              totalSteps: 4,
                            ),
                            SizedBox(height: context.h(16)),
                            if (state.isTracksLoading)
                              Padding(
                                padding: EdgeInsets.only(bottom: context.h(12)),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: context.w(16),
                                      height: context.w(16),
                                      child: const CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    SizedBox(width: context.w(8)),
                                    Text(
                                      'Loading tracks...',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize:
                                            context.sp(12).clamp(11.0, 13.0),
                                        color: isDark
                                            ? AppColors.grey300
                                            : AppColors.grey800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            _TrackSelectPicker(
                              title: 'Interested Tracks',
                              value: selectedTrack,
                              options: trackOptions,
                              isLoading: state.isTracksLoading,
                              hint: state.isTracksLoading
                                  ? 'Loading tracks...'
                                  : trackOptions.isEmpty
                                      ? 'Tap to load career tracks'
                                      : 'Select your target career track',
                              onPick: (v) => _commitTrack(v),
                              onEmptyTap: _reloadTracks,
                            ),
                            if (!state.isTracksLoading &&
                                trackOptions.isEmpty &&
                                state.backendError == null) ...[
                              SizedBox(height: context.h(8)),
                              _InfoBox(
                                isDark: isDark,
                                message:
                                    'Career tracks are not loaded yet. Tap the field above to try again.',
                              ),
                            ],
                            if (state.selectedTrack != null &&
                                state.selectedTrack!.description
                                    .trim()
                                    .isNotEmpty) ...[
                              SizedBox(height: context.h(8)),
                              Text(
                                state.selectedTrack!.description,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: context.sp(12).clamp(11.0, 13.0),
                                  fontWeight: FontWeight.w500,
                                  height: 1.35,
                                  color: isDark
                                      ? AppColors.grey400
                                      : AppColors.grey700,
                                ),
                              ),
                            ],
                            SizedBox(height: context.h(14)),
                            Text(
                              'Upload CV',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: context.sp(12).clamp(11.0, 13.0),
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.grey200
                                    : AppColors.blue900,
                              ),
                            ),
                            SizedBox(height: context.h(6)),
                            _UploadCvBox(
                              fileName: state.cvFileName,
                              isDark: isDark,
                              onPick:
                                  state.isAnalyzeLoading ? () {} : _pickCvFile,
                              onRemove:
                                  state.isAnalyzeLoading ? () {} : _clearCv,
                            ),
                            if (state.backendError != null) ...[
                              SizedBox(height: context.h(12)),
                              _ErrorBox(
                                message: state.backendError!,
                                isDark: isDark,
                              ),
                            ],
                            SizedBox(height: context.h(24)),
                            FigmaBackNextButtons(
                              isLoading: state.isAnalyzeLoading,
                              onBack: () => _backToPlans(context),
                              onNext: () => _next(context),
                            ),
                            SizedBox(height: context.h(14)),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (state.isAnalyzeLoading)
            Container(
              color: Colors.black.withOpacity(0.18),
              child: Center(
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: context.w(24)),
                  padding: EdgeInsets.all(context.w(18)),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF111A38) : Colors.white,
                    borderRadius: BorderRadius.circular(context.r(16)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFF268299),
                      ),
                      SizedBox(height: context.h(14)),
                      Text(
                        'Analyzing your CV...',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: context.sp(15).clamp(14.0, 16.0),
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.grey50 : AppColors.blue900,
                        ),
                      ),
                      SizedBox(height: context.h(8)),
                      Text(
                        'We are detecting your current skills and comparing them with the selected track requirements.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: context.sp(12).clamp(11.0, 13.0),
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                          color: isDark ? AppColors.grey400 : AppColors.grey700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String message;
  final bool isDark;

  const _InfoBox({
    required this.message,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.w(12)),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF2A8AA2).withOpacity(0.12)
            : const Color(0xFF268299).withOpacity(0.08),
        borderRadius: BorderRadius.circular(context.r(12)),
        border: Border.all(
          color: isDark
              ? const Color(0xFF2A8AA2).withOpacity(0.35)
              : const Color(0xFF268299).withOpacity(0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: context.icon(18),
            color: const Color(0xFF268299),
          ),
          SizedBox(width: context.w(8)),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: context.sp(12).clamp(11.0, 13.0),
                fontWeight: FontWeight.w600,
                height: 1.35,
                color: isDark ? AppColors.grey200 : AppColors.grey800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  final bool isDark;

  const _ErrorBox({
    required this.message,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.w(12)),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.red300.withOpacity(0.10)
            : AppColors.red600.withOpacity(0.08),
        borderRadius: BorderRadius.circular(context.r(12)),
        border: Border.all(
          color: isDark
              ? AppColors.red300.withOpacity(0.35)
              : AppColors.red600.withOpacity(0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: context.icon(18),
            color: isDark ? AppColors.red300 : AppColors.red600,
          ),
          SizedBox(width: context.w(8)),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: context.sp(12).clamp(11.0, 13.0),
                fontWeight: FontWeight.w600,
                height: 1.35,
                color: isDark ? AppColors.red300 : AppColors.red600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadCvBox extends StatelessWidget {
  final String? fileName;
  final bool isDark;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _UploadCvBox({
    required this.fileName,
    required this.isDark,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark ? const Color(0xFF2A8AA2) : AppColors.grey300;
    final bgColor = isDark ? const Color(0xFF111A38) : AppColors.grey50;
    final titleColor = isDark ? AppColors.grey50 : AppColors.blue900;
    final subColor = isDark ? AppColors.grey400 : AppColors.grey700;
    final iconColor = isDark ? AppColors.grey200 : AppColors.grey800;

    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(context.r(8)),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(context.w(14)),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(context.r(8)),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.file_present_outlined,
              size: context.icon(28),
              color: iconColor,
            ),
            SizedBox(height: context.h(8)),
            Text(
              fileName == null ? 'click to upload' : fileName!,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: context.sp(13).clamp(12.0, 14.0),
                fontWeight: FontWeight.w600,
                color: titleColor,
              ),
            ),
            SizedBox(height: context.h(6)),
            Text(
              fileName == null
                  ? 'Supported formats: PDF, DOC, DOCX (max 10 MB)'
                  : 'Click to change • Supported formats: PDF, DOC, DOCX',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: context.sp(11).clamp(10.0, 12.0),
                fontWeight: FontWeight.w500,
                color: subColor,
              ),
            ),
            if (fileName != null) ...[
              SizedBox(height: context.h(10)),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: onRemove,
                  icon: Icon(
                    Icons.delete_outline,
                    color: isDark ? AppColors.red300 : AppColors.red600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class FigmaBackNextButtons extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onNext;
  final bool isLoading;

  const FigmaBackNextButtons({
    super.key,
    required this.onBack,
    required this.onNext,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    const figmaTeal = Color(0xFF268299);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SizedBox(
          width: context.w(110),
          height: context.h(48),
          child: OutlinedButton(
            onPressed: isLoading ? null : onBack,
            style: OutlinedButton.styleFrom(
              foregroundColor: figmaTeal,
              side: const BorderSide(color: figmaTeal, width: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
            child: Text(
              'Back',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: context.sp(14).clamp(13.0, 15.0),
              ),
            ),
          ),
        ),
        SizedBox(
          width: context.w(110),
          height: context.h(48),
          child: ElevatedButton(
            onPressed: isLoading ? null : onNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: figmaTeal,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50),
              ),
            ),
            child: isLoading
                ? SizedBox(
                    width: context.w(18),
                    height: context.w(18),
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Next',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: context.sp(14).clamp(13.0, 15.0),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _TrackSelectPicker extends StatefulWidget {
  final String title;
  final String? value;
  final List<String> options;
  final String hint;
  final bool isLoading;
  final ValueChanged<String> onPick;
  final Future<void> Function()? onEmptyTap;

  const _TrackSelectPicker({
    required this.title,
    required this.value,
    required this.options,
    required this.hint,
    required this.onPick,
    this.isLoading = false,
    this.onEmptyTap,
  });

  @override
  State<_TrackSelectPicker> createState() => _TrackSelectPickerState();
}

class _TrackSelectPickerState extends State<_TrackSelectPicker> {
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _fieldKey = GlobalKey();
  OverlayEntry? _overlay;

  @override
  void didUpdateWidget(covariant _TrackSelectPicker oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.options.isEmpty && _overlay != null) {
      _hide();
    }
  }

  @override
  void dispose() {
    _hide();
    super.dispose();
  }

  RenderBox? _fieldRenderBox() {
    final ctx = _fieldKey.currentContext;
    if (ctx == null) return null;
    return ctx.findRenderObject() as RenderBox?;
  }

  double _fieldWidth(BuildContext context) {
    final box = _fieldRenderBox();
    if (box == null) return MediaQuery.of(context).size.width;
    return box.size.width;
  }

  bool _shouldShowAbove(BuildContext context, double overlayHeight) {
    final box = _fieldRenderBox();
    if (box == null) return false;

    final topLeft = box.localToGlobal(Offset.zero);
    final fieldTop = topLeft.dy;
    final fieldBottom = topLeft.dy + box.size.height;

    final mq = MediaQuery.of(context);
    final screenH = mq.size.height;
    final paddingTop = mq.padding.top;
    final paddingBottom = mq.padding.bottom;

    final spaceAbove = fieldTop - paddingTop;
    final spaceBelow = (screenH - paddingBottom) - fieldBottom;

    if (spaceBelow >= overlayHeight) return false;
    if (spaceAbove >= overlayHeight) return true;
    return spaceAbove > spaceBelow;
  }

  Future<void> _handleTap() async {
    if (widget.isLoading) return;

    if (widget.options.isEmpty) {
      await widget.onEmptyTap?.call();
      return;
    }

    _show();
  }

  void _show() {
    if (_overlay != null) return;
    if (widget.options.isEmpty) return;

    _overlay = OverlayEntry(
      builder: (overlayContext) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final width = _fieldWidth(overlayContext);
        final maxH = context.h(300);

        final itemH = context.h(50);
        final desiredH = (widget.options.length * itemH) + context.h(16);
        final overlayH = desiredH > maxH ? maxH : desiredH;

        final showAbove = _shouldShowAbove(overlayContext, overlayH);
        final offset = showAbove
            ? Offset(0, -(overlayH + context.h(8)))
            : Offset(0, context.h(52));

        final overlayBg = isDark ? const Color(0xFF111A38) : AppColors.grey50;
        final overlayText = isDark ? AppColors.grey50 : const Color(0xFF111827);
        final overlayBorder =
            isDark ? const Color(0xFF2A8AA2) : const Color(0xFF268299);

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: _hide,
                behavior: HitTestBehavior.translucent,
              ),
            ),
            Positioned(
              width: width,
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: offset,
                child: Material(
                  color: Colors.transparent,
                  elevation: 10,
                  child: Container(
                    decoration: BoxDecoration(
                      color: overlayBg,
                      borderRadius: BorderRadius.circular(context.r(8)),
                      border: Border.all(
                        color: overlayBorder,
                        width: 1.5,
                      ),
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: maxH),
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          vertical: context.h(8),
                          horizontal: context.w(16),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: widget.options.map((t) {
                            return InkWell(
                              onTap: () {
                                widget.onPick(t);
                                _hide();
                              },
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(
                                  vertical: context.h(12),
                                ),
                                child: Text(
                                  t,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w500,
                                    fontSize: context.sp(16).clamp(14.0, 18.0),
                                    color: overlayText,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context, rootOverlay: true).insert(_overlay!);
  }

  void _hide() {
    _overlay?.remove();
    _overlay = null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final fieldBg = isDark ? const Color(0xFF111A38) : const Color(0xFFF8F8F8);
    final fieldBorder =
        isDark ? const Color(0xFF2A8AA2) : const Color(0xFFACACAC);
    final valueTextColor = isDark ? AppColors.grey50 : const Color(0xFF111827);
    final hintColor = isDark ? AppColors.grey400 : const Color(0xFF6B7280);
    final arrowColor = isDark ? AppColors.grey200 : const Color(0xFF111827);

    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: context.sp(12).clamp(11.0, 13.0),
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.grey200 : AppColors.blue900,
            ),
          ),
          SizedBox(height: context.h(6)),
          InkWell(
            onTap: _handleTap,
            borderRadius: BorderRadius.circular(context.r(8)),
            child: Container(
              key: _fieldKey,
              height: context.h(48),
              padding: EdgeInsets.symmetric(horizontal: context.w(16)),
              decoration: BoxDecoration(
                color: fieldBg,
                borderRadius: BorderRadius.circular(context.r(8)),
                border: Border.all(color: fieldBorder, width: 1),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      (widget.value == null || widget.value!.trim().isEmpty)
                          ? widget.hint
                          : widget.value!.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: context.sp(14).clamp(13.0, 16.0),
                        fontWeight: FontWeight.w500,
                        color: (widget.value == null ||
                                widget.value!.trim().isEmpty)
                            ? hintColor
                            : valueTextColor,
                      ),
                    ),
                  ),
                  widget.isLoading
                      ? SizedBox(
                          width: context.w(18),
                          height: context.w(18),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: arrowColor,
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

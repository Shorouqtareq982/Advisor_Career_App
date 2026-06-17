import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import 'portfolio_text_field.dart';
import 'portfolio_upload_box.dart';
import 'portfolio_upload_tile.dart';

class PortfolioSectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isExpanded;
  final bool isSelected;
  final Widget? child;
  final VoidCallback? onTap;
  final VoidCallback? onArrowTap;
  final bool arrowEnabled;

  const PortfolioSectionCard._({
    required this.title,
    required this.subtitle,
    required this.isExpanded,
    required this.isSelected,
    this.child,
    this.onTap,
    this.onArrowTap,
    this.arrowEnabled = true,
  });

  static const _basePath = 'assets/images/ai_protifilo';
  static const _lightCardColor = Color(0xFFF8F8F8);
  static const _darkCardColor = Color(0xFF131A3B);
  static const _lightBorderColor = Color(0xFF686868);
  static const _darkBorderColor = Color(0xFFB8BCC8);
  static const _sectionShadow = BoxShadow(
    color: Color(0x40000000),
    offset: Offset(4, 4),
    blurRadius: 4,
    spreadRadius: 0,
  );

  factory PortfolioSectionCard.simple({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool arrowEnabled = false,
    bool isSelected = false,
  }) {
    return PortfolioSectionCard._(
      title: title,
      subtitle: subtitle,
      isExpanded: false,
      isSelected: isSelected,
      onTap: onTap,
      arrowEnabled: arrowEnabled,
    );
  }

  factory PortfolioSectionCard.cover({
    required bool isExpanded,
    required bool isSelected,
    required String fullName,
    required String professionalTitle,
    required String shortValueStatement,
    required String location,
    required String? profileImagePath,
    required String? profileImageName,
    required String? resumeFileName,
    required bool showViewMyWorkSelected,
    required bool showDownloadCvSelected,
    required bool showContactMeSelected,
    required ValueChanged<String> onFullNameChanged,
    required ValueChanged<String> onProfessionalTitleChanged,
    required ValueChanged<String> onShortValueStatementChanged,
    required ValueChanged<String> onLocationChanged,
    required VoidCallback onArrowTap,
    required VoidCallback onProfileUpload,
    required VoidCallback onResumeUpload,
    required VoidCallback onRemoveProfileImage,
    required VoidCallback onRemoveResumeFile,
    required VoidCallback onViewMyWorkTap,
    required VoidCallback onDownloadCvTap,
    required VoidCallback onContactMeTap,
  }) {
    return PortfolioSectionCard._(
      title: 'Cover',
      subtitle: 'Make a strong first impression',
      isExpanded: isExpanded,
      isSelected: isSelected,
      onTap: onArrowTap,
      onArrowTap: onArrowTap,
      arrowEnabled: true,
      child: _CoverSectionBody(
        fullName: fullName,
        professionalTitle: professionalTitle,
        shortValueStatement: shortValueStatement,
        location: location,
        profileImagePath: profileImagePath,
        profileImageName: profileImageName,
        resumeFileName: resumeFileName,
        showViewMyWorkSelected: showViewMyWorkSelected,
        showDownloadCvSelected: showDownloadCvSelected,
        showContactMeSelected: showContactMeSelected,
        onFullNameChanged: onFullNameChanged,
        onProfessionalTitleChanged: onProfessionalTitleChanged,
        onShortValueStatementChanged: onShortValueStatementChanged,
        onLocationChanged: onLocationChanged,
        onProfileUpload: onProfileUpload,
        onResumeUpload: onResumeUpload,
        onRemoveProfileImage: onRemoveProfileImage,
        onRemoveResumeFile: onRemoveResumeFile,
        onViewMyWorkTap: onViewMyWorkTap,
        onDownloadCvTap: onDownloadCvTap,
        onContactMeTap: onContactMeTap,
      ),
    );
  }

  factory PortfolioSectionCard.professionalExperience({
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return PortfolioSectionCard._(
      title: 'Professional Experience',
      subtitle: 'Where you worked and what you achieved',
      isExpanded: false,
      isSelected: isSelected,
      onTap: onTap,
      onArrowTap: onTap,
      arrowEnabled: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.r(8)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: EdgeInsets.all(context.w(16)),
        decoration: BoxDecoration(
          color: isDark ? _darkCardColor : _lightCardColor,
          borderRadius: BorderRadius.circular(context.r(8)),
          border: Border.all(
            color: isDark ? _darkBorderColor : _lightBorderColor,
            width: 1,
          ),
          boxShadow: const [_sectionShadow],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: context.sp(16).clamp(15.0, 16.0),
                          color:
                              isDark ? Colors.white : const Color(0xFF0F111D),
                        ),
                      ),
                      SizedBox(height: context.h(6)),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                          fontSize: context.sp(13).clamp(12.0, 13.0),
                          color: isDark
                              ? const Color(0xFF9CA3AF)
                              : const Color(0xFF686868),
                        ),
                      ),
                    ],
                  ),
                ),
                if (arrowEnabled)
                  GestureDetector(
                    onTap: onArrowTap,
                    behavior: HitTestBehavior.opaque,
                    child: Transform.rotate(
                      angle: isExpanded ? 1.5708 : 0,
                      child: Image.asset(
                        '$_basePath/arrow.png',
                        width: context.w(24),
                        height: context.w(24),
                        color: isDark ? Colors.white : const Color(0xFF0F111D),
                      ),
                    ),
                  ),
              ],
            ),
            if (isExpanded && child != null) ...[
              SizedBox(height: context.h(16)),
              child!,
            ],
          ],
        ),
      ),
    );
  }
}

class _CoverSectionBody extends StatelessWidget {
  final String fullName;
  final String professionalTitle;
  final String shortValueStatement;
  final String location;

  final String? profileImagePath;
  final String? profileImageName;
  final String? resumeFileName;

  final bool showViewMyWorkSelected;
  final bool showDownloadCvSelected;
  final bool showContactMeSelected;

  final ValueChanged<String> onFullNameChanged;
  final ValueChanged<String> onProfessionalTitleChanged;
  final ValueChanged<String> onShortValueStatementChanged;
  final ValueChanged<String> onLocationChanged;

  final VoidCallback onProfileUpload;
  final VoidCallback onResumeUpload;

  final VoidCallback onRemoveProfileImage;
  final VoidCallback onRemoveResumeFile;

  final VoidCallback onViewMyWorkTap;
  final VoidCallback onDownloadCvTap;
  final VoidCallback onContactMeTap;

  const _CoverSectionBody({
    required this.fullName,
    required this.professionalTitle,
    required this.shortValueStatement,
    required this.location,
    required this.profileImagePath,
    required this.profileImageName,
    required this.resumeFileName,
    required this.showViewMyWorkSelected,
    required this.showDownloadCvSelected,
    required this.showContactMeSelected,
    required this.onFullNameChanged,
    required this.onProfessionalTitleChanged,
    required this.onShortValueStatementChanged,
    required this.onLocationChanged,
    required this.onProfileUpload,
    required this.onResumeUpload,
    required this.onRemoveProfileImage,
    required this.onRemoveResumeFile,
    required this.onViewMyWorkTap,
    required this.onDownloadCvTap,
    required this.onContactMeTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.w(12)),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2145) : const Color(0xFFEBEBEB),
        borderRadius: BorderRadius.circular(context.r(8)),
        border: Border.all(
          color: isDark ? const Color(0xFFB8BCC8) : const Color(0xFFACACAC),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24000000),
            offset: Offset(2, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PortfolioTextField(
            label: 'Full Name',
            hintText: 'Enter Full Name',
            initialValue: fullName,
            onChanged: onFullNameChanged,
          ),
          SizedBox(height: context.h(8)),
          PortfolioTextField(
            label: 'Professional Title',
            hintText: 'e.g. UI/UX Designer | Web Developer',
            initialValue: professionalTitle,
            onChanged: onProfessionalTitleChanged,
          ),
          SizedBox(height: context.h(8)),
          PortfolioTextField(
            label: 'Short Value Statement',
            hintText: 'One sentence that highlights your value',
            initialValue: shortValueStatement,
            onChanged: onShortValueStatementChanged,
          ),
          SizedBox(height: context.h(8)),
          PortfolioTextField(
            label: 'Location (Optional)',
            hintText: 'e.g. Alex, Egypt',
            initialValue: location,
            onChanged: onLocationChanged,
          ),
          SizedBox(height: context.h(8)),
          PortfolioUploadTile(
            label: 'Profile Image',
            filePath: profileImagePath,
            fileName: profileImageName,
            onTap: onProfileUpload,
            onRemove: onRemoveProfileImage,
          ),
          SizedBox(height: context.h(8)),
          PortfolioUploadBox(
            fileName: resumeFileName,
            onTap: onResumeUpload,
            onRemove: onRemoveResumeFile,
          ),
          SizedBox(height: context.h(8)),
          _SelectableFilledPillButton(
            label: 'View My Work',
            isSelected: showViewMyWorkSelected,
            onTap: onViewMyWorkTap,
          ),
          SizedBox(height: context.h(8)),
          _CoverActionButtons(
            downloadSelected: showDownloadCvSelected,
            contactSelected: showContactMeSelected,
            onDownloadCvTap: onDownloadCvTap,
            onContactMeTap: onContactMeTap,
          ),
        ],
      ),
    );
  }
}

class _CoverActionButtons extends StatelessWidget {
  final bool downloadSelected;
  final bool contactSelected;
  final VoidCallback onDownloadCvTap;
  final VoidCallback onContactMeTap;

  const _CoverActionButtons({
    required this.downloadSelected,
    required this.contactSelected,
    required this.onDownloadCvTap,
    required this.onContactMeTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SelectableOutlinePillButton(
            label: 'Download CV',
            isSelected: downloadSelected,
            onTap: onDownloadCvTap,
          ),
        ),
        SizedBox(width: context.w(8)),
        Expanded(
          child: _SelectableOutlinePillButton(
            label: 'Contact Me',
            isSelected: contactSelected,
            onTap: onContactMeTap,
          ),
        ),
      ],
    );
  }
}

class _SelectableFilledPillButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectableFilledPillButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  static const _basePath = 'assets/images/ai_protifilo';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final background = isSelected
        ? AppColors.lightBlue700
        : (isDark ? const Color(0xFF131A3B) : AppColors.grey50);
    final textColor = isSelected
        ? Colors.white
        : (isDark ? Colors.white : const Color(0xFF0F111D));
    final borderColor = isSelected
        ? AppColors.lightBlue700
        : (isDark ? const Color(0xFFB8BCC8) : AppColors.grey600);

    return SizedBox(
      width: double.infinity,
      height: context.h(32),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: textColor,
          side: BorderSide(
            color: borderColor,
            width: 1,
          ),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: context.w(16),
            vertical: context.h(8),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  fontSize: context.sp(13).clamp(12.0, 13.0),
                  color: textColor,
                ),
              ),
            ),
            Image.asset(
              '$_basePath/edit.png',
              width: context.w(16),
              height: context.w(16),
              color: textColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectableOutlinePillButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectableOutlinePillButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: context.h(32),
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: isSelected ? Colors.white : AppColors.lightBlue700,
          side: const BorderSide(
            color: AppColors.lightBlue700,
            width: 1,
          ),
          backgroundColor:
              isSelected ? AppColors.lightBlue700 : AppColors.grey50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: context.w(16),
            vertical: context.h(8),
          ),
        ),
        child: Center(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: context.sp(13).clamp(12.0, 13.0),
              color: isSelected ? Colors.white : AppColors.lightBlue700,
            ),
          ),
        ),
      ),
    );
  }
}

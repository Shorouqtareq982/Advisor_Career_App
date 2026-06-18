import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../providers/ai_portfolio_provider.dart';
import '../widgets/ai_portfolio_bottom_nav.dart';
import '../widgets/portfolio_adaptive_image.dart';

class AIPortfolioDesignsScreen extends ConsumerWidget {
  const AIPortfolioDesignsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(aiPortfolioProvider);
    final notifier = ref.read(aiPortfolioProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final previewData = notifier.buildTemplatePreviewData();

    return Scaffold(
      backgroundColor: isDark ? AppColors.blue900 : AppColors.textDark,
      bottomNavigationBar: AIPortfolioBottomNav(
        currentTab: PortfolioTab.designs,
        canNavigate: state.canNavigateTabs,
        canPreview: state.canPreview,
        onTap: (tab) {
          notifier.goToTab(tab);

          switch (tab) {
            case PortfolioTab.edit:
              context.go('/ai-portfolio');
              break;

            case PortfolioTab.designs:
              break;

            case PortfolioTab.preview:
              if (ref.read(aiPortfolioProvider).canPreview) {
                context.go('/ai-portfolio/preview');
              }
              break;

            case PortfolioTab.settings:
              if (ref.read(aiPortfolioProvider).canPreview) {
                context.go('/ai-portfolio/settings');
              }
              break;
          }
        },
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.w(16),
            vertical: context.h(10),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => context.go('/ai-portfolio'),
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      width: context.w(24),
                      height: context.w(24),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: context.w(18),
                        color: isDark ? AppColors.grey50 : AppColors.blue900,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Image.asset(
                    'assets/images/ai_protifilo/logo.png',
                    height: context.h(40),
                    fit: BoxFit.contain,
                  ),
                  const Spacer(),
                  SizedBox(width: context.w(24)),
                ],
              ),
              SizedBox(height: context.h(10)),
              Text(
                'Choose Your Portfolio Design',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: context.sp(19).clamp(18.0, 19.0),
                  color: isDark ? Colors.white : const Color(0xFF0F111D),
                ),
              ),
              SizedBox(height: context.h(8)),
              Text(
                'Pick a layout that fits your style and vision.\nYou can always change it later',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  fontSize: context.sp(14).clamp(13.0, 14.0),
                  height: 1.2,
                  color: isDark
                      ? const Color(0xFFCACACA)
                      : const Color(0xFF686868),
                ),
              ),
              SizedBox(height: context.h(16)),
              _TopNextButton(
                enabled: state.hasSelectedTemplate,
                onTap: state.hasSelectedTemplate
                    ? () {
                        notifier.onNext();
                        context.go('/ai-portfolio/preview');
                      }
                    : null,
              ),
              SizedBox(height: context.h(16)),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(bottom: context.h(20)),
                  child: Column(
                    children: [
                      _DesignCardShell(
                        title: _templateTitle(
                          state,
                          fallback: 'Design 1',
                          templateId: 1,
                        ),
                        description: _templateDescription(
                          state,
                          fallback: 'Personal Modern',
                          templateId: 1,
                        ),
                        selected: state.selectedTemplate ==
                            PortfolioTemplateType.design1,
                        onTap: () {
                          notifier
                              .selectTemplate(PortfolioTemplateType.design1);
                        },
                        preview: _DesignOneMiniPreview(
                          previewData: previewData,
                        ),
                      ),
                      SizedBox(height: context.h(16)),
                      _DesignCardShell(
                        title: _templateTitle(
                          state,
                          fallback: 'Design 2',
                          templateId: 2,
                        ),
                        description: _templateDescription(
                          state,
                          fallback: 'IPortfolio',
                          templateId: 2,
                        ),
                        selected: state.selectedTemplate ==
                            PortfolioTemplateType.design2,
                        onTap: () {
                          notifier
                              .selectTemplate(PortfolioTemplateType.design2);
                        },
                        preview: _DesignTwoMiniPreview(
                          previewData: previewData,
                        ),
                      ),
                      SizedBox(height: context.h(16)),
                      _DesignCardShell(
                        title: _templateTitle(
                          state,
                          fallback: 'Design 3',
                          templateId: 3,
                        ),
                        description: _templateDescription(
                          state,
                          fallback: 'Clean Minimalist',
                          templateId: 3,
                        ),
                        selected: state.selectedTemplate ==
                            PortfolioTemplateType.design3,
                        onTap: () {
                          notifier
                              .selectTemplate(PortfolioTemplateType.design3);
                        },
                        preview: _DesignThreeMiniPreview(
                          previewData: previewData,
                        ),
                      ),
                      SizedBox(height: context.h(16)),
                      _DesignCardShell(
                        title: _templateTitle(
                          state,
                          fallback: 'Design 4',
                          templateId: 4,
                        ),
                        description: _templateDescription(
                          state,
                          fallback: 'Creative Dark',
                          templateId: 4,
                        ),
                        selected: state.selectedTemplate ==
                            PortfolioTemplateType.design4,
                        onTap: () {
                          notifier
                              .selectTemplate(PortfolioTemplateType.design4);
                        },
                        preview: _DesignFourMiniPreview(
                          previewData: previewData,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _templateTitle(
    AIPortfolioState state, {
    required int templateId,
    required String fallback,
  }) {
    for (final template in state.templates) {
      if (template.id == templateId && template.name.trim().isNotEmpty) {
        return template.name;
      }
    }

    return fallback;
  }

  static String _templateDescription(
    AIPortfolioState state, {
    required int templateId,
    required String fallback,
  }) {
    for (final template in state.templates) {
      if (template.id == templateId && template.description.trim().isNotEmpty) {
        return template.description;
      }
    }

    return fallback;
  }
}

class _TopNextButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback? onTap;

  const _TopNextButton({
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: context.h(42),
      child: ElevatedButton(
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              enabled ? const Color(0xFF268299) : AppColors.grey200,
          foregroundColor: enabled ? Colors.white : AppColors.grey600,
          disabledBackgroundColor: AppColors.grey200,
          disabledForegroundColor: AppColors.grey600,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'Next',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: context.sp(14).clamp(13.0, 14.0),
            ),
          ),
        ),
      ),
    );
  }
}

class _DesignCardShell extends StatelessWidget {
  final String title;
  final String description;
  final bool selected;
  final VoidCallback? onTap;
  final Widget preview;

  const _DesignCardShell({
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
    required this.preview,
  });

  @override
  Widget build(BuildContext context) {
    final buttonLabel = selected ? 'Selected' : 'Use this design';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(context.r(10)),
        border: Border.all(
          color: selected ? const Color(0xFF268299) : const Color(0xFFD9D9D9),
          width: selected ? 1.3 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            offset: Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          preview,
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.w(12),
              context.h(12),
              context.w(12),
              context.h(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: context.sp(16).clamp(15.0, 16.0),
                    color: const Color(0xFF0F111D),
                  ),
                ),
                if (description.trim().isNotEmpty) ...[
                  SizedBox(height: context.h(5)),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                      fontSize: context.sp(11.5).clamp(10.5, 11.5),
                      height: 1.25,
                      color: const Color(0xFF686868),
                    ),
                  ),
                ],
                SizedBox(height: context.h(10)),
                SizedBox(
                  width: double.infinity,
                  height: context.h(40),
                  child: OutlinedButton(
                    onPressed: onTap,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: selected
                          ? const Color(0xFF268299)
                          : Colors.transparent,
                      foregroundColor:
                          selected ? Colors.white : const Color(0xFF268299),
                      side: const BorderSide(
                        color: Color(0xFF268299),
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        buttonLabel,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: context.sp(12.5).clamp(11.5, 12.5),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniProfile extends StatelessWidget {
  final String? imagePath;
  final double size;
  final BorderRadius borderRadius;
  final Color borderColor;

  const _MiniProfile({
    required this.imagePath,
    required this.size,
    required this.borderRadius,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: PortfolioAdaptiveImage(
        imagePath: imagePath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        borderRadius: borderRadius,
        placeholder: Container(
          width: size,
          height: size,
          color: Colors.white.withOpacity(0.16),
          alignment: Alignment.center,
          child: Icon(
            Icons.person,
            size: size * 0.42,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _MiniActionCapsule extends StatelessWidget {
  final String text;
  final Color background;
  final Color textColor;
  final Color? borderColor;

  const _MiniActionCapsule({
    required this.text,
    required this.background,
    required this.textColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.w(11),
        vertical: context.h(6.5),
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: borderColor == null
            ? null
            : Border.all(color: borderColor!, width: 1),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: context.sp(10.2).clamp(9.2, 10.2),
          color: textColor,
        ),
      ),
    );
  }
}

class _MiniLocationChip extends StatelessWidget {
  final String location;
  final Color textColor;
  final Color background;

  const _MiniLocationChip({
    required this.location,
    required this.textColor,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    if (location.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.w(9),
        vertical: context.h(5),
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.location_on_rounded,
            size: context.w(12),
            color: textColor,
          ),
          SizedBox(width: context.w(4)),
          Flexible(
            child: Text(
              location,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: context.sp(9.8).clamp(8.8, 9.8),
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniCoverBackground extends StatelessWidget {
  final String? imagePath;
  final BorderRadius borderRadius;
  final Widget fallback;
  final Widget child;
  final double overlayOpacity;

  const _MiniCoverBackground({
    required this.imagePath,
    required this.borderRadius,
    required this.fallback,
    required this.child,
    this.overlayOpacity = 0.22,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = (imagePath ?? '').trim().isNotEmpty;

    return ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        children: [
          Positioned.fill(child: fallback),
          if (hasImage)
            Positioned.fill(
              child: PortfolioAdaptiveImage(
                imagePath: imagePath,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                borderRadius: borderRadius,
                placeholder: const SizedBox.shrink(),
              ),
            ),
          Positioned.fill(
            child: Container(
              color: hasImage ? Colors.black.withOpacity(overlayOpacity) : null,
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _MiniNameTitleBlock extends StatelessWidget {
  final String fullName;
  final String title;
  final String statement;
  final Color nameColor;
  final Color titleColor;
  final Color bodyColor;
  final TextAlign textAlign;
  final CrossAxisAlignment crossAxisAlignment;
  final int statementLines;

  const _MiniNameTitleBlock({
    required this.fullName,
    required this.title,
    required this.statement,
    required this.nameColor,
    required this.titleColor,
    required this.bodyColor,
    required this.textAlign,
    required this.crossAxisAlignment,
    this.statementLines = 3,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Text(
          fullName,
          textAlign: textAlign,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: context.sp(13).clamp(12.0, 13.0),
            color: nameColor,
          ),
        ),
        SizedBox(height: context.h(4)),
        Text(
          title,
          textAlign: textAlign,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: context.sp(10.5).clamp(9.5, 10.5),
            color: titleColor,
          ),
        ),
        SizedBox(height: context.h(7)),
        Text(
          statement,
          textAlign: textAlign,
          maxLines: statementLines,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
            fontSize: context.sp(8.6).clamp(7.6, 8.6),
            height: 1.25,
            color: bodyColor,
          ),
        ),
      ],
    );
  }
}

class _MiniDualActions extends StatelessWidget {
  final Color primaryBg;
  final Color primaryText;
  final Color secondaryBg;
  final Color secondaryText;
  final Color? secondaryBorder;
  final WrapAlignment alignment;

  const _MiniDualActions({
    required this.primaryBg,
    required this.primaryText,
    required this.secondaryBg,
    required this.secondaryText,
    this.secondaryBorder,
    this.alignment = WrapAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: alignment,
      spacing: context.w(8),
      runSpacing: context.h(8),
      children: [
        _MiniActionCapsule(
          text: 'View My Work',
          background: primaryBg,
          textColor: primaryText,
        ),
        _MiniActionCapsule(
          text: 'Contact Me',
          background: secondaryBg,
          textColor: secondaryText,
          borderColor: secondaryBorder,
        ),
      ],
    );
  }
}

class _DesignOneMiniPreview extends StatelessWidget {
  final PortfolioTemplatePreviewData previewData;

  const _DesignOneMiniPreview({
    required this.previewData,
  });

  @override
  Widget build(BuildContext context) {
    return _MiniCoverBackground(
      imagePath: previewData.coverImagePath,
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(context.r(10)),
      ),
      fallback: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF8D2B8B),
              Color(0xFF8B5CF6),
            ],
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
          ),
        ),
      ),
      overlayOpacity: 0.20,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(context.w(14)),
        child: Column(
          children: [
            _MiniProfile(
              imagePath: previewData.profileImagePath,
              size: context.w(48),
              borderRadius: BorderRadius.circular(14),
              borderColor: Colors.white,
            ),
            SizedBox(height: context.h(8)),
            _MiniNameTitleBlock(
              fullName: previewData.fullName,
              title: previewData.professionalTitle,
              statement: previewData.shortValueStatement,
              nameColor: Colors.white,
              titleColor: const Color(0xFFF3E8FF),
              bodyColor: const Color(0xFFE9DBFF),
              textAlign: TextAlign.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              statementLines: 2,
            ),
            SizedBox(height: context.h(8)),
            _MiniLocationChip(
              location: previewData.location,
              textColor: Colors.white,
              background: Colors.white.withOpacity(0.18),
            ),
            SizedBox(height: context.h(10)),
            _MiniDualActions(
              alignment: WrapAlignment.center,
              primaryBg: Colors.white,
              primaryText: const Color(0xFF7C35D9),
              secondaryBg: const Color(0xFFB96AE7),
              secondaryText: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}

class _DesignTwoMiniPreview extends StatelessWidget {
  final PortfolioTemplatePreviewData previewData;

  const _DesignTwoMiniPreview({
    required this.previewData,
  });

  @override
  Widget build(BuildContext context) {
    return _MiniCoverBackground(
      imagePath: previewData.coverImagePath,
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(context.r(10)),
      ),
      fallback: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFF6EBDD),
              Color(0xFFE6D1BE),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      overlayOpacity: 0.08,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(context.w(14)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: context.w(10)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MiniNameTitleBlock(
                      fullName: previewData.fullName,
                      title: previewData.professionalTitle,
                      statement: previewData.shortValueStatement,
                      nameColor: const Color(0xFF2B1A12),
                      titleColor: const Color(0xFF8C3515),
                      bodyColor: const Color(0xFF5A463B),
                      textAlign: TextAlign.left,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      statementLines: 3,
                    ),
                    SizedBox(height: context.h(8)),
                    _MiniLocationChip(
                      location: previewData.location,
                      textColor: const Color(0xFF6A3A22),
                      background: Colors.white.withOpacity(0.68),
                    ),
                    SizedBox(height: context.h(10)),
                    _MiniDualActions(
                      primaryBg: const Color(0xFF8C3515),
                      primaryText: Colors.white,
                      secondaryBg: const Color(0xFFF3E1D5),
                      secondaryText: const Color(0xFF7B2F14),
                    ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: _MiniProfile(
                imagePath: previewData.profileImagePath,
                size: context.w(60),
                borderRadius: BorderRadius.circular(18),
                borderColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesignThreeMiniPreview extends StatelessWidget {
  final PortfolioTemplatePreviewData previewData;

  const _DesignThreeMiniPreview({
    required this.previewData,
  });

  @override
  Widget build(BuildContext context) {
    return _MiniCoverBackground(
      imagePath: previewData.coverImagePath,
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(context.r(10)),
      ),
      fallback: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0A2A33),
              Color(0xFF11626A),
              Color(0xFF071A20),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      overlayOpacity: 0.22,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(context.w(14)),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _MiniNameTitleBlock(
                    fullName: previewData.fullName,
                    title: previewData.professionalTitle,
                    statement: previewData.shortValueStatement,
                    nameColor: Colors.white,
                    titleColor: const Color(0xFFA9F0E7),
                    bodyColor: const Color(0xFFD8F5F1),
                    textAlign: TextAlign.left,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    statementLines: 2,
                  ),
                ),
                SizedBox(width: context.w(10)),
                _MiniProfile(
                  imagePath: previewData.profileImagePath,
                  size: context.w(54),
                  borderRadius: BorderRadius.circular(14),
                  borderColor: const Color(0xFFA9F0E7),
                ),
              ],
            ),
            SizedBox(height: context.h(8)),
            Align(
              alignment: Alignment.centerLeft,
              child: _MiniLocationChip(
                location: previewData.location,
                textColor: Colors.white,
                background: Colors.white.withOpacity(0.12),
              ),
            ),
            SizedBox(height: context.h(10)),
            _MiniDualActions(
              primaryBg: Colors.white,
              primaryText: const Color(0xFF0C1E25),
              secondaryBg: Colors.transparent,
              secondaryText: const Color(0xFFA9F0E7),
              secondaryBorder: const Color(0xFFA9F0E7),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesignFourMiniPreview extends StatelessWidget {
  final PortfolioTemplatePreviewData previewData;

  const _DesignFourMiniPreview({
    required this.previewData,
  });

  @override
  Widget build(BuildContext context) {
    return _MiniCoverBackground(
      imagePath: previewData.coverImagePath,
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(context.r(10)),
      ),
      fallback: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF1C1A19),
              Color(0xFF5B4632),
              Color(0xFFB28C66),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      overlayOpacity: 0.16,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(context.w(14)),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: context.w(10)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _MiniNameTitleBlock(
                          fullName: previewData.fullName,
                          title: previewData.professionalTitle,
                          statement: previewData.shortValueStatement,
                          nameColor: Colors.white,
                          titleColor: const Color(0xFFF1DDC4),
                          bodyColor: const Color(0xFFF6EFE7),
                          textAlign: TextAlign.left,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          statementLines: 2,
                        ),
                        SizedBox(height: context.h(8)),
                        _MiniLocationChip(
                          location: previewData.location,
                          textColor: Colors.white,
                          background: Colors.white.withOpacity(0.14),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(context.w(2)),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: const Color(0xFFCCB38B),
                  ),
                  child: _MiniProfile(
                    imagePath: previewData.profileImagePath,
                    size: context.w(58),
                    borderRadius: BorderRadius.circular(14),
                    borderColor: const Color(0xFFF1DDC4),
                  ),
                ),
              ],
            ),
            SizedBox(height: context.h(10)),
            _MiniDualActions(
              alignment: WrapAlignment.center,
              primaryBg: Colors.white,
              primaryText: const Color(0xFF4A3828),
              secondaryBg: const Color(0xFFD7B894),
              secondaryText: const Color(0xFF2C241D),
            ),
          ],
        ),
      ),
    );
  }
}

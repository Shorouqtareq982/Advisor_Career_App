import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../providers/ai_portfolio_provider.dart' as portfolio_provider;
import '../widgets/ai_portfolio_bottom_nav.dart' as bottom_nav_widget;
import '../widgets/ai_portfolio_header.dart' as header_widget;
import '../widgets/contact_section.dart';
import '../widgets/education_section.dart';
import '../widgets/portfolio_about_me_card.dart';
import '../widgets/portfolio_primary_button.dart' as primary_button_widget;
import '../widgets/portfolio_section_card.dart' as section_card_widget;
import '../widgets/professional_experience_section.dart';
import '../widgets/projects_section.dart';
import '../widgets/skills_section.dart';

enum _PortfolioSectionType {
  cover,
  aboutMe,
  professionalExperience,
  projects,
  skills,
  education,
  contact,
}

class AIPortfolioScreen extends ConsumerStatefulWidget {
  const AIPortfolioScreen({super.key});

  @override
  ConsumerState<AIPortfolioScreen> createState() => _AIPortfolioScreenState();
}

class _AIPortfolioScreenState extends ConsumerState<AIPortfolioScreen> {
  _PortfolioSectionType _selectedSection = _PortfolioSectionType.cover;

  final _coverKey = GlobalKey();
  final _aboutKey = GlobalKey();
  final _experienceKey = GlobalKey();
  final _projectsKey = GlobalKey();
  final _skillsKey = GlobalKey();
  final _educationKey = GlobalKey();
  final _contactKey = GlobalKey();

  Future<void> _scrollTo(GlobalKey key) async {
    final targetContext = key.currentContext;
    if (targetContext == null) return;

    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      alignment: 0.12,
    );
  }

  Future<void> _selectSection(
    _PortfolioSectionType section,
    portfolio_provider.AIPortfolioNotifier notifier,
  ) async {
    setState(() => _selectedSection = section);

    final state = ref.read(portfolio_provider.aiPortfolioProvider);

    if (section == _PortfolioSectionType.cover && !state.isCoverExpanded) {
      notifier.toggleCoverExpanded();
    }

    if (section == _PortfolioSectionType.professionalExperience &&
        !state.isProfessionalExperienceExpanded) {
      notifier.toggleProfessionalExperienceExpanded();
    }

    if (section == _PortfolioSectionType.projects &&
        !state.isProjectsExpanded) {
      notifier.toggleProjectsExpanded();
    }

    if (section == _PortfolioSectionType.skills && !state.isSkillsExpanded) {
      notifier.toggleSkillsExpanded();
    }

    if (section == _PortfolioSectionType.education &&
        !state.isEducationExpanded) {
      notifier.toggleEducationExpanded();
    }

    if (section == _PortfolioSectionType.contact && !state.isContactExpanded) {
      notifier.toggleContactExpanded();
    }

    await Future.delayed(const Duration(milliseconds: 50));

    switch (section) {
      case _PortfolioSectionType.cover:
        await _scrollTo(_coverKey);
        break;
      case _PortfolioSectionType.aboutMe:
        await _scrollTo(_aboutKey);
        break;
      case _PortfolioSectionType.professionalExperience:
        await _scrollTo(_experienceKey);
        break;
      case _PortfolioSectionType.projects:
        await _scrollTo(_projectsKey);
        break;
      case _PortfolioSectionType.skills:
        await _scrollTo(_skillsKey);
        break;
      case _PortfolioSectionType.education:
        await _scrollTo(_educationKey);
        break;
      case _PortfolioSectionType.contact:
        await _scrollTo(_contactKey);
        break;
    }
  }

  Future<void> _showSectionsMenu(
    BuildContext context,
    TapDownDetails details,
    portfolio_provider.AIPortfolioNotifier notifier,
  ) async {
    final selected = await showMenu<_PortfolioSectionType>(
      context: context,
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx - context.w(220),
        details.globalPosition.dy + context.h(10),
        details.globalPosition.dx,
        0,
      ),
      color: AppColors.grey100,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.r(16)),
        side: const BorderSide(
          color: AppColors.lightBlue700,
          width: 1,
        ),
      ),
      items: const [
        PopupMenuItem(
          value: _PortfolioSectionType.cover,
          child: _SectionMenuItemText('Cover'),
        ),
        PopupMenuItem(
          value: _PortfolioSectionType.aboutMe,
          child: _SectionMenuItemText('About Me'),
        ),
        PopupMenuItem(
          value: _PortfolioSectionType.professionalExperience,
          child: _SectionMenuItemText('Professional Experience'),
        ),
        PopupMenuItem(
          value: _PortfolioSectionType.projects,
          child: _SectionMenuItemText('Projects'),
        ),
        PopupMenuItem(
          value: _PortfolioSectionType.skills,
          child: _SectionMenuItemText('Skills & Expertise'),
        ),
        PopupMenuItem(
          value: _PortfolioSectionType.education,
          child: _SectionMenuItemText('Education'),
        ),
        PopupMenuItem(
          value: _PortfolioSectionType.contact,
          child: _SectionMenuItemText('Contact'),
        ),
      ],
    );

    if (selected != null) {
      await _selectSection(selected, notifier);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(portfolio_provider.aiPortfolioProvider);
    final notifier = ref.read(portfolio_provider.aiPortfolioProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.blue900 : AppColors.textDark,
      bottomNavigationBar: bottom_nav_widget.AIPortfolioBottomNav(
        currentTab: state.currentTab,
        canNavigate: state.canNavigateTabs,
        canPreview: state.canPreview,
        onTap: (tab) {
          notifier.goToTab(tab);
          switch (tab) {
            case portfolio_provider.PortfolioTab.edit:
              context.go('/ai-portfolio');
              break;
            case portfolio_provider.PortfolioTab.designs:
              context.go('/ai-portfolio/designs');
              break;
            case portfolio_provider.PortfolioTab.preview:
              context.go('/ai-portfolio/preview');
              break;
            case portfolio_provider.PortfolioTab.settings:
              context.go('/ai-portfolio/settings');
              break;
          }
        },
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.w(16),
                    vertical: context.h(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      header_widget.AIPortfolioHeader(
                        onBack: () => context.go('/home'),
                        onMenuTap: (details) =>
                            _showSectionsMenu(context, details, notifier),
                      ),
                      SizedBox(height: context.h(18)),
                      primary_button_widget.PortfolioPrimaryButton(
                        label: 'Next',
                        enabled: state.canGoNext,
                        onTap: state.canGoNext
                            ? () {
                                notifier.onNext();
                                context.go('/ai-portfolio/designs');
                              }
                            : null,
                      ),
                      SizedBox(height: context.h(18)),
                      Container(
                        key: _coverKey,
                        child: section_card_widget.PortfolioSectionCard.cover(
                          isExpanded: state.isCoverExpanded,
                          isSelected:
                              _selectedSection == _PortfolioSectionType.cover,
                          fullName: state.portfolio.cover.fullName,
                          professionalTitle:
                              state.portfolio.cover.professionalTitle,
                          shortValueStatement:
                              state.portfolio.cover.shortValueStatement,
                          location: state.portfolio.cover.location,
                          profileImagePath:
                              state.portfolio.cover.profileImagePath,
                          profileImageName:
                              state.portfolio.cover.profileImageName,
                          resumeFileName: state.portfolio.cover.resumeFileName,
                          showViewMyWorkSelected: state.showViewMyWorkButton,
                          showDownloadCvSelected: state.showDownloadCvButton,
                          showContactMeSelected: state.showContactMeButton,
                          onFullNameChanged: notifier.updateFullName,
                          onProfessionalTitleChanged:
                              notifier.updateProfessionalTitle,
                          onShortValueStatementChanged:
                              notifier.updateShortValueStatement,
                          onLocationChanged: notifier.updateLocation,
                          onArrowTap: () async {
                            setState(() {
                              _selectedSection = _PortfolioSectionType.cover;
                            });

                            notifier.toggleCoverExpanded();

                            await Future.delayed(
                              const Duration(milliseconds: 50),
                            );
                            await _scrollTo(_coverKey);
                          },
                          onProfileUpload: notifier.pickProfileImage,
                          onResumeUpload: notifier.pickResumeFile,
                          onRemoveProfileImage: notifier.removeProfileImage,
                          onRemoveResumeFile: notifier.removeResumeFile,
                          onViewMyWorkTap: () => notifier.setViewMyWorkEnabled(
                            !state.showViewMyWorkButton,
                          ),
                          onDownloadCvTap: () => notifier.setDownloadCvEnabled(
                            !state.showDownloadCvButton,
                          ),
                          onContactMeTap: () => notifier.setContactMeEnabled(
                            !state.showContactMeButton,
                          ),
                        ),
                      ),
                      SizedBox(height: context.h(16)),
                      Container(
                        key: _aboutKey,
                        child: PortfolioAboutMeCard(
                          initiallyExpanded:
                              _selectedSection == _PortfolioSectionType.aboutMe,
                          isSelected:
                              _selectedSection == _PortfolioSectionType.aboutMe,
                          onSelected: () async {
                            setState(() {
                              _selectedSection = _PortfolioSectionType.aboutMe;
                            });
                            await _scrollTo(_aboutKey);
                          },
                        ),
                      ),
                      SizedBox(height: context.h(16)),
                      Container(
                        key: _experienceKey,
                        child: ProfessionalExperienceSection(
                          isSelected: _selectedSection ==
                              _PortfolioSectionType.professionalExperience,
                          onSelected: () async {
                            setState(() {
                              _selectedSection =
                                  _PortfolioSectionType.professionalExperience;
                            });
                            await _scrollTo(_experienceKey);
                          },
                        ),
                      ),
                      SizedBox(height: context.h(16)),
                      Container(
                        key: _projectsKey,
                        child: ProjectsSection(
                          isSelected: _selectedSection ==
                              _PortfolioSectionType.projects,
                          onSelected: () async {
                            setState(() {
                              _selectedSection = _PortfolioSectionType.projects;
                            });
                            await _scrollTo(_projectsKey);
                          },
                        ),
                      ),
                      SizedBox(height: context.h(16)),
                      Container(
                        key: _skillsKey,
                        child: SkillsSection(
                          initiallyExpanded:
                              _selectedSection == _PortfolioSectionType.skills,
                          isSelected:
                              _selectedSection == _PortfolioSectionType.skills,
                          onSelected: () async {
                            setState(() {
                              _selectedSection = _PortfolioSectionType.skills;
                            });
                            await _scrollTo(_skillsKey);
                          },
                        ),
                      ),
                      SizedBox(height: context.h(16)),
                      Container(
                        key: _educationKey,
                        child: EducationSection(
                          initiallyExpanded: _selectedSection ==
                              _PortfolioSectionType.education,
                          isSelected: _selectedSection ==
                              _PortfolioSectionType.education,
                          onSelected: () async {
                            setState(() {
                              _selectedSection =
                                  _PortfolioSectionType.education;
                            });
                            await _scrollTo(_educationKey);
                          },
                        ),
                      ),
                      SizedBox(height: context.h(16)),
                      Container(
                        key: _contactKey,
                        child: ContactSection(
                          initiallyExpanded:
                              _selectedSection == _PortfolioSectionType.contact,
                          isSelected:
                              _selectedSection == _PortfolioSectionType.contact,
                          onSelected: () async {
                            setState(() {
                              _selectedSection = _PortfolioSectionType.contact;
                            });
                            await _scrollTo(_contactKey);
                          },
                        ),
                      ),
                      SizedBox(height: context.h(14)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SectionMenuItemText extends StatelessWidget {
  final String title;

  const _SectionMenuItemText(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: context.sp(14).clamp(13.0, 14.0),
        fontWeight: FontWeight.w500,
        color: AppColors.blue900,
      ),
    );
  }
}

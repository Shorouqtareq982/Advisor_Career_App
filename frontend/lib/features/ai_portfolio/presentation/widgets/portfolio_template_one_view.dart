import 'package:flutter/material.dart';

import '../../../../core/extensions/responsive_extension.dart';
import '../../domain/entities/portfolio_skill_entity.dart';
import '../providers/ai_portfolio_provider.dart';
import 'portfolio_adaptive_image.dart';

class PortfolioTemplateOneView extends StatelessWidget {
  final PortfolioTemplatePreviewData previewData;
  final GlobalKey aboutKey;
  final GlobalKey skillsKey;
  final GlobalKey experienceKey;
  final GlobalKey projectsKey;
  final GlobalKey educationKey;
  final GlobalKey contactKey;
  final VoidCallback onViewMyWorkTap;
  final VoidCallback onContactMeTap;
  final VoidCallback onDownloadCvTap;

  const PortfolioTemplateOneView({
    super.key,
    required this.previewData,
    required this.aboutKey,
    required this.skillsKey,
    required this.experienceKey,
    required this.projectsKey,
    required this.educationKey,
    required this.contactKey,
    required this.onViewMyWorkTap,
    required this.onContactMeTap,
    required this.onDownloadCvTap,
  });

  @override
  Widget build(BuildContext context) {
    final validExperience = previewData.professionalExperienceEntries
        .where(
          (e) =>
              e.jobTitle.trim().isNotEmpty || e.companyName.trim().isNotEmpty,
        )
        .toList();

    final validProjects = previewData.projectEntries
        .where(
          (e) =>
              e.title.trim().isNotEmpty ||
              e.shortDescription.trim().isNotEmpty ||
              (e.coverImagePath ?? '').trim().isNotEmpty,
        )
        .toList();

    final validEducation = previewData.educationEntries
        .where(
          (e) =>
              e.institutionName.trim().isNotEmpty || e.degree.trim().isNotEmpty,
        )
        .toList();

    final validSkills =
        previewData.skills.where((e) => e.skillName.trim().isNotEmpty).toList();

    final showContactSection = previewData.contactEmail.trim().isNotEmpty ||
        previewData.contactPhoneNumber.trim().isNotEmpty ||
        previewData.contactLocation.trim().isNotEmpty ||
        _resolveSupportedSocials(previewData).isNotEmpty;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(context.r(20)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          _DesignOneHeader(
            previewData: previewData,
            onViewMyWorkTap: onViewMyWorkTap,
            onContactMeTap: onContactMeTap,
            onDownloadCvTap: onDownloadCvTap,
          ),
          Padding(
            padding: EdgeInsets.all(context.w(12)),
            child: Column(
              children: [
                _DesignOneCard(
                  key: aboutKey,
                  title: 'About Me',
                  child: _DesignOneAboutBody(previewData: previewData),
                ),
                if (validSkills.isNotEmpty) ...[
                  SizedBox(height: context.h(12)),
                  _DesignOneCard(
                    key: skillsKey,
                    title: 'Skills & Expertise',
                    child: _DesignOneSkillsBody(skills: validSkills),
                  ),
                ],
                if (validExperience.isNotEmpty) ...[
                  SizedBox(height: context.h(12)),
                  _DesignOneCard(
                    key: experienceKey,
                    title: 'Professional Experience',
                    child: Column(
                      children: List.generate(validExperience.length, (index) {
                        final entry = validExperience[index];
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index == validExperience.length - 1
                                ? 0
                                : context.h(10),
                          ),
                          child: _DesignOneTimelineCard(
                            title: entry.jobTitle,
                            subtitle: entry.companyName,
                            location: entry.location,
                            dateText: _dateRangeText(
                              startMonth: entry.startMonth,
                              startYear: entry.startYear,
                              endMonth: entry.endMonth,
                              endYear: entry.endYear,
                              isCurrent: entry.currentlyWorkingHere,
                            ),
                            description: entry.description,
                          ),
                        );
                      }),
                    ),
                  ),
                ],
                if (validProjects.isNotEmpty) ...[
                  SizedBox(height: context.h(12)),
                  _DesignOneCard(
                    key: projectsKey,
                    title: 'Projects',
                    child: Column(
                      children: List.generate(validProjects.length, (index) {
                        final project = validProjects[index];
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index == validProjects.length - 1
                                ? 0
                                : context.h(10),
                          ),
                          child: _DesignOneProjectCard(project: project),
                        );
                      }),
                    ),
                  ),
                ],
                if (validEducation.isNotEmpty) ...[
                  SizedBox(height: context.h(12)),
                  _DesignOneCard(
                    key: educationKey,
                    title: 'Education',
                    child: Column(
                      children: List.generate(validEducation.length, (index) {
                        final edu = validEducation[index];
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index == validEducation.length - 1
                                ? 0
                                : context.h(10),
                          ),
                          child: _DesignOneTimelineCard(
                            title: edu.institutionName,
                            subtitle:
                                '${edu.degree}${edu.fieldOfStudy.trim().isNotEmpty ? ' • ${edu.fieldOfStudy}' : ''}',
                            location: edu.location,
                            dateText: _dateRangeText(
                              startMonth: edu.startMonth,
                              startYear: edu.startYear,
                              endMonth: edu.endMonth,
                              endYear: edu.endYear,
                              isCurrent: edu.currentlyStudying,
                            ),
                            description: edu.description,
                          ),
                        );
                      }),
                    ),
                  ),
                ],
                if (showContactSection) ...[
                  SizedBox(height: context.h(12)),
                  _DesignOneContactSection(
                    key: contactKey,
                    previewData: previewData,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _dateRangeText({
    String? startMonth,
    String? startYear,
    String? endMonth,
    String? endYear,
    required bool isCurrent,
  }) {
    final start = [
      if ((startMonth ?? '').trim().isNotEmpty) startMonth,
      if ((startYear ?? '').trim().isNotEmpty) startYear,
    ].join(' ');

    final end = isCurrent
        ? 'Present'
        : [
            if ((endMonth ?? '').trim().isNotEmpty) endMonth,
            if ((endYear ?? '').trim().isNotEmpty) endYear,
          ].join(' ');

    if (start.isEmpty && end.isEmpty) return '';
    if (start.isEmpty) return end;
    if (end.isEmpty) return start;
    return '$start - $end';
  }
}

class _DesignOneHeader extends StatelessWidget {
  final PortfolioTemplatePreviewData previewData;
  final VoidCallback onViewMyWorkTap;
  final VoidCallback onContactMeTap;
  final VoidCallback onDownloadCvTap;

  const _DesignOneHeader({
    required this.previewData,
    required this.onViewMyWorkTap,
    required this.onContactMeTap,
    required this.onDownloadCvTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageSize = context.w(88);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        context.w(18),
        context.h(18),
        context.w(18),
        context.h(18),
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF8F30BA),
            Color(0xFF7B3FE4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(context.r(20)),
        ),
      ),
      child: Column(
        children: [
          _DesignOneProfileImage(
            imagePath: previewData.profileImagePath,
            size: imageSize,
          ),
          SizedBox(height: context.h(12)),
          Text(
            previewData.fullName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: context.sp(20).clamp(18.0, 20.0),
              color: Colors.white,
            ),
          ),
          SizedBox(height: context.h(4)),
          Text(
            previewData.professionalTitle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: context.sp(13.5).clamp(12.5, 13.5),
              color: const Color(0xFFF7EAFE),
            ),
          ),
          SizedBox(height: context.h(10)),
          Text(
            previewData.shortValueStatement,
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
              fontSize: context.sp(11.2).clamp(10.2, 11.2),
              height: 1.35,
              color: const Color(0xFFF2E8FF),
            ),
          ),
          if (previewData.location.trim().isNotEmpty) ...[
            SizedBox(height: context.h(10)),
            _DesignOneLocationChip(location: previewData.location),
          ],
          SizedBox(height: context.h(14)),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: context.w(8),
            runSpacing: context.h(8),
            children: [
              if (previewData.showViewMyWork)
                _DesignOneActionButton(
                  label: 'View My Work',
                  background: Colors.white,
                  foreground: const Color(0xFF7C35D9),
                  onTap: onViewMyWorkTap,
                ),
              if (previewData.showContactMe)
                _DesignOneActionButton(
                  label: 'Contact Me',
                  background: const Color(0xFFB96AE7),
                  foreground: Colors.white,
                  onTap: onContactMeTap,
                ),
              if (previewData.showDownloadCv)
                _DesignOneActionButton(
                  label: 'Download CV',
                  background: const Color(0xFF170B2B),
                  foreground: Colors.white,
                  onTap: onDownloadCvTap,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DesignOneLocationChip extends StatelessWidget {
  final String location;

  const _DesignOneLocationChip({
    required this.location,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.w(10),
        vertical: context.h(5),
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.location_on_rounded,
            size: context.w(14),
            color: Colors.white,
          ),
          SizedBox(width: context.w(4)),
          Flexible(
            child: Text(
              location,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: context.sp(10.5).clamp(9.5, 10.5),
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DesignOneProfileImage extends StatelessWidget {
  final String? imagePath;
  final double size;

  const _DesignOneProfileImage({
    required this.imagePath,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: PortfolioAdaptiveImage(
        imagePath: imagePath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        borderRadius: BorderRadius.circular(18),
        placeholder: Container(
          color: Colors.white.withOpacity(0.16),
          alignment: Alignment.center,
          child: Icon(
            Icons.person,
            color: Colors.white,
            size: size * 0.42,
          ),
        ),
      ),
    );
  }
}

class _DesignOneActionButton extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  const _DesignOneActionButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.w(14),
            vertical: context.h(8),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: context.sp(11).clamp(10.0, 11.0),
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }
}

class _DesignOneCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _DesignOneCard({
    super.key,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.w(14)),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(context.r(16)),
        border: Border.all(color: const Color(0xFFD9D9D9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x13000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
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
              color: const Color(0xFF8E33C2),
            ),
          ),
          SizedBox(height: context.h(12)),
          child,
        ],
      ),
    );
  }
}

class _DesignOneAboutBody extends StatelessWidget {
  final PortfolioTemplatePreviewData previewData;

  const _DesignOneAboutBody({
    required this.previewData,
  });

  @override
  Widget build(BuildContext context) {
    final strengths =
        previewData.coreStrengths.where((e) => e.trim().isNotEmpty).toList();
    final focus =
        previewData.careerFocus.where((e) => e.trim().isNotEmpty).toList();
    final industries = previewData.industriesWorkedIn
        .where((e) => e.trim().isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          previewData.aboutSummary,
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
            fontSize: context.sp(12).clamp(11.0, 12.0),
            height: 1.45,
            color: const Color(0xFF2D2D2D),
          ),
        ),
        if (previewData.yearsOfExperience > 0) ...[
          SizedBox(height: context.h(10)),
          _DesignOneChip(
            text: 'Experience: ${previewData.yearsOfExperience} years',
          ),
        ],
        if (strengths.isNotEmpty) ...[
          SizedBox(height: context.h(12)),
          _DesignOneSectionLabel(label: 'Core Strengths:'),
          SizedBox(height: context.h(8)),
          Wrap(
            spacing: context.w(8),
            runSpacing: context.h(8),
            children: strengths.map((e) => _DesignOneChip(text: e)).toList(),
          ),
        ],
        if (focus.isNotEmpty || industries.isNotEmpty) ...[
          SizedBox(height: context.h(12)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (focus.isNotEmpty)
                Expanded(
                  child: _DesignOneBulletGroup(
                    title: 'Career Focus:',
                    items: focus,
                  ),
                ),
              if (focus.isNotEmpty && industries.isNotEmpty)
                SizedBox(width: context.w(16)),
              if (industries.isNotEmpty)
                Expanded(
                  child: _DesignOneBulletGroup(
                    title: 'Industries:',
                    items: industries,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _DesignOneSectionLabel extends StatelessWidget {
  final String label;

  const _DesignOneSectionLabel({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w700,
        fontSize: context.sp(11.3).clamp(10.3, 11.3),
        color: const Color(0xFF3C3C3C),
      ),
    );
  }
}

class _DesignOneBulletGroup extends StatelessWidget {
  final String title;
  final List<String> items;

  const _DesignOneBulletGroup({
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DesignOneSectionLabel(label: title),
        SizedBox(height: context.h(6)),
        ...items.map(
          (item) => Padding(
            padding: EdgeInsets.only(bottom: context.h(4)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: context.h(5)),
                  child: Container(
                    width: context.w(5),
                    height: context.w(5),
                    decoration: const BoxDecoration(
                      color: Color(0xFF8E33C2),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                SizedBox(width: context.w(8)),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                      fontSize: context.sp(11).clamp(10.0, 11.0),
                      color: const Color(0xFF2D2D2D),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DesignOneSkillsBody extends StatelessWidget {
  final List<PortfolioSkillEntity> skills;

  const _DesignOneSkillsBody({
    required this.skills,
  });

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<PortfolioSkillEntity>>{};
    for (final skill in skills) {
      final key =
          skill.category.trim().isEmpty ? 'General' : skill.category.trim();
      grouped.putIfAbsent(key, () => []).add(skill);
    }

    final categoryOrder = grouped.keys.toList();

    return Column(
      children: List.generate(categoryOrder.length, (categoryIndex) {
        final category = categoryOrder[categoryIndex];
        final categorySkills = grouped[category]!;
        return Padding(
          padding: EdgeInsets.only(
            bottom:
                categoryIndex == categoryOrder.length - 1 ? 0 : context.h(12),
          ),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(context.w(12)),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F1F1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD9D9D9)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: context.sp(13).clamp(12.0, 13.0),
                    color: const Color(0xFFB03BBA),
                  ),
                ),
                SizedBox(height: context.h(10)),
                ...List.generate(categorySkills.length, (index) {
                  final skill = categorySkills[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == categorySkills.length - 1
                          ? 0
                          : context.h(10),
                    ),
                    child: _DesignOneSkillRow(skill: skill),
                  );
                }),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _DesignOneSkillRow extends StatelessWidget {
  final PortfolioSkillEntity skill;

  const _DesignOneSkillRow({
    required this.skill,
  });

  @override
  Widget build(BuildContext context) {
    final progress = _skillProgress(skill.proficiency);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                skill.skillName,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  fontSize: context.sp(11.5).clamp(10.5, 11.5),
                  color: const Color(0xFF2C2C2C),
                ),
              ),
            ),
            SizedBox(width: context.w(8)),
            Text(
              skill.proficiency.trim().isEmpty ? '—' : skill.proficiency,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                fontSize: context.sp(11).clamp(10.0, 11.0),
                color: const Color(0xFF2C2C2C),
              ),
            ),
          ],
        ),
        SizedBox(height: context.h(6)),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: context.h(5),
            backgroundColor: const Color(0xFFE3D8EE),
            valueColor: const AlwaysStoppedAnimation(Color(0xFF8E33C2)),
          ),
        ),
      ],
    );
  }
}

class _DesignOneChip extends StatelessWidget {
  final String text;

  const _DesignOneChip({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.w(12),
        vertical: context.h(6),
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF1E6FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: context.sp(10.5).clamp(9.5, 10.5),
          color: const Color(0xFF7B33B1),
        ),
      ),
    );
  }
}

class _DesignOneTimelineCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String location;
  final String dateText;
  final String description;

  const _DesignOneTimelineCard({
    required this.title,
    required this.subtitle,
    required this.location,
    required this.dateText,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.w(12)),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F1F1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD9D9D9)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: context.w(4),
            constraints: BoxConstraints(minHeight: context.h(78)),
            decoration: BoxDecoration(
              color: const Color(0xFF8E33C2),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          SizedBox(width: context.w(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.trim().isNotEmpty)
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: context.sp(13).clamp(12.0, 13.0),
                      color: const Color(0xFF2D2D2D),
                    ),
                  ),
                if (subtitle.trim().isNotEmpty) ...[
                  SizedBox(height: context.h(4)),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: context.sp(11).clamp(10.0, 11.0),
                      color: const Color(0xFF7B33B1),
                    ),
                  ),
                ],
                if (location.trim().isNotEmpty) ...[
                  SizedBox(height: context.h(4)),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: context.w(13),
                        color: const Color(0xFF6A6470),
                      ),
                      SizedBox(width: context.w(4)),
                      Expanded(
                        child: Text(
                          location,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                            fontSize: context.sp(10.5).clamp(9.5, 10.5),
                            color: const Color(0xFF6A6470),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (dateText.trim().isNotEmpty) ...[
                  SizedBox(height: context.h(4)),
                  Text(
                    dateText,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                      fontSize: context.sp(10.5).clamp(9.5, 10.5),
                      color: const Color(0xFF6A6470),
                    ),
                  ),
                ],
                if (description.trim().isNotEmpty) ...[
                  SizedBox(height: context.h(6)),
                  Text(
                    description,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      fontSize: context.sp(11).clamp(10.0, 11.0),
                      height: 1.35,
                      color: const Color(0xFF3A3840),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DesignOneProjectCard extends StatelessWidget {
  final ProjectEntryModel project;

  const _DesignOneProjectCard({
    required this.project,
  });

  @override
  Widget build(BuildContext context) {
    final outcomes = _parseOutcomeBullets(project.keyOutcomes);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.w(12)),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F1F1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD9D9D9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((project.coverImagePath ?? '').trim().isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: PortfolioAdaptiveImage(
                imagePath: project.coverImagePath,
                width: double.infinity,
                height: context.h(160),
                fit: BoxFit.cover,
                borderRadius: BorderRadius.circular(12),
                placeholder: Container(
                  height: context.h(160),
                  color: const Color(0xFFEADDF9),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.image_outlined,
                    size: context.w(28),
                    color: const Color(0xFF8E33C2),
                  ),
                ),
              ),
            ),
            SizedBox(height: context.h(10)),
          ],
          if (project.title.trim().isNotEmpty)
            Text(
              project.title,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: context.sp(13).clamp(12.0, 13.0),
                color: const Color(0xFF8E33C2),
              ),
            ),
          if (project.category.trim().isNotEmpty) ...[
            SizedBox(height: context.h(4)),
            Text(
              project.category,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                fontSize: context.sp(11).clamp(10.0, 11.0),
                color: const Color(0xFF5E5E5E),
              ),
            ),
          ],
          if (project.shortDescription.trim().isNotEmpty) ...[
            SizedBox(height: context.h(8)),
            Text(
              project.shortDescription,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
                fontSize: context.sp(11).clamp(10.0, 11.0),
                height: 1.35,
                color: const Color(0xFF3A3840),
              ),
            ),
          ],
          if (project.tools.isNotEmpty) ...[
            SizedBox(height: context.h(10)),
            _DesignOneSectionLabel(label: 'Tools:'),
            SizedBox(height: context.h(8)),
            Wrap(
              spacing: context.w(8),
              runSpacing: context.h(8),
              children: project.tools
                  .where((tool) => tool.trim().isNotEmpty)
                  .map((tool) => _DesignOneChip(text: tool))
                  .toList(),
            ),
          ],
          if (outcomes.isNotEmpty) ...[
            SizedBox(height: context.h(10)),
            _DesignOneSectionLabel(label: 'Results:'),
            SizedBox(height: context.h(6)),
            ...outcomes.map(
              (item) => Padding(
                padding: EdgeInsets.only(bottom: context.h(4)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: context.h(5)),
                      child: Container(
                        width: context.w(5),
                        height: context.w(5),
                        decoration: const BoxDecoration(
                          color: Color(0xFF8E33C2),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    SizedBox(width: context.w(8)),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                          fontSize: context.sp(11).clamp(10.0, 11.0),
                          color: const Color(0xFF3A3840),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DesignOneContactSection extends StatelessWidget {
  final PortfolioTemplatePreviewData previewData;

  const _DesignOneContactSection({
    super.key,
    required this.previewData,
  });

  @override
  Widget build(BuildContext context) {
    final socials = _resolveSupportedSocials(previewData);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.w(16)),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF8F30BA),
            Color(0xFF7B3FE4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(context.r(16)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Contact Me',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: context.sp(16).clamp(15.0, 16.0),
              color: Colors.white,
            ),
          ),
          SizedBox(height: context.h(14)),
          if (previewData.contactEmail.trim().isNotEmpty)
            _DesignOneContactPill(
              icon: Icons.email_outlined,
              text: previewData.contactEmail,
            ),
          if (previewData.contactPhoneNumber.trim().isNotEmpty) ...[
            SizedBox(height: context.h(8)),
            _DesignOneContactPill(
              icon: Icons.phone_outlined,
              text:
                  '${previewData.contactPhoneCode} ${previewData.contactPhoneNumber}',
            ),
          ],
          if (previewData.contactLocation.trim().isNotEmpty) ...[
            SizedBox(height: context.h(8)),
            _DesignOneContactPill(
              icon: Icons.location_on_outlined,
              text: previewData.contactLocation,
            ),
          ],
          if (socials.isNotEmpty) ...[
            SizedBox(height: context.h(14)),
            Text(
              'Find me online',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: context.sp(12).clamp(11.0, 12.0),
                color: Colors.white,
              ),
            ),
            SizedBox(height: context.h(10)),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: context.w(8),
              runSpacing: context.h(8),
              children: socials
                  .map(
                    (social) => Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.w(12),
                        vertical: context.h(8),
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        social.label,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: context.sp(10.5).clamp(9.5, 10.5),
                          color: const Color(0xFF7B33B1),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _DesignOneContactPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DesignOneContactPill({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: context.w(12),
        vertical: context.h(10),
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: context.w(16)),
          SizedBox(width: context.w(8)),
          Expanded(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                fontSize: context.sp(11).clamp(10.0, 11.0),
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportedSocial {
  final String label;

  const _SupportedSocial(this.label);
}

List<_SupportedSocial> _resolveSupportedSocials(
  PortfolioTemplatePreviewData previewData,
) {
  final links = previewData.contactLinks
      .where((e) => e.trim().isNotEmpty)
      .map((e) => e.toLowerCase())
      .toList();

  bool hasLinkedIn = false;
  bool hasGitHub = false;
  bool hasWhatsApp = previewData.contactPhoneNumber.trim().isNotEmpty;

  for (final link in links) {
    if (link.contains('linkedin')) hasLinkedIn = true;
    if (link.contains('github')) hasGitHub = true;
    if (link.contains('whatsapp') ||
        link.contains('wa.me') ||
        link.contains('whats app')) {
      hasWhatsApp = true;
    }

    if (link.trim() == 'linkedin') hasLinkedIn = true;
    if (link.trim() == 'github') hasGitHub = true;
    if (link.trim() == 'whatsapp') hasWhatsApp = true;
  }

  final result = <_SupportedSocial>[];
  if (hasLinkedIn) result.add(const _SupportedSocial('LinkedIn'));
  if (hasGitHub) result.add(const _SupportedSocial('GitHub'));
  if (hasWhatsApp) result.add(const _SupportedSocial('WhatsApp'));
  return result;
}

List<String> _parseOutcomeBullets(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return [];

  final normalized = trimmed
      .replaceAll('•', '\n')
      .replaceAll('●', '\n')
      .replaceAll('▪', '\n')
      .replaceAll('‣', '\n');

  final lines = normalized
      .split('\n')
      .map((e) => e.replaceFirst(RegExp(r'^\s*[-*]+\s*'), '').trim())
      .where((e) => e.isNotEmpty)
      .toList();

  if (lines.length > 1) return lines;
  return [trimmed];
}

double _skillProgress(String proficiency) {
  switch (proficiency.trim().toLowerCase()) {
    case 'beginner':
      return 0.35;
    case 'intermediate':
      return 0.55;
    case 'advanced':
      return 0.78;
    case 'expert':
      return 1.0;
    default:
      return 0.45;
  }
}

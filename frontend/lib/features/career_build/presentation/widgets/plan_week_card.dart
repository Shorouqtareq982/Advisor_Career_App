import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../providers/career_build_provider.dart';

class PlanWeekCard extends StatelessWidget {
  final PlanWeekUiModel week;

  const PlanWeekCard({super.key, required this.week});

  Future<void> _openResource(BuildContext context, String url) async {
    final uri = Uri.tryParse(url.trim());

    if (uri == null || !uri.hasScheme) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid resource link')),
      );
      return;
    }

    final ok = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the resource link')),
      );
    }
  }

  List<CourseLinkUiModel> _resolvedResources() {
    if (week.courseLinks.isNotEmpty) return week.courseLinks;

    final legacy = (week.courseUrl ?? '').trim();
    if (legacy.isNotEmpty) {
      return [
        CourseLinkUiModel(
          id: 'legacy-course-link',
          title: 'Go to Course',
          url: legacy,
          providerKey: 'external',
          type: 'external',
        ),
      ];
    }

    return const [];
  }

  IconData _resourceIcon(String type) {
    switch (type.toLowerCase().trim()) {
      case 'youtube':
        return Icons.play_circle_fill_rounded;
      case 'docs':
      case 'documentation':
        return Icons.description_rounded;
      case 'practice':
      case 'exercise':
      case 'exercises':
        return Icons.fitness_center_rounded;
      case 'project':
      case 'github':
        return Icons.folder_copy_rounded;
      case 'article':
      case 'blog':
        return Icons.article_rounded;
      default:
        return Icons.link_rounded;
    }
  }

  String _resourceTypeLabel(String type) {
    final value = type.trim();
    if (value.isEmpty) return 'Resource';

    return value
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  String _durationText(CourseLinkUiModel link) {
    if (link.type.toLowerCase() == 'youtube' &&
        link.youtubeDurationMinutes != null &&
        link.youtubeDurationMinutes! > 0) {
      return '${link.youtubeDurationMinutes} min';
    }

    return link.duration.trim();
  }

  @override
  Widget build(BuildContext context) {
    const figmaTeal = Color(0xFF268299);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resources = _resolvedResources();

    final cardBg = isDark ? const Color(0xFF111A38) : AppColors.grey50;
    final cardBorder =
        isDark ? const Color(0xFF2A8AA2).withOpacity(0.25) : Colors.transparent;
    final titleColor = isDark ? AppColors.grey50 : AppColors.blue900;
    final labelColor = isDark ? AppColors.grey200 : AppColors.blue900;
    final bodyColor = isDark ? AppColors.grey300 : AppColors.grey800;
    final subColor = isDark ? AppColors.grey400 : AppColors.grey700;
    final dotColor = isDark ? AppColors.grey50 : AppColors.blue900;

    final focusSkills = week.focusSkills.isNotEmpty
        ? week.focusSkills
        : week.skillTag
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

    final outcomes = week.learningOutcomes.isNotEmpty
        ? week.learningOutcomes
        : week.focusPoints;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.w(16)),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(context.r(16)),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color:
                isDark ? Colors.black.withOpacity(0.18) : AppColors.lightshadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Week ${week.weekNumber}',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: context.sp(12).clamp(11.0, 13.0),
              fontWeight: FontWeight.w800,
              color: figmaTeal,
            ),
          ),
          SizedBox(height: context.h(4)),
          Text(
            week.topic.trim().isNotEmpty ? week.topic : week.title,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: context.sp(19).clamp(17.0, 20.0),
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: titleColor,
            ),
          ),
          SizedBox(height: context.h(10)),
          Text(
            week.description.trim().isNotEmpty ? week.description : week.goal,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: context.sp(13).clamp(12.0, 14.0),
              fontWeight: FontWeight.w500,
              height: 1.35,
              color: bodyColor,
            ),
          ),
          if (focusSkills.isNotEmpty) ...[
            SizedBox(height: context.h(12)),
            _SectionTitle(title: 'Focus Skills', color: labelColor),
            SizedBox(height: context.h(8)),
            Wrap(
              spacing: context.w(8),
              runSpacing: context.h(8),
              children: focusSkills.map((skill) {
                return _Pill(text: skill, isDark: isDark);
              }).toList(),
            ),
          ],
          if (outcomes.isNotEmpty) ...[
            SizedBox(height: context.h(14)),
            _SectionTitle(title: 'Learning Outcomes', color: labelColor),
            SizedBox(height: context.h(8)),
            ...outcomes.map(
              (item) => _BulletLine(
                text: item,
                dotColor: dotColor,
                textColor: bodyColor,
              ),
            ),
          ],
          if (week.whatToStudy.isNotEmpty) ...[
            SizedBox(height: context.h(14)),
            _SectionTitle(title: 'What to Study', color: labelColor),
            SizedBox(height: context.h(8)),
            ...week.whatToStudy.map(
              (item) => _BulletLine(
                text: item,
                dotColor: figmaTeal,
                textColor: bodyColor,
              ),
            ),
          ],
          if (week.howToStudy.isNotEmpty) ...[
            SizedBox(height: context.h(14)),
            _SectionTitle(title: 'How to Study', color: labelColor),
            SizedBox(height: context.h(8)),
            ...week.howToStudy.map(
              (item) => _BulletLine(
                text: item,
                dotColor: figmaTeal,
                textColor: bodyColor,
              ),
            ),
          ],
          if (week.timeSplit.isNotEmpty) ...[
            SizedBox(height: context.h(14)),
            _SectionTitle(title: 'Time Split', color: labelColor),
            SizedBox(height: context.h(8)),
            Wrap(
              spacing: context.w(8),
              runSpacing: context.h(8),
              children: week.timeSplit.entries.map((entry) {
                return _Pill(
                  text:
                      '${_prettyText(entry.key.toString())}: ${entry.value.toString()}',
                  isDark: isDark,
                );
              }).toList(),
            ),
          ],
          if (resources.isNotEmpty) ...[
            SizedBox(height: context.h(16)),
            _SectionTitle(title: 'Resources', color: labelColor),
            SizedBox(height: context.h(10)),
            ...resources.map(
              (resource) => Padding(
                padding: EdgeInsets.only(bottom: context.h(10)),
                child: _ResourceCard(
                  resource: resource,
                  icon: _resourceIcon(resource.type),
                  typeLabel: _resourceTypeLabel(resource.type),
                  duration: _durationText(resource),
                  isDark: isDark,
                  onTap: () => _openResource(context, resource.url),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResourceCard extends StatelessWidget {
  final CourseLinkUiModel resource;
  final IconData icon;
  final String typeLabel;
  final String duration;
  final bool isDark;
  final VoidCallback onTap;

  const _ResourceCard({
    required this.resource,
    required this.icon,
    required this.typeLabel,
    required this.duration,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const figmaTeal = Color(0xFF268299);

    final bg = isDark ? const Color(0xFF0B132D) : Colors.white;
    final border =
        isDark ? const Color(0xFF2A8AA2).withOpacity(0.25) : AppColors.grey300;
    final titleColor = isDark ? AppColors.grey50 : AppColors.blue900;
    final bodyColor = isDark ? AppColors.grey400 : AppColors.grey700;

    return InkWell(
      onTap: resource.url.trim().isEmpty ? null : onTap,
      borderRadius: BorderRadius.circular(context.r(14)),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(context.w(12)),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(context.r(14)),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: context.w(34),
                  height: context.w(34),
                  decoration: BoxDecoration(
                    color: figmaTeal.withOpacity(isDark ? 0.18 : 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: context.icon(18),
                    color: figmaTeal,
                  ),
                ),
                SizedBox(width: context.w(10)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resource.title.trim().isEmpty
                            ? 'Untitled Resource'
                            : resource.title,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: context.sp(13).clamp(12.0, 14.0),
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                          color: titleColor,
                        ),
                      ),
                      SizedBox(height: context.h(6)),
                      Wrap(
                        spacing: context.w(8),
                        runSpacing: context.h(6),
                        children: [
                          _MiniTag(
                            text: typeLabel,
                            isDark: isDark,
                          ),
                          if (duration.trim().isNotEmpty)
                            _MiniTag(
                              text: duration,
                              isDark: isDark,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.open_in_new_rounded,
                  size: context.icon(17),
                  color: figmaTeal,
                ),
              ],
            ),
            if (resource.snippet.trim().isNotEmpty) ...[
              SizedBox(height: context.h(10)),
              Text(
                resource.snippet,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: context.sp(12).clamp(11.0, 13.0),
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                  color: bodyColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Color color;

  const _SectionTitle({
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: context.sp(13).clamp(12.0, 14.0),
        fontWeight: FontWeight.w800,
        height: 1.2,
        color: color,
      ),
    );
  }
}

class _BulletLine extends StatelessWidget {
  final String text;
  final Color dotColor;
  final Color textColor;

  const _BulletLine({
    required this.text,
    required this.dotColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(bottom: context.h(7)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: context.h(6)),
            child: Container(
              width: context.w(6),
              height: context.w(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor,
              ),
            ),
          ),
          SizedBox(width: context.w(8)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: context.sp(13).clamp(12.0, 14.0),
                fontWeight: FontWeight.w500,
                height: 1.35,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final bool isDark;

  const _Pill({
    required this.text,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    const figmaTeal = Color(0xFF268299);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.w(10),
        vertical: context.h(6),
      ),
      decoration: BoxDecoration(
        color: figmaTeal.withOpacity(isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: figmaTeal.withOpacity(0.30)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: context.sp(11).clamp(10.0, 12.0),
          fontWeight: FontWeight.w800,
          color: isDark ? AppColors.grey50 : AppColors.blue900,
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String text;
  final bool isDark;

  const _MiniTag({
    required this.text,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.w(8),
        vertical: context.h(5),
      ),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.grey50.withOpacity(0.08)
            : AppColors.grey200.withOpacity(0.75),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: context.sp(10).clamp(9.0, 11.0),
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.grey300 : AppColors.grey800,
        ),
      ),
    );
  }
}

String _prettyText(String raw) {
  final s = raw.replaceAll('_', ' ').trim();
  if (s.isEmpty) return raw;

  return s
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

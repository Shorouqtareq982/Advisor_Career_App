import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../../../../core/theme/app_text_theme.dart';
import '../../domain/entities/job_entity.dart';

class JobCard extends StatelessWidget {
  final JobEntity job;
  final VoidCallback onViewDetails;
  final VoidCallback onToggleSave;

  const JobCard({
    super.key,
    required this.job,
    required this.onViewDetails,
    required this.onToggleSave,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = context.appTextTheme;

    final cardBg = isDark ? AppColors.blue700 : AppColors.grey50;
    final cardBorder = isDark ? AppColors.blue400 : AppColors.grey200;
    final textPrimary = isDark ? AppColors.grey50 : AppColors.blue900;
    final textMuted = isDark ? AppColors.grey400 : AppColors.grey700;
    final accentColor =
        isDark ? AppColors.lightBlue500 : AppColors.lightBlue700;

    return Container(
      margin: EdgeInsets.only(bottom: context.h(12)),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(context.r(12)),
        border: Border.all(color: cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? AppColors.blue900.withOpacity(0.4)
                : AppColors.grey300.withOpacity(0.4),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(context.w(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (job.rank != null) ...[
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: context.w(7),
                                vertical: context.h(3),
                              ),
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.15),
                                borderRadius:
                                    BorderRadius.circular(context.r(6)),
                              ),
                              child: Text(
                                '#${job.rank}',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: context.sp(11),
                                  fontWeight: FontWeight.w700,
                                  color: accentColor,
                                ),
                              ),
                            ),
                            SizedBox(width: context.w(6)),
                          ],
                          Expanded(
                            child: Text(
                              job.title,
                              style: textTheme.title2Bold
                                  .copyWith(color: textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: context.h(4)),
                      Text(
                        job.company,
                        style: textTheme.bodyRegular.copyWith(color: textMuted),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: context.w(8)),
                GestureDetector(
                  onTap: onToggleSave,
                  child: Container(
                    width: context.w(36),
                    height: context.w(36),
                    decoration: BoxDecoration(
                      color: job.isSaved
                          ? accentColor
                          : (isDark ? AppColors.blue500 : AppColors.grey200),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      job.isSaved ? Icons.bookmark : Icons.bookmark_border,
                      color: job.isSaved
                          ? (isDark ? AppColors.blue900 : AppColors.grey50)
                          : textMuted,
                      size: context.icon(18),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: context.h(10)),
            if (job.matchScore != null) ...[
              _MatchScoreBar(
                score: job.matchScore!,
                isDark: isDark,
                accentColor: accentColor,
                textMuted: textMuted,
              ),
              SizedBox(height: context.h(10)),
            ],
            _InfoRow(
                icon: Icons.location_on_outlined,
                text: job.location,
                textMuted: textMuted),
            SizedBox(height: context.h(4)),
            _InfoRow(
                icon: Icons.work_outline,
                text: '${job.workLocation} • ${job.workType}',
                textMuted: textMuted),
            if (job.explanation != null && job.explanation!.isNotEmpty) ...[
              SizedBox(height: context.h(10)),
              _ExplanationSection(
                text: job.explanation!,
                accentColor: accentColor,
                textMuted: textMuted,
              ),
            ],
            SizedBox(height: context.h(12)),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onViewDetails,
                    child: Container(
                      height: context.h(40),
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(context.r(50)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'View Details',
                        style: textTheme.bodyBold.copyWith(
                          color: isDark ? AppColors.blue900 : AppColors.grey50,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: context.w(8)),
                GestureDetector(
                  onTap: () async {
                    if (job.jobUrl != null) {
                      final uri = Uri.tryParse(job.jobUrl!);
                      if (uri != null && await canLaunchUrl(uri)) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    }
                  },
                  child: Container(
                    width: context.w(40),
                    height: context.h(40),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(context.r(50)),
                    ),
                    child: Icon(
                      Icons.open_in_new,
                      color: isDark ? AppColors.blue900 : AppColors.grey50,
                      size: context.icon(18),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Match Score Bar ──────────────────────────────────────────────────────────
class _MatchScoreBar extends StatelessWidget {
  final double score;
  final bool isDark;
  final Color accentColor;
  final Color textMuted;

  const _MatchScoreBar({
    required this.score,
    required this.isDark,
    required this.accentColor,
    required this.textMuted,
  });

  Color get _barColor {
    if (score >= 70) return AppColors.green500;
    if (score >= 45) return AppColors.orange400;
    return AppColors.red400;
  }

  @override
  Widget build(BuildContext context) {
    final pct = score.clamp(0.0, 100.0);
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(context.r(4)),
            child: LinearProgressIndicator(
              value: pct / 100,
              minHeight: context.h(6),
              backgroundColor: isDark
                  ? AppColors.blue500.withOpacity(0.4)
                  : AppColors.grey200,
              valueColor: AlwaysStoppedAnimation<Color>(_barColor),
            ),
          ),
        ),
        SizedBox(width: context.w(8)),
        Text(
          '${pct.round()}% match',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: context.sp(12),
            fontWeight: FontWeight.w600,
            color: _barColor,
          ),
        ),
      ],
    );
  }
}

// ─── Info Row ─────────────────────────────────────────────────────────────────
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
        Text(
          text,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: context.sp(13),
            color: textMuted,
          ),
        ),
      ],
    );
  }
}

// ─── Explanation Section (with See more / See less) ───────────────────────────
class _ExplanationSection extends StatefulWidget {
  final String text;
  final Color accentColor;
  final Color textMuted;

  const _ExplanationSection({
    required this.text,
    required this.accentColor,
    required this.textMuted,
  });

  @override
  State<_ExplanationSection> createState() => _ExplanationSectionState();
}

class _ExplanationSectionState extends State<_ExplanationSection> {
  bool _expanded = false;

  bool _isOverflowing(double maxWidth, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: widget.text, style: style),
      maxLines: 3,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    return tp.didExceedMaxLines;
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      fontFamily: 'Inter',
      fontSize: context.sp(12),
      color: widget.textMuted,
      height: 1.4,
    );

    final iconSpace = context.icon(14) + context.w(6);

    return Container(
      padding: EdgeInsets.all(context.w(10)),
      decoration: BoxDecoration(
        color: widget.accentColor.withOpacity(0.07),
        borderRadius: BorderRadius.circular(context.r(8)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textMaxWidth = constraints.maxWidth - iconSpace;
          final canExpand =
              !_expanded && _isOverflowing(textMaxWidth, textStyle);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.auto_awesome,
                      size: context.icon(14), color: widget.accentColor),
                  SizedBox(width: context.w(6)),
                  Expanded(
                    child: Text(
                      widget.text,
                      style: textStyle,
                      maxLines: _expanded ? null : 3,
                      overflow: _expanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (canExpand || _expanded)
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Padding(
                    padding:
                        EdgeInsets.only(top: context.h(4), left: iconSpace),
                    child: Text(
                      _expanded ? 'See less' : 'See more',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: context.sp(12),
                        fontWeight: FontWeight.w600,
                        color: widget.accentColor,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

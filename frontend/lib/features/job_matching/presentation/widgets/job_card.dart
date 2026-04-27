// lib/features/job_matching/presentation/widgets/job_card.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../../../../core/theme/app_text_theme.dart';
import '../../domain/entities/job_entity.dart';
import 'job_rating_widget.dart';

class JobCard extends StatelessWidget {
  final JobEntity job;
  final VoidCallback onViewDetails;
  final VoidCallback onToggleSave;
  final ValueChanged<int> onRate;
  final bool showRating; // only in recommended tab

  const JobCard({
    super.key,
    required this.job,
    required this.onViewDetails,
    required this.onToggleSave,
    required this.onRate,
    this.showRating = true,
  });

  String _formatPostedAt(DateTime postedAt) {
    final diff = DateTime.now().difference(postedAt);
    if (diff.inMinutes < 60) return 'Posted ${diff.inMinutes} min ago';
    if (diff.inHours < 24)
      return 'Posted ${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    if (diff.inDays == 1) return 'Posted 1 day ago';
    if (diff.inDays < 30) return 'Posted ${diff.inDays} days ago';
    return 'Posted on ${postedAt.day}/${postedAt.month}/${postedAt.year}';
  }

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
            // ── Header row ──────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title + "New" badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              job.title,
                              style: textTheme.title2Bold
                                  .copyWith(color: textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (job.isNew) ...[
                            SizedBox(width: context.w(8)),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: context.w(8),
                                vertical: context.h(3),
                              ),
                              decoration: BoxDecoration(
                                color: accentColor,
                                borderRadius:
                                    BorderRadius.circular(context.r(4)),
                              ),
                              child: Text(
                                'New',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: context.sp(11),
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppColors.blue900
                                      : AppColors.grey50,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: context.h(4)),
                      // Company
                      Text(
                        job.company,
                        style: textTheme.bodyRegular.copyWith(color: textMuted),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: context.w(8)),
                // Bookmark icon
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

            // ── Info rows ────────────────────────────────────────────────────
            _InfoRow(
              icon: Icons.location_on_outlined,
              text: job.location,
              isDark: isDark,
              textMuted: textMuted,
            ),
            SizedBox(height: context.h(4)),
            _InfoRow(
              icon: Icons.work_outline,
              text: '${job.workLocation} • ${job.workType}',
              isDark: isDark,
              textMuted: textMuted,
            ),
            SizedBox(height: context.h(4)),
            _InfoRow(
              icon: Icons.calendar_today_outlined,
              text: _formatPostedAt(job.postedAt),
              isDark: isDark,
              textMuted: textMuted,
            ),

            SizedBox(height: context.h(12)),

            // ── Action buttons ───────────────────────────────────────────────
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
                // External link button
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

            // ── Rating section (recommended only) ────────────────────────────
            if (showRating) ...[
              SizedBox(height: context.h(12)),
              Text(
                'Rate this job recommendation',
                style: textTheme.bodyRegular.copyWith(color: textMuted),
              ),
              SizedBox(height: context.h(8)),
              JobRatingWidget(
                selectedRating: job.userRating,
                onRatingSelected: onRate,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isDark;
  final Color textMuted;

  const _InfoRow({
    required this.icon,
    required this.text,
    required this.isDark,
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

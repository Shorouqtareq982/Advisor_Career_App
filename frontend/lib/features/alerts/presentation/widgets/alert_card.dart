import 'package:flutter/material.dart';
import 'package:growza/core/constants/app_colors.dart';
import '../../domain/entities/alert_entity.dart';
import 'new_badge.dart';

class AlertCard extends StatelessWidget {
  final AlertEntity alert;
  final VoidCallback onTap;

  const AlertCard({super.key, required this.alert, required this.onTap});

  String _iconAsset(AlertType type) {
    switch (type) {
      case AlertType.resume:
        return 'assets/images/alerts/resume.jpg';
      case AlertType.jobs:
        return 'assets/images/alerts/job_matching.jpg';
      case AlertType.interview:
        return 'assets/images/alerts/interview.jpg';
      case AlertType.plan:
        return 'assets/images/alerts/plan.jpg';
    }
  }

  String _timeText(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
  }

  @override
  Widget build(BuildContext context) {
    final isNew = !alert.isRead;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardAdaptive(context),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, 4),
              blurRadius: 6,
              color: isDark ? const Color(0x22000000) : const Color(0x20000000),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon Container
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.lightBlue700.withOpacity(isDark ? 0.18 : 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  _iconAsset(alert.type),
                  width: 24,
                  height: 24,
                  fit: BoxFit.cover,
                ),
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          alert.title,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimaryAdaptive(context),
                            height: 1.2,
                          ),
                        ),
                      ),
                      if (isNew) const NewBadge(),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    alert.body,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textMutedAdaptive(context),
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(
                            width: 1,
                            color: isDark
                                ? AppColors.green50
                                : const Color(0xFF4F4F4F),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.calendar_today_outlined,
                          size: 10,
                          color: isDark
                              ? AppColors.grey50
                              : const Color(0xFF4F4F4F),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _timeText(alert.createdAt),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: isDark
                              ? AppColors.grey50
                              : const Color(0xFF4F4F4F),
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

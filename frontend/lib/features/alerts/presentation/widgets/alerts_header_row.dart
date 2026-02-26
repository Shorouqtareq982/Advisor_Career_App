import 'package:flutter/material.dart';
import 'package:growza/core/constants/app_colors.dart';
import 'package:growza/core/extensions/responsive_extension.dart';

class AlertsHeaderRow extends StatelessWidget {
  final int unreadCount;
  final VoidCallback? onMarkAllRead;

  const AlertsHeaderRow({
    super.key,
    required this.unreadCount,
    required this.onMarkAllRead,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = unreadCount == 0 || onMarkAllRead == null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$unreadCount unread Alerts',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: context.sp(16),
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimaryAdaptive(context),
            height: 1.2,
          ),
        ),
        InkWell(
          onTap: disabled ? null : onMarkAllRead,
          borderRadius: BorderRadius.circular(context.r(50)),
          child: Opacity(
            opacity: disabled ? 0.35 : 1,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: context.w(16),
                vertical: context.h(6),
              ),
              decoration: BoxDecoration(
                color: AppColors.lightBlue700,
                borderRadius: BorderRadius.circular(context.r(50)),
              ),
              child: Text(
                'Mark all read',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: context.sp(13),
                  fontWeight: FontWeight.w700,
                  color: AppColors.grey50,
                  height: 1.2,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

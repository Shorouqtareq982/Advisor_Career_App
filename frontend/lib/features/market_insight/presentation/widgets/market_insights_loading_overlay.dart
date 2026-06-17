import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';

class MarketInsightsLoadingOverlay extends StatelessWidget {
  final String text;

  const MarketInsightsLoadingOverlay({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AbsorbPointer(
        child: Container(
          color: Colors.black.withOpacity(0.22),
          alignment: Alignment.center,
          child: _LoadingCard(text: text),
        ),
      ),
    );
  }
}

class _LoadingCard extends StatefulWidget {
  final String text;

  const _LoadingCard({
    required this.text,
  });

  @override
  State<_LoadingCard> createState() => _LoadingCardState();
}

class _LoadingCardState extends State<_LoadingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: context.w(228),
      padding: EdgeInsets.symmetric(
        horizontal: context.w(20),
        vertical: context.h(18),
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.blue700 : AppColors.grey50,
        borderRadius: BorderRadius.circular(context.r(16)),
        border: Border.all(
          color: isDark
              ? AppColors.grey300.withOpacity(0.3)
              : AppColors.grey800.withOpacity(0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? AppColors.blue200.withOpacity(0.25)
                : AppColors.lightshadow,
            blurRadius: context.r(8),
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RotationTransition(
            turns: _controller,
            child: Icon(
              Icons.refresh_rounded,
              color: isDark ? AppColors.lightBlue500 : AppColors.lightBlue700,
              size: context.icon(34),
            ),
          ),
          SizedBox(height: context.h(12)),
          Text(
            widget.text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? AppColors.grey100 : AppColors.blue900,
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

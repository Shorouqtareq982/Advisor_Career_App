import 'package:flutter/material.dart';
import '../../core/theme/app_card_theme.dart';

class AppCard extends StatelessWidget {
  final Widget child;

  const AppCard({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cardTheme = Theme.of(context).extension<AppCardTheme>()!;

    return Container(
      decoration: BoxDecoration(
        color: cardTheme.backgroundColor,
        borderRadius: BorderRadius.circular(cardTheme.borderRadius),
        border: Border.all(
          color: cardTheme.borderColor,
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: cardTheme.shadowColor,
            offset: cardTheme.offset,
            blurRadius: cardTheme.blurRadius,
            spreadRadius: cardTheme.spreadRadius,
          ),
        ],
      ),
      child: child,
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../../../../core/theme/app_text_theme.dart';
import '../providers/market_insights_provider.dart';

class MarketInsightsSearchSection extends StatelessWidget {
  final MarketInsightsState state;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSuggestionTap;
  final VoidCallback onViewInsights;

  const MarketInsightsSearchSection({
    super.key,
    required this.state,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSuggestionTap,
    required this.onViewInsights,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 343),
        child: Column(
          children: [
            const _SearchIntro(),
            SizedBox(height: context.h(16)),
            _SearchField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: state.showSuggestions
                  ? Padding(
                      key: const ValueKey('suggestions'),
                      padding: EdgeInsets.only(top: context.h(10)),
                      child: _SuggestionsCard(
                        state: state,
                        onTap: onSuggestionTap,
                      ),
                    )
                  : const SizedBox.shrink(
                      key: ValueKey('no-suggestions'),
                    ),
            ),
            SizedBox(height: context.h(16)),
            _ViewInsightsButton(
              enabled: state.query.trim().isNotEmpty && !state.isBusy,
              onTap: onViewInsights,
            ),
            SizedBox(height: context.h(70)),
            const _EmptyState(),
          ],
        ),
      ),
    );
  }
}

class _SearchIntro extends StatelessWidget {
  const _SearchIntro();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = context.appTextTheme;

    return SizedBox(
      width: double.infinity,
      child: Column(
        children: [
          Text(
            'Market Insights',
            textAlign: TextAlign.center,
            style: context.responsiveText(
              textTheme.title1Bold.copyWith(
                color: isDark ? AppColors.grey100 : AppColors.blue900,
                fontSize: 19,
              ),
            ),
          ),
          SizedBox(height: context.h(12)),
          Text(
            'Choose a career track or type a job title to explore market demand.',
            textAlign: TextAlign.center,
            style: context.responsiveText(
              textTheme.title2Medium.copyWith(
                color: isDark ? AppColors.blue200 : AppColors.grey800,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => focusNode.requestFocus(),
      child: AnimatedBuilder(
        animation: focusNode,
        builder: (context, _) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: double.infinity,
            height: context.h(48),
            decoration: BoxDecoration(
              color: isDark ? AppColors.blue700 : AppColors.grey50,
              borderRadius: BorderRadius.circular(context.r(8)),
              border: Border.all(
                color: focusNode.hasFocus
                    ? (isDark ? AppColors.lightBlue500 : AppColors.lightBlue700)
                    : (isDark
                        ? AppColors.blue200.withOpacity(0.45)
                        : AppColors.grey600),
              ),
              boxShadow: focusNode.hasFocus
                  ? [
                      BoxShadow(
                        color: (isDark
                                ? AppColors.lightBlue500
                                : AppColors.lightBlue700)
                            .withOpacity(0.10),
                        blurRadius: context.r(12),
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            padding: EdgeInsets.fromLTRB(
              context.w(12),
              context.h(4),
              context.w(12),
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Track / Job Title',
                  style: TextStyle(
                    color: isDark ? AppColors.grey100 : AppColors.blue900,
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onChanged: onChanged,
                      style: TextStyle(
                        color: isDark ? AppColors.grey100 : AppColors.blue900,
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        hintText: 'e.g. Frontend Development, AI Engineering',
                        hintStyle: TextStyle(
                          color: isDark ? AppColors.blue200 : AppColors.grey600,
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SuggestionsCard extends StatelessWidget {
  final MarketInsightsState state;
  final ValueChanged<String> onTap;

  const _SuggestionsCard({
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final suggestions = state.filteredSuggestions;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget child;

    if (state.isLoadingJobs) {
      child = _SuggestionMessage(
        icon: Icons.sync_rounded,
        text: 'Loading tracks...',
        isDark: isDark,
      );
    } else if (state.jobs.isEmpty) {
      child = _SuggestionMessage(
        icon: Icons.wifi_off_rounded,
        text: 'Couldn’t load tracks. You can still type any job title.',
        isDark: isDark,
      );
    } else if (suggestions.isEmpty && state.query.trim().isNotEmpty) {
      child = _SuggestionMessage(
        icon: Icons.search_off_rounded,
        text: 'No matching track found. You can still use your own job title.',
        isDark: isDark,
      );
    } else if (suggestions.isEmpty) {
      child = _SuggestionMessage(
        icon: Icons.work_outline_rounded,
        text: 'Start typing to search available tracks.',
        isDark: isDark,
      );
    } else {
      child = Column(
        children: suggestions
            .take(10)
            .map(
              (item) => InkWell(
                onTap: () => onTap(item),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: context.w(16),
                    vertical: context.h(14),
                  ),
                  child: Text(
                    item,
                    style: TextStyle(
                      color: isDark ? AppColors.grey100 : AppColors.blue900,
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      );
    }

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: context.h(280),
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.blue700 : AppColors.grey50,
        borderRadius: BorderRadius.circular(context.r(8)),
        border: Border.all(
          color: isDark ? AppColors.lightBlue500 : AppColors.lightBlue700,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? AppColors.blue200.withOpacity(0.25)
                : AppColors.lightshadow,
            offset: const Offset(4, 4),
            blurRadius: context.r(4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: child,
      ),
    );
  }
}

class _SuggestionMessage extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isDark;

  const _SuggestionMessage({
    required this.icon,
    required this.text,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.w(16),
        vertical: context.h(18),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: isDark ? AppColors.lightBlue500 : AppColors.lightBlue700,
            size: context.icon(20),
          ),
          SizedBox(width: context.w(10)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isDark ? AppColors.grey100 : AppColors.blue900,
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewInsightsButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _ViewInsightsButton({
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = enabled
        ? (isDark ? AppColors.lightBlue500 : AppColors.lightBlue700)
        : (isDark ? AppColors.blue400 : AppColors.grey200);

    final fg = enabled
        ? (isDark ? AppColors.blue700 : AppColors.grey50)
        : (isDark ? AppColors.blue100 : AppColors.grey500);

    return SizedBox(
      width: double.infinity,
      height: context.h(48),
      child: ElevatedButton(
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: bg,
          disabledBackgroundColor: bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(context.r(50)),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: context.w(24),
            vertical: context.h(8),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ColorFiltered(
              colorFilter: ColorFilter.mode(fg, BlendMode.srcIn),
              child: Image.asset(
                'assets/images/market_insights/job_title.png',
                width: context.icon(20),
                height: context.icon(20),
              ),
            ),
            SizedBox(width: context.w(8)),
            Text(
              'View Insights',
              style: TextStyle(
                color: fg,
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Column(
        children: [
          Container(
            width: context.w(76),
            height: context.h(76),
            decoration: const BoxDecoration(
              color: AppColors.lightBlue100,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Image.asset(
              'assets/images/market_insights/search.png',
              width: context.w(48),
              height: context.h(49),
            ),
          ),
          SizedBox(height: context.h(24)),
          Text(
            'Select a track or type a job title to start exploring market insights.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? AppColors.grey100 : AppColors.blue900,
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

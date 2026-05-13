import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../providers/market_insights_provider.dart';
import '../widgets/market_bottom_nav.dart';
import '../widgets/market_insights_header.dart';
import '../widgets/market_insights_loading_overlay.dart';
import '../widgets/market_insights_results_section.dart';
import '../widgets/market_insights_search_section.dart';

class MarketInsightsScreen extends ConsumerStatefulWidget {
  const MarketInsightsScreen({super.key});

  @override
  ConsumerState<MarketInsightsScreen> createState() =>
      _MarketInsightsScreenState();
}

class _MarketInsightsScreenState extends ConsumerState<MarketInsightsScreen> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  String? _lastShownError;

  @override
  void initState() {
    super.initState();

    debugPrint('✅ ENTERED MARKET INSIGHTS SCREEN');

    ref.read(marketInsightsProvider.notifier).resetForEntry();

    _controller = TextEditingController();
    _focusNode = FocusNode();

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        ref.read(marketInsightsProvider.notifier).showSuggestions();
      } else {
        Future.delayed(const Duration(milliseconds: 120), () {
          if (!mounted) return;
          ref.read(marketInsightsProvider.notifier).hideSuggestions();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<MarketInsightsState>(marketInsightsProvider, (previous, next) {
      final error = next.errorMessage;

      if (error == null || error.trim().isEmpty) return;
      if (_lastShownError == error) return;

      _lastShownError = error;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });

    final state = ref.watch(marketInsightsProvider);
    final notifier = ref.read(marketInsightsProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_controller.text != state.query) {
      _controller.value = _controller.value.copyWith(
        text: state.query,
        selection: TextSelection.collapsed(offset: state.query.length),
        composing: TextRange.empty,
      );
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: isDark ? AppColors.blue900 : AppColors.textDark,
        bottomNavigationBar: const MarketBottomNav(),
        body: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: context.w(16),
                  vertical: context.h(12),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: context.contentConstraints,
                    child: Column(
                      children: [
                        MarketInsightsHeader(
                          onBack: () => context.go('/home'),
                        ),
                        SizedBox(height: context.h(18)),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          child: state.hasData
                              ? MarketInsightsResultsSection(
                                  key: const ValueKey('results'),
                                  data: state.data!,
                                  animationSeed: state.animationSeed,
                                  onChangeRole: notifier.changeRole,
                                  onRefresh: notifier.refresh,
                                )
                              : MarketInsightsSearchSection(
                                  key: const ValueKey('search'),
                                  state: state,
                                  controller: _controller,
                                  focusNode: _focusNode,
                                  onChanged: notifier.setQuery,
                                  onSuggestionTap: (value) {
                                    notifier.selectSuggestion(value);
                                    _focusNode.unfocus();
                                  },
                                  onViewInsights: () {
                                    _focusNode.unfocus();
                                    notifier.submit();
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (state.isBusy)
                MarketInsightsLoadingOverlay(
                  text: state.isRefreshing
                      ? 'Refreshing insights...\nPlease wait a few seconds'
                      : state.isPolling
                          ? 'Collecting market data...\n${state.jobStatus?.rows ?? 0} jobs found'
                          : 'Starting market insights...',
                ),
            ],
          ),
        ),
      ),
    );
  }
}

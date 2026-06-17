import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../providers/ai_portfolio_provider.dart';
import '../widgets/ai_portfolio_bottom_nav.dart';

class AIPortfolioPreviewScreen extends ConsumerStatefulWidget {
  const AIPortfolioPreviewScreen({super.key});

  @override
  ConsumerState<AIPortfolioPreviewScreen> createState() {
    return _AIPortfolioPreviewScreenState();
  }
}

class _AIPortfolioPreviewScreenState
    extends ConsumerState<AIPortfolioPreviewScreen> {
  bool _requestedPreview = false;
  String _loadedHtml = '';

  late final WebViewController _webViewController = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setBackgroundColor(Colors.white)
    ..setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: (request) {
          return NavigationDecision.navigate;
        },
      ),
    );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_requestedPreview) return;
    _requestedPreview = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(aiPortfolioProvider.notifier).loadPreviewHtmlFromBackend();
    });
  }

  Future<void> _loadHtmlIfNeeded(String html) async {
    if (html.trim().isEmpty) return;
    if (_loadedHtml == html) return;

    _loadedHtml = html;

    await _webViewController.loadHtmlString(
      html,
      baseUrl: 'https://growza-portfolios.local',
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiPortfolioProvider);
    final notifier = ref.read(aiPortfolioProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (state.previewHtml.trim().isNotEmpty) {
      _loadHtmlIfNeeded(state.previewHtml);
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.blue900 : AppColors.textDark,
      bottomNavigationBar: AIPortfolioBottomNav(
        currentTab: PortfolioTab.preview,
        canNavigate: state.canNavigateTabs,
        canPreview: state.canPreview,
        onTap: (tab) {
          notifier.goToTab(tab);

          switch (tab) {
            case PortfolioTab.edit:
              context.go('/ai-portfolio');
              break;

            case PortfolioTab.designs:
              context.go('/ai-portfolio/designs');
              break;

            case PortfolioTab.preview:
              break;

            case PortfolioTab.settings:
              context.go('/ai-portfolio/settings');
              break;
          }
        },
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.w(12),
            vertical: context.h(8),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => context.go('/ai-portfolio/designs'),
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      width: context.w(24),
                      height: context.w(24),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: context.w(18),
                        color: isDark ? AppColors.grey50 : AppColors.blue900,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Image.asset(
                    'assets/images/ai_protifilo/logo.png',
                    height: context.h(36),
                    fit: BoxFit.contain,
                  ),
                  const Spacer(),
                  SizedBox(width: context.w(24)),
                ],
              ),
              SizedBox(height: context.h(10)),
              Expanded(
                child: _buildBody(
                  context: context,
                  state: state,
                  notifier: notifier,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required AIPortfolioState state,
    required AIPortfolioNotifier notifier,
    required bool isDark,
  }) {
    if (state.isLoadingPreview || state.isSaving) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if ((state.errorMessage ?? '').trim().isNotEmpty &&
        state.previewHtml.trim().isEmpty) {
      return _MessageCard(
        isDark: isDark,
        icon: Icons.error_outline_rounded,
        title: 'Could not load preview',
        message: state.errorMessage!,
        buttonText: 'Try Again',
        onTap: notifier.loadPreviewHtmlFromBackend,
      );
    }

    if (state.previewHtml.trim().isEmpty) {
      return _MessageCard(
        isDark: isDark,
        icon: Icons.visibility_off_outlined,
        title: 'No preview available',
        message: 'Save your portfolio first, then preview it again.',
        buttonText: 'Reload Preview',
        onTap: notifier.loadPreviewHtmlFromBackend,
      );
    }

    return Column(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(context.r(12)),
            child: Container(
              width: double.infinity,
              color: Colors.white,
              child: WebViewWidget(
                controller: _webViewController,
              ),
            ),
          ),
        ),
        SizedBox(height: context.h(12)),
        Row(
          children: [
            Expanded(
              child: _BottomOutlinedButton(
                label: 'Back',
                onTap: () => context.go('/ai-portfolio/designs'),
              ),
            ),
            SizedBox(width: context.w(10)),
            Expanded(
              child: _BottomFilledButton(
                label: 'Next',
                onTap: () => context.go('/ai-portfolio/settings'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MessageCard extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String title;
  final String message;
  final String buttonText;
  final VoidCallback onTap;

  const _MessageCard({
    required this.isDark,
    required this.icon,
    required this.title,
    required this.message,
    required this.buttonText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(context.w(22)),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131A3B) : AppColors.grey50,
          borderRadius: BorderRadius.circular(context.r(12)),
          border: Border.all(
            color: isDark ? const Color(0xFFB8BCC8) : AppColors.grey600,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: context.w(42),
              color: isDark ? Colors.white : AppColors.blue900,
            ),
            SizedBox(height: context.h(12)),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: context.sp(17),
                color: isDark ? Colors.white : AppColors.blue900,
              ),
            ),
            SizedBox(height: context.h(8)),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
                fontSize: context.sp(13),
                color: isDark ? const Color(0xFFCACACA) : AppColors.grey600,
              ),
            ),
            SizedBox(height: context.h(16)),
            SizedBox(
              height: context.h(42),
              child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF268299),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: Text(buttonText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomOutlinedButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _BottomOutlinedButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: context.h(44),
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: const Color(0xFFF4F4F4),
          foregroundColor: const Color(0xFF268299),
          side: const BorderSide(
            color: Color(0xFF268299),
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: context.sp(13).clamp(12.0, 13.0),
          ),
        ),
      ),
    );
  }
}

class _BottomFilledButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _BottomFilledButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: context.h(44),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF268299),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: context.sp(13).clamp(12.0, 13.0),
          ),
        ),
      ),
    );
  }
}

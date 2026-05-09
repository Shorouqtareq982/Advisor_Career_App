import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../providers/ai_portfolio_provider.dart';

class AIPortfolioMyPortfoliosScreen extends ConsumerStatefulWidget {
  const AIPortfolioMyPortfoliosScreen({super.key});

  @override
  ConsumerState<AIPortfolioMyPortfoliosScreen> createState() {
    return _AIPortfolioMyPortfoliosScreenState();
  }
}

class _AIPortfolioMyPortfoliosScreenState
    extends ConsumerState<AIPortfolioMyPortfoliosScreen> {
  bool _loaded = false;
  String? _openingId;
  String? _previewingId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_loaded) return;
    _loaded = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(aiPortfolioProvider.notifier).loadUserPortfolios();
    });
  }

  Future<void> _openForEdit(String portfolioId) async {
    setState(() => _openingId = portfolioId);

    final notifier = ref.read(aiPortfolioProvider.notifier);
    await notifier.loadPortfolioById(portfolioId);

    if (!mounted) return;

    final latestState = ref.read(aiPortfolioProvider);
    setState(() => _openingId = null);

    if ((latestState.errorMessage ?? '').trim().isNotEmpty) {
      _showSnackBar(latestState.errorMessage!);
      return;
    }

    notifier.goToTab(PortfolioTab.edit);

    if (!mounted) return;
    context.go('/ai-portfolio');
  }

  Future<void> _openForPreview(String portfolioId) async {
    setState(() => _previewingId = portfolioId);

    final notifier = ref.read(aiPortfolioProvider.notifier);
    await notifier.loadPortfolioById(portfolioId);

    if (!mounted) return;

    final afterLoadState = ref.read(aiPortfolioProvider);
    setState(() => _previewingId = null);

    if ((afterLoadState.errorMessage ?? '').trim().isNotEmpty) {
      _showSnackBar(afterLoadState.errorMessage!);
      return;
    }

    notifier.goToTab(PortfolioTab.preview);

    if (!mounted) return;
    context.go('/ai-portfolio/preview');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiPortfolioProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.blue900 : AppColors.textDark,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.w(16),
            vertical: context.h(10),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => context.go('/ai-portfolio/settings'),
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
                    height: context.h(40),
                    fit: BoxFit.contain,
                  ),
                  const Spacer(),
                  SizedBox(width: context.w(24)),
                ],
              ),
              SizedBox(height: context.h(16)),
              Text(
                'My Portfolios',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: context.sp(20).clamp(18.0, 20.0),
                  color: isDark ? Colors.white : const Color(0xFF0F111D),
                ),
              ),
              SizedBox(height: context.h(6)),
              Text(
                'Open, preview, or continue editing your saved portfolios.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  fontSize: context.sp(13).clamp(12.0, 13.0),
                  color: isDark
                      ? const Color(0xFFCACACA)
                      : const Color(0xFF686868),
                ),
              ),
              SizedBox(height: context.h(16)),
              if ((state.errorMessage ?? '').trim().isNotEmpty) ...[
                _ErrorBox(
                  isDark: isDark,
                  message: state.errorMessage!,
                ),
                SizedBox(height: context.h(12)),
              ],
              Expanded(
                child: _buildBody(
                  context: context,
                  state: state,
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
    required bool isDark,
  }) {
    if (state.isLoading && state.userPortfolios.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (state.userPortfolios.isEmpty) {
      return _EmptyState(
        isDark: isDark,
        onCreateTap: () => context.go('/ai-portfolio'),
        onRefreshTap: () {
          ref.read(aiPortfolioProvider.notifier).loadUserPortfolios();
        },
      );
    }

    return RefreshIndicator(
      onRefresh: () {
        return ref.read(aiPortfolioProvider.notifier).loadUserPortfolios();
      },
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: context.h(20)),
        itemCount: state.userPortfolios.length,
        separatorBuilder: (_, __) => SizedBox(height: context.h(12)),
        itemBuilder: (context, index) {
          final item = state.userPortfolios[index];

          return _PortfolioListCard(
            isDark: isDark,
            id: item.id,
            title:
                item.title.trim().isEmpty ? 'Untitled Portfolio' : item.title,
            templateIndex: item.templateIndex,
            isPublished: item.isPublished,
            publicUrl: item.publicUrl,
            updatedAtText: _formatDate(item.updatedAt),
            isOpening: _openingId == item.id,
            isPreviewing: _previewingId == item.id,
            onEdit: () => _openForEdit(item.id),
            onPreview: () => _openForPreview(item.id),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'No update date';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day/$month/$year';
  }
}

class _PortfolioListCard extends StatelessWidget {
  final bool isDark;
  final String id;
  final String title;
  final int templateIndex;
  final bool isPublished;
  final String? publicUrl;
  final String updatedAtText;
  final bool isOpening;
  final bool isPreviewing;
  final VoidCallback onEdit;
  final VoidCallback onPreview;

  const _PortfolioListCard({
    required this.isDark,
    required this.id,
    required this.title,
    required this.templateIndex,
    required this.isPublished,
    required this.publicUrl,
    required this.updatedAtText,
    required this.isOpening,
    required this.isPreviewing,
    required this.onEdit,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor =
        isPublished ? const Color(0xFF268299) : const Color(0xFFB7791F);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.w(14)),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131A3B) : const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(context.r(12)),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2F56) : const Color(0xFFACACAC),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            offset: Offset(0, 3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: context.w(42),
                height: context.w(42),
                decoration: BoxDecoration(
                  color: const Color(0xFF268299).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(context.r(12)),
                ),
                child: Icon(
                  Icons.account_box_outlined,
                  color: const Color(0xFF268299),
                  size: context.w(23),
                ),
              ),
              SizedBox(width: context.w(10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: context.sp(14).clamp(13.0, 14.0),
                        color: isDark ? Colors.white : const Color(0xFF0F111D),
                      ),
                    ),
                    SizedBox(height: context.h(4)),
                    Text(
                      'Template $templateIndex • Updated $updatedAtText',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                        fontSize: context.sp(11).clamp(10.0, 11.0),
                        color: isDark
                            ? const Color(0xFFCACACA)
                            : const Color(0xFF686868),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: context.h(12)),
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.w(10),
                  vertical: context.h(5),
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: statusColor.withOpacity(0.5),
                  ),
                ),
                child: Text(
                  isPublished ? 'Published' : 'Draft',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: context.sp(10).clamp(9.0, 10.0),
                    color: statusColor,
                  ),
                ),
              ),
              const Spacer(),
              if ((publicUrl ?? '').trim().isNotEmpty)
                Icon(
                  Icons.public_rounded,
                  color: const Color(0xFF268299),
                  size: context.w(18),
                ),
            ],
          ),
          SizedBox(height: context.h(12)),
          Row(
            children: [
              Expanded(
                child: _CardButton(
                  label: isOpening ? 'Opening...' : 'Edit',
                  icon: Icons.edit_outlined,
                  isPrimary: false,
                  isDark: isDark,
                  onTap: isOpening || isPreviewing ? null : onEdit,
                ),
              ),
              SizedBox(width: context.w(8)),
              Expanded(
                child: _CardButton(
                  label: isPreviewing ? 'Loading...' : 'Preview',
                  icon: Icons.visibility_outlined,
                  isPrimary: true,
                  isDark: isDark,
                  onTap: isOpening || isPreviewing ? null : onPreview,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isPrimary;
  final bool isDark;
  final VoidCallback? onTap;

  const _CardButton({
    required this.label,
    required this.icon,
    required this.isPrimary,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return SizedBox(
      height: context.h(38),
      child: isPrimary
          ? ElevatedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: context.w(15)),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    enabled ? const Color(0xFF268299) : AppColors.grey200,
                foregroundColor: enabled ? Colors.white : AppColors.grey600,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: context.w(15)),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor:
                    isDark ? const Color(0xFF131A3B) : Colors.white,
                foregroundColor:
                    enabled ? const Color(0xFF268299) : AppColors.grey600,
                side: BorderSide(
                  color: enabled ? const Color(0xFF268299) : AppColors.grey300,
                  width: 1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isDark;
  final VoidCallback onCreateTap;
  final VoidCallback onRefreshTap;

  const _EmptyState({
    required this.isDark,
    required this.onCreateTap,
    required this.onRefreshTap,
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
              Icons.folder_open_rounded,
              size: context.w(44),
              color: isDark ? Colors.white : AppColors.blue900,
            ),
            SizedBox(height: context.h(12)),
            Text(
              'No saved portfolios yet',
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
              'Create your first AI portfolio, then it will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
                fontSize: context.sp(13),
                color: isDark ? const Color(0xFFCACACA) : AppColors.grey600,
              ),
            ),
            SizedBox(height: context.h(16)),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onRefreshTap,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF268299),
                      side: const BorderSide(
                        color: Color(0xFF268299),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: const Text('Refresh'),
                  ),
                ),
                SizedBox(width: context.w(10)),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onCreateTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF268299),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: const Text('Create New'),
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

class _ErrorBox extends StatelessWidget {
  final bool isDark;
  final String message;

  const _ErrorBox({
    required this.isDark,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.w(12)),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF3A1F2A) : const Color(0xFFFFECEC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD03430)),
      ),
      child: Text(
        message,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: context.sp(12).clamp(11.0, 12.0),
          color: isDark ? Colors.white : const Color(0xFFD03430),
        ),
      ),
    );
  }
}

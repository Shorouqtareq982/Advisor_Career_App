import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../providers/ai_portfolio_provider.dart';
import '../widgets/ai_portfolio_bottom_nav.dart';

class AIPortfolioSettingsScreen extends ConsumerWidget {
  const AIPortfolioSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(aiPortfolioProvider);
    final notifier = ref.read(aiPortfolioProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.blue900 : AppColors.textDark,
      bottomNavigationBar: AIPortfolioBottomNav(
        currentTab: PortfolioTab.settings,
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
              context.go('/ai-portfolio/preview');
              break;
            case PortfolioTab.settings:
              break;
          }
        },
      ),
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
                    onTap: () => context.go('/ai-portfolio/preview'),
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
              SizedBox(height: context.h(10)),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: context.h(20)),
                  child: Column(
                    children: [
                      Text(
                        'Settings',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: context.sp(19).clamp(18.0, 19.0),
                          color:
                              isDark ? Colors.white : const Color(0xFF0F111D),
                        ),
                      ),
                      SizedBox(height: context.h(8)),
                      Text(
                        'Manage publishing, sharing, exporting, and saved portfolios',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                          fontSize: context.sp(14).clamp(13.0, 14.0),
                          color: isDark
                              ? const Color(0xFFCACACA)
                              : const Color(0xFF686868),
                        ),
                      ),
                      if ((state.errorMessage ?? '').trim().isNotEmpty) ...[
                        SizedBox(height: context.h(12)),
                        _ErrorBox(isDark: isDark, message: state.errorMessage!),
                      ],
                      SizedBox(height: context.h(16)),
                      _SettingsCard(
                        isDark: isDark,
                        title: 'My Portfolios',
                        subtitle:
                            'View all portfolios you created before and continue editing them.',
                        child: SizedBox(
                          width: double.infinity,
                          child: _SettingsActionButton(
                            label: 'Open My Portfolios',
                            icon: Icons.folder_copy_outlined,
                            isDark: isDark,
                            onTap: () =>
                                context.go('/ai-portfolio/my-portfolios'),
                          ),
                        ),
                      ),
                      SizedBox(height: context.h(12)),
                      _SettingsCard(
                        isDark: isDark,
                        title: 'Portfolio URL',
                        subtitle:
                            'Publish your portfolio to get a public Cloudflare Pages link.',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _UrlBox(
                              isDark: isDark,
                              value: state.publicUrl.trim().isEmpty
                                  ? 'Your public portfolio link will appear here after publishing.'
                                  : state.publicUrl,
                            ),
                            SizedBox(height: context.h(10)),
                            Row(
                              children: [
                                Expanded(
                                  child: _SettingsActionButton(
                                    label: state.isPublishing
                                        ? 'Publishing...'
                                        : state.isPublished
                                            ? 'Update Publish'
                                            : 'Publish',
                                    icon: Icons.public_rounded,
                                    isDark: isDark,
                                    onTap: state.isPublishing
                                        ? null
                                        : () async {
                                            await notifier.publishPortfolio();
                                            if (context.mounted &&
                                                ref
                                                    .read(aiPortfolioProvider)
                                                    .publicUrl
                                                    .trim()
                                                    .isNotEmpty) {
                                              _showSnackBar(context,
                                                  'Portfolio published successfully');
                                            }
                                          },
                                  ),
                                ),
                                SizedBox(width: context.w(8)),
                                Expanded(
                                  child: _SettingsActionButton(
                                    label: state.isUnpublishing
                                        ? 'Unpublishing...'
                                        : 'Unpublish',
                                    icon: Icons.visibility_off_rounded,
                                    isDark: isDark,
                                    onTap: state.isPublished &&
                                            !state.isUnpublishing
                                        ? () async {
                                            await notifier.unpublishPortfolio();
                                            if (context.mounted)
                                              _showSnackBar(context,
                                                  'Portfolio unpublished');
                                          }
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: context.h(10)),
                            Row(
                              children: [
                                Expanded(
                                  child: _SettingsActionButton(
                                    label: 'Open',
                                    icon: Icons.open_in_new_rounded,
                                    isDark: isDark,
                                    onTap: state.publicUrl.trim().isEmpty
                                        ? null
                                        : () => _openExternal(
                                            context, state.publicUrl),
                                  ),
                                ),
                                SizedBox(width: context.w(8)),
                                Expanded(
                                  child: _SettingsActionButton(
                                    label: 'Copy Link',
                                    icon: Icons.copy_rounded,
                                    isDark: isDark,
                                    onTap: state.publicUrl.trim().isEmpty
                                        ? null
                                        : () => _copyText(
                                            context,
                                            state.publicUrl,
                                            'Portfolio link copied'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: context.h(12)),
                      _SettingsCard(
                        isDark: isDark,
                        title: 'Share Portfolio',
                        subtitle:
                            'Share your published portfolio on LinkedIn or WhatsApp.',
                        child: Row(
                          children: [
                            Expanded(
                              child: _SettingsActionButton(
                                label: 'LinkedIn',
                                icon: Icons.business_center_outlined,
                                isDark: isDark,
                                onTap: state.publicUrl.trim().isEmpty
                                    ? null
                                    : () {
                                        final linkedInUrl =
                                            'https://www.linkedin.com/sharing/share-offsite/?url=${Uri.encodeComponent(state.publicUrl)}';
                                        _openExternal(context, linkedInUrl);
                                      },
                              ),
                            ),
                            SizedBox(width: context.w(8)),
                            Expanded(
                              child: _SettingsActionButton(
                                label: 'WhatsApp',
                                icon: Icons.chat_bubble_outline_rounded,
                                isDark: isDark,
                                onTap: state.publicUrl.trim().isEmpty
                                    ? null
                                    : () {
                                        final whatsappUrl =
                                            'https://wa.me/?text=${Uri.encodeComponent(state.publicUrl)}';
                                        _openExternal(context, whatsappUrl);
                                      },
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: context.h(12)),
                      _SettingsCard(
                        isDark: isDark,
                        title: 'Export Portfolio',
                        subtitle:
                            'Generate a PDF from the backend-rendered portfolio.',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _UrlBox(
                              isDark: isDark,
                              value: state.pdfUrl.trim().isEmpty
                                  ? 'Your PDF link will appear here after export.'
                                  : state.pdfUrl,
                            ),
                            SizedBox(height: context.h(10)),
                            _SettingsActionButton(
                              label: state.isExportingPdf
                                  ? 'Exporting...'
                                  : 'Export PDF',
                              icon: Icons.picture_as_pdf_outlined,
                              isDark: isDark,
                              onTap: state.isExportingPdf
                                  ? null
                                  : () async {
                                      await notifier.exportPortfolioPdf();
                                      if (context.mounted &&
                                          ref
                                              .read(aiPortfolioProvider)
                                              .pdfUrl
                                              .trim()
                                              .isNotEmpty) {
                                        _showSnackBar(context,
                                            'PDF exported successfully');
                                      }
                                    },
                            ),
                            SizedBox(height: context.h(10)),
                            Row(
                              children: [
                                Expanded(
                                  child: _SettingsActionButton(
                                    label: 'Open PDF',
                                    icon: Icons.open_in_new_rounded,
                                    isDark: isDark,
                                    onTap: state.pdfUrl.trim().isEmpty
                                        ? null
                                        : () => _openExternal(
                                            context, state.pdfUrl),
                                  ),
                                ),
                                SizedBox(width: context.w(8)),
                                Expanded(
                                  child: _SettingsActionButton(
                                    label: 'Copy PDF',
                                    icon: Icons.copy_rounded,
                                    isDark: isDark,
                                    onTap: state.pdfUrl.trim().isEmpty
                                        ? null
                                        : () => _copyText(context, state.pdfUrl,
                                            'PDF link copied'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: context.h(12)),
                      _SettingsCard(
                        isDark: isDark,
                        title: 'Delete Portfolio',
                        subtitle:
                            'Delete this portfolio from backend storage permanently.',
                        child: SizedBox(
                          width: double.infinity,
                          child: _DangerButton(
                            label: state.isDeleting
                                ? 'Deleting...'
                                : 'Delete Portfolio',
                            onTap: state.isDeleting
                                ? null
                                : () async {
                                    final confirmed = await _showDeleteDialog(
                                        context, isDark);
                                    if (confirmed != true) return;
                                    await notifier.deletePortfolioFromBackend();
                                    if (context.mounted)
                                      context.go('/ai-portfolio');
                                  },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openExternal(BuildContext context, String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null) {
      _showSnackBar(context, 'Invalid link');
      return;
    }

    final opened = await launchUrl(
      uri,
      mode: LaunchMode.platformDefault,
      webOnlyWindowName: '_blank',
    );

    if (!opened && context.mounted) {
      _showSnackBar(context, 'Could not open link');
    }
  }

  Future<void> _copyText(
      BuildContext context, String value, String message) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (context.mounted) _showSnackBar(context, message);
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<bool?> _showDeleteDialog(BuildContext context, bool isDark) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _ConfirmDialog(
        isDark: isDark,
        title: 'Delete Portfolio?',
        message:
            'This will permanently delete your portfolio. This action cannot be undone.',
        confirmLabel: 'Delete',
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final bool isDark;
  final String message;

  const _ErrorBox({required this.isDark, required this.message});

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

class _UrlBox extends StatelessWidget {
  final bool isDark;
  final String value;

  const _UrlBox({required this.isDark, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: context.h(48)),
      padding: EdgeInsets.symmetric(
        horizontal: context.w(12),
        vertical: context.h(10),
      ),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131A3B) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF268299),
          width: 1,
        ),
      ),
      child: SelectableText(
        value,
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
          fontSize: context.sp(12).clamp(11.0, 12.0),
          color: isDark ? Colors.white : const Color(0xFF0F111D),
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final bool isDark;
  final String title;
  final String subtitle;
  final Widget child;

  const _SettingsCard({
    required this.isDark,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.w(16)),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131A3B) : const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(8),
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
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: context.sp(14).clamp(13.0, 14.0),
              color: isDark ? Colors.white : const Color(0xFF0F111D),
            ),
          ),
          SizedBox(height: context.h(4)),
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
              fontSize: context.sp(10).clamp(9.0, 10.0),
              color: isDark ? const Color(0xFFCACACA) : const Color(0xFF686868),
            ),
          ),
          SizedBox(height: context.h(12)),
          child,
        ],
      ),
    );
  }
}

class _SettingsActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isDark;
  final VoidCallback? onTap;

  const _SettingsActionButton({
    required this.label,
    required this.icon,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return SizedBox(
      height: context.h(40),
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: context.w(16)),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: context.sp(12).clamp(11.0, 12.0),
            ),
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled
              ? (isDark ? const Color(0xFF35B7D7) : const Color(0xFF268299))
              : AppColors.grey200,
          foregroundColor: enabled ? Colors.white : AppColors.grey600,
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: context.w(10)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
        ),
      ),
    );
  }
}

class _DangerButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _DangerButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return SizedBox(
      height: context.h(42),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              enabled ? const Color(0xFFD03430) : AppColors.grey200,
          foregroundColor: enabled ? Colors.white : AppColors.grey600,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
          padding: EdgeInsets.symmetric(horizontal: context.w(14)),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: context.sp(12).clamp(11.0, 12.0),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  final bool isDark;
  final String title;
  final String message;
  final String confirmLabel;

  const _ConfirmDialog({
    required this.isDark,
    required this.title,
    required this.message,
    required this.confirmLabel,
  });

  @override
  Widget build(BuildContext context) {
    final background =
        isDark ? const Color(0xFF131A3B) : const Color(0xFFF8F8F8);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: EdgeInsets.all(context.w(24)),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: context.sp(20).clamp(18.0, 20.0),
                color: isDark ? Colors.white : const Color(0xFF0F111D),
              ),
            ),
            SizedBox(height: context.h(18)),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
                fontSize: context.sp(14).clamp(13.0, 14.0),
                color:
                    isDark ? const Color(0xFFCACACA) : const Color(0xFF686868),
              ),
            ),
            SizedBox(height: context.h(24)),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: context.h(44),
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.grey200,
                        foregroundColor: const Color(0xFF4F4F4F),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                ),
                SizedBox(width: context.w(16)),
                Expanded(
                  child: SizedBox(
                    height: context.h(44),
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD03430),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50),
                        ),
                      ),
                      child: Text(confirmLabel),
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

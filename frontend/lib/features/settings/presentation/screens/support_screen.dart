import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/settings_app_bar.dart';

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();

  bool _isLoading = false;
  String? _ipAddress;
  String? _browserInfo;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _getDeviceInfo();
  }

  void _loadUserData() {
    final user = ref.read(authProvider).user;
    if (user != null) {
      _nameController.text = user.username ?? '';
      _emailController.text = user.email ?? '';
    }
  }

  Future<void> _getDeviceInfo() async {
    setState(() {
      _ipAddress = '192.168.1.1';
      _browserInfo = 'Flutter App';
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _handleSendMessage() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final user = ref.read(authProvider).user;

      await supabase.from('contactme').insert({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'message': _messageController.text.trim(),
        'ip_address': _ipAddress,
        'browser_information': _browserInfo,
        'user_id': user?.id,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      _showSuccessDialog();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to send message: ${e.toString()}',
            style: const TextStyle(fontFamily: 'Inter'),
          ),
          backgroundColor: AppColors.red600,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final h = c.maxHeight;

            final dialogW = (w * 0.92).clamp(300.0, 460.0);
            final pad = (dialogW * 0.06).clamp(16.0, 26.0);
            final iconBox = (dialogW * 0.18).clamp(64.0, 84.0);
            final titleSize = (dialogW * 0.045).clamp(16.0, 20.0);
            final bodySize = (dialogW * 0.035).clamp(13.0, 15.0);
            final btnH = (h * 0.06).clamp(44.0, 52.0);

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.symmetric(
                horizontal: (w * 0.04).clamp(12.0, 20.0),
                vertical: (h * 0.03).clamp(12.0, 20.0),
              ),
              child: Container(
                width: dialogW,
                padding: EdgeInsets.all(pad),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E1E2F)
                      : const Color(0xFFF8F8F8),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.10),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: iconBox,
                      height: iconBox,
                      decoration: BoxDecoration(
                        color: AppColors.green700.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle_outline,
                        color: AppColors.green700,
                        size: (iconBox * 0.62).clamp(36.0, 54.0),
                      ),
                    ),
                    SizedBox(height: (pad * 0.7).clamp(10.0, 18.0)),
                    Text(
                      'Message Sent Successfully',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: titleSize,
                        fontWeight: FontWeight.w700,
                        color:
                            isDark ? AppColors.grey50 : const Color(0xFF0F111D),
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: (pad * 0.35).clamp(6.0, 10.0)),
                    Text(
                      'Our support team will contact you via email within 24 hours.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: bodySize,
                        color: isDark
                            ? Colors.grey.shade400
                            : const Color(0xFF686868),
                        height: 1.35,
                      ),
                    ),
                    SizedBox(height: (pad * 0.9).clamp(14.0, 22.0)),
                    SizedBox(
                      width: double.infinity,
                      height: btnH,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          context.go('/settings');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.lightBlue700,
                          foregroundColor: AppColors.grey50,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                        ),
                        child: Text(
                          'Got it',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: (dialogW * 0.04).clamp(14.0, 16.0),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.blue500 : const Color(0xFFF8F8F8);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;

            final horizontalPad = (w * 0.04).clamp(14.0, 36.0);

            final titleSize = (w * 0.03).clamp(18.0, 26.0);

            final gap8 = (h * 0.01).clamp(6.0, 10.0);
            final gap16 = (h * 0.02).clamp(12.0, 18.0);

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPad),
              child: Column(
                children: [
                  SettingsAppBar(
                    centerLogo: true,
                    onBack: () => context.go('/settings'),
                  ),
                  SizedBox(height: gap8),
                  Text(
                    'Support',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: titleSize,
                      fontWeight: FontWeight.w700,
                      color:
                          isDark ? AppColors.grey50 : const Color(0xFF0F111D),
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: gap16),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.only(
                        bottom:
                            MediaQuery.of(context).viewInsets.bottom + gap16,
                      ),
                      child: _SupportCard(
                        isDark: isDark,
                        formKey: _formKey,
                        name: _nameController.text,
                        email: _emailController.text,
                        messageController: _messageController,
                        isLoading: _isLoading,
                        onSend: _handleSendMessage,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  final bool isDark;
  final GlobalKey<FormState> formKey;
  final String name;
  final String email;
  final TextEditingController messageController;
  final bool isLoading;
  final VoidCallback onSend;

  const _SupportCard({
    required this.isDark,
    required this.formKey,
    required this.name,
    required this.email,
    required this.messageController,
    required this.isLoading,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final pad = (w * 0.04).clamp(14.0, 26.0);

        final h1 = (w * 0.03).clamp(16.0, 20.0);
        final p = (w * 0.022).clamp(13.0, 16.0);

        final btnH =
            (MediaQuery.of(context).size.height * 0.06).clamp(44.0, 52.0);

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(pad),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2F) : AppColors.grey50,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Contact Us',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: h1,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.grey50 : const Color(0xFF0F111D),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Send us your issue and we will get back to you.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: p,
                    color:
                        isDark ? Colors.grey.shade400 : const Color(0xFF686868),
                    height: 1.25,
                  ),
                ),
                SizedBox(height: (pad * 0.9).clamp(14.0, 22.0)),
                _readOnlyField(
                  context,
                  icon: Icons.person_outline,
                  label: 'Full Name',
                  value: name,
                  isDark: isDark,
                ),
                SizedBox(height: (pad * 0.7).clamp(12.0, 18.0)),
                _readOnlyField(
                  context,
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: email,
                  isDark: isDark,
                ),
                SizedBox(height: (pad * 0.7).clamp(12.0, 18.0)),
                _messageField(context, isDark, messageController),
                SizedBox(height: (pad * 1.0).clamp(16.0, 24.0)),
                SizedBox(
                  width: double.infinity,
                  height: btnH,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : onSend,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.lightBlue700,
                      foregroundColor: AppColors.grey50,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.grey50),
                            ),
                          )
                        : Text(
                            'Send Message',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: (w * 0.022).clamp(14.0, 16.0),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _readOnlyField(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    final display = value.trim().isEmpty ? 'Not provided' : value.trim();

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final labelSize = (w * 0.02).clamp(12.5, 14.5);
        final textSize = (w * 0.02).clamp(12.5, 14.5);
        final iconSize = (w * 0.022).clamp(14.0, 18.0);
        final padV = (w * 0.015).clamp(10.0, 12.0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: iconSize,
                  color: isDark ? AppColors.grey50 : const Color(0xFF0F111D),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: labelSize,
                    color: isDark ? AppColors.grey50 : const Color(0xFF0F111D),
                    height: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: padV),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color:
                      isDark ? Colors.grey.shade700 : const Color(0xFFACACAC),
                ),
              ),
              child: Text(
                display,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: textSize,
                  color: value.trim().isEmpty
                      ? (isDark
                          ? Colors.grey.shade500
                          : const Color(0xFF868686))
                      : (isDark ? AppColors.grey50 : const Color(0xFF0F111D)),
                  height: 1.2,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _messageField(
    BuildContext context,
    bool isDark,
    TextEditingController controller,
  ) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final labelSize = (w * 0.02).clamp(12.5, 14.5);
        final textSize = (w * 0.02).clamp(12.5, 14.5);
        final iconSize = (w * 0.022).clamp(14.0, 18.0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.message_outlined,
                  size: iconSize,
                  color: isDark ? AppColors.grey50 : const Color(0xFF0F111D),
                ),
                const SizedBox(width: 6),
                Text(
                  'Message',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: labelSize,
                    color: isDark ? AppColors.grey50 : const Color(0xFF0F111D),
                    height: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color:
                      isDark ? Colors.grey.shade700 : const Color(0xFFACACAC),
                ),
              ),
              child: TextFormField(
                controller: controller,
                maxLines: 4,
                maxLength: 500,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: textSize,
                  color: isDark ? AppColors.grey50 : const Color(0xFF0F111D),
                  height: 1.2,
                ),
                decoration: InputDecoration(
                  hintText: 'Describe your issue...',
                  hintStyle: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: textSize,
                    color:
                        isDark ? Colors.grey.shade500 : const Color(0xFF868686),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(12),
                  counterText: '',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Message is required';
                  }
                  return null;
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

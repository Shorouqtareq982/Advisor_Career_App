import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/curved_background.dart';
import '../widgets/primary_button.dart';

class ChooseVerificationScreen extends StatefulWidget {
  final String email;
  final String? phone;

  const ChooseVerificationScreen({super.key, required this.email, this.phone});

  @override
  State<ChooseVerificationScreen> createState() =>
      _ChooseVerificationScreenState();
}

class _ChooseVerificationScreenState extends State<ChooseVerificationScreen> {
  String _selectedMethod = 'email'; // 'email' or 'phone'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CurvedBackground(
        showLogo: true,
        child: Column(
          children: [
            // Back button
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.white),
                    onPressed: () => context.pop(),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 80),

            // White card
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),

                      // Title
                      Text(
                        'Choose Verification Method',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),

                      const SizedBox(height: 16),

                      // Subtitle
                      Text(
                        'Choose how you\'d like to receive your\nverification code to protect your account',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Email Option
                      _buildVerificationOption(
                        icon: Icons.email_outlined,
                        title: 'Email Verification',
                        subtitle: 'We\'ll send a code to your email address',
                        value: 'email',
                        maskText: widget.email,
                      ),

                      const SizedBox(height: 16),

                      // Phone Option
                      _buildVerificationOption(
                        icon: Icons.phone_outlined,
                        title: 'Phone Verification',
                        subtitle: 'We\'ll send a code via SMS to your phone',
                        value: 'phone',
                        maskText: widget.phone ?? '+20 *** *** ****',
                        isDisabled: widget.phone == null,
                      ),

                      const SizedBox(height: 40),

                      // Send Code Button
                      PrimaryButton(
                        text: 'Send Code',
                        onPressed: () {
                          if (_selectedMethod == 'email') {
                            context.push('/verification', extra: widget.email);
                          } else {
                            context.push(
                              '/verification-phone',
                              extra: widget.phone,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required String maskText,
    bool isDisabled = false,
  }) {
    final isSelected = _selectedMethod == value;

    return GestureDetector(
      onTap: isDisabled
          ? null
          : () {
              setState(() {
                _selectedMethod = value;
              });
            },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDisabled ? AppColors.greyLight : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : isDisabled
                ? AppColors.grey
                : AppColors.greyLight,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDisabled
                    ? AppColors.grey.withOpacity(0.1)
                    : isSelected
                    ? AppColors.primary.withOpacity(0.1)
                    : AppColors.greyLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isDisabled
                    ? AppColors.grey
                    : isSelected
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
            ),

            const SizedBox(width: 16),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: isDisabled
                          ? AppColors.grey
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDisabled
                          ? AppColors.grey
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Radio
            if (!isDisabled)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.grey,
                    width: 2,
                  ),
                  color: isSelected ? AppColors.primary : Colors.transparent,
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 16, color: AppColors.white)
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}

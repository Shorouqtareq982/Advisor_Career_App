import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/responsive_extension.dart';
import '../../../../core/utils/auth_validators.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/widgets/phone_input_field.dart';
import '../../../../shared/models/country_model.dart';

class PersonalInfoScreen extends ConsumerStatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  ConsumerState<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends ConsumerState<PersonalInfoScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _phoneInputKey = GlobalKey<PhoneInputFieldState>();

  bool _isLoading = false;
  bool _isEditing = false;
  bool _isUploadingImage = false;

  Country _selectedCountry = Countries.egypt;
  String? _avatarUrl;

  String? _usernameError;
  String? _emailError;
  String? _phoneError;

  String? _originalUsername;
  String? _originalEmail;
  String? _originalPhone;
  Country _originalCountry = Countries.egypt;
  String? _originalAvatarUrl;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging &&
          _tabController.index == 1 &&
          mounted) {
        context.pushReplacement('/career-preferences');
      }
    });

    _loadUserData();

    _usernameController.addListener(() {
      if (_usernameError != null) setState(() => _usernameError = null);
    });
    _emailController.addListener(() {
      if (_emailError != null) setState(() => _emailError = null);
    });
    _phoneController.addListener(() {
      if (_phoneError != null) setState(() => _phoneError = null);
    });
  }

  void _loadUserData() {
    final user = ref.read(authProvider).user;
    if (user != null) {
      _usernameController.text = user.username ?? '';
      _emailController.text = user.email ?? '';

      if (user.phone != null && user.phone!.isNotEmpty) {
        final phone = user.phone!;
        for (final country in Countries.all) {
          if (phone.startsWith(country.dialCode)) {
            _selectedCountry = country;
            _phoneController.text = phone.replaceFirst(country.dialCode, '');
            break;
          }
        }
        if (_phoneController.text.isEmpty) {
          _phoneController.text = phone;
        }
      }

      _avatarUrl = user.avatarUrl;

      _originalUsername = user.username;
      _originalEmail = user.email;
      _originalPhone = user.phone;
      _originalCountry = _selectedCountry;
      _originalAvatarUrl = user.avatarUrl;
    }
  }

  void _cancelEditing() {
    setState(() {
      _usernameController.text = _originalUsername ?? '';
      _emailController.text = _originalEmail ?? '';

      if (_originalPhone != null && _originalPhone!.isNotEmpty) {
        final phone = _originalPhone!;
        for (final country in Countries.all) {
          if (phone.startsWith(country.dialCode)) {
            _selectedCountry = country;
            _phoneController.text = phone.replaceFirst(country.dialCode, '');
            break;
          }
        }
        if (_phoneController.text.isEmpty) {
          _phoneController.text = phone;
        }
      } else {
        _phoneController.clear();
        _selectedCountry = _originalCountry;
      }

      _avatarUrl = _originalAvatarUrl;
      _isEditing = false;
      _usernameError = null;
      _emailError = null;
      _phoneError = null;
    });
  }

  bool _hasChanges(String? fullPhone) {
    final currentUsername = _usernameController.text.trim().isEmpty
        ? null
        : _usernameController.text.trim();
    final currentEmail = _emailController.text.trim().isEmpty
        ? null
        : _emailController.text.trim();
    final currentPhone = fullPhone?.isEmpty ?? true ? null : fullPhone;

    return currentUsername != _originalUsername ||
        currentEmail != _originalEmail ||
        currentPhone != _originalPhone ||
        _avatarUrl != _originalAvatarUrl;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      setState(() => _isUploadingImage = true);

      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (image != null && mounted) {
        final imageFile = File(image.path);
        final avatarUrl =
            await ref.read(authProvider.notifier).uploadAvatar(imageFile);

        if (avatarUrl != null && mounted) {
          setState(() {
            _avatarUrl = avatarUrl;
            _originalAvatarUrl = avatarUrl;
          });
          _showSnackBar('Profile picture updated!', isError: false);
        } else if (mounted) {
          _showSnackBar(
            'Failed to upload image. Please check storage permissions.',
            isError: true,
          );
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) _showSnackBar('Error: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Inter')),
        backgroundColor: isError ? AppColors.red600 : AppColors.green700,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.symmetric(
          horizontal: context.w(16),
          vertical: context.h(8),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(context.r(12)),
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    final fullPhone = _phoneInputKey.currentState?.getFullPhoneNumber();

    if (!_hasChanges(fullPhone)) {
      _showSnackBar('No changes to save.', isError: false);
      setState(() {
        _isEditing = false;
        _usernameError = null;
        _emailError = null;
        _phoneError = null;
      });
      return;
    }

    // ── فاليديشن الفورم قبل ما نبعت للـ API ──
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _usernameError = null;
      _emailError = null;
      _phoneError = null;
    });

    final success = await ref.read(authProvider.notifier).updateUserProfile(
          username: _usernameController.text.trim().isEmpty
              ? null
              : _usernameController.text.trim(),
          email: _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          phone: fullPhone?.isEmpty ?? true ? null : fullPhone,
          avatarUrl: _avatarUrl,
        );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (success) {
      setState(() {
        _isEditing = false;
        _originalUsername = _usernameController.text.trim().isEmpty
            ? null
            : _usernameController.text.trim();
        _originalEmail = _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim();
        _originalPhone = fullPhone;
        _originalCountry = _selectedCountry;
        _originalAvatarUrl = _avatarUrl;
      });
      _showSnackBar('Profile updated successfully!', isError: false);
    } else {
      final authState = ref.read(authProvider);
      setState(() {
        _usernameError = authState.usernameError;
        _emailError = authState.emailError;
        _phoneError = authState.phoneError;
      });

      if (authState.error != null &&
          authState.usernameError == null &&
          authState.emailError == null &&
          authState.phoneError == null) {
        _showSnackBar(authState.error!, isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = _isLoading || authState.isLoading;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth >= 600;
    final isLargeTablet = screenWidth >= 900;
    final isSmallPhone = screenWidth < 360;
    final isShortScreen = screenHeight < 650;

    final avatarSize = isLargeTablet
        ? 140.0
        : isTablet
            ? 120.0
            : isSmallPhone
                ? 80.0
                : context.w(100).clamp(80.0, 110.0).toDouble();

    final cameraIconSize = (avatarSize * 0.30).clamp(20.0, 36.0);
    final cameraContainerSize = (avatarSize * 0.34).clamp(26.0, 42.0);

    final horizontalPadding = isLargeTablet
        ? screenWidth * 0.18
        : isTablet
            ? context.w(48)
            : context.w(20);

    final titleFontSize = isTablet ? context.sp(22) : context.sp(20);
    final tabFontSize = isTablet
        ? context.sp(15)
        : isSmallPhone
            ? context.sp(12)
            : context.sp(13);

    final fieldSpacing = isShortScreen ? context.h(10) : context.h(14);
    final avatarTopSpacing = isShortScreen ? context.h(10) : context.h(20);
    final avatarBottomSpacing = isShortScreen ? context.h(14) : context.h(24);
    final saveButtonTopSpacing = isShortScreen ? context.h(16) : context.h(28);

    final bgColor = isDark ? AppColors.blue700 : AppColors.grey200;
    final titleColor = isDark ? AppColors.grey50 : AppColors.blue900;
    final accentColor =
        isDark ? AppColors.lightBlue500 : AppColors.lightBlue700;

    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final safeBottom = MediaQuery.of(context).padding.bottom;
            final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

            return Column(
              children: [
                // ── Top bar ──────────────────────────────────────────────────
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: context.h(isShortScreen ? 10 : 16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Icon(
                          Icons.arrow_back_ios_new,
                          color: titleColor,
                          size: context.icon(20),
                        ),
                      ),
                      const Spacer(),
                      const AppLogo(),
                      const Spacer(),
                      SizedBox(width: context.icon(20)),
                    ],
                  ),
                ),

                // ── Title + edit icon ────────────────────────────────────────
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Row(
                    children: [
                      SizedBox(width: context.w(36)),
                      Expanded(
                        child: Center(
                          child: Text(
                            'Profile',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.w700,
                              color: titleColor,
                            ),
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          if (_isEditing) {
                            _cancelEditing();
                          } else {
                            setState(() => _isEditing = true);
                          }
                        },
                        borderRadius: BorderRadius.circular(context.r(8)),
                        child: Padding(
                          padding: EdgeInsets.all(context.w(6)),
                          child: Icon(
                            _isEditing ? Icons.close : Icons.edit,
                            color: _isEditing ? AppColors.red600 : accentColor,
                            size: context.icon(20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: context.h(isShortScreen ? 8 : 12)),

                // ── Tab bar ──────────────────────────────────────────────────
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: TabBar(
                    controller: _tabController,
                    indicator: UnderlineTabIndicator(
                      borderSide: BorderSide(width: 2.5, color: accentColor),
                      insets: EdgeInsets.zero,
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: accentColor,
                    unselectedLabelColor:
                        isDark ? AppColors.grey400 : AppColors.grey600,
                    labelStyle: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: tabFontSize,
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelStyle: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: tabFontSize,
                      fontWeight: FontWeight.w400,
                    ),
                    dividerColor:
                        isDark ? AppColors.blue400 : AppColors.grey300,
                    isScrollable: isSmallPhone,
                    tabs: const [
                      Tab(text: 'Personal Info'),
                      Tab(text: 'Career Preferences'),
                    ],
                  ),
                ),

                SizedBox(height: avatarTopSpacing),

                // ── Scrollable body ──────────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.only(
                      left: horizontalPadding,
                      right: horizontalPadding,
                      bottom: keyboardHeight + safeBottom + context.h(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Avatar ───────────────────────────────────────────
                        Center(
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: avatarSize,
                                height: avatarSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.grey300,
                                  image: _avatarUrl != null
                                      ? DecorationImage(
                                          image: NetworkImage(_avatarUrl!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: _avatarUrl == null
                                    ? Icon(
                                        Icons.person,
                                        size: (avatarSize * 0.58)
                                            .clamp(36.0, 72.0),
                                        color: AppColors.blue400,
                                      )
                                    : null,
                              ),
                              Positioned(
                                bottom: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: _isEditing
                                      ? (_isUploadingImage ? null : _pickImage)
                                      : null,
                                  child: Container(
                                    width: cameraContainerSize,
                                    height: cameraContainerSize,
                                    decoration: BoxDecoration(
                                      color: accentColor,
                                      shape: BoxShape.circle,
                                      border:
                                          Border.all(color: bgColor, width: 2),
                                    ),
                                    child: _isUploadingImage
                                        ? Center(
                                            child: SizedBox(
                                              width: cameraIconSize * 0.65,
                                              height: cameraIconSize * 0.65,
                                              child:
                                                  const CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                        Color>(Colors.white),
                                              ),
                                            ),
                                          )
                                        : Icon(
                                            _isEditing
                                                ? Icons.camera_alt
                                                : Icons.edit,
                                            color: Colors.white,
                                            size: cameraIconSize * 0.62,
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: avatarBottomSpacing),

                        // ── Form ─────────────────────────────────────────────
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FigmaField(
                                label: 'Full Name',
                                controller: _usernameController,
                                enabled: _isEditing,
                                errorText: _usernameError,
                                keyboardType: TextInputType.name,
                                textInputAction: TextInputAction.next,
                                validator: _isEditing
                                    ? (v) => AuthValidators.validateUsername(v)
                                    : (_) => null,
                                isDark: isDark,
                              ),
                              SizedBox(height: fieldSpacing),
                              _FigmaField(
                                label: 'Email',
                                controller: _emailController,
                                enabled: _isEditing,
                                errorText: _emailError,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                validator: _isEditing
                                    ? (v) {
                                        if (v == null || v.trim().isEmpty) {
                                          return null;
                                        }
                                        return AuthValidators.validateEmail(v);
                                      }
                                    : (_) => null,
                                isDark: isDark,
                              ),
                              SizedBox(height: fieldSpacing),
                              PhoneInputField(
                                key: _phoneInputKey,
                                controller: _phoneController,
                                selectedCountry: _selectedCountry,
                                onCountryChanged: (c) =>
                                    setState(() => _selectedCountry = c),
                                label: 'Phone Number',
                                enabled: _isEditing,
                                errorText: _phoneError,
                                validator: _isEditing
                                    ? (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return null;
                                        }
                                        return AuthValidators.validatePhone(
                                            value, _selectedCountry);
                                      }
                                    : (_) => null,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _handleSave(),
                                useTheme: true,
                                hideLabelAbove: false,
                                overrideBorderRadius: 10.0,
                                overrideBorderWidth: _isEditing ? 1.5 : 1.0,
                                overrideBgColor: isDark
                                    ? AppColors.blue700
                                    : AppColors.grey50,
                                overrideEnabledBorderColor: accentColor,
                                overrideDisabledBorderColor: _isEditing
                                    ? accentColor
                                    : (isDark
                                        ? AppColors.blue400
                                        : AppColors.grey600),
                                overrideLabelColor: isDark
                                    ? AppColors.grey100
                                    : AppColors.blue900,
                                overrideTextColor: isDark
                                    ? AppColors.grey50
                                    : AppColors.blue900,
                              ),
                              if (_isEditing) ...[
                                SizedBox(height: saveButtonTopSpacing),
                                CustomButton(
                                  text: 'Save Changes',
                                  onPressed: _handleSave,
                                  isLoading: isLoading,
                                  backgroundColor: accentColor,
                                  textColor:
                                      isDark ? AppColors.blue700 : Colors.white,
                                ),
                              ],
                              SizedBox(height: context.h(24)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Figma-style outlined field ──────────────────────────────────────────────
class _FigmaField extends StatelessWidget {
  const _FigmaField({
    required this.label,
    required this.controller,
    required this.enabled,
    required this.isDark,
    this.errorText,
    this.keyboardType,
    this.textInputAction,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;
  final bool isDark;
  final String? errorText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final fieldBg = isDark ? AppColors.blue700 : AppColors.grey50;
    final textColor = isDark ? AppColors.grey50 : AppColors.blue900;
    final labelColor = isDark ? AppColors.grey100 : AppColors.blue900;
    final viewBorderColor = isDark ? AppColors.blue400 : AppColors.grey600;
    final activeBorderColor =
        isDark ? AppColors.lightBlue500 : AppColors.lightBlue700;

    final hasError = errorText != null;
    final activeBorder = hasError
        ? AppColors.red600
        : enabled
            ? activeBorderColor
            : viewBorderColor;

    final borderWidth = enabled ? 1.5 : 1.0;

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(context.r(10.0)),
      borderSide: BorderSide(color: activeBorder, width: borderWidth),
    );

    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(context.r(10.0)),
      borderSide: BorderSide(
        color: hasError ? AppColors.red600 : activeBorderColor,
        width: 1.5,
      ),
    );

    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: context.sp(15),
        fontWeight: enabled ? FontWeight.w500 : FontWeight.w400,
        color: enabled ? textColor : textColor.withOpacity(0.45),
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: context.sp(13),
          color: labelColor,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: context.sp(12),
          color: hasError ? AppColors.red600 : activeBorder,
          fontWeight: FontWeight.w500,
        ),
        errorText: errorText,
        errorStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: context.sp(12),
          color: AppColors.red600,
        ),
        filled: true,
        fillColor: fieldBg,
        contentPadding: EdgeInsets.symmetric(
          horizontal: context.w(16),
          vertical: context.h(16),
        ),
        enabledBorder: border,
        focusedBorder: focusedBorder,
        disabledBorder: border,
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(context.r(10.0)),
          borderSide: const BorderSide(color: AppColors.red600, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(context.r(10.0)),
          borderSide: const BorderSide(color: AppColors.red600, width: 1.5),
        ),
      ),
    );
  }
}

// ─── Small reusable widgets ──────────────────────────────────────────────────
class _InfoHint extends StatelessWidget {
  const _InfoHint({required this.label, required this.isDark});

  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: context.w(16), top: context.h(4)),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: context.icon(14),
            color: AppColors.lightBlue700,
          ),
          SizedBox(width: context.w(4)),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: context.sp(12),
                color: isDark ? AppColors.grey400 : AppColors.grey800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

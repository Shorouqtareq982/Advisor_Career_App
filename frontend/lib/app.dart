import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_links/app_links.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/app_colors.dart';
import 'config/routes/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/services/auth_service.dart';
import 'features/settings/providers/theme_provider.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import '../../../../core/theme/app_text_theme.dart';
import '../../../../core/services/notification_service.dart';

class GrowzaApp extends ConsumerStatefulWidget {
  const GrowzaApp({super.key});

  @override
  ConsumerState<GrowzaApp> createState() => _GrowzaAppState();
}

class _GrowzaAppState extends ConsumerState<GrowzaApp> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  StreamSubscription<AuthState>? _authSubscription;
  final AuthService _authService = AuthService();

  bool _isProcessingOAuth = false;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();

    print('AuthService init: ${_authService.runtimeType}');

    // ── Notification tap → navigate ────────────────────────────────────────
    // FIX: استخدم setCallback بدل الـ direct assignment عشان يشغّل أي
    NotificationService.setCallback((payload) {
      if (_isNavigating) return;
      _isNavigating = true;

      // Add small delay to ensure router is ready
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) {
          _isNavigating = false;
          return;
        }

        try {
          if (payload.startsWith('interview_feedback:')) {
            final sessionId = payload.replaceFirst('interview_feedback:', '');
            AppRouter.router
                .push('/interview-feedback-detail', extra: sessionId);
          } else if (payload == 'job_results') {
            AppRouter.router.go('/recommended-jobs'); // ← ده صح
          } else if (payload == 'career_plan') {
            AppRouter.router.push('/career-build/plans');
          } else {
            AppRouter.router.go('/alerts');
          }
        } catch (e) {
          debugPrint('Navigation error: $e');
        }

        Future.delayed(const Duration(seconds: 2), () {
          _isNavigating = false;
        });
      });
    });

    _initDeepLinks();

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        print(' [AUTH] State changed: ${data.event}');
        if (data.event == AuthChangeEvent.signedIn) {
          print(' [AUTH] User signed in!');
          if (_isProcessingOAuth && mounted) {
            setState(() {
              _isProcessingOAuth = false;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              AppRouter.router.go('/');
            });
          }
        }
      },
    );
  }

  void _handleAuthStateChanged() {
    final authNotifier = ref.read(authProvider.notifier);
    final redirectPath = authNotifier.getRedirectPath();

    if (redirectPath != null && mounted) {
      print(' Auth state changed - redirecting to: $redirectPath');

      if (_isProcessingOAuth) {
        setState(() {
          _isProcessingOAuth = false;
        });
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 100), () {
          print('    Executing redirect to: $redirectPath');
          AppRouter.router.go(redirectPath);
        });
      });
    }
  }

  /// Initialize deep links
  Future<void> _initDeepLinks() async {
    print('[DEEP LINK] Initializing...');
    _appLinks = AppLinks();

    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        print(' [DEEP LINK] App opened with initial link');
        _handleDeepLink(initialUri);
      } else {
        print('[DEEP LINK] No initial link');
      }
    } catch (e) {
      print('   [DEEP LINK] Error getting initial link: $e');
    }

    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        print(' [DEEP LINK] Received link while running');
        _handleDeepLink(uri);
      },
      onError: (err) {
        print('   [DEEP LINK] Stream error: $err');
      },
    );

    print('    [DEEP LINK] Listener active');
  }

  /// Handle deep link navigation
  void _handleDeepLink(Uri uri) {
    print(' [DEEP LINK] Processing...');
    print('   Full URI: $uri');
    print('   Scheme: ${uri.scheme}');
    print('   Host: ${uri.host}');
    print('   Path: ${uri.path}');
    print('   Query: ${uri.query}');
    print('   Fragment: ${uri.fragment}');

    final params = uri.queryParameters;
    print('[DEEP LINK] Query Parameters:');
    if (params.isEmpty) {
      print('   (none)');
    } else {
      params.forEach((key, value) {
        if (key.contains('token') || key.contains('Token')) {
          print('   $key: ${value.substring(0, 20)}...');
        } else {
          print('   $key: $value');
        }
      });
    }

    // Check for fragment
    if (uri.fragment.isNotEmpty) {
      print(' [DEEP LINK] Fragment detected: ${uri.fragment}');

      final fragmentParams = Uri.splitQueryString(uri.fragment);
      print('[DEEP LINK] Fragment Parameters:');
      fragmentParams.forEach((key, value) {
        if (key.contains('token') || key.contains('Token')) {
          print('   $key: ${value.substring(0, 20)}...');
        } else {
          print('   $key: $value');
        }
      });

      final accessToken = fragmentParams['access_token'];
      final refreshToken = fragmentParams['refresh_token'];

      if (accessToken != null) {
        print('    [DEEP LINK] OAuth tokens found in fragment!');
        if (mounted) {
          setState(() {
            _isProcessingOAuth = true;
          });
        }
        return;
      }
    }

    // Handle login callback
    if (uri.host == 'login-callback') {
      print(' [DEEP LINK] Login callback detected');

      final accessToken = params['access_token'];
      final refreshToken = params['refresh_token'];
      final code = params['code'];
      final type = params['type'];
      final errorCode = params['error_code'];
      final errorDescription = params['error_description'];

      // Handle OAuth errors
      if (errorCode != null) {
        print('   [DEEP LINK] OAuth error!');
        print('   Code: $errorCode');
        print('   Description: $errorDescription');

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Future.delayed(const Duration(milliseconds: 100), () {
                AppRouter.router.go('/');
              });
            });
          }
        });
        return;
      }

      // Handle authorization code
      if (code != null) {
        print(
          '    [DEEP LINK] Authorization code detected: ${code.substring(0, 10)}...',
        );
        print('[DEEP LINK] Supabase SDK will exchange code automatically...');

        // Set flag to prevent unwanted navigation
        if (mounted) {
          setState(() {
            _isProcessingOAuth = true;
          });
        }

        Future.delayed(const Duration(seconds: 5), () {
          if (mounted && _isProcessingOAuth) {
            setState(() {
              _isProcessingOAuth = false;
            });
            print('  [DEEP LINK] OAuth timeout - clearing flag');
          }
        });

        return;
      }

      // Handle direct tokens
      if (accessToken != null && refreshToken != null) {
        print(' [DEEP LINK] OAuth tokens received!');
        if (mounted) {
          setState(() {
            _isProcessingOAuth = true;
          });
        }
        return;
      }

      // Handle email confirmation
      if (type == 'signup' || type == 'email_confirmation') {
        print('  [DEEP LINK] Email confirmation');

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Future.delayed(const Duration(milliseconds: 100), () {
                AppRouter.router.go('/sign-in');
              });
            });
          }
        });
        return;
      }

      print('  [DEEP LINK] No tokens or code in callback');
    }

    // Handle password reset
    else if (uri.host == 'reset-password') {
      print(' [DEEP LINK] Password reset callback');

      final token = params['token'];
      final type = params['type'];

      print('   Type: $type');
      print('   Has token: ${token != null}');

      if (token != null) {
        print('    [DEEP LINK] Navigating to new password screen');
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Future.delayed(const Duration(milliseconds: 100), () {
              AppRouter.router.go('/new-password');
            });
          });
        }
      }
    }

    // Unknown host
    else {
      print('  [DEEP LINK] Unknown host: ${uri.host}');
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthProviderState>(authProvider, (previous, next) {
      if (next.isAuthenticated && previous?.isAuthenticated == false) {
        print(' Auth state changed in listener - user just signed in');

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleAuthStateChanged();
        });
      }
    });

    final themeMode = ref.watch(themeProvider);

    if (_isProcessingOAuth) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        home: Scaffold(
          backgroundColor: const Color(0xFF2E3469),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;
              final isSmall = w < 360;
              final isTablet = w >= 600;
              final isDesktop = w >= 1024;

              final logoSize = isDesktop
                  ? 140.0
                  : isTablet
                      ? 120.0
                      : isSmall
                          ? 80.0
                          : 100.0;
              final ringOuter = isTablet ? 80.0 : 60.0;
              final ringInner = isTablet ? 66.0 : 50.0;
              final titleFontSize = isDesktop
                  ? 24.0
                  : isTablet
                      ? 22.0
                      : isSmall
                          ? 15.0
                          : 18.0;
              final subtitleFontSize = isTablet ? 16.0 : 14.0;
              final vSpacing = h * 0.07;
              final maxContentWidth = isDesktop ? 480.0 : double.infinity;

              return Stack(
                children: [
                  // Animated Background
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(seconds: 2),
                    builder: (context, value, child) {
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF2E3469),
                              Color.lerp(
                                const Color(0xFF2E3469),
                                const Color(0xFF1E2451),
                                value,
                              )!,
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // Content
                  SafeArea(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxContentWidth),
                        child: SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 48.0 : 24.0,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(height: vSpacing),

                                // Animated Logo with Pulse Effect
                                TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  duration: const Duration(milliseconds: 800),
                                  curve: Curves.elasticOut,
                                  builder: (context, value, child) {
                                    return Transform.scale(
                                      scale: 0.5 + (value * 0.5),
                                      child: Opacity(
                                        opacity: value,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: EdgeInsets.all(isTablet ? 28 : 20),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF6C63FF)
                                              .withOpacity(0.3),
                                          blurRadius: 40,
                                          spreadRadius: 10,
                                        ),
                                      ],
                                    ),
                                    child: Image.asset(
                                      'assets/images/branding/logo.png',
                                      width: logoSize,
                                      height: logoSize,
                                    ),
                                  ),
                                ),

                                SizedBox(height: vSpacing),

                                // Animated Loading Indicator
                                TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  duration: const Duration(milliseconds: 600),
                                  builder: (context, value, child) {
                                    return Opacity(
                                      opacity: value,
                                      child: child,
                                    );
                                  },
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // Outer Ring
                                      SizedBox(
                                        width: ringOuter,
                                        height: ringOuter,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 3,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            AppColors.grey50.withOpacity(0.3),
                                          ),
                                        ),
                                      ),
                                      // Inner Ring
                                      SizedBox(
                                        width: ringInner,
                                        height: ringInner,
                                        child: const CircularProgressIndicator(
                                          strokeWidth: 4,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            Color(0xFF6C63FF),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 32),

                                // Animated Text with Dots
                                _AnimatedLoadingText(fontSize: titleFontSize),

                                const SizedBox(height: 12),

                                // Subtitle
                                TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  duration: const Duration(milliseconds: 800),
                                  builder: (context, value, child) {
                                    return Opacity(
                                      opacity: value,
                                      child: child,
                                    );
                                  },
                                  child: Text(
                                    'Setting up your account...',
                                    style: TextStyle(
                                      color: AppColors.grey50.withOpacity(0.6),
                                      fontSize: subtitleFontSize,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'Inter',
                                      letterSpacing: 0.5,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),

                                const SizedBox(height: 40),

                                // Animated Progress Dots
                                const _AnimatedProgressDots(),

                                SizedBox(height: vSpacing),
                              ],
                            ),
                          ),
                        ),
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

    return MaterialApp.router(
      title: 'Growza',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme.copyWith(
        extensions: [
          AppTextThemeExtension(AppTextTheme.create()),
        ],
      ),
      darkTheme: AppTheme.darkTheme.copyWith(
        extensions: [
          AppTextThemeExtension(AppTextTheme.create()),
        ],
      ),
      themeMode: themeMode,
      routerConfig: AppRouter.router,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            viewInsets: EdgeInsets.fromViewPadding(
              View.of(context).viewInsets,
              View.of(context).devicePixelRatio,
            ),
          ),
          child: child!,
        );
      },
    );
  }
}

// Animated Loading Text Widget
class _AnimatedLoadingText extends StatefulWidget {
  final double fontSize;
  const _AnimatedLoadingText({this.fontSize = 18.0});

  @override
  State<_AnimatedLoadingText> createState() => _AnimatedLoadingTextState();
}

class _AnimatedLoadingTextState extends State<_AnimatedLoadingText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _dotCount = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..addListener(() {
        if (_controller.isCompleted) {
          setState(() {
            _dotCount = (_dotCount + 1) % 4;
          });
          _controller.reset();
          _controller.forward();
        }
      });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Text(
            'Completing sign in${"." * _dotCount}',
            style: TextStyle(
              color: AppColors.grey50,
              fontSize: widget.fontSize,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }
}

// Animated Progress Dots Widget
class _AnimatedProgressDots extends StatefulWidget {
  const _AnimatedProgressDots();

  @override
  State<_AnimatedProgressDots> createState() => _AnimatedProgressDotsState();
}

class _AnimatedProgressDotsState extends State<_AnimatedProgressDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1000),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (index) {
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final delay = index * 0.2;
                  final scale = 0.5 +
                      0.5 *
                          ((_controller.value - delay).clamp(0.0, 1.0) * 2.0)
                              .clamp(0.0, 1.0);

                  return Transform.scale(
                    scale: scale > 1.5 ? 2.0 - scale : scale,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C63FF),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6C63FF).withOpacity(0.5),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        );
      },
    );
  }
}

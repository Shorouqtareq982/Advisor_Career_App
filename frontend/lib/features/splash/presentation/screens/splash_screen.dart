import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/splash_panels.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  late final Animation<double> _panelsProgress;
  late final Animation<double> _logoProgress;

  static const double _panelsEnd = 0.85;
  static const double _logoStart = 0.85;
  static const Duration _splashDuration = Duration(milliseconds: 1800);

  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _controller = AnimationController(
      vsync: this,
      duration: _splashDuration,
    );

    _panelsProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, _panelsEnd, curve: Curves.easeInOutCubic),
    );

    _logoProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(_logoStart, 1.0, curve: Curves.easeOutBack),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted && !_navigated) {
        _navigated = true;
        _handoffToNext();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.forward(from: 0);
    });
  }

  Future<void> _handoffToNext() async {
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;

    final session = Supabase.instance.client.auth.currentSession;
    final isAuthenticated = session != null;

    if (!hasSeenOnboarding) {
      context.go('/onboarding');
      return;
    }

    if (isAuthenticated) {
      try {
        final container = ProviderScope.containerOf(context, listen: false);
        final authNotifier = container.read(authProvider.notifier);
        final redirectPath = authNotifier.getRedirectPath();
        context.go(redirectPath ?? '/home');
        return;
      } catch (_) {
        context.go('/home');
        return;
      }
    }

    context.go('/');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_navigated) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;

    final joinY = h * 0.50;
    final notchDepth = h * 0.06;

    final topVisibleStart = h * 0.22;
    final bottomVisibleStart = h * 0.23;

    return Scaffold(
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final topStart = -(h - topVisibleStart);
          final bottomStart = (h - bottomVisibleStart);

          final topTranslateY =
              lerpDouble(topStart, 0.0, _panelsProgress.value)!;
          final bottomTranslateY =
              lerpDouble(bottomStart, 0.0, _panelsProgress.value)!;

          final logoOpacity =
              Curves.easeInOut.transform(_logoProgress.value.clamp(0, 1));
          final logoScale = lerpDouble(0.92, 1.0, logoOpacity)!;

          return Stack(
            children: [
              SplashPanels(
                topTranslateY: topTranslateY,
                bottomTranslateY: bottomTranslateY,
                screenHeight: h,
                joinY: joinY,
                notchDepth: notchDepth,
              ),
              Positioned.fill(
                child: Align(
                  alignment: const Alignment(0, 0.02),
                  child: Opacity(
                    opacity: logoOpacity,
                    child: Transform.scale(
                      scale: logoScale,
                      child: SizedBox(
                        width: 180,
                        height: 210,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/images/branding/logo.png',
                              width: 110,
                              height: 110,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 110,
                                  height: 110,
                                  decoration: BoxDecoration(
                                    color:
                                        AppColors.lightBlue500.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.rocket_launch,
                                    size: 60,
                                    color: AppColors.lightBlue500,
                                  ),
                                );
                              },
                            ),
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
    );
  }
}

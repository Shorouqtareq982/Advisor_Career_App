import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';

import '../../features/home/presentation/widgets/home_bottom_nav.dart';

import '../../features/auth/presentation/screens/welcome_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/sign_in_screen.dart';
import '../../features/auth/presentation/screens/phone_sign_up_screen.dart';
import '../../features/auth/presentation/screens/otp_verification_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/auth/presentation/screens/new_password_screen.dart';
import '../../features/auth/presentation/screens/choose_verification_screen.dart';

import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';

import '../../features/profile/presentation/screens/profile_username_screen.dart';
import '../../features/profile/presentation/screens/profile_information_screen.dart';

import '../../features/home/presentation/screens/home_screen.dart'
    as home_screen;

import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/screens/settings_account_screen.dart';
import '../../features/settings/presentation/screens/support_screen.dart';

import '../../features/alerts/presentation/screens/alerts_screen.dart';

import '../../features/settings/presentation/screens/personal_info_screen.dart';
import '../../features/settings/presentation/screens/career_preferences_screen.dart';
import '../../features/settings/presentation/screens/change_password_screen.dart';
import '../../features/settings/presentation/screens/delete_account_screen.dart';

import '../../features/resume_optimization/presentation/screens/resume_optimization_screen.dart';
import '../../features/resume_optimization/presentation/screens/report_details_screen.dart';
import '../../features/resume_optimization/presentation/screens/start_optimization_screen.dart';

// // ── Career Build ─────────────────────────────────────────────────────
import '../../features/career_build/presentation/screens/career_builder_screen.dart';
import '../../features/career_build/presentation/screens/career_build_entry_screen.dart';
import '../../features/career_build/presentation/screens/create_plan_step1_screen.dart';
import '../../features/career_build/presentation/screens/create_plan_step2_screen.dart';
import '../../features/career_build/presentation/screens/create_plan_step3_screen.dart';
import '../../features/career_build/presentation/screens/create_plan_step4_screen.dart';
import '../../features/career_build/presentation/screens/career_plans_screen.dart';
import '../../features/career_build/presentation/screens/career_plan_view_screen.dart';

import '../../features/mock_interview/presentation/screens/mock_interview_screen.dart';
import '../../features/market_insight/presentation/screens/market_insights_screen.dart';

// // ── Ai Portfolio ─────────────────────────────────────────────────────
import '../../features/ai_portfolio/presentation/screens/ai_portfolio_entry_screen.dart';
import '../../features/ai_portfolio/presentation/screens/ai_portfolio_designs_screen.dart';
import '../../features/ai_portfolio/presentation/screens/ai_portfolio_preview_screen.dart';
import '../../features/ai_portfolio/presentation/screens/ai_portfolio_settings_screen.dart';
import '../../features/ai_portfolio/presentation/screens/ai_portfolio_section_details_screen.dart';
import '../../features/ai_portfolio/presentation/screens/ai_portfolio_my_portfolios_screen.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';

// // ── Job Matching ─────────────────────────────────────────────────────
import '../../features/job_matching/presentation/screens/job_preferences_gate.dart';
import '../../features/job_matching/presentation/screens/job_preferences_screen.dart';
import '../../features/job_matching/presentation/screens/recommended_jobs_screen.dart';
import '../../features/job_matching/presentation/screens/job_details_screen.dart';
import '../../features/job_matching/domain/entities/job_entity.dart';

// // ── Mock Interview ─────────────────────────────────────────────────────
import '../../features/mock_interview/presentation/screens/interview_feedback_screen.dart';
import '../../features/mock_interview/presentation/screens/interview_feedback_detail_screen.dart';
import '../../features/mock_interview/presentation/screens/interview_session_screen.dart';

Widget _withAuthTheme(BuildContext context, Widget child) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  if (isDark) return child;
  return Theme(data: AppTheme.lightTheme, child: child);
}

Widget _forceLightTheme(Widget child) {
  return Theme(data: AppTheme.lightTheme, child: child);
}

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    redirect: (context, state) async {
      final currentPath = state.uri.path;
      final currentFragment = state.uri.fragment;
      final fullLocation = state.uri.toString();

      final normalizedFragmentPath = currentFragment.startsWith('/')
          ? currentFragment.split('?').first
          : currentFragment.isNotEmpty
              ? '/${currentFragment.split('?').first}'
              : '';

      final effectivePath = normalizedFragmentPath.isNotEmpty
          ? normalizedFragmentPath
          : currentPath;

      final isPortfolioWebRoute =
          effectivePath.startsWith('/ai-portfolio/web/') ||
              currentFragment.contains('/ai-portfolio/web/') ||
              fullLocation.contains('/ai-portfolio/web/');

      if (isPortfolioWebRoute) {
        return null;
      }

      if (effectivePath == '/splash') return null;

      final prefs = await SharedPreferences.getInstance();
      final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;

      final session = Supabase.instance.client.auth.currentSession;
      final isAuthenticated = session != null;

      final publicRoutes = <String>{
        '/splash',
        '/onboarding',
        '/',
        '/sign-up',
        '/sign-in',
        '/phone-sign-up',
      };

      final passwordResetRoutes = <String>{
        '/forgot-password',
        '/choose-verification',
        '/reset-password',
        '/verify-code',
        '/new-password',
        '/otp-verification',
      };

      final isPublicRoute = publicRoutes.contains(currentPath);
      final isPasswordResetRoute = passwordResetRoutes.contains(currentPath);

      if (!hasSeenOnboarding &&
          currentPath != '/onboarding' &&
          currentPath != '/splash') {
        return '/onboarding';
      }

      if (currentPath == '/onboarding' && hasSeenOnboarding) {
        return isAuthenticated ? '/home' : '/';
      }

      if (!isAuthenticated && !isPublicRoute && !isPasswordResetRoute) {
        return '/splash';
      }

      if (isAuthenticated &&
          isPublicRoute &&
          currentPath != '/onboarding' &&
          currentPath != '/splash') {
        try {
          final container = ProviderScope.containerOf(context, listen: false);
          final authNotifier = container.read(authProvider.notifier);
          final redirectPath = authNotifier.getRedirectPath();
          return redirectPath ?? '/home';
        } catch (_) {
          return '/home';
        }
      }

      return null;
    },
    routes: [
      // ── Splash & Onboarding ───────────────────────────────
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),

      // ── Auth screens ─────────────────────────────────────
      GoRoute(
        path: '/',
        name: 'welcome',
        builder: (context, state) =>
            _withAuthTheme(context, const WelcomeScreen()),
      ),
      GoRoute(
        path: '/sign-up',
        name: 'sign-up',
        builder: (context, state) =>
            _withAuthTheme(context, const RegisterScreen()),
      ),
      GoRoute(
        path: '/sign-in',
        name: 'sign-in',
        builder: (context, state) =>
            _withAuthTheme(context, const SignInScreen()),
      ),
      GoRoute(
        path: '/phone-sign-up',
        name: 'phone-sign-up',
        builder: (context, state) =>
            _withAuthTheme(context, const PhoneSignUpScreen()),
      ),

      GoRoute(
        path: '/otp-verification',
        name: 'otp-verification',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final method = extra?['method'] as String? ?? 'phone';
          final contact = extra?['contact'] as String? ?? '';
          final type = extra?['type'] as String? ?? 'signup';
          final useTheme = extra?['useTheme'] as bool? ?? false;
          final provider = extra?['provider'] as String?;

          final screen = OtpVerificationScreen(
            method: method,
            contact: contact,
            type: type,
            useTheme: useTheme,
            provider: provider,
          );

          return useTheme ? screen : _withAuthTheme(context, screen);
        },
      ),

      GoRoute(
        path: '/choose-verification',
        name: 'choose-verification',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final useTheme = extra?['useTheme'] as bool? ?? false;
          final screen = ChooseVerificationScreen(useTheme: useTheme);
          return useTheme ? screen : _withAuthTheme(context, screen);
        },
      ),

      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final useTheme = extra?['useTheme'] as bool? ?? false;
          final screen = ChooseVerificationScreen(useTheme: useTheme);
          return useTheme ? screen : _withAuthTheme(context, screen);
        },
      ),

      GoRoute(
        path: '/reset-password',
        name: 'reset-password',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final method = extra?['method'] as String? ?? 'email';
          final useTheme = extra?['useTheme'] as bool? ?? false;

          final screen =
              ResetPasswordScreen(method: method, useTheme: useTheme);
          return useTheme ? screen : _withAuthTheme(context, screen);
        },
      ),

      GoRoute(
        path: '/verify-code',
        name: 'verify-code',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          if (extra == null) {
            return _withAuthTheme(
              context,
              const ChooseVerificationScreen(useTheme: false),
            );
          }
          final method = extra['method'] as String;
          final contact = extra['contact'] as String;
          final useTheme = extra['useTheme'] as bool? ?? false;

          final screen = OtpVerificationScreen(
            method: method,
            contact: contact,
            type: 'reset',
            useTheme: useTheme,
          );
          return useTheme ? screen : _withAuthTheme(context, screen);
        },
      ),

      GoRoute(
        path: '/new-password',
        name: 'new-password',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final useTheme = extra?['useTheme'] as bool? ?? false;

          final screen = NewPasswordScreen(
            email: extra?['email'] as String?,
            phone: extra?['phone'] as String?,
            useTheme: useTheme,
          );
          return useTheme ? screen : _withAuthTheme(context, screen);
        },
      ),

      GoRoute(
        path: '/profile-username',
        name: 'profile-username',
        builder: (context, state) =>
            _withAuthTheme(context, const ProfileUsernameScreen()),
      ),

      GoRoute(
        path: '/profile-information',
        name: 'profile-information',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final fromHome = extra?['fromHome'] as bool? ?? false;

          final screen = ProfileInformationScreen(fromHome: fromHome);
          return fromHome ? screen : _forceLightTheme(screen);
        },
      ),

      // ── Home & App screens ────────────────────────────────
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const home_screen.HomeScreen(),
      ),

      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),

      GoRoute(
        path: '/settings-account',
        name: 'settings-account',
        builder: (context, state) => const SettingsAccountScreen(),
      ),

      GoRoute(
        path: '/settings-security',
        name: 'settings-security',
        redirect: (context, state) => '/change-password',
      ),

      GoRoute(
        path: '/settings-support',
        name: 'settings-support',
        builder: (context, state) => const SupportScreen(),
      ),

      GoRoute(
        path: '/alerts',
        name: 'alerts',
        builder: (context, state) => const AlertsScreen(),
      ),

      // // ── Job Matching ──────────────────────────────────────────────────────
      GoRoute(
        path: '/jobs',
        name: 'jobs',
        builder: (context, state) => const JobPreferencesGate(),
      ),
      GoRoute(
        path: '/job-preferences',
        name: 'job-preferences',
        builder: (context, state) {
          final fromJobMatching = (state.extra
                  as Map<String, dynamic>?)?['fromJobMatching'] as bool? ??
              false;
          return JobPreferencesScreen(fromJobMatching: fromJobMatching);
        },
      ),
      GoRoute(
        path: '/recommended-jobs',
        name: 'recommended-jobs',
        builder: (context, state) => const RecommendedJobsScreen(),
      ),
      GoRoute(
        path: '/job-details',
        name: 'job-details',
        builder: (context, state) {
          final job = state.extra as JobEntity;
          return JobDetailsScreen(job: job);
        },
      ),

      GoRoute(
        path: '/profile',
        name: 'profile',
        redirect: (context, state) => '/settings',
      ),

      GoRoute(
        path: '/personal-info',
        name: 'personal-info',
        builder: (context, state) => const PersonalInfoScreen(),
      ),

      GoRoute(
        path: '/career-preferences',
        name: 'career-preferences',
        builder: (context, state) {
          final callback = state.extra as VoidCallback?;

          return CareerPreferencesScreen(
            onPreferencesSaved: callback,
          );
        },
      ),

      GoRoute(
        path: '/change-password',
        name: 'change-password',
        builder: (context, state) => const ChangePasswordScreen(),
      ),

      GoRoute(
        path: '/delete-account',
        name: 'delete-account',
        builder: (context, state) => const DeleteAccountScreen(),
      ),

      GoRoute(
        path: '/resume-optimization',
        name: 'resume-optimization',
        builder: (context, state) => const ResumeOptimizationScreen(),
      ),
      GoRoute(
        path: '/start-optimization',
        name: 'start-optimization',
        builder: (context, state) => const StartOptimizationScreen(),
      ),
      GoRoute(
        path: '/report-details/:reportId',
        name: 'report-details',
        builder: (context, state) {
          final reportId = state.pathParameters['reportId']!;
          return ReportDetailsScreen(reportId: reportId);
        },
      ),
      GoRoute(
        path: '/career-builder',
        name: 'career-builder',
        builder: (context, state) => const CareerBuilderScreen(),
      ),

      // // ── Mock Interview ──────────────────────────────────────────────────────
      GoRoute(
        path: '/career-build',
        name: 'career-build-entry',
        builder: (context, state) => const CareerBuildEntryScreen(),
      ),
      GoRoute(
        path: '/career-build/create/step-1',
        name: 'career-build-step-1',
        builder: (context, state) => const CreatePlanStep1Screen(),
      ),
      GoRoute(
        path: '/career-build/create/step-2',
        name: 'career-build-step-2',
        builder: (context, state) => const CreatePlanStep2Screen(),
      ),
      GoRoute(
        path: '/career-build/create/step-3',
        name: 'career-build-step-3',
        builder: (context, state) => const CreatePlanStep3Screen(),
      ),
      GoRoute(
        path: '/career-build/create/step-4',
        name: 'career-build-step-4',
        builder: (context, state) => const CreatePlanStep4Screen(),
      ),
      GoRoute(
        path: '/career-build/plans',
        name: 'career-build-plans',
        builder: (context, state) => const CareerPlansScreen(),
      ),
      GoRoute(
        path: '/career-build/plans/:id',
        name: 'career-build-plan-view',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';

          return CareerPlanViewScreen(
            planId: id,
          );
        },
      ),

      GoRoute(
        path: '/mock-interview',
        name: 'mock-interview',
        builder: (context, state) => const InterviewFeedbackScreen(),
      ),
      GoRoute(
        path: '/interview-session',
        name: 'interview-session',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return InterviewSessionScreen(
            roleName: extra['roleName'] as String,
            roleId: extra['roleId'] as String,
          );
        },
      ),
      GoRoute(
        path: '/interview-feedback-detail',
        name: 'interview-feedback-detail',
        builder: (context, state) {
          final sessionId = state.extra as String;
          return InterviewFeedbackDetailScreen(sessionId: sessionId);
        },
      ),

      GoRoute(
        path: '/market-insights',
        name: 'market-insights',
        builder: (context, state) => const MarketInsightsScreen(),
      ),

      // // ── Mock Interview ──────────────────────────────────────────────────────
      GoRoute(
        path: '/ai-portfolio',
        name: 'ai-portfolio',
        builder: (context, state) => const AIPortfolioEntryScreen(),
      ),
      GoRoute(
        path: '/ai-portfolio/designs',
        name: 'ai-portfolio-designs',
        builder: (context, state) => const AIPortfolioDesignsScreen(),
      ),
      GoRoute(
        path: '/ai-portfolio/preview',
        name: 'ai-portfolio-preview',
        builder: (context, state) => const AIPortfolioPreviewScreen(),
      ),
      GoRoute(
        path: '/ai-portfolio/settings',
        name: 'ai-portfolio-settings',
        builder: (context, state) => const AIPortfolioSettingsScreen(),
      ),
      GoRoute(
        path: '/ai-portfolio/my-portfolios',
        name: 'ai-portfolio-my-portfolios',
        builder: (context, state) => const AIPortfolioMyPortfoliosScreen(),
      ),
      GoRoute(
        path: '/ai-portfolio/section/:sectionKey',
        name: 'ai-portfolio-section',
        builder: (context, state) {
          final sectionKey = state.pathParameters['sectionKey'] ?? '';

          switch (sectionKey) {
            case 'about-me':
              return const AIPortfolioSectionDetailsScreen(
                title: 'About Me',
                subtitle: 'Tell your professional story',
              );

            case 'professional-experience':
              return const AIPortfolioSectionDetailsScreen(
                title: 'Professional Experience',
                subtitle: 'Where you worked and what you achieved',
              );

            case 'projects':
              return const AIPortfolioSectionDetailsScreen(
                title: 'Projects',
                subtitle: 'Showcase your best work',
              );

            case 'skills':
              return const AIPortfolioSectionDetailsScreen(
                title: 'Skills & Expertise',
                subtitle: 'Showcase your expertise',
              );

            case 'education':
              return const AIPortfolioSectionDetailsScreen(
                title: 'Education',
                subtitle: 'Your academic background',
              );

            case 'contact':
              return const AIPortfolioSectionDetailsScreen(
                title: 'Contact',
                subtitle: 'Let people reach you',
              );

            default:
              return const AIPortfolioSectionDetailsScreen(
                title: 'Section',
                subtitle: 'Portfolio section',
              );
          }
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: AppColors.blue500,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.grey50, size: 80),
            const SizedBox(height: 16),
            Text(
              '404 - Page Not Found',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.grey50,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'The page "${state.uri}" does not exist.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.grey200,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => GoRouter.of(context).go('/splash'),
              child: const Text('Go to Home'),
            ),
          ],
        ),
      ),
    ),
  );
}

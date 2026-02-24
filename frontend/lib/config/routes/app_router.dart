import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/welcome_screen.dart';
// import '../../features/auth/presentation/screens/login_screen.dart';
// import '../../features/auth/presentation/screens/register_screen.dart';
// ... باقي الـ imports

/// 🗺️ App Router - نظام التنقل في التطبيق
class AppRouter {
  AppRouter._();

  // ========================================
  // Route Names (أسماء الصفحات)
  // ========================================
  static const String welcome = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  // ... باقي الـ routes

  // ========================================
  // GoRouter Configuration
  // ========================================
  static final GoRouter router = GoRouter(
    initialLocation: welcome, // البداية من Welcome Screen
    debugLogDiagnostics: true,

    routes: [
      // ========================================
      // Welcome Screen (الصفحة الأولى)
      // ========================================
      GoRoute(
        path: welcome,
        name: 'welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),

      // ========================================
      // Login Screen
      // ========================================
      // GoRoute(
      //   path: login,
      //   name: 'login',
      //   builder: (context, state) => const LoginScreen(),
      // ),

      // ========================================
      // Register Screen
      // ========================================
      // GoRoute(
      //   path: register,
      //   name: 'register',
      //   builder: (context, state) => const RegisterScreen(),
      // ),

      // ========================================
      // Home Screen (بعد تسجيل الدخول)
      // ========================================
      // GoRoute(
      //   path: home,
      //   name: 'home',
      //   builder: (context, state) => const HomeScreen(),
      // ),

      // ... باقي الـ routes
    ],

    // ========================================
    // Error Page (لو حصل خطأ في التنقل)
    // ========================================
    errorBuilder: (context, state) =>
        Scaffold(body: Center(child: Text('Page not found: ${state.uri}'))),

    // ========================================
    // Redirect Logic (اختياري - للتحقق من المصادقة)
    // ========================================
    // redirect: (context, state) {
    //   final isAuthenticated = SupabaseService.isAuthenticated;
    //   final isGoingToAuth = state.matchedLocation == welcome ||
    //                          state.matchedLocation == login ||
    //                          state.matchedLocation == register;
    //
    //   // لو مش مسجل دخول وبيروح لصفحة محمية
    //   if (!isAuthenticated && !isGoingToAuth) {
    //     return welcome;
    //   }
    //
    //   // لو مسجل دخول وبيروح للـ auth pages
    //   if (isAuthenticated && isGoingToAuth) {
    //     return home;
    //   }
    //
    //   return null; // كمل عادي
    // },
  );
}

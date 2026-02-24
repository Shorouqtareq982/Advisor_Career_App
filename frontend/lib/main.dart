import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/services/supabase_service.dart';
import 'core/theme/app_theme.dart';
import 'config/routes/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ========================================
  // Initialize Supabase (موجود عندك من قبل)
  // ========================================
  await SupabaseService.initialize();

  // ========================================
  // تثبيت اتجاه الشاشة (Portrait فقط)
  // ========================================
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ========================================
  // تخصيص الـ Status Bar
  // ========================================
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Growza - Career Advisor',
      debugShowCheckedModeBanner: false,

      // ========================================
      // الثيمات (محدثة من app_theme.dart الجديد)
      // ========================================
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,

      // ========================================
      // الـ Router (موجود عندك من قبل)
      // ========================================
      routerConfig: AppRouter.router,
    );
  }
}

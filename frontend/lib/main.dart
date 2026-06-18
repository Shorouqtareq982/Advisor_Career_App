import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/services/supabase_service.dart';
import 'core/network/api_client.dart';
import 'core/services/notification_service.dart';
import 'core/services/app_notification_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: _firebaseOptions());
  debugPrint('FCM Background message: ${message.messageId}');
}

//  Firebase options لـ Android وiOS
FirebaseOptions _firebaseOptions() {
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    return const FirebaseOptions(
      apiKey: 'AIzaSyCXCx7-um3gxZEAS41LROEUYlfZ5giULxA',
      appId: '1:686018400273:ios:eaeb56a426718fac9221b0',
      messagingSenderId: '686018400273',
      projectId: 'growza-ca476',
      storageBucket: 'growza-ca476.firebasestorage.app',
      iosBundleId: 'com.example.growza',
    );
  }
  // Android (default)
  return const FirebaseOptions(
    apiKey: 'AIzaSyB-yL_KFQUpoV7BCnXQZBG97_ROOO1qAog',
    appId: '1:686018400273:android:de253c3ae1a934509221b0',
    messagingSenderId: '686018400273',
    projectId: 'growza-ca476',
    storageBucket: 'growza-ca476.firebasestorage.app',
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  //  Initialize Firebase
  await Firebase.initializeApp(options: _firebaseOptions());

  // Register background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  try {
    await SupabaseService.initialize();
    print('Supabase initialized successfully');
    apiClient.init();
    print('ApiClient initialized');
  } catch (e) {
    debugPrint('Failed to initialize Supabase: $e');
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF2E3469),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await NotificationService.instance.init();
  await NotificationService.instance.requestPermissions();
  await AppNotificationService.instance.init();

  runApp(
    const ProviderScope(
      child: GrowzaApp(),
    ),
  );

  _setupFCM();
}

Future<void> _setupFCM() async {
  try {
    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final token = await messaging.getToken();
    debugPrint('FCM Token: $token');

    if (token != null) {
      await _saveFcmToken(token);
    }

    messaging.onTokenRefresh.listen(_saveFcmToken);

    //  FCM foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('FCM message received: ${message.notification?.title}');
    });
  } catch (e, s) {
    debugPrint('FCM setup failed: $e');
    debugPrintStack(stackTrace: s);
  }
}

Future<void> saveFcmTokenForUser(String token) async {
  try {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('FCM: No user logged in — skipping token save');
      return;
    }

    await supabase.from('user_fcm_tokens').upsert(
      {
        'user_id': userId,
        'fcm_token': token,
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'user_id',
    );

    debugPrint('FCM token saved for user $userId');
  } catch (e) {
    debugPrint('FCM token save failed: $e');
  }
}

Future<void> _saveFcmToken(String token) => saveFcmTokenForUser(token);

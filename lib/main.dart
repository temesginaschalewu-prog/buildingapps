import 'dart:convert';
import 'dart:io' show Platform;

import 'package:familyacademyclient/app.dart';
import 'package:familyacademyclient/providers/auth_provider.dart';
import 'package:familyacademyclient/providers/category_provider.dart';
import 'package:familyacademyclient/providers/chatbot_provider.dart';
import 'package:familyacademyclient/providers/device_provider.dart';
import 'package:familyacademyclient/providers/notification_provider.dart';
import 'package:familyacademyclient/providers/payment_provider.dart';
import 'package:familyacademyclient/providers/school_provider.dart';
import 'package:familyacademyclient/providers/settings_provider.dart';
import 'package:familyacademyclient/providers/subscription_provider.dart';
import 'package:familyacademyclient/providers/theme_provider.dart';
import 'package:familyacademyclient/providers/user_provider.dart';
import 'package:familyacademyclient/providers/video_provider.dart';
import 'package:familyacademyclient/providers/exam_provider.dart';
import 'package:familyacademyclient/providers/streak_provider.dart';
import 'package:familyacademyclient/providers/exam_question_provider.dart';
import 'package:familyacademyclient/providers/chapter_provider.dart';
import 'package:familyacademyclient/providers/course_provider.dart';
import 'package:familyacademyclient/providers/note_provider.dart';
import 'package:familyacademyclient/providers/question_provider.dart';
import 'package:familyacademyclient/providers/parent_link_provider.dart';
import 'package:familyacademyclient/services/api_service.dart';
import 'package:familyacademyclient/services/storage_service.dart';
import 'package:familyacademyclient/services/notification_service.dart';
import 'package:familyacademyclient/utils/screen_protection.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");

  final prefs = await SharedPreferences.getInstance();
  final notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;

  if (!notificationsEnabled) {
    print("Notifications are disabled, skipping background notification");
    return;
  }

  final notificationService = NotificationService();
  await notificationService.init();

  await notificationService.showLocalNotification(
    title: message.notification?.title ?? 'Family Academy',
    body: message.notification?.body ?? '',
    payload: json.encode(message.data),
  );
}

class AppLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        ScreenProtectionService.enableOnResume();
        break;
      case AppLifecycleState.paused:
        ScreenProtectionService.disableOnPause();
        break;
      case AppLifecycleState.inactive:
        ScreenProtectionService.disableOnPause();
        break;
      default:
        break;
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  if (Platform.isAndroid || Platform.isIOS) {
    try {
      await Firebase.initializeApp();
      print("✅ Firebase initialized for mobile platform");

      final notificationService = NotificationService();
      await notificationService.init();
      await notificationService.setupFirebaseHandlers();

      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      final messaging = FirebaseMessaging.instance;

      final currentSettings = await messaging.getNotificationSettings();
      if (currentSettings.authorizationStatus ==
          AuthorizationStatus.notDetermined) {
        final settings = await messaging.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );

        print('User granted permission: ${settings.authorizationStatus}');
      }

      final token = await messaging.getToken();
      print("Firebase Messaging Token: $token");

      final prefs = await SharedPreferences.getInstance();
      if (token != null) {
        await prefs.setString('fcm_token', token);
        print("Saved FCM token to shared preferences");
      }
    } catch (e) {
      print('Firebase initialization failed: $e');
    }
  } else {
    print(
        "⚠️ Firebase not initialized for non-mobile platform (${Platform.operatingSystem})");
  }

  if (Platform.isAndroid || Platform.isIOS) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  await ScreenProtectionService.initialize();

  final storageService = StorageService();
  await storageService.init();
  print('Main: StorageService initialized');

  final apiService = ApiService();
  print('Main: ApiService created');

  final notificationService = NotificationService();
  await notificationService.init();
  print('Main: NotificationService initialized');

  final appLifecycleObserver = AppLifecycleObserver();
  WidgetsBinding.instance.addObserver(appLifecycleObserver);

  runApp(
    MultiProvider(
      providers: [
        // Add StorageService provider here
        Provider<StorageService>(
          create: (_) => storageService,
        ),

        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            apiService: apiService,
            storageService: storageService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => UserProvider(apiService: apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => DeviceProvider(apiService: apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => CategoryProvider(apiService: apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => SchoolProvider(apiService: apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => CourseProvider(apiService: apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => VideoProvider(apiService: apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => ExamProvider(apiService: apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => ExamQuestionProvider(apiService: apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => ChapterProvider(apiService: apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => NoteProvider(apiService: apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => QuestionProvider(apiService: apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => PaymentProvider(apiService: apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => SubscriptionProvider(apiService: apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => StreakProvider(apiService: apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => ParentLinkProvider(apiService: apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => NotificationProvider(apiService: apiService),
        ),
        ChangeNotifierProvider(create: (_) => ChatbotProvider()),
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(apiService: apiService),
        ),
      ],
      child: FamilyAcademyApp(
        notificationService: notificationService,
      ),
    ),
  );
}

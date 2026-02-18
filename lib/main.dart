import 'dart:async';
import 'dart:io';

import 'package:familyacademyclient/app.dart';
import 'package:familyacademyclient/providers/auth_provider.dart';
import 'package:familyacademyclient/providers/category_provider.dart';
import 'package:familyacademyclient/providers/chatbot_provider.dart';
import 'package:familyacademyclient/providers/device_provider.dart';
import 'package:familyacademyclient/providers/notification_provider.dart';
import 'package:familyacademyclient/providers/payment_provider.dart';
import 'package:familyacademyclient/providers/progress_provider.dart';
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
import 'package:familyacademyclient/services/device_service.dart';
import 'package:familyacademyclient/services/storage_service.dart';
import 'package:familyacademyclient/services/notification_service.dart';
import 'package:familyacademyclient/utils/screen_protection.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

// IMPORTANT: Fix MediaKit imports for cross-platform
import 'package:media_kit/media_kit.dart' as media_kit;

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    // Only initialize Firebase if on mobile
    if (Platform.isAndroid || Platform.isIOS) {
      await Firebase.initializeApp();
    }
    debugPrint("Handling a background message: ${message.messageId}");

    final prefs = await SharedPreferences.getInstance();
    final notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;

    if (!notificationsEnabled) {
      debugPrint(
          "Notifications are disabled, skipping background notification");
      return;
    }

    final notificationService = NotificationService();
    await notificationService.handleBackgroundMessage(message);
  } catch (e) {
    debugPrint('Background message handler error: $e');
  }
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

void _syncProviders(BuildContext context) {
  try {
    final subscriptionProvider =
        Provider.of<SubscriptionProvider>(context, listen: false);
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);

    subscriptionProvider.setCategoryProvider(categoryProvider);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    authProvider.registerOnLogoutCallback(() {
      categoryProvider.clearUserData();
      subscriptionProvider.clearUserData();
    });

    authProvider.registerOnLoginCallback(() async {
      await subscriptionProvider.loadSubscriptions();
      await categoryProvider.loadCategories();
    });

    debugPrint('Main ✅ Provider synchronization complete');
  } catch (e) {
    debugPrint('Main ❌ Provider synchronization error: $e');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // CRITICAL FIX: Initialize MediaKit with proper error handling for all platforms
  try {
    media_kit.MediaKit.ensureInitialized();
    debugPrint('Main ✅ MediaKit initialized successfully');
  } catch (e) {
    debugPrint('Main ⚠️ MediaKit initialization error (non-critical): $e');
  }

  // Better .env file loading with multiple fallback paths for Windows
  try {
    // Try multiple possible paths for the .env file
    const possiblePaths = [
      '.env',
      'assets/.env',
      'lib/.env',
      'data/flutter_assets/.env', // Windows build path
    ];

    bool envLoaded = false;

    for (final envPath in possiblePaths) {
      try {
        await dotenv.load(fileName: envPath);
        debugPrint('Main ✅ Loaded .env file from: $envPath');
        envLoaded = true;
        break;
      } catch (e) {
        debugPrint('Main ⚠️ Could not load .env from $envPath: $e');
      }
    }

    if (!envLoaded) {
      // Fallback to environment variables - no testLoad, just continue
      debugPrint('Main ⚠️ No .env file found, using default configuration');
      // Set default values in memory by loading from a string
      // This is a workaround - we'll just proceed without .env
      // The app will use hardcoded defaults from constants.dart
    }
  } catch (e) {
    debugPrint('Main ⚠️ Error loading .env: $e');
  }

  // Enable edge-to-edge on Android/iOS only
  if (Platform.isAndroid || Platform.isIOS) {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // Set status bar and navigation bar colors
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ));
  } else {
    // Windows/Linux - just set minimal UI
    try {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
          overlays: []);
    } catch (e) {
      debugPrint('Main ⚠️ System UI mode error: $e');
    }
  }

  // Initialize Firebase for mobile platforms ONLY
  FirebaseApp? firebaseApp;
  if (Platform.isAndroid || Platform.isIOS) {
    try {
      firebaseApp = await Firebase.initializeApp();
      debugPrint(
          "✅ Firebase initialized for mobile platform (${Platform.operatingSystem})");

      // Only initialize notification service for mobile platforms
      final notificationService = NotificationService();
      await notificationService.init();
      debugPrint('Main: NotificationService initialized for mobile');

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

        debugPrint('User granted permission: ${settings.authorizationStatus}');
      }

      final token = await messaging.getToken();
      debugPrint("Firebase Messaging Token: ${token?.substring(0, 20)}...");

      final prefs = await SharedPreferences.getInstance();
      if (token != null) {
        await prefs.setString('fcm_token', token);
        debugPrint("Saved FCM token to shared preferences");
      }
    } catch (e) {
      debugPrint('Firebase initialization failed: $e');
    }
  } else {
    debugPrint(
        "⚠️ Firebase not initialized for non-mobile platform (${Platform.operatingSystem}) - notifications will be local only");
    // Still initialize notification service for local notifications on Windows
    try {
      final notificationService = NotificationService();
      await notificationService.init();
      debugPrint(
          'Main: NotificationService initialized for local notifications');
    } catch (e) {
      debugPrint('Main ⚠️ Local notification init error: $e');
    }
  }

  // Initialize screen protection (safe for all platforms)
  try {
    await ScreenProtectionService.initialize();
  } catch (e) {
    debugPrint('Main ⚠️ Screen protection init error: $e');
  }

  // Initialize services IN ORDER with error handling
  final storageService = StorageService();
  try {
    await storageService.init();
    debugPrint('Main: StorageService initialized');
  } catch (e) {
    debugPrint('Main ⚠️ StorageService init error: $e');
  }

  final deviceService = DeviceService();
  try {
    await deviceService.init();
    debugPrint('Main: DeviceService initialized');
  } catch (e) {
    debugPrint('Main ⚠️ DeviceService init error: $e');
  }

  final apiService = ApiService();
  debugPrint('Main: ApiService created');

  final notificationService = NotificationService();

  final appLifecycleObserver = AppLifecycleObserver();
  WidgetsBinding.instance.addObserver(appLifecycleObserver);

  runApp(
    MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storageService),
        Provider<DeviceService>.value(value: deviceService),
        Provider<ApiService>.value(value: apiService),
        Provider<NotificationService>.value(value: notificationService),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(
          create: (context) => AuthProvider(
            apiService: context.read<ApiService>(),
            storageService: context.read<StorageService>(),
            deviceService: context.read<DeviceService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => UserProvider(
            apiService: context.read<ApiService>(),
            deviceService: context.read<DeviceService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => DeviceProvider(
            apiService: context.read<ApiService>(),
            deviceService: context.read<DeviceService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => CategoryProvider(
            apiService: context.read<ApiService>(),
            deviceService: context.read<DeviceService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => SchoolProvider(
            apiService: context.read<ApiService>(),
            deviceService: context.read<DeviceService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => CourseProvider(
            apiService: context.read<ApiService>(),
            deviceService: context.read<DeviceService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => VideoProvider(
            apiService: context.read<ApiService>(),
            deviceService: context.read<DeviceService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => ExamProvider(
            apiService: context.read<ApiService>(),
            deviceService: context.read<DeviceService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => ExamQuestionProvider(
            apiService: context.read<ApiService>(),
            deviceService: context.read<DeviceService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => ChapterProvider(
            apiService: context.read<ApiService>(),
            deviceService: context.read<DeviceService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => NoteProvider(
            apiService: context.read<ApiService>(),
            deviceService: context.read<DeviceService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => QuestionProvider(
            apiService: context.read<ApiService>(),
            deviceService: context.read<DeviceService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => PaymentProvider(
            apiService: context.read<ApiService>(),
            deviceService: context.read<DeviceService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => SubscriptionProvider(
            apiService: context.read<ApiService>(),
            deviceService: context.read<DeviceService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => StreakProvider(
            apiService: context.read<ApiService>(),
            deviceService: deviceService,
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => ParentLinkProvider(
            apiService: context.read<ApiService>(),
            deviceService: context.read<DeviceService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => NotificationProvider(
            apiService: context.read<ApiService>(),
            deviceService: context.read<DeviceService>(),
          ),
        ),
        ChangeNotifierProvider(create: (_) => ChatbotProvider()),
        ChangeNotifierProvider(
          create: (context) => SettingsProvider(
            apiService: context.read<ApiService>(),
            deviceService: context.read<DeviceService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => ProgressProvider(
            apiService: context.read<ApiService>(),
            streakProvider: StreakProvider(
                apiService: context.read<ApiService>(),
                deviceService: deviceService),
            deviceService: context.read<DeviceService>(),
          ),
        ),
      ],
      child: Builder(
        builder: (context) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _syncProviders(context);
          });

          return FamilyAcademyApp(
            apiService: apiService,
            notificationService: notificationService,
          );
        },
      ),
    ),
  );
}

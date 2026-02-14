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

// MediaKit import for desktop video playback
import 'package:media_kit/media_kit.dart' as media_kit;

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");

  final prefs = await SharedPreferences.getInstance();
  final notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;

  if (!notificationsEnabled) {
    debugPrint("Notifications are disabled, skipping background notification");
    return;
  }

  final notificationService = NotificationService();
  await notificationService.handleBackgroundMessage(message);
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

  // Initialize MediaKit for desktop platforms FIRST
  if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
    try {
      media_kit.MediaKit.ensureInitialized();
      debugPrint(
          '✅ MediaKit initialized for desktop (${Platform.operatingSystem})');
    } catch (e) {
      debugPrint('⚠️ MediaKit initialization error: $e');
    }
  }

  await dotenv.load(fileName: ".env");

  // Enable edge-to-edge on Android/iOS
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Set status bar and navigation bar colors
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
  ));

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
  }

  // Initialize screen protection
  await ScreenProtectionService.initialize();

  // Initialize services IN ORDER
  final storageService = StorageService();
  await storageService.init();
  debugPrint('Main: StorageService initialized');

  final deviceService = DeviceService();
  await deviceService.init(); // Wait for DeviceService to initialize
  debugPrint('Main: DeviceService initialized');

  final apiService = ApiService();
  debugPrint('Main: ApiService created');

  final notificationService = NotificationService();

  final appLifecycleObserver = AppLifecycleObserver();
  WidgetsBinding.instance.addObserver(appLifecycleObserver);

  runApp(
    MultiProvider(
      providers: [
        Provider<StorageService>(create: (_) => storageService),
        Provider<DeviceService>(create: (_) => deviceService),
        Provider<ApiService>(create: (_) => apiService),
        Provider<NotificationService>(create: (_) => notificationService),
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

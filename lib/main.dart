// lib/main.dart
// COMPLETE PRODUCTION-READY FILE - REPLACE ENTIRE FILE

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:familyacademyclient/app.dart';
import 'package:familyacademyclient/providers/theme_provider.dart';
import 'package:familyacademyclient/providers/auth_provider.dart';
import 'package:familyacademyclient/providers/device_provider.dart';
import 'package:familyacademyclient/providers/user_provider.dart';
import 'package:familyacademyclient/providers/school_provider.dart';
import 'package:familyacademyclient/providers/settings_provider.dart';
import 'package:familyacademyclient/providers/category_provider.dart';
import 'package:familyacademyclient/providers/subscription_provider.dart';
import 'package:familyacademyclient/providers/payment_provider.dart';
import 'package:familyacademyclient/providers/notification_provider.dart';
import 'package:familyacademyclient/providers/course_provider.dart';
import 'package:familyacademyclient/providers/chapter_provider.dart';
import 'package:familyacademyclient/providers/video_provider.dart';
import 'package:familyacademyclient/providers/note_provider.dart';
import 'package:familyacademyclient/providers/question_provider.dart';
import 'package:familyacademyclient/providers/exam_provider.dart';
import 'package:familyacademyclient/providers/streak_provider.dart';
import 'package:familyacademyclient/providers/progress_provider.dart';
import 'package:familyacademyclient/providers/chatbot_provider.dart';
import 'package:familyacademyclient/providers/exam_question_provider.dart';
import 'package:familyacademyclient/providers/parent_link_provider.dart';
import 'package:familyacademyclient/services/api_service.dart';
import 'package:familyacademyclient/services/device_service.dart';
import 'package:familyacademyclient/services/storage_service.dart';
import 'package:familyacademyclient/services/notification_service.dart';
import 'package:familyacademyclient/services/connectivity_service.dart';
import 'package:familyacademyclient/services/hive_service.dart';
import 'package:familyacademyclient/services/offline_queue_manager.dart';
import 'package:familyacademyclient/utils/platform_helper.dart'; // ✅ CHANGED
import 'package:familyacademyclient/utils/screen_protection.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:media_kit/media_kit.dart' as media_kit;

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('🔥 Background message received');
}

void main() async {
  debugPrint('🚀 APP STARTING - PRODUCTION MODE WITH FULL OFFLINE SUPPORT');
  PlatformHelper.logPlatformInfo(); // ✅ Using PlatformHelper

  WidgetsFlutterBinding.ensureInitialized();

  // Initialize MediaKit for ALL platforms
  try {
    media_kit.MediaKit.ensureInitialized();
    debugPrint('✅ MediaKit initialized successfully');
  } catch (e) {
    debugPrint('⚠️ MediaKit initialization error: $e');
  }

  // Initialize Hive
  try {
    await HiveService().init();
    debugPrint('✅ Hive initialized successfully');
  } catch (e) {
    debugPrint(
        '⚠️ Hive initialization error (continuing with memory-only mode): $e');
  }

  // Initialize Offline Queue Manager
  try {
    await OfflineQueueManager().initialize();
    debugPrint('✅ OfflineQueueManager initialized');
  } catch (e) {
    debugPrint(
        '⚠️ OfflineQueueManager initialization error (continuing with limited offline): $e');
  }

  // Initialize PlatformHelper
  await PlatformHelper.initialize();

  // Load environment variables
  try {
    await dotenv.load();
    debugPrint('✅ Environment loaded');
  } catch (e) {
    debugPrint('⚠️ No .env file found - using defaults');
  }

  // Initialize Firebase for mobile platforms
  if (PlatformHelper.isMobile) {
    // ✅ Using PlatformHelper
    try {
      await Firebase.initializeApp();
      debugPrint('✅ Firebase initialized');
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint('⚠️ Firebase error: $e');
    }
  }

  // Initialize screen protection for mobile
  if (PlatformHelper.isMobile) {
    // ✅ Using PlatformHelper
    try {
      await ScreenProtectionService.initialize();
      debugPrint('✅ Screen protection initialized');
    } catch (e) {
      debugPrint('⚠️ Screen protection error: $e');
    }
  }

  debugPrint('🔄 Initializing core services...');

  // STEP 1: Create service instances
  final storageService = StorageService();
  final deviceService = DeviceService();
  final connectivityService = ConnectivityService();
  final notificationService = NotificationService();
  final apiService = ApiService();
  final hiveService = HiveService();
  final offlineQueueManager = OfflineQueueManager();

  // STEP 2: Connect services to each other
  offlineQueueManager.setApiService(apiService);
  apiService.setOfflineQueueManager(offlineQueueManager);

  // STEP 3: Initialize ALL services in correct order
  try {
    await storageService.init().timeout(const Duration(seconds: 5));
    debugPrint('✅ StorageService initialized');

    await deviceService.init().timeout(const Duration(seconds: 5));
    debugPrint('✅ DeviceService initialized');

    storageService.setDeviceService(deviceService);
    storageService.setHiveService(hiveService);

    await connectivityService.initialize().timeout(const Duration(seconds: 5));
    debugPrint('✅ ConnectivityService initialized');

    notificationService.apiService = apiService;
    notificationService.connectivityService = connectivityService;
    await notificationService.init().timeout(const Duration(seconds: 5));
    debugPrint('✅ NotificationService initialized');
  } catch (e) {
    debugPrint('⚠️ Service initialization had non-critical errors: $e');
  }

  debugPrint('🎯 All services ready - launching app');

  runApp(
    MultiProvider(
      providers: [
        // Core Services
        Provider<ApiService>.value(value: apiService),
        Provider<NotificationService>.value(value: notificationService),
        Provider<StorageService>.value(value: storageService),
        Provider<DeviceService>.value(value: deviceService),
        Provider<ConnectivityService>.value(value: connectivityService),
        Provider<OfflineQueueManager>.value(value: offlineQueueManager),
        Provider<HiveService>.value(value: hiveService),

        // Theme Provider
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) =>
              ThemeProvider(connectivityService: connectivityService),
        ),

        // Auth Provider
        ChangeNotifierProvider<AuthProvider>(
          create: (context) => AuthProvider(
            apiService: context.read<ApiService>(),
            storageService: context.read<StorageService>(),
            deviceService: context.read<DeviceService>(),
            connectivityService: context.read<ConnectivityService>(),
            hiveService: context.read<HiveService>(),
            offlineQueueManager: context.read<OfflineQueueManager>(),
          ),
        ),

        // Device Provider
        ChangeNotifierProvider<DeviceProvider>(
          create: (context) => DeviceProvider(
            apiService: context.read<ApiService>(),
            deviceService: context.read<DeviceService>(),
            connectivityService: context.read<ConnectivityService>(),
            hiveService: context.read<HiveService>(),
          ),
        ),

        // User Provider
        ChangeNotifierProvider<UserProvider>(
          create: (context) => UserProvider(
            apiService: context.read<ApiService>(),
            deviceService: context.read<DeviceService>(),
            connectivityService: context.read<ConnectivityService>(),
            hiveService: context.read<HiveService>(),
            offlineQueueManager: context.read<OfflineQueueManager>(),
          ),
        ),

        // School Provider
        ChangeNotifierProvider<SchoolProvider>(
          create: (context) => SchoolProvider(
            apiService: context.read<ApiService>(),
            deviceService: context.read<DeviceService>(),
            connectivityService: context.read<ConnectivityService>(),
            hiveService: context.read<HiveService>(),
          ),
        ),

        // Settings Provider
        ChangeNotifierProvider<SettingsProvider>(
          create: (context) => SettingsProvider(
            apiService: context.read<ApiService>(),
            deviceService: context.read<DeviceService>(),
            connectivityService: context.read<ConnectivityService>(),
            hiveService: context.read<HiveService>(),
          ),
        ),

        // Category Provider
        ChangeNotifierProvider<CategoryProvider>(
          create: (context) => CategoryProvider(
            apiService: context.read<ApiService>(),
            deviceService: context.read<DeviceService>(),
            connectivityService: context.read<ConnectivityService>(),
            hiveService: context.read<HiveService>(),
          ),
        ),

        // Subscription Provider
        ChangeNotifierProvider<SubscriptionProvider>(
          create: (context) => SubscriptionProvider(
            apiService: context.read<ApiService>(),
            deviceService: context.read<DeviceService>(),
            connectivityService: context.read<ConnectivityService>(),
            hiveService: context.read<HiveService>(),
            offlineQueueManager: context.read<OfflineQueueManager>(),
          ),
        ),

        // Payment Provider
        ChangeNotifierProvider<PaymentProvider>(
          create: (context) => PaymentProvider(
            apiService: context.read<ApiService>(),
            deviceService: context.read<DeviceService>(),
            connectivityService: context.read<ConnectivityService>(),
            hiveService: context.read<HiveService>(),
            offlineQueueManager: context.read<OfflineQueueManager>(),
          ),
        ),

        // Notification Provider
        ChangeNotifierProvider<NotificationProvider>(
          create: (context) => NotificationProvider(
            apiService: context.read<ApiService>(),
            deviceService: context.read<DeviceService>(),
            connectivityService: context.read<ConnectivityService>(),
            hiveService: context.read<HiveService>(),
            offlineQueueManager: context.read<OfflineQueueManager>(),
          ),
        ),

        // Parent Link Provider
        ChangeNotifierProvider<ParentLinkProvider>(
          create: (context) => ParentLinkProvider(
            apiService: context.read<ApiService>(),
            deviceService: context.read<DeviceService>(),
            connectivityService: context.read<ConnectivityService>(),
            hiveService: context.read<HiveService>(),
            offlineQueueManager: context.read<OfflineQueueManager>(),
          ),
        ),

        // Course Provider
        ChangeNotifierProvider<CourseProvider>(
          create: (context) => CourseProvider(
            apiService: context.read<ApiService>(),
            deviceService: context.read<DeviceService>(),
            connectivityService: context.read<ConnectivityService>(),
            hiveService: context.read<HiveService>(),
          ),
        ),

        // Chapter Provider
        ChangeNotifierProvider<ChapterProvider>(
          create: (context) => ChapterProvider(
            apiService: context.read<ApiService>(),
            deviceService: context.read<DeviceService>(),
            connectivityService: context.read<ConnectivityService>(),
            hiveService: context.read<HiveService>(),
          ),
        ),

        // Video Provider
        ChangeNotifierProvider<VideoProvider>(
          create: (context) => VideoProvider(
            apiService: context.read<ApiService>(),
            deviceService: context.read<DeviceService>(),
            connectivityService: context.read<ConnectivityService>(),
            hiveService: context.read<HiveService>(),
            offlineQueueManager: context.read<OfflineQueueManager>(),
          ),
        ),

        // Note Provider
        ChangeNotifierProvider<NoteProvider>(
          create: (context) => NoteProvider(
            apiService: context.read<ApiService>(),
            deviceService: context.read<DeviceService>(),
            connectivityService: context.read<ConnectivityService>(),
            hiveService: context.read<HiveService>(),
          ),
        ),

        // Question Provider
        ChangeNotifierProvider<QuestionProvider>(
          create: (context) => QuestionProvider(
            apiService: context.read<ApiService>(),
            deviceService: context.read<DeviceService>(),
            connectivityService: context.read<ConnectivityService>(),
            hiveService: context.read<HiveService>(),
            offlineQueueManager: context.read<OfflineQueueManager>(),
          ),
        ),

        // Exam Provider
        ChangeNotifierProvider<ExamProvider>(
          create: (context) => ExamProvider(
            apiService: context.read<ApiService>(),
            deviceService: context.read<DeviceService>(),
            connectivityService: context.read<ConnectivityService>(),
            hiveService: context.read<HiveService>(),
            offlineQueueManager: context.read<OfflineQueueManager>(),
          ),
        ),

        // Exam Question Provider
        ChangeNotifierProvider<ExamQuestionProvider>(
          create: (context) => ExamQuestionProvider(
            apiService: context.read<ApiService>(),
            deviceService: context.read<DeviceService>(),
            connectivityService: context.read<ConnectivityService>(),
            hiveService: context.read<HiveService>(),
            offlineQueueManager: context.read<OfflineQueueManager>(),
          ),
        ),

        // Streak Provider
        ChangeNotifierProvider<StreakProvider>(
          create: (context) => StreakProvider(
            apiService: context.read<ApiService>(),
            deviceService: context.read<DeviceService>(),
            connectivityService: context.read<ConnectivityService>(),
            hiveService: context.read<HiveService>(),
            offlineQueueManager: context.read<OfflineQueueManager>(),
          ),
        ),

        // Progress Provider
        ChangeNotifierProvider<ProgressProvider>(
          create: (context) => ProgressProvider(
            apiService: context.read<ApiService>(),
            deviceService: context.read<DeviceService>(),
            streakProvider: context.read<StreakProvider>(),
            connectivityService: context.read<ConnectivityService>(),
            hiveService: context.read<HiveService>(),
            offlineQueueManager: context.read<OfflineQueueManager>(),
          ),
        ),

        // Chatbot Provider
        ChangeNotifierProvider<ChatbotProvider>(
          create: (context) => ChatbotProvider(
            apiService: context.read<ApiService>(),
            connectivityService: context.read<ConnectivityService>(),
            hiveService: context.read<HiveService>(),
            offlineQueueManager: context.read<OfflineQueueManager>(),
          ),
        ),
      ],
      child: FamilyAcademyApp(
        apiService: apiService,
        notificationService: notificationService,
      ),
    ),
  );

  debugPrint('✅ App launched successfully with full offline support');
}

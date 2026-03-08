import 'dart:io';
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
import 'package:familyacademyclient/services/platform_service.dart';
import 'package:familyacademyclient/utils/helpers.dart';
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
  debugPrint('🚀 APP STARTING - MAIN EXECUTED');
  PlatformService.logPlatformInfo();

  WidgetsFlutterBinding.ensureInitialized();

  if (!PlatformService.isLinux) {
    try {
      media_kit.MediaKit.ensureInitialized();
      debugPrint('✅ MediaKit initialized');
    } catch (e) {
      debugPrint('⚠️ MediaKit error: $e');
    }
  } else {
    debugPrint('ℹ️ MediaKit skipped on Linux');
  }

  try {
    await dotenv.load(fileName: '.env');
    debugPrint('✅ Environment loaded');
  } catch (e) {
    debugPrint('⚠️ No .env file found');
  }

  if (PlatformService.shouldUseFirebase) {
    try {
      await Firebase.initializeApp();
      debugPrint('✅ Firebase initialized');
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint('⚠️ Firebase error: $e');
    }
  }

  if (PlatformService.shouldUseScreenProtection) {
    try {
      await ScreenProtectionService.initialize();
      debugPrint('✅ Screen protection initialized');
    } catch (e) {
      debugPrint('⚠️ Screen protection error: $e');
    }
  }

  debugPrint('🔄 Creating services...');

  final storageService = StorageService();
  final deviceService = DeviceService();
  final connectivityService = ConnectivityService();
  final notificationService = NotificationService();
  final apiService = ApiService();

  // CONNECT STORAGE AND DEVICE SERVICES
  storageService.setDeviceService(deviceService);

  notificationService.apiService = apiService;

  if (PlatformService.shouldAwaitServices) {
    debugPrint('📱 Mobile mode - awaiting services');
    try {
      await Future.wait([
        storageService.init().timeout(const Duration(seconds: 5)),
        deviceService.init().timeout(const Duration(seconds: 5)),
        connectivityService.initialize().timeout(const Duration(seconds: 5)),
        notificationService.init().timeout(const Duration(seconds: 5)),
      ]).catchError((e) {
        debugPrint('⚠️ Service initialization error: $e');
      });
    } catch (e) {
      debugPrint('❌ Service initialization failed: $e');
    }
  } else {
    debugPrint('🖥️ Desktop mode - background initialization');
    storageService.init().then((_) => debugLog('Main', 'Storage initialized'));
    deviceService.init().then((_) => debugLog('Main', 'Device initialized'));
    notificationService.init(forceMinimal: true);
    connectivityService.setMockOnline(true);
  }

  debugPrint('🎯 About to call runApp');

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiService>.value(value: apiService),
        Provider<NotificationService>.value(value: notificationService),
        Provider<StorageService>.value(value: storageService),
        Provider<DeviceService>.value(value: deviceService),
        Provider<ConnectivityService>.value(value: connectivityService),
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) =>
              ThemeProvider(connectivityService: connectivityService),
        ),
        ChangeNotifierProvider<AuthProvider>(
          create: (context) => AuthProvider(
            apiService: context.read<ApiService>(),
            storageService: context.read<StorageService>(),
            deviceService: context.read<DeviceService>(),
            connectivityService: context.read<ConnectivityService>(),
          ),
        ),
        ChangeNotifierProvider<DeviceProvider>(
          create: (context) => DeviceProvider(
            apiService: context.read<ApiService>(),
            deviceService: context.read<DeviceService>(),
            connectivityService: context.read<ConnectivityService>(),
          ),
        ),
        ChangeNotifierProvider<UserProvider>(
          create: (context) => UserProvider(
            apiService: context.read<ApiService>(),
            deviceService: context.read<DeviceService>(),
            connectivityService: context.read<ConnectivityService>(),
          ),
        ),
        ChangeNotifierProvider<SchoolProvider>(
          create: (context) => SchoolProvider(
            apiService: context.read<ApiService>(),
            deviceService: context.read<DeviceService>(),
            connectivityService: context.read<ConnectivityService>(),
          ),
        ),
        ChangeNotifierProvider<SettingsProvider>(
          create: (context) => SettingsProvider(
            apiService: context.read<ApiService>(),
            deviceService: context.read<DeviceService>(),
            connectivityService: context.read<ConnectivityService>(),
          ),
        ),
        ChangeNotifierProvider<CategoryProvider>(
          create: (context) => CategoryProvider(
            apiService: context.read<ApiService>(),
            deviceService: context.read<DeviceService>(),
            connectivityService: context.read<ConnectivityService>(),
          ),
        ),
        ChangeNotifierProvider<SubscriptionProvider>(
          create: (context) => SubscriptionProvider(
            apiService: context.read<ApiService>(),
            deviceService: context.read<DeviceService>(),
            connectivityService: context.read<ConnectivityService>(),
          ),
        ),
        ChangeNotifierProvider<PaymentProvider>(
          create: (context) => PaymentProvider(
            apiService: context.read<ApiService>(),
            deviceService: context.read<DeviceService>(),
            connectivityService: context.read<ConnectivityService>(),
          ),
        ),
        ChangeNotifierProvider<NotificationProvider>(
          create: (context) => NotificationProvider(
            apiService: context.read<ApiService>(),
            deviceService: context.read<DeviceService>(),
            connectivityService: context.read<ConnectivityService>(),
          ),
        ),
        ChangeNotifierProvider<ParentLinkProvider>(
          create: (context) => ParentLinkProvider(
            apiService: context.read<ApiService>(),
            deviceService: context.read<DeviceService>(),
            connectivityService: context.read<ConnectivityService>(),
          ),
        ),
        ChangeNotifierProvider<CourseProvider>(
          create: (context) => CourseProvider(
            apiService: context.read<ApiService>(),
            deviceService: context.read<DeviceService>(),
            connectivityService: context.read<ConnectivityService>(),
          ),
        ),
        ChangeNotifierProvider<ChapterProvider>(
          create: (context) => ChapterProvider(
            apiService: context.read<ApiService>(),
            deviceService: context.read<DeviceService>(),
            connectivityService: context.read<ConnectivityService>(),
          ),
        ),
        ChangeNotifierProvider<VideoProvider>(
          create: (context) => VideoProvider(
            apiService: context.read<ApiService>(),
            deviceService: context.read<DeviceService>(),
            connectivityService: context.read<ConnectivityService>(),
          ),
        ),
        ChangeNotifierProvider<NoteProvider>(
          create: (context) => NoteProvider(
            apiService: context.read<ApiService>(),
            deviceService: context.read<DeviceService>(),
            connectivityService: context.read<ConnectivityService>(),
          ),
        ),
        ChangeNotifierProvider<QuestionProvider>(
          create: (context) => QuestionProvider(
            apiService: context.read<ApiService>(),
            deviceService: context.read<DeviceService>(),
            connectivityService: context.read<ConnectivityService>(),
          ),
        ),
        ChangeNotifierProvider<ExamProvider>(
          create: (context) => ExamProvider(
            apiService: context.read<ApiService>(),
            deviceService: context.read<DeviceService>(),
            connectivityService: context.read<ConnectivityService>(),
          ),
        ),
        ChangeNotifierProvider<ExamQuestionProvider>(
          create: (context) => ExamQuestionProvider(
            apiService: context.read<ApiService>(),
            deviceService: context.read<DeviceService>(),
            connectivityService: context.read<ConnectivityService>(),
          ),
        ),
        ChangeNotifierProvider<StreakProvider>(
          create: (context) => StreakProvider(
            apiService: context.read<ApiService>(),
            deviceService: context.read<DeviceService>(),
            connectivityService: context.read<ConnectivityService>(),
          ),
        ),
        ChangeNotifierProvider<ProgressProvider>(
          create: (context) => ProgressProvider(
            apiService: context.read<ApiService>(),
            deviceService: context.read<DeviceService>(),
            streakProvider: context.read<StreakProvider>(),
            connectivityService: context.read<ConnectivityService>(),
          ),
        ),
        ChangeNotifierProvider<ChatbotProvider>(
          create: (context) => ChatbotProvider(
            apiService: context.read<ApiService>(),
            connectivityService: context.read<ConnectivityService>(),
          ),
        ),
      ],
      child: FamilyAcademyApp(
        apiService: apiService,
        notificationService: notificationService,
      ),
    ),
  );

  debugPrint('✅ runApp completed');
}

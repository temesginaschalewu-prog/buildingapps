import 'dart:async';

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
import 'package:familyacademyclient/utils/helpers.dart';
import 'package:familyacademyclient/utils/platform_helper.dart';
import 'package:familyacademyclient/utils/screen_protection.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:media_kit/media_kit.dart' as media_kit;

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await HiveService().init();
  } catch (e) {
    debugLog('Main', 'Hive initialization fallback: $e');
  }

  // Initialize PlatformHelper
  await PlatformHelper.initialize();

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
      ],
      child: _SessionScopedProviders(
        apiService: apiService,
        notificationService: notificationService,
      ),
    ),
  );

  unawaited(
    _bootstrapCoreServices(
      storageService: storageService,
      deviceService: deviceService,
      connectivityService: connectivityService,
      notificationService: notificationService,
      apiService: apiService,
      hiveService: hiveService,
      offlineQueueManager: offlineQueueManager,
    ),
  );
}

Future<void> _bootstrapCoreServices({
  required StorageService storageService,
  required DeviceService deviceService,
  required ConnectivityService connectivityService,
  required NotificationService notificationService,
  required ApiService apiService,
  required HiveService hiveService,
  required OfflineQueueManager offlineQueueManager,
}) async {
  try {
    media_kit.MediaKit.ensureInitialized();
  } catch (e) {
    debugLog('Main', 'MediaKit initialization fallback: $e');
  }

  try {
    await offlineQueueManager.initialize();
  } catch (e) {
    debugLog('Main', 'Offline queue initialization fallback: $e');
  }

  try {
    await dotenv.load();
  } catch (e) {
    debugLog('Main', 'Environment defaults in use');
  }

  if (PlatformHelper.isAndroid ||
      PlatformHelper.isIOS ||
      PlatformHelper.isMacOS) {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
    } catch (e) {
      debugLog('Main', 'Firebase initialization fallback: $e');
    }
  }

  if (PlatformHelper.isMobile) {
    try {
      await ScreenProtectionService.initialize();
    } catch (e) {
      debugLog('Main', 'Screen protection initialization fallback: $e');
    }
  }

  try {
    await storageService.init().timeout(const Duration(seconds: 5));

    await deviceService.init().timeout(const Duration(seconds: 5));

    storageService.setDeviceService(deviceService);
    storageService.setHiveService(hiveService);

    await connectivityService.initialize().timeout(const Duration(seconds: 5));

    notificationService.apiService = apiService;
    notificationService.connectivityService = connectivityService;
    await notificationService.init().timeout(const Duration(seconds: 5));
  } catch (e) {
    debugLog('Main', 'Core service initialization fallback: $e');
  }
}

class _SessionScopedProviders extends StatelessWidget {
  final ApiService apiService;
  final NotificationService notificationService;

  const _SessionScopedProviders({
    required this.apiService,
    required this.notificationService,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final sessionScopeKey = ValueKey<String>(
      authProvider.currentUser?.id.toString() ?? 'guest',
    );

    return KeyedSubtree(
      key: sessionScopeKey,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<UserProvider>(
            create: (context) => UserProvider(
              apiService: context.read<ApiService>(),
              deviceService: context.read<DeviceService>(),
              connectivityService: context.read<ConnectivityService>(),
              hiveService: context.read<HiveService>(),
              offlineQueueManager: context.read<OfflineQueueManager>(),
            ),
          ),
          ChangeNotifierProvider<SchoolProvider>(
            create: (context) => SchoolProvider(
              apiService: context.read<ApiService>(),
              deviceService: context.read<DeviceService>(),
              connectivityService: context.read<ConnectivityService>(),
              hiveService: context.read<HiveService>(),
            ),
          ),
          ChangeNotifierProvider<SettingsProvider>(
            create: (context) => SettingsProvider(
              apiService: context.read<ApiService>(),
              deviceService: context.read<DeviceService>(),
              connectivityService: context.read<ConnectivityService>(),
              hiveService: context.read<HiveService>(),
            ),
          ),
          ChangeNotifierProvider<CategoryProvider>(
            create: (context) => CategoryProvider(
              apiService: context.read<ApiService>(),
              deviceService: context.read<DeviceService>(),
              connectivityService: context.read<ConnectivityService>(),
              hiveService: context.read<HiveService>(),
            ),
          ),
          ChangeNotifierProvider<SubscriptionProvider>(
            create: (context) => SubscriptionProvider(
              apiService: context.read<ApiService>(),
              deviceService: context.read<DeviceService>(),
              connectivityService: context.read<ConnectivityService>(),
              hiveService: context.read<HiveService>(),
              offlineQueueManager: context.read<OfflineQueueManager>(),
            ),
          ),
          ChangeNotifierProvider<PaymentProvider>(
            create: (context) => PaymentProvider(
              apiService: context.read<ApiService>(),
              deviceService: context.read<DeviceService>(),
              connectivityService: context.read<ConnectivityService>(),
              hiveService: context.read<HiveService>(),
              offlineQueueManager: context.read<OfflineQueueManager>(),
            ),
          ),
          ChangeNotifierProvider<NotificationProvider>(
            create: (context) => NotificationProvider(
              apiService: context.read<ApiService>(),
              deviceService: context.read<DeviceService>(),
              connectivityService: context.read<ConnectivityService>(),
              hiveService: context.read<HiveService>(),
              offlineQueueManager: context.read<OfflineQueueManager>(),
            ),
          ),
          ChangeNotifierProvider<ParentLinkProvider>(
            create: (context) => ParentLinkProvider(
              apiService: context.read<ApiService>(),
              deviceService: context.read<DeviceService>(),
              connectivityService: context.read<ConnectivityService>(),
              hiveService: context.read<HiveService>(),
              offlineQueueManager: context.read<OfflineQueueManager>(),
            ),
          ),
          ChangeNotifierProvider<CourseProvider>(
            create: (context) => CourseProvider(
              apiService: context.read<ApiService>(),
              deviceService: context.read<DeviceService>(),
              connectivityService: context.read<ConnectivityService>(),
              hiveService: context.read<HiveService>(),
            ),
          ),
          ChangeNotifierProvider<ChapterProvider>(
            create: (context) => ChapterProvider(
              apiService: context.read<ApiService>(),
              deviceService: context.read<DeviceService>(),
              connectivityService: context.read<ConnectivityService>(),
              hiveService: context.read<HiveService>(),
            ),
          ),
          ChangeNotifierProvider<VideoProvider>(
            create: (context) => VideoProvider(
              apiService: context.read<ApiService>(),
              deviceService: context.read<DeviceService>(),
              connectivityService: context.read<ConnectivityService>(),
              hiveService: context.read<HiveService>(),
              offlineQueueManager: context.read<OfflineQueueManager>(),
            ),
          ),
          ChangeNotifierProvider<NoteProvider>(
            create: (context) => NoteProvider(
              apiService: context.read<ApiService>(),
              deviceService: context.read<DeviceService>(),
              connectivityService: context.read<ConnectivityService>(),
              hiveService: context.read<HiveService>(),
            ),
          ),
          ChangeNotifierProvider<QuestionProvider>(
            create: (context) => QuestionProvider(
              apiService: context.read<ApiService>(),
              deviceService: context.read<DeviceService>(),
              connectivityService: context.read<ConnectivityService>(),
              hiveService: context.read<HiveService>(),
              offlineQueueManager: context.read<OfflineQueueManager>(),
            ),
          ),
          ChangeNotifierProvider<ExamProvider>(
            create: (context) => ExamProvider(
              apiService: context.read<ApiService>(),
              deviceService: context.read<DeviceService>(),
              connectivityService: context.read<ConnectivityService>(),
              hiveService: context.read<HiveService>(),
              offlineQueueManager: context.read<OfflineQueueManager>(),
            ),
          ),
          ChangeNotifierProvider<ExamQuestionProvider>(
            create: (context) => ExamQuestionProvider(
              apiService: context.read<ApiService>(),
              deviceService: context.read<DeviceService>(),
              connectivityService: context.read<ConnectivityService>(),
              hiveService: context.read<HiveService>(),
              offlineQueueManager: context.read<OfflineQueueManager>(),
            ),
          ),
          ChangeNotifierProvider<StreakProvider>(
            create: (context) => StreakProvider(
              apiService: context.read<ApiService>(),
              deviceService: context.read<DeviceService>(),
              connectivityService: context.read<ConnectivityService>(),
              hiveService: context.read<HiveService>(),
              offlineQueueManager: context.read<OfflineQueueManager>(),
            ),
          ),
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
          ChangeNotifierProvider<ChatbotProvider>(
            create: (context) => ChatbotProvider(
              apiService: context.read<ApiService>(),
              connectivityService: context.read<ConnectivityService>(),
              hiveService: context.read<HiveService>(),
              offlineQueueManager: context.read<OfflineQueueManager>(),
              settingsProvider: context.read<SettingsProvider>(),
            ),
          ),
        ],
        child: FamilyAcademyApp(
          apiService: apiService,
          notificationService: notificationService,
        ),
      ),
    );
  }
}

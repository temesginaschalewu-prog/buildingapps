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
import 'package:familyacademyclient/utils/helpers.dart';
import 'package:familyacademyclient/utils/screen_protection.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:media_kit/media_kit.dart' as media_kit;

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Platform.isAndroid || Platform.isIOS) {
      await Firebase.initializeApp();
    }

    final prefs = await SharedPreferences.getInstance();
    final notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    if (!notificationsEnabled) return;

    final notificationService = NotificationService();
    await notificationService.handleBackgroundMessage(message);
  } catch (e) {}
}

class AppLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        ScreenProtectionService.enableOnResume();
        _handleAppResumed();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        ScreenProtectionService.disableOnPause();
        break;
      default:
        break;
    }
  }

  Future<void> _handleAppResumed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationService = NotificationService();
      final newToken = await notificationService.getFCMToken();
      final oldToken = prefs.getString('fcm_token');

      if (newToken != null && newToken != oldToken) {
        final context = _getContext();
        if (context != null) {
          final authProvider =
              Provider.of<AuthProvider>(context, listen: false);
          if (authProvider.isAuthenticated) {
            final apiService = Provider.of<ApiService>(context, listen: false);
            await apiService.updateFcmToken(newToken);
            await prefs.setString('fcm_token', newToken);
            debugLog('AppLifecycle', 'FCM token refreshed on resume');
          }
        }
      }
    } catch (e) {
      debugLog('AppLifecycle', 'Error refreshing token: $e');
    }
  }

  BuildContext? _getContext() {
    return _appContext;
  }
}

BuildContext? _appContext;

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

      final notificationService = NotificationService();
      final fcmToken = await notificationService.getFCMToken();
      if (fcmToken != null) {
        final apiService = Provider.of<ApiService>(context, listen: false);
        await apiService.updateFcmToken(fcmToken);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', fcmToken);
      }
    });

    authProvider.deviceChangeRequired.listen((requiresChange) {
      if (requiresChange && context.mounted) {
        _showDeviceChangeDialog(context);
      }
    });

    authProvider.deviceDeactivated.listen((message) {
      if (message != null && context.mounted) {
        _showDeviceDeactivatedDialog(context, message);
      }
    });
  } catch (e) {}
}

void _showDeviceChangeDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Device Change Required'),
      content: const Text(
          'You are trying to login from a new device. This requires approval.'),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();

            Navigator.of(context).pushNamed('/device-change');
          },
          child: const Text('Continue'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            Provider.of<AuthProvider>(context, listen: false).logout();
          },
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
}

void _showDeviceDeactivatedDialog(BuildContext context, String message) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Device Deactivated'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            Provider.of<AuthProvider>(context, listen: false).logout();
          },
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    media_kit.MediaKit.ensureInitialized();

    if (Platform.isAndroid) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    debugLog('Main', 'MediaKit initialized successfully');
  } catch (e) {
    debugLog('Main', 'MediaKit init error: $e');
  }

  try {
    const possiblePaths = [
      '.env',
      'assets/.env',
      'lib/.env',
      'data/flutter_assets/.env'
    ];
    bool envLoaded = false;
    for (final envPath in possiblePaths) {
      try {
        await dotenv.load(fileName: envPath);
        envLoaded = true;
        break;
      } catch (e) {}
    }
    if (!envLoaded) {}
  } catch (e) {}

  if (Platform.isAndroid || Platform.isIOS) {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ));
  } else {
    try {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
          overlays: []);
    } catch (e) {}
  }

  FirebaseApp? firebaseApp;
  final notificationService = NotificationService();

  if (Platform.isAndroid || Platform.isIOS) {
    try {
      firebaseApp = await Firebase.initializeApp();
      await notificationService.init();

      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      final messaging = FirebaseMessaging.instance;
      final currentSettings = await messaging.getNotificationSettings();
      if (currentSettings.authorizationStatus ==
          AuthorizationStatus.notDetermined) {
        await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      final token = await messaging.getToken();
      final prefs = await SharedPreferences.getInstance();
      if (token != null) {
        await prefs.setString('fcm_token', token);
        debugLog('Main', 'FCM token saved: ${token.substring(0, 20)}...');
      }
    } catch (e) {
      debugLog('Main', 'Firebase init error: $e');
    }
  } else {
    try {
      await notificationService.init();
    } catch (e) {}
  }

  try {
    await ScreenProtectionService.initialize();
  } catch (e) {}

  final storageService = StorageService();
  try {
    await storageService.init();
  } catch (e) {}

  final deviceService = DeviceService();
  try {
    await deviceService.init();
  } catch (e) {}

  final apiService = ApiService();

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
        ChangeNotifierProvider(
          create: (context) => ChatbotProvider(
            apiService: context.read<ApiService>(),
          ),
        ),
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
              deviceService: deviceService,
            ),
            deviceService: context.read<DeviceService>(),
          ),
        ),
      ],
      child: Builder(
        builder: (context) {
          _appContext = context;
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _syncProviders(context));
          return FamilyAcademyApp(
            apiService: apiService,
            notificationService: notificationService,
          );
        },
      ),
    ),
  );
}

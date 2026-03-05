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
import 'package:familyacademyclient/services/user_session.dart';
import 'package:familyacademyclient/services/connectivity_service.dart';
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
  } catch (e) {
    debugLog('Main', 'Background message handler error: $e');
  }
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
        if (context != null && context.mounted) {
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

    authProvider.registerOnLogoutCallback(() async {
      await UserSession().prepareForLogout();

      final currentUserId = await UserSession().getCurrentUserId();
      final lastUserId = await UserSession().getLastUserId();

      if (lastUserId != null && lastUserId != currentUserId) {
        debugLog('Main', '🔄 Different user logout - clearing provider data');

        categoryProvider.clearUserData();
        subscriptionProvider.clearUserData();

        Provider.of<CourseProvider>(context, listen: false).clearUserData();
        Provider.of<ChapterProvider>(context, listen: false).clearUserData();
        Provider.of<ExamProvider>(context, listen: false).clearUserData();
        Provider.of<ExamQuestionProvider>(context, listen: false)
            .clearUserData();
        Provider.of<NoteProvider>(context, listen: false).clearUserData();
        Provider.of<QuestionProvider>(context, listen: false).clearUserData();
        Provider.of<PaymentProvider>(context, listen: false).clearUserData();
        Provider.of<ProgressProvider>(context, listen: false).clearUserData();
        Provider.of<StreakProvider>(context, listen: false).clearUserData();
        Provider.of<NotificationProvider>(context, listen: false)
            .clearUserData();
        Provider.of<UserProvider>(context, listen: false).clearUserData();
        Provider.of<VideoProvider>(context, listen: false).clearUserData();
        Provider.of<SettingsProvider>(context, listen: false).clearUserData();
        Provider.of<SchoolProvider>(context, listen: false).clearUserData();
        Provider.of<ParentLinkProvider>(context, listen: false).clearUserData();
        Provider.of<DeviceProvider>(context, listen: false).clearUserData();
      } else {
        debugLog('Main', '✅ Same user logout - preserving all provider data');
      }

      await UserSession().completeLogout();
    });

    authProvider.registerOnLoginCallback(() => _handleLoginCallback(context));

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
  } catch (e) {
    debugLog('Main', 'Sync providers error: $e');
  }
}

Future<void> _handleLoginCallback(BuildContext context) async {
  if (!context.mounted) return;

  final subscriptionProvider =
      Provider.of<SubscriptionProvider>(context, listen: false);
  final categoryProvider =
      Provider.of<CategoryProvider>(context, listen: false);

  await subscriptionProvider.loadSubscriptions();
  if (!context.mounted) return;

  await categoryProvider.loadCategories();
  if (!context.mounted) return;

  final notificationService = NotificationService();
  final fcmToken = await notificationService.getFCMToken();
  if (!context.mounted) return;

  if (fcmToken != null) {
    final apiService = Provider.of<ApiService>(context, listen: false);
    await apiService.updateFcmToken(fcmToken);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', fcmToken);
  }
}

void _showDeviceChangeDialog(BuildContext context) {
  if (!context.mounted) return;

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
            if (context.mounted) {
              Navigator.of(context).pushNamed('/device-change');
            }
          },
          child: const Text('Continue'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            if (context.mounted) {
              Provider.of<AuthProvider>(context, listen: false).logout();
            }
          },
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
}

void _showDeviceDeactivatedDialog(BuildContext context, String message) {
  if (!context.mounted) return;

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
            if (context.mounted) {
              Provider.of<AuthProvider>(context, listen: false).logout();
            }
          },
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

void _initializeMediaKit() {
  try {
    media_kit.MediaKit.ensureInitialized();
    debugLog('Main', '✅ MediaKit initialized successfully');
  } catch (e) {
    debugLog('Main', '❌ MediaKit init error: $e - will use fallback players');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  _initializeMediaKit();

  if (Platform.isAndroid || Platform.isIOS) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
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
      } catch (e) {
        debugLog('Main', 'Env load error for $envPath: $e');
      }
    }
    if (!envLoaded) {
      debugLog('Main', 'No .env file found, using defaults');
    }
  } catch (e) {
    debugLog('Main', 'Env setup error: $e');
  }

  if (Platform.isAndroid || Platform.isIOS) {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ));
  }

  final notificationService = NotificationService();

  if (Platform.isAndroid || Platform.isIOS) {
    try {
      await Firebase.initializeApp();
      await notificationService.init();

      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      final messaging = FirebaseMessaging.instance;
      final currentSettings = await messaging.getNotificationSettings();
      if (currentSettings.authorizationStatus ==
          AuthorizationStatus.notDetermined) {
        await messaging.requestPermission();
      }

      final token = await messaging.getToken();
      final prefs = await SharedPreferences.getInstance();
      if (token != null) {
        await prefs.setString('fcm_token', token);
        debugLog('Main', 'FCM token saved');
      }
    } catch (e) {
      debugLog('Main', 'Firebase init error: $e');
    }
  } else {
    try {
      await notificationService.init();
    } catch (e) {
      debugLog('Main', 'Notification service init error: $e');
    }
  }

  try {
    await ScreenProtectionService.initialize();
  } catch (e) {
    debugLog('Main', 'Screen protection init error: $e');
  }

  final storageService = StorageService();
  try {
    await storageService.init();
  } catch (e) {
    debugLog('Main', 'Storage service init error: $e');
  }

  final deviceService = DeviceService();
  try {
    await deviceService.init();
  } catch (e) {
    debugLog('Main', 'Device service init error: $e');
  }

  try {
    await UserSession().init();
  } catch (e) {
    debugLog('Main', 'UserSession init error: $e');
  }

  final connectivityService = ConnectivityService();
  try {
    await connectivityService.initialize();
    debugLog('Main', 'ConnectivityService initialized');
  } catch (e) {
    debugLog('Main', 'ConnectivityService init error: $e');
  }

  final apiService = ApiService();
  notificationService.apiService = apiService;

  final appLifecycleObserver = AppLifecycleObserver();
  WidgetsBinding.instance.addObserver(appLifecycleObserver);

  runApp(
    MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storageService),
        Provider<DeviceService>.value(value: deviceService),
        Provider<ApiService>.value(value: apiService),
        Provider<NotificationService>.value(value: notificationService),
        Provider<ConnectivityService>.value(value: connectivityService),
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

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              _syncProviders(context);
            }
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

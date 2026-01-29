import 'dart:async';
import 'dart:convert';
import 'package:familyacademyclient/services/api_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter/foundation.dart';

import '../utils/constants.dart';
import '../utils/helpers.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static bool _isInitialized = false;
  static bool _isInitializing = false;
  static final Completer<void> _initCompleter = Completer<void>();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  final StreamController<Map<String, dynamic>> _notificationStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get notificationStream =>
      _notificationStreamController.stream;

  FirebaseMessaging? _firebaseMessaging;
  String? _fcmToken;
  ApiService? _apiService;

  // Track last notification to prevent duplicates
  Map<String, DateTime> _lastNotificationTime = {};

  void setApiService(ApiService apiService) {
    _apiService = apiService;
  }

  Future<void> init({bool forceReinit = false}) async {
    // Prevent multiple initializations
    if (_isInitialized && !forceReinit) {
      debugLog('NotificationService', 'Already initialized, skipping...');
      return;
    }

    if (_isInitializing) {
      debugLog('NotificationService', 'Already initializing, waiting...');
      await _initCompleter.future;
      return;
    }

    _isInitializing = true;

    try {
      debugLog(
          'NotificationService', '🚀 Initializing notification service...');

      // Initialize Firebase if not already initialized
      try {
        await Firebase.initializeApp();
        debugLog('NotificationService', '✅ Firebase initialized');
      } catch (e) {
        debugLog('NotificationService',
            '⚠️ Firebase already initialized or error: $e');
      }

      // Initialize timezone data
      tz.initializeTimeZones();

      // Initialize local notifications
      await _initLocalNotifications();

      // Initialize Firebase Messaging
      await _initFirebaseMessaging();

      // Request permissions
      await _requestPermissions();

      // Listen for token refresh
      _setupTokenRefreshListener();

      _isInitialized = true;
      _initCompleter.complete();

      debugLog(
          'NotificationService', '✅ Notification service fully initialized');
    } catch (e, stack) {
      _initCompleter.completeError(e);
      debugLog('NotificationService',
          '❌ Notification service initialization failed: $e');
      debugLog('NotificationService', 'Stack trace: $stack');
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _initLocalNotifications() async {
    try {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initializationSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
      );

      debugLog('NotificationService', '✅ Local notifications initialized');
    } catch (e) {
      debugLog('NotificationService', '❌ Local notifications init error: $e');
    }
  }

  Future<void> _initFirebaseMessaging() async {
    try {
      _firebaseMessaging = FirebaseMessaging.instance;

      // Get FCM token
      _fcmToken = await _firebaseMessaging!.getToken();
      if (_fcmToken != null) {
        debugLog('NotificationService',
            '✅ FCM Token: ${_fcmToken!.substring(0, 20)}...');
        await _saveFCMToken(_fcmToken!);
      } else {
        debugLog('NotificationService', '⚠️ FCM token is null');
      }

      // Configure foreground message handling
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Configure background message handling
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      // Handle initial message when app is terminated
      RemoteMessage? initialMessage =
          await _firebaseMessaging!.getInitialMessage();
      if (initialMessage != null) {
        await _handleMessage(initialMessage);
      }

      debugLog('NotificationService', '✅ Firebase Messaging initialized');
    } catch (e, stack) {
      debugLog('NotificationService', '❌ Firebase Messaging init error: $e');
      debugLog('NotificationService', 'Stack trace: $stack');
    }
  }

  Future<void> _requestPermissions() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        NotificationSettings settings =
            await _firebaseMessaging!.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );

        debugLog('NotificationService',
            'iOS Permission status: ${settings.authorizationStatus}');
      }

      if (defaultTargetPlatform == TargetPlatform.android) {
        // Android 13+ requires notification permission
        NotificationSettings permission =
            await _firebaseMessaging!.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );

        debugLog(
            'NotificationService', 'Android Permission granted: $permission');
      }
    } catch (e) {
      debugLog('NotificationService', '❌ Permission request error: $e');
    }
  }

  void _setupTokenRefreshListener() {
    _firebaseMessaging!.onTokenRefresh.listen((newToken) async {
      debugLog('NotificationService',
          '🔄 FCM token refreshed: ${newToken.substring(0, 20)}...');
      _fcmToken = newToken;
      await _saveFCMToken(newToken);

      // Send updated token to backend if user is authenticated
      await _sendFcmTokenToBackend(newToken);
    });
  }

  Future<void> _saveFCMToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', token);
      debugLog(
          'NotificationService', '✅ FCM token saved to shared preferences');
    } catch (e) {
      debugLog('NotificationService', '❌ Error saving FCM token: $e');
    }
  }

  // NEW: Send FCM token to backend ONLY when authenticated
  Future<void> sendFcmTokenToBackendIfAuthenticated() async {
    try {
      if (_fcmToken == null) {
        debugLog('NotificationService', '⚠️ No FCM token to send');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.tokenKey);

      if (token == null || token.isEmpty) {
        debugLog('NotificationService',
            '⚠️ User not authenticated, skipping FCM token update');
        return;
      }

      await _sendFcmTokenToBackend(_fcmToken!);
    } catch (e) {
      debugLog('NotificationService',
          '❌ Error checking authentication for FCM token: $e');
    }
  }

  Future<void> _sendFcmTokenToBackend(String fcmToken) async {
    try {
      if (_apiService == null) {
        debugLog('NotificationService',
            '⚠️ ApiService not set, skipping FCM token update');
        return;
      }

      debugLog('NotificationService', '📱 Sending FCM token to backend...');
      await _apiService!.updateFcmToken(fcmToken);
      debugLog('NotificationService', '✅ FCM token sent to backend');
    } catch (e) {
      debugLog(
          'NotificationService', '⚠️ Failed to send FCM token to backend: $e');
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugLog('NotificationService',
        '📱 Foreground message received: ${message.notification?.title}');

    // Check if notifications are enabled
    final prefs = await SharedPreferences.getInstance();
    final notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;

    if (!notificationsEnabled) {
      debugLog('NotificationService', '📱 Notifications disabled, skipping');
      return;
    }

    // Prevent duplicate notifications - check if same notification was just received
    final notificationKey =
        '${message.messageId}_${message.notification?.title}';
    final now = DateTime.now();

    if (_lastNotificationTime.containsKey(notificationKey)) {
      final lastTime = _lastNotificationTime[notificationKey]!;
      if (now.difference(lastTime).inSeconds < 2) {
        debugLog('NotificationService', '⚠️ Duplicate notification ignored');
        return;
      }
    }

    _lastNotificationTime[notificationKey] = now;

    // Handle the message data first
    await _handleMessage(message);

    // Only show local notification if app is in foreground
    // Firebase will show notification automatically in background
    if (message.notification?.title != null &&
        message.notification?.body != null) {
      await showLocalNotification(
        title: message.notification!.title!,
        body: message.notification!.body!,
        payload: json.encode(message.data),
      );
    }
  }

  Future<void> _handleMessage(RemoteMessage message) async {
    try {
      final data = message.data;
      final type = data['type'] ?? 'general';

      debugLog('NotificationService', '📱 Handling message type: $type');

      _notificationStreamController.add({
        'type': type,
        'data': data,
        'timestamp': DateTime.now(),
        'message': message.notification?.body,
        'click_action':
            data['click_action'] ?? data['route'] ?? '/notifications',
      });
    } catch (e) {
      debugLog('NotificationService', '❌ Error handling message: $e');
    }
  }

  Future<void> _handleMessageOpenedApp(RemoteMessage message) async {
    debugLog('NotificationService',
        '📱 App opened from notification: ${message.notification?.title}');
    await _handleMessage(message);

    // Navigate to notification screen
    final data = message.data;
    final route = data['click_action'] ?? data['route'] ?? '/notifications';
    _notificationStreamController.add({
      'type': 'navigate',
      'route': route,
      'data': data,
      'timestamp': DateTime.now(),
    });
  }

  static Future<void> _onDidReceiveNotificationResponse(
    NotificationResponse response,
  ) async {
    debugLog(
        'NotificationService', '📱 Notification clicked: ${response.payload}');

    if (response.payload != null) {
      try {
        final data = json.decode(response.payload!);

        // Navigate to appropriate screen
        NotificationService._instance._notificationStreamController.add({
          'type': 'notification_clicked',
          'data': data,
          'timestamp': DateTime.now(),
          'route': data['click_action'] ?? data['route'] ?? '/notifications',
        });
      } catch (e) {
        debugLog(
            'NotificationService', '❌ Error parsing notification payload: $e');
      }
    }
  }

  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
    int? id,
  }) async {
    try {
      // Check if we should show this notification
      final prefs = await SharedPreferences.getInstance();
      final notificationsEnabled =
          prefs.getBool('notifications_enabled') ?? true;

      if (!notificationsEnabled) {
        debugLog('NotificationService', '📱 Notifications disabled, skipping');
        return;
      }

      const androidDetails = AndroidNotificationDetails(
        'family_academy_channel',
        'Family Academy Notifications',
        channelDescription: 'Important notifications from Family Academy',
        importance: Importance.high,
        priority: Priority.high,
        ticker: 'ticker',
        enableVibration: true,
        playSound: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        id ?? DateTime.now().millisecondsSinceEpoch % 2147483647,
        title,
        body,
        notificationDetails,
        payload: payload,
      );

      debugLog('NotificationService', '📱 Local notification shown: $title');
    } catch (e, stack) {
      debugLog('NotificationService', '❌ Error showing local notification: $e');
      debugLog('NotificationService', 'Stack trace: $stack');
    }
  }

  Future<String?> getFCMToken() async {
    if (_fcmToken == null) {
      try {
        _fcmToken = await _firebaseMessaging?.getToken();
        if (_fcmToken != null) {
          await _saveFCMToken(_fcmToken!);
        }
      } catch (e) {
        debugLog('NotificationService', '❌ Error getting FCM token: $e');
      }
    }
    return _fcmToken;
  }

  Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
    int? id,
    bool allowWhileIdle = true,
  }) async {
    try {
      // Check if notifications are enabled
      final prefs = await SharedPreferences.getInstance();
      final notificationsEnabled =
          prefs.getBool('notifications_enabled') ?? true;

      if (!notificationsEnabled) {
        debugLog('NotificationService',
            '📱 Notifications disabled, skipping schedule');
        return;
      }

      const androidDetails = AndroidNotificationDetails(
        'family_academy_scheduled',
        'Scheduled Notifications',
        channelDescription: 'Scheduled notifications from Family Academy',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final tzDateTime = tz.TZDateTime.from(scheduledTime, tz.local);

      await _localNotifications.zonedSchedule(
        id ?? 0,
        title,
        body,
        tzDateTime,
        notificationDetails,
        androidScheduleMode: allowWhileIdle
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.exact,
        payload: payload,
      );

      debugLog('NotificationService',
          '📅 Notification scheduled: $title at $scheduledTime');
    } catch (e, stack) {
      debugLog('NotificationService', '❌ Error scheduling notification: $e');
      debugLog('NotificationService', 'Stack trace: $stack');
    }
  }

  Future<void> cancelAllNotifications() async {
    try {
      await _localNotifications.cancelAll();
      debugLog('NotificationService', '🗑️ All notifications cancelled');
    } catch (e) {
      debugLog(
          'NotificationService', '❌ Error cancelling all notifications: $e');
    }
  }

  Future<void> cancelScheduledNotifications() async {
    try {
      await _localNotifications.cancel(1001);
      await _localNotifications.cancel(1002);
      await _localNotifications.cancel(1003);
      debugLog('NotificationService', '🗑️ Scheduled notifications cancelled');
    } catch (e) {
      debugLog('NotificationService',
          '❌ Error cancelling scheduled notifications: $e');
    }
  }

  Future<void> dispose() async {
    try {
      await _notificationStreamController.close();
      debugLog('NotificationService', '🔄 Notification service disposed');
    } catch (e) {
      debugLog(
          'NotificationService', '❌ Error disposing notification service: $e');
    }
  }

  Future<void> showPaymentVerifiedNotification({
    required String categoryName,
    required double amount,
  }) async {
    await showLocalNotification(
      title: 'Payment Verified!',
      body: 'Your payment of $amount Birr for $categoryName has been verified.',
      payload: json.encode({
        'type': 'payment_verified',
        'category': categoryName,
        'amount': amount,
        'timestamp': DateTime.now().toIso8601String(),
        'click_action': '/notifications',
      }),
    );
  }

  Future<void> showExamResultNotification({
    required String examTitle,
    required double score,
    required bool passed,
  }) async {
    await showLocalNotification(
      title: 'Exam Result: ${passed ? 'Passed' : 'Failed'}',
      body: 'Your exam "$examTitle" score: ${score.toStringAsFixed(1)}%',
      payload: json.encode({
        'type': 'exam_result',
        'exam_title': examTitle,
        'score': score,
        'passed': passed,
        'timestamp': DateTime.now().toIso8601String(),
        'click_action': '/progress',
      }),
    );
  }

  Future<void> showStreakNotification({
    required int streakCount,
    required String streakLevel,
  }) async {
    await showLocalNotification(
      title: 'Streak Update: $streakLevel',
      body: 'You have maintained a $streakCount day streak! Keep going!',
      payload: json.encode({
        'type': 'streak_update',
        'streak_count': streakCount,
        'streak_level': streakLevel,
        'timestamp': DateTime.now().toIso8601String(),
        'click_action': '/progress',
      }),
    );
  }

  // Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notifications_enabled') ?? true;
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  debugLog('NotificationService',
      'Background message received: ${message.notification?.title}');

  final prefs = await SharedPreferences.getInstance();
  final notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;

  if (!notificationsEnabled) {
    debugLog('NotificationService',
        'Notifications are disabled, skipping background notification');
    return;
  }

  // Don't show duplicate notification - Firebase handles it in background
  // Just save the notification data
  try {
    if (message.notification?.title != null &&
        message.notification?.body != null) {
      final notificationService = NotificationService();
      await notificationService.showLocalNotification(
        title: message.notification!.title!,
        body: message.notification!.body!,
        payload: json.encode(message.data),
      );
    }
  } catch (e) {
    debugLog('NotificationService', 'Background handler error: $e');
  }
}

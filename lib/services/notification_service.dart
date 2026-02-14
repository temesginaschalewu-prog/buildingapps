import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
  static bool _listenersSetUp = false;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  final StreamController<Map<String, dynamic>> _notificationStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get notificationStream =>
      _notificationStreamController.stream;

  FirebaseMessaging? _firebaseMessaging;
  String? _fcmToken;
  ApiService? _apiService;

  final Map<String, DateTime> _lastNotificationTime = {};
  final Set<String> _processedMessageIds = {};
  final Set<String> _preventDuplicateIds = {};

  void setApiService(ApiService apiService) {
    _apiService = apiService;
  }

  Future<void> init({bool forceReinit = false}) async {
    if (_isInitialized && !forceReinit) {
      debugLog('NotificationService', 'Already initialized, skipping...');
      return;
    }

    if (_isInitializing) {
      debugLog('NotificationService', 'Already initializing, waiting...');
      return;
    }

    _isInitializing = true;

    try {
      debugLog(
          'NotificationService', '🚀 Initializing notification service...');

      // Initialize timezone for local notifications
      tz.initializeTimeZones();

      // Initialize local notifications FIRST (works on all platforms)
      await _initLocalNotifications();

      // Initialize Firebase ONLY on mobile platforms
      if (Platform.isAndroid || Platform.isIOS) {
        try {
          await Firebase.initializeApp();
          debugLog('NotificationService', '✅ Firebase initialized for mobile');
        } catch (e) {
          debugLog(
              'NotificationService', '⚠️ Firebase initialization error: $e');
        }
      }

      await _initFirebaseMessaging();

      await _requestPermissions();

      _setupTokenRefreshListener();

      await _setupMessageListeners();

      _isInitialized = true;

      debugLog(
          'NotificationService', '✅ Notification service fully initialized');
    } catch (e, stack) {
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

      // Add Linux initialization settings
      const linuxSettings = LinuxInitializationSettings(
        defaultActionName: 'Open notification',
      );

      const initializationSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
        linux: linuxSettings,
      );

      await _localNotifications.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
        onDidReceiveBackgroundNotificationResponse:
            _onDidReceiveNotificationResponse,
      );
      debugLog('NotificationService', '✅ Local notifications initialized');
    } catch (e) {
      debugLog('NotificationService', '❌ Local notifications init error: $e');
    }
  }

  Future<void> _initFirebaseMessaging() async {
    try {
      // Only initialize Firebase Messaging on mobile platforms
      if (Platform.isAndroid || Platform.isIOS) {
        _firebaseMessaging = FirebaseMessaging.instance;

        _fcmToken = await _firebaseMessaging!.getToken();
        if (_fcmToken != null) {
          debugLog('NotificationService',
              '✅ FCM Token: ${_fcmToken!.substring(0, 20)}...');
          await _saveFCMToken(_fcmToken!);
        } else {
          debugLog('NotificationService', '⚠️ FCM token is null');
        }

        debugLog('NotificationService', '✅ Firebase Messaging initialized');
      } else {
        debugLog('NotificationService',
            '⚠️ Firebase Messaging not available on ${Platform.operatingSystem}');
      }
    } catch (e, stack) {
      debugLog('NotificationService', '❌ Firebase Messaging init error: $e');
      debugLog('NotificationService', 'Stack trace: $stack');
    }
  }

  Future<void> _setupMessageListeners() async {
    if (_listenersSetUp) {
      debugLog('NotificationService', '⚠️ Message listeners already set up');
      return;
    }

    try {
      debugLog('NotificationService', '🔧 Setting up message listeners...');

      // Only setup Firebase message listeners on mobile platforms
      if (Platform.isAndroid || Platform.isIOS && _firebaseMessaging != null) {
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
        FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

        RemoteMessage? initialMessage =
            await _firebaseMessaging!.getInitialMessage();
        if (initialMessage != null) {
          debugLog('NotificationService', '📱 Handling initial message');
          await _handleMessage(initialMessage);
        }
      }

      _listenersSetUp = true;
      debugLog('NotificationService', '✅ Message listeners set up');
    } catch (e, stack) {
      debugLog(
          'NotificationService', '❌ Error setting up message listeners: $e');
      debugLog('NotificationService', 'Stack trace: $stack');
    }
  }

  Future<void> _requestPermissions() async {
    try {
      if (Platform.isIOS && _firebaseMessaging != null) {
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

      if (Platform.isAndroid && _firebaseMessaging != null) {
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
    if (_firebaseMessaging != null) {
      _firebaseMessaging!.onTokenRefresh.listen((newToken) async {
        debugLog('NotificationService',
            '🔄 FCM token refreshed: ${newToken.substring(0, 20)}...');
        _fcmToken = newToken;
        await _saveFCMToken(newToken);

        await _sendFcmTokenToBackend(newToken);
      });
    }
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
        '📱 Foreground message received: ${message.messageId}');

    // Prevent duplicate notifications
    final String notificationId = _generateNotificationId(message);
    if (_preventDuplicateIds.contains(notificationId)) {
      debugLog('NotificationService',
          '⚠️ Duplicate notification prevented: $notificationId');
      return;
    }

    _preventDuplicateIds.add(notificationId);

    // Clean up old IDs to prevent memory leak
    if (_preventDuplicateIds.length > 1000) {
      final idsToRemove = _preventDuplicateIds.take(500).toList();
      _preventDuplicateIds.removeAll(idsToRemove);
    }

    if (_processedMessageIds.contains(message.messageId)) {
      debugLog('NotificationService',
          '⚠️ Message ${message.messageId} already processed, ignoring');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;

    if (!notificationsEnabled) {
      debugLog('NotificationService', '📱 Notifications disabled, skipping');
      return;
    }

    _processedMessageIds.add(message.messageId ?? '');

    if (_processedMessageIds.length > 100) {
      _processedMessageIds.clear();
    }

    await _handleMessage(message);

    if (message.notification?.title != null &&
        message.notification?.body != null) {
      await showLocalNotification(
        title: message.notification!.title!,
        body: message.notification!.body!,
        payload: json.encode(message.data),
        notificationId: notificationId,
      );
    }
  }

  String _generateNotificationId(RemoteMessage message) {
    // Generate a unique ID based on message content to prevent duplicates
    final title = message.notification?.title ?? '';
    final body = message.notification?.body ?? '';
    final dataHash = json.encode(message.data).hashCode;
    return '${title}_${body}_$dataHash';
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
        'message_id': message.messageId,
      });
    } catch (e) {
      debugLog('NotificationService', '❌ Error handling message: $e');
    }
  }

  Future<void> _handleMessageOpenedApp(RemoteMessage message) async {
    debugLog('NotificationService',
        '📱 App opened from notification: ${message.messageId}');

    if (_processedMessageIds.contains(message.messageId)) {
      return;
    }

    await _handleMessage(message);

    final data = message.data;
    final route = data['click_action'] ?? data['route'] ?? '/notifications';
    _notificationStreamController.add({
      'type': 'navigate',
      'route': route,
      'data': data,
      'timestamp': DateTime.now(),
      'message_id': message.messageId,
    });
  }

  Future<void> handleBackgroundMessage(RemoteMessage message) async {
    debugLog('NotificationService',
        '📱 Handling background message: ${message.messageId}');

    // Prevent duplicate background notifications
    final String notificationId = _generateNotificationId(message);
    if (_preventDuplicateIds.contains(notificationId)) {
      debugLog('NotificationService',
          '⚠️ Duplicate background notification prevented: $notificationId');
      return;
    }

    _preventDuplicateIds.add(notificationId);

    if (_processedMessageIds.contains(message.messageId)) {
      debugLog('NotificationService',
          '⚠️ Background message already processed, ignoring');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;

    if (!notificationsEnabled) {
      debugLog('NotificationService', '📱 Notifications disabled, skipping');
      return;
    }

    _processedMessageIds.add(message.messageId ?? '');

    if (message.notification?.title != null &&
        message.notification?.body != null) {
      await showLocalNotification(
        title: message.notification!.title!,
        body: message.notification!.body!,
        payload: json.encode(message.data),
        notificationId: notificationId,
      );
    }

    await _handleMessage(message);
  }

  static Future<void> _onDidReceiveNotificationResponse(
    NotificationResponse response,
  ) async {
    debugLog(
        'NotificationService', '📱 Notification clicked: ${response.payload}');

    if (response.payload != null) {
      try {
        final data = json.decode(response.payload!);

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
    String? notificationId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsEnabled =
          prefs.getBool('notifications_enabled') ?? true;

      if (!notificationsEnabled) {
        debugLog('NotificationService', '📱 Notifications disabled, skipping');
        return;
      }

      // Check if this exact notification was shown recently (within 5 seconds)
      final String uniqueId = notificationId ?? '$title$body$payload';
      final now = DateTime.now();
      final lastShown = _lastNotificationTime[uniqueId];

      if (lastShown != null && now.difference(lastShown).inSeconds < 5) {
        debugLog('NotificationService',
            '⚠️ Notification suppressed (duplicate within 5 seconds): $title');
        return;
      }

      _lastNotificationTime[uniqueId] = now;

      // Clean up old entries
      if (_lastNotificationTime.length > 100) {
        final keysToRemove = _lastNotificationTime.keys
            .where((key) =>
                now.difference(_lastNotificationTime[key]!).inMinutes > 5)
            .toList();
        for (final key in keysToRemove) {
          _lastNotificationTime.remove(key);
        }
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
        onlyAlertOnce: true, // Prevent duplicate alerts
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        threadIdentifier: 'family_academy',
      );

      final linuxDetails = LinuxNotificationDetails(
        actions: [
          LinuxNotificationAction(
            key: 'open',
            label: 'Open',
          ),
        ],
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
        linux: linuxDetails,
      );

      final notificationIdValue =
          id ?? (title.hashCode + body.hashCode) & 0x7fffffff;
      await _localNotifications.show(
        id: notificationIdValue,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
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
        id: id ?? 0,
        title: title,
        body: body,
        scheduledDate: tzDateTime,
        notificationDetails: notificationDetails,
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
      await _localNotifications.cancel(id: 1001);
      await _localNotifications.cancel(id: 1002);
      await _localNotifications.cancel(id: 1003);
      debugLog('NotificationService', '🗑️ Scheduled notifications cancelled');
    } catch (e) {
      debugLog('NotificationService',
          '❌ Error cancelling scheduled notifications: $e');
    }
  }

  Future<void> dispose() async {
    try {
      _processedMessageIds.clear();
      _preventDuplicateIds.clear();
      _lastNotificationTime.clear();
      await _notificationStreamController.close();
      _listenersSetUp = false;
      _isInitialized = false;
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

  Future<bool> areNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notifications_enabled') ?? true;
  }

  void clearProcessedMessages() {
    _processedMessageIds.clear();
    _preventDuplicateIds.clear();
    _lastNotificationTime.clear();
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:familyacademyclient/services/api_service.dart';
import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/utils/constants.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
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

  set apiService(ApiService service) {
    _apiService = service;
    debugLog('NotificationService', 'ApiService set');
  }

  final Map<String, DateTime> _lastNotificationTime = {};
  final Set<String> _processedMessageIds = {};
  final Set<String> _preventDuplicateIds = {};

  Future<void> init({bool forceReinit = false}) async {
    if (_isInitialized && !forceReinit) return;
    if (_isInitializing) return;

    _isInitializing = true;

    try {
      tz.initializeTimeZones();
      await _initLocalNotifications();

      if (Platform.isAndroid || Platform.isIOS) {
        try {
          await Firebase.initializeApp();
          debugLog('NotificationService', 'Firebase initialized');
        } catch (e) {
          debugLog('NotificationService', 'Firebase init error: $e');
        }
      }

      await _initFirebaseMessaging();
      await _requestPermissions();
      _setupTokenRefreshListener();
      await _setupMessageListeners();

      _isInitialized = true;
      debugLog('NotificationService', 'Notification service initialized');
    } catch (e) {
      debugLog('NotificationService', 'Init error: $e');
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _initLocalNotifications() async {
    try {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings();
      const linuxSettings = LinuxInitializationSettings(
        defaultActionName: 'Open',
      );

      const initializationSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
        linux: linuxSettings,
      );

      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
        onDidReceiveBackgroundNotificationResponse:
            _onDidReceiveNotificationResponse,
      );

      debugLog('NotificationService', 'Local notifications initialized');
    } catch (e) {
      debugLog('NotificationService', 'Local notifications init error: $e');
    }
  }

  Future<void> _initFirebaseMessaging() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        _firebaseMessaging = FirebaseMessaging.instance;
        _fcmToken = await _firebaseMessaging!.getToken();
        if (_fcmToken != null) {
          await _saveFCMToken(_fcmToken!);
          debugLog('NotificationService', 'FCM token obtained');
        }
      }
    } catch (e) {
      debugLog('NotificationService', 'Firebase messaging init error: $e');
    }
  }

  Future<void> _setupMessageListeners() async {
    if (_listenersSetUp) return;

    try {
      if (Platform.isAndroid || Platform.isIOS && _firebaseMessaging != null) {
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
        FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

        final RemoteMessage? initialMessage =
            await _firebaseMessaging!.getInitialMessage();
        if (initialMessage != null) {
          await _handleMessage(initialMessage);
        }

        debugLog('NotificationService', 'Message listeners set up');
      }

      _listenersSetUp = true;
    } catch (e) {
      debugLog('NotificationService', 'Message listeners error: $e');
    }
  }

  Future<void> _requestPermissions() async {
    try {
      if (Platform.isIOS && _firebaseMessaging != null) {
        await _firebaseMessaging!.requestPermission();
      }
    } catch (e) {
      debugLog('NotificationService', 'Permission request error: $e');
    }
  }

  void _setupTokenRefreshListener() {
    if (_firebaseMessaging != null) {
      _firebaseMessaging!.onTokenRefresh.listen((newToken) async {
        _fcmToken = newToken;
        await _saveFCMToken(newToken);
        await _sendFcmTokenToBackend(newToken);
      });
    }
  }

  Future<void> _saveFCMToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.fcmTokenCacheKey, token);
    } catch (e) {
      debugLog('NotificationService', 'Error saving FCM token: $e');
    }
  }

  Future<void> sendFcmTokenToBackendIfAuthenticated() async {
    try {
      if (_fcmToken == null) return;
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.tokenKey);
      if (token == null || token.isEmpty) return;
      await _sendFcmTokenToBackend(_fcmToken!);
    } catch (e) {
      debugLog('NotificationService', 'Error sending FCM token: $e');
    }
  }

  Future<void> _sendFcmTokenToBackend(String fcmToken) async {
    try {
      if (_apiService == null) {
        debugLog(
            'NotificationService', 'ApiService not set, cannot send token');
        return;
      }
      await _apiService!.updateFcmToken(fcmToken);
      debugLog('NotificationService', 'FCM token sent to backend');
    } catch (e) {
      debugLog('NotificationService', 'Error sending token to backend: $e');
    }
  }

  String _generateNotificationId(RemoteMessage message) {
    final title = message.notification?.title ?? '';
    final body = message.notification?.body ?? '';
    final dataHash = json.encode(message.data).hashCode;
    return '${title}_${body}_$dataHash';
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final String notificationId = _generateNotificationId(message);
    if (_preventDuplicateIds.contains(notificationId)) return;

    _preventDuplicateIds.add(notificationId);
    if (_preventDuplicateIds.length > 1000) {
      final idsToRemove = _preventDuplicateIds.take(500).toList();
      _preventDuplicateIds.removeAll(idsToRemove);
    }

    if (_processedMessageIds.contains(message.messageId)) return;

    final prefs = await SharedPreferences.getInstance();
    final notificationsEnabled =
        prefs.getBool(AppConstants.notificationsEnabledKey) ?? true;
    if (!notificationsEnabled) return;

    _processedMessageIds.add(message.messageId ?? '');
    if (_processedMessageIds.length > 100) _processedMessageIds.clear();

    await _handleMessage(message);

    if (message.notification?.title != null &&
        message.notification?.body != null) {
      String notificationType = 'info';
      if (message.data['type'] != null) {
        notificationType = message.data['type'];
      } else if (message.notification?.title
              ?.toLowerCase()
              .contains('payment') ??
          false) {
        notificationType = 'payment';
      } else if (message.notification!.title?.toLowerCase().contains('exam') ??
          false) {
        notificationType = 'academic';
      } else if (message.notification?.title
              ?.toLowerCase()
              .contains('success') ??
          false) {
        notificationType = 'success';
      } else if (message.notification?.title
              ?.toLowerCase()
              .contains('warning') ??
          false) {
        notificationType = 'warning';
      } else if (message.notification?.title?.toLowerCase().contains('error') ??
          false) {
        notificationType = 'error';
      }

      await showLocalNotification(
        title: message.notification!.title!,
        body: message.notification!.body!,
        payload: json.encode(message.data),
        type: notificationType,
      );
    }
  }

  Future<void> _handleMessage(RemoteMessage message) async {
    try {
      final data = message.data;
      final type = data['type'] ?? 'general';

      _notificationStreamController.add({
        'type': type,
        'data': data,
        'timestamp': DateTime.now(),
        'message': message.notification?.body,
        'title': message.notification?.title,
        'route': _getRouteFromData(data),
        'message_id': message.messageId,
      });
    } catch (e) {
      debugLog('NotificationService', 'Error handling message: $e');
    }
  }

  String _getRouteFromData(Map<String, dynamic> data) {
    if (data['click_action'] != null) return data['click_action'];
    if (data['route'] != null) return data['route'];
    final type = data['type'];
    if (type == 'payment_verified' || type == 'payment_rejected') {
      return '/payment-history';
    }
    if (type == 'exam_result') {
      return '/exam-results';
    }
    if (type == 'chapter_complete') {
      return '/progress';
    }
    if (type == 'streak_update' || type == 'streak_milestone') {
      return '/progress';
    }
    return '/notifications';
  }

  Future<void> _handleMessageOpenedApp(RemoteMessage message) async {
    if (_processedMessageIds.contains(message.messageId)) return;
    await _handleMessage(message);
    final data = message.data;
    final route = _getRouteFromData(data);
    _notificationStreamController.add({
      'type': 'navigate',
      'route': route,
      'data': data,
      'timestamp': DateTime.now(),
      'message_id': message.messageId,
    });
  }

  Future<void> handleBackgroundMessage(RemoteMessage message) async {
    final String notificationId = _generateNotificationId(message);
    if (_preventDuplicateIds.contains(notificationId)) return;
    _preventDuplicateIds.add(notificationId);
    if (_processedMessageIds.contains(message.messageId)) return;
    final prefs = await SharedPreferences.getInstance();
    final notificationsEnabled =
        prefs.getBool(AppConstants.notificationsEnabledKey) ?? true;
    if (!notificationsEnabled) return;
    _processedMessageIds.add(message.messageId ?? '');
    if (message.notification?.title != null &&
        message.notification?.body != null) {
      await showLocalNotification(
        title: message.notification!.title!,
        body: message.notification!.body!,
        payload: json.encode(message.data),
      );
    }
    await _handleMessage(message);
  }

  static Future<void> _onDidReceiveNotificationResponse(
      NotificationResponse response) async {
    if (response.payload != null) {
      try {
        final data = json.decode(response.payload!);
        NotificationService._instance._notificationStreamController.add({
          'type': 'notification_clicked',
          'data': data,
          'timestamp': DateTime.now(),
          'route': NotificationService._instance._getRouteFromData(data),
        });
      } catch (e) {
        debugLog('NotificationService', 'Error on notification response: $e');
      }
    }
  }

  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
    int? id,
    String? type,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsEnabled =
          prefs.getBool(AppConstants.notificationsEnabledKey) ?? true;
      if (!notificationsEnabled) return;

      final String uniqueId = '$title$body$payload';
      final now = DateTime.now();
      final lastShown = _lastNotificationTime[uniqueId];

      if (lastShown != null && now.difference(lastShown).inSeconds < 5) return;

      _lastNotificationTime[uniqueId] = now;

      if (_lastNotificationTime.length > 100) {
        final keysToRemove = _lastNotificationTime.keys
            .where((key) =>
                now.difference(_lastNotificationTime[key]!).inMinutes > 5)
            .toList();
        for (final key in keysToRemove) {
          _lastNotificationTime.remove(key);
        }
      }

      Color notificationColor;
      switch (type) {
        case 'success':
          notificationColor = AppColors.success;
          break;
        case 'warning':
          notificationColor = AppColors.warning;
          break;
        case 'error':
          notificationColor = AppColors.error;
          break;
        case 'academic':
          notificationColor = AppColors.info;
          break;
        case 'payment':
          notificationColor = AppColors.pending;
          break;
        default:
          notificationColor = AppColors.info;
      }

      final androidDetails = AndroidNotificationDetails(
        AppConstants.notificationChannelId,
        AppConstants.notificationChannelName,
        channelDescription: AppConstants.notificationChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        color: notificationColor,
        ledColor: notificationColor,
        ledOnMs: AppConstants.notificationLedOnMs,
        ledOffMs: AppConstants.notificationLedOffMs,
        enableLights: true,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          summaryText: AppConstants.appName,
        ),
        icon: '@mipmap/ic_launcher',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        ticker: AppConstants.appName,
        onlyAlertOnce: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        threadIdentifier: AppConstants.appName,
      );

      const linuxDetails = LinuxNotificationDetails(
        defaultActionName: 'Open',
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
        linux: linuxDetails,
      );

      final notificationId =
          id ?? (title.hashCode + body.hashCode) & 0x7fffffff;

      await _localNotifications.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: payload,
      );

      debugLog('NotificationService', '✨ Beautiful notification shown: $title');
    } catch (e) {
      debugLog('NotificationService', 'Show local notification error: $e');
    }
  }

  Future<String?> getFCMToken() async {
    if (_fcmToken == null) {
      try {
        _fcmToken = await _firebaseMessaging?.getToken();
        if (_fcmToken != null) await _saveFCMToken(_fcmToken!);
      } catch (e) {
        debugLog('NotificationService', 'Error getting FCM token: $e');
      }
    }
    return _fcmToken;
  }

  Future<bool> areNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.notificationsEnabledKey) ?? true;
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.notificationsEnabledKey, enabled);
  }

  void clearProcessedMessages() {
    _processedMessageIds.clear();
    _preventDuplicateIds.clear();
    _lastNotificationTime.clear();
  }

  void dispose() {
    _notificationStreamController.close();
  }
}

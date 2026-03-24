import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:familyacademyclient/services/api_service.dart';
import 'package:familyacademyclient/services/connectivity_service.dart';
import 'package:familyacademyclient/utils/platform_helper.dart';
import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/utils/constants.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:hive/hive.dart';
import '../utils/helpers.dart';

/// PRODUCTION-READY Notification Service
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static bool _isInitialized = false;
  static bool _isInitializing = false;
  static bool _firebaseInitLogged = false;
  static bool _fcmAuthFailureLogged = false;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  final StreamController<Map<String, dynamic>> _notificationStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get notificationStream =>
      _notificationStreamController.stream;

  FirebaseMessaging? _firebaseMessaging;
  String? _fcmToken;

  ApiService? _apiService;
  ConnectivityService? _connectivityService;

  // Hive box for notification cache
  Box? _notificationBox;

  set apiService(ApiService service) {
    _apiService = service;
  }

  set connectivityService(ConnectivityService service) {
    _connectivityService = service;
  }

  final Map<String, DateTime> _lastNotificationTime = {};
  final Set<String> _processedMessageIds = {};
  final Set<String> _preventDuplicateIds = {};

  Future<void> init({bool forceReinit = false}) async {
    if (_isInitialized && !forceReinit) return;
    if (_isInitializing) return;

    _isInitializing = true;

    try {
      // Initialize notification box
      await _initNotificationBox();

      tz.initializeTimeZones();
      await _initLocalNotifications();

      if (PlatformHelper.isAndroid ||
          PlatformHelper.isIOS ||
          PlatformHelper.isMacOS) {
        try {
          if (Firebase.apps.isEmpty) {
            await Firebase.initializeApp();
          }
          if (!_firebaseInitLogged) {
            debugLog('NotificationService', 'Firebase initialized');
            _firebaseInitLogged = true;
          }
        } catch (e) {
          debugLog('NotificationService', 'Firebase init error: $e');
        }
      }

      if (PlatformHelper.isAndroid ||
          PlatformHelper.isIOS ||
          PlatformHelper.isMacOS) {
        await _initFirebaseMessaging();
        await _requestPermissions();
        _setupTokenRefreshListener();
        await _setupMessageListeners();
      }

      _isInitialized = true;
      debugLog('NotificationService', 'Notification service initialized');
    } catch (e) {
      debugLog('NotificationService', 'Init error: $e');
    } finally {
      _isInitializing = false;
    }
  }

  // Initialize Hive notification box
  Future<void> _initNotificationBox() async {
    try {
      if (Hive.isBoxOpen('notifications_box')) {
        _notificationBox = Hive.box('notifications_box');
        debugLog(
            'NotificationService', '✅ Using already opened notification box');
      } else {
        _notificationBox = await Hive.openBox('notifications_box');
        debugLog('NotificationService', '✅ Notification box opened');
      }
    } catch (e) {
      debugLog('NotificationService', '⚠️ Error opening notification box: $e');
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
        settings: initializationSettings,
        onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
        onDidReceiveBackgroundNotificationResponse:
            _onDidReceiveNotificationResponse,
      );
    } catch (e) {
      debugLog('NotificationService', 'Local notifications init error: $e');
    }
  }

  Future<void> _initFirebaseMessaging() async {
    try {
      if (PlatformHelper.isAndroid ||
          PlatformHelper.isIOS ||
          PlatformHelper.isMacOS) {
        _firebaseMessaging = FirebaseMessaging.instance;
        _fcmToken = await _firebaseMessaging!.getToken();
        if (_fcmToken != null) {
          await _saveFCMToken(_fcmToken!);
        }
      }
    } catch (e) {
      final message = e.toString();
      if (message.contains('AUTHENTICATION_FAILED')) {
        _fcmToken = null;
        if (!_fcmAuthFailureLogged) {
          debugLog(
            'NotificationService',
            'Firebase messaging auth failed in this environment. Push token unavailable; in-app notifications will still work.',
          );
          _fcmAuthFailureLogged = true;
        }
      } else {
        debugLog('NotificationService', 'Firebase messaging init error: $e');
      }
    }
  }

  Future<void> _setupMessageListeners() async {
    try {
      if ((PlatformHelper.isAndroid ||
              PlatformHelper.isIOS ||
              PlatformHelper.isMacOS) &&
          _firebaseMessaging != null) {
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
        FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

        final RemoteMessage? initialMessage =
            await _firebaseMessaging!.getInitialMessage();
        if (initialMessage != null) {
          await _handleMessage(initialMessage);
        }
      }
    } catch (e) {
      debugLog('NotificationService', 'Message listeners error: $e');
    }
  }

  Future<void> _requestPermissions() async {
    try {
      if ((PlatformHelper.isAndroid ||
              PlatformHelper.isIOS ||
              PlatformHelper.isMacOS) &&
          _firebaseMessaging != null) {
        await _firebaseMessaging!.requestPermission();
      }
    } catch (e) {
      debugLog('NotificationService', 'Permission request error: $e');
    }
  }

  void _setupTokenRefreshListener() {
    if (_firebaseMessaging != null &&
        (PlatformHelper.isAndroid ||
            PlatformHelper.isIOS ||
            PlatformHelper.isMacOS)) {
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

      // Save to Hive
      if (_notificationBox != null) {
        await _notificationBox!.put('fcm_token', token);
      }
    } catch (e) {
      debugLog('NotificationService', 'Error saving FCM token: $e');
    }
  }

  Future<void> sendFcmTokenToBackendIfAuthenticated() async {
    if (!(PlatformHelper.isAndroid ||
        PlatformHelper.isIOS ||
        PlatformHelper.isMacOS)) {
      return;
    }

    try {
      if (_fcmToken == null) return;

      final connectivity = _connectivityService ?? ConnectivityService();
      if (!connectivity.isOnline) {
        await _queueFcmTokenForSync(_fcmToken!);
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.tokenKey);
      if (token == null || token.isEmpty) return;
      await _sendFcmTokenToBackend(_fcmToken!);
    } catch (e) {
      debugLog('NotificationService', 'Error sending FCM token: $e');
    }
  }

  Future<void> _queueFcmTokenForSync(String fcmToken) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_fcm_token', fcmToken);
    } catch (e) {
      debugLog('NotificationService', 'Error queueing FCM token: $e');
    }
  }

  Future<void> syncPendingFcmToken() async {
    if (!(PlatformHelper.isAndroid ||
        PlatformHelper.isIOS ||
        PlatformHelper.isMacOS)) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingToken = prefs.getString('pending_fcm_token');
      if (pendingToken == null) return;

      final connectivity = _connectivityService ?? ConnectivityService();
      if (!connectivity.isOnline) return;

      await _sendFcmTokenToBackend(pendingToken);
      await prefs.remove('pending_fcm_token');
    } catch (e) {
      debugLog('NotificationService', 'Error syncing FCM token: $e');
    }
  }

  Future<void> _sendFcmTokenToBackend(String fcmToken) async {
    try {
      if (_apiService == null) return;
      await _apiService!.updateFcmToken(fcmToken);
    } catch (e) {
      debugLog('NotificationService', 'Error sending token to backend: $e');
    }
  }

  Future<Map<String, dynamic>> getDiagnostics() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedToken = prefs.getString(AppConstants.fcmTokenCacheKey);
    final pendingToken = prefs.getString('pending_fcm_token');
    final authToken = prefs.getString(AppConstants.tokenKey);
    final connectivity = _connectivityService ?? ConnectivityService();

    return {
      'push_capable_platform': PlatformHelper.isAndroid ||
          PlatformHelper.isIOS ||
          PlatformHelper.isMacOS,
      'platform': PlatformHelper.platformName,
      'service_initialized': _isInitialized,
      'firebase_initialized': Firebase.apps.isNotEmpty,
      'notifications_enabled':
          prefs.getBool(AppConstants.notificationsEnabledKey) ?? true,
      'is_online': connectivity.isOnline,
      'is_authenticated': authToken != null && authToken.isNotEmpty,
      'live_fcm_token_present': _fcmToken != null && _fcmToken!.isNotEmpty,
      'cached_fcm_token_present': cachedToken != null && cachedToken.isNotEmpty,
      'pending_fcm_token_present':
          pendingToken != null && pendingToken.isNotEmpty,
      'fcm_token_preview': _maskToken(_fcmToken ?? cachedToken),
    };
  }

  String _maskToken(String? token) {
    if (token == null || token.isEmpty) return 'Not available';
    if (token.length <= 12) return token;
    return '${token.substring(0, 8)}...${token.substring(token.length - 4)}';
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

      // Save notification to Hive for offline access
      await _saveNotificationToHive(data);

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

  // Save notification to Hive
  Future<void> _saveNotificationToHive(Map<String, dynamic> data) async {
    try {
      if (_notificationBox == null) return;

      final notificationId = data['notification_id'] ??
          'notif_${DateTime.now().millisecondsSinceEpoch}';

      final notification = {
        'id': notificationId,
        'type': data['type'],
        'title': data['title'],
        'body': data['body'],
        'data': data,
        'received_at': DateTime.now().toIso8601String(),
        'is_read': false,
      };

      final existingNotifications =
          _notificationBox!.get('notifications') as List? ?? [];
      existingNotifications.insert(0, notification);

      // Keep only last 100 notifications
      if (existingNotifications.length > 100) {
        existingNotifications.removeRange(100, existingNotifications.length);
      }

      await _notificationBox!.put('notifications', existingNotifications);
    } catch (e) {
      debugLog('NotificationService', 'Error saving to Hive: $e');
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
    if (type == 'chapter_complete' || type == 'streak_update') {
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

      final androidDetails = AndroidNotificationDetails(
        AppConstants.notificationChannelId,
        AppConstants.notificationChannelName,
        channelDescription: AppConstants.notificationChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        color: AppColors.info,
        ledColor: AppColors.info,
        ledOnMs: AppConstants.notificationLedOnMs,
        ledOffMs: AppConstants.notificationLedOffMs,
        enableLights: true,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          summaryText: AppConstants.appName,
        ),
        icon: '@mipmap/ic_launcher',
        onlyAlertOnce: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const linuxDetails = LinuxNotificationDetails(
        defaultActionName: 'Open',
      );

      final notificationDetails = NotificationDetails(
        android: PlatformHelper.isMobile ? androidDetails : null,
        iOS: PlatformHelper.isMobile ? iosDetails : null,
        linux: linuxDetails,
      );

      final notificationId =
          id ?? (title.hashCode + body.hashCode) & 0x7fffffff;

      await _localNotifications.show(
        id: notificationId,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
        payload: payload,
      );
    } catch (e) {
      debugLog('NotificationService', 'Show local notification error: $e');
    }
  }

  Future<String?> getFCMToken() async {
    if (_fcmToken == null && PlatformHelper.isMobile) {
      try {
        _fcmToken = await _firebaseMessaging?.getToken();
        if (_fcmToken != null) await _saveFCMToken(_fcmToken!);
      } catch (e) {
        final message = e.toString();
        if (message.contains('AUTHENTICATION_FAILED')) {
          if (!_fcmAuthFailureLogged && kDebugMode) {
            debugLog(
              'NotificationService',
              'FCM token unavailable due to AUTHENTICATION_FAILED in this environment.',
            );
            _fcmAuthFailureLogged = true;
          }
        } else {
          debugLog('NotificationService', 'Error getting FCM token: $e');
        }
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

  // Get cached notifications from Hive
  Future<List<Map<String, dynamic>>> getCachedNotifications() async {
    try {
      if (_notificationBox == null) return [];
      return _notificationBox!.get('notifications')
              as List<Map<String, dynamic>>? ??
          [];
    } catch (e) {
      debugLog('NotificationService', 'Error getting cached notifications: $e');
      return [];
    }
  }

  void clearProcessedMessages() {
    _processedMessageIds.clear();
    _preventDuplicateIds.clear();
    _lastNotificationTime.clear();
  }

  void dispose() {
    _notificationStreamController.close();
    _notificationBox?.close();
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

import '../utils/constants.dart';
import '../utils/helpers.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  final StreamController<Map<String, dynamic>> _notificationStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get notificationStream =>
      _notificationStreamController.stream;

  Future<void> init() async {
    try {
      // Initialize timezone data
      tz.initializeTimeZones();

      // Platform-specific initialization
      const initializationSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
        linux: LinuxInitializationSettings(
          defaultActionName: 'Open notification',
        ),
      );

      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
      );

      debugLog('NotificationService', '✅ Notification service initialized');
    } catch (e) {
      debugLog('NotificationService', '❌ Notification service init error: $e');
    }
  }

  Future<void> _onDidReceiveNotificationResponse(
    NotificationResponse response,
  ) async {
    if (response.payload != null) {
      try {
        final data = json.decode(response.payload!);
        _handleNotificationData(data);
      } catch (e) {
        debugLog(
            'NotificationService', 'Error parsing notification payload: $e');
      }
    }
  }

  void _handleNotificationData(Map<String, dynamic> data) {
    final type = data['type'];

    switch (type) {
      case 'payment_verified':
        _notificationStreamController.add({
          'type': 'payment_verified',
          'data': data,
          'timestamp': DateTime.now(),
        });
        break;
      case 'payment_rejected':
        _notificationStreamController.add({
          'type': 'payment_rejected',
          'data': data,
          'timestamp': DateTime.now(),
        });
        break;
      case 'exam_result':
        _notificationStreamController.add({
          'type': 'exam_result',
          'data': data,
          'timestamp': DateTime.now(),
        });
        break;
      case 'streak_update':
        _notificationStreamController.add({
          'type': 'streak_update',
          'data': data,
          'timestamp': DateTime.now(),
        });
        break;
      case 'system_announcement':
        _notificationStreamController.add({
          'type': 'system_announcement',
          'data': data,
          'timestamp': DateTime.now(),
        });
        break;
      default:
        _notificationStreamController.add({
          'type': 'general',
          'data': data,
          'timestamp': DateTime.now(),
        });
    }
  }

  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
    int? id,
  }) async {
    try {
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

      const linuxDetails = LinuxNotificationDetails(
        actions: [LinuxNotificationAction(key: 'open', label: 'Open')],
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
        linux: linuxDetails,
      );

      await _localNotifications.show(
        id ?? DateTime.now().millisecondsSinceEpoch % 2147483647,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
      debugLog('NotificationService', '📱 Notification shown: $title');
    } catch (e) {
      debugLog('NotificationService', '❌ Error showing notification: $e');
    }
  }

  static Future<void> showBackgroundNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'family_academy_channel',
      'Family Academy Notifications',
      channelDescription: 'Important notifications from Family Academy',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch % 2147483647,
      message.notification?.title ?? 'Background Notification',
      message.notification?.body ?? '',
      notificationDetails,
      payload: json.encode(message.data),
    );
  }

  Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
    int? id,
  }) async {
    try {
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

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Convert DateTime to TZDateTime
      final tzDateTime = tz.TZDateTime.from(scheduledTime, tz.local);
      await _localNotifications.zonedSchedule(
        id ?? 0,
        title,
        body,
        tzDateTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
      debugLog('NotificationService',
          '📅 Notification scheduled: $title at $scheduledTime');
    } catch (e) {
      debugLog('NotificationService', '❌ Error scheduling notification: $e');
    }
  }

  Future<void> showPaymentVerifiedNotification({
    required String categoryName,
    required double amount,
  }) async {
    await showLocalNotification(
      title: '✅ Payment Verified',
      body: 'Your payment of $amount Birr for $categoryName has been verified.',
      payload: json.encode({
        'type': 'payment_verified',
        'category': categoryName,
        'amount': amount,
        'timestamp': DateTime.now().toIso8601String(),
      }),
    );
  }

  Future<void> showPaymentRejectedNotification({
    required String categoryName,
    required String reason,
  }) async {
    await showLocalNotification(
      title: '❌ Payment Rejected',
      body: 'Your payment for $categoryName was rejected. Reason: $reason',
      payload: json.encode({
        'type': 'payment_rejected',
        'category': categoryName,
        'reason': reason,
        'timestamp': DateTime.now().toIso8601String(),
      }),
    );
  }

  Future<void> showExamResultNotification({
    required String examTitle,
    required double score,
    required bool passed,
  }) async {
    await showLocalNotification(
      title: '📝 Exam Result: ${passed ? 'Passed' : 'Failed'}',
      body: 'Your exam "$examTitle" score: ${score.toStringAsFixed(1)}%',
      payload: json.encode({
        'type': 'exam_result',
        'exam_title': examTitle,
        'score': score,
        'passed': passed,
        'timestamp': DateTime.now().toIso8601String(),
      }),
    );
  }

  Future<void> showStreakNotification({
    required int streakCount,
    required String streakLevel,
  }) async {
    await showLocalNotification(
      title: '🔥 Streak Update: $streakLevel',
      body: 'You have maintained a $streakCount day streak! Keep going!',
      payload: json.encode({
        'type': 'streak_update',
        'streak_count': streakCount,
        'streak_level': streakLevel,
        'timestamp': DateTime.now().toIso8601String(),
      }),
    );
  }

  Future<void> showExpiryReminderNotification({
    required String categoryName,
    required int daysLeft,
  }) async {
    await showLocalNotification(
      title: '⏰ Subscription Expiring Soon',
      body:
          'Your $categoryName subscription expires in $daysLeft days. Renew now!',
      payload: json.encode({
        'type': 'expiry_reminder',
        'category': categoryName,
        'days_left': daysLeft,
        'timestamp': DateTime.now().toIso8601String(),
      }),
    );
  }

  Future<void> scheduleExpiryReminders(
    DateTime expiryDate,
    String categoryName,
  ) async {
    final now = DateTime.now();
    final daysUntilExpiry = expiryDate.difference(now).inDays;

    // Schedule 7-day reminder
    if (daysUntilExpiry > 7) {
      final reminderDate = expiryDate.subtract(const Duration(days: 7));
      if (reminderDate.isAfter(now)) {
        await scheduleNotification(
          title: '⏰ Subscription Expiring Soon',
          body: 'Your $categoryName subscription expires in 7 days. Renew now!',
          scheduledTime: reminderDate,
          payload: json.encode({
            'type': 'expiry_reminder',
            'category': categoryName,
            'days_left': 7,
            'timestamp': reminderDate.toIso8601String(),
          }),
          id: 1001,
        );
      }
    }

    // Schedule 3-day reminder
    if (daysUntilExpiry > 3) {
      final reminderDate = expiryDate.subtract(const Duration(days: 3));
      if (reminderDate.isAfter(now)) {
        await scheduleNotification(
          title: '⚠️ Subscription Expiring Soon',
          body: 'Your $categoryName subscription expires in 3 days. Renew now!',
          scheduledTime: reminderDate,
          payload: json.encode({
            'type': 'expiry_reminder',
            'category': categoryName,
            'days_left': 3,
            'timestamp': reminderDate.toIso8601String(),
          }),
          id: 1002,
        );
      }
    }

    // Schedule expiry day reminder
    if (daysUntilExpiry > 0) {
      final reminderDate = expiryDate.subtract(const Duration(minutes: 30));
      if (reminderDate.isAfter(now)) {
        await scheduleNotification(
          title: '❌ Subscription Expiring Today',
          body: 'Your $categoryName subscription expires today. Renew now!',
          scheduledTime: reminderDate,
          payload: json.encode({
            'type': 'expiry_reminder',
            'category': categoryName,
            'days_left': 0,
            'timestamp': reminderDate.toIso8601String(),
          }),
          id: 1003,
        );
      }
    }
  }

  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
    debugLog('NotificationService', '🗑️ All notifications cancelled');
  }

  Future<void> cancelScheduledNotifications() async {
    await _localNotifications.cancel(1001);
    await _localNotifications.cancel(1002);
    await _localNotifications.cancel(1003);
    debugLog('NotificationService', '🗑️ Scheduled notifications cancelled');
  }

  Future<void> dispose() async {
    await _notificationStreamController.close();
    debugLog('NotificationService', '🔄 Notification service disposed');
  }
}

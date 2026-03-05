import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../services/user_session.dart';
import '../models/notification_model.dart' as notification_model;
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../utils/api_response.dart';

class NotificationProvider with ChangeNotifier {
  final ApiService apiService;
  final DeviceService deviceService;

  List<notification_model.Notification> _notifications = [];
  bool _isLoading = false;
  String? _error;
  int _unreadCount = 0;
  bool _hasLoaded = false;
  DateTime? _lastLoadTime;
  Timer? _refreshTimer;

  static const Duration _cacheDuration = Duration(minutes: 15);
  static const Duration _refreshInterval = Duration(minutes: 5);

  NotificationProvider(
      {required this.apiService, required this.deviceService}) {
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (_hasLoaded && !_isLoading) unawaited(loadNotifications());
    });
  }

  List<notification_model.Notification> get notifications =>
      List.unmodifiable(_notifications);
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get unreadCount => _unreadCount;

  List<notification_model.Notification> get unreadNotifications {
    return _notifications.where((n) => !n.isRead && n.isDelivered).toList();
  }

  List<notification_model.Notification> get readNotifications {
    return _notifications.where((n) => n.isRead && n.isDelivered).toList();
  }

  Future<void> loadNotifications({bool forceRefresh = false}) async {
    if (_isLoading && !forceRefresh) return;

    if (!forceRefresh && _hasLoaded) {
      final now = DateTime.now();
      if (_lastLoadTime != null &&
          now.difference(_lastLoadTime!) < _cacheDuration) {
        return;
      }
    }

    if (!forceRefresh && !_hasLoaded) {
      final cachedNotifications = await deviceService
          .getCacheItem<List<notification_model.Notification>>(
              AppConstants.notificationsCacheKey,
              isUserSpecific: true);
      if (cachedNotifications != null) {
        _notifications = cachedNotifications;
        _unreadCount =
            _notifications.where((n) => !n.isRead && n.isDelivered).length;
        _hasLoaded = true;
        _notifySafely();
        unawaited(_refreshFromApi());
        return;
      }
    }

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      final response = await apiService.getMyNotifications();

      if (response.success && response.data != null) {
        _notifications = response.data ?? [];
        _unreadCount =
            _notifications.where((n) => !n.isRead && n.isDelivered).length;
        _hasLoaded = true;
        _lastLoadTime = DateTime.now();

        await deviceService.saveCacheItem(
            AppConstants.notificationsCacheKey, _notifications,
            ttl: _cacheDuration, isUserSpecific: true);
      } else {
        _error = response.message;
      }
    } catch (e) {
      _error = e.toString();
      if (!_hasLoaded) _error = 'No internet connection';
      debugLog('NotificationProvider', 'Error loading notifications: $e');
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> _refreshFromApi() async {
    try {
      final response = await apiService.getMyNotifications();

      if (response.success && response.data != null) {
        final newNotifications = response.data ?? [];
        final Map<int, notification_model.Notification> notificationMap = {};
        for (final notif in _notifications) {
          notificationMap[notif.logId] = notif;
        }
        for (final notif in newNotifications) {
          notificationMap[notif.logId] = notif;
        }

        _notifications = notificationMap.values.toList()
          ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
        _unreadCount =
            _notifications.where((n) => !n.isRead && n.isDelivered).length;
        _lastLoadTime = DateTime.now();

        await deviceService.saveCacheItem(
            AppConstants.notificationsCacheKey, _notifications,
            ttl: _cacheDuration, isUserSpecific: true);
        if (hasListeners) _notifySafely();
      }
    } catch (e) {
      debugLog('NotificationProvider', 'Error refreshing from API: $e');
    }
  }

  Future<void> refreshUnreadCount() async {
    try {
      final response = await apiService.getUnreadCount();
      if (response.success && response.data != null) {
        _unreadCount = response.data!['unread_count'] ?? 0;
        notifyListeners();
      }
    } catch (e) {
      debugLog('NotificationProvider', 'Refresh unread count error: $e');
    }
  }

  Future<void> markAsRead(int logId) async {
    try {
      final index = _notifications.indexWhere((n) => n.logId == logId);
      if (index != -1) {
        _notifications[index] = notification_model.Notification(
          logId: _notifications[index].logId,
          notificationId: _notifications[index].notificationId,
          title: _notifications[index].title,
          message: _notifications[index].message,
          deliveryStatus: _notifications[index].deliveryStatus,
          isRead: true,
          receivedAt: _notifications[index].receivedAt,
          sentAt: _notifications[index].sentAt,
          readAt: DateTime.now(),
          deliveredAt: _notifications[index].deliveredAt,
          sentBy: _notifications[index].sentBy,
        );

        _unreadCount = unreadNotifications.length;
        await deviceService.saveCacheItem(
            AppConstants.notificationsCacheKey, _notifications,
            ttl: _cacheDuration, isUserSpecific: true);
        _notifySafely();

        unawaited(apiService.markNotificationAsRead(logId));
      }
    } catch (e) {
      debugLog('NotificationProvider', 'Error marking as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      _notifications = _notifications.map((notification) {
        return notification_model.Notification(
          logId: notification.logId,
          notificationId: notification.notificationId,
          title: notification.title,
          message: notification.message,
          deliveryStatus: notification.deliveryStatus,
          isRead: true,
          receivedAt: notification.receivedAt,
          sentAt: notification.sentAt,
          readAt: DateTime.now(),
          deliveredAt: notification.deliveredAt,
          sentBy: notification.sentBy,
        );
      }).toList();

      _unreadCount = 0;
      await deviceService.saveCacheItem(
          AppConstants.notificationsCacheKey, _notifications,
          ttl: _cacheDuration, isUserSpecific: true);
      _notifySafely();

      unawaited(apiService.markAllNotificationsAsRead());
    } catch (e) {
      debugLog('NotificationProvider', 'Error marking all as read: $e');
    }
  }

  Future<void> deleteNotification(int logId) async {
    try {
      _notifications.removeWhere((n) => n.logId == logId);
      _unreadCount = unreadNotifications.length;

      await deviceService.saveCacheItem(
          AppConstants.notificationsCacheKey, _notifications,
          ttl: _cacheDuration, isUserSpecific: true);
      _notifySafely();

      unawaited(apiService.deleteNotification(logId).catchError((e) {
        debugLog('NotificationProvider',
            ' Backend delete failed, but removed locally: $e');
        unawaited(loadNotifications(forceRefresh: true));

        return Future.value(ApiResponse<void>(
          success: false,
          message: 'Backend delete failed, but removed locally',
        ));
      }));
    } catch (e) {
      debugLog('NotificationProvider', '❌ Delete notification error: $e');
    }
  }

  void addNotification(notification_model.Notification notification) {
    _notifications.insert(0, notification);
    if (!notification.isRead && notification.isDelivered) _unreadCount++;
    unawaited(deviceService.saveCacheItem(
        AppConstants.notificationsCacheKey, _notifications,
        ttl: _cacheDuration, isUserSpecific: true));
    _notifySafely();
  }

  notification_model.Notification? getNotificationByLogId(int logId) {
    try {
      return _notifications.firstWhere((n) => n.logId == logId);
    } catch (e) {
      debugLog(
          'NotificationProvider', 'Error finding notification by logId: $e');
      return null;
    }
  }

  void clearNotifications() {
    _notifications.clear();
    _unreadCount = 0;
    _notifySafely();
  }

  void clearError() {
    _error = null;
    _notifySafely();
  }

  Future<void> clearUserData() async {
    debugLog('NotificationProvider', 'Clearing notification data');

    final session = UserSession();
    final isDifferentUser = !await session.isSameUser();
    final isLoggingOut = await _isLoggingOut();

    if (!isDifferentUser || !isLoggingOut) {
      debugLog('NotificationProvider',
          '✅ Same user - preserving notification cache');
      return;
    }

    await deviceService.clearCacheByPrefix('notifications');
    _notifications.clear();
    _unreadCount = 0;
    _hasLoaded = false;
    _lastLoadTime = null;
    _notifySafely();
  }

  Future<bool> _isLoggingOut() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.isLoggingOutKey) ?? false;
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _notifySafely() {
    if (hasListeners) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (hasListeners) notifyListeners();
      });
    }
  }
}

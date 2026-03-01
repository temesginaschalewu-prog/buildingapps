import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../models/notification_model.dart' as AppNotification;
import '../utils/helpers.dart';

class NotificationProvider with ChangeNotifier {
  final ApiService apiService;
  final DeviceService deviceService;

  List<AppNotification.Notification> _notifications = [];
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
      if (_hasLoaded && !_isLoading) loadNotifications();
    });
  }

  List<AppNotification.Notification> get notifications =>
      List.unmodifiable(_notifications);
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get unreadCount => _unreadCount;

  List<AppNotification.Notification> get unreadNotifications {
    return _notifications.where((n) => !n.isRead && n.isDelivered).toList();
  }

  List<AppNotification.Notification> get readNotifications {
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
          .getCacheItem<List<AppNotification.Notification>>('notifications',
              isUserSpecific: true);
      if (cachedNotifications != null) {
        _notifications = cachedNotifications;
        _unreadCount =
            _notifications.where((n) => !n.isRead && n.isDelivered).length;
        _hasLoaded = true;
        _notifySafely();
        _refreshFromApi();
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

        await deviceService.saveCacheItem('notifications', _notifications,
            ttl: _cacheDuration, isUserSpecific: true);
      } else {
        _error = response.message ?? 'Failed to load notifications';
      }
    } catch (e) {
      _error = e.toString();
      if (!_hasLoaded) _error = 'No internet connection';
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
        final Map<int, AppNotification.Notification> notificationMap = {};
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

        await deviceService.saveCacheItem('notifications', _notifications,
            ttl: _cacheDuration, isUserSpecific: true);
        if (hasListeners) _notifySafely();
      }
    } catch (e) {}
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
        _notifications[index] = AppNotification.Notification(
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
        await deviceService.saveCacheItem('notifications', _notifications,
            ttl: _cacheDuration, isUserSpecific: true);
        _notifySafely();

        try {
          await apiService.markNotificationAsRead(logId);
        } catch (e) {}
      }
    } catch (e) {}
  }

  Future<void> markAllAsRead() async {
    try {
      _notifications = _notifications.map((notification) {
        return AppNotification.Notification(
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
      await deviceService.saveCacheItem('notifications', _notifications,
          ttl: _cacheDuration, isUserSpecific: true);
      _notifySafely();

      try {
        await apiService.markAllNotificationsAsRead();
      } catch (e) {}
    } catch (e) {}
  }

  Future<void> deleteNotification(int logId) async {
    try {
      // Remove from local list immediately for UI responsiveness
      _notifications.removeWhere((n) => n.logId == logId);
      _unreadCount = unreadNotifications.length;

      // Save to cache
      await deviceService.saveCacheItem('notifications', _notifications,
          ttl: _cacheDuration, isUserSpecific: true);
      _notifySafely();

      // Call API to delete from backend
      try {
        await apiService.deleteNotification(logId);
        debugLog('NotificationProvider',
            '✅ Deleted notification $logId from backend');
      } catch (e) {
        debugLog('NotificationProvider',
            '⚠️ Backend delete failed, but removed locally: $e');
        // If backend delete fails, we should refresh to sync
        Future.delayed(const Duration(seconds: 2),
            () => loadNotifications(forceRefresh: true));
      }
    } catch (e) {
      debugLog('NotificationProvider', '❌ Delete notification error: $e');
    }
  }

  void addNotification(AppNotification.Notification notification) {
    _notifications.insert(0, notification);
    if (!notification.isRead && notification.isDelivered) _unreadCount++;
    deviceService.saveCacheItem('notifications', _notifications,
        ttl: _cacheDuration, isUserSpecific: true);
    _notifySafely();
  }

  Future<void> clearUserData() async {
    await deviceService.clearCacheByPrefix('notifications');
    _notifications.clear();
    _unreadCount = 0;
    _hasLoaded = false;
    _lastLoadTime = null;
    _notifySafely();
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

  AppNotification.Notification? getNotificationByLogId(int logId) {
    try {
      return _notifications.firstWhere((n) => n.logId == logId);
    } catch (e) {
      return null;
    }
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

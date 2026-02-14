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
      if (_hasLoaded && !_isLoading) {
        loadNotifications();
      }
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

    // Check cache first
    if (!forceRefresh && _hasLoaded) {
      final now = DateTime.now();
      if (_lastLoadTime != null &&
          now.difference(_lastLoadTime!) < _cacheDuration) {
        debugLog('NotificationProvider', 'Using recent cache');
        return;
      }
    }

    // Try to load from cache first for instant UI
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
        debugLog('NotificationProvider',
            '✅ Loaded ${_notifications.length} notifications from cache');

        // Refresh in background
        _refreshFromApi();
        return;
      }
    }

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('NotificationProvider', 'Loading notifications from API');
      final response = await apiService.getMyNotifications();

      if (response.success && response.data != null) {
        _notifications = response.data ?? [];
        _unreadCount =
            _notifications.where((n) => !n.isRead && n.isDelivered).length;
        _hasLoaded = true;
        _lastLoadTime = DateTime.now();

        // Cache the notifications
        await deviceService.saveCacheItem(
          'notifications',
          _notifications,
          ttl: _cacheDuration,
          isUserSpecific: true,
        );

        debugLog('NotificationProvider',
            '✅ Loaded ${_notifications.length} notifications, Unread: $_unreadCount');
      } else {
        _error = response.message ?? 'Failed to load notifications';
        debugLog('NotificationProvider', '❌ API error: ${response.message}');
      }
    } catch (e) {
      _error = e.toString();
      debugLog('NotificationProvider', 'loadNotifications error: $e');

      // If offline and no cache, show empty state with retry option
      if (!_hasLoaded) {
        _error = 'No internet connection';
      }
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> _refreshFromApi() async {
    try {
      debugLog(
          'NotificationProvider', 'Refreshing notifications in background');
      final response = await apiService.getMyNotifications();

      if (response.success && response.data != null) {
        final newNotifications = response.data ?? [];

        // Merge with existing notifications
        final Map<int, AppNotification.Notification> notificationMap = {};
        for (final notif in _notifications) {
          notificationMap[notif.logId] = notif;
        }

        // Update with new data
        for (final notif in newNotifications) {
          notificationMap[notif.logId] = notif;
        }

        _notifications = notificationMap.values.toList()
          ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));

        _unreadCount =
            _notifications.where((n) => !n.isRead && n.isDelivered).length;
        _lastLoadTime = DateTime.now();

        // Update cache
        await deviceService.saveCacheItem(
          'notifications',
          _notifications,
          ttl: _cacheDuration,
          isUserSpecific: true,
        );

        debugLog('NotificationProvider',
            '✅ Background refresh: ${_notifications.length} notifications');

        if (hasListeners) {
          _notifySafely();
        }
      }
    } catch (e) {
      debugLog('NotificationProvider', 'Background refresh error: $e');
      // Silently fail for background refresh
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

        // Update cache
        await deviceService.saveCacheItem(
          'notifications',
          _notifications,
          ttl: _cacheDuration,
          isUserSpecific: true,
        );

        _notifySafely();

        // Try to sync with API
        try {
          await apiService.markNotificationAsRead(logId);
          debugLog('NotificationProvider',
              '✅ Synced read status for notification $logId');
        } catch (e) {
          debugLog(
              'NotificationProvider', '❌ API sync failed for read status: $e');
          // Still keep local state
        }
      }
    } catch (e) {
      debugLog('NotificationProvider', 'Error marking as read: $e');
    }
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

      // Update cache
      await deviceService.saveCacheItem(
        'notifications',
        _notifications,
        ttl: _cacheDuration,
        isUserSpecific: true,
      );

      _notifySafely();

      // Try to sync with API
      try {
        await apiService.markAllNotificationsAsRead();
        debugLog('NotificationProvider', '✅ Synced mark all as read');
      } catch (e) {
        debugLog('NotificationProvider', '❌ API sync failed for mark all: $e');
        // Still keep local state
      }
    } catch (e) {
      debugLog('NotificationProvider', 'Error marking all as read: $e');
    }
  }

  Future<void> deleteNotification(int logId) async {
    try {
      _notifications.removeWhere((n) => n.logId == logId);
      _unreadCount = unreadNotifications.length;

      // Update cache
      await deviceService.saveCacheItem(
        'notifications',
        _notifications,
        ttl: _cacheDuration,
        isUserSpecific: true,
      );

      _notifySafely();

      // Try to sync with API
      try {
        await apiService.deleteNotification(logId);
        debugLog(
            'NotificationProvider', '✅ Synced delete for notification $logId');
      } catch (e) {
        debugLog('NotificationProvider', '❌ API sync failed for delete: $e');
        // Still keep local state
      }
    } catch (e) {
      debugLog('NotificationProvider', 'Error deleting notification: $e');
    }
  }

  void addNotification(AppNotification.Notification notification) {
    _notifications.insert(0, notification);
    if (!notification.isRead && notification.isDelivered) {
      _unreadCount++;
    }

    // Update cache
    deviceService.saveCacheItem(
      'notifications',
      _notifications,
      ttl: _cacheDuration,
      isUserSpecific: true,
    );

    _notifySafely();
  }

  Future<void> clearUserData() async {
    debugLog('NotificationProvider', 'Clearing notification data');

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

  void refreshUnreadCount() {
    _unreadCount = unreadNotifications.length;
    _notifySafely();
  }

  AppNotification.Notification? getNotificationByLogId(int logId) {
    try {
      return _notifications.firstWhere((n) => n.logId == logId);
    } catch (e) {
      return null;
    }
  }

  void addTestNotification() {
    final testNotification = AppNotification.Notification(
      logId: DateTime.now().millisecondsSinceEpoch,
      title: 'Test Notification',
      message: 'This is a test notification to verify the system is working.',
      deliveryStatus: 'delivered',
      isRead: false,
      receivedAt: DateTime.now(),
    );

    _notifications.insert(0, testNotification);
    _unreadCount++;

    deviceService.saveCacheItem(
      'notifications',
      _notifications,
      ttl: Duration(minutes: 5),
      isUserSpecific: true,
    );

    _notifySafely();
    debugLog('NotificationProvider', 'Added test notification');
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _notifySafely() {
    if (hasListeners) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (hasListeners) {
          notifyListeners();
        }
      });
    }
  }
}

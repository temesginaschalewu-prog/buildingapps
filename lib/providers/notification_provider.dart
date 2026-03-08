import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../services/user_session.dart';
import '../services/connectivity_service.dart';
import '../models/notification_model.dart' as notification_model;
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../utils/api_response.dart';

class NotificationProvider with ChangeNotifier {
  final ApiService apiService;
  final DeviceService deviceService;
  final ConnectivityService connectivityService;

  List<notification_model.Notification> _notifications = [];
  bool _isLoading = false;
  String? _error;
  int _unreadCount = 0;
  bool _hasLoaded = false;
  DateTime? _lastLoadTime;
  Timer? _refreshTimer;
  bool _isOffline = false;

  static const Duration _cacheDuration = AppConstants.cacheTTLNotifications;
  static const Duration _refreshInterval = Duration(minutes: 5);

  NotificationProvider({
    required this.apiService,
    required this.deviceService,
    required this.connectivityService,
  }) {
    _setupConnectivityListener();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (_hasLoaded && !_isLoading && !_isOffline) {
        unawaited(loadNotifications());
      }
    });
  }

  void _setupConnectivityListener() {
    connectivityService.onConnectivityChanged.listen((isOnline) {
      if (_isOffline != !isOnline) {
        _isOffline = !isOnline;
        if (!_isOffline && _notifications.isNotEmpty) {
          _refreshFromApi();
        }
        notifyListeners();
      }
    });
  }

  List<notification_model.Notification> get notifications =>
      List.unmodifiable(_notifications);
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get unreadCount => _unreadCount;
  bool get isOffline => _isOffline;

  List<notification_model.Notification> get unreadNotifications {
    return _notifications.where((n) => !n.isRead && n.isDelivered).toList();
  }

  List<notification_model.Notification> get readNotifications {
    return _notifications.where((n) => n.isRead && n.isDelivered).toList();
  }

  Future<void> loadNotifications(
      {bool forceRefresh = false, bool isManualRefresh = false}) async {
    if (_isLoading && !forceRefresh) return;

    // If this is a manual refresh, ALWAYS force refresh
    if (isManualRefresh) {
      forceRefresh = true;
    }

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
        if (!_isOffline) {
          unawaited(_refreshFromApi());
        }
        return;
      }
    }

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      if (_isOffline) {
        _error = 'You are offline. Using cached data.';
        _isLoading = false;
        _notifySafely();

        // THROW exception for manual refresh!
        if (isManualRefresh) {
          throw Exception(
              'Network error. Please check your internet connection.');
        }
        return;
      }

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

        if (isManualRefresh) {
          throw Exception(response.message);
        }
      }
    } catch (e) {
      _error = e.toString();
      if (!_hasLoaded) _error = 'No internet connection';
      debugLog('NotificationProvider', 'Error loading notifications: $e');

      // Re-throw for manual refresh
      if (isManualRefresh) {
        rethrow;
      }
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> _refreshFromApi() async {
    if (_isOffline) return;

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

        if (!_isOffline) {
          unawaited(apiService.markNotificationAsRead(logId));
        } else {
          // Queue for offline sync
          await _queueMarkAsReadOffline(logId);
        }
      }
    } catch (e) {
      debugLog('NotificationProvider', 'Error marking as read: $e');
    }
  }

  Future<void> _queueMarkAsReadOffline(int logId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = await UserSession().getCurrentUserId();

      if (userId == null) return;

      const pendingKey = 'pending_notification_reads';
      final userPendingKey = '${pendingKey}_$userId';
      final existingJson = prefs.getString(userPendingKey);
      List<Map<String, dynamic>> pendingReads = [];

      if (existingJson != null) {
        try {
          pendingReads =
              List<Map<String, dynamic>>.from(jsonDecode(existingJson));
        } catch (e) {
          debugLog('NotificationProvider', 'Error parsing pending reads: $e');
        }
      }

      pendingReads.add({
        'log_id': logId,
        'timestamp': DateTime.now().toIso8601String(),
        'retry_count': 0,
      });

      await prefs.setString(userPendingKey, jsonEncode(pendingReads));
      debugLog('NotificationProvider',
          '📝 Queued mark as read for notification $logId');
    } catch (e) {
      debugLog('NotificationProvider', 'Error queueing mark as read: $e');
    }
  }

  Future<void> syncPendingReads() async {
    if (_isOffline) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = await UserSession().getCurrentUserId();

      if (userId == null) return;

      const pendingKey = 'pending_notification_reads';
      final userPendingKey = '${pendingKey}_$userId';
      final existingJson = prefs.getString(userPendingKey);

      if (existingJson == null) return;

      List<Map<String, dynamic>> pendingReads = [];
      try {
        pendingReads =
            List<Map<String, dynamic>>.from(jsonDecode(existingJson));
      } catch (e) {
        debugLog('NotificationProvider', 'Error parsing pending reads: $e');
        await prefs.remove(userPendingKey);
        return;
      }

      if (pendingReads.isEmpty) return;

      debugLog('NotificationProvider',
          '🔄 Syncing ${pendingReads.length} pending notification reads');

      final List<Map<String, dynamic>> failedReads = [];

      for (final read in pendingReads) {
        try {
          await apiService.markNotificationAsRead(read['log_id']);
          debugLog('NotificationProvider',
              '✅ Synced read for notification ${read['log_id']}');
        } catch (e) {
          debugLog('NotificationProvider', '❌ Failed to sync read: $e');

          final retryCount = (read['retry_count'] ?? 0) + 1;
          if (retryCount <= 3) {
            read['retry_count'] = retryCount;
            failedReads.add(read);
          }
        }
      }

      if (failedReads.isEmpty) {
        await prefs.remove(userPendingKey);
        debugLog('NotificationProvider', '✅ All pending reads synced');
      } else {
        await prefs.setString(userPendingKey, jsonEncode(failedReads));
        debugLog('NotificationProvider',
            '⚠️ ${failedReads.length} reads still pending');
      }
    } catch (e) {
      debugLog('NotificationProvider', 'Error syncing pending reads: $e');
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

      if (!_isOffline) {
        unawaited(apiService.markAllNotificationsAsRead());
      }
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

      if (!_isOffline) {
        unawaited(apiService.deleteNotification(logId).catchError((e) {
          debugLog('NotificationProvider',
              ' Backend delete failed, but removed locally: $e');
          unawaited(loadNotifications(forceRefresh: true));

          return Future.value(ApiResponse<void>(
            success: false,
            message: 'Backend delete failed, but removed locally',
          ));
        }));
      }
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

    // Clear pending reads
    final userId = await session.getCurrentUserId();
    if (userId != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_notification_reads_$userId');
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

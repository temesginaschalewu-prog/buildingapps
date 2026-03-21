// lib/providers/notification_provider.dart
// PRODUCTION-READY FINAL VERSION - FIXED OFFLINE CHECK

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../services/user_session.dart';
import '../services/connectivity_service.dart';
import '../services/hive_service.dart';
import '../services/offline_queue_manager.dart';
import '../models/notification_model.dart' as notification_model;
import '../utils/api_response.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'base_provider.dart';

/// PRODUCTION-READY Notification Provider
class NotificationProvider extends ChangeNotifier
    with
        BaseProvider<NotificationProvider>,
        OfflineAwareProvider<NotificationProvider>,
        BackgroundRefreshMixin<NotificationProvider> {
  @override
  final ConnectivityService connectivityService;

  final ApiService apiService;
  final DeviceService deviceService;
  final HiveService hiveService;
  final OfflineQueueManager offlineQueueManager;

  List<notification_model.Notification> _notifications = [];
  int _unreadCount = 0;
  DateTime? _lastLoadTime;
  DateTime? _lastUnreadRefreshAt;
  Completer<void>? _unreadRefreshCompleter;

  static const Duration _cacheDuration = AppConstants.cacheTTLNotifications;
  static const Duration _minUnreadRefreshInterval = Duration(seconds: 20);
  @override
  Duration get refreshInterval => const Duration(minutes: 5);

  Box? _notificationsBox;

  int _apiCallCount = 0;

  late StreamController<List<notification_model.Notification>>
      _notificationsUpdateController;

  DateTime? _lastBackgroundRefresh;
  static const Duration _minBackgroundInterval = Duration(minutes: 2);

  NotificationProvider({
    required this.apiService,
    required this.deviceService,
    required this.connectivityService,
    required this.hiveService,
    required this.offlineQueueManager,
  }) : _notificationsUpdateController = StreamController<
            List<notification_model.Notification>>.broadcast() {
    log('NotificationProvider constructor called');
    initializeOfflineAware(
      connectivity: connectivityService,
      queue: offlineQueueManager,
    );
    _registerQueueProcessors();
    _init();
  }

  void _registerQueueProcessors() {
    offlineQueueManager.registerProcessor(
      AppConstants.queueActionMarkNotificationRead,
      _processMarkAsRead,
    );
    log('✅ Registered queue processors');
  }

  Future<bool> _processMarkAsRead(Map<String, dynamic> data) async {
    try {
      log('Processing offline mark as read');
      final logId = data['log_id'];
      final response = await apiService.markNotificationAsRead(logId);
      return response.success;
    } catch (e) {
      log('Error processing mark as read: $e');
      return false;
    }
  }

  Future<void> _init() async {
    log('_init() START');
    await _openHiveBoxes();
    await _loadCachedNotifications();

    if (_notifications.isNotEmpty) {
      startBackgroundRefresh();
    }

    log('_init() END');
  }

  Future<void> _openHiveBoxes() async {
    try {
      if (!Hive.isBoxOpen(AppConstants.hiveNotificationsBox)) {
        _notificationsBox =
            await Hive.openBox(AppConstants.hiveNotificationsBox);
      } else {
        _notificationsBox = Hive.box(AppConstants.hiveNotificationsBox);
      }
      log('✅ Hive box opened');
    } catch (e) {
      log('⚠️ Error opening Hive box: $e');
    }
  }

  Future<void> _loadCachedNotifications() async {
    try {
      final userId = await UserSession().getCurrentUserId();
      if (userId == null || _notificationsBox == null) return;

      final cachedKey = 'user_${userId}_notifications';
      final cachedNotifications = _notificationsBox!.get(cachedKey);

      if (cachedNotifications != null && cachedNotifications is List) {
        final List<notification_model.Notification> notifications = [];
        for (final item in cachedNotifications) {
          if (item is notification_model.Notification) {
            notifications.add(item);
          } else if (item is Map<String, dynamic>) {
            notifications.add(notification_model.Notification.fromJson(item));
          }
        }

        if (notifications.isNotEmpty) {
          _notifications = notifications;
          _unreadCount =
              _notifications.where((n) => !n.isRead && n.isDelivered).length;
          setLoaded();
          _lastLoadTime = DateTime.now();
          _notificationsUpdateController.add(_notifications);
          log('✅ Loaded ${_notifications.length} notifications from Hive');
        }
      }
    } catch (e) {
      log('Error loading cached notifications: $e');
    }
  }

  Future<void> _saveToHive() async {
    try {
      final userId = await UserSession().getCurrentUserId();
      if (userId == null || _notificationsBox == null) return;

      final cacheKey = 'user_${userId}_notifications';
      await _notificationsBox!.put(cacheKey, _notifications);
      log('💾 Saved ${_notifications.length} notifications to Hive');
    } catch (e) {
      log('Error saving to Hive: $e');
    }
  }

  // ===== GETTERS =====
  List<notification_model.Notification> get notifications =>
      List.unmodifiable(_notifications);

  int get unreadCount => _unreadCount;

  Stream<List<notification_model.Notification>> get notificationsUpdates =>
      _notificationsUpdateController.stream;

  @override
  bool get isLoaded => _lastLoadTime != null;

  List<notification_model.Notification> get unreadNotifications {
    return _notifications.where((n) => !n.isRead).toList();
  }

  List<notification_model.Notification> get readNotifications {
    return _notifications.where((n) => n.isRead).toList();
  }

  // ===== LOAD NOTIFICATIONS - ✅ FIXED: CHECK CACHE FIRST, NO API CALL OFFLINE =====
  Future<void> loadNotifications({
    bool forceRefresh = false,
    bool isManualRefresh = false,
  }) async {
    _apiCallCount++;
    final callId = _apiCallCount;

    log('loadNotifications() CALL #$callId');

    if (isManualRefresh && isOffline) {
      throw Exception(getUserFriendlyErrorMessage(
          'Network error. Please check your internet connection.'));
    }

    // ✅ CRITICAL: Return cached data IMMEDIATELY if we have it
    if (_notifications.isNotEmpty && !forceRefresh) {
      log('✅ Already have ${_notifications.length} notifications, returning cached');
      setLoaded();
      _notificationsUpdateController.add(_notifications);
      return;
    }

    if (isLoading && !forceRefresh) {
      log('⏳ Already loading, skipping');
      return;
    }

    setLoading();

    try {
      // ✅ STEP 1: ALWAYS try Hive cache first (fastest)
      if (!forceRefresh && _notifications.isEmpty) {
        log('STEP 1: Checking Hive cache');
        final userId = await UserSession().getCurrentUserId();
        if (userId != null && _notificationsBox != null) {
          final cachedKey = 'user_${userId}_notifications';
          final cachedNotifications = _notificationsBox!.get(cachedKey);

          if (cachedNotifications != null && cachedNotifications is List) {
            final List<notification_model.Notification> notifications = [];
            for (final item in cachedNotifications) {
              if (item is notification_model.Notification) {
                notifications.add(item);
              } else if (item is Map<String, dynamic>) {
                notifications
                    .add(notification_model.Notification.fromJson(item));
              }
            }
            if (notifications.isNotEmpty) {
              _notifications = notifications;
              _unreadCount = _notifications
                  .where((n) => !n.isRead && n.isDelivered)
                  .length;
              setLoaded();
              _notificationsUpdateController.add(_notifications);
              log('✅ Using cached notifications from Hive');
              return;
            }
          }
        }
      }

      // ✅ STEP 2: Try DeviceService cache
      if (!forceRefresh && _notifications.isEmpty) {
        log('STEP 2: Checking DeviceService cache');
        final cachedNotifications =
            await deviceService.getCacheItem<List<dynamic>>(
          AppConstants.notificationsCacheKey,
          isUserSpecific: true,
        );

        if (cachedNotifications != null) {
          final List<notification_model.Notification> notifications = [];
          for (final json in cachedNotifications) {
            if (json is Map<String, dynamic>) {
              notifications.add(notification_model.Notification.fromJson(json));
            }
          }
          if (notifications.isNotEmpty) {
            _notifications = notifications;
            _unreadCount =
                _notifications.where((n) => !n.isRead && n.isDelivered).length;
            setLoaded();
            _notificationsUpdateController.add(_notifications);

            await _saveToHive();
            log('✅ Using cached notifications from DeviceService');
            return;
          }
        }
      }

      // ✅ STEP 3: Check offline status - NO API CALL WHEN OFFLINE
      if (isOffline) {
        log('STEP 3: Offline mode - no cached data available');
        _notifications = [];
        _unreadCount = 0;
        setLoaded();
        _notificationsUpdateController.add(_notifications);

        if (isManualRefresh) {
          throw Exception(getUserFriendlyErrorMessage(
              'Network error. Please check your internet connection.'));
        }
        log('ℹ️ Offline with no notifications, showing empty state');
        return;
      }

      // ✅ STEP 4: Only fetch from API if online
      log('STEP 4: Fetching from API');
      final response = await apiService.getMyNotifications();

      if (response.success && response.data != null) {
        _notifications = response.data ?? [];
        _unreadCount =
            _notifications.where((n) => !n.isRead && n.isDelivered).length;
        _lastLoadTime = DateTime.now();
        setLoaded();
        log('✅ Received ${_notifications.length} notifications from API');

        await _saveToHive();

        deviceService.saveCacheItem(
          AppConstants.notificationsCacheKey,
          _notifications.map((n) => n.toJson()).toList(),
          ttl: _cacheDuration,
          isUserSpecific: true,
        );

        _notificationsUpdateController.add(_notifications);
        log('✅ Success! Notifications loaded');
      } else {
        setError(getUserFriendlyErrorMessage(response.message));
        setLoaded();
        log('❌ API error: ${response.message}');
        _notificationsUpdateController.add(_notifications);

        if (isManualRefresh) {
          throw Exception(response.message);
        }
      }
    } catch (e) {
      log('❌ Error loading notifications: $e');

      setError(getUserFriendlyErrorMessage(e));
      setLoaded();

      // Show empty state on error
      _notifications = [];
      _unreadCount = 0;
      _notificationsUpdateController.add(_notifications);

      if (isManualRefresh) {
        rethrow;
      }
    } finally {
      safeNotify();
    }
  }

  Future<void> _refreshFromApi() async {
    if (isOffline) return;

    if (_lastBackgroundRefresh != null &&
        DateTime.now().difference(_lastBackgroundRefresh!) <
            _minBackgroundInterval) {
      log('⏱️ Background refresh rate limited');
      return;
    }
    _lastBackgroundRefresh = DateTime.now();

    try {
      final response = await apiService.getMyNotifications();

      if (response.success && response.data != null) {
        final newNotifications = response.data ?? [];

        final Map<int, notification_model.Notification> notificationMap = {};
        for (final notif in _notifications) {
          notificationMap[notif.logId] = notif;
        }
        for (final notif in newNotifications) {
          if (notificationMap.containsKey(notif.logId)) {
            final existing = notificationMap[notif.logId]!;
            notificationMap[notif.logId] = notification_model.Notification(
              logId: notif.logId,
              notificationId: notif.notificationId,
              title: notif.title,
              message: notif.message,
              deliveryStatus: notif.deliveryStatus,
              isRead: existing.isRead,
              receivedAt: notif.receivedAt,
              sentAt: notif.sentAt,
              readAt: existing.readAt,
              deliveredAt: notif.deliveredAt,
              sentBy: notif.sentBy,
            );
          } else {
            notificationMap[notif.logId] = notif;
          }
        }

        _notifications = notificationMap.values.toList()
          ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
        _unreadCount =
            _notifications.where((n) => !n.isRead && n.isDelivered).length;
        _lastLoadTime = DateTime.now();

        await _saveToHive();

        deviceService.saveCacheItem(
          AppConstants.notificationsCacheKey,
          _notifications.map((n) => n.toJson()).toList(),
          ttl: _cacheDuration,
          isUserSpecific: true,
        );

        _notificationsUpdateController.add(_notifications);
        log('🔄 Background refresh complete - ${_notifications.length} notifications');
      }
    } catch (e) {
      log('Background refresh error: $e');
    }
  }

  Future<void> _recoverFromCache() async {
    log('Attempting cache recovery');
    final userId = await UserSession().getCurrentUserId();
    if (userId != null && _notificationsBox != null) {
      try {
        final cachedKey = 'user_${userId}_notifications';
        final cachedNotifications = _notificationsBox!.get(cachedKey);
        if (cachedNotifications != null && cachedNotifications is List) {
          final List<notification_model.Notification> notifications = [];
          for (final item in cachedNotifications) {
            if (item is notification_model.Notification) {
              notifications.add(item);
            } else if (item is Map<String, dynamic>) {
              notifications.add(notification_model.Notification.fromJson(item));
            }
          }
          if (notifications.isNotEmpty) {
            _notifications = notifications;
            _unreadCount =
                _notifications.where((n) => !n.isRead && n.isDelivered).length;
            _notificationsUpdateController.add(_notifications);
            log('✅ Recovered ${notifications.length} notifications from Hive after error');
            return;
          }
        }
      } catch (e) {
        log('Error recovering from Hive: $e');
      }
    }

    try {
      final cachedNotifications =
          await deviceService.getCacheItem<List<dynamic>>(
        AppConstants.notificationsCacheKey,
        isUserSpecific: true,
      );
      if (cachedNotifications != null) {
        final List<notification_model.Notification> notifications = [];
        for (final json in cachedNotifications) {
          if (json is Map<String, dynamic>) {
            notifications.add(notification_model.Notification.fromJson(json));
          }
        }
        if (notifications.isNotEmpty) {
          _notifications = notifications;
          _unreadCount =
              _notifications.where((n) => !n.isRead && n.isDelivered).length;
          _notificationsUpdateController.add(_notifications);
          log('✅ Recovered ${notifications.length} notifications from DeviceService after error');
        }
      }
    } catch (e) {
      log('Error recovering from DeviceService: $e');
    }
  }

  // ===== MARK AS READ =====
  Future<void> markAsRead(int logId) async {
    log('markAsRead() for notification $logId');

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

        await _saveToHive();

        deviceService.saveCacheItem(
          AppConstants.notificationsCacheKey,
          _notifications.map((n) => n.toJson()).toList(),
          ttl: _cacheDuration,
          isUserSpecific: true,
        );

        _notificationsUpdateController.add(_notifications);
        safeNotify();

        if (connectivityService.isOnline) {
          unawaited(apiService.markNotificationAsRead(logId).catchError((e) {
            log('⚠️ Error marking as read online, queueing: $e');
            unawaited(_queueMarkAsReadOffline(logId));
            return ApiResponse<void>(success: false, message: e.toString());
          }));
        } else {
          await _queueMarkAsReadOffline(logId);
        }
        log('✅ Notification $logId marked as read');
      }
    } catch (e) {
      log('Error marking as read: $e');
    }
  }

  Future<void> _queueMarkAsReadOffline(int logId) async {
    try {
      final userId = await UserSession().getCurrentUserId();
      if (userId == null) return;

      offlineQueueManager.addItem(
        type: AppConstants.queueActionMarkNotificationRead,
        data: {
          'log_id': logId,
          'timestamp': DateTime.now().toIso8601String(),
          'userId': userId,
        },
      );

      log('📝 Queued mark as read for notification $logId');
    } catch (e) {
      log('Error queueing mark as read: $e');
    }
  }

  // ===== MARK ALL AS READ =====
  Future<void> markAllAsRead() async {
    log('markAllAsRead()');

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

      await _saveToHive();

      deviceService.saveCacheItem(
        AppConstants.notificationsCacheKey,
        _notifications.map((n) => n.toJson()).toList(),
        ttl: _cacheDuration,
        isUserSpecific: true,
      );

      _notificationsUpdateController.add(_notifications);
      safeNotify();

      if (connectivityService.isOnline) {
        unawaited(apiService.markAllNotificationsAsRead());
      }
      log('✅ All notifications marked as read');
    } catch (e) {
      log('Error marking all as read: $e');
    }
  }

  // ===== DELETE NOTIFICATION =====
  Future<void> deleteNotification(int logId) async {
    log('deleteNotification() for notification $logId');

    try {
      _notifications.removeWhere((n) => n.logId == logId);
      _unreadCount = unreadNotifications.length;

      await _saveToHive();

      deviceService.saveCacheItem(
        AppConstants.notificationsCacheKey,
        _notifications.map((n) => n.toJson()).toList(),
        ttl: _cacheDuration,
        isUserSpecific: true,
      );

      _notificationsUpdateController.add(_notifications);
      safeNotify();

      if (connectivityService.isOnline) {
        unawaited(apiService.deleteNotification(logId).catchError((e) {
          log('⚠️ Error deleting online, will refresh: $e');
          unawaited(loadNotifications(forceRefresh: true));
          return ApiResponse<void>(success: false, message: e.toString());
        }));
      }
      log('✅ Notification $logId deleted');
    } catch (e) {
      log('Delete notification error: $e');
    }
  }

  // ===== REFRESH UNREAD COUNT =====
  Future<void> refreshUnreadCount({bool force = false}) async {
    log('refreshUnreadCount()');

    if (!connectivityService.isOnline) {
      log('Offline - using cached unread count');
      safeNotify();
      return;
    }

    if (!force && _lastUnreadRefreshAt != null) {
      final elapsed = DateTime.now().difference(_lastUnreadRefreshAt!);
      if (elapsed < _minUnreadRefreshInterval) {
        log('Skipping refresh - too soon');
        return;
      }
    }

    if (_unreadRefreshCompleter != null) {
      log('Waiting for existing refresh');
      await _unreadRefreshCompleter!.future;
      return;
    }

    _unreadRefreshCompleter = Completer<void>();
    try {
      final response = await apiService.getUnreadCount();
      if (response.success && response.data != null) {
        _unreadCount = response.data!['unread_count'] ?? 0;
        _lastUnreadRefreshAt = DateTime.now();
        safeNotify();
        log('✅ Refreshed unread count: $_unreadCount');
      }
    } catch (e) {
      log('Refresh unread count error: $e');
    } finally {
      _unreadRefreshCompleter?.complete();
      _unreadRefreshCompleter = null;
    }
  }

  // ===== ADD NOTIFICATION (for local updates) =====
  void addNotification(notification_model.Notification notification) {
    log('addNotification()');

    _notifications.insert(0, notification);
    if (!notification.isRead && notification.isDelivered) _unreadCount++;

    unawaited(_saveToHive());

    deviceService.saveCacheItem(
      AppConstants.notificationsCacheKey,
      _notifications.map((n) => n.toJson()).toList(),
      ttl: _cacheDuration,
      isUserSpecific: true,
    );

    _notificationsUpdateController.add(_notifications);
    safeNotify();
    log('✅ Notification added locally');
  }

  @override
  Future<void> onBackgroundRefresh() async {
    log('Background refresh triggered');
    if (!isOffline && _notifications.isNotEmpty) {
      await _refreshFromApi();
    }
  }

  @override
  Future<void> onOnlineRefresh() async {
    log('Online - refreshing notifications');
    await loadNotifications(forceRefresh: true);
  }

  Future<void> clearUserData() async {
    final session = UserSession();
    if (!session.shouldClearCacheOnLogout()) return;

    final userId = await session.getCurrentUserId();
    if (userId != null) {
      if (_notificationsBox != null) {
        final cacheKey = 'user_${userId}_notifications';
        await _notificationsBox!.delete(cacheKey);
      }

      await deviceService.clearCacheByPrefix('notifications');
    }

    stopBackgroundRefresh();
    _lastBackgroundRefresh = null;
    _notifications.clear();
    _unreadCount = 0;
    _lastLoadTime = null;

    await _notificationsUpdateController.close();
    _notificationsUpdateController =
        StreamController<List<notification_model.Notification>>.broadcast();
    _notificationsUpdateController.add(_notifications);

    safeNotify();
  }

  @override
  void clearError() {
    super.clearError();
  }

  @override
  void dispose() {
    stopBackgroundRefresh();
    _notificationsUpdateController.close();
    _notificationsBox?.close();
    disposeSubscriptions();
    super.dispose();
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../models/user_model.dart';
import '../models/subscription_model.dart';
import '../models/payment_model.dart';
import '../models/notification_model.dart' as AppNotification;
import '../utils/helpers.dart';

class UserProvider with ChangeNotifier {
  final ApiService apiService;
  final DeviceService deviceService;

  User? _currentUser;
  List<Payment> _payments = [];
  List<AppNotification.Notification> _notifications = [];
  bool _isLoading = false;
  bool _hasLoadedProfile = false;
  bool _hasLoadedNotifications = false;
  bool _hasLoadedPayments = false;
  String? _error;

  // Telegram-style caching
  bool _isBackgroundRefreshing = false;
  bool _hasInitialCache = false;
  Timer? _backgroundRefreshTimer;
  StreamController<User?> _userUpdateController =
      StreamController<User?>.broadcast();
  StreamController<List<Payment>> _paymentsUpdateController =
      StreamController<List<Payment>>.broadcast();
  StreamController<List<AppNotification.Notification>>
      _notificationsUpdateController =
      StreamController<List<AppNotification.Notification>>.broadcast();

  // Cache with expiration
  DateTime? _lastProfileCacheTime;
  DateTime? _lastNotificationsCacheTime;
  DateTime? _lastPaymentsCacheTime;
  static const Duration _cacheExpiry = Duration(minutes: 10);
  static const Duration _backgroundRefreshInterval = Duration(minutes: 10);
  static const Duration _minRefreshInterval = Duration(minutes: 2);
  static final Map<String, DateTime> _lastRefreshTime = {};

  // Track ongoing refreshes to prevent duplicates
  final Map<String, Completer<bool>> _ongoingRefreshes = {};

  UserProvider({required this.apiService, required this.deviceService});

  User? get currentUser => _currentUser;
  List<Payment> get payments => List.unmodifiable(_payments);
  List<AppNotification.Notification> get notifications =>
      List.unmodifiable(_notifications);
  bool get isLoading => _isLoading;
  bool get isBackgroundRefreshing => _isBackgroundRefreshing;
  bool get hasInitialCache => _hasInitialCache;
  String? get error => _error;

  Stream<User?> get userUpdates => _userUpdateController.stream;
  Stream<List<Payment>> get paymentsUpdates => _paymentsUpdateController.stream;
  Stream<List<AppNotification.Notification>> get notificationsUpdates =>
      _notificationsUpdateController.stream;

  bool _shouldRefresh(String type, {bool forceRefresh = false}) {
    if (forceRefresh) return true;

    final lastRefresh = _lastRefreshTime[type];
    if (lastRefresh == null) return true;

    final secondsSinceLastRefresh =
        DateTime.now().difference(lastRefresh).inSeconds;
    return secondsSinceLastRefresh >= _minRefreshInterval.inSeconds;
  }

  Future<bool> _executeRefresh(
    String type,
    Future<void> Function() refreshFunction, {
    bool forceRefresh = false,
  }) async {
    if (!_shouldRefresh(type, forceRefresh: forceRefresh)) {
      debugLog('UserProvider', '⏰ Skipping $type refresh - too soon');
      return false;
    }

    if (_ongoingRefreshes.containsKey(type)) {
      debugLog(
          'UserProvider', '⏳ $type refresh already in progress, waiting...');
      return await _ongoingRefreshes[type]!.future;
    }

    final completer = Completer<bool>();
    _ongoingRefreshes[type] = completer;

    try {
      await refreshFunction();
      _lastRefreshTime[type] = DateTime.now();
      completer.complete(true);
      return true;
    } catch (e) {
      completer.complete(false);
      return false;
    } finally {
      _ongoingRefreshes.remove(type);
    }
  }

  // Telegram-style cache-first loading
  Future<void> loadUserProfile({bool forceRefresh = false}) async {
    // Don't show loading if we have cache (Telegram style)
    if (!forceRefresh && _hasLoadedProfile && _currentUser != null) {
      debugLog('UserProvider', '📦 Using cached profile data');
      _userUpdateController.add(_currentUser);
      return;
    }

    // Show loading only if no cache
    if (!_hasLoadedProfile || forceRefresh) {
      _isLoading = true;
      _notifySafely();
    }

    try {
      debugLog('UserProvider', '🔄 Loading user profile');

      // Try cache first
      if (!forceRefresh) {
        final cachedUser =
            await deviceService.getCacheItem<User>('user_profile');
        if (cachedUser != null) {
          _currentUser = cachedUser;
          _hasLoadedProfile = true;
          _hasInitialCache = true;
          _lastProfileCacheTime = DateTime.now();
          _userUpdateController.add(_currentUser);
          debugLog('UserProvider',
              '✅ Loaded user profile from cache: ${_currentUser?.id}');

          // Start background refresh if cache is stale
          if (_isCacheStale(_lastProfileCacheTime)) {
            unawaited(_refreshProfileInBackground());
          }

          return;
        }
      }

      // Load fresh data
      final response = await apiService.getMyProfile();

      if (response.success) {
        if (response.data is User) {
          _currentUser = response.data;
        } else if (response.data is Map<String, dynamic>) {
          _currentUser = User.fromJson(response.data as Map<String, dynamic>);
        }
      } else {
        throw Exception('Failed to load profile: ${response.message}');
      }

      _hasLoadedProfile = true;
      _hasInitialCache = true;
      _lastProfileCacheTime = DateTime.now();

      // Save to cache
      if (_currentUser != null) {
        await deviceService.saveCacheItem('user_profile', _currentUser!,
            ttl: _cacheExpiry, isUserSpecific: true);
      }

      _userUpdateController.add(_currentUser);
      debugLog('UserProvider', '✅ Loaded user profile: ${_currentUser?.id}');

      // Start background refresh timer
      _startBackgroundRefresh();
    } catch (e) {
      _error = e.toString();
      debugLog('UserProvider', '❌ loadUserProfile error: $e');

      // If we have cache, use it even on error
      if (!forceRefresh && _currentUser != null) {
        _userUpdateController.add(_currentUser);
      } else {
        rethrow;
      }
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> _refreshProfileInBackground() async {
    if (_isBackgroundRefreshing) return;

    await _executeRefresh('profile', () async {
      _isBackgroundRefreshing = true;

      try {
        debugLog('UserProvider', '🔄 Background refreshing profile...');

        final response = await apiService.getMyProfile();

        if (response.success) {
          User? updatedUser;
          if (response.data is User) {
            updatedUser = response.data;
          } else if (response.data is Map<String, dynamic>) {
            updatedUser = User.fromJson(response.data as Map<String, dynamic>);
          }

          if (updatedUser != null && _currentUser?.id == updatedUser.id) {
            _currentUser = updatedUser;
            _lastProfileCacheTime = DateTime.now();

            // Update cache
            await deviceService.saveCacheItem('user_profile', _currentUser!,
                ttl: _cacheExpiry, isUserSpecific: true);

            // Notify only if there are actual changes
            if (_currentUser != null) {
              _userUpdateController.add(_currentUser);
              debugLog('UserProvider', '✅ Background profile refresh complete');
            }
          }
        }
      } catch (e) {
        // Check for rate limiting
        if (e.toString().contains('429') ||
            e.toString().contains('Too many requests')) {
          debugLog('UserProvider', '⚠️ Rate limited in background refresh');
        } else {
          debugLog('UserProvider', '⚠️ Background refresh failed: $e');
        }
      } finally {
        _isBackgroundRefreshing = false;
      }
    });
  }

  Future<void> loadPayments({bool forceRefresh = false}) async {
    if (!forceRefresh && _hasLoadedPayments && _payments.isNotEmpty) {
      debugLog('UserProvider', '📦 Using cached payments data');
      _paymentsUpdateController.add(_payments);
      return;
    }

    if (!_hasLoadedPayments || forceRefresh) {
      _isLoading = true;
      _notifySafely();
    }

    try {
      debugLog('UserProvider', '🔄 Loading payments');

      // Cache first
      if (!forceRefresh) {
        final cachedPayments =
            await deviceService.getCacheItem<List<Payment>>('user_payments');
        if (cachedPayments != null) {
          _payments = cachedPayments;
          _hasLoadedPayments = true;
          _lastPaymentsCacheTime = DateTime.now();
          _paymentsUpdateController.add(_payments);
          debugLog('UserProvider',
              '✅ Loaded payments from cache: ${_payments.length}');

          if (_isCacheStale(_lastPaymentsCacheTime)) {
            unawaited(_refreshPaymentsInBackground());
          }

          return;
        }
      }

      // Fresh load
      final response = await apiService.getMyPayments();
      _payments = response.data ?? [];
      _hasLoadedPayments = true;
      _lastPaymentsCacheTime = DateTime.now();

      // Cache it
      await deviceService.saveCacheItem('user_payments', _payments,
          ttl: _cacheExpiry, isUserSpecific: true);

      _paymentsUpdateController.add(_payments);
      debugLog('UserProvider', '✅ Loaded payments: ${_payments.length}');
    } catch (e) {
      _error = e.toString();
      debugLog('UserProvider', '❌ loadPayments error: $e');

      if (!forceRefresh && _payments.isNotEmpty) {
        _paymentsUpdateController.add(_payments);
      } else {
        rethrow;
      }
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> loadNotifications({bool forceRefresh = false}) async {
    if (!forceRefresh && _hasLoadedNotifications && _notifications.isNotEmpty) {
      debugLog('UserProvider', '📦 Using cached notifications data');
      _notificationsUpdateController.add(_notifications);
      return;
    }

    if (!_hasLoadedNotifications || forceRefresh) {
      _isLoading = true;
      _notifySafely();
    }

    try {
      debugLog('UserProvider', '🔄 Loading notifications');

      // Cache first
      if (!forceRefresh) {
        final cachedNotifications = await deviceService.getCacheItem<
            List<AppNotification.Notification>>('user_notifications');
        if (cachedNotifications != null) {
          _notifications = cachedNotifications;
          _hasLoadedNotifications = true;
          _lastNotificationsCacheTime = DateTime.now();
          _notificationsUpdateController.add(_notifications);
          debugLog('UserProvider',
              '✅ Loaded notifications from cache: ${_notifications.length}');

          if (_isCacheStale(_lastNotificationsCacheTime)) {
            unawaited(_refreshNotificationsInBackground());
          }

          return;
        }
      }

      // Fresh load
      final response = await apiService.getMyNotifications();
      _notifications = response.data ?? [];
      _hasLoadedNotifications = true;
      _lastNotificationsCacheTime = DateTime.now();

      // Cache it
      await deviceService.saveCacheItem('user_notifications', _notifications,
          ttl: _cacheExpiry, isUserSpecific: true);

      _notificationsUpdateController.add(_notifications);
      debugLog(
          'UserProvider', '✅ Loaded notifications: ${_notifications.length}');
    } catch (e) {
      _error = e.toString();
      debugLog('UserProvider', '❌ loadNotifications error: $e');

      if (!forceRefresh && _notifications.isNotEmpty) {
        _notificationsUpdateController.add(_notifications);
      } else {
        rethrow;
      }
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  // Telegram-style background refresh
  void _startBackgroundRefresh() {
    _stopBackgroundRefresh();

    _backgroundRefreshTimer = Timer.periodic(
      _backgroundRefreshInterval,
      (timer) async {
        if (!_isLoading && !_isBackgroundRefreshing) {
          await _refreshAllInBackground();
        }
      },
    );

    debugLog('UserProvider',
        '⏰ Started background refresh timer (every 10 minutes)');
  }

  void _stopBackgroundRefresh() {
    if (_backgroundRefreshTimer != null) {
      _backgroundRefreshTimer!.cancel();
      _backgroundRefreshTimer = null;
    }
  }

  Future<void> _refreshAllInBackground() async {
    debugLog('UserProvider', '🔄 Refreshing all data in background');

    await Future.wait([
      _refreshProfileInBackground(),
      _refreshPaymentsInBackground(),
      _refreshNotificationsInBackground(),
    ], eagerError: false); // Don't let one failure stop others
  }

  Future<void> _refreshPaymentsInBackground() async {
    await _executeRefresh('payments', () async {
      try {
        final response = await apiService.getMyPayments();
        if (response.data != null && response.data!.isNotEmpty) {
          _payments = response.data!;
          _lastPaymentsCacheTime = DateTime.now();

          await deviceService.saveCacheItem('user_payments', _payments,
              ttl: _cacheExpiry, isUserSpecific: true);

          _paymentsUpdateController.add(_payments);
          debugLog('UserProvider', '✅ Background payments refresh complete');
        }
      } catch (e) {
        if (e.toString().contains('429') ||
            e.toString().contains('Too many requests')) {
          debugLog('UserProvider', '⚠️ Rate limited in payments refresh');
        } else {
          debugLog('UserProvider', '⚠️ Background payments refresh failed: $e');
        }
      }
    });
  }

  Future<void> _refreshNotificationsInBackground() async {
    await _executeRefresh('notifications', () async {
      try {
        final response = await apiService.getMyNotifications();
        if (response.data != null) {
          _notifications = response.data!;
          _lastNotificationsCacheTime = DateTime.now();

          await deviceService.saveCacheItem(
              'user_notifications', _notifications,
              ttl: _cacheExpiry, isUserSpecific: true);

          _notificationsUpdateController.add(_notifications);
          debugLog(
              'UserProvider', '✅ Background notifications refresh complete');
        }
      } catch (e) {
        if (e.toString().contains('429') ||
            e.toString().contains('Too many requests')) {
          debugLog('UserProvider', '⚠️ Rate limited in notifications refresh');
        } else {
          debugLog(
              'UserProvider', '⚠️ Background notifications refresh failed: $e');
        }
      }
    });
  }

  bool _isCacheStale(DateTime? cacheTime) {
    if (cacheTime == null) return true;
    return DateTime.now().difference(cacheTime) > _cacheExpiry;
  }

  // FIXED: updateProfile with proper error handling - THIS IS THE CRITICAL PART
  Future<void> updateProfile({
    String? email,
    String? phone,
    String? profileImage,
  }) async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('UserProvider', '✏️ Updating profile...');

      // Call API - this will throw if there's an error
      await apiService.updateMyProfile(
        email: email,
        phone: phone,
        profileImage: profileImage,
      );

      // Only reach here if API call succeeded
      if (_currentUser != null) {
        final updatedUser = User(
          id: _currentUser!.id,
          username: _currentUser!.username,
          email: email ?? _currentUser!.email,
          phone: phone ?? _currentUser!.phone,
          profileImage: profileImage ?? _currentUser!.profileImage,
          schoolId: _currentUser!.schoolId,
          accountStatus: _currentUser!.accountStatus,
          primaryDeviceId: _currentUser!.primaryDeviceId,
          tvDeviceId: _currentUser!.tvDeviceId,
          parentLinked: _currentUser!.parentLinked,
          parentTelegramUsername: _currentUser!.parentTelegramUsername,
          parentLinkDate: _currentUser!.parentLinkDate,
          streakCount: _currentUser!.streakCount,
          lastStreakDate: _currentUser!.lastStreakDate,
          totalStudyTime: _currentUser!.totalStudyTime,
          adminNotes: _currentUser!.adminNotes,
          createdAt: _currentUser!.createdAt,
          updatedAt: DateTime.now(),
        );

        _currentUser = updatedUser;
        _lastProfileCacheTime = DateTime.now();

        // Update cache
        await deviceService.saveCacheItem('user_profile', _currentUser!,
            ttl: _cacheExpiry, isUserSpecific: true);

        _userUpdateController.add(_currentUser);
        debugLog('UserProvider', '✅ Profile updated successfully');
      }
    } catch (e) {
      _error = e.toString();
      debugLog('UserProvider', '❌ updateProfile error: $e');

      // Extract the actual error message from the exception
      String errorMessage = 'Failed to update profile';
      if (e.toString().contains('Email already in use')) {
        errorMessage = 'Email already in use by another user';
      } else if (e.toString().contains('phone')) {
        errorMessage = 'Phone number already in use by another user';
      } else if (e.toString().contains('Invalid email')) {
        errorMessage = 'Please enter a valid email address';
      } else if (e.toString().contains('Invalid phone')) {
        errorMessage = 'Please enter a valid phone number';
      }

      // Throw a clean error message that the UI can display
      throw Exception(errorMessage);
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> markNotificationAsRead(int logId) async {
    final index = _notifications.indexWhere((n) => n.logId == logId);
    if (index != -1) {
      final notification = _notifications[index];
      _notifications[index] = AppNotification.Notification(
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

      // Update cache
      await deviceService.saveCacheItem('user_notifications', _notifications,
          ttl: _cacheExpiry, isUserSpecific: true);

      _notificationsUpdateController.add(_notifications);
      debugLog('UserProvider', '✅ Marked notification $logId as read');
      _notifySafely();
    }
  }

  Future<void> clearUserData() async {
    debugLog('UserProvider', '🧹 Clearing user data');

    await deviceService.clearCacheByPrefix('user_profile');
    await deviceService.clearCacheByPrefix('user_payments');
    await deviceService.clearCacheByPrefix('user_notifications');

    _currentUser = null;
    _payments.clear();
    _notifications.clear();
    _hasLoadedProfile = false;
    _hasLoadedNotifications = false;
    _hasLoadedPayments = false;
    _hasInitialCache = false;
    _lastProfileCacheTime = null;
    _lastNotificationsCacheTime = null;
    _lastPaymentsCacheTime = null;
    _lastRefreshTime.clear();
    _ongoingRefreshes.clear();

    _stopBackgroundRefresh();

    _userUpdateController.add(null);
    _paymentsUpdateController.add(_payments);
    _notificationsUpdateController.add(_notifications);

    debugLog('UserProvider', '✅ User data cleared');
    _notifySafely();
  }

  void clearNotifications() async {
    await deviceService.removeCacheItem('user_notifications');

    _notifications.clear();
    _hasLoadedNotifications = false;
    _lastNotificationsCacheTime = null;

    _notificationsUpdateController.add(_notifications);
    _notifySafely();
  }

  void clearError() {
    _error = null;
    _notifySafely();
  }

  @override
  void dispose() {
    _stopBackgroundRefresh();
    _userUpdateController.close();
    _paymentsUpdateController.close();
    _notificationsUpdateController.close();
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

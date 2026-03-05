import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../services/user_session.dart';
import '../models/user_model.dart';
import '../models/payment_model.dart';
import '../models/notification_model.dart' as notification_model;
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../utils/parsers.dart';

class UserProvider with ChangeNotifier {
  final ApiService apiService;
  final DeviceService deviceService;

  User? _currentUser;
  List<Payment> _payments = [];
  List<notification_model.Notification> _notifications = [];
  bool _isLoading = false;
  bool _hasLoadedProfile = false;
  bool _hasLoadedNotifications = false;
  bool _hasLoadedPayments = false;
  String? _error;
  String? _currentUserId;

  bool _isBackgroundRefreshing = false;
  bool _hasInitialCache = false;
  Timer? _backgroundRefreshTimer;
  final StreamController<User?> _userUpdateController =
      StreamController<User?>.broadcast();
  final StreamController<List<Payment>> _paymentsUpdateController =
      StreamController<List<Payment>>.broadcast();
  final StreamController<List<notification_model.Notification>>
      _notificationsUpdateController =
      StreamController<List<notification_model.Notification>>.broadcast();

  DateTime? _lastProfileCacheTime;
  DateTime? _lastNotificationsCacheTime;
  DateTime? _lastPaymentsCacheTime;
  static const Duration _cacheExpiry = Duration(minutes: 10);
  static const Duration _backgroundRefreshInterval = Duration(minutes: 10);
  static const Duration _minRefreshInterval = Duration(minutes: 2);
  static final Map<String, DateTime> _lastRefreshTime = {};
  final Map<String, Completer<bool>> _ongoingRefreshes = {};

  UserProvider({required this.apiService, required this.deviceService}) {
    _init();
  }

  Future<void> _init() async {
    await _getCurrentUserId();
    _startBackgroundRefresh();
  }

  Future<void> _getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString(AppConstants.currentUserIdKey);
  }

  User? get currentUser => _currentUser;
  List<Payment> get payments => List.unmodifiable(_payments);
  List<notification_model.Notification> get notifications =>
      List.unmodifiable(_notifications);
  bool get isLoading => _isLoading;
  bool get isBackgroundRefreshing => _isBackgroundRefreshing;
  bool get hasInitialCache => _hasInitialCache;
  String? get error => _error;

  Stream<User?> get userUpdates => _userUpdateController.stream;
  Stream<List<Payment>> get paymentsUpdates => _paymentsUpdateController.stream;
  Stream<List<notification_model.Notification>> get notificationsUpdates =>
      _notificationsUpdateController.stream;

  bool get hasActiveSubscription {
    if (_currentUser == null) return false;
    if (_currentUser!.subscriptions == null ||
        _currentUser!.subscriptions!.isEmpty) return false;

    final now = DateTime.now();
    return _currentUser!.subscriptions!.any((sub) {
      final status = sub['status']?.toString() ?? '';
      final expiryStr = sub['expiry_date']?.toString();
      if (expiryStr == null) return false;
      try {
        final expiryDate = DateTime.parse(expiryStr);
        return status == 'active' && expiryDate.isAfter(now);
      } catch (e) {
        return false;
      }
    });
  }

  bool hasActiveSubscriptionForCategory(int categoryId) {
    if (_currentUser == null || _currentUser!.subscriptions == null)
      return false;

    final now = DateTime.now();
    return _currentUser!.subscriptions!.any((sub) {
      final subCategoryId = Parsers.parseInt(sub['category_id']);
      if (subCategoryId != categoryId) return false;

      final status = sub['status']?.toString() ?? '';
      final expiryStr = sub['expiry_date']?.toString();
      if (expiryStr == null) return false;

      try {
        final expiryDate = DateTime.parse(expiryStr);
        return status == 'active' && expiryDate.isAfter(now);
      } catch (e) {
        return false;
      }
    });
  }

  List<Map<String, dynamic>> get activeSubscriptions {
    if (_currentUser == null || _currentUser!.subscriptions == null) return [];

    final now = DateTime.now();
    return _currentUser!.subscriptions!.where((sub) {
      final status = sub['status']?.toString() ?? '';
      final expiryStr = sub['expiry_date']?.toString();
      if (expiryStr == null) return false;

      try {
        final expiryDate = DateTime.parse(expiryStr);
        return status == 'active' && expiryDate.isAfter(now);
      } catch (e) {
        return false;
      }
    }).toList();
  }

  bool _shouldRefresh(String type, {bool forceRefresh = false}) {
    if (forceRefresh) return true;
    final lastRefresh = _lastRefreshTime[type];
    if (lastRefresh == null) return true;
    final secondsSinceLastRefresh =
        DateTime.now().difference(lastRefresh).inSeconds;
    return secondsSinceLastRefresh >= _minRefreshInterval.inSeconds;
  }

  Future<bool> _executeRefresh(
      String type, Future<void> Function() refreshFunction,
      {bool forceRefresh = false}) async {
    if (!_shouldRefresh(type, forceRefresh: forceRefresh)) return false;
    if (_ongoingRefreshes.containsKey(type)) {
      return _ongoingRefreshes[type]!.future;
    }

    final completer = Completer<bool>();
    _ongoingRefreshes[type] = completer;

    try {
      await refreshFunction();
      _lastRefreshTime[type] = DateTime.now();
      completer.complete(true);
      return true;
    } catch (e) {
      debugLog('UserProvider', 'Refresh error for $type: $e');
      completer.complete(false);
      return false;
    } finally {
      _ongoingRefreshes.remove(type);
    }
  }

  bool _isCacheStale(DateTime? cacheTime) {
    if (cacheTime == null) return true;
    return DateTime.now().difference(cacheTime) > _cacheExpiry;
  }

  Future<void> loadUserProfile({bool forceRefresh = false}) async {
    if (!forceRefresh && _hasLoadedProfile && _currentUser != null) {
      _userUpdateController.add(_currentUser);
      return;
    }

    if (!_hasLoadedProfile || forceRefresh) {
      _isLoading = true;
      _notifySafely();
    }

    try {
      if (!forceRefresh && _currentUserId != null) {
        final cachedUser = await deviceService.getCacheItem<User>(
            AppConstants.userProfileKey(_currentUserId!),
            isUserSpecific: true);
        if (cachedUser != null) {
          _currentUser = cachedUser;
          _hasLoadedProfile = true;
          _hasInitialCache = true;
          _lastProfileCacheTime = DateTime.now();
          _userUpdateController.add(_currentUser);
          if (_isCacheStale(_lastProfileCacheTime)) {
            unawaited(_refreshProfileInBackground());
          }
          return;
        }
      }

      final response = await apiService.getMyProfile();
      if (response.success) {
        _currentUser = response.data is User
            ? response.data
            : User.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw Exception('Failed to load profile: ${response.message}');
      }

      _hasLoadedProfile = true;
      _hasInitialCache = true;
      _lastProfileCacheTime = DateTime.now();

      if (_currentUser != null && _currentUserId != null) {
        await deviceService.saveCacheItem(
            AppConstants.userProfileKey(_currentUserId!), _currentUser!,
            ttl: _cacheExpiry, isUserSpecific: true);
      }

      _userUpdateController.add(_currentUser);
    } catch (e) {
      _error = e.toString();
      debugLog('UserProvider', 'Load user profile error: $e');
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
    await _executeRefresh('profile', () async {
      _isBackgroundRefreshing = true;
      try {
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
            if (_currentUserId != null) {
              await deviceService.saveCacheItem(
                  AppConstants.userProfileKey(_currentUserId!), _currentUser!,
                  ttl: _cacheExpiry, isUserSpecific: true);
            }
            if (_currentUser != null) _userUpdateController.add(_currentUser);
          }
        }
      } finally {
        _isBackgroundRefreshing = false;
      }
    });
  }

  Future<void> loadPayments({bool forceRefresh = false}) async {
    if (!forceRefresh && _hasLoadedPayments && _payments.isNotEmpty) {
      _paymentsUpdateController.add(_payments);
      return;
    }

    if (!_hasLoadedPayments || forceRefresh) {
      _isLoading = true;
      _notifySafely();
    }

    try {
      if (!forceRefresh && _currentUserId != null) {
        final cachedPayments = await deviceService.getCacheItem<List<Payment>>(
            AppConstants.userPaymentsKey(_currentUserId!),
            isUserSpecific: true);
        if (cachedPayments != null) {
          _payments = cachedPayments;
          _hasLoadedPayments = true;
          _lastPaymentsCacheTime = DateTime.now();
          _paymentsUpdateController.add(_payments);
          if (_isCacheStale(_lastPaymentsCacheTime)) {
            unawaited(_refreshPaymentsInBackground());
          }
          return;
        }
      }

      final response = await apiService.getMyPayments();
      _payments = response.data ?? [];
      _hasLoadedPayments = true;
      _lastPaymentsCacheTime = DateTime.now();

      if (_currentUserId != null) {
        await deviceService.saveCacheItem(
            AppConstants.userPaymentsKey(_currentUserId!), _payments,
            ttl: _cacheExpiry, isUserSpecific: true);
      }

      _paymentsUpdateController.add(_payments);
    } catch (e) {
      _error = e.toString();
      debugLog('UserProvider', 'Load payments error: $e');
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
      _notificationsUpdateController.add(_notifications);
      return;
    }

    if (!_hasLoadedNotifications || forceRefresh) {
      _isLoading = true;
      _notifySafely();
    }

    try {
      if (!forceRefresh && _currentUserId != null) {
        final cachedNotifications = await deviceService
            .getCacheItem<List<notification_model.Notification>>(
                AppConstants.userNotificationsKey(_currentUserId!),
                isUserSpecific: true);
        if (cachedNotifications != null) {
          _notifications = cachedNotifications;
          _hasLoadedNotifications = true;
          _lastNotificationsCacheTime = DateTime.now();
          _notificationsUpdateController.add(_notifications);
          if (_isCacheStale(_lastNotificationsCacheTime)) {
            unawaited(_refreshNotificationsInBackground());
          }
          return;
        }
      }

      final response = await apiService.getMyNotifications();
      _notifications = response.data ?? [];
      _hasLoadedNotifications = true;
      _lastNotificationsCacheTime = DateTime.now();

      if (_currentUserId != null) {
        await deviceService.saveCacheItem(
            AppConstants.userNotificationsKey(_currentUserId!), _notifications,
            ttl: _cacheExpiry, isUserSpecific: true);
      }

      _notificationsUpdateController.add(_notifications);
    } catch (e) {
      _error = e.toString();
      debugLog('UserProvider', 'Load notifications error: $e');
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

  void _startBackgroundRefresh() {
    _stopBackgroundRefresh();
    _backgroundRefreshTimer =
        Timer.periodic(_backgroundRefreshInterval, (timer) async {
      if (!_isLoading && !_isBackgroundRefreshing) {
        await _refreshAllInBackground();
      }
    });
  }

  void _stopBackgroundRefresh() {
    _backgroundRefreshTimer?.cancel();
    _backgroundRefreshTimer = null;
  }

  Future<void> _refreshAllInBackground() async {
    await Future.wait([
      _refreshProfileInBackground(),
      _refreshPaymentsInBackground(),
      _refreshNotificationsInBackground(),
    ]);
  }

  Future<void> _refreshPaymentsInBackground() async {
    await _executeRefresh('payments', () async {
      try {
        final response = await apiService.getMyPayments();
        if (response.data != null && response.data!.isNotEmpty) {
          _payments = response.data!;
          _lastPaymentsCacheTime = DateTime.now();
          if (_currentUserId != null) {
            await deviceService.saveCacheItem(
                AppConstants.userPaymentsKey(_currentUserId!), _payments,
                ttl: _cacheExpiry, isUserSpecific: true);
          }
          _paymentsUpdateController.add(_payments);
        }
      } catch (e) {
        debugLog('UserProvider', 'Refresh payments error: $e');
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
          if (_currentUserId != null) {
            await deviceService.saveCacheItem(
                AppConstants.userNotificationsKey(_currentUserId!),
                _notifications,
                ttl: _cacheExpiry,
                isUserSpecific: true);
          }
          _notificationsUpdateController.add(_notifications);
        }
      } catch (e) {
        debugLog('UserProvider', 'Refresh notifications error: $e');
      }
    });
  }

  Future<void> updateProfile(
      {String? email, String? phone, String? profileImage}) async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      await apiService.updateMyProfile(
          email: email, phone: phone, profileImage: profileImage);

      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(
          email: email ?? _currentUser!.email,
          phone: phone ?? _currentUser!.phone,
          profileImage: profileImage ?? _currentUser!.profileImage,
        );
        _lastProfileCacheTime = DateTime.now();

        if (_currentUserId != null) {
          await deviceService.saveCacheItem(
              AppConstants.userProfileKey(_currentUserId!), _currentUser!,
              ttl: _cacheExpiry, isUserSpecific: true);
        }
        _userUpdateController.add(_currentUser);
      }
    } catch (e) {
      _error = e.toString();
      debugLog('UserProvider', 'Update profile error: $e');
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
      _notifications[index] = notification_model.Notification(
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

      if (_currentUserId != null) {
        await deviceService.saveCacheItem(
            AppConstants.userNotificationsKey(_currentUserId!), _notifications,
            ttl: _cacheExpiry, isUserSpecific: true);
      }
      _notificationsUpdateController.add(_notifications);
      _notifySafely();
    }
  }

  Future<void> clearUserData() async {
    debugLog('UserProvider', 'Clearing user data');

    final session = UserSession();
    final isDifferentUser = !await session.isSameUser();
    final isLoggingOut = await _isLoggingOut();

    if (!isDifferentUser || !isLoggingOut) {
      debugLog('UserProvider', '✅ Same user - preserving user cache');
      return;
    }

    if (_currentUserId != null) {
      await deviceService.removeCacheItem(
          AppConstants.userProfileKey(_currentUserId!),
          isUserSpecific: true);
      await deviceService.removeCacheItem(
          AppConstants.userPaymentsKey(_currentUserId!),
          isUserSpecific: true);
      await deviceService.removeCacheItem(
          AppConstants.userNotificationsKey(_currentUserId!),
          isUserSpecific: true);
    }

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
    _notifySafely();
  }

  Future<bool> _isLoggingOut() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.isLoggingOutKey) ?? false;
  }

  Future<void> clearNotifications() async {
    if (_currentUserId != null) {
      await deviceService.removeCacheItem(
          AppConstants.userNotificationsKey(_currentUserId!),
          isUserSpecific: true);
    }
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
        if (hasListeners) notifyListeners();
      });
    }
  }
}

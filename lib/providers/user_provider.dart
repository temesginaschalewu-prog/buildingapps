import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  String? _currentUserId;

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
    _currentUserId = prefs.getString('current_user_id');
  }

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
      String type, Future<void> Function() refreshFunction,
      {bool forceRefresh = false}) async {
    if (!_shouldRefresh(type, forceRefresh: forceRefresh)) return false;
    if (_ongoingRefreshes.containsKey(type))
      return await _ongoingRefreshes[type]!.future;

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
            'user_profile_$_currentUserId',
            isUserSpecific: true);
        if (cachedUser != null) {
          _currentUser = cachedUser;
          _hasLoadedProfile = true;
          _hasInitialCache = true;
          _lastProfileCacheTime = DateTime.now();
          _userUpdateController.add(_currentUser);
          if (_isCacheStale(_lastProfileCacheTime))
            unawaited(_refreshProfileInBackground());
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
            'user_profile_$_currentUserId', _currentUser!,
            ttl: _cacheExpiry, isUserSpecific: true);
      }

      _userUpdateController.add(_currentUser);
    } catch (e) {
      _error = e.toString();
      if (!forceRefresh && _currentUser != null)
        _userUpdateController.add(_currentUser);
      else
        rethrow;
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
          if (response.data is User)
            updatedUser = response.data;
          else if (response.data is Map<String, dynamic>)
            updatedUser = User.fromJson(response.data as Map<String, dynamic>);

          if (updatedUser != null && _currentUser?.id == updatedUser.id) {
            _currentUser = updatedUser;
            _lastProfileCacheTime = DateTime.now();
            if (_currentUserId != null) {
              await deviceService.saveCacheItem(
                  'user_profile_$_currentUserId', _currentUser!,
                  ttl: _cacheExpiry, isUserSpecific: true);
            }
            if (_currentUser != null) _userUpdateController.add(_currentUser);
          }
        }
      } catch (e) {
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
            'user_payments_$_currentUserId',
            isUserSpecific: true);
        if (cachedPayments != null) {
          _payments = cachedPayments;
          _hasLoadedPayments = true;
          _lastPaymentsCacheTime = DateTime.now();
          _paymentsUpdateController.add(_payments);
          if (_isCacheStale(_lastPaymentsCacheTime))
            unawaited(_refreshPaymentsInBackground());
          return;
        }
      }

      final response = await apiService.getMyPayments();
      _payments = response.data ?? [];
      _hasLoadedPayments = true;
      _lastPaymentsCacheTime = DateTime.now();

      if (_currentUserId != null) {
        await deviceService.saveCacheItem(
            'user_payments_$_currentUserId', _payments,
            ttl: _cacheExpiry, isUserSpecific: true);
      }

      _paymentsUpdateController.add(_payments);
    } catch (e) {
      _error = e.toString();
      if (!forceRefresh && _payments.isNotEmpty)
        _paymentsUpdateController.add(_payments);
      else
        rethrow;
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
            .getCacheItem<List<AppNotification.Notification>>(
                'user_notifications_$_currentUserId',
                isUserSpecific: true);
        if (cachedNotifications != null) {
          _notifications = cachedNotifications;
          _hasLoadedNotifications = true;
          _lastNotificationsCacheTime = DateTime.now();
          _notificationsUpdateController.add(_notifications);
          if (_isCacheStale(_lastNotificationsCacheTime))
            unawaited(_refreshNotificationsInBackground());
          return;
        }
      }

      final response = await apiService.getMyNotifications();
      _notifications = response.data ?? [];
      _hasLoadedNotifications = true;
      _lastNotificationsCacheTime = DateTime.now();

      if (_currentUserId != null) {
        await deviceService.saveCacheItem(
            'user_notifications_$_currentUserId', _notifications,
            ttl: _cacheExpiry, isUserSpecific: true);
      }

      _notificationsUpdateController.add(_notifications);
    } catch (e) {
      _error = e.toString();
      if (!forceRefresh && _notifications.isNotEmpty)
        _notificationsUpdateController.add(_notifications);
      else
        rethrow;
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  void _startBackgroundRefresh() {
    _stopBackgroundRefresh();
    _backgroundRefreshTimer =
        Timer.periodic(_backgroundRefreshInterval, (timer) async {
      if (!_isLoading && !_isBackgroundRefreshing)
        await _refreshAllInBackground();
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
    ], eagerError: false);
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
                'user_payments_$_currentUserId', _payments,
                ttl: _cacheExpiry, isUserSpecific: true);
          }
          _paymentsUpdateController.add(_payments);
        }
      } catch (e) {}
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
                'user_notifications_$_currentUserId', _notifications,
                ttl: _cacheExpiry, isUserSpecific: true);
          }
          _notificationsUpdateController.add(_notifications);
        }
      } catch (e) {}
    });
  }

  bool _isCacheStale(DateTime? cacheTime) {
    if (cacheTime == null) return true;
    return DateTime.now().difference(cacheTime) > _cacheExpiry;
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
              'user_profile_$_currentUserId', _currentUser!,
              ttl: _cacheExpiry, isUserSpecific: true);
        }
        _userUpdateController.add(_currentUser);
      }
    } catch (e) {
      _error = e.toString();
      String errorMessage = 'Failed to update profile';
      if (e.toString().contains('Email already in use'))
        errorMessage = 'Email already in use by another user';
      else if (e.toString().contains('phone'))
        errorMessage = 'Phone number already in use by another user';
      else if (e.toString().contains('Invalid email'))
        errorMessage = 'Please enter a valid email address';
      else if (e.toString().contains('Invalid phone'))
        errorMessage = 'Please enter a valid phone number';
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

      if (_currentUserId != null) {
        await deviceService.saveCacheItem(
            'user_notifications_$_currentUserId', _notifications,
            ttl: _cacheExpiry, isUserSpecific: true);
      }
      _notificationsUpdateController.add(_notifications);
      _notifySafely();
    }
  }

  Future<void> clearUserData() async {
    if (_currentUserId != null) {
      await deviceService.removeCacheItem('user_profile_$_currentUserId',
          isUserSpecific: true);
      await deviceService.removeCacheItem('user_payments_$_currentUserId',
          isUserSpecific: true);
      await deviceService.removeCacheItem('user_notifications_$_currentUserId',
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

  void clearNotifications() async {
    if (_currentUserId != null) {
      await deviceService.removeCacheItem('user_notifications_$_currentUserId',
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

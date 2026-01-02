import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/user_model.dart';
import '../models/subscription_model.dart';
import '../models/payment_model.dart';
import '../models/notification_model.dart' as AppNotification;
import '../utils/helpers.dart';

class UserProvider with ChangeNotifier {
  final ApiService apiService;

  User? _currentUser;
  List<Payment> _payments = [];
  List<AppNotification.Notification> _notifications = [];
  bool _isLoading = false;
  bool _hasLoadedProfile = false;
  bool _hasLoadedNotifications = false;
  bool _hasLoadedPayments = false;
  String? _error;

  UserProvider({required this.apiService});

  User? get currentUser => _currentUser;
  List<Payment> get payments => List.unmodifiable(_payments);
  List<AppNotification.Notification> get notifications =>
      List.unmodifiable(_notifications);
  bool get isLoading => _isLoading;
  bool get hasLoadedProfile => _hasLoadedProfile;
  bool get hasLoadedNotifications => _hasLoadedNotifications;
  bool get hasLoadedPayments => _hasLoadedPayments;
  String? get error => _error;

  Future<void> loadUserProfile({bool forceRefresh = false}) async {
    if (_isLoading) return;
    if (_hasLoadedProfile && !forceRefresh) return;

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('UserProvider', 'Loading user profile');
      final response = await apiService.getMyProfile();
      _currentUser = response.data;
      _hasLoadedProfile = true;
      debugLog('UserProvider', 'Loaded user profile: ${_currentUser?.id}');
    } catch (e) {
      _error = e.toString();
      debugLog('UserProvider', 'loadUserProfile error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> loadPayments({bool forceRefresh = false}) async {
    if (_isLoading) return;
    if (_hasLoadedPayments && !forceRefresh) return;

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('UserProvider', 'Loading payments');
      final response = await apiService.getMyPayments();
      _payments = response.data ?? [];
      _hasLoadedPayments = true;
      debugLog('UserProvider', 'Loaded payments: ${_payments.length}');
    } catch (e) {
      _error = e.toString();
      debugLog('UserProvider', 'loadPayments error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> loadNotifications({bool forceRefresh = false}) async {
    if (_isLoading) return;
    if (_hasLoadedNotifications && !forceRefresh) return;

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('UserProvider', 'Loading notifications');
      final response = await apiService.getMyNotifications();
      _notifications = response.data ?? [];
      _hasLoadedNotifications = true;
      debugLog(
          'UserProvider', 'Loaded notifications: ${_notifications.length}');
    } catch (e) {
      _error = e.toString();
      debugLog('UserProvider', 'loadNotifications error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

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
      debugLog('UserProvider', 'Updating profile: email=$email phone=$phone');
      await apiService.updateMyProfile(
        email: email,
        phone: phone,
        profileImage: profileImage,
      );

      // Update local user data
      if (_currentUser != null) {
        _currentUser = User(
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
        _hasLoadedProfile = false; // Mark for reload
      }
    } catch (e) {
      _error = e.toString();
      debugLog('UserProvider', 'updateProfile error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> markNotificationAsRead(int notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      final notification = _notifications[index];
      _notifications[index] = AppNotification.Notification(
        id: notification.id,
        title: notification.title,
        message: notification.message,
        deliveryStatus: 'delivered',
        receivedAt: notification.receivedAt,
        sentAt: notification.sentAt,
      );
      debugLog('UserProvider', 'Marked notification $notificationId as read');
      _notifySafely();
    }
  }

  Future<int?> getCategoryIdByName(String categoryName) async {
    return null;
  }

  Future<void> clearNotifications() async {
    _notifications.clear();
    _hasLoadedNotifications = false;
    _notifySafely();
  }

  void clearError() {
    _error = null;
    _notifySafely();
  }

  void clearAllData() {
    _currentUser = null;
    _payments.clear();
    _notifications.clear();
    _hasLoadedProfile = false;
    _hasLoadedNotifications = false;
    _hasLoadedPayments = false;
    _notifySafely();
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

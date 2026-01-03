import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/notification_model.dart' as AppNotification;
import '../utils/helpers.dart';

class NotificationProvider with ChangeNotifier {
  final ApiService apiService;

  List<AppNotification.Notification> _notifications = [];
  bool _isLoading = false;
  String? _error;

  NotificationProvider({required this.apiService});

  List<AppNotification.Notification> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<AppNotification.Notification> get unreadNotifications {
    return _notifications.where((n) => !n.isDelivered).toList();
  }

  List<AppNotification.Notification> get readNotifications {
    return _notifications.where((n) => n.isDelivered).toList();
  }

  int get unreadCount => unreadNotifications.length;

  Future<void> loadNotifications() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugLog('NotificationProvider', 'Loading notifications');
      final response = await apiService.getMyNotifications();
      _notifications = response.data ?? [];
      debugLog('NotificationProvider',
          'Loaded notifications: ${_notifications.length}');
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugLog('NotificationProvider', 'loadNotifications error: $e');
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(int notificationId) async {
    try {
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = AppNotification.Notification(
          id: _notifications[index].id,
          title: _notifications[index].title,
          message: _notifications[index].message,
          deliveryStatus: 'delivered',
          receivedAt: _notifications[index].receivedAt,
          sentAt: _notifications[index].sentAt,
        );
        notifyListeners();
        debugLog('NotificationProvider',
            'Marked notification $notificationId as read');
      }
    } catch (e) {
      debugLog('NotificationProvider', 'Error marking as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      _notifications = _notifications.map((notification) {
        return AppNotification.Notification(
          id: notification.id,
          title: notification.title,
          message: notification.message,
          deliveryStatus: 'delivered',
          receivedAt: notification.receivedAt,
          sentAt: notification.sentAt,
        );
      }).toList();
      notifyListeners();
      debugLog('NotificationProvider', 'Marked all notifications as read');
    } catch (e) {
      debugLog('NotificationProvider', 'Error marking all as read: $e');
    }
  }

  Future<void> deleteNotification(int notificationId) async {
    try {
      _notifications.removeWhere((n) => n.id == notificationId);
      notifyListeners();
      debugLog('NotificationProvider', 'Deleted notification $notificationId');
    } catch (e) {
      debugLog('NotificationProvider', 'Error deleting notification: $e');
    }
  }

  void addNotification(AppNotification.Notification notification) {
    _notifications.insert(0, notification);
    notifyListeners();
  }

  void clearNotifications() {
    _notifications.clear();
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  AppNotification.Notification? getNotificationById(int id) {
    try {
      return _notifications.firstWhere((n) => n.id == id);
    } catch (e) {
      return null;
    }
  }

  // Add test notification for debugging
  void addTestNotification() {
    final testNotification = AppNotification.Notification(
      id: DateTime.now().millisecondsSinceEpoch,
      title: 'Test Notification',
      message: 'This is a test notification to verify the system is working.',
      deliveryStatus: 'pending',
      receivedAt: DateTime.now(),
    );

    _notifications.insert(0, testNotification);
    notifyListeners();
    debugLog('NotificationProvider', 'Added test notification');
  }
}

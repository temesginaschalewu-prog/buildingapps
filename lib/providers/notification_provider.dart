import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/notification_model.dart' as AppNotification;
import '../utils/helpers.dart';

class NotificationProvider with ChangeNotifier {
  final ApiService apiService;

  List<AppNotification.Notification> _notifications = [];
  bool _isLoading = false;
  String? _error;
  int _unreadCount = 0;

  NotificationProvider({required this.apiService});

  List<AppNotification.Notification> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get unreadCount => _unreadCount;

  List<AppNotification.Notification> get unreadNotifications {
    return _notifications.where((n) => !n.isRead && n.isDelivered).toList();
  }

  List<AppNotification.Notification> get readNotifications {
    return _notifications.where((n) => n.isRead && n.isDelivered).toList();
  }

  Future<void> loadNotifications() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugLog('NotificationProvider', 'Loading notifications');
      final response = await apiService.getMyNotifications();
      _notifications = response.data ?? [];

      // Calculate unread count
      _unreadCount =
          _notifications.where((n) => !n.isRead && n.isDelivered).length;

      debugLog('NotificationProvider',
          'Loaded notifications: ${_notifications.length}, Unread: $_unreadCount');
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

        // Update unread count
        _unreadCount = unreadNotifications.length;
        notifyListeners();

        // Call API to mark as read on server
        await apiService.markNotificationAsRead(logId);
        debugLog('NotificationProvider', 'Marked notification $logId as read');
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
      notifyListeners();

      // Call API to mark all as read on server
      await apiService.markAllNotificationsAsRead();
      debugLog('NotificationProvider', 'Marked all notifications as read');
    } catch (e) {
      debugLog('NotificationProvider', 'Error marking all as read: $e');
    }
  }

  Future<void> deleteNotification(int logId) async {
    try {
      _notifications.removeWhere((n) => n.logId == logId);
      _unreadCount = unreadNotifications.length;
      notifyListeners();

      // Call API to delete on server
      await apiService.deleteNotification(logId);
      debugLog('NotificationProvider', 'Deleted notification $logId');
    } catch (e) {
      debugLog('NotificationProvider', 'Error deleting notification: $e');
    }
  }

  void addNotification(AppNotification.Notification notification) {
    _notifications.insert(0, notification);
    if (!notification.isRead && notification.isDelivered) {
      _unreadCount++;
    }
    notifyListeners();
  }

  void clearNotifications() {
    _notifications.clear();
    _unreadCount = 0;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void refreshUnreadCount() {
    _unreadCount = unreadNotifications.length;
    notifyListeners();
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
    notifyListeners();
    debugLog('NotificationProvider', 'Added test notification');
  }
}

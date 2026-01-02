import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../models/notification_model.dart'
    as AppNotification; // Alias to avoid conflict
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
    // Find the notification
    final notification = _notifications.firstWhere(
      (n) => n.id == notificationId,
      orElse: () => AppNotification.Notification(
        id: 0,
        title: '',
        message: '',
        deliveryStatus: 'delivered',
        receivedAt: DateTime.now(),
      ),
    );

    if (notification.id != 0) {
      // In a real app, you would call an API to mark as read
      // For now, we'll just update locally
      final index = _notifications.indexOf(notification);
      _notifications[index] = AppNotification.Notification(
        id: notification.id,
        title: notification.title,
        message: notification.message,
        deliveryStatus: 'delivered', // Mark as delivered
        receivedAt: notification.receivedAt,
        sentAt: notification.sentAt,
      );
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    // In a real app, you would call an API to mark all as read
    // For now, we'll just update locally
    for (int i = 0; i < _notifications.length; i++) {
      final notification = _notifications[i];
      _notifications[i] = AppNotification.Notification(
        id: notification.id,
        title: notification.title,
        message: notification.message,
        deliveryStatus: 'delivered',
        receivedAt: notification.receivedAt,
        sentAt: notification.sentAt,
      );
    }
    notifyListeners();
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

  // Fix for line 48: Check if user is not null before accessing id
  AppNotification.Notification? getNotificationById(int id) {
    try {
      return _notifications.firstWhere((n) => n.id == id);
    } catch (e) {
      return null;
    }
  }
}

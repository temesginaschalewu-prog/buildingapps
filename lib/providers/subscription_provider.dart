import 'package:flutter/material.dart';
import 'package:familyacademyclient/services/api_service.dart';
import 'package:familyacademyclient/models/subscription_model.dart';
import 'package:familyacademyclient/utils/helpers.dart';

class SubscriptionProvider with ChangeNotifier {
  final ApiService apiService;

  List<Subscription> _subscriptions = [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _error;
  Map<int, Subscription> _activeSubscriptionsByCategory = {};

  SubscriptionProvider({required this.apiService});

  List<Subscription> get subscriptions => List.unmodifiable(_subscriptions);
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get error => _error;
  Map<int, Subscription> get activeSubscriptionsByCategory =>
      Map.unmodifiable(_activeSubscriptionsByCategory);

  List<Subscription> getActiveSubscriptions() {
    return _subscriptions.where((s) => s.isActive && !s.hasExpired).toList();
  }

  List<Subscription> getExpiredSubscriptions() {
    return _subscriptions.where((s) => s.hasExpired).toList();
  }

  List<Subscription> getCancelledSubscriptions() {
    return _subscriptions.where((s) => s.isCancelled).toList();
  }

  List<Subscription> getExpiringSoonSubscriptions() {
    return _subscriptions.where((s) => s.isExpiringSoon).toList();
  }

  Future<void> loadSubscriptions({bool forceRefresh = false}) async {
    if (_isLoading) return;
    if (_hasLoaded && !forceRefresh) return;

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('SubscriptionProvider', 'Loading subscriptions');
      final response = await apiService.getMySubscriptions();
      _subscriptions = response.data ?? [];

      // Build category map for quick lookup
      _activeSubscriptionsByCategory = {};
      for (final sub in getActiveSubscriptions()) {
        _activeSubscriptionsByCategory[sub.categoryId] = sub;
      }

      _hasLoaded = true;
      debugLog(
        'SubscriptionProvider',
        'Loaded ${_subscriptions.length} subscriptions, '
            '${getActiveSubscriptions().length} active',
      );
    } catch (e) {
      _error = e.toString();
      debugLog('SubscriptionProvider', 'loadSubscriptions error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<Map<String, dynamic>> checkSubscriptionStatus(int categoryId) async {
    if (_isLoading) return {};

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('SubscriptionProvider',
          'Checking subscription status for category:$categoryId');
      final response = await apiService.checkSubscriptionStatus(categoryId);
      debugLog('SubscriptionProvider',
          'Subscription status response: ${response.data}');
      return response.data ?? {};
    } catch (e) {
      _error = e.toString();
      debugLog('SubscriptionProvider', 'checkSubscriptionStatus error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  bool hasActiveSubscriptionForCategory(int categoryId) {
    return _activeSubscriptionsByCategory.containsKey(categoryId);
  }

  Subscription? getSubscriptionByCategoryId(int categoryId) {
    return _activeSubscriptionsByCategory[categoryId];
  }

  Subscription? getSubscriptionById(int id) {
    try {
      return _subscriptions.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> refreshSubscription(int categoryId) async {
    try {
      debugLog('SubscriptionProvider',
          'Refreshing subscription for category: $categoryId');

      // Force reload subscriptions
      await loadSubscriptions(forceRefresh: true);

      // Also check specific category status
      final status = await checkSubscriptionStatus(categoryId);

      debugLog(
          'SubscriptionProvider', 'Subscription status after refresh: $status');

      if (status['has_subscription'] == true) {
        debugLog('SubscriptionProvider',
            '✅ Subscription active for category: $categoryId');

        // Notify all listeners that subscription state changed
        _notifySafely();
      }
    } catch (e) {
      debugLog('SubscriptionProvider', 'Error refreshing subscription: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getCategorySubscriptionDetails(
      int categoryId) async {
    try {
      final status = await checkSubscriptionStatus(categoryId);

      if (status['has_subscription'] == true) {
        // Update local cache
        final subscription = Subscription.fromJson({
          'id': status['id'],
          'start_date': status['start_date'],
          'expiry_date': status['expiry_date'],
          'status': status['current_status'],
          'billing_cycle': status['billing_cycle'] ?? 'monthly',
          'category_name': status['category_name'] ?? 'Unknown Category',
          'category_id': categoryId,
          'price': status['price'] ?? 0,
          'payment_method': status['payment_method'],
          'payment_status': status['payment_status'],
          'days_remaining': status['days_remaining'] ?? 0,
        });

        _activeSubscriptionsByCategory[categoryId] = subscription;
        _notifySafely();
      }

      return status;
    } catch (e) {
      debugLog(
          'SubscriptionProvider', 'getCategorySubscriptionDetails error: $e');
      return {'has_subscription': false, 'status': 'unpaid'};
    }
  }

// Add this method to force refresh when payment is verified
  Future<void> refreshAfterPaymentVerification() async {
    debugLog('SubscriptionProvider', 'Refreshing after payment verification');

    // Clear current data
    _subscriptions = [];
    _activeSubscriptionsByCategory = {};
    _hasLoaded = false;

    // Reload everything
    await loadSubscriptions(forceRefresh: true);

    debugLog('SubscriptionProvider',
        '✅ Subscriptions refreshed after payment verification');
    _notifySafely();
  }

  bool isSubscriptionExpiringSoon(int categoryId) {
    final sub = getSubscriptionByCategoryId(categoryId);
    return sub != null && sub.isExpiringSoon;
  }

  int getDaysRemaining(int categoryId) {
    final sub = getSubscriptionByCategoryId(categoryId);
    return sub?.daysRemaining ?? 0;
  }

  void clearSubscriptions() {
    _subscriptions = [];
    _activeSubscriptionsByCategory = {};
    _hasLoaded = false;
    _notifySafely();
  }

  void clearError() {
    _error = null;
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

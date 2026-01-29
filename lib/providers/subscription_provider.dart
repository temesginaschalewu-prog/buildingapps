import 'dart:async';
import 'package:flutter/material.dart';
import 'package:familyacademyclient/services/api_service.dart';
import 'package:familyacademyclient/models/subscription_model.dart';
import 'package:familyacademyclient/utils/helpers.dart';

class SubscriptionProvider with ChangeNotifier {
  final ApiService apiService;

  Map<int, Subscription> _subscriptionsByCategory = {};
  List<Subscription> _allSubscriptions = [];
  Map<int, bool> _categoryAccessCache = {};
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _error;
  Timer? _refreshTimer;

  SubscriptionProvider({required this.apiService}) {
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_hasLoaded) {
        loadSubscriptions(forceRefresh: true);
      }
    });
  }

  List<Subscription> get allSubscriptions =>
      List.unmodifiable(_allSubscriptions);
  Map<int, Subscription> get subscriptionsByCategory =>
      Map.unmodifiable(_subscriptionsByCategory);
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get error => _error;

  List<Subscription> get activeSubscriptions {
    return _allSubscriptions.where((sub) => sub.isActive).toList();
  }

  List<Subscription> get expiredSubscriptions {
    return _allSubscriptions.where((sub) => sub.isExpired).toList();
  }

  List<Subscription> get expiringSoonSubscriptions {
    return _allSubscriptions.where((sub) => sub.isExpiringSoon).toList();
  }

  Future<void> loadSubscriptions({bool forceRefresh = false}) async {
    if (_isLoading && !forceRefresh) return;
    if (_hasLoaded && !forceRefresh && !_isLoading) return;

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('SubscriptionProvider', 'Loading subscriptions...');
      final response = await apiService.getMySubscriptions();

      if (response.success && response.data != null) {
        _allSubscriptions = response.data!;

        _subscriptionsByCategory = {};
        _categoryAccessCache = {};

        for (final sub in _allSubscriptions) {
          _subscriptionsByCategory[sub.categoryId] = sub;
          _categoryAccessCache[sub.categoryId] = sub.isActive;
        }

        _hasLoaded = true;
        debugLog('SubscriptionProvider',
            '✅ Loaded ${_allSubscriptions.length} subscriptions, ${activeSubscriptions.length} active');
      } else {
        _error = response.message;
        debugLog('SubscriptionProvider',
            '❌ Failed to load subscriptions: ${response.message}');
      }
    } catch (e, stackTrace) {
      _error = e.toString();
      debugLog('SubscriptionProvider',
          '❌ Error loading subscriptions: $e\n$stackTrace');
      _allSubscriptions = [];
      _subscriptionsByCategory = {};
      _categoryAccessCache = {};
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<bool> checkHasActiveSubscriptionForCategory(int categoryId) async {
    if (_categoryAccessCache.containsKey(categoryId)) {
      return _categoryAccessCache[categoryId]!;
    }

    final subscription = _subscriptionsByCategory[categoryId];
    if (subscription != null) {
      final hasAccess = subscription.isActive;
      _categoryAccessCache[categoryId] = hasAccess;
      return hasAccess;
    }

    try {
      debugLog('SubscriptionProvider',
          'Checking subscription status for category: $categoryId');
      final response = await apiService.checkSubscriptionStatus(categoryId);

      if (response.success && response.data != null) {
        final data = response.data as Map<String, dynamic>;

        if (data['has_subscription'] == true) {
          final subscription = Subscription.fromJson({
            'id': data['id'] ?? 0,
            'user_id': data['user_id'] ?? 0,
            'category_id': categoryId,
            'start_date':
                data['start_date'] ?? DateTime.now().toIso8601String(),
            'expiry_date': data['expiry_date'] ??
                DateTime.now().add(const Duration(days: 30)).toIso8601String(),
            'status': (data['current_status'] ?? data['status'] ?? 'active')
                .toString(),
            'billing_cycle': (data['billing_cycle'] ?? 'monthly').toString(),
            'category_name': data['category_name'] ?? '',
            'price': data['price'] ?? 0.0,
          });

          _subscriptionsByCategory[categoryId] = subscription;

          if (!_allSubscriptions.any((s) => s.id == subscription.id)) {
            _allSubscriptions.add(subscription);
          }

          final hasAccess = subscription.isActive;
          _categoryAccessCache[categoryId] = hasAccess;

          _notifySafely();
          return hasAccess;
        }
      }

      _categoryAccessCache[categoryId] = false;
      return false;
    } catch (e) {
      debugLog(
          'SubscriptionProvider', '❌ Error checking subscription status: $e');

      _categoryAccessCache[categoryId] = false;
      return false;
    }
  }

  bool hasActiveSubscriptionForCategory(int categoryId) {
    return _categoryAccessCache[categoryId] ?? false;
  }

  bool hasPendingPaymentForCategory(int categoryId) {
    return false;
  }

  Subscription? getSubscriptionForCategory(int categoryId) {
    return _subscriptionsByCategory[categoryId];
  }

  Future<void> refreshAfterPaymentVerification() async {
    debugLog(
        'SubscriptionProvider', '🔄 Refreshing after payment verification');

    _allSubscriptions = [];
    _subscriptionsByCategory = {};
    _categoryAccessCache = {};
    _hasLoaded = false;

    await loadSubscriptions(forceRefresh: true);

    debugLog('SubscriptionProvider', '✅ Subscriptions refreshed');
    _notifySafely();
  }

  Future<void> refreshCategorySubscription(int categoryId) async {
    try {
      _categoryAccessCache.remove(categoryId);

      await loadSubscriptions(forceRefresh: true);

      debugLog('SubscriptionProvider',
          '✅ Refreshed subscription for category: $categoryId');
    } catch (e) {
      debugLog('SubscriptionProvider',
          '❌ Error refreshing category subscription: $e');
    }
  }

  void clearSubscriptions() {
    _allSubscriptions = [];
    _subscriptionsByCategory = {};
    _categoryAccessCache = {};
    _hasLoaded = false;
    _notifySafely();
  }

  void clearError() {
    _error = null;
    _notifySafely();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
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

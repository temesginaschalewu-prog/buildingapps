import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../services/user_session.dart';
import '../models/subscription_model.dart';
import '../providers/category_provider.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class SubscriptionProvider with ChangeNotifier {
  final ApiService apiService;
  final DeviceService deviceService;

  Map<int, Subscription> _subscriptionsByCategory = {};
  List<Subscription> _allSubscriptions = [];
  Map<int, bool> _categoryAccessCache = {};
  Map<int, bool> _categoryCheckComplete = {};
  Map<int, DateTime> _lastCheckTime = {};

  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _error;

  Timer? _backgroundRefreshTimer;
  static const Duration _backgroundRefreshInterval = Duration(minutes: 5);
  static const Duration _cacheDuration = Duration(minutes: 30);

  DateTime? _lastBackgroundRefreshTime;

  final StreamController<Map<int, bool>> _subscriptionUpdateController =
      StreamController<Map<int, bool>>.broadcast();
  final StreamController<List<Subscription>> _subscriptionsUpdateController =
      StreamController<List<Subscription>>.broadcast();
  final StreamController<int> _subscriptionStatusChangedController =
      StreamController<int>.broadcast();

  final Map<int, Completer<bool>> _categoryCheckCompleters = {};
  static const Duration _categoryCheckTimeout = Duration(seconds: 10);

  CategoryProvider? _categoryProvider;

  SubscriptionProvider({
    required this.apiService,
    required this.deviceService,
  }) {
    _initBackgroundRefresh();
  }

  void setCategoryProvider(CategoryProvider categoryProvider) {
    _categoryProvider = categoryProvider;
    debugLog('SubscriptionProvider', '✅ CategoryProvider reference set');
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

  Stream<Map<int, bool>> get subscriptionUpdates =>
      _subscriptionUpdateController.stream;
  Stream<List<Subscription>> get subscriptionsUpdates =>
      _subscriptionsUpdateController.stream;
  Stream<int> get subscriptionStatusChanged =>
      _subscriptionStatusChangedController.stream;

  bool hasActiveSubscriptionForCategory(int categoryId) {
    if (_categoryAccessCache.containsKey(categoryId)) {
      return _categoryAccessCache[categoryId]!;
    }

    final subscription = _subscriptionsByCategory[categoryId];
    if (subscription != null) {
      final isActive = subscription.isActive;
      _categoryAccessCache[categoryId] = isActive;
      _categoryCheckComplete[categoryId] = true;
      _lastCheckTime[categoryId] = DateTime.now();
      return isActive;
    }

    return false;
  }

  List<int> getCategoriesWithActiveSubscription() {
    final List<int> result = [];
    _categoryAccessCache.forEach((categoryId, hasAccess) {
      if (hasAccess) result.add(categoryId);
    });
    return result;
  }

  void _initBackgroundRefresh() {
    _backgroundRefreshTimer = Timer.periodic(_backgroundRefreshInterval, (_) {
      if (_hasLoaded && !_isLoading) {
        _performBackgroundRefresh();
      }
    });
  }

  Future<void> _performBackgroundRefresh() async {
    if (_lastBackgroundRefreshTime != null) {
      final minutesSinceLastRefresh =
          DateTime.now().difference(_lastBackgroundRefreshTime!).inMinutes;
      if (minutesSinceLastRefresh < 2) {
        debugLog('SubscriptionProvider',
            '⏰ Skipping background refresh - only $minutesSinceLastRefresh minutes since last refresh');
        return;
      }
    }

    _lastBackgroundRefreshTime = DateTime.now();
    await _refreshInBackground();
  }

  Future<void> _refreshInBackground() async {
    debugLog('SubscriptionProvider', '🔄 Background refresh started');

    try {
      final response = await apiService.getMySubscriptions();

      if (response.success && response.data != null) {
        final newSubscriptions = response.data!;

        final bool hasChanges = _hasSubscriptionChanges(newSubscriptions);

        if (hasChanges) {
          debugLog(
              'SubscriptionProvider', '📦 Changes detected, updating cache');
          _allSubscriptions = newSubscriptions;
          await deviceService.saveCacheItem(
              AppConstants.subscriptionsCacheKey, _allSubscriptions,
              ttl: _cacheDuration, isUserSpecific: true);

          _rebuildCacheFromSubscriptions();
          _notifyChanges();
        } else {
          debugLog('SubscriptionProvider', '✅ No changes detected');
        }
      } else {
        debugLog(
            'SubscriptionProvider', '⚠️ Background refresh returned no data');
      }
    } catch (e) {
      if (e.toString().contains('429') ||
          e.toString().contains('Too many requests')) {
        debugLog('SubscriptionProvider',
            '⚠️ Rate limited in background, will retry later');
      } else {
        debugLog('SubscriptionProvider', '⚠️ Background refresh failed: $e');
      }
    }
  }

  bool _hasSubscriptionChanges(List<Subscription> newSubscriptions) {
    if (_allSubscriptions.length != newSubscriptions.length) return true;

    for (int i = 0; i < newSubscriptions.length; i++) {
      if (!_allSubscriptions.any((s) =>
          s.id == newSubscriptions[i].id &&
          s.isActive == newSubscriptions[i].isActive)) {
        return true;
      }
    }

    return false;
  }

  Future<void> loadSubscriptions({bool forceRefresh = false}) async {
    if (_isLoading && !forceRefresh) return;

    if (_hasLoaded && !forceRefresh && _allSubscriptions.isNotEmpty) {
      debugLog('SubscriptionProvider', '📦 Using cached subscriptions');
      return;
    }

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('SubscriptionProvider', '📥 Loading subscriptions...');

      if (!forceRefresh) {
        final cachedSubscriptions =
            await deviceService.getCacheItem<List<Subscription>>(
                AppConstants.subscriptionsCacheKey,
                isUserSpecific: true);

        if (cachedSubscriptions != null && cachedSubscriptions.isNotEmpty) {
          _allSubscriptions = cachedSubscriptions;
          _rebuildCacheFromSubscriptions();
          _hasLoaded = true;
          _isLoading = false;
          _notifySafely();
          _subscriptionsUpdateController.add(_allSubscriptions);

          if (_categoryProvider != null) {
            final statusMap = <int, bool>{};
            for (final sub in _allSubscriptions) {
              statusMap[sub.categoryId] = sub.isActive;
            }
            unawaited(
                _categoryProvider!.batchUpdateSubscriptionStatus(statusMap));
          }

          debugLog('SubscriptionProvider',
              '✅ Loaded ${_allSubscriptions.length} subscriptions from cache');
          return;
        }
      }

      final response = await apiService.getMySubscriptions();

      if (response.success && response.data != null) {
        _allSubscriptions = response.data!;

        await deviceService.saveCacheItem(
            AppConstants.subscriptionsCacheKey, _allSubscriptions,
            ttl: _cacheDuration, isUserSpecific: true);

        _rebuildCacheFromSubscriptions();
        _hasLoaded = true;

        debugLog('SubscriptionProvider',
            '✅ Loaded ${_allSubscriptions.length} subscriptions, ${activeSubscriptions.length} active');

        _notifyChanges();

        if (_categoryProvider != null) {
          final statusMap = <int, bool>{};
          for (final sub in _allSubscriptions) {
            statusMap[sub.categoryId] = sub.isActive;
          }
          unawaited(
              _categoryProvider!.batchUpdateSubscriptionStatus(statusMap));
        }
      } else {
        _error = response.message;
        debugLog('SubscriptionProvider',
            '❌ Failed to load subscriptions: ${response.message}');
      }
    } catch (e) {
      _error = e.toString();
      debugLog('SubscriptionProvider', '❌ Error loading subscriptions: $e');

      if (e.toString().contains('429') ||
          e.toString().contains('Too many requests')) {
        debugLog('SubscriptionProvider', '⚠️ Rate limited, using cached data');
        if (_allSubscriptions.isEmpty) {
          final cachedSubscriptions =
              await deviceService.getCacheItem<List<Subscription>>(
                  AppConstants.subscriptionsCacheKey,
                  isUserSpecific: true);
          if (cachedSubscriptions != null && cachedSubscriptions.isNotEmpty) {
            _allSubscriptions = cachedSubscriptions;
            _rebuildCacheFromSubscriptions();
            _hasLoaded = true;
            debugLog('SubscriptionProvider',
                '✅ Recovered from cache after rate limit');
          }
        }
      } else if (_allSubscriptions.isEmpty) {
        _allSubscriptions = [];
        _rebuildCacheFromSubscriptions();
      }
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  void _rebuildCacheFromSubscriptions() {
    debugLog('SubscriptionProvider',
        '🔄 Rebuilding cache from ${_allSubscriptions.length} subscriptions');

    _subscriptionsByCategory = {};
    _categoryAccessCache = {};
    _categoryCheckComplete = {};
    _lastCheckTime = {};

    for (final sub in _allSubscriptions) {
      final isActive = sub.isActive;

      _subscriptionsByCategory[sub.categoryId] = sub;
      _categoryAccessCache[sub.categoryId] = isActive;
      _categoryCheckComplete[sub.categoryId] = true;
      _lastCheckTime[sub.categoryId] = DateTime.now();

      debugLog('SubscriptionProvider',
          '✅ Category ${sub.categoryId} access set to: $isActive');
    }
  }

  void _notifyChanges() {
    _subscriptionsUpdateController.add(_allSubscriptions);
    _subscriptionUpdateController.add(Map.from(_categoryAccessCache));
    for (final categoryId in _categoryAccessCache.keys) {
      _subscriptionStatusChangedController.add(categoryId);
    }
  }

  Future<bool> checkHasActiveSubscriptionForCategory(int categoryId) async {
    debugLog('SubscriptionProvider',
        '🔍 Checking subscription for category: $categoryId');

    if (_categoryAccessCache.containsKey(categoryId)) {
      final result = _categoryAccessCache[categoryId]!;
      debugLog('SubscriptionProvider',
          '✅ Cache hit - category $categoryId: $result');
      return result;
    }

    if (_categoryCheckCompleters.containsKey(categoryId)) {
      debugLog('SubscriptionProvider',
          '⏳ Waiting for existing check for category: $categoryId');
      try {
        return await _categoryCheckCompleters[categoryId]!
            .future
            .timeout(_categoryCheckTimeout);
      } on TimeoutException {
        debugLog(
            'SubscriptionProvider', '⏰ Category check timeout for $categoryId');
        return false;
      }
    }

    final completer = Completer<bool>();
    _categoryCheckCompleters[categoryId] = completer;

    try {
      final response = await apiService.checkSubscriptionStatus(categoryId);

      if (response.success && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final hasSubscription = data['has_subscription'] == true;

        _categoryAccessCache[categoryId] = hasSubscription;
        _categoryCheckComplete[categoryId] = true;
        _lastCheckTime[categoryId] = DateTime.now();

        if (hasSubscription && data['id'] != null) {
          final subscription = Subscription(
            id: data['id'] as int? ?? 0,
            userId: data['user_id'] as int? ?? 0,
            categoryId: categoryId,
            startDate: DateTime.parse(data['start_date'] as String),
            expiryDate: DateTime.parse(data['expiry_date'] as String),
            status: data['status'] as String? ?? 'active',
            billingCycle: data['billing_cycle'] as String? ?? 'monthly',
            paymentId: data['payment_id'] as int?,
            createdAt: data['created_at'] != null
                ? DateTime.parse(data['created_at'] as String)
                : null,
            updatedAt: data['updated_at'] != null
                ? DateTime.parse(data['updated_at'] as String)
                : null,
            categoryName: data['category_name'] as String?,
            price: data['price'] != null
                ? double.parse(data['price'].toString())
                : null,
          );

          _subscriptionsByCategory[categoryId] = subscription;
          if (!_allSubscriptions.any((s) => s.id == subscription.id)) {
            _allSubscriptions.add(subscription);
            unawaited(deviceService.saveCacheItem(
                AppConstants.subscriptionsCacheKey, _allSubscriptions,
                ttl: _cacheDuration, isUserSpecific: true));
          }
        }

        _subscriptionUpdateController.add({categoryId: hasSubscription});
        _subscriptionStatusChangedController.add(categoryId);

        if (_categoryProvider != null) {
          unawaited(_categoryProvider!
              .updateCategorySubscriptionStatus(categoryId, hasSubscription));
        }

        debugLog('SubscriptionProvider',
            '✅ API check - category $categoryId: $hasSubscription');
        completer.complete(hasSubscription);
        return hasSubscription;
      }

      _categoryAccessCache[categoryId] = false;
      _categoryCheckComplete[categoryId] = true;
      _lastCheckTime[categoryId] = DateTime.now();

      _subscriptionUpdateController.add({categoryId: false});
      _subscriptionStatusChangedController.add(categoryId);

      if (_categoryProvider != null) {
        unawaited(_categoryProvider!
            .updateCategorySubscriptionStatus(categoryId, false));
      }

      completer.complete(false);
      return false;
    } catch (e) {
      debugLog('SubscriptionProvider', '❌ Error checking subscription: $e');

      completer.complete(false);
      return false;
    } finally {
      _categoryCheckCompleters.remove(categoryId);
    }
  }

  Future<Map<int, bool>> checkSubscriptionsForCategories(
      List<int> categoryIds) async {
    final results = <int, bool>{};
    final updates = <int, bool>{};

    debugLog('SubscriptionProvider',
        '🔄 Checking subscriptions for categories: $categoryIds');

    for (final categoryId in categoryIds) {
      if (_categoryAccessCache.containsKey(categoryId)) {
        results[categoryId] = _categoryAccessCache[categoryId]!;
        updates[categoryId] = results[categoryId]!;
      }
    }

    final missingIds =
        categoryIds.where((id) => !results.containsKey(id)).toList();

    if (missingIds.isNotEmpty) {
      final futures = missingIds.map(checkHasActiveSubscriptionForCategory);
      final newResults = await Future.wait(futures);

      for (int i = 0; i < missingIds.length; i++) {
        results[missingIds[i]] = newResults[i];
        updates[missingIds[i]] = newResults[i];
      }
    }

    if (_categoryProvider != null && updates.isNotEmpty) {
      unawaited(_categoryProvider!.batchUpdateSubscriptionStatus(updates));
    }

    debugLog(
        'SubscriptionProvider', '✅ Final subscription check results: $results');
    return results;
  }

  Future<void> preCheckActiveCategories(List<int> categoryIds) async {
    if (categoryIds.isEmpty) return;

    debugLog('SubscriptionProvider',
        '🔍 Pre-checking ${categoryIds.length} categories');

    final futures = <Future>[];
    final updates = <int, bool>{};

    for (final categoryId in categoryIds) {
      if (!_categoryAccessCache.containsKey(categoryId)) {
        futures.add(
            checkHasActiveSubscriptionForCategory(categoryId).then((result) {
          updates[categoryId] = result;
        }));
      }
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures);

      if (_categoryProvider != null && updates.isNotEmpty) {
        unawaited(_categoryProvider!.batchUpdateSubscriptionStatus(updates));
      }
    }
  }

  Future<void> refreshAfterPaymentVerification() async {
    debugLog(
        'SubscriptionProvider', '🔄 Refreshing after payment verification');

    await deviceService.clearCacheByPrefix('subscriptions');

    _allSubscriptions = [];
    _subscriptionsByCategory = {};
    _categoryAccessCache = {};
    _categoryCheckComplete = {};
    _lastCheckTime = {};
    _hasLoaded = false;

    await loadSubscriptions(forceRefresh: true);
    debugLog('SubscriptionProvider', '✅ Subscriptions refreshed');
  }

  Future<void> refreshCategorySubscription(int categoryId) async {
    try {
      await deviceService.removeCacheItem(
          AppConstants.categoryAccessKey(categoryId),
          isUserSpecific: true);

      _categoryAccessCache.remove(categoryId);
      _categoryCheckComplete.remove(categoryId);
      _lastCheckTime.remove(categoryId);

      await checkHasActiveSubscriptionForCategory(categoryId);
      debugLog('SubscriptionProvider',
          '✅ Refreshed subscription for category: $categoryId');
    } catch (e) {
      debugLog('SubscriptionProvider',
          '❌ Error refreshing category subscription: $e');
    }
  }

  Future<void> forceRefreshAllCategories() async {
    debugLog('SubscriptionProvider',
        '🔄 Force refreshing all category subscriptions');

    _categoryAccessCache.clear();
    _categoryCheckComplete.clear();
    _lastCheckTime.clear();
    _categoryCheckCompleters.clear();

    await deviceService.clearCacheByPrefix('subscriptions');
    await loadSubscriptions(forceRefresh: true);

    debugLog('SubscriptionProvider', '✅ All categories refreshed');
  }

  Future<void> clearUserData() async {
    debugLog('SubscriptionProvider', ' Clearing subscription data');

    final session = UserSession();
    final isDifferentUser = !await session.isSameUser();
    final isLoggingOut = await _isLoggingOut();

    if (!isDifferentUser || !isLoggingOut) {
      debugLog('SubscriptionProvider',
          '✅ Same user - preserving subscription cache');
      return;
    }

    await deviceService.clearCacheByPrefix('subscriptions');

    _allSubscriptions = [];
    _subscriptionsByCategory = {};
    _categoryAccessCache = {};
    _categoryCheckComplete = {};
    _lastCheckTime = {};
    _hasLoaded = false;
    _categoryCheckCompleters.clear();

    _subscriptionUpdateController.add({});
    _subscriptionsUpdateController.add([]);

    _notifySafely();
  }

  Future<bool> _isLoggingOut() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.isLoggingOutKey) ?? false;
  }

  void clearError() {
    _error = null;
    _notifySafely();
  }

  @override
  void dispose() {
    _backgroundRefreshTimer?.cancel();
    _subscriptionUpdateController.close();
    _subscriptionsUpdateController.close();
    _subscriptionStatusChangedController.close();
    _categoryCheckCompleters.clear();
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

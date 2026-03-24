// lib/providers/subscription_provider.dart
// PRODUCTION-READY FINAL VERSION - WITH FORCE CACHE INVALIDATION

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../services/user_session.dart';
import '../services/connectivity_service.dart';
import '../services/hive_service.dart';
import '../services/offline_queue_manager.dart';
import '../models/subscription_model.dart';
import '../models/user_model.dart';
import '../providers/category_provider.dart';
import '../utils/constants.dart';
import '../utils/api_response.dart';
import '../utils/helpers.dart';
import 'base_provider.dart';

class SubscriptionProvider extends ChangeNotifier
    with
        BaseProvider<SubscriptionProvider>,
        OfflineAwareProvider<SubscriptionProvider> {
  final ConnectivityService _connectivityService;

  final ApiService apiService;
  final DeviceService deviceService;
  final HiveService hiveService;
  final OfflineQueueManager offlineQueueManager;

  Map<int, Subscription> _subscriptionsByCategory = {};
  List<Subscription> _allSubscriptions = [];
  Map<int, bool> _categoryAccessCache = {};
  Map<int, bool> _categoryCheckComplete = {};

  bool _hasLoaded = false;
  bool _hasInitialData = false;

  DateTime? _lastBackgroundRefreshTime;
  Box? _subscriptionsBox;

  int _apiCallCount = 0;

  late StreamController<Map<int, bool>> _subscriptionUpdateController;
  late StreamController<List<Subscription>> _subscriptionsUpdateController;

  final Map<int, Completer<bool>> _categoryCheckCompleters = {};
  static const Duration _categoryCheckTimeout = Duration(seconds: 10);

  static const int _maxConcurrentRequests = 2;
  int _activeRequests = 0;
  final List<Map<String, dynamic>> _pendingRequests = [];

  DateTime? _lastBackgroundRefresh;
  static const Duration _minBackgroundInterval = Duration(minutes: 2);

  CategoryProvider? _categoryProvider;

  DateTime? _lastBatchCheck;
  static const Duration _batchCheckCooldown = Duration(seconds: 30);

  SubscriptionProvider({
    required this.apiService,
    required this.deviceService,
    required ConnectivityService connectivityService,
    required this.hiveService,
    required this.offlineQueueManager,
  })  : _connectivityService = connectivityService,
        _subscriptionUpdateController =
            StreamController<Map<int, bool>>.broadcast(),
        _subscriptionsUpdateController =
            StreamController<List<Subscription>>.broadcast() {
    log('SubscriptionProvider constructor called');
    initializeOfflineAware(
      connectivity: connectivityService,
      queue: offlineQueueManager,
    );
    _init();
  }

  @override
  ConnectivityService get connectivityService => _connectivityService;

  Future<void> _init() async {
    log('_init() START');
    await _openHiveBox();
    await _loadCachedData();

    _hasInitialData = _allSubscriptions.isNotEmpty;
    log('_init() END');
  }

  Future<void> _openHiveBox() async {
    try {
      if (!Hive.isBoxOpen(AppConstants.hiveSubscriptionsBox)) {
        _subscriptionsBox =
            await Hive.openBox<dynamic>(AppConstants.hiveSubscriptionsBox);
      } else {
        _subscriptionsBox =
            Hive.box<dynamic>(AppConstants.hiveSubscriptionsBox);
      }
      log('✅ Hive box opened');
    } catch (e) {
      log('⚠️ Error opening Hive box: $e');
    }
  }

  Future<void> _loadCachedData() async {
    try {
      final userId = await UserSession().getCurrentUserId();
      if (userId != null && _subscriptionsBox != null) {
        final cachedSubscriptions =
            _subscriptionsBox!.get('user_${userId}_subscriptions');

        if (cachedSubscriptions != null && cachedSubscriptions is List) {
          final List<Subscription> subscriptions = [];
          for (final item in cachedSubscriptions) {
            if (item is Subscription) {
              subscriptions.add(item);
            } else if (item is Map<String, dynamic>) {
              subscriptions.add(Subscription.fromJson(item));
            }
          }

          if (subscriptions.isNotEmpty) {
            _allSubscriptions = subscriptions;
            _rebuildCacheFromSubscriptions();
            _hasLoaded = true;
            _hasInitialData = true;
            _subscriptionsUpdateController.add(_allSubscriptions);
            _subscriptionUpdateController.add(_categoryAccessCache);
            log('✅ Loaded ${_allSubscriptions.length} subscriptions from Hive');
            return;
          }
        }
      }

      log('Trying DeviceService cache');
      final cachedSubscriptions =
          await deviceService.getCacheItem<List<dynamic>>(
        AppConstants.subscriptionsCacheKey,
        isUserSpecific: true,
      );

      if (cachedSubscriptions != null) {
        final subscriptions = _subscriptionsFromDynamicList(cachedSubscriptions);

        if (subscriptions.isNotEmpty) {
          _allSubscriptions = subscriptions;
          _rebuildCacheFromSubscriptions();
          _hasLoaded = true;
          _hasInitialData = true;
          _subscriptionsUpdateController.add(_allSubscriptions);
          _subscriptionUpdateController.add(_categoryAccessCache);

          await _saveToHive();
          log('✅ Loaded ${_allSubscriptions.length} cached subscriptions from DeviceService');
          return;
        }
      }

      final restoredFromUser = await _restoreSubscriptionsFromCachedUser();
      if (restoredFromUser) {
        log('✅ Restored subscriptions from cached user profile');
      }
    } catch (e) {
      log('Error loading cached subscriptions: $e');
    }
  }

  String _normalizeCategoryName(String? value) {
    return (value ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  int _resolveCategoryId(int currentId, String? categoryName) {
    if (currentId > 0) return currentId;
    if (categoryName == null || categoryName.trim().isEmpty) return currentId;
    final categories = _categoryProvider?.categories ?? const [];
    if (categories.isEmpty) return currentId;

    final normalizedTarget = _normalizeCategoryName(categoryName);
    for (final category in categories) {
      if (_normalizeCategoryName(category.name) == normalizedTarget) {
        return category.id;
      }
    }
    return currentId;
  }

  Subscription _normalizeSubscription(Subscription subscription) {
    final resolvedCategoryId =
        _resolveCategoryId(subscription.categoryId, subscription.categoryName);
    if (resolvedCategoryId == subscription.categoryId) {
      return subscription;
    }

    return Subscription(
      id: subscription.id,
      userId: subscription.userId,
      categoryId: resolvedCategoryId,
      startDate: subscription.startDate,
      expiryDate: subscription.expiryDate,
      status: subscription.status,
      billingCycle: subscription.billingCycle,
      paymentId: subscription.paymentId,
      createdAt: subscription.createdAt,
      updatedAt: subscription.updatedAt,
      categoryName: subscription.categoryName,
      price: subscription.price,
    );
  }

  List<Subscription> _subscriptionsFromDynamicList(List<dynamic> rawList) {
    final List<Subscription> subscriptions = [];
    for (final item in rawList) {
      if (item is Subscription) {
        subscriptions.add(_normalizeSubscription(item));
      } else if (item is Map<String, dynamic>) {
        subscriptions.add(
          _normalizeSubscription(Subscription.fromJson(item)),
        );
      } else if (item is Map) {
        subscriptions.add(
          _normalizeSubscription(
            Subscription.fromJson(Map<String, dynamic>.from(item)),
          ),
        );
      }
    }
    return subscriptions;
  }

  Subscription _pickPreferredSubscription(
    Subscription current,
    Subscription candidate,
  ) {
    if (candidate.isActive != current.isActive) {
      return candidate.isActive ? candidate : current;
    }

    if (candidate.expiryDate != current.expiryDate) {
      return candidate.expiryDate.isAfter(current.expiryDate)
          ? candidate
          : current;
    }

    final currentUpdated = current.updatedAt ?? current.createdAt;
    final candidateUpdated = candidate.updatedAt ?? candidate.createdAt;
    if (candidateUpdated != null && currentUpdated != null) {
      if (candidateUpdated.isAfter(currentUpdated)) {
        return candidate;
      }
      if (currentUpdated.isAfter(candidateUpdated)) {
        return current;
      }
    } else if (candidateUpdated != null) {
      return candidate;
    } else if (currentUpdated != null) {
      return current;
    }

    return candidate.id > current.id ? candidate : current;
  }

  List<Subscription> _collapseSubscriptions(
    List<Subscription> subscriptions,
  ) {
    final Map<int, Subscription> byCategory = {};

    for (final subscription in subscriptions) {
      final normalized = _normalizeSubscription(subscription);
      if (normalized.categoryId <= 0) {
        continue;
      }

      final existing = byCategory[normalized.categoryId];
      byCategory[normalized.categoryId] = existing == null
          ? normalized
          : _pickPreferredSubscription(existing, normalized);
    }

    final collapsed = byCategory.values.toList()
      ..sort((a, b) {
        if (a.isActive != b.isActive) {
          return a.isActive ? -1 : 1;
        }
        return b.expiryDate.compareTo(a.expiryDate);
      });

    return collapsed;
  }

  Future<bool> _restoreSubscriptionsFromCachedUser() async {
    final userId = await UserSession().getCurrentUserId();
    if (userId == null) return false;

    try {
      User? cachedUser;

      if (Hive.isBoxOpen(AppConstants.hiveUserBox)) {
        final userBox = Hive.box<dynamic>(AppConstants.hiveUserBox);
        final hiveUser = userBox.get('user_${userId}_profile');
        if (hiveUser is User) {
          cachedUser = hiveUser;
        } else if (hiveUser is Map) {
          cachedUser = User.fromJson(Map<String, dynamic>.from(hiveUser));
        }
      }

      cachedUser ??= await deviceService
          .getCacheItem<Map<String, dynamic>>(
            AppConstants.userProfileKey(userId),
            isUserSpecific: true,
          )
          .then((json) => json != null ? User.fromJson(json) : null);

      if (cachedUser == null) return false;

      return _hydrateFromUserProfile(cachedUser, persistCache: false);
    } catch (e) {
      log('⚠️ Error restoring subscriptions from cached user: $e');
      return false;
    }
  }

  Future<bool> _hydrateFromUserProfile(
    User user, {
    bool persistCache = true,
  }) async {
    final rawSubscriptions = user.subscriptions;
    if (rawSubscriptions == null || rawSubscriptions.isEmpty) return false;

    final profileSubscriptions =
        _collapseSubscriptions(_subscriptionsFromDynamicList(rawSubscriptions));
    final subscriptions = _allSubscriptions.isNotEmpty
        ? _collapseSubscriptions([
            ..._allSubscriptions,
            ...profileSubscriptions,
          ])
        : profileSubscriptions;
    if (subscriptions.isEmpty) return false;

    _allSubscriptions = subscriptions;
    _rebuildCacheFromSubscriptions();
    _hasLoaded = true;
    _hasInitialData = true;

    if (persistCache) {
      await _saveSubscriptionsCache();
    }

    _notifyChanges();
    return true;
  }

  Future<void> syncFromUserProfile(User? user) async {
    if (user == null) return;

    final hydrated = await _hydrateFromUserProfile(user);
    if (hydrated) {
      log('✅ Synced subscriptions from active user profile');
    }
  }

  Future<void> _saveToHive() async {
    try {
      final userId = await UserSession().getCurrentUserId();
      if (userId != null && _subscriptionsBox != null) {
        final collapsedSubscriptions = _collapseSubscriptions(_allSubscriptions);
        _allSubscriptions = collapsedSubscriptions;
        await _subscriptionsBox!
            .put('user_${userId}_subscriptions', collapsedSubscriptions);
        log('💾 Saved ${collapsedSubscriptions.length} subscriptions to Hive');
      }
    } catch (e) {
      log('Error saving to Hive: $e');
    }
  }

  Future<void> _saveSubscriptionsCache() async {
    final collapsedSubscriptions = _collapseSubscriptions(_allSubscriptions);
    _allSubscriptions = collapsedSubscriptions;
    await _saveToHive();
    deviceService.saveCacheItem(
      AppConstants.subscriptionsCacheKey,
      collapsedSubscriptions.map((s) => s.toJson()).toList(),
      isUserSpecific: true,
    );
  }

  void _rebuildCacheFromSubscriptions() {
    _subscriptionsByCategory = {};
    _categoryAccessCache = {};
    _categoryCheckComplete = {};

    final collapsedSubscriptions = _collapseSubscriptions(_allSubscriptions);
    _allSubscriptions = collapsedSubscriptions;

    for (final normalized in collapsedSubscriptions) {
      final isActive = normalized.isActive;
      _subscriptionsByCategory[normalized.categoryId] = normalized;
      _categoryAccessCache[normalized.categoryId] = isActive;
      _categoryCheckComplete[normalized.categoryId] = true;
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

  void _notifyChanges() {
    _subscriptionsUpdateController.add(_allSubscriptions);
    _subscriptionUpdateController.add(Map.from(_categoryAccessCache));
    safeNotify();
  }

  // ===== GETTERS =====
  List<Subscription> get allSubscriptions =>
      List.unmodifiable(_allSubscriptions);
  Map<int, Subscription> get subscriptionsByCategory =>
      Map.unmodifiable(_subscriptionsByCategory);

  bool get hasLoaded => _hasLoaded;
  bool get hasInitialData => _hasInitialData;

  Stream<Map<int, bool>> get subscriptionUpdates =>
      _subscriptionUpdateController.stream;
  Stream<List<Subscription>> get subscriptionsUpdates =>
      _subscriptionsUpdateController.stream;

  List<Subscription> get activeSubscriptions {
    return _allSubscriptions.where((sub) => sub.isActive).toList();
  }

  List<Subscription> get expiredSubscriptions {
    return _allSubscriptions.where((sub) => sub.isExpired).toList();
  }

  List<Subscription> get expiringSoonSubscriptions {
    return _allSubscriptions.where((sub) => sub.isExpiringSoon).toList();
  }

  bool hasActiveSubscriptionForCategory(int categoryId) {
    if (_categoryAccessCache.containsKey(categoryId)) {
      return _categoryAccessCache[categoryId]!;
    }
    final subscription = _subscriptionsByCategory[categoryId];
    if (subscription != null) {
      final isActive = subscription.isActive;
      _categoryAccessCache[categoryId] = isActive;
      _categoryCheckComplete[categoryId] = true;
      return isActive;
    }
    return false;
  }

  bool? _getKnownAccessState(int categoryId) {
    if (_categoryAccessCache.containsKey(categoryId)) {
      return _categoryAccessCache[categoryId];
    }

    final subscription = _subscriptionsByCategory[categoryId];
    if (subscription != null) {
      final isActive = subscription.isActive;
      _categoryAccessCache[categoryId] = isActive;
      _categoryCheckComplete[categoryId] = true;
      return isActive;
    }

    return null;
  }

  List<int> getCategoriesWithActiveSubscription() {
    final List<int> result = [];
    _categoryAccessCache.forEach((categoryId, hasAccess) {
      if (hasAccess) result.add(categoryId);
    });
    return result;
  }

  void setCategoryProvider(CategoryProvider categoryProvider) {
    _categoryProvider = categoryProvider;
    if (_allSubscriptions.isNotEmpty) {
      _allSubscriptions = _allSubscriptions.map(_normalizeSubscription).toList();
      _rebuildCacheFromSubscriptions();
      _notifyChanges();
    }
    log('CategoryProvider set');
  }

  // ✅ FORCE INVALIDATE CACHE - clears ALL cached subscription data
  Future<void> forceInvalidateCache() async {
    log('forceInvalidateCache() - clearing ALL cached subscription data');

    _categoryAccessCache.clear();
    _categoryCheckComplete.clear();
    _allSubscriptions = [];
    _subscriptionsByCategory = {};
    _hasLoaded = false;
    _hasInitialData = false;

    for (final completer in _categoryCheckCompleters.values) {
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    }
    _categoryCheckCompleters.clear();

    final userId = await UserSession().getCurrentUserId();
    if (userId != null && _subscriptionsBox != null) {
      try {
        await _subscriptionsBox!.delete('user_${userId}_subscriptions');
        log('✅ Cleared Hive subscription cache');
      } catch (e) {
        log('Error clearing Hive cache: $e');
      }
    }

    try {
      await deviceService.removeCacheItem(
        AppConstants.subscriptionsCacheKey,
        isUserSpecific: true,
      );
      log('✅ Cleared DeviceService cache');
    } catch (e) {
      log('Error clearing DeviceService cache: $e');
    }

    _notifyChanges();

    log('✅ Cache invalidation complete');
  }

  // ✅ FORCE REFRESH - clears cache and tries to fetch fresh data
  Future<void> forceRefreshFromServer() async {
    log('forceRefreshFromServer() - clearing cache and fetching fresh data');

    await forceInvalidateCache();

    if (isOffline) {
      log('Offline - cache cleared, but cannot fetch fresh data');
      return;
    }

    try {
      final response = await apiService.getMySubscriptions().timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          log('⏱️ API timeout during force refresh');
          return ApiResponse<List<Subscription>>(
            success: false,
            message: 'Request timed out',
          );
        },
      );

      if (response.success && response.data != null) {
        _allSubscriptions = response.data!;
        _hasLoaded = true;
        _hasInitialData = _allSubscriptions.isNotEmpty;

        await _saveSubscriptionsCache();
        _rebuildCacheFromSubscriptions();
        _notifyChanges();
        log('✅ Force refresh completed - loaded ${_allSubscriptions.length} subscriptions');
      } else {
        log('⚠️ Force refresh failed - keeping cache cleared');
        _hasLoaded = true;
        _notifyChanges();
      }
    } catch (e) {
      log('❌ Force refresh error: $e');
      _hasLoaded = true;
      _notifyChanges();
    }
  }

  // ===== LOAD SUBSCRIPTIONS =====
  Future<void> loadSubscriptions({
    bool forceRefresh = false,
    bool isManualRefresh = false,
  }) async {
    _apiCallCount++;
    final callId = _apiCallCount;

    log('loadSubscriptions() CALL #$callId');

    if (isManualRefresh && isOffline) {
      throw Exception(getUserFriendlyErrorMessage(
          'Network error. Please check your internet connection.'));
    }

    if (_hasLoaded && !forceRefresh && !isManualRefresh) {
      log('✅ Already have data, returning cached');
      _notifyChanges();
      setLoaded();
      return;
    }

    if (isLoading && !forceRefresh) {
      log('⏳ Already loading, waiting...');
      int attempts = 0;
      while (isLoading && attempts < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }
      if (_hasLoaded) {
        log('✅ Load completed while waiting');
        return;
      }
    }

    setLoading();

    try {
      // STEP 1: Try Hive first
      if (!forceRefresh) {
        log('STEP 1: Checking Hive cache');
        final userId = await UserSession().getCurrentUserId();
        if (userId != null && _subscriptionsBox != null) {
          final cachedSubscriptions =
              _subscriptionsBox!.get('user_${userId}_subscriptions');

          if (cachedSubscriptions != null && cachedSubscriptions is List) {
            final subscriptions = _subscriptionsFromDynamicList(cachedSubscriptions);

            if (subscriptions.isNotEmpty) {
              _allSubscriptions = subscriptions;
              _rebuildCacheFromSubscriptions();
              _hasLoaded = true;
              _hasInitialData = true;
              setLoaded();
              _notifyChanges();
              log('✅ Loaded ${subscriptions.length} subscriptions from Hive cache');

              if (_categoryProvider != null) {
                final statusMap = <int, bool>{};
                for (final sub in _allSubscriptions) {
                  statusMap[sub.categoryId] = sub.isActive;
                }
                unawaited(_categoryProvider!
                    .batchUpdateSubscriptionStatus(statusMap));
              }

              if (!isOffline && !isManualRefresh) {
                unawaited(_refreshInBackground());
              }
              return;
            }
          }
        }
      }

      // STEP 2: Try DeviceService
      if (!forceRefresh) {
        log('STEP 2: Checking DeviceService cache');
        final cachedSubscriptions =
            await deviceService.getCacheItem<List<dynamic>>(
          AppConstants.subscriptionsCacheKey,
          isUserSpecific: true,
        );

        if (cachedSubscriptions != null) {
          final subscriptions = _subscriptionsFromDynamicList(cachedSubscriptions);

          if (subscriptions.isNotEmpty) {
            _allSubscriptions = subscriptions;
            _rebuildCacheFromSubscriptions();
            _hasLoaded = true;
            _hasInitialData = true;
            setLoaded();
            _notifyChanges();
            log('✅ Loaded ${subscriptions.length} subscriptions from DeviceService cache');

            await _saveToHive();

            if (_categoryProvider != null) {
              final statusMap = <int, bool>{};
              for (final sub in _allSubscriptions) {
                statusMap[sub.categoryId] = sub.isActive;
              }
              unawaited(
                  _categoryProvider!.batchUpdateSubscriptionStatus(statusMap));
            }

            if (!isOffline && !isManualRefresh) {
              unawaited(_refreshInBackground());
            }
            return;
          }
        }

        final restoredFromUser = await _restoreSubscriptionsFromCachedUser();
        if (restoredFromUser) {
          log('✅ Loaded subscriptions from cached user profile fallback');
          return;
        }
      }

      // STEP 3: Check offline status
      if (isOffline) {
        log('STEP 3: Offline mode');
        if (_hasInitialData) {
          _hasLoaded = true;
          setLoaded();
          _notifyChanges();
          log('✅ Showing cached subscriptions offline');
          return;
        }

        setLoaded();
        _notifyChanges();

        if (isManualRefresh) {
          throw Exception(getUserFriendlyErrorMessage(
              'Network error. Please check your internet connection.'));
        }
        return;
      }

      // STEP 4: Fetch from API
      log('STEP 4: Fetching from API');
      try {
        final previousSubscriptions =
            List<Subscription>.from(_allSubscriptions);
        final hadCachedSubscriptions =
            _hasInitialData || previousSubscriptions.isNotEmpty;

        final response = await apiService.getMySubscriptions().timeout(
          const Duration(seconds: 45),
          onTimeout: () {
            log('⏱️ API timeout in loadSubscriptions - using cached data');
            return ApiResponse<List<Subscription>>(
              success: false,
              message: 'Request timed out. Please try again.',
            );
          },
        );

        if (response.success) {
          _allSubscriptions =
              (response.data ?? []).map(_normalizeSubscription).toList();
          log('✅ Received ${_allSubscriptions.length} subscriptions from API');

          _hasLoaded = true;
          _hasInitialData = _allSubscriptions.isNotEmpty;
          setLoaded();

          await _saveSubscriptionsCache();
          _rebuildCacheFromSubscriptions();
          _notifyChanges();
        } else {
          final restoredFromUser = await _restoreSubscriptionsFromCachedUser();
          if (restoredFromUser) {
            log('⚠️ Using cached user subscriptions after API failure');
            return;
          }

          if (hadCachedSubscriptions) {
            _allSubscriptions = previousSubscriptions;
            _hasLoaded = true;
            _hasInitialData = _allSubscriptions.isNotEmpty;
            setLoaded();
            _rebuildCacheFromSubscriptions();
            _notifyChanges();
            log('⚠️ Using existing subscription cache after API failure');
            return;
          }

          _allSubscriptions = [];
          _hasLoaded = true;
          _hasInitialData = false;
          setLoaded();
          setError(getUserFriendlyErrorMessage(response.message));
          _rebuildCacheFromSubscriptions();
          _notifyChanges();
          log('ℹ️ No subscriptions available from API');
          return;
        }

        if (_categoryProvider != null && _allSubscriptions.isNotEmpty) {
          final statusMap = <int, bool>{};
          for (final sub in _allSubscriptions) {
            statusMap[sub.categoryId] = sub.isActive;
          }
          unawaited(
              _categoryProvider!.batchUpdateSubscriptionStatus(statusMap));
        }
        log('✅ Success! Subscriptions loaded');
      } catch (e) {
        log('❌ Error loading subscriptions: $e');
        final restoredFromUser = await _restoreSubscriptionsFromCachedUser();
        if (restoredFromUser) {
          log('⚠️ Using cached user subscriptions after exception');
          return;
        }
        setError(getUserFriendlyErrorMessage(e));
        _hasLoaded = true;
        setLoaded();
        _notifyChanges();

        if (isManualRefresh) {
          rethrow;
        }
      }
    } catch (e) {
      log('❌ Error loading subscriptions: $e');

      final restoredFromUser = await _restoreSubscriptionsFromCachedUser();
      if (restoredFromUser) {
        log('⚠️ Using cached user subscriptions after outer failure');
        return;
      }

      setError(getUserFriendlyErrorMessage(e));

      _hasLoaded = true;
      setLoaded();
      _notifyChanges();

      if (isManualRefresh) {
        rethrow;
      }
    } finally {
      safeNotify();
    }
  }

  // ===== CHECK SUBSCRIPTION FOR CATEGORY =====
  Future<bool> checkHasActiveSubscriptionForCategory(
    int categoryId, {
    bool isManualRefresh = false,
  }) async {
    _apiCallCount++;
    final callId = _apiCallCount;

    log('checkHasActiveSubscriptionForCategory() CALL #$callId for category $categoryId');

    if (isManualRefresh && isOffline) {
      final knownAccess = _getKnownAccessState(categoryId);
      if (knownAccess != null) {
        log('Offline manual refresh - preserving known access for category $categoryId: $knownAccess');
        return knownAccess;
      }
      throw Exception(getUserFriendlyErrorMessage(
          'Network error. Please check your internet connection.'));
    }

    final knownAccess = _getKnownAccessState(categoryId);
    if (knownAccess != null) {
      final cached = knownAccess;
      log('Using cached access for category $categoryId: $cached');
      return cached;
    }

    if (isOffline) {
      log('Offline, no known cached access for category $categoryId');
      return false;
    }

    if (_categoryCheckCompleters.containsKey(categoryId)) {
      log('Waiting for existing check for category $categoryId');
      try {
        return await _categoryCheckCompleters[categoryId]!
            .future
            .timeout(_categoryCheckTimeout);
      } on TimeoutException {
        log('Timeout waiting for category $categoryId');
        return false;
      }
    }

    final completer = Completer<bool>();
    _categoryCheckCompleters[categoryId] = completer;

    _queueCategoryCheck(categoryId, completer);

    return completer.future;
  }

  void _queueCategoryCheck(int categoryId, Completer<bool> completer) {
    _pendingRequests.add({
      'categoryId': categoryId,
      'completer': completer,
      'timestamp': DateTime.now(),
    });

    _processNextRequest();
  }

  Future<void> _processNextRequest() async {
    if (_pendingRequests.isEmpty || _activeRequests >= _maxConcurrentRequests) {
      return;
    }

    if (_pendingRequests.length >= 3 && !isOffline) {
      await _processBatchRequest();
      return;
    }

    _activeRequests++;
    final request = _pendingRequests.removeAt(0);
    final categoryId = request['categoryId'];
    final completer = request['completer'];

    try {
      log('Processing queued request for category $categoryId (active: $_activeRequests)');

      final response =
          await apiService.checkSubscriptionStatus(categoryId).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          log('⏱️ API timeout for category $categoryId');
          return ApiResponse<Map<String, dynamic>>(
            success: false,
            message: 'Request timed out',
            data: {'has_subscription': false},
          );
        },
      );

      if (response.success && response.data != null) {
        final data = response.data!;
        final hasSubscription = data['has_subscription'] == true;
        log('API response for category $categoryId: hasSubscription=$hasSubscription');

        _categoryAccessCache[categoryId] = hasSubscription;
        _categoryCheckComplete[categoryId] = true;

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
            _hasInitialData = true;
            unawaited(_saveToHive());
          }
        }

        _subscriptionUpdateController.add({categoryId: hasSubscription});

        if (_categoryProvider != null) {
          unawaited(_categoryProvider!
              .updateCategorySubscriptionStatus(categoryId, hasSubscription));
        }

        completer.complete(hasSubscription);
      } else {
        log('API returned no subscription for category $categoryId');
        final previousKnownAccess = _getKnownAccessState(categoryId);
        if (previousKnownAccess != null) {
          log('Preserving cached access for category $categoryId after failed API check: $previousKnownAccess');
          completer.complete(previousKnownAccess);
        } else {
          _categoryAccessCache[categoryId] = false;
          _categoryCheckComplete[categoryId] = true;
          _subscriptionUpdateController.add({categoryId: false});

          if (_categoryProvider != null) {
            unawaited(_categoryProvider!
                .updateCategorySubscriptionStatus(categoryId, false));
          }

          completer.complete(false);
        }
      }
    } catch (e) {
      log('Error checking subscription for category $categoryId: $e');
      final previousKnownAccess = _getKnownAccessState(categoryId);
      completer.complete(previousKnownAccess ?? false);
    } finally {
      _activeRequests--;
      _categoryCheckCompleters.remove(categoryId);
      unawaited(_processNextRequest());
    }
  }

  Future<void> _processBatchRequest() async {
    if (_pendingRequests.isEmpty || isOffline) return;

    if (_lastBatchCheck != null &&
        DateTime.now().difference(_lastBatchCheck!) < _batchCheckCooldown) {
      log('⏱️ Batch check cooldown, falling back to individual');
      unawaited(_processNextRequest());
      return;
    }

    final batchSize =
        _pendingRequests.length > 10 ? 10 : _pendingRequests.length;
    final batchRequests = _pendingRequests.sublist(0, batchSize);
    final categoryIds =
        batchRequests.map((r) => r['categoryId'] as int).toList();
    final completers =
        batchRequests.map((r) => r['completer'] as Completer<bool>).toList();

    _pendingRequests.removeRange(0, batchSize);

    _activeRequests++;
    _lastBatchCheck = DateTime.now();

    try {
      log('Processing batch request for ${categoryIds.length} categories');

      final results =
          await apiService.checkMultipleSubscriptions(categoryIds).timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          log('⏱️ Batch API timeout');
          return <int, bool>{};
        },
      );

      for (int i = 0; i < categoryIds.length; i++) {
        final categoryId = categoryIds[i];
        final completer = completers[i];

        final hasSubscription =
            results.containsKey(categoryId)
                ? (results[categoryId] ?? false)
                : (_getKnownAccessState(categoryId) ?? false);

        _categoryAccessCache[categoryId] = hasSubscription;
        _categoryCheckComplete[categoryId] = true;
        _subscriptionUpdateController.add({categoryId: hasSubscription});

        if (_categoryProvider != null) {
          unawaited(_categoryProvider!
              .updateCategorySubscriptionStatus(categoryId, hasSubscription));
        }

        completer.complete(hasSubscription);
      }

      log('✅ Batch processed ${results.length} results');
    } catch (e) {
      log('❌ Batch request failed: $e');
      for (int i = 0; i < categoryIds.length; i++) {
        _pendingRequests.add({
          'categoryId': categoryIds[i],
          'completer': completers[i],
          'timestamp': DateTime.now(),
        });
      }
    } finally {
      _activeRequests--;
      unawaited(_processNextRequest());
    }
  }

  // ===== CHECK MULTIPLE CATEGORIES =====
  Future<Map<int, bool>> checkSubscriptionsForCategories(
    List<int> categoryIds, {
    bool isManualRefresh = false,
  }) async {
    log('checkSubscriptionsForCategories() for ${categoryIds.length} categories');

    final results = <int, bool>{};
    final updates = <int, bool>{};

    for (final categoryId in categoryIds) {
      if (_categoryAccessCache.containsKey(categoryId)) {
        results[categoryId] = _categoryAccessCache[categoryId]!;
        updates[categoryId] = results[categoryId]!;
      }
    }

    final missingIds =
        categoryIds.where((id) => !results.containsKey(id)).toList();

    if (missingIds.isNotEmpty && !isOffline) {
      log('Checking ${missingIds.length} missing categories');

      if (missingIds.length >= 3 && !isOffline) {
        try {
          final batchResults =
              await apiService.checkMultipleSubscriptions(missingIds);
          if (batchResults.isNotEmpty) {
            for (final entry in batchResults.entries) {
              results[entry.key] = entry.value;
              updates[entry.key] = entry.value;
              _categoryAccessCache[entry.key] = entry.value;
              _categoryCheckComplete[entry.key] = true;
            }
            missingIds.removeWhere(batchResults.containsKey);
          }
        } catch (e) {
          log('Batch check failed, falling back to individual: $e');
        }
      }

      if (missingIds.isNotEmpty) {
        final futures = missingIds.map((id) =>
            checkHasActiveSubscriptionForCategory(id,
                isManualRefresh: isManualRefresh));

        final newResults = await Future.wait(futures);

        for (int i = 0; i < missingIds.length; i++) {
          results[missingIds[i]] = newResults[i];
          updates[missingIds[i]] = newResults[i];
        }
      }
    } else if (isOffline && missingIds.isNotEmpty && isManualRefresh) {
      log('❌ Offline with missing categories during manual refresh');
      throw Exception(getUserFriendlyErrorMessage(
          'Network error. Please check your internet connection.'));
    }

    if (_categoryProvider != null && updates.isNotEmpty) {
      unawaited(_categoryProvider!.batchUpdateSubscriptionStatus(updates));
    }

    log('Returning results for ${results.length} categories');
    return results;
  }

  Future<void> _refreshInBackground() async {
    if (isOffline) return;

    if (_lastBackgroundRefresh != null &&
        DateTime.now().difference(_lastBackgroundRefresh!) <
            _minBackgroundInterval) {
      log('⏱️ Background refresh rate limited');
      return;
    }
    _lastBackgroundRefresh = DateTime.now();

    if (_lastBackgroundRefreshTime != null) {
      final minutesSinceLastRefresh =
          DateTime.now().difference(_lastBackgroundRefreshTime!).inMinutes;
      if (minutesSinceLastRefresh < 2) {
        log('Skipping background refresh - too soon');
        return;
      }
    }
    _lastBackgroundRefreshTime = DateTime.now();

    try {
      final response = await apiService.getMySubscriptions().timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          log('⏱️ API timeout in background refresh');
          return ApiResponse<List<Subscription>>(
            success: false,
            message: 'Request timed out',
          );
        },
      );

      if (response.success && response.data != null) {
        final newSubscriptions = response.data!;

        if (_hasSubscriptionChanges(newSubscriptions)) {
          log('Changes detected in background refresh');
          _allSubscriptions = newSubscriptions;

          await _saveSubscriptionsCache();

          _rebuildCacheFromSubscriptions();
          _notifyChanges();
          log('🔄 Background refresh complete with changes');
        }
      }
    } catch (e) {
      log('⚠️ Background refresh failed: $e');
    }
  }

  // ===== REFRESH METHODS =====
  Future<void> refreshAfterPaymentVerification() async {
    log('refreshAfterPaymentVerification()');

    _categoryAccessCache = {};
    _categoryCheckComplete = {};
    _categoryCheckCompleters.clear();
    _lastBatchCheck = null;
    _hasLoaded = false;

    await forceRefreshFromServer();
    log('refreshAfterPaymentVerification() complete');
  }

  Future<void> refreshCategorySubscription(int categoryId) async {
    log('refreshCategorySubscription() for category $categoryId');

    await deviceService.removeCacheItem(
      AppConstants.categoryAccessKey(categoryId),
      isUserSpecific: true,
    );
    _categoryAccessCache.remove(categoryId);
    _categoryCheckComplete.remove(categoryId);

    if (!isOffline) {
      await checkHasActiveSubscriptionForCategory(categoryId);
    }
  }

  Future<void> forceRefreshAllCategories() async {
    log('forceRefreshAllCategories()');

    _categoryAccessCache.clear();
    _categoryCheckComplete.clear();
    _categoryCheckCompleters.clear();

    await deviceService.clearCacheByPrefix('subscriptions');

    final userId = await UserSession().getCurrentUserId();
    if (userId != null && _subscriptionsBox != null) {
      await _subscriptionsBox!.delete('user_${userId}_subscriptions');
    }

    await loadSubscriptions(forceRefresh: true, isManualRefresh: true);
    log('forceRefreshAllCategories() complete');
  }

  @override
  Future<void> onOnlineRefresh() async {
    log('Online - refreshing subscriptions');
    await loadSubscriptions();
  }

  Future<void> clearUserData() async {
    final session = UserSession();
    if (!session.shouldClearCacheOnLogout()) return;

    final userId = await session.getCurrentUserId();
    if (userId != null && _subscriptionsBox != null) {
      await _subscriptionsBox!.delete('user_${userId}_subscriptions');
    }

    await deviceService.clearCacheByPrefix('subscriptions');

    _allSubscriptions = [];
    _subscriptionsByCategory = {};
    _categoryAccessCache = {};
    _categoryCheckComplete = {};
    _hasLoaded = false;
    _hasInitialData = false;
    _categoryCheckCompleters.clear();
    _lastBackgroundRefresh = null;
    _lastBatchCheck = null;

    await _subscriptionUpdateController.close();
    await _subscriptionsUpdateController.close();
    _subscriptionUpdateController =
        StreamController<Map<int, bool>>.broadcast();
    _subscriptionsUpdateController =
        StreamController<List<Subscription>>.broadcast();
    _subscriptionUpdateController.add({});
    _subscriptionsUpdateController.add([]);

    safeNotify();
  }

  @override
  void dispose() {
    _subscriptionUpdateController.close();
    _subscriptionsUpdateController.close();
    _subscriptionsBox?.close();
    _categoryCheckCompleters.clear();
    _pendingRequests.clear();
    disposeSubscriptions();
    super.dispose();
  }
}

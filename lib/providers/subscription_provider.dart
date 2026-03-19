// lib/providers/subscription_provider.dart
// PRODUCTION-READY FINAL VERSION - WITH BATCH SUBSCRIPTION CHECKING

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
import '../providers/category_provider.dart';
import '../utils/constants.dart';
import '../utils/api_response.dart';
import '../utils/helpers.dart';
import 'base_provider.dart';

class SubscriptionProvider extends ChangeNotifier
    with
        BaseProvider<SubscriptionProvider>,
        OfflineAwareProvider<SubscriptionProvider> {
  @override
  final ConnectivityService connectivityService;

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

  // ✅ FIXED: Proper stream declarations
  late StreamController<Map<int, bool>> _subscriptionUpdateController;
  late StreamController<List<Subscription>> _subscriptionsUpdateController;

  final Map<int, Completer<bool>> _categoryCheckCompleters = {};
  static const Duration _categoryCheckTimeout = Duration(seconds: 10);

  // Add a semaphore to limit parallel requests
  static const int _maxConcurrentRequests = 2;
  int _activeRequests = 0;
  final List<Map<String, dynamic>> _pendingRequests = [];

  // ✅ FIXED: Rate limiting
  DateTime? _lastBackgroundRefresh;
  static const Duration _minBackgroundInterval = Duration(minutes: 2);

  CategoryProvider? _categoryProvider;

  // ✅ FIXED: Cache for batch results
  DateTime? _lastBatchCheck;
  static const Duration _batchCheckCooldown = Duration(seconds: 30);

  SubscriptionProvider({
    required this.apiService,
    required this.deviceService,
    required this.connectivityService,
    required this.hiveService,
    required this.offlineQueueManager,
  })  : _subscriptionUpdateController =
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
        final List<Subscription> subscriptions = [];
        for (final json in cachedSubscriptions) {
          if (json is Map<String, dynamic>) {
            subscriptions.add(Subscription.fromJson(json));
          }
        }

        if (subscriptions.isNotEmpty) {
          _allSubscriptions = subscriptions;
          _rebuildCacheFromSubscriptions();
          _hasLoaded = true;
          _hasInitialData = true;
          _subscriptionsUpdateController.add(_allSubscriptions);
          _subscriptionUpdateController.add(_categoryAccessCache);

          await _saveToHive();
          log('✅ Loaded ${_allSubscriptions.length} cached subscriptions from DeviceService');
        }
      }
    } catch (e) {
      log('Error loading cached subscriptions: $e');
    }
  }

  Future<void> _saveToHive() async {
    try {
      final userId = await UserSession().getCurrentUserId();
      if (userId != null && _subscriptionsBox != null) {
        await _subscriptionsBox!
            .put('user_${userId}_subscriptions', _allSubscriptions);
        log('💾 Saved ${_allSubscriptions.length} subscriptions to Hive');
      }
    } catch (e) {
      log('Error saving to Hive: $e');
    }
  }

  void _rebuildCacheFromSubscriptions() {
    _subscriptionsByCategory = {};
    _categoryAccessCache = {};
    _categoryCheckComplete = {};

    for (final sub in _allSubscriptions) {
      final isActive = sub.isActive;
      _subscriptionsByCategory[sub.categoryId] = sub;
      _categoryAccessCache[sub.categoryId] = isActive;
      _categoryCheckComplete[sub.categoryId] = true;
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

  List<int> getCategoriesWithActiveSubscription() {
    final List<int> result = [];
    _categoryAccessCache.forEach((categoryId, hasAccess) {
      if (hasAccess) result.add(categoryId);
    });
    return result;
  }

  void setCategoryProvider(CategoryProvider categoryProvider) {
    _categoryProvider = categoryProvider;
    log('CategoryProvider set');
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
          final List<Subscription> subscriptions = [];
          for (final json in cachedSubscriptions) {
            if (json is Map<String, dynamic>) {
              subscriptions.add(Subscription.fromJson(json));
            }
          }

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
        final response = await apiService.getMySubscriptions().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            log('⏱️ API timeout in loadSubscriptions - using cached data');
            if (_hasInitialData) {
              _hasLoaded = true;
              setLoaded();
              _notifyChanges();
              return ApiResponse<List<Subscription>>(
                success: true,
                message: 'Using cached data (server timeout)',
                data: _allSubscriptions,
              );
            }
            return ApiResponse<List<Subscription>>(
              success: false,
              message: 'Request timed out. Please try again.',
              data: [],
            );
          },
        );

        if (response.success) {
          _allSubscriptions = response.data ?? [];
          log('✅ Received ${_allSubscriptions.length} subscriptions from API');
        } else {
          _allSubscriptions = [];
          setError(getUserFriendlyErrorMessage(response.message));
          log('ℹ️ No subscriptions found from API');
        }

        _hasLoaded = true;
        _hasInitialData = _allSubscriptions.isNotEmpty;
        setLoaded();

        await _saveToHive();

        deviceService.saveCacheItem(
          AppConstants.subscriptionsCacheKey,
          _allSubscriptions.map((s) => s.toJson()).toList(),
          isUserSpecific: true,
        );

        _rebuildCacheFromSubscriptions();
        _notifyChanges();

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
      throw Exception(getUserFriendlyErrorMessage(
          'Network error. Please check your internet connection.'));
    }

    // Check cache first
    if (_categoryAccessCache.containsKey(categoryId)) {
      final cached = _categoryAccessCache[categoryId]!;
      log('Using cached access for category $categoryId: $cached');
      return cached;
    }

    if (isOffline) {
      log('Offline, returning false for category $categoryId');
      return false;
    }

    // If already checking, wait for result
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

    // Create completer for this request
    final completer = Completer<bool>();
    _categoryCheckCompleters[categoryId] = completer;

    // Queue the request instead of executing immediately
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

  // ✅ FIXED: Enhanced to use batch checking when possible
  Future<void> _processNextRequest() async {
    if (_pendingRequests.isEmpty || _activeRequests >= _maxConcurrentRequests) {
      return;
    }

    // Check if we can do a batch request
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
        const Duration(seconds: 8),
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
        _categoryAccessCache[categoryId] = false;
        _categoryCheckComplete[categoryId] = true;
        _subscriptionUpdateController.add({categoryId: false});

        if (_categoryProvider != null) {
          unawaited(_categoryProvider!
              .updateCategorySubscriptionStatus(categoryId, false));
        }

        completer.complete(false);
      }
    } catch (e) {
      log('Error checking subscription for category $categoryId: $e');
      completer.complete(false);
    } finally {
      _activeRequests--;
      _categoryCheckCompleters.remove(categoryId);
      // Process next request
      _processNextRequest();
    }
  }

  // ✅ FIXED: New batch processing method
  Future<void> _processBatchRequest() async {
    if (_pendingRequests.isEmpty || isOffline) return;

    // Check cooldown
    if (_lastBatchCheck != null &&
        DateTime.now().difference(_lastBatchCheck!) < _batchCheckCooldown) {
      log('⏱️ Batch check cooldown, falling back to individual');
      _processNextRequest(); // Fall back to individual
      return;
    }

    // Collect up to 10 category IDs
    final batchSize =
        _pendingRequests.length > 10 ? 10 : _pendingRequests.length;
    final batchRequests = _pendingRequests.sublist(0, batchSize);
    final categoryIds =
        batchRequests.map((r) => r['categoryId'] as int).toList();
    final completers =
        batchRequests.map((r) => r['completer'] as Completer<bool>).toList();

    // Remove these from pending queue
    _pendingRequests.removeRange(0, batchSize);

    _activeRequests++;
    _lastBatchCheck = DateTime.now();

    try {
      log('Processing batch request for ${categoryIds.length} categories');

      final results =
          await apiService.checkMultipleSubscriptions(categoryIds).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          log('⏱️ Batch API timeout');
          return <int, bool>{};
        },
      );

      // Process results
      for (int i = 0; i < categoryIds.length; i++) {
        final categoryId = categoryIds[i];
        final completer = completers[i];

        final hasSubscription = results[categoryId] ?? false;

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
      // Re-queue failed items as individual requests
      for (int i = 0; i < categoryIds.length; i++) {
        _pendingRequests.add({
          'categoryId': categoryIds[i],
          'completer': completers[i],
          'timestamp': DateTime.now(),
        });
      }
    } finally {
      _activeRequests--;
      // Continue processing
      _processNextRequest();
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

    // Get cached results first
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

      // Try batch first if enough categories
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

            // Remove successfully checked IDs
            missingIds.removeWhere((id) => batchResults.containsKey(id));
          }
        } catch (e) {
          log('Batch check failed, falling back to individual: $e');
        }
      }

      // Handle remaining IDs with individual checks
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

  // ✅ FIXED: Rate limited background refresh
  Future<void> _refreshInBackground() async {
    if (isOffline) return;

    // Rate limiting
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
        const Duration(seconds: 10),
        onTimeout: () {
          log('⏱️ API timeout in background refresh');
          return ApiResponse<List<Subscription>>(
            success: false,
            message: 'Request timed out',
            data: [],
          );
        },
      );

      if (response.success && response.data != null) {
        final newSubscriptions = response.data!;

        if (_hasSubscriptionChanges(newSubscriptions)) {
          log('Changes detected in background refresh');
          _allSubscriptions = newSubscriptions;

          await _saveToHive();
          deviceService.saveCacheItem(
            AppConstants.subscriptionsCacheKey,
            _allSubscriptions.map((s) => s.toJson()).toList(),
            isUserSpecific: true,
          );

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

    await deviceService.clearCacheByPrefix('subscriptions');

    final userId = await UserSession().getCurrentUserId();
    if (userId != null && _subscriptionsBox != null) {
      await _subscriptionsBox!.delete('user_${userId}_subscriptions');
    }

    _allSubscriptions = [];
    _subscriptionsByCategory = {};
    _categoryAccessCache = {};
    _categoryCheckComplete = {};
    _hasLoaded = false;
    _hasInitialData = false;

    await loadSubscriptions(forceRefresh: true, isManualRefresh: true);
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

  // ✅ FIXED: Clear user data with proper stream recreation
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

    // FIX: Properly recreate streams
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
  void clearError() {
    super.clearError();
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

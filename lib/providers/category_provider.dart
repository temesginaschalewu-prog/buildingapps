import 'dart:async';
import 'package:familyacademyclient/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../services/user_session.dart';
import '../services/connectivity_service.dart';
import '../models/category_model.dart';
import '../utils/helpers.dart';
import '../utils/ui_helpers.dart';
import '../themes/app_colors.dart';

class CategoryProvider with ChangeNotifier {
  final ApiService apiService;
  final DeviceService deviceService;
  final ConnectivityService connectivityService;

  List<Category> _categories = [];
  List<Category> _activeCategories = [];
  List<Category> _comingSoonCategories = [];
  final Map<int, bool> _categorySubscriptionStatus = {};
  final Map<int, bool> _categoryStatusLoaded = {};
  final Map<int, DateTime> _lastSubscriptionCheck = {};

  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _error;
  bool _isOffline = false;

  final Map<int, bool> _isLoadingCategory = {};

  Timer? _backgroundRefreshTimer;
  static const Duration _backgroundRefreshInterval = Duration(minutes: 5);
  static const Duration _cacheDuration = AppConstants.cacheTTLCategories;

  final StreamController<List<Category>> _categoriesUpdateController =
      StreamController<List<Category>>.broadcast();
  final StreamController<Map<int, bool>> _subscriptionStatusController =
      StreamController<Map<int, bool>>.broadcast();

  final Map<int, Completer<bool>> _waitForCheckCompleters = {};
  bool _isSyncingSubscription = false;

  CategoryProvider({
    required this.apiService,
    required this.deviceService,
    required this.connectivityService,
  }) {
    _initBackgroundRefresh();
    _setupConnectivityListener();
  }

  void _setupConnectivityListener() {
    connectivityService.onConnectivityChanged.listen((isOnline) {
      if (_isOffline != !isOnline) {
        _isOffline = !isOnline;
        if (!_isOffline && _hasLoaded) {
          _refreshInBackground();
        }
        notifyListeners();
      }
    });
  }

  List<Category> get categories => List.unmodifiable(_categories);
  List<Category> get activeCategories => List.unmodifiable(_activeCategories);
  List<Category> get comingSoonCategories =>
      List.unmodifiable(_comingSoonCategories);
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get error => _error;
  bool get isOffline => _isOffline;
  bool get isSyncingSubscription => _isSyncingSubscription;

  bool isLoadingCategory(int categoryId) =>
      _isLoadingCategory[categoryId] ?? false;

  Stream<List<Category>> get categoriesUpdates =>
      _categoriesUpdateController.stream;
  Stream<Map<int, bool>> get subscriptionStatusUpdates =>
      _subscriptionStatusController.stream;

  bool getCategorySubscriptionStatus(int categoryId) {
    return _categorySubscriptionStatus[categoryId] ?? false;
  }

  bool isCategoryStatusLoaded(int categoryId) {
    return _categoryStatusLoaded[categoryId] ?? false;
  }

  bool shouldCheckSubscription(int categoryId) {
    final lastCheck = _lastSubscriptionCheck[categoryId];
    if (lastCheck == null) return true;
    return DateTime.now().difference(lastCheck).inMinutes > 15;
  }

  Color getCategoryAccessColor(
    int categoryId, {
    required bool hasActiveSubscription,
    required bool hasPendingPayment,
  }) {
    final category = getCategoryById(categoryId);
    if (category == null) return AppColors.telegramGray;

    return UiHelpers.getCategoryAccessColor(
      isComingSoon: category.isComingSoon,
      isFree: category.isFree,
      hasActiveSubscription: hasActiveSubscription,
      hasPendingPayment: hasPendingPayment,
    );
  }

  IconData getCategoryAccessIcon(
    int categoryId, {
    required bool hasActiveSubscription,
    required bool hasPendingPayment,
  }) {
    final category = getCategoryById(categoryId);
    if (category == null) return Icons.help;

    return UiHelpers.getCategoryAccessIcon(
      isComingSoon: category.isComingSoon,
      isFree: category.isFree,
      hasActiveSubscription: hasActiveSubscription,
      hasPendingPayment: hasPendingPayment,
    );
  }

  String getCategoryAccessLabel(
    int categoryId, {
    required bool hasActiveSubscription,
    required bool hasPendingPayment,
  }) {
    final category = getCategoryById(categoryId);
    if (category == null) return 'UNKNOWN';

    return UiHelpers.getCategoryAccessLabel(
      isComingSoon: category.isComingSoon,
      isFree: category.isFree,
      hasActiveSubscription: hasActiveSubscription,
      hasPendingPayment: hasPendingPayment,
    );
  }

  void _initBackgroundRefresh() {
    _backgroundRefreshTimer = Timer.periodic(_backgroundRefreshInterval, (_) {
      if (_hasLoaded && !_isLoading && !_isOffline) {
        unawaited(_refreshInBackground());
      }
    });
  }

  Future<void> _refreshInBackground() async {
    debugLog('CategoryProvider', '🔄 Background refresh started');

    try {
      final response = await apiService.getCategories();

      if (response.success && response.data != null) {
        List<Category> loadedCategories = [];

        if (response.data is List<Category>) {
          loadedCategories = response.data ?? [];
        } else if (response.data is List) {
          loadedCategories = (response.data as List)
              .map((item) => item is Category ? item : Category.fromJson(item))
              .toList();
        }

        final bool hasChanges = _hasCategoryChanges(loadedCategories);

        if (hasChanges) {
          debugLog('CategoryProvider', '📦 Changes detected, updating cache');
          _categories = loadedCategories;
          _updateCategoryLists();

          await deviceService.saveCacheItem(
              'categories',
              {
                'categories': _categories.map((c) => c.toJson()).toList(),
                'timestamp': DateTime.now().toIso8601String(),
              },
              ttl: _cacheDuration,
              isUserSpecific: true);

          _categoriesUpdateController.add(_categories);
          _notifySafely();
        }
      }
    } catch (e) {
      debugLog('CategoryProvider', '⚠️ Background refresh failed: $e');
    }
  }

  bool _hasCategoryChanges(List<Category> newCategories) {
    if (_categories.length != newCategories.length) return true;

    for (int i = 0; i < newCategories.length; i++) {
      if (_categories[i].id != newCategories[i].id ||
          _categories[i].name != newCategories[i].name ||
          _categories[i].status != newCategories[i].status ||
          _categories[i].imageUrl != newCategories[i].imageUrl) {
        return true;
      }
    }

    return false;
  }

  void _updateCategoryLists() {
    _activeCategories = _categories.where((c) => c.isActive).toList();
    _comingSoonCategories = _categories.where((c) => c.isComingSoon).toList();
  }

  Future<void> loadCategories(
      {bool forceRefresh = false, bool isManualRefresh = false}) async {
    if (_isLoading && !forceRefresh) return;

    if (isManualRefresh) {
      forceRefresh = true;
    }

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('CategoryProvider', '📥 Loading categories');

      // STEP 1: ALWAYS try cache first (EVEN WHEN OFFLINE)
      if (!forceRefresh) {
        final cachedData =
            await deviceService.getCacheItem<Map<String, dynamic>>(
          'categories',
          isUserSpecific: true,
        );

        if (cachedData != null && cachedData['categories'] is List) {
          final categoriesList = cachedData['categories'] as List;
          _categories = categoriesList.map<Category>((item) {
            try {
              if (item is Category) return item;
              if (item is Map<String, dynamic>) return Category.fromJson(item);
              return Category(
                id: 0,
                name: 'Unknown',
                status: 'active',
                billingCycle: 'monthly',
              );
            } catch (e) {
              debugLog('CategoryProvider', 'Error parsing cached category: $e');
              return Category(
                id: 0,
                name: 'Unknown',
                status: 'active',
                billingCycle: 'monthly',
              );
            }
          }).toList();

          _updateCategoryLists();
          _hasLoaded = true;
          _isLoading = false;

          _categoriesUpdateController.add(_categories);
          _notifySafely();

          debugLog('CategoryProvider',
              '✅ Loaded ${_categories.length} categories from cache');

          // STEP 2: If online, refresh in background
          if (!_isOffline) {
            unawaited(_refreshInBackground());
          }
          return;
        }
      }

      // STEP 3: If offline and no cache, show error
      if (_isOffline) {
        _error = 'You are offline. No cached categories available.';
        _isLoading = false;
        _notifySafely();

        if (isManualRefresh) {
          throw Exception(
              'Network error. Please check your internet connection.');
        }
        return;
      }

      final response = await apiService.getCategories();

      if (response.success && response.data != null) {
        List<Category> loadedCategories = [];

        if (response.data is List<Category>) {
          loadedCategories = response.data ?? [];
        } else if (response.data is List) {
          loadedCategories = (response.data as List).map<Category>((item) {
            if (item is Category) return item;
            if (item is Map<String, dynamic>) return Category.fromJson(item);
            return Category(
              id: 0,
              name: 'Unknown',
              status: 'active',
              billingCycle: 'monthly',
            );
          }).toList();
        }

        _categories = loadedCategories;
        _updateCategoryLists();

        await deviceService.saveCacheItem(
            'categories',
            {
              'categories': _categories.map((c) => c.toJson()).toList(),
              'timestamp': DateTime.now().toIso8601String(),
            },
            ttl: _cacheDuration,
            isUserSpecific: true);

        _hasLoaded = true;
        _categoriesUpdateController.add(_categories);

        debugLog(
            'CategoryProvider', '✅ Loaded ${_categories.length} categories');
      } else {
        _error = response.message;
        debugLog('CategoryProvider',
            '❌ Failed to load categories: ${response.message}');

        if (isManualRefresh) {
          throw Exception(response.message);
        }
      }
    } catch (e) {
      _error = e.toString();
      debugLog('CategoryProvider', '❌ loadCategories error: $e');

      if (isManualRefresh) {
        rethrow;
      }
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> loadCategoriesWithSubscriptionCheck(
      {bool forceRefresh = false}) async {
    await loadCategories(forceRefresh: forceRefresh);

    if (_activeCategories.isNotEmpty && !_isOffline) {
      debugLog('CategoryProvider',
          '🔍 Will check subscription status for ${_activeCategories.length} active categories');

      for (final category in _activeCategories) {
        if (shouldCheckSubscription(category.id)) {
          unawaited(_refreshCategorySubscription(category.id));
        }
      }
    }
  }

  Future<void> _refreshCategorySubscription(int categoryId) async {
    // This will be handled by subscription provider
  }

  Future<Category?> getCategoryByIdAsync(int id) async {
    debugLog(
        'CategoryProvider', '🔍 getCategoryByIdAsync called for category $id');

    _isLoadingCategory[id] = true;
    _notifySafely();

    try {
      final existing = getCategoryById(id);
      if (existing != null) {
        debugLog('CategoryProvider', '✅ Found category $id in cache');
        _isLoadingCategory[id] = false;
        _notifySafely();
        return existing;
      }

      debugLog(
          'CategoryProvider', '🔄 Category $id not in cache, loading from API');

      if (_isLoading) {
        debugLog('CategoryProvider', '⏳ Waiting for existing categories load');

        while (_isLoading) {
          await Future.delayed(const Duration(milliseconds: 100));
        }

        final afterLoad = getCategoryById(id);
        if (afterLoad != null) {
          debugLog('CategoryProvider', '✅ Found category $id after waiting');
          _isLoadingCategory[id] = false;
          _notifySafely();
          return afterLoad;
        }
      }

      await loadCategories(forceRefresh: true);

      final category = getCategoryById(id);
      debugLog('CategoryProvider',
          '✅ After loading, category $id found: ${category != null}');
      return category;
    } finally {
      _isLoadingCategory[id] = false;
      _notifySafely();
    }
  }

  Category? getCategoryById(int id) {
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> syncSubscriptionStatus(Map<int, bool> subscriptionStatus) async {
    if (_isSyncingSubscription) return;

    _isSyncingSubscription = true;

    try {
      debugLog('CategoryProvider',
          '🔄 Syncing subscription status for ${subscriptionStatus.length} categories');

      final now = DateTime.now();
      subscriptionStatus.forEach((categoryId, hasSubscription) {
        _categorySubscriptionStatus[categoryId] = hasSubscription;
        _categoryStatusLoaded[categoryId] = true;
        _lastSubscriptionCheck[categoryId] = now;

        if (_waitForCheckCompleters.containsKey(categoryId)) {
          _waitForCheckCompleters[categoryId]!.complete(hasSubscription);
          _waitForCheckCompleters.remove(categoryId);
        }
      });

      _subscriptionStatusController.add(subscriptionStatus);
      _notifySafely();

      debugLog('CategoryProvider',
          '✅ Subscription status synced for ${subscriptionStatus.length} categories');
    } finally {
      _isSyncingSubscription = false;
    }
  }

  Future<void> batchUpdateSubscriptionStatus(Map<int, bool> statusMap) async {
    if (statusMap.isEmpty) {
      debugLog('CategoryProvider', '⚠️ Received empty status map');
      return;
    }

    debugLog('CategoryProvider',
        '📥 Received batch update for ${statusMap.length} categories');

    final now = DateTime.now();

    statusMap.forEach((categoryId, hasSubscription) {
      _categorySubscriptionStatus[categoryId] = hasSubscription;
      _categoryStatusLoaded[categoryId] = true;
      _lastSubscriptionCheck[categoryId] = now;

      if (_waitForCheckCompleters.containsKey(categoryId)) {
        _waitForCheckCompleters[categoryId]!.complete(hasSubscription);
        _waitForCheckCompleters.remove(categoryId);
      }
    });

    _subscriptionStatusController.add(Map.from(statusMap));
    _notifySafely();

    debugLog('CategoryProvider',
        '✅ Batch updated ${statusMap.length} category subscription statuses');
  }

  Future<void> updateCategorySubscriptionStatus(
      int categoryId, bool hasSubscription) async {
    _categorySubscriptionStatus[categoryId] = hasSubscription;
    _categoryStatusLoaded[categoryId] = true;
    _lastSubscriptionCheck[categoryId] = DateTime.now();

    if (_waitForCheckCompleters.containsKey(categoryId)) {
      _waitForCheckCompleters[categoryId]!.complete(hasSubscription);
      _waitForCheckCompleters.remove(categoryId);
    }

    _subscriptionStatusController.add({categoryId: hasSubscription});
    _notifySafely();

    debugLog('CategoryProvider',
        'Updated category $categoryId subscription status: $hasSubscription');
  }

  Future<bool> waitForSubscriptionCheck(int categoryId,
      {Duration timeout = const Duration(seconds: 10)}) async {
    if (_categoryStatusLoaded[categoryId] == true) {
      return _categorySubscriptionStatus[categoryId] ?? false;
    }

    if (!_waitForCheckCompleters.containsKey(categoryId)) {
      _waitForCheckCompleters[categoryId] = Completer<bool>();
    }

    Future.delayed(timeout, () {
      if (!_waitForCheckCompleters[categoryId]!.isCompleted) {
        _waitForCheckCompleters[categoryId]!.complete(false);
        debugLog('CategoryProvider',
            '⏰ Subscription check timeout for category $categoryId');
      }
    });

    return _waitForCheckCompleters[categoryId]!.future;
  }

  Future<bool> verifyCategoryAccess(int categoryId,
      {bool forceCheck = false}) async {
    if (!forceCheck &&
        _categoryStatusLoaded[categoryId] == true &&
        !shouldCheckSubscription(categoryId)) {
      return _categorySubscriptionStatus[categoryId] ?? false;
    }

    _categoryStatusLoaded[categoryId] = false;
    _notifySafely();

    return waitForSubscriptionCheck(categoryId);
  }

  void clearError() {
    _error = null;
    _notifySafely();
  }

  Future<void> clearUserData() async {
    debugLog('CategoryProvider', ' Clearing category data');

    final session = UserSession();
    final isDifferentUser = !await session.isSameUser();
    final isLoggingOut = await _isLoggingOut();

    if (!isDifferentUser || !isLoggingOut) {
      debugLog('CategoryProvider', '✅ Same user - preserving category cache');
      return;
    }

    await deviceService.clearCacheByPrefix('categories');

    _categories.clear();
    _activeCategories.clear();
    _comingSoonCategories.clear();
    _categorySubscriptionStatus.clear();
    _categoryStatusLoaded.clear();
    _lastSubscriptionCheck.clear();
    _hasLoaded = false;
    _isSyncingSubscription = false;
    _waitForCheckCompleters.clear();
    _isLoadingCategory.clear();

    _categoriesUpdateController.add([]);
    _subscriptionStatusController.add({});
    _notifySafely();
  }

  Future<bool> _isLoggingOut() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.isLoggingOutKey) ?? false;
  }

  @override
  void dispose() {
    _backgroundRefreshTimer?.cancel();
    _categoriesUpdateController.close();
    _subscriptionStatusController.close();
    _waitForCheckCompleters.clear();
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

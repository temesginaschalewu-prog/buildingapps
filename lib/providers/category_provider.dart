import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../models/category_model.dart';
import '../utils/helpers.dart';

class CategoryProvider with ChangeNotifier {
  final ApiService apiService;
  final DeviceService deviceService;

  List<Category> _categories = [];
  List<Category> _activeCategories = [];
  List<Category> _comingSoonCategories = [];
  Map<int, bool> _categorySubscriptionStatus = {};
  Map<int, bool> _categoryStatusLoaded = {};
  Map<int, DateTime> _lastSubscriptionCheck = {};

  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _error;

  Timer? _backgroundRefreshTimer;
  static const Duration _backgroundRefreshInterval = Duration(minutes: 5);
  static const Duration _cacheDuration =
      Duration(hours: 1); // Reduced to 1 hour

  final StreamController<List<Category>> _categoriesUpdateController =
      StreamController<List<Category>>.broadcast();
  final StreamController<Map<int, bool>> _subscriptionStatusController =
      StreamController<Map<int, bool>>.broadcast();

  final Map<int, Completer<bool>> _waitForCheckCompleters = {};
  bool _isSyncingSubscription = false;

  CategoryProvider({required this.apiService, required this.deviceService}) {
    _initBackgroundRefresh();
  }

  void _initBackgroundRefresh() {
    _backgroundRefreshTimer = Timer.periodic(_backgroundRefreshInterval, (_) {
      if (_hasLoaded && !_isLoading) {
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
          loadedCategories = response.data!;
        } else if (response.data is List) {
          loadedCategories = (response.data as List)
              .map((item) => item is Category ? item : Category.fromJson(item))
              .toList();
        }

        bool hasChanges = _hasCategoryChanges(loadedCategories);

        if (hasChanges) {
          debugLog('CategoryProvider', '📦 Changes detected, updating cache');
          _categories = loadedCategories;
          _updateCategoryLists();

          // Log image URLs for debugging
          for (var cat in _categories) {
            if (cat.imageUrl != null) {
              debugLog('CategoryProvider',
                  '📸 ${cat.name} has image: ${cat.imageUrl}');
            }
          }

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
        // Check image URL changes
        return true;
      }
    }

    return false;
  }

  List<Category> get categories => List.unmodifiable(_categories);
  List<Category> get activeCategories => List.unmodifiable(_activeCategories);
  List<Category> get comingSoonCategories =>
      List.unmodifiable(_comingSoonCategories);
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get error => _error;
  bool get isSyncingSubscription => _isSyncingSubscription;

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

  Future<void> loadCategories({bool forceRefresh = false}) async {
    if (_isLoading && !forceRefresh) return;

    if (_hasLoaded && !forceRefresh && _categories.isNotEmpty) {
      debugLog('CategoryProvider', '📦 Using cached categories');
      return;
    }

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('CategoryProvider', '📥 Loading categories');

      if (!forceRefresh) {
        final cachedData =
            await deviceService.getCacheItem<Map<String, dynamic>>('categories',
                isUserSpecific: true);

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

          // Log cached image URLs
          for (var cat in _categories) {
            if (cat.imageUrl != null) {
              debugLog('CategoryProvider',
                  '📸 [CACHED] ${cat.name} image: ${cat.imageUrl}');
            }
          }

          _categoriesUpdateController.add(_categories);
          _notifySafely();

          debugLog('CategoryProvider',
              '✅ Loaded ${_categories.length} categories from cache');

          unawaited(_refreshInBackground());
          return;
        }
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

        // Log image URLs from API
        for (var cat in _categories) {
          if (cat.imageUrl != null) {
            debugLog('CategoryProvider',
                '📸 [API] ${cat.name} image: ${cat.imageUrl}');
          } else {
            debugLog('CategoryProvider', '📸 [API] ${cat.name} has NO image');
          }
        }

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
      }
    } catch (e) {
      _error = e.toString();
      debugLog('CategoryProvider', '❌ loadCategories error: $e');
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  void _updateCategoryLists() {
    _activeCategories = _categories.where((c) => c.isActive).toList();
    _comingSoonCategories = _categories.where((c) => c.isComingSoon).toList();
  }

  Future<void> loadCategoriesWithSubscriptionCheck(
      {bool forceRefresh = false}) async {
    await loadCategories(forceRefresh: forceRefresh);

    if (_activeCategories.isNotEmpty) {
      debugLog('CategoryProvider',
          '🔍 Will check subscription status for ${_activeCategories.length} active categories');

      for (final category in _activeCategories) {
        if (shouldCheckSubscription(category.id)) {
          unawaited(_refreshCategorySubscription(category.id));
        }
      }
    }
  }

  Future<void> _refreshCategorySubscription(int categoryId) async {}

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

  Category? getCategoryById(int id) {
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
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

    return await _waitForCheckCompleters[categoryId]!.future;
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

    return await waitForSubscriptionCheck(categoryId);
  }

  void clearError() {
    _error = null;
    _notifySafely();
  }

  Future<void> clearUserData() async {
    debugLog('CategoryProvider', '🧹 Clearing category data');

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

    _categoriesUpdateController.add([]);
    _subscriptionStatusController.add({});
    _notifySafely();
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

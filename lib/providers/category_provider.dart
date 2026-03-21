// lib/providers/category_provider.dart
// PRODUCTION-READY FINAL VERSION - AUTO LOAD + BACKGROUND REFRESH

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../services/offline_queue_manager.dart';
import '../services/user_session.dart';
import '../services/connectivity_service.dart';
import '../services/hive_service.dart';
import '../models/category_model.dart';
import '../utils/constants.dart';
import 'base_provider.dart';

class CategoryProvider extends ChangeNotifier
    with
        BaseProvider<CategoryProvider>,
        OfflineAwareProvider<CategoryProvider> {
  @override
  final ConnectivityService connectivityService;

  final ApiService apiService;
  final DeviceService deviceService;
  final HiveService hiveService;

  List<Category> _categories = [];
  List<Category> _activeCategories = [];
  List<Category> _comingSoonCategories = [];
  final Map<int, bool> _categorySubscriptionStatus = {};

  bool _hasLoaded = false;
  bool _hasInitialData = false;
  int _apiCallCount = 0;

  bool _isApiCallInProgress = false;
  Completer<void>? _apiCallCompleter;

  Box? _categoriesBox;

  late StreamController<List<Category>> _categoriesUpdateController;

  DateTime? _lastBackgroundRefresh;
  static const Duration _minBackgroundInterval = Duration(minutes: 2);

  CategoryProvider({
    required this.apiService,
    required this.deviceService,
    required this.connectivityService,
    required this.hiveService,
  }) : _categoriesUpdateController =
            StreamController<List<Category>>.broadcast() {
    log('CategoryProvider constructor called');
    initializeOfflineAware(
      connectivity: connectivityService,
      queue: OfflineQueueManager(),
    );
    _init();
  }

  Future<void> _init() async {
    log('_init() START');
    await _openHiveBox();
    await _loadCachedData();
    _hasInitialData = _categories.isNotEmpty;

    // ✅ Show cached data IMMEDIATELY if we have it
    if (_hasInitialData) {
      _categoriesUpdateController.add(_categories);
      safeNotify();
      log('✅ Showing ${_categories.length} cached categories immediately');
    }

    // ✅ Auto-refresh in background to get latest data (no user action needed)
    if (!isOffline) {
      log('🔄 Auto-refreshing categories in background');
      // Small delay to not block UI
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!_isApiCallInProgress) {
          loadCategories(forceRefresh: true);
        }
      });
    }

    log('_init() END - hasInitialData: $_hasInitialData, categories: ${_categories.length}');
  }

  Future<void> _openHiveBox() async {
    try {
      _categoriesBox = await Hive.openBox(AppConstants.hiveCategoriesBox);
      log('✅ Hive box opened');
    } catch (e) {
      log('⚠️ Error opening Hive box: $e');
    }
  }

  // ===== GETTERS =====
  List<Category> get categories => List.unmodifiable(_categories);
  List<Category> get activeCategories => List.unmodifiable(_activeCategories);
  List<Category> get comingSoonCategories =>
      List.unmodifiable(_comingSoonCategories);
  bool get hasLoaded => _hasLoaded;
  bool get hasInitialData => _hasInitialData;

  Stream<List<Category>> get categoriesUpdates =>
      _categoriesUpdateController.stream;

  bool getCategorySubscriptionStatus(int categoryId) {
    return _categorySubscriptionStatus[categoryId] ?? false;
  }

  // ===== LOAD CACHED DATA =====
  Future<void> _loadCachedData() async {
    log('Loading cached data...');

    try {
      if (_categoriesBox != null) {
        final userId = await UserSession().getCurrentUserId();
        if (userId != null) {
          final dynamic cachedData =
              _categoriesBox!.get('user_${userId}_categories');

          if (cachedData != null && cachedData is List) {
            final List<Category> convertedCategories = [];
            for (final item in cachedData) {
              if (item is Category) {
                convertedCategories.add(item);
              } else if (item is Map<String, dynamic>) {
                convertedCategories.add(Category.fromJson(item));
              }
            }

            if (convertedCategories.isNotEmpty) {
              _categories = convertedCategories;
              _updateCategoryLists();
              _hasInitialData = true;
              _hasLoaded = true;
              _categoriesUpdateController.add(_categories);
              log('✅ Loaded ${_categories.length} categories from Hive');
              return;
            }
          }
        }
      }

      // Fallback to DeviceService
      final cachedCategories = await deviceService.getCacheItem<List<dynamic>>(
        'categories',
        isUserSpecific: true,
      );

      if (cachedCategories != null && cachedCategories.isNotEmpty) {
        log('Found ${cachedCategories.length} categories in DeviceService cache');

        final List<Category> convertedCategories = [];
        for (final json in cachedCategories) {
          if (json is Map<String, dynamic>) {
            convertedCategories.add(Category.fromJson(json));
          }
        }

        _categories = convertedCategories;
        _updateCategoryLists();
        _hasInitialData = true;
        _hasLoaded = true;
        _categoriesUpdateController.add(_categories);

        await _saveToHive();
        log('✅ Loaded ${_categories.length} categories from DeviceService');
      } else {
        log('No cached data found');
        _hasLoaded = true;
        _categories = [];
        _updateCategoryLists();
        _categoriesUpdateController.add([]);
      }
    } catch (e) {
      log('❌ Error loading cached categories: $e');
      _hasLoaded = true;
      _categories = [];
      _updateCategoryLists();
      _categoriesUpdateController.add([]);
    }
  }

  Future<void> _saveToHive() async {
    try {
      if (_categoriesBox != null) {
        final userId = await UserSession().getCurrentUserId();
        if (userId != null) {
          await _categoriesBox!.put('user_${userId}_categories', _categories);
          log('💾 Saved ${_categories.length} categories to Hive');
        }
      }
    } catch (e) {
      log('Error saving to Hive: $e');
    }
  }

  // ===== LOAD CATEGORIES =====
  Future<void> loadCategories({
    bool forceRefresh = false,
    bool isManualRefresh = false,
  }) async {
    _apiCallCount++;
    final callId = _apiCallCount;

    log('loadCategories() CALL #$callId - forceRefresh: $forceRefresh, isManualRefresh: $isManualRefresh');

    if (isManualRefresh && isOffline) {
      throw Exception('Network error. Please check your internet connection.');
    }

    // Return cached data immediately if we have it
    if (_hasLoaded && !forceRefresh && !isManualRefresh) {
      log('✅ Already have data, returning cached');
      setLoaded();
      _categoriesUpdateController.add(_categories);
      return;
    }

    if (isLoading && !forceRefresh) {
      log('⏳ Already loading, skipping');
      return;
    }

    // Wait for in-progress API call
    if (_isApiCallInProgress && !forceRefresh && !isManualRefresh) {
      log('⏳ API call already in progress, waiting...');
      if (_apiCallCompleter != null) {
        await _apiCallCompleter!.future;
        if (_hasLoaded) {
          log('✅ Data loaded from waiting');
          setLoaded();
          _categoriesUpdateController.add(_categories);
          return;
        }
      }
    }

    setLoading();

    try {
      // STEP 1: Try Hive cache
      if (!forceRefresh) {
        final userId = await UserSession().getCurrentUserId();
        if (userId != null && _categoriesBox != null) {
          final dynamic cachedData =
              _categoriesBox!.get('user_${userId}_categories');
          if (cachedData != null && cachedData is List) {
            final List<Category> convertedCategories = [];
            for (final item in cachedData) {
              if (item is Category) {
                convertedCategories.add(item);
              } else if (item is Map<String, dynamic>) {
                convertedCategories.add(Category.fromJson(item));
              }
            }
            if (convertedCategories.isNotEmpty) {
              _categories = convertedCategories;
              _updateCategoryLists();
              _hasLoaded = true;
              _hasInitialData = true;
              setLoaded();
              _categoriesUpdateController.add(_categories);
              log('✅ Loaded ${_categories.length} categories from Hive cache');
              if (!isOffline && !isManualRefresh) {
                unawaited(_refreshInBackground());
              }
              return;
            }
          }
        }
      }

      // STEP 2: Try DeviceService cache
      if (!forceRefresh) {
        final cachedCategories =
            await deviceService.getCacheItem<List<dynamic>>(
          'categories',
          isUserSpecific: true,
        );
        if (cachedCategories != null && cachedCategories.isNotEmpty) {
          final List<Category> convertedCategories = [];
          for (final json in cachedCategories) {
            if (json is Map<String, dynamic>) {
              convertedCategories.add(Category.fromJson(json));
            }
          }
          _categories = convertedCategories;
          _updateCategoryLists();
          _hasLoaded = true;
          _hasInitialData = true;
          setLoaded();
          _categoriesUpdateController.add(_categories);
          await _saveToHive();
          log('✅ Loaded ${_categories.length} categories from DeviceService');
          if (!isOffline && !isManualRefresh) unawaited(_refreshInBackground());
          return;
        }
      }

      // STEP 3: Check offline status
      if (isOffline) {
        log('STEP 3: Offline mode');
        if (_hasInitialData) {
          _hasLoaded = true;
          setLoaded();
          _categoriesUpdateController.add(_categories);
          log('✅ Showing ${_categories.length} cached categories offline');
          return;
        }
        setError('You are offline. No cached categories available.');
        _hasLoaded = true;
        setLoaded();
        if (isManualRefresh) {
          throw Exception(
              'Network error. Please check your internet connection.');
        }
        return;
      }

      // STEP 4: Fetch from API
      log('STEP 4: Fetching from API');
      _isApiCallInProgress = true;
      _apiCallCompleter = Completer<void>();

      try {
        final response = await apiService.getCategories();

        if (response.success && response.data != null) {
          _categories = response.data!;
          log('✅ Successfully received ${_categories.length} categories from API');
          _updateCategoryLists();
          _hasLoaded = true;
          _hasInitialData = true;
          setLoaded();
          await _saveToHive();
          deviceService.saveCacheItem(
            'categories',
            _categories.map((c) => c.toJson()).toList(),
            ttl: AppConstants.cacheTTLCategories,
            isUserSpecific: true,
          );
          _categoriesUpdateController.add(_categories);
          log('✅ Categories loaded successfully');
        } else {
          setError(response.message);
          log('❌ API error: ${response.message}');
          _hasLoaded = true;
          setLoaded();
          if (isManualRefresh) throw Exception(response.message);
        }
      } finally {
        _isApiCallInProgress = false;
        _apiCallCompleter?.complete();
        _apiCallCompleter = null;
      }
    } catch (e) {
      log('❌ Error: $e');
      _hasLoaded = true;
      setLoaded();
      setError(e.toString());
      if (isManualRefresh) rethrow;
    } finally {
      safeNotify();
    }
  }

  // ✅ Background refresh with rate limiting
  Future<void> _refreshInBackground() async {
    if (_lastBackgroundRefresh != null &&
        DateTime.now().difference(_lastBackgroundRefresh!) <
            _minBackgroundInterval) {
      log('⏱️ Background refresh rate limited');
      return;
    }
    _lastBackgroundRefresh = DateTime.now();

    if (isOffline) return;

    try {
      final response = await apiService.getCategories();
      if (response.success && response.data != null) {
        final loadedCategories = response.data!;
        if (_hasCategoryChanges(loadedCategories)) {
          log('Changes detected in background refresh');
          _categories = loadedCategories;
          _updateCategoryLists();
          await _saveToHive();
          deviceService.saveCacheItem(
            'categories',
            _categories.map((c) => c.toJson()).toList(),
            ttl: AppConstants.cacheTTLCategories,
            isUserSpecific: true,
          );
          _categoriesUpdateController.add(_categories);
          safeNotify();
          log('🔄 Background refresh complete - updated ${_categories.length} categories');
        }
      }
    } catch (e) {
      log('Background refresh failed: $e');
    }
  }

  void _updateCategoryLists() {
    _activeCategories = _categories.where((c) => c.isActive).toList();
    _comingSoonCategories = _categories.where((c) => c.isComingSoon).toList();
  }

  bool _hasCategoryChanges(List<Category> newCategories) {
    if (_categories.length != newCategories.length) return true;
    for (int i = 0; i < newCategories.length; i++) {
      if (_categories[i].id != newCategories[i].id ||
          _categories[i].name != newCategories[i].name ||
          _categories[i].status != newCategories[i].status) {
        return true;
      }
    }
    return false;
  }

  Category? getCategoryById(int id) {
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> syncSubscriptionStatus(Map<int, bool> subscriptionStatus) async {
    _categorySubscriptionStatus.addAll(subscriptionStatus);
    safeNotify();
  }

  Future<void> updateCategorySubscriptionStatus(
      int categoryId, bool hasSubscription) async {
    _categorySubscriptionStatus[categoryId] = hasSubscription;
    safeNotify();
  }

  Future<void> batchUpdateSubscriptionStatus(Map<int, bool> statusMap) async {
    if (statusMap.isEmpty) return;
    _categorySubscriptionStatus.addAll(statusMap);
    safeNotify();
  }

  @override
  Future<void> onOnlineRefresh() async {
    log('Online - refreshing categories');
    await loadCategories();
  }

  Future<void> clearUserData() async {
    final session = UserSession();
    if (!session.shouldClearCacheOnLogout()) return;
    final userId = await session.getCurrentUserId();
    if (userId != null && _categoriesBox != null) {
      await _categoriesBox!.delete('user_${userId}_categories');
    }
    await deviceService.clearCacheByPrefix('categories');
    _categories.clear();
    _activeCategories.clear();
    _comingSoonCategories.clear();
    _categorySubscriptionStatus.clear();
    _hasLoaded = false;
    _hasInitialData = false;

    await _categoriesUpdateController.close();
    _categoriesUpdateController = StreamController<List<Category>>.broadcast();
    _categoriesUpdateController.add([]);

    safeNotify();
  }

  @override
  void dispose() {
    _categoriesUpdateController.close();
    _categoriesBox?.close();
    disposeSubscriptions();
    super.dispose();
  }
}

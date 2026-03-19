// lib/providers/course_provider.dart
// PRODUCTION-READY FINAL VERSION - FIXED RACE CONDITIONS

import 'dart:async';
import 'package:familyacademyclient/services/offline_queue_manager.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../services/user_session.dart';
import '../services/connectivity_service.dart';
import '../services/hive_service.dart';
import '../models/course_model.dart';
import '../utils/api_response.dart';
import '../utils/constants.dart';
import 'base_provider.dart';

class CourseProvider extends ChangeNotifier
    with
        BaseProvider<CourseProvider>,
        OfflineAwareProvider<CourseProvider>,
        BackgroundRefreshMixin<CourseProvider> {
  @override
  final ConnectivityService connectivityService;

  final ApiService apiService;
  final DeviceService deviceService;
  final HiveService hiveService;

  final Map<int, List<Course>> _coursesByCategory = {};
  final Map<int, bool> _hasLoadedCategory = {};
  final Map<int, bool> _isLoadingCategory = {};
  final Map<int, bool> _failedCategory = {};
  final Map<int, DateTime> _lastFailedAttempt = {};

  // ✅ FIXED: Request deduplication
  final Map<int, Future<void>?> _inFlightRequests = {};

  // Request queuing to prevent parallel API calls
  static const int _maxConcurrentRequests = 2;
  int _activeRequests = 0;
  final List<Map<String, dynamic>> _pendingRequests = [];

  static const Duration _cacheDuration = AppConstants.cacheTTLCourses;
  static const Duration _retryDelay = Duration(seconds: 30);
  @override
  Duration get refreshInterval => const Duration(minutes: 5);

  Box? _coursesBox;
  int _apiCallCount = 0;

  // ✅ FIXED: Proper stream recreation
  late StreamController<Map<int, List<Course>>> _coursesUpdateController;

  CourseProvider({
    required this.apiService,
    required this.deviceService,
    required this.connectivityService,
    required this.hiveService,
  }) : _coursesUpdateController =
            StreamController<Map<int, List<Course>>>.broadcast() {
    log('CourseProvider constructor called');
    initializeOfflineAware(
      connectivity: connectivityService,
      queue: OfflineQueueManager(),
    );
    _init();
  }

  Future<void> _init() async {
    log('_init() START');
    await _openHiveBox();
    await _loadCachedDataForAll();

    if (_hasLoadedCategory.isNotEmpty) {
      startBackgroundRefresh();
    }

    log('_init() END');
  }

  Future<void> _openHiveBox() async {
    try {
      if (!Hive.isBoxOpen(AppConstants.hiveCoursesBox)) {
        _coursesBox = await Hive.openBox<dynamic>(AppConstants.hiveCoursesBox);
      } else {
        _coursesBox = Hive.box<dynamic>(AppConstants.hiveCoursesBox);
      }
      log('✅ Hive box opened');
    } catch (e) {
      log('⚠️ Error opening Hive box: $e');
    }
  }

  Future<void> _loadCachedDataForAll() async {
    try {
      final userId = await UserSession().getCurrentUserId();
      if (userId == null || _coursesBox == null) return;

      final cachedData = _coursesBox!.get('user_${userId}_all_courses');
      if (cachedData != null && cachedData is Map) {
        final Map<int, List<Course>> convertedMap = {};

        cachedData.forEach((key, value) {
          final int categoryId = int.tryParse(key.toString()) ?? 0;
          if (categoryId > 0 && value is List) {
            final List<Course> courses = [];
            for (final item in value) {
              if (item is Course) {
                courses.add(item);
              } else if (item is Map<String, dynamic>) {
                courses.add(Course.fromJson(item));
              }
            }
            if (courses.isNotEmpty) {
              convertedMap[categoryId] = courses;
            }
          }
        });

        _coursesByCategory.addAll(convertedMap);
        for (final categoryId in _coursesByCategory.keys) {
          _hasLoadedCategory[categoryId] = true;
          _failedCategory[categoryId] = false;
        }
        _coursesUpdateController.add(_coursesByCategory);
        log('✅ Loaded ${_coursesByCategory.length} categories from Hive');
      }
    } catch (e) {
      log('Error loading cached data: $e');
    }
  }

  Future<void> _saveToHive() async {
    try {
      final userId = await UserSession().getCurrentUserId();
      if (userId != null && _coursesBox != null) {
        await _coursesBox!
            .put('user_${userId}_all_courses', _coursesByCategory);
        log('💾 Saved courses to Hive');
      }
    } catch (e) {
      log('Error saving to Hive: $e');
    }
  }

  Future<void> _saveCategoryToHive(int categoryId, List<Course> courses) async {
    try {
      final userId = await UserSession().getCurrentUserId();
      if (userId != null && _coursesBox != null) {
        await _coursesBox!.put('user_${userId}_category_${categoryId}_courses',
            {categoryId: courses});
        await _saveToHive();
      }
    } catch (e) {
      log('Error saving category to Hive: $e');
    }
  }

  // ===== GETTERS =====
  List<Course> getCoursesByCategory(int categoryId) {
    return _coursesByCategory[categoryId] ?? [];
  }

  bool hasLoadedCategory(int categoryId) {
    return _hasLoadedCategory[categoryId] ?? false;
  }

  bool isLoadingCategory(int categoryId) {
    return _isLoadingCategory[categoryId] ?? false;
  }

  bool hasFailedCategory(int categoryId) {
    return _failedCategory[categoryId] ?? false;
  }

  Course? getCourseById(int id) {
    for (final courses in _coursesByCategory.values) {
      try {
        return courses.firstWhere((c) => c.id == id);
      } catch (e) {
        continue;
      }
    }
    return null;
  }

  Stream<Map<int, List<Course>>> get coursesUpdates =>
      _coursesUpdateController.stream;

  // ===== LOAD COURSES - FIXED WITH REQUEST DEDUPLICATION =====
  Future<void> loadCoursesByCategory(
    int categoryId, {
    bool forceRefresh = false,
    bool? hasAccess,
    bool isManualRefresh = false,
  }) async {
    _apiCallCount++;
    final callId = _apiCallCount;

    log('loadCoursesByCategory() CALL #$callId for category $categoryId');

    if (isManualRefresh && isOffline) {
      throw Exception('Network error. Please check your internet connection.');
    }

    // Return cached data immediately if available
    if (_hasLoadedCategory[categoryId] == true && !forceRefresh) {
      log('✅ Already have data for category $categoryId, returning cached');
      _coursesUpdateController
          .add({categoryId: _coursesByCategory[categoryId]!});
      setLoaded();
      return;
    }

    // ✅ FIXED: Check if request is already in flight
    if (_inFlightRequests.containsKey(categoryId) && !forceRefresh) {
      log('⏳ Request already in flight for category $categoryId, waiting...');
      await _inFlightRequests[categoryId];
      if (_hasLoadedCategory[categoryId] == true) {
        _coursesUpdateController
            .add({categoryId: _coursesByCategory[categoryId]!});
        setLoaded();
      }
      return;
    }

    // Check if recently failed
    if (_failedCategory[categoryId] == true &&
        _lastFailedAttempt[categoryId] != null &&
        DateTime.now().difference(_lastFailedAttempt[categoryId]!) <
            _retryDelay &&
        !forceRefresh &&
        !isManualRefresh) {
      log('⚠️ Recently failed for category $categoryId, using cache if available');
      if (_coursesByCategory.containsKey(categoryId)) {
        _hasLoadedCategory[categoryId] = true;
        _coursesUpdateController
            .add({categoryId: _coursesByCategory[categoryId]!});
        return;
      }
    }

    if (_isLoadingCategory[categoryId] == true && !forceRefresh) {
      log('⏳ Already loading category $categoryId, waiting...');
      int attempts = 0;
      while (_isLoadingCategory[categoryId] == true && attempts < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }
      if (_hasLoadedCategory[categoryId] == true) {
        log('✅ Got courses from existing load');
        _coursesUpdateController
            .add({categoryId: _coursesByCategory[categoryId]!});
        setLoaded();
        return;
      }
    }

    _isLoadingCategory[categoryId] = true;
    safeNotify();

    // ✅ FIXED: Store the future to deduplicate requests
    _inFlightRequests[categoryId] = _executeLoadCoursesByCategory(
      categoryId,
      forceRefresh: forceRefresh,
      hasAccess: hasAccess,
      isManualRefresh: isManualRefresh,
    );

    try {
      await _inFlightRequests[categoryId];
    } finally {
      _inFlightRequests.remove(categoryId);
    }
  }

  Future<void> _executeLoadCoursesByCategory(
    int categoryId, {
    bool forceRefresh = false,
    bool? hasAccess,
    bool isManualRefresh = false,
  }) async {
    try {
      // STEP 1: Check Hive cache first
      if (!forceRefresh) {
        log('STEP 1: Checking Hive cache for category $categoryId');
        final userId = await UserSession().getCurrentUserId();
        if (userId != null && _coursesBox != null) {
          final cachedData =
              _coursesBox!.get('user_${userId}_category_${categoryId}_courses');

          if (cachedData != null &&
              cachedData is Map &&
              cachedData[categoryId] != null) {
            final dynamic courseData = cachedData[categoryId];
            if (courseData is List) {
              final List<Course> courses = [];
              for (final item in courseData) {
                if (item is Course) {
                  courses.add(item);
                } else if (item is Map<String, dynamic>) {
                  courses.add(Course.fromJson(item));
                }
              }
              if (courses.isNotEmpty) {
                _coursesByCategory[categoryId] = courses;
                _hasLoadedCategory[categoryId] = true;
                _failedCategory[categoryId] = false;
                _isLoadingCategory[categoryId] = false;
                setLoaded();
                _coursesUpdateController.add({categoryId: courses});
                log('✅ Loaded ${courses.length} courses from Hive for category $categoryId');

                if (!isOffline && !isManualRefresh) {
                  _queueBackgroundRefresh(categoryId, hasAccess);
                }
                return;
              }
            }
          }
        }
      }

      // STEP 2: Try DeviceService cache
      if (!forceRefresh) {
        log('STEP 2: Checking DeviceService cache for category $categoryId');
        final cachedCourses = await deviceService.getCacheItem<List<dynamic>>(
          'courses_$categoryId',
          isUserSpecific: true,
        );

        if (cachedCourses != null && cachedCourses.isNotEmpty) {
          final List<Course> courses = [];
          for (final json in cachedCourses) {
            if (json is Map<String, dynamic>) {
              courses.add(Course.fromJson(json));
            }
          }

          if (courses.isNotEmpty) {
            _coursesByCategory[categoryId] = courses;
            _hasLoadedCategory[categoryId] = true;
            _failedCategory[categoryId] = false;
            _isLoadingCategory[categoryId] = false;
            setLoaded();
            _coursesUpdateController.add({categoryId: courses});

            await _saveCategoryToHive(categoryId, courses);
            log('✅ Loaded ${courses.length} courses from DeviceService for category $categoryId');

            if (!isOffline && !isManualRefresh) {
              _queueBackgroundRefresh(categoryId, hasAccess);
            }
            return;
          }
        }
      }

      // STEP 3: Check offline status
      if (isOffline) {
        log('STEP 3: Offline mode for category $categoryId');
        if (_coursesByCategory.containsKey(categoryId)) {
          _hasLoadedCategory[categoryId] = true;
          _isLoadingCategory[categoryId] = false;
          setLoaded();
          _coursesUpdateController
              .add({categoryId: _coursesByCategory[categoryId]!});
          log('✅ Showing cached courses offline for category $categoryId');
          return;
        }

        if (isManualRefresh) {
          throw Exception(
              'Network error. Please check your internet connection.');
        }

        _coursesByCategory[categoryId] = [];
        _hasLoadedCategory[categoryId] = true;
        _isLoadingCategory[categoryId] = false;
        setLoaded();
        _coursesUpdateController.add({categoryId: []});
        return;
      }

      // STEP 4: Queue the API request
      log('STEP 4: Queuing API request for category $categoryId');
      _queueCourseRequest(categoryId, forceRefresh, hasAccess, isManualRefresh);
    } catch (e) {
      log('❌ Error loading courses: $e');

      _failedCategory[categoryId] = true;
      _lastFailedAttempt[categoryId] = DateTime.now();

      if (!_coursesByCategory.containsKey(categoryId)) {
        await _recoverFromCache(categoryId);
      }

      _hasLoadedCategory[categoryId] = true;
      _isLoadingCategory[categoryId] = false;
      setLoaded();
      _coursesUpdateController
          .add({categoryId: _coursesByCategory[categoryId]!});

      if (isManualRefresh) {
        rethrow;
      }
    } finally {
      safeNotify();
    }
  }

  void _queueCourseRequest(int categoryId, bool forceRefresh, bool? hasAccess,
      bool isManualRefresh) {
    _pendingRequests.add({
      'categoryId': categoryId,
      'forceRefresh': forceRefresh,
      'hasAccess': hasAccess,
      'isManualRefresh': isManualRefresh,
      'timestamp': DateTime.now(),
    });

    _processNextCourseRequest();
  }

  Future<void> _processNextCourseRequest() async {
    if (_pendingRequests.isEmpty || _activeRequests >= _maxConcurrentRequests) {
      return;
    }

    _activeRequests++;
    final request = _pendingRequests.removeAt(0);
    final categoryId = request['categoryId'];
    final isManualRefresh = request['isManualRefresh'];

    try {
      log('Processing queued request for category $categoryId (active: $_activeRequests)');

      final response =
          await apiService.getCoursesByCategory(categoryId).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          log('⏱️ API timeout for category $categoryId');
          if (_coursesByCategory.containsKey(categoryId)) {
            log('✅ Using cached courses due to timeout');
            _hasLoadedCategory[categoryId] = true;
            _isLoadingCategory[categoryId] = false;
            setLoaded();
            _coursesUpdateController
                .add({categoryId: _coursesByCategory[categoryId]!});
            return ApiResponse<List<Course>>(
              success: true,
              message: 'Using cached data',
              data: _coursesByCategory[categoryId],
            );
          }
          return ApiResponse<List<Course>>(
            success: false,
            message: 'Request timed out',
            data: [],
          );
        },
      );

      if (!response.success) {
        throw Exception(response.message);
      }

      final courses = response.data ?? [];
      log('✅ Received ${courses.length} courses from API for category $categoryId');

      _coursesByCategory[categoryId] = courses;
      _hasLoadedCategory[categoryId] = true;
      _failedCategory[categoryId] = false;
      _isLoadingCategory[categoryId] = false;
      setLoaded();

      await _saveCategoryToHive(categoryId, courses);

      deviceService.saveCacheItem(
        'courses_$categoryId',
        courses.map((c) => c.toJson()).toList(),
        ttl: _cacheDuration,
        isUserSpecific: true,
      );

      _coursesUpdateController.add({categoryId: courses});
      log('✅ Success! Courses loaded for category $categoryId');
    } catch (e) {
      log('❌ Error loading courses for category $categoryId: $e');

      _failedCategory[categoryId] = true;
      _lastFailedAttempt[categoryId] = DateTime.now();

      if (!_coursesByCategory.containsKey(categoryId)) {
        await _recoverFromCache(categoryId);
      }

      _hasLoadedCategory[categoryId] = true;
      _isLoadingCategory[categoryId] = false;
      setLoaded();
      _coursesUpdateController
          .add({categoryId: _coursesByCategory[categoryId]!});

      if (isManualRefresh) {
        rethrow;
      }
    } finally {
      _activeRequests--;
      _processNextCourseRequest();
    }
  }

  void _queueBackgroundRefresh(int categoryId, bool? hasAccess) {
    if (isOffline) return;

    _pendingRequests.add({
      'categoryId': categoryId,
      'forceRefresh': true,
      'hasAccess': hasAccess,
      'isManualRefresh': false,
      'isBackground': true,
      'timestamp': DateTime.now(),
    });

    unawaited(_processNextCourseRequest());
  }

  Future<void> _recoverFromCache(int categoryId) async {
    log('Attempting cache recovery for category $categoryId');
    final userId = await UserSession().getCurrentUserId();
    if (userId == null) return;

    if (_coursesBox != null) {
      try {
        final cachedData =
            _coursesBox!.get('user_${userId}_category_${categoryId}_courses');
        if (cachedData != null &&
            cachedData is Map &&
            cachedData[categoryId] != null) {
          final dynamic courseData = cachedData[categoryId];
          if (courseData is List) {
            final List<Course> courses = [];
            for (final item in courseData) {
              if (item is Course) {
                courses.add(item);
              } else if (item is Map<String, dynamic>) {
                courses.add(Course.fromJson(item));
              }
            }
            if (courses.isNotEmpty) {
              _coursesByCategory[categoryId] = courses;
              _hasLoadedCategory[categoryId] = true;
              _failedCategory[categoryId] = false;
              _coursesUpdateController.add({categoryId: courses});
              log('✅ Recovered ${courses.length} courses from Hive after error');
              return;
            }
          }
        }
      } catch (e) {
        log('Error recovering from Hive: $e');
      }
    }

    try {
      final cachedCourses = await deviceService.getCacheItem<List<dynamic>>(
        'courses_$categoryId',
        isUserSpecific: true,
      );
      if (cachedCourses != null && cachedCourses.isNotEmpty) {
        final List<Course> courses = [];
        for (final json in cachedCourses) {
          if (json is Map<String, dynamic>) {
            courses.add(Course.fromJson(json));
          }
        }

        if (courses.isNotEmpty) {
          _coursesByCategory[categoryId] = courses;
          _hasLoadedCategory[categoryId] = true;
          _failedCategory[categoryId] = false;
          _coursesUpdateController.add({categoryId: courses});
          log('✅ Recovered ${courses.length} courses from DeviceService after error');
        }
      }
    } catch (e) {
      log('Error recovering from DeviceService: $e');
    }
  }

  Future<void> refreshCoursesWithAccessCheck(
      int categoryId, bool hasAccess) async {
    log('refreshCoursesWithAccessCheck($categoryId, $hasAccess)');
    await deviceService.removeCacheItem('courses_$categoryId',
        isUserSpecific: true);

    final userId = await UserSession().getCurrentUserId();
    if (userId != null && _coursesBox != null) {
      await _coursesBox!
          .delete('user_${userId}_category_${categoryId}_courses');
    }

    _coursesByCategory.remove(categoryId);
    _hasLoadedCategory.remove(categoryId);
    _isLoadingCategory.remove(categoryId);
    _failedCategory.remove(categoryId);
    await loadCoursesByCategory(categoryId,
        forceRefresh: true, hasAccess: hasAccess);
  }

  // ✅ FIXED: Background refresh with rate limiting
  DateTime? _lastBackgroundRefresh;
  static const Duration _minBackgroundInterval = Duration(minutes: 2);

  @override
  Future<void> onBackgroundRefresh() async {
    // Rate limit background refreshes
    if (_lastBackgroundRefresh != null &&
        DateTime.now().difference(_lastBackgroundRefresh!) <
            _minBackgroundInterval) {
      log('⏱️ Background refresh rate limited');
      return;
    }
    _lastBackgroundRefresh = DateTime.now();

    log('Background refresh triggered');
    if (isOffline) return;

    for (final categoryId in _hasLoadedCategory.keys) {
      final shouldSkip = _failedCategory[categoryId] == true &&
          _lastFailedAttempt[categoryId] != null &&
          DateTime.now().difference(_lastFailedAttempt[categoryId]!) <
              _retryDelay;

      if (_hasLoadedCategory[categoryId] == true &&
          !(_isLoadingCategory[categoryId] ?? false) &&
          !shouldSkip) {
        _queueBackgroundRefresh(categoryId, null);
      }
    }
  }

  @override
  Future<void> onOnlineRefresh() async {
    log('Online - refreshing courses');
    for (final categoryId in _hasLoadedCategory.keys) {
      if (_hasLoadedCategory[categoryId] == true) {
        await loadCoursesByCategory(categoryId, forceRefresh: true);
      }
    }
  }

  // ✅ FIXED: Clear user data with proper stream recreation
  Future<void> clearUserData() async {
    final session = UserSession();
    if (!session.shouldClearCacheOnLogout()) return;

    final userId = await session.getCurrentUserId();
    if (userId != null && _coursesBox != null) {
      final keysToDelete = _coursesBox!.keys
          .where((key) => key.toString().contains('user_${userId}_'))
          .toList();
      for (final key in keysToDelete) {
        await _coursesBox!.delete(key);
      }
    }

    for (final categoryId in _coursesByCategory.keys) {
      await deviceService.removeCacheItem('courses_$categoryId',
          isUserSpecific: true);
    }

    _coursesByCategory.clear();
    _hasLoadedCategory.clear();
    _isLoadingCategory.clear();
    _failedCategory.clear();
    _pendingRequests.clear();
    _activeRequests = 0;
    _inFlightRequests.clear();
    stopBackgroundRefresh();

    // ✅ FIXED: Properly recreate stream controller
    await _coursesUpdateController.close();
    _coursesUpdateController =
        StreamController<Map<int, List<Course>>>.broadcast();
    _coursesUpdateController.add({});

    safeNotify();
  }

  @override
  void clearError() {
    super.clearError();
  }

  @override
  void dispose() {
    stopBackgroundRefresh();
    _coursesUpdateController.close();
    _coursesBox?.close();
    _pendingRequests.clear();
    _inFlightRequests.clear();
    disposeSubscriptions();
    super.dispose();
  }
}

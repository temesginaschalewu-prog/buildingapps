import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../services/user_session.dart';
import '../services/connectivity_service.dart';
import '../models/course_model.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class CourseProvider with ChangeNotifier {
  final ApiService apiService;
  final DeviceService deviceService;
  final ConnectivityService connectivityService;

  final List<Course> _courses = [];
  final Map<int, List<Course>> _coursesByCategory = {};
  final Map<int, bool> _hasLoadedCategory = {};
  final Map<int, bool> _isLoadingCategory = {};
  final Map<int, DateTime> _lastLoadedTime = {};
  bool _isLoading = false;
  String? _error;
  bool _isOffline = false;

  static const Duration _cacheDuration = AppConstants.cacheTTLCourses;

  StreamController<Map<int, List<Course>>> _coursesUpdateController =
      StreamController<Map<int, List<Course>>>.broadcast();

  CourseProvider({
    required this.apiService,
    required this.deviceService,
    required this.connectivityService,
  }) {
    _setupConnectivityListener();
  }

  void _setupConnectivityListener() {
    connectivityService.onConnectivityChanged.listen((isOnline) {
      if (_isOffline != !isOnline) {
        _isOffline = !isOnline;
        notifyListeners();
      }
    });
  }

  List<Course> get courses => List.unmodifiable(_courses);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isOffline => _isOffline;
  Stream<Map<int, List<Course>>> get coursesUpdates =>
      _coursesUpdateController.stream;

  List<Course> getCoursesByCategory(int categoryId) {
    return _coursesByCategory[categoryId] ?? [];
  }

  bool hasLoadedCategory(int categoryId) {
    return _hasLoadedCategory[categoryId] ?? false;
  }

  bool isLoadingCategory(int categoryId) {
    return _isLoadingCategory[categoryId] ?? false;
  }

  Course? getCourseById(int id) {
    try {
      return _courses.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  bool hasAccessToCourse(int courseId, bool hasActiveSubscription) {
    final course = getCourseById(courseId);
    if (course == null) return false;
    return course.hasFullAccess(hasActiveSubscription);
  }

  List<Course> getAccessibleCourses(bool hasActiveSubscription) {
    return _courses
        .where((course) => course.hasFullAccess(hasActiveSubscription))
        .toList();
  }

  String getCourseAccessStatus(int courseId, bool hasActiveSubscription) {
    final course = getCourseById(courseId);
    if (course == null) return 'unknown';
    return course.hasFullAccess(hasActiveSubscription) ? 'full' : 'limited';
  }

  Future<void> loadCoursesByCategory(int categoryId,
      {bool forceRefresh = false,
      bool? hasAccess,
      bool isManualRefresh = false}) async {
    // If this is a manual refresh, ALWAYS force refresh
    if (isManualRefresh) {
      forceRefresh = true;
    }

    _isLoadingCategory[categoryId] = true;
    _isLoading = true;
    _error = null;
    _notifySafely();

    debugLog('CourseProvider',
        '🔍 loadCoursesByCategory called for category $categoryId, forceRefresh: $forceRefresh, isOffline: $_isOffline');

    // STEP 1: ALWAYS try cache first (EVEN WHEN OFFLINE) - NO CONDITIONAL!
    if (!forceRefresh) {
      debugLog('CourseProvider',
          '📦 Attempting to load from cache for category $categoryId');

      final cachedCourses = await deviceService.getCacheItem<List<Course>>(
        'courses_$categoryId',
        isUserSpecific: true,
      );

      if (cachedCourses != null && cachedCourses.isNotEmpty) {
        debugLog('CourseProvider',
            '✅ FOUND ${cachedCourses.length} courses in cache for category $categoryId');

        _coursesByCategory[categoryId] = cachedCourses;
        _hasLoadedCategory[categoryId] = true;
        _lastLoadedTime[categoryId] = DateTime.now();
        _updateMainCoursesList(cachedCourses);

        _isLoadingCategory[categoryId] = false;
        _isLoading = false;

        _coursesUpdateController.add({categoryId: cachedCourses});
        _notifySafely();

        // STEP 2: If online, refresh in background
        if (!_isOffline) {
          debugLog('CourseProvider',
              '🔄 Online - refreshing in background for category $categoryId');
          unawaited(_refreshInBackground(categoryId, hasAccess));
        } else {
          debugLog('CourseProvider',
              '📴 Offline - using cached courses for category $categoryId');
        }
        return;
      } else {
        debugLog('CourseProvider',
            '📦 No cached courses found for category $categoryId');
      }
    } else {
      debugLog('CourseProvider', '🔄 forceRefresh = true, skipping cache');
    }

    // STEP 3: If offline and no cache, show error
    if (_isOffline) {
      debugLog(
          'CourseProvider', '📴 Offline and no cache for category $categoryId');
      _error = 'You are offline. No cached courses available.';
      _isLoadingCategory[categoryId] = false;
      _isLoading = false;
      _notifySafely();

      if (isManualRefresh) {
        throw Exception(
            'Network error. Please check your internet connection.');
      }
      return;
    }

    debugLog('CourseProvider',
        '📥 Loading courses from API for category: $categoryId');

    try {
      final response = await apiService.getCoursesByCategory(categoryId);

      if (!response.success) {
        throw Exception(response.message);
      }

      final responseData = response.data ?? {};
      final categoryData = responseData['category'] ?? {};
      final coursesData = responseData['courses'] ?? [];

      final bool categoryHasAccess =
          hasAccess ?? (categoryData['has_access'] ?? false);

      if (coursesData is List) {
        final List<Course> parsedCourses = [];

        for (final courseData in coursesData) {
          try {
            if (courseData is Map<String, dynamic>) {
              final course = Course.fromJson(courseData);

              parsedCourses.add(Course(
                id: course.id,
                name: course.name,
                categoryId: course.categoryId,
                description: course.description,
                chapterCount: course.chapterCount,
                access: categoryHasAccess ? 'full' : 'limited',
                message: categoryHasAccess
                    ? 'Full access to all content'
                    : 'Limited access to free chapters only',
                requiresPayment: !categoryHasAccess,
              ));
            }
          } catch (e) {
            debugLog('CourseProvider',
                'Error parsing course: $e, data: $courseData');
          }
        }

        // Save to cache for next time
        debugLog('CourseProvider',
            '💾 Saving ${parsedCourses.length} courses to cache for category $categoryId');
        await deviceService.saveCacheItem(
          'courses_$categoryId',
          parsedCourses,
          ttl: _cacheDuration,
          isUserSpecific: true,
        );

        _coursesByCategory[categoryId] = parsedCourses;
        _hasLoadedCategory[categoryId] = true;
        _lastLoadedTime[categoryId] = DateTime.now();

        _updateMainCoursesList(parsedCourses);

        _coursesUpdateController.add({categoryId: parsedCourses});
        _notifySafely();

        debugLog('CourseProvider',
            '✅ Parsed ${parsedCourses.length} courses for category $categoryId, access: $categoryHasAccess');

        if (parsedCourses.isEmpty) {
          debugLog(
              'CourseProvider', '⚠️ No courses found for category $categoryId');
        }
      } else {
        debugLog('CourseProvider',
            'Courses data is not a list: ${coursesData.runtimeType}');
        _coursesByCategory[categoryId] = [];
        _hasLoadedCategory[categoryId] = true;
        _lastLoadedTime[categoryId] = DateTime.now();

        _coursesUpdateController.add({categoryId: []});
        _notifySafely();
      }
    } catch (e) {
      _error = e.toString();
      debugLog('CourseProvider', '❌ loadCoursesByCategory error: $e');

      if (!_hasLoadedCategory.containsKey(categoryId) ||
          _coursesByCategory[categoryId]?.isEmpty == true) {
        _coursesByCategory[categoryId] = [];
        _hasLoadedCategory[categoryId] = true;
        _lastLoadedTime[categoryId] = DateTime.now();
        _coursesUpdateController.add({categoryId: []});
        _notifySafely();
      }

      // Re-throw for manual refresh
      if (isManualRefresh) {
        rethrow;
      }
    } finally {
      _isLoadingCategory[categoryId] = false;
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> _refreshInBackground(int categoryId, bool? hasAccess) async {
    if (_isOffline) return;

    try {
      debugLog(
          'CourseProvider', '🔄 Background refresh for category $categoryId');

      final response = await apiService.getCoursesByCategory(categoryId);

      if (response.success && response.data != null) {
        final responseData = response.data ?? {};
        final categoryData = responseData['category'] ?? {};
        final coursesData = responseData['courses'] ?? [];

        final bool categoryHasAccess =
            hasAccess ?? (categoryData['has_access'] ?? false);

        if (coursesData is List) {
          final List<Course> parsedCourses = [];

          for (final courseData in coursesData) {
            try {
              if (courseData is Map<String, dynamic>) {
                final course = Course.fromJson(courseData);
                parsedCourses.add(Course(
                  id: course.id,
                  name: course.name,
                  categoryId: course.categoryId,
                  description: course.description,
                  chapterCount: course.chapterCount,
                  access: categoryHasAccess ? 'full' : 'limited',
                  message: categoryHasAccess
                      ? 'Full access to all content'
                      : 'Limited access to free chapters only',
                  requiresPayment: !categoryHasAccess,
                ));
              }
            } catch (e) {}
          }

          if (parsedCourses.isNotEmpty) {
            debugLog('CourseProvider',
                '💾 Background refresh - updating cache for category $categoryId');
            await deviceService.saveCacheItem(
                'courses_$categoryId', parsedCourses,
                ttl: _cacheDuration, isUserSpecific: true);

            _coursesByCategory[categoryId] = parsedCourses;
            _lastLoadedTime[categoryId] = DateTime.now();
            _updateMainCoursesList(parsedCourses);

            _coursesUpdateController.add({categoryId: parsedCourses});
            _notifySafely();

            debugLog('CourseProvider',
                '✅ Background refresh completed for category $categoryId');
          }
        }
      }
    } catch (e) {
      debugLog('CourseProvider', '⚠️ Background refresh failed: $e');
    }
  }

  void _updateMainCoursesList(List<Course> newCourses) {
    final currentIds = _courses.map((c) => c.id).toSet();
    for (final course in newCourses) {
      if (!currentIds.contains(course.id)) {
        _courses.add(course);
      }
    }
  }

  Future<void> refreshCoursesWithAccessCheck(
      int categoryId, bool hasAccess) async {
    try {
      debugLog('CourseProvider',
          'Refreshing courses for category $categoryId with access: $hasAccess');

      await deviceService.removeCacheItem('courses_$categoryId',
          isUserSpecific: true);

      _coursesByCategory.remove(categoryId);
      _hasLoadedCategory.remove(categoryId);
      _isLoadingCategory.remove(categoryId);
      _lastLoadedTime.remove(categoryId);

      await loadCoursesByCategory(categoryId,
          forceRefresh: true, hasAccess: hasAccess, isManualRefresh: true);

      debugLog('CourseProvider', '✅ Courses refreshed with access: $hasAccess');
    } catch (e) {
      debugLog('CourseProvider', 'refreshCoursesWithAccessCheck error: $e');
    }
  }

  Future<void> clearUserData() async {
    debugLog('CourseProvider', 'Clearing course data');

    final session = UserSession();
    final isDifferentUser = !await session.isSameUser();
    final isLoggingOut = await _isLoggingOut();

    if (!isDifferentUser || !isLoggingOut) {
      debugLog('CourseProvider', '✅ Same user - preserving course cache');
      return;
    }

    for (final categoryId in _coursesByCategory.keys) {
      await deviceService.removeCacheItem('courses_$categoryId',
          isUserSpecific: true);
    }

    _courses.clear();
    _coursesByCategory.clear();
    _hasLoadedCategory.clear();
    _isLoadingCategory.clear();
    _lastLoadedTime.clear();

    await _coursesUpdateController.close();
    _coursesUpdateController =
        StreamController<Map<int, List<Course>>>.broadcast();
    _coursesUpdateController.add({});

    _notifySafely();
  }

  Future<bool> _isLoggingOut() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.isLoggingOutKey) ?? false;
  }

  Future<void> clearCoursesForCategory(int categoryId) async {
    await deviceService.removeCacheItem('courses_$categoryId',
        isUserSpecific: true);

    final categoryCourses = _coursesByCategory[categoryId] ?? [];
    _courses
        .removeWhere((course) => categoryCourses.any((c) => c.id == course.id));

    _coursesByCategory.remove(categoryId);
    _hasLoadedCategory.remove(categoryId);
    _isLoadingCategory.remove(categoryId);
    _lastLoadedTime.remove(categoryId);

    _coursesUpdateController.add({categoryId: []});
    _notifySafely();
  }

  void clearError() {
    _error = null;
    _notifySafely();
  }

  @override
  void dispose() {
    _coursesUpdateController.close();
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

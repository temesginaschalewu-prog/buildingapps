import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../models/course_model.dart';
import '../utils/helpers.dart';

class CourseProvider with ChangeNotifier {
  final ApiService apiService;
  final DeviceService deviceService;

  List<Course> _courses = [];
  Map<int, List<Course>> _coursesByCategory = {};
  Map<int, bool> _hasLoadedCategory = {};
  Map<int, bool> _isLoadingCategory = {};
  Map<int, DateTime> _lastLoadedTime = {};
  bool _isLoading = false;
  String? _error;

  static const Duration _cacheDuration = Duration(minutes: 10);

  CourseProvider({required this.apiService, required this.deviceService});

  List<Course> get courses => List.unmodifiable(_courses);
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Course> getCoursesByCategory(int categoryId) {
    return _coursesByCategory[categoryId] ?? [];
  }

  bool hasLoadedCategory(int categoryId) {
    return _hasLoadedCategory[categoryId] ?? false;
  }

  bool isLoadingCategory(int categoryId) {
    return _isLoadingCategory[categoryId] ?? false;
  }

  Future<void> loadCoursesByCategory(int categoryId,
      {bool forceRefresh = false, bool? hasAccess}) async {
    if (_isLoadingCategory[categoryId] == true && !forceRefresh) {
      return;
    }

    if (!forceRefresh && _hasLoadedCategory[categoryId] == true) {
      final lastLoaded = _lastLoadedTime[categoryId];
      if (lastLoaded != null &&
          DateTime.now().difference(lastLoaded) < _cacheDuration) {
        debugLog('CourseProvider',
            '✅ Using cached courses for category: $categoryId');
        return;
      }
    }

    _isLoadingCategory[categoryId] = true;
    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('CourseProvider', 'Loading courses for category: $categoryId');

      if (!forceRefresh) {
        final cachedCourses = await deviceService
            .getCacheItem<List<Course>>('courses_$categoryId');
        if (cachedCourses != null) {
          _coursesByCategory[categoryId] = cachedCourses;
          _hasLoadedCategory[categoryId] = true;
          _lastLoadedTime[categoryId] = DateTime.now();
          _updateMainCoursesList(cachedCourses);
          debugLog('CourseProvider',
              '✅ Loaded ${cachedCourses.length} courses from cache for category $categoryId');
          return;
        }
      }

      final response = await apiService.getCoursesByCategory(categoryId);

      final responseData = response.data ?? {};
      final categoryData = responseData['category'] ?? {};
      final coursesData = responseData['courses'] ?? [];

      bool categoryHasAccess =
          hasAccess ?? (categoryData['has_access'] ?? false);

      if (coursesData is List) {
        List<Course> parsedCourses = [];

        for (var courseData in coursesData) {
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
                hasPendingPayment: false,
                requiresPayment: !categoryHasAccess,
              ));
            }
          } catch (e) {
            debugLog('CourseProvider',
                'Error parsing course: $e, data: $courseData');
          }
        }

        await deviceService.saveCacheItem('courses_$categoryId', parsedCourses,
            ttl: _cacheDuration);

        _coursesByCategory[categoryId] = parsedCourses;
        _hasLoadedCategory[categoryId] = true;
        _lastLoadedTime[categoryId] = DateTime.now();

        _updateMainCoursesList(parsedCourses);

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
      }
    } catch (e) {
      _error = e.toString();
      debugLog('CourseProvider', 'loadCoursesByCategory error: $e');

      if (!(_hasLoadedCategory[categoryId] ?? false)) {
        _coursesByCategory[categoryId] = [];
        _hasLoadedCategory[categoryId] = true;
        _lastLoadedTime[categoryId] = DateTime.now();
      }
    } finally {
      _isLoadingCategory[categoryId] = false;
      _isLoading = false;
      _notifySafely();
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

      await deviceService.removeCacheItem('courses_$categoryId');

      _coursesByCategory.remove(categoryId);
      _hasLoadedCategory.remove(categoryId);
      _isLoadingCategory.remove(categoryId);
      _lastLoadedTime.remove(categoryId);

      await loadCoursesByCategory(categoryId,
          forceRefresh: true, hasAccess: hasAccess);

      debugLog('CourseProvider', '✅ Courses refreshed with access: $hasAccess');
    } catch (e) {
      debugLog('CourseProvider', 'refreshCoursesWithAccessCheck error: $e');
    }
  }

  Course? getCourseById(int id) {
    try {
      return _courses.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> clearUserData() async {
    debugLog('CourseProvider', 'Clearing course data');

    for (final categoryId in _coursesByCategory.keys) {
      await deviceService.removeCacheItem('courses_$categoryId');
    }

    _courses.clear();
    _coursesByCategory.clear();
    _hasLoadedCategory.clear();
    _isLoadingCategory.clear();
    _lastLoadedTime.clear();

    _notifySafely();
  }

  void clearCoursesForCategory(int categoryId) async {
    await deviceService.removeCacheItem('courses_$categoryId');

    final categoryCourses = _coursesByCategory[categoryId] ?? [];
    _courses
        .removeWhere((course) => categoryCourses.any((c) => c.id == course.id));

    _coursesByCategory.remove(categoryId);
    _hasLoadedCategory.remove(categoryId);
    _isLoadingCategory.remove(categoryId);
    _lastLoadedTime.remove(categoryId);

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

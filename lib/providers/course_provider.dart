import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/course_model.dart';
import '../utils/helpers.dart';

class CourseProvider with ChangeNotifier {
  final ApiService apiService;

  List<Course> _courses = [];
  Map<int, List<Course>> _coursesByCategory = {};
  Map<int, bool> _hasLoadedCategory = {};
  bool _isLoading = false;
  String? _error;

  CourseProvider({required this.apiService});

  List<Course> get courses => List.unmodifiable(_courses);
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Course> getCoursesByCategory(int categoryId) {
    return _coursesByCategory[categoryId] ?? [];
  }

  bool hasLoadedCategory(int categoryId) {
    return _hasLoadedCategory[categoryId] ?? false;
  }

  Future<void> loadCoursesByCategory(int categoryId,
      {bool forceRefresh = false}) async {
    // If we already have data and not forcing refresh, just return cached data
    if (_hasLoadedCategory[categoryId] == true &&
        !forceRefresh &&
        !_isLoading) {
      return;
    }

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('CourseProvider', 'Loading courses for category: $categoryId');
      final response = await apiService.getCoursesByCategory(categoryId);

      final responseData = response.data ?? {};
      final categoryData = responseData['category'] ?? {};
      final coursesData = responseData['courses'] ?? [];

      bool categoryHasAccess = categoryData['has_access'] ?? false;

      if (coursesData is List) {
        List<Course> parsedCourses = [];

        for (var courseData in coursesData) {
          try {
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
          } catch (e) {
            debugLog('CourseProvider',
                'Error parsing course: $e, data: $courseData');
          }
        }

        _coursesByCategory[categoryId] = parsedCourses;
        _hasLoadedCategory[categoryId] = true;

        debugLog('CourseProvider',
            'Parsed ${parsedCourses.length} courses for category $categoryId, access: $categoryHasAccess');

        if (parsedCourses.isEmpty) {
          debugLog(
              'CourseProvider', '⚠️ No courses found for category $categoryId');
        }
      } else {
        debugLog('CourseProvider',
            'Courses data is not a list: ${coursesData.runtimeType}');
        _coursesByCategory[categoryId] = [];
        _hasLoadedCategory[categoryId] = true;
      }

      // Update main courses list without duplicates
      final currentIds = _courses.map((c) => c.id).toSet();
      final newCourses = _coursesByCategory[categoryId]!
          .where((course) => !currentIds.contains(course.id))
          .toList();
      _courses.addAll(newCourses);

      debugLog('CourseProvider',
          'Loaded ${_coursesByCategory[categoryId]!.length} courses for category $categoryId');
    } catch (e) {
      _error = e.toString();
      debugLog('CourseProvider', 'loadCoursesByCategory error: $e');
      // Keep existing data if available
      if (!_hasLoadedCategory[categoryId]!) {
        _coursesByCategory[categoryId] = [];
        _hasLoadedCategory[categoryId] = true;
      }
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> refreshCoursesWithAccessCheck(
      int categoryId, bool hasAccess) async {
    try {
      debugLog('CourseProvider',
          'Refreshing courses for category $categoryId with access: $hasAccess');

      // Clear cache for this category
      _coursesByCategory.remove(categoryId);
      _hasLoadedCategory.remove(categoryId);

      await loadCoursesByCategory(categoryId);

      final courses = _coursesByCategory[categoryId] ?? [];
      if (courses.isNotEmpty) {
        final updatedCourses = courses
            .map((course) => Course(
                  id: course.id,
                  name: course.name,
                  categoryId: course.categoryId,
                  description: course.description,
                  chapterCount: course.chapterCount,
                  access: hasAccess ? 'full' : 'limited',
                  message: hasAccess
                      ? 'Full access to all content'
                      : 'Limited access to free chapters only',
                  hasPendingPayment: false,
                  requiresPayment: !hasAccess,
                ))
            .toList();

        _coursesByCategory[categoryId] = updatedCourses;
        _notifySafely();
      }
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

  void clearCourses() {
    _courses = [];
    _coursesByCategory = {};
    _hasLoadedCategory = {};
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

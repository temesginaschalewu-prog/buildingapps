import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/course_model.dart';
import '../utils/helpers.dart';

class CourseProvider with ChangeNotifier {
  final ApiService apiService;

  List<Course> _courses = [];
  Map<int, List<Course>> _coursesByCategory = {};
  bool _isLoading = false;
  String? _error;

  CourseProvider({required this.apiService});

  List<Course> get courses => _courses;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Course> getCoursesByCategory(int categoryId) {
    return _coursesByCategory[categoryId] ?? [];
  }

  Future<void> loadCoursesByCategory(int categoryId) async {
    if (_isLoading) return; // Prevent multiple simultaneous loads

    _isLoading = true;
    _error = null;

    // Delay notifyListeners to avoid calling during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });

    try {
      debugLog('CourseProvider', 'Loading courses for category: $categoryId');
      final response = await apiService.getCoursesByCategory(categoryId);

      // Extract the courses list from the response data
      final responseData = response.data ?? {};
      final coursesData = responseData['courses'] ?? responseData['data'] ?? [];

      if (coursesData is List) {
        _coursesByCategory[categoryId] =
            List<Course>.from(coursesData.map((x) => Course.fromJson(x)));
      } else {
        _coursesByCategory[categoryId] = [];
      }

      // Update main courses list
      _courses = [..._courses, ..._coursesByCategory[categoryId]!];

      debugLog('CourseProvider',
          'Loaded ${_coursesByCategory[categoryId]!.length} courses for category $categoryId');
    } catch (e) {
      _error = e.toString();
      debugLog('CourseProvider', 'loadCoursesByCategory error: $e');
      _coursesByCategory[categoryId] = [];
    } finally {
      _isLoading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  void clearError() {
    _error = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }
}

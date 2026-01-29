import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/chapter_model.dart';
import '../utils/helpers.dart';

class ChapterProvider with ChangeNotifier {
  final ApiService apiService;

  List<Chapter> _chapters = [];
  Map<int, List<Chapter>> _chaptersByCourse = {};
  Map<int, bool> _hasLoadedForCourse = {};
  Map<int, bool> _isLoadingForCourse = {};
  Map<int, DateTime> _lastLoadedTime = {};
  bool _isLoading = false;
  String? _error;

  // Cache duration: 5 minutes
  static const Duration cacheDuration = Duration(minutes: 5);

  ChapterProvider({required this.apiService});

  List<Chapter> get chapters => _chapters;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool hasLoadedForCourse(int courseId) =>
      _hasLoadedForCourse[courseId] ?? false;
  bool isLoadingForCourse(int courseId) =>
      _isLoadingForCourse[courseId] ?? false;

  List<Chapter> getChaptersByCourse(int courseId) {
    return _chaptersByCourse[courseId] ?? [];
  }

  List<Chapter> getFreeChaptersByCourse(int courseId) {
    final chapters = _chaptersByCourse[courseId] ?? [];
    return chapters.where((c) => c.isFree).toList();
  }

  List<Chapter> getLockedChaptersByCourse(int courseId) {
    final chapters = _chaptersByCourse[courseId] ?? [];
    return chapters.where((c) => c.isLocked).toList();
  }

  Future<void> loadChaptersByCourse(int courseId,
      {bool forceRefresh = false}) async {
    // Check if already loading for this course
    if (_isLoadingForCourse[courseId] == true) {
      return;
    }

    // Check cache: if we have data and it's not expired, don't reload
    final lastLoaded = _lastLoadedTime[courseId];
    final hasCache = _hasLoadedForCourse[courseId] == true;
    final isCacheValid = lastLoaded != null &&
        DateTime.now().difference(lastLoaded) < cacheDuration;

    if (hasCache && !forceRefresh && isCacheValid) {
      debugLog(
          'ChapterProvider', '✅ Using cached chapters for course: $courseId');
      return;
    }

    // Set loading state for this course only
    _isLoadingForCourse[courseId] = true;
    _error = null;
    notifyListeners();

    try {
      debugLog('ChapterProvider', '📚 Loading chapters for course: $courseId');
      final response = await apiService.getChaptersByCourse(courseId);

      final responseData = response.data ?? {};
      final chaptersData =
          responseData['chapters'] ?? responseData['data'] ?? [];

      if (chaptersData is List) {
        final loadedChapters =
            List<Chapter>.from(chaptersData.map((x) => Chapter.fromJson(x)));

        // Update cache
        _chaptersByCourse[courseId] = loadedChapters;
        _hasLoadedForCourse[courseId] = true;
        _lastLoadedTime[courseId] = DateTime.now();

        // Add to global list, avoiding duplicates
        for (final chapter in loadedChapters) {
          if (!_chapters.any((c) => c.id == chapter.id)) {
            _chapters.add(chapter);
          }
        }

        debugLog('ChapterProvider',
            '✅ Loaded ${loadedChapters.length} chapters for course $courseId');
      } else {
        _chaptersByCourse[courseId] = [];
        _hasLoadedForCourse[courseId] = true;
        _lastLoadedTime[courseId] = DateTime.now();
      }

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugLog('ChapterProvider', '❌ loadChaptersByCourse error: $e');

      // If we have cache, keep it even if refresh fails
      if (!_hasLoadedForCourse[courseId]!) {
        _chaptersByCourse[courseId] = [];
      }

      notifyListeners();
      rethrow;
    } finally {
      _isLoadingForCourse[courseId] = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  Chapter? getChapterById(int id) {
    try {
      return _chapters.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  // Clear cache for specific course
  void clearChaptersForCourse(int courseId) {
    _hasLoadedForCourse.remove(courseId);
    _lastLoadedTime.remove(courseId);

    // Remove chapters for this course from global list
    final courseChapters = _chaptersByCourse[courseId] ?? [];
    _chapters.removeWhere(
        (chapter) => courseChapters.any((c) => c.id == chapter.id));
    _chaptersByCourse.remove(courseId);

    notifyListeners();
  }

  // Clear all cache
  void clearAllChapters() {
    _chapters.clear();
    _chaptersByCourse.clear();
    _hasLoadedForCourse.clear();
    _lastLoadedTime.clear();
    _isLoadingForCourse.clear();
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

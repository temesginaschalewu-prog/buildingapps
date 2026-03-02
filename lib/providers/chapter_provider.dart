import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../services/user_session.dart';
import '../models/chapter_model.dart';
import '../utils/helpers.dart';

class ChapterProvider with ChangeNotifier {
  final ApiService apiService;
  final DeviceService deviceService;

  final List<Chapter> _chapters = [];
  final Map<int, List<Chapter>> _chaptersByCourse = {};
  final Map<int, bool> _hasLoadedForCourse = {};
  final Map<int, bool> _isLoadingForCourse = {};
  final Map<int, DateTime> _lastLoadedTime = {};
  bool _isLoading = false;
  String? _error;

  StreamController<Map<int, List<Chapter>>> _chaptersUpdateController =
      StreamController<Map<int, List<Chapter>>>.broadcast();

  static const Duration cacheDuration = Duration(minutes: 15);

  ChapterProvider({required this.apiService, required this.deviceService});

  List<Chapter> get chapters => _chapters;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Stream<Map<int, List<Chapter>>> get chaptersUpdates =>
      _chaptersUpdateController.stream;

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
    if (_isLoadingForCourse[courseId] == true) {
      return;
    }

    final lastLoaded = _lastLoadedTime[courseId];
    final hasCache = _hasLoadedForCourse[courseId] == true;
    final isCacheValid = lastLoaded != null &&
        DateTime.now().difference(lastLoaded) < cacheDuration;

    if (hasCache && !forceRefresh && isCacheValid) {
      debugLog(
          'ChapterProvider', '✅ Using cached chapters for course: $courseId');
      return;
    }

    if (!forceRefresh) {
      final cachedChapters = await deviceService
          .getCacheItem<List<Chapter>>('chapters_course_$courseId');
      if (cachedChapters != null) {
        _chaptersByCourse[courseId] = cachedChapters;
        _hasLoadedForCourse[courseId] = true;
        _lastLoadedTime[courseId] = DateTime.now();

        _addToGlobalList(cachedChapters);

        _chaptersUpdateController.add({courseId: cachedChapters});

        debugLog('ChapterProvider',
            '✅ Loaded ${cachedChapters.length} chapters from cache for course $courseId');
        return;
      }
    }

    _isLoadingForCourse[courseId] = true;
    _error = null;

    try {
      debugLog('ChapterProvider', '📚 Loading chapters for course: $courseId');
      final response = await apiService.getChaptersByCourse(courseId);

      final responseData = response.data ?? {};
      final chaptersData =
          responseData['chapters'] ?? responseData['data'] ?? [];

      if (chaptersData is List) {
        final loadedChapters =
            List<Chapter>.from(chaptersData.map((x) => Chapter.fromJson(x)));

        _chaptersByCourse[courseId] = loadedChapters;
        _hasLoadedForCourse[courseId] = true;
        _lastLoadedTime[courseId] = DateTime.now();

        await deviceService.saveCacheItem(
            'chapters_course_$courseId', loadedChapters,
            ttl: cacheDuration);

        _addToGlobalList(loadedChapters);

        debugLog('ChapterProvider',
            '✅ Loaded ${loadedChapters.length} chapters for course $courseId');

        _chaptersUpdateController.add({courseId: loadedChapters});
      } else {
        _chaptersByCourse[courseId] = [];
        _hasLoadedForCourse[courseId] = true;
        _lastLoadedTime[courseId] = DateTime.now();

        await deviceService.saveCacheItem('chapters_course_$courseId', [],
            ttl: cacheDuration);

        _chaptersUpdateController.add({courseId: []});
      }
    } catch (e) {
      _error = e.toString();
      debugLog('ChapterProvider', '❌ loadChaptersByCourse error: $e');

      if (!_hasLoadedForCourse[courseId]!) {
        _chaptersByCourse[courseId] = [];
        _hasLoadedForCourse[courseId] = true;
        _lastLoadedTime[courseId] = DateTime.now();
      }

      _chaptersUpdateController.add({courseId: []});
    } finally {
      _isLoadingForCourse[courseId] = false;
      _isLoading = false;
      _notifySafely();
    }
  }

  void _addToGlobalList(List<Chapter> newChapters) {
    for (final chapter in newChapters) {
      if (!_chapters.any((c) => c.id == chapter.id)) {
        _chapters.add(chapter);
      }
    }
  }

  Chapter? getChapterById(int id) {
    try {
      return _chapters.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> clearChaptersForCourse(int courseId) async {
    _hasLoadedForCourse.remove(courseId);
    _lastLoadedTime.remove(courseId);

    final courseChapters = _chaptersByCourse[courseId] ?? [];
    _chapters.removeWhere(
        (chapter) => courseChapters.any((c) => c.id == chapter.id));
    _chaptersByCourse.remove(courseId);

    await deviceService.removeCacheItem('chapters_course_$courseId');

    _chaptersUpdateController.add({courseId: []});

    _notifySafely();
  }

  /// 🔵 FIX: Clear user data ONLY for different user logout
  Future<void> clearUserData() async {
    debugLog('ChapterProvider', 'Clearing chapter data');

    // Only clear if this is a different user logout
    final session = UserSession();
    final isDifferentUser = !await session.isSameUser();
    final isLoggingOut = await _isLoggingOut();

    if (!isDifferentUser || !isLoggingOut) {
      debugLog('ChapterProvider', '✅ Same user - preserving chapter cache');
      return;
    }

    await deviceService.clearCacheByPrefix('chapters_course_');

    _chapters.clear();
    _chaptersByCourse.clear();
    _hasLoadedForCourse.clear();
    _lastLoadedTime.clear();
    _isLoadingForCourse.clear();

    await _chaptersUpdateController.close();
    _chaptersUpdateController =
        StreamController<Map<int, List<Chapter>>>.broadcast();

    _chaptersUpdateController.add({});
    _notifySafely();
  }

  Future<bool> _isLoggingOut() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_logging_out') ?? false;
  }

  Future<void> clearAllChapters() async {
    debugLog(
        'ChapterProvider', '⚠️ clearAllChapters called - check if intentional');

    // Only clear if explicitly requested during logout
    final isLoggingOut = await _isLoggingOut();
    if (!isLoggingOut) {
      debugLog(
          'ChapterProvider', 'Skipping clearAllChapters - not logging out');
      return;
    }

    await deviceService.clearCacheByPrefix('chapters_course_');

    _chapters.clear();
    _chaptersByCourse.clear();
    _hasLoadedForCourse.clear();
    _lastLoadedTime.clear();
    _isLoadingForCourse.clear();

    _chaptersUpdateController.add({});
    _notifySafely();
  }

  Future<void> clearError() async {
    _error = null;
    _notifySafely();
  }

  @override
  void dispose() {
    _chaptersUpdateController.close();
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

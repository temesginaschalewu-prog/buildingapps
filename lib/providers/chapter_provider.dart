import 'dart:async';
import 'package:familyacademyclient/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../services/user_session.dart';
import '../services/connectivity_service.dart';
import '../models/chapter_model.dart';
import '../utils/helpers.dart';

class ChapterProvider with ChangeNotifier {
  final ApiService apiService;
  final DeviceService deviceService;
  final ConnectivityService connectivityService;

  final List<Chapter> _chapters = [];
  final Map<int, List<Chapter>> _chaptersByCourse = {};
  final Map<int, bool> _hasLoadedForCourse = {};
  final Map<int, bool> _isLoadingForCourse = {};
  final Map<int, DateTime> _lastLoadedTime = {};
  bool _isLoading = false;
  String? _error;
  bool _isOffline = false;

  StreamController<Map<int, List<Chapter>>> _chaptersUpdateController =
      StreamController<Map<int, List<Chapter>>>.broadcast();

  static const Duration cacheDuration = AppConstants.cacheTTLChapters;

  ChapterProvider({
    required this.apiService,
    required this.deviceService,
    required this.connectivityService,
  }) {
    _preloadCommonCourses();
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

  Future<void> _preloadCommonCourses() async {
    Future.delayed(Duration.zero, () async {
      try {
        final userId = await UserSession().getCurrentUserId();
        if (userId != null) {}
      } catch (e) {}
    });
  }

  List<Chapter> get chapters => _chapters;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isOffline => _isOffline;
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

  Chapter? getChapterById(int id) {
    try {
      return _chapters.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> loadChaptersByCourse(int courseId,
      {bool forceRefresh = false, bool isManualRefresh = false}) async {
    if (_isLoadingForCourse[courseId] == true && !forceRefresh) {
      return;
    }

    if (isManualRefresh) {
      forceRefresh = true;
    }

    _isLoadingForCourse[courseId] = true;
    _isLoading = true;
    _error = null;
    _notifySafely();

    // STEP 1: ALWAYS try cache first (EVEN WHEN OFFLINE)
    if (!forceRefresh) {
      final cachedChapters = await deviceService
          .getCacheItem<List<Chapter>>('chapters_course_$courseId');

      if (cachedChapters != null) {
        _chaptersByCourse[courseId] = cachedChapters;
        _hasLoadedForCourse[courseId] = true;
        _lastLoadedTime[courseId] = DateTime.now();

        _addToGlobalList(cachedChapters);

        _chaptersUpdateController.add({courseId: cachedChapters});
        _notifySafely();

        debugLog('ChapterProvider',
            '✅ Loaded ${cachedChapters.length} chapters from cache for course $courseId');

        // STEP 2: If online, refresh in background
        if (!_isOffline) {
          unawaited(_refreshInBackground(courseId));
        }
        return;
      }
    }

    // STEP 3: If offline and no cache, show error
    if (_isOffline) {
      _error = 'You are offline. No cached chapters available.';
      _isLoadingForCourse[courseId] = false;
      _isLoading = false;
      _notifySafely();

      if (isManualRefresh) {
        throw Exception(
            'Network error. Please check your internet connection.');
      }
      return;
    }

    debugLog('ChapterProvider', '📚 Loading chapters for course: $courseId');

    try {
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

      if (!_hasLoadedForCourse.containsKey(courseId)) {
        _chaptersByCourse[courseId] = [];
        _hasLoadedForCourse[courseId] = true;
        _lastLoadedTime[courseId] = DateTime.now();
      }

      _chaptersUpdateController
          .add({courseId: _chaptersByCourse[courseId] ?? []});

      if (isManualRefresh) {
        rethrow;
      }
    } finally {
      _isLoadingForCourse[courseId] = false;
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> _refreshInBackground(int courseId) async {
    if (_isOffline) return;

    try {
      debugLog('ChapterProvider', '🔄 Background refresh for course $courseId');

      final response = await apiService.getChaptersByCourse(courseId);
      final responseData = response.data ?? {};
      final chaptersData =
          responseData['chapters'] ?? responseData['data'] ?? [];

      if (chaptersData is List) {
        final loadedChapters =
            List<Chapter>.from(chaptersData.map((x) => Chapter.fromJson(x)));

        _chaptersByCourse[courseId] = loadedChapters;
        _lastLoadedTime[courseId] = DateTime.now();

        await deviceService.saveCacheItem(
            'chapters_course_$courseId', loadedChapters,
            ttl: cacheDuration);

        _addToGlobalList(loadedChapters);

        _chaptersUpdateController.add({courseId: loadedChapters});
        _notifySafely();

        debugLog('ChapterProvider',
            '✅ Background refresh completed for course $courseId');
      }
    } catch (e) {
      debugLog('ChapterProvider', '⚠️ Background refresh failed: $e');
    }
  }

  void _addToGlobalList(List<Chapter> newChapters) {
    for (final chapter in newChapters) {
      if (!_chapters.any((c) => c.id == chapter.id)) {
        _chapters.add(chapter);
      }
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

  Future<void> clearUserData() async {
    debugLog('ChapterProvider', 'Clearing chapter data');

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
    return prefs.getBool(AppConstants.isLoggingOutKey) ?? false;
  }

  Future<void> clearAllChapters() async {
    debugLog(
        'ChapterProvider', '⚠️ clearAllChapters called - check if intentional');

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

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:familyacademyclient/models/progress_model.dart';
import 'package:familyacademyclient/services/api_service.dart';
import 'package:familyacademyclient/services/device_service.dart';
import 'package:familyacademyclient/providers/streak_provider.dart';
import 'package:familyacademyclient/utils/helpers.dart';
import '../utils/api_response.dart';

class ProgressProvider with ChangeNotifier {
  final ApiService apiService;
  final DeviceService deviceService;
  final StreakProvider streakProvider;

  List<UserProgress> _userProgress = [];
  Map<int, UserProgress> _progressByChapter = {};
  Map<String, dynamic> _overallStats = {};
  List<Map<String, dynamic>> _achievements = [];
  List<Map<String, dynamic>> _recentActivity = [];
  List<DateTime> _streakHistory = [];

  bool _isLoading = false;
  bool _isLoadingOverall = false;
  bool _hasLoadedOverall = false;
  bool _hasLoadedProgress = false;
  String? _error;

  final Set<int> _pendingSaves = {};
  final Map<int, Timer> _saveDebounceTimers = {};

  StreamController<List<UserProgress>> _progressUpdateController =
      StreamController<List<UserProgress>>.broadcast();
  StreamController<Map<int, UserProgress>> _chapterProgressController =
      StreamController<Map<int, UserProgress>>.broadcast();
  StreamController<Map<String, dynamic>> _overallStatsController =
      StreamController<Map<String, dynamic>>.broadcast();

  static const Duration _cacheDuration = Duration(minutes: 30);
  static const Duration _syncInterval = Duration(seconds: 60);
  static const Duration _saveDebounceDuration = Duration(seconds: 5);

  ProgressProvider({
    required this.apiService,
    required this.deviceService,
    required this.streakProvider,
  }) {
    _init();
  }

  Future<void> _init() async {
    await _loadCachedProgress();
  }

  List<UserProgress> get userProgress => List.unmodifiable(_userProgress);
  Map<String, dynamic> get overallStats => Map.unmodifiable(_overallStats);
  List<Map<String, dynamic>> get achievements =>
      List.unmodifiable(_achievements);
  List<Map<String, dynamic>> get recentActivity =>
      List.unmodifiable(_recentActivity);
  List<DateTime> get streakHistory => List.unmodifiable(_streakHistory);
  bool get isLoading => _isLoading;
  bool get isLoadingOverall => _isLoadingOverall;
  bool get hasLoadedOverall => _hasLoadedOverall;
  bool get hasLoadedProgress => _hasLoadedProgress;
  String? get error => _error;

  Stream<List<UserProgress>> get progressUpdates =>
      _progressUpdateController.stream;
  Stream<Map<int, UserProgress>> get chapterProgressUpdates =>
      _chapterProgressController.stream;
  Stream<Map<String, dynamic>> get overallStatsUpdates =>
      _overallStatsController.stream;

  UserProgress? getProgressForChapter(int chapterId) {
    return _progressByChapter[chapterId];
  }

  double getOverallProgress() {
    if (_userProgress.isEmpty) return 0;
    final totalProgress = _userProgress.fold(
      0.0,
      (sum, progress) => sum + progress.completionPercentage,
    );
    return totalProgress / _userProgress.length;
  }

  int getCompletedChaptersCount() {
    return _userProgress.where((p) => p.completed).length;
  }

  int getTotalChaptersAttempted() {
    return _userProgress.length;
  }

  double getOverallAccuracy() {
    final attemptedQuestions = _userProgress.fold(
      0,
      (sum, progress) => sum + progress.questionsAttempted,
    );

    final correctQuestions = _userProgress.fold(
      0,
      (sum, progress) => sum + progress.questionsCorrect,
    );

    if (attemptedQuestions == 0) return 0;
    return (correctQuestions / attemptedQuestions) * 100;
  }

  Future<void> _loadCachedProgress() async {
    try {
      final cachedProgress = await deviceService
          .getCacheItem<Map<String, dynamic>>('all_user_progress',
              isUserSpecific: true);

      if (cachedProgress != null) {
        final progressList = cachedProgress['progress'] as List? ?? [];
        _userProgress = progressList
            .map((json) => UserProgress.fromJson(json as Map<String, dynamic>))
            .toList();
        _progressByChapter = {for (var p in _userProgress) p.chapterId: p};
        _hasLoadedProgress = true;

        _progressUpdateController.add(_userProgress);
        _chapterProgressController.add(_progressByChapter);

        debugLog('ProgressProvider',
            '✅ Loaded ${_userProgress.length} progress items from cache');
      }

      final cachedStats = await deviceService
          .getCacheItem<Map<String, dynamic>>('overall_stats',
              isUserSpecific: true);
      if (cachedStats != null) {
        _overallStats = cachedStats;
        _hasLoadedOverall = true;

        if (_overallStats['achievements'] != null &&
            _overallStats['achievements'] is List) {
          _achievements = List<Map<String, dynamic>>.from(
              _overallStats['achievements'] as List);
        }

        if (_overallStats['recent_activity'] != null &&
            _overallStats['recent_activity'] is List) {
          _recentActivity = List<Map<String, dynamic>>.from(
              _overallStats['recent_activity'] as List);
        }

        if (_overallStats['streak_history'] != null &&
            _overallStats['streak_history'] is List) {
          _streakHistory = (_overallStats['streak_history'] as List)
              .map((date) => DateTime.parse(date).toLocal())
              .toList();
        }

        _overallStatsController.add(_overallStats);
        notifyListeners();

        debugLog('ProgressProvider', '✅ Loaded overall stats from cache');
      }

      _loadAllProgressFromApi();
    } catch (e) {
      debugLog('ProgressProvider', 'Error loading cached progress: $e');
    }
  }

  Future<void> _loadAllProgressFromApi() async {
    try {
      debugLog(
          'ProgressProvider', 'Loading all progress from API in background');

      final response = await apiService.getOverallProgress();

      if (response.success && response.data != null) {
        _overallStats = response.data!;

        if (_overallStats['achievements'] != null &&
            _overallStats['achievements'] is List) {
          _achievements = List<Map<String, dynamic>>.from(
              _overallStats['achievements'] as List);
          debugLog('ProgressProvider',
              '✅ Loaded ${_achievements.length} achievements');
        }

        if (_overallStats['recent_activity'] != null &&
            _overallStats['recent_activity'] is List) {
          _recentActivity = List<Map<String, dynamic>>.from(
              _overallStats['recent_activity'] as List);
          debugLog('ProgressProvider',
              '✅ Loaded ${_recentActivity.length} recent activities');
        }

        if (_overallStats['streak_history'] != null &&
            _overallStats['streak_history'] is List) {
          _streakHistory = (_overallStats['streak_history'] as List)
              .map((date) => DateTime.parse(date).toLocal())
              .toList();
          debugLog('ProgressProvider',
              '✅ Loaded ${_streakHistory.length} streak history entries');
        }

        await deviceService.saveCacheItem('overall_stats', _overallStats,
            ttl: _cacheDuration, isUserSpecific: true);

        _hasLoadedOverall = true;
        _overallStatsController.add(_overallStats);
        notifyListeners();
      }
    } catch (e) {
      debugLog('ProgressProvider', 'Error loading all progress: $e');
    }
  }

  Future<void> loadUserProgressForCourse(int courseId,
      {bool forceRefresh = false}) async {
    if (_isLoading) return;

    if (!forceRefresh && _hasLoadedProgress && _userProgress.isNotEmpty) {
      debugLog(
          'ProgressProvider', '📦 Using cached progress for course: $courseId');
      _progressUpdateController.add(_userProgress);
      _chapterProgressController.add(_progressByChapter);
      return;
    }

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('ProgressProvider', 'Loading progress for course: $courseId');

      final cacheKey = 'progress_course_$courseId';
      final cachedProgress = await deviceService
          .getCacheItem<List<dynamic>>(cacheKey, isUserSpecific: true);

      if (cachedProgress != null && !forceRefresh) {
        _userProgress = cachedProgress
            .map((json) => UserProgress.fromJson(json as Map<String, dynamic>))
            .toList();
        _progressByChapter = {for (var p in _userProgress) p.chapterId: p};
        _hasLoadedProgress = true;

        _progressUpdateController.add(_userProgress);
        _chapterProgressController.add(_progressByChapter);

        debugLog('ProgressProvider',
            '✅ Loaded ${_userProgress.length} progress entries from cache');

        _refreshCourseProgressInBackground(courseId);
        return;
      }

      final response = await apiService.getUserProgressForCourse(courseId);
      if (response.success && response.data != null) {
        _userProgress = response.data!;
        _progressByChapter = {for (var p in _userProgress) p.chapterId: p};
        _hasLoadedProgress = true;

        await deviceService.saveCacheItem(
            cacheKey, _userProgress.map((p) => p.toJson()).toList(),
            ttl: _cacheDuration, isUserSpecific: true);

        _progressUpdateController.add(_userProgress);
        _chapterProgressController.add(_progressByChapter);

        debugLog('ProgressProvider',
            '✅ Loaded ${_userProgress.length} progress entries from API');
      }
    } on ApiError catch (e) {
      _error = e.userFriendlyMessage;
      debugLog('ProgressProvider', 'ApiError loading progress: ${e.message}');
    } catch (e) {
      _error = 'Failed to load progress: ${e.toString()}';
      debugLog('ProgressProvider', 'Error loading progress: $e');
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> _refreshCourseProgressInBackground(int courseId) async {
    try {
      final response = await apiService.getUserProgressForCourse(courseId);
      if (response.success && response.data != null) {
        _userProgress = response.data!;
        _progressByChapter = {for (var p in _userProgress) p.chapterId: p};

        final cacheKey = 'progress_course_$courseId';
        await deviceService.saveCacheItem(
            cacheKey, _userProgress.map((p) => p.toJson()).toList(),
            ttl: _cacheDuration, isUserSpecific: true);

        _progressUpdateController.add(_userProgress);
        _chapterProgressController.add(_progressByChapter);

        debugLog('ProgressProvider',
            '✅ Background refresh complete for course: $courseId');
      }
    } catch (e) {
      debugLog('ProgressProvider', 'Background refresh error: $e');
    }
  }

  Future<void> loadOverallProgress({bool forceRefresh = false}) async {
    if (_isLoadingOverall) return;

    if (!forceRefresh && _hasLoadedOverall && _overallStats.isNotEmpty) {
      debugLog('ProgressProvider', '📦 Using cached overall stats');
      _overallStatsController.add(_overallStats);
      notifyListeners();

      _refreshOverallProgressInBackground();
      return;
    }

    _isLoadingOverall = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('ProgressProvider', 'Loading overall progress');

      final cachedStats = await deviceService
          .getCacheItem<Map<String, dynamic>>('overall_stats',
              isUserSpecific: true);
      if (cachedStats != null && !forceRefresh) {
        _overallStats = cachedStats;
        _hasLoadedOverall = true;

        if (_overallStats['achievements'] != null &&
            _overallStats['achievements'] is List) {
          _achievements = List<Map<String, dynamic>>.from(
              _overallStats['achievements'] as List);
        }

        if (_overallStats['recent_activity'] != null &&
            _overallStats['recent_activity'] is List) {
          _recentActivity = List<Map<String, dynamic>>.from(
              _overallStats['recent_activity'] as List);
        }

        if (_overallStats['streak_history'] != null &&
            _overallStats['streak_history'] is List) {
          _streakHistory = (_overallStats['streak_history'] as List)
              .map((date) => DateTime.parse(date).toLocal())
              .toList();
        }

        _overallStatsController.add(_overallStats);
        debugLog('ProgressProvider', '✅ Loaded overall stats from cache');

        _refreshOverallProgressInBackground();
        return;
      }

      final response = await apiService.getOverallProgress();

      if (response.success && response.data != null) {
        _overallStats = response.data!;
        _hasLoadedOverall = true;

        if (_overallStats['achievements'] != null &&
            _overallStats['achievements'] is List) {
          _achievements = List<Map<String, dynamic>>.from(
              _overallStats['achievements'] as List);
        }

        if (_overallStats['recent_activity'] != null &&
            _overallStats['recent_activity'] is List) {
          _recentActivity = List<Map<String, dynamic>>.from(
              _overallStats['recent_activity'] as List);
        }

        if (_overallStats['streak_history'] != null &&
            _overallStats['streak_history'] is List) {
          _streakHistory = (_overallStats['streak_history'] as List)
              .map((date) => DateTime.parse(date).toLocal())
              .toList();
        }

        await deviceService.saveCacheItem('overall_stats', _overallStats,
            ttl: _cacheDuration, isUserSpecific: true);
        _overallStatsController.add(_overallStats);
        notifyListeners();

        debugLog('ProgressProvider', '✅ Loaded overall progress stats');
      } else {
        _setEmptyProgressData();
      }
    } on ApiError catch (e) {
      debugLog('ProgressProvider', 'ApiError loading overall progress: $e');
      _setEmptyProgressData();
    } catch (e) {
      _error = 'Failed to load overall progress: ${e.toString()}';
      debugLog('ProgressProvider', 'Error loading overall progress: $e');
      _setEmptyProgressData();
    } finally {
      _isLoadingOverall = false;
      _notifySafely();
    }
  }

  Future<void> _refreshOverallProgressInBackground() async {
    try {
      final response = await apiService.getOverallProgress();
      if (response.success && response.data != null) {
        _overallStats = response.data!;

        if (_overallStats['achievements'] != null &&
            _overallStats['achievements'] is List) {
          _achievements = List<Map<String, dynamic>>.from(
              _overallStats['achievements'] as List);
        }

        if (_overallStats['recent_activity'] != null &&
            _overallStats['recent_activity'] is List) {
          _recentActivity = List<Map<String, dynamic>>.from(
              _overallStats['recent_activity'] as List);
        }

        if (_overallStats['streak_history'] != null &&
            _overallStats['streak_history'] is List) {
          _streakHistory = (_overallStats['streak_history'] as List)
              .map((date) => DateTime.parse(date).toLocal())
              .toList();
        }

        await deviceService.saveCacheItem('overall_stats', _overallStats,
            ttl: _cacheDuration, isUserSpecific: true);

        _overallStatsController.add(_overallStats);
        notifyListeners();

        debugLog('ProgressProvider',
            '✅ Background refresh complete for overall stats');
      }
    } catch (e) {
      debugLog('ProgressProvider', 'Background refresh error: $e');
    }
  }

  void _setEmptyProgressData() {
    _overallStats = {
      'stats': {
        'chapters_completed': 0,
        'total_chapters_attempted': 0,
        'accuracy_percentage': 0.0,
        'study_time_hours': 0.0,
        'total_questions_attempted': 0,
        'total_questions_correct': 0,
      },
      'recent_activity': [],
      'streak_history': [],
      'achievements': [],
    };
    _achievements = [];
    _recentActivity = [];
    _streakHistory = [];
    _hasLoadedOverall = true;
    _overallStatsController.add(_overallStats);
    debugLog('ProgressProvider', 'Set empty progress data');
  }

  Future<void> saveChapterProgress({
    required int chapterId,
    int? videoProgress,
    bool? notesViewed,
    int? questionsAttempted,
    int? questionsCorrect,
  }) async {
    try {
      debugLog('ProgressProvider', 'Saving progress for chapter: $chapterId');

      _saveDebounceTimers[chapterId]?.cancel();

      final completer = Completer<void>();

      _saveDebounceTimers[chapterId] = Timer(_saveDebounceDuration, () async {
        _pendingSaves.add(chapterId);

        try {
          final existingProgress = _progressByChapter[chapterId];
          final now = DateTime.now();

          UserProgress newProgress;

          if (existingProgress != null) {
            newProgress = UserProgress(
              chapterId: chapterId,
              completed:
                  existingProgress.completed || (videoProgress ?? 0) >= 90,
              videoProgress: videoProgress ?? existingProgress.videoProgress,
              notesViewed: notesViewed ?? existingProgress.notesViewed,
              questionsAttempted:
                  questionsAttempted ?? existingProgress.questionsAttempted,
              questionsCorrect:
                  questionsCorrect ?? existingProgress.questionsCorrect,
              lastAccessed: now,
            );
          } else {
            newProgress = UserProgress(
              chapterId: chapterId,
              completed: (videoProgress ?? 0) >= 90,
              videoProgress: videoProgress ?? 0,
              notesViewed: notesViewed ?? false,
              questionsAttempted: questionsAttempted ?? 0,
              questionsCorrect: questionsCorrect ?? 0,
              lastAccessed: now,
            );
          }

          _progressByChapter[chapterId] = newProgress;
          _userProgress = _progressByChapter.values.toList();

          await _saveToLocalCache(chapterId, newProgress);

          _progressUpdateController.add(_userProgress);
          _chapterProgressController.add(_progressByChapter);
          _notifySafely();

          try {
            await apiService.saveUserProgress(
              chapterId: chapterId,
              videoProgress: newProgress.videoProgress,
              notesViewed: newProgress.notesViewed,
              questionsAttempted: newProgress.questionsAttempted,
              questionsCorrect: newProgress.questionsCorrect,
            );

            if (videoProgress != null ||
                notesViewed == true ||
                questionsAttempted != null) {
              await streakProvider.updateStreak();
            }

            await loadOverallProgress(forceRefresh: true);

            debugLog('ProgressProvider',
                '✅ Progress saved to API for chapter: $chapterId');

            completer.complete();
          } catch (apiError) {
            debugLog('ProgressProvider',
                '⚠️ API save failed, will retry later: $apiError');
            await _markAsPendingSync(chapterId, newProgress);
            completer.complete();
          }
        } catch (e) {
          debugLog('ProgressProvider', 'Error in debounced save: $e');
          completer.completeError(e);
        } finally {
          _pendingSaves.remove(chapterId);
          _saveDebounceTimers.remove(chapterId);
        }
      });

      return completer.future;
    } catch (e) {
      debugLog('ProgressProvider', 'Error saving progress: $e');
      rethrow;
    }
  }

  Future<void> _saveToLocalCache(int chapterId, UserProgress progress) async {
    try {
      final cacheKey = 'progress_chapter_$chapterId';
      await deviceService.saveCacheItem(cacheKey, progress.toJson(),
          ttl: _cacheDuration, isUserSpecific: true);

      const allProgressKey = 'all_user_progress';
      final allProgressData = {
        'progress': _userProgress.map((p) => p.toJson()).toList(),
        'last_updated': DateTime.now().toIso8601String(),
      };
      await deviceService.saveCacheItem(allProgressKey, allProgressData,
          ttl: _cacheDuration, isUserSpecific: true);
    } catch (e) {
      debugLog('ProgressProvider', 'Error saving to cache: $e');
    }
  }

  Future<void> _markAsPendingSync(int chapterId, UserProgress progress) async {
    try {
      const pendingKey = 'pending_progress';
      final existing = await deviceService
              .getCacheItem<List<dynamic>>(pendingKey, isUserSpecific: true) ??
          [];

      final updated = [
        ...existing,
        {
          'chapter_id': chapterId,
          'progress': progress.toJson(),
          'timestamp': DateTime.now().toIso8601String(),
        }
      ];

      await deviceService.saveCacheItem(pendingKey, updated,
          ttl: const Duration(days: 7), isUserSpecific: true);
    } catch (e) {
      debugLog('ProgressProvider', 'Error marking pending sync: $e');
    }
  }

  Future<void> _syncPendingProgress() async {
    try {
      const pendingKey = 'pending_progress';
      final pendingItems = await deviceService
          .getCacheItem<List<dynamic>>(pendingKey, isUserSpecific: true);

      if (pendingItems == null || pendingItems.isEmpty) return;

      debugLog('ProgressProvider',
          '🔄 Syncing ${pendingItems.length} pending progress items');

      final List<dynamic> failedItems = [];

      for (final item in pendingItems) {
        try {
          final chapterId = item['chapter_id'] as int;
          final progressData = item['progress'] as Map<String, dynamic>;

          await apiService.saveUserProgress(
            chapterId: chapterId,
            videoProgress: progressData['video_progress'] as int?,
            notesViewed: progressData['notes_viewed'] as bool?,
            questionsAttempted: progressData['questions_attempted'] as int?,
            questionsCorrect: progressData['questions_correct'] as int?,
          );

          debugLog(
              'ProgressProvider', '✅ Synced progress for chapter: $chapterId');
        } catch (e) {
          debugLog('ProgressProvider', '❌ Failed to sync item: $e');
          failedItems.add(item);
        }
      }

      if (failedItems.isEmpty) {
        await deviceService.removeCacheItem(pendingKey, isUserSpecific: true);
      } else {
        await deviceService.saveCacheItem(pendingKey, failedItems,
            ttl: const Duration(days: 7), isUserSpecific: true);
      }
    } catch (e) {
      debugLog('ProgressProvider', 'Error syncing pending progress: $e');
    }
  }

  Future<void> markChapterAsCompleted(int chapterId) async {
    await saveChapterProgress(
      chapterId: chapterId,
      videoProgress: 100,
      notesViewed: true,
      questionsAttempted: 1,
      questionsCorrect: 1,
    );
  }

  Future<void> forceSyncPending() async {
    await _syncPendingProgress();
  }

  Future<void> clearUserData() async {
    debugLog('ProgressProvider', 'Clearing progress data');

    for (final timer in _saveDebounceTimers.values) {
      timer.cancel();
    }
    _saveDebounceTimers.clear();
    _pendingSaves.clear();

    await deviceService.clearCacheByPrefix('progress_');
    await deviceService.clearCacheByPrefix('pending_');

    _userProgress = [];
    _progressByChapter = {};
    _overallStats = {};
    _achievements = [];
    _recentActivity = [];
    _streakHistory = [];
    _hasLoadedOverall = false;
    _hasLoadedProgress = false;

    _progressUpdateController.close();
    _chapterProgressController.close();
    _overallStatsController.close();

    _progressUpdateController =
        StreamController<List<UserProgress>>.broadcast();
    _chapterProgressController =
        StreamController<Map<int, UserProgress>>.broadcast();
    _overallStatsController =
        StreamController<Map<String, dynamic>>.broadcast();

    _progressUpdateController.add(_userProgress);
    _chapterProgressController.add(_progressByChapter);
    _overallStatsController.add(_overallStats);

    _notifySafely();
  }

  void clearError() {
    _error = null;
    _notifySafely();
  }

  @override
  void dispose() {
    for (final timer in _saveDebounceTimers.values) {
      timer.cancel();
    }
    _progressUpdateController.close();
    _chapterProgressController.close();
    _overallStatsController.close();
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

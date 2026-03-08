import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../services/user_session.dart';
import '../services/connectivity_service.dart';
import '../providers/streak_provider.dart';
import '../models/progress_model.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../utils/parsers.dart';
import '../utils/api_response.dart';

class ProgressProvider with ChangeNotifier {
  final ApiService apiService;
  final DeviceService deviceService;
  final StreakProvider streakProvider;
  final ConnectivityService connectivityService;

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
  bool _isOffline = false;

  final Set<int> _pendingSaves = {};
  final Map<int, Timer> _saveDebounceTimers = {};

  StreamController<List<UserProgress>> _progressUpdateController =
      StreamController<List<UserProgress>>.broadcast();
  StreamController<Map<int, UserProgress>> _chapterProgressController =
      StreamController<Map<int, UserProgress>>.broadcast();
  StreamController<Map<String, dynamic>> _overallStatsController =
      StreamController<Map<String, dynamic>>.broadcast();

  static const Duration _cacheDuration = AppConstants.cacheTTLUserProfile;
  static const Duration _saveDebounceDuration = Duration(seconds: 5);

  ProgressProvider({
    required this.apiService,
    required this.deviceService,
    required this.streakProvider,
    required this.connectivityService,
  }) {
    _init();
    _setupConnectivityListener();
  }

  void _setupConnectivityListener() {
    connectivityService.onConnectivityChanged.listen((isOnline) {
      if (_isOffline != !isOnline) {
        _isOffline = !isOnline;
        if (_isOffline) {
          debugLog(
              'ProgressProvider', '📴 Offline mode - using cached progress');
        } else {
          debugLog('ProgressProvider', '📶 Online - syncing pending progress');
          _syncPendingProgress();
        }
        notifyListeners();
      }
    });
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
  bool get isOffline => _isOffline;

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
          .getCacheItem<Map<String, dynamic>>(AppConstants.allUserProgressKey,
              isUserSpecific: true);

      if (cachedProgress != null) {
        final progressList = cachedProgress['progress'] as List? ?? [];
        _userProgress = progressList
            .map((json) => UserProgress.fromJson(json as Map<String, dynamic>))
            .toList();
        _progressByChapter = {for (final p in _userProgress) p.chapterId: p};
        _hasLoadedProgress = true;

        _progressUpdateController.add(_userProgress);
        _chapterProgressController.add(_progressByChapter);

        debugLog('ProgressProvider',
            '✅ Loaded ${_userProgress.length} progress items from cache');
      }

      final cachedStats = await deviceService
          .getCacheItem<Map<String, dynamic>>(AppConstants.overallStatsKey,
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
              .map((date) => Parsers.parseDate(date) ?? DateTime.now())
              .toList();
        }

        _overallStatsController.add(_overallStats);
        notifyListeners();

        debugLog('ProgressProvider', '✅ Loaded overall stats from cache');
      }

      // If online, refresh in background
      if (!_isOffline) {
        await _loadAllProgressFromApi();
      }
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
              .map((date) => Parsers.parseDate(date) ?? DateTime.now())
              .toList();
          debugLog('ProgressProvider',
              '✅ Loaded ${_streakHistory.length} streak history entries');
        }

        await deviceService.saveCacheItem(
            AppConstants.overallStatsKey, _overallStats,
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
      {bool forceRefresh = false, bool isManualRefresh = false}) async {
    if (_isLoading) return;

    // If this is a manual refresh, ALWAYS force refresh
    if (isManualRefresh) {
      forceRefresh = true;
    }

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

      final cacheKey = AppConstants.progressCourseKey(courseId);
      final cachedProgress = await deviceService
          .getCacheItem<List<dynamic>>(cacheKey, isUserSpecific: true);

      if (cachedProgress != null && !forceRefresh && !_isOffline) {
        _userProgress = cachedProgress
            .map((json) => UserProgress.fromJson(json as Map<String, dynamic>))
            .toList();
        _progressByChapter = {for (final p in _userProgress) p.chapterId: p};
        _hasLoadedProgress = true;

        _progressUpdateController.add(_userProgress);
        _chapterProgressController.add(_progressByChapter);

        debugLog('ProgressProvider',
            ' Loaded ${_userProgress.length} progress entries from cache');

        if (!_isOffline) {
          await _refreshCourseProgressInBackground(courseId);
        }
        return;
      }

      if (_isOffline) {
        _error = 'You are offline. Using cached data.';
        _isLoading = false;
        _notifySafely();

        if (isManualRefresh) {
          throw Exception(
              'Network error. Please check your internet connection.');
        }
        return;
      }

      final response = await apiService.getUserProgressForCourse(courseId);
      if (response.success && response.data != null) {
        _userProgress = response.data!;
        _progressByChapter = {for (final p in _userProgress) p.chapterId: p};
        _hasLoadedProgress = true;

        await deviceService.saveCacheItem(
            cacheKey, _userProgress.map((p) => p.toJson()).toList(),
            ttl: _cacheDuration, isUserSpecific: true);

        _progressUpdateController.add(_userProgress);
        _chapterProgressController.add(_progressByChapter);

        debugLog('ProgressProvider',
            '✅ Loaded ${_userProgress.length} progress entries from API');
      } else {
        if (isManualRefresh) {
          throw Exception(response.message);
        }
      }
    } on ApiError catch (e) {
      _error = e.userFriendlyMessage;
      debugLog('ProgressProvider', 'ApiError loading progress: ${e.message}');

      if (isManualRefresh) {
        rethrow;
      }
    } catch (e) {
      _error = 'Failed to load progress: ${e.toString()}';
      debugLog('ProgressProvider', 'Error loading progress: $e');

      if (isManualRefresh) {
        rethrow;
      }
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> _refreshCourseProgressInBackground(int courseId) async {
    if (_isOffline) return;

    try {
      final response = await apiService.getUserProgressForCourse(courseId);
      if (response.success && response.data != null) {
        _userProgress = response.data!;
        _progressByChapter = {for (final p in _userProgress) p.chapterId: p};

        final cacheKey = AppConstants.progressCourseKey(courseId);
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

  Future<void> loadOverallProgress(
      {bool forceRefresh = false, bool isManualRefresh = false}) async {
    if (_isLoadingOverall) return;

    // If this is a manual refresh, ALWAYS force refresh
    if (isManualRefresh) {
      forceRefresh = true;
    }

    if (!forceRefresh && _hasLoadedOverall && _overallStats.isNotEmpty) {
      debugLog('ProgressProvider', ' Using cached overall stats');
      _overallStatsController.add(_overallStats);
      notifyListeners();

      if (!_isOffline) {
        await _refreshOverallProgressInBackground();
      }
      return;
    }

    _isLoadingOverall = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('ProgressProvider', 'Loading overall progress');

      final cachedStats = await deviceService
          .getCacheItem<Map<String, dynamic>>(AppConstants.overallStatsKey,
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
              .map((date) => Parsers.parseDate(date) ?? DateTime.now())
              .toList();
        }

        _overallStatsController.add(_overallStats);
        debugLog('ProgressProvider', '✅ Loaded overall stats from cache');

        if (!_isOffline) {
          await _refreshOverallProgressInBackground();
        }
        return;
      }

      if (_isOffline) {
        _setEmptyProgressData();
        _error = 'You are offline. Showing cached data.';
        _isLoadingOverall = false;
        _notifySafely();

        if (isManualRefresh) {
          throw Exception(
              'Network error. Please check your internet connection.');
        }
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
              .map((date) => Parsers.parseDate(date) ?? DateTime.now())
              .toList();
        }

        await deviceService.saveCacheItem(
            AppConstants.overallStatsKey, _overallStats,
            ttl: _cacheDuration, isUserSpecific: true);
        _overallStatsController.add(_overallStats);
        notifyListeners();

        debugLog('ProgressProvider', '✅ Loaded overall progress stats');
      } else {
        _setEmptyProgressData();

        if (isManualRefresh) {
          throw Exception(response.message);
        }
      }
    } on ApiError catch (e) {
      debugLog('ProgressProvider', 'ApiError loading overall progress: $e');
      _setEmptyProgressData();

      if (isManualRefresh) {
        rethrow;
      }
    } catch (e) {
      _error = 'Failed to load overall progress: ${e.toString()}';
      debugLog('ProgressProvider', 'Error loading overall progress: $e');
      _setEmptyProgressData();

      if (isManualRefresh) {
        rethrow;
      }
    } finally {
      _isLoadingOverall = false;
      _notifySafely();
    }
  }

  Future<void> _refreshOverallProgressInBackground() async {
    if (_isOffline) return;

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
              .map((date) => Parsers.parseDate(date) ?? DateTime.now())
              .toList();
        }

        await deviceService.saveCacheItem(
            AppConstants.overallStatsKey, _overallStats,
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

          // Try to sync with server if online
          if (!_isOffline) {
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
          } else {
            // Offline - queue for later sync
            debugLog('ProgressProvider',
                '📴 Offline - queued progress for chapter: $chapterId');
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
      final cacheKey = AppConstants.progressChapterKey(chapterId);
      await deviceService.saveCacheItem(cacheKey, progress.toJson(),
          ttl: _cacheDuration, isUserSpecific: true);

      const allProgressKey = AppConstants.allUserProgressKey;
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
      final prefs = await SharedPreferences.getInstance();
      const pendingKey = AppConstants.pendingProgressKey;
      final userId = await UserSession().getCurrentUserId();

      if (userId == null) return;

      final userPendingKey = '${pendingKey}_$userId';
      final existingJson = prefs.getString(userPendingKey);
      List<Map<String, dynamic>> pendingItems = [];

      if (existingJson != null) {
        try {
          pendingItems =
              List<Map<String, dynamic>>.from(jsonDecode(existingJson));
        } catch (e) {
          debugLog('ProgressProvider', 'Error parsing pending progress: $e');
        }
      }

      // Update or add
      final existingIndex =
          pendingItems.indexWhere((item) => item['chapter_id'] == chapterId);

      final newItem = {
        'chapter_id': chapterId,
        'progress': progress.toJson(),
        'timestamp': DateTime.now().toIso8601String(),
        'retry_count': 0,
      };

      if (existingIndex >= 0) {
        pendingItems[existingIndex] = newItem;
      } else {
        pendingItems.add(newItem);
      }

      await prefs.setString(userPendingKey, jsonEncode(pendingItems));

      debugLog('ProgressProvider',
          '📝 Marked chapter $chapterId for pending sync (total: ${pendingItems.length})');
    } catch (e) {
      debugLog('ProgressProvider', 'Error marking pending sync: $e');
    }
  }

  Future<void> _syncPendingProgress() async {
    if (_isOffline) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = await UserSession().getCurrentUserId();

      if (userId == null) return;

      const pendingKey = AppConstants.pendingProgressKey;
      final userPendingKey = '${pendingKey}_$userId';
      final existingJson = prefs.getString(userPendingKey);

      if (existingJson == null) return;

      List<Map<String, dynamic>> pendingItems = [];
      try {
        pendingItems =
            List<Map<String, dynamic>>.from(jsonDecode(existingJson));
      } catch (e) {
        debugLog('ProgressProvider', 'Error parsing pending progress: $e');
        await prefs.remove(userPendingKey);
        return;
      }

      if (pendingItems.isEmpty) return;

      debugLog('ProgressProvider',
          '🔄 Syncing ${pendingItems.length} pending progress items');

      final List<Map<String, dynamic>> failedItems = [];

      for (final item in pendingItems) {
        try {
          final chapterId = Parsers.parseInt(item['chapter_id']);
          final progressData = item['progress'] as Map<String, dynamic>;

          await apiService.saveUserProgress(
            chapterId: chapterId,
            videoProgress: Parsers.parseInt(progressData['video_progress']),
            notesViewed: Parsers.parseBool(progressData['notes_viewed']),
            questionsAttempted:
                Parsers.parseInt(progressData['questions_attempted']),
            questionsCorrect:
                Parsers.parseInt(progressData['questions_correct']),
          );

          debugLog(
              'ProgressProvider', '✅ Synced progress for chapter: $chapterId');
        } catch (e) {
          debugLog('ProgressProvider', '❌ Failed to sync item: $e');

          final retryCount = (item['retry_count'] ?? 0) + 1;
          if (retryCount <= 3) {
            item['retry_count'] = retryCount;
            failedItems.add(item);
            debugLog(
                'ProgressProvider', '🔄 Will retry (attempt $retryCount/3)');
          } else {
            debugLog(
                'ProgressProvider', '❌ Permanently failed after 3 retries');
            // Store permanently failed items separately if needed
          }
        }
      }

      if (failedItems.isEmpty) {
        await prefs.remove(userPendingKey);
        debugLog(
            'ProgressProvider', '✅ All pending progress synced successfully');
      } else {
        await prefs.setString(userPendingKey, jsonEncode(failedItems));
        debugLog('ProgressProvider',
            '⚠️ ${failedItems.length} items still pending after sync');
      }

      // Refresh overall progress after sync
      await loadOverallProgress(forceRefresh: true);
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

    final session = UserSession();
    final isDifferentUser = !await session.isSameUser();
    final isLoggingOut = await _isLoggingOut();

    if (!isDifferentUser || !isLoggingOut) {
      debugLog('ProgressProvider', '✅ Same user - preserving progress cache');
      return;
    }

    for (final timer in _saveDebounceTimers.values) {
      timer.cancel();
    }
    _saveDebounceTimers.clear();
    _pendingSaves.clear();

    // Clear user-specific pending progress
    final userId = await session.getCurrentUserId();
    if (userId != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('${AppConstants.pendingProgressKey}_$userId');
    }

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

    await _progressUpdateController.close();
    await _chapterProgressController.close();
    await _overallStatsController.close();

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

  Future<bool> _isLoggingOut() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.isLoggingOutKey) ?? false;
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

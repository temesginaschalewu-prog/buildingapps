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
  bool _isLoading = false;
  bool _isLoadingOverall = false;
  String? _error;
  Timer? _progressSyncTimer;

  StreamController<List<UserProgress>> _progressUpdateController =
      StreamController<List<UserProgress>>.broadcast();
  StreamController<Map<int, UserProgress>> _chapterProgressController =
      StreamController<Map<int, UserProgress>>.broadcast();
  StreamController<Map<String, dynamic>> _overallStatsController =
      StreamController<Map<String, dynamic>>.broadcast();

  static const Duration _cacheDuration = Duration(minutes: 10);
  static const Duration _syncInterval = Duration(seconds: 30);

  ProgressProvider({
    required this.apiService,
    required this.deviceService,
    required this.streakProvider,
  }) {
    _progressSyncTimer = Timer.periodic(_syncInterval, (_) {
      _syncProgressWithBackend();
    });
  }

  List<UserProgress> get userProgress => List.unmodifiable(_userProgress);
  Map<String, dynamic> get overallStats => Map.unmodifiable(_overallStats);
  bool get isLoading => _isLoading;
  bool get isLoadingOverall => _isLoadingOverall;
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

  void initializeEmptyStats() {
    _setEmptyProgressData();
    debugLog('ProgressProvider', 'Initialized with empty stats');
  }

  Future<void> loadUserProgressForCourse(int courseId) async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('ProgressProvider', 'Loading progress for course:$courseId');

      final cacheKey = 'progress_course_$courseId';
      final cachedProgress =
          await deviceService.getCacheItem<List<dynamic>>(cacheKey);

      if (cachedProgress != null) {
        _userProgress =
            cachedProgress.map((json) => UserProgress.fromJson(json)).toList();
        _progressByChapter = {for (var p in _userProgress) p.chapterId: p};

        _progressUpdateController.add(_userProgress);
        _chapterProgressController.add(_progressByChapter);

        debugLog('ProgressProvider',
            '✅ Loaded ${_userProgress.length} progress entries from cache');
        return;
      }

      final response = await apiService.getUserProgressForCourse(courseId);
      _userProgress = response.data ?? [];
      _progressByChapter = {for (var p in _userProgress) p.chapterId: p};

      final progressJson = _userProgress.map((p) => p.toJson()).toList();
      await deviceService.saveCacheItem(cacheKey, progressJson,
          ttl: _cacheDuration);

      _progressUpdateController.add(_userProgress);
      _chapterProgressController.add(_progressByChapter);

      debugLog('ProgressProvider',
          '✅ Loaded ${_userProgress.length} progress entries');
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

  Future<void> loadOverallProgress({required bool forceRefresh}) async {
    if (_isLoadingOverall) return;

    _isLoadingOverall = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('ProgressProvider', 'Loading overall progress');

      final cachedStats = await deviceService
          .getCacheItem<Map<String, dynamic>>('overall_stats');
      if (cachedStats != null) {
        _overallStats = cachedStats;
        _overallStatsController.add(_overallStats);
        debugLog('ProgressProvider', '✅ Loaded overall stats from cache');
        return;
      }

      final response = await apiService.getOverallProgress();

      if (response.success && response.data != null) {
        _overallStats = response.data!;
        await deviceService.saveCacheItem('overall_stats', _overallStats,
            ttl: _cacheDuration);
        _overallStatsController.add(_overallStats);

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
    };
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
      debugLog('ProgressProvider', 'Saving progress for chapter:$chapterId');

      await apiService.saveUserProgress(
        chapterId: chapterId,
        videoProgress: videoProgress,
        notesViewed: notesViewed,
        questionsAttempted: questionsAttempted,
        questionsCorrect: questionsCorrect,
      );

      final existingProgress = _progressByChapter[chapterId];
      final now = DateTime.now();

      UserProgress newProgress;

      if (existingProgress != null) {
        newProgress = UserProgress(
          chapterId: chapterId,
          completed: existingProgress.completed || (videoProgress ?? 0) >= 90,
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

      final courseId = await _getCourseIdForChapter(chapterId);
      if (courseId != null) {
        final cacheKey = 'progress_course_$courseId';
        final progressJson = _userProgress.map((p) => p.toJson()).toList();
        await deviceService.saveCacheItem(cacheKey, progressJson,
            ttl: _cacheDuration);
      }

      if (videoProgress != null ||
          notesViewed == true ||
          questionsAttempted != null) {
        await streakProvider.updateStreak();
      }

      _progressUpdateController.add(_userProgress);
      _chapterProgressController.add(_progressByChapter);

      debugLog('ProgressProvider', 'Progress saved for chapter:$chapterId');
      _notifySafely();

      await loadOverallProgress(forceRefresh: true);
    } on ApiError catch (e) {
      _error = e.userFriendlyMessage;
      debugLog('ProgressProvider', 'ApiError saving progress: $e');
      rethrow;
    } catch (e) {
      _error = 'Failed to save progress: ${e.toString()}';
      debugLog('ProgressProvider', 'Error saving progress: $e');
      rethrow;
    }
  }

  Future<void> markChapterAsCompleted(int chapterId) async {
    try {
      debugLog('ProgressProvider', 'Marking chapter $chapterId as completed');

      await apiService.saveUserProgress(
        chapterId: chapterId,
        videoProgress: 100,
        notesViewed: true,
        questionsAttempted: 1,
        questionsCorrect: 1,
      );

      final progress = _progressByChapter[chapterId];
      if (progress != null) {
        final completedProgress = UserProgress(
          chapterId: chapterId,
          completed: true,
          videoProgress: 100,
          notesViewed: true,
          questionsAttempted: progress.questionsAttempted + 1,
          questionsCorrect: progress.questionsCorrect + 1,
          lastAccessed: DateTime.now(),
        );

        _progressByChapter[chapterId] = completedProgress;
        _userProgress = _progressByChapter.values.toList();

        final courseId = await _getCourseIdForChapter(chapterId);
        if (courseId != null) {
          final cacheKey = 'progress_course_$courseId';
          final progressJson = _userProgress.map((p) => p.toJson()).toList();
          await deviceService.saveCacheItem(cacheKey, progressJson,
              ttl: _cacheDuration);
        }
      }

      await streakProvider.updateStreak();

      _progressUpdateController.add(_userProgress);
      _chapterProgressController.add(_progressByChapter);

      await loadOverallProgress(forceRefresh: true);

      _notifySafely();
    } on ApiError catch (e) {
      debugLog('ProgressProvider', 'ApiError marking chapter completed: $e');
      rethrow;
    } catch (e) {
      debugLog('ProgressProvider', 'Error marking chapter as completed: $e');
      rethrow;
    }
  }

  Future<void> _syncProgressWithBackend() async {
    if (_userProgress.isEmpty) return;

    try {
      debugLog('ProgressProvider', '🔄 Syncing progress with backend...');
    } catch (e) {
      debugLog('ProgressProvider', 'Error syncing progress: $e');
    }
  }

  Future<int?> _getCourseIdForChapter(int chapterId) async {
    return null;
  }

  Future<void> clearUserData() async {
    debugLog('ProgressProvider', 'Clearing progress data');

    await deviceService.clearCacheByPrefix('progress_');
    await deviceService.clearCacheByPrefix('overall_stats');

    _userProgress = [];
    _progressByChapter = {};
    _overallStats = {};

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
    _progressSyncTimer?.cancel();
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

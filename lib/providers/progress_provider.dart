// lib/providers/progress_provider.dart
// COMPLETE FIXED VERSION - PROPERLY HANDLES _Map<dynamic, dynamic>

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../services/user_session.dart';
import '../services/connectivity_service.dart';
import '../services/hive_service.dart';
import '../services/offline_queue_manager.dart';
import '../providers/streak_provider.dart';
import '../models/progress_model.dart';
import '../utils/constants.dart';
import '../utils/parsers.dart';
import '../utils/helpers.dart';
import 'base_provider.dart';

/// PRODUCTION-READY Progress Provider with Full Offline Support
class ProgressProvider extends ChangeNotifier
    with
        BaseProvider<ProgressProvider>,
        OfflineAwareProvider<ProgressProvider>,
        BackgroundRefreshMixin<ProgressProvider> {
  @override
  final ConnectivityService connectivityService;

  final ApiService apiService;
  final DeviceService deviceService;
  final StreakProvider streakProvider;
  final HiveService hiveService;
  final OfflineQueueManager offlineQueueManager;

  List<UserProgress> _userProgress = [];
  Map<int, UserProgress> _progressByChapter = {};
  Map<String, dynamic> _overallStats = {};
  List<Map<String, dynamic>> _achievements = [];
  List<Map<String, dynamic>> _recentActivity = [];
  List<DateTime> _streakHistory = [];

  bool _hasLoadedOverall = false;
  bool _hasLoadedProgress = false;
  bool _isLoadingOverall = false;

  static const Duration _cacheDuration = AppConstants.cacheTTLUserProfile;
  static const Duration _saveDebounceDuration = Duration(seconds: 5);
  @override
  Duration get refreshInterval => const Duration(minutes: 5);

  final Set<int> _pendingSaves = {};
  final Map<int, Timer> _saveDebounceTimers = {};

  Box? _progressBox;
  Box? _statsBox;
  String? _activeUserId;

  int _apiCallCount = 0;

  late StreamController<List<UserProgress>> _progressUpdateController;
  late StreamController<Map<int, UserProgress>> _chapterProgressController;
  late StreamController<Map<String, dynamic>> _overallStatsController;

  DateTime? _lastBackgroundRefresh;
  static const Duration _minBackgroundInterval = Duration(minutes: 2);

  ProgressProvider({
    required this.apiService,
    required this.deviceService,
    required this.streakProvider,
    required this.connectivityService,
    required this.hiveService,
    required this.offlineQueueManager,
  })  : _progressUpdateController =
            StreamController<List<UserProgress>>.broadcast(),
        _chapterProgressController =
            StreamController<Map<int, UserProgress>>.broadcast(),
        _overallStatsController =
            StreamController<Map<String, dynamic>>.broadcast() {
    log('ProgressProvider constructor called');
    initializeOfflineAware(
      connectivity: connectivityService,
      queue: offlineQueueManager,
    );
    _registerQueueProcessors();
    _init();
  }

  void _registerQueueProcessors() {
    offlineQueueManager.registerProcessor(
      AppConstants.queueActionSaveProgress,
      _processSaveProgress,
    );
    log('✅ Registered queue processors');
  }

  Future<bool> _processSaveProgress(Map<String, dynamic> data) async {
    try {
      log('Processing offline progress save');
      final response = await apiService.saveUserProgress(
        chapterId: data['chapter_id'],
        videoProgress: data['video_progress'],
        notesViewed: data['notes_viewed'],
        questionsAttempted: data['questions_attempted'],
        questionsCorrect: data['questions_correct'],
      );
      return response.success;
    } catch (e) {
      log('Error processing progress save: $e');
      return false;
    }
  }

  Future<void> _init() async {
    log('_init() START');
    await _openHiveBoxes();
    await _ensureCurrentUserScope();
    await _loadCachedProgress();

    if (_hasLoadedOverall || _hasLoadedProgress) {
      startBackgroundRefresh();
    }

    log('_init() END');
  }

  Future<void> _openHiveBoxes() async {
    try {
      if (!Hive.isBoxOpen(AppConstants.hiveProgressBox)) {
        _progressBox = await Hive.openBox(AppConstants.hiveProgressBox);
      } else {
        _progressBox = Hive.box(AppConstants.hiveProgressBox);
      }

      if (!Hive.isBoxOpen('progress_stats_box')) {
        _statsBox = await Hive.openBox('progress_stats_box');
      } else {
        _statsBox = Hive.box('progress_stats_box');
      }

      log('✅ Hive boxes opened');
    } catch (e) {
      log('⚠️ Error opening Hive boxes: $e');
    }
  }

  Future<String?> _ensureCurrentUserScope() async {
    final userId = await UserSession().getCurrentUserId();
    if (_activeUserId == userId) return userId;

    log('🔄 ProgressProvider user scope changed: $_activeUserId -> $userId');
    _activeUserId = userId;
    _resetInMemoryState();
    return userId;
  }

  void _resetInMemoryState() {
    for (final timer in _saveDebounceTimers.values) {
      timer.cancel();
    }
    _saveDebounceTimers.clear();
    _pendingSaves.clear();

    stopBackgroundRefresh();
    _lastBackgroundRefresh = null;

    _userProgress = [];
    _progressByChapter = {};
    _overallStats = {};
    _achievements = [];
    _recentActivity = [];
    _streakHistory = [];
    _hasLoadedOverall = false;
    _hasLoadedProgress = false;
    _isLoadingOverall = false;

    if (!_progressUpdateController.isClosed) {
      _progressUpdateController.add(_userProgress);
    }
    if (!_chapterProgressController.isClosed) {
      _chapterProgressController.add(_progressByChapter);
    }
    if (!_overallStatsController.isClosed) {
      _overallStatsController.add(_overallStats);
    }

    safeNotify();
  }

  // ✅ FIXED: Properly convert any Map type to Map<String, dynamic>
  Map<String, dynamic> _convertToMapString(dynamic input) {
    if (input == null) return {};
    if (input is Map<String, dynamic>) return input;

    if (input is Map) {
      try {
        final Map<String, dynamic> result = {};
        // Use keys and values directly - this works for _Map<dynamic, dynamic>
        final keys = input.keys.toList();
        final values = input.values.toList();
        for (int i = 0; i < keys.length; i++) {
          final key = keys[i];
          final value = values[i];
          result[key.toString()] = value;
        }
        return result;
      } catch (e) {
        log('Error converting map: $e');
        return {};
      }
    }
    return {};
  }

// ✅ FIXED: Complete rewrite with safe casting for ALL data types
  Future<void> _loadCachedProgress() async {
    try {
      final userId = await _ensureCurrentUserScope();
      if (userId == null) return;

      // Try Hive first
      if (_progressBox != null) {
        final dynamic cachedProgressMap =
            _progressBox!.get('user_${userId}_progress');

        if (cachedProgressMap != null) {
          final Map<int, UserProgress> convertedMap = {};

          // ✅ FIXED: Handle different map types safely
          if (cachedProgressMap is Map) {
            try {
              // Convert to a map with string keys first
              final Map<String, dynamic> stringKeyMap = {};
              cachedProgressMap.forEach((key, value) {
                stringKeyMap[key.toString()] = value;
              });

              // Now iterate safely
              for (final entry in stringKeyMap.entries) {
                final String key = entry.key;
                final dynamic value = entry.value;
                final int chapterId = int.tryParse(key) ?? 0;

                if (chapterId > 0) {
                  try {
                    UserProgress progress;

                    if (value is UserProgress) {
                      progress = value;
                    } else if (value is Map<String, dynamic>) {
                      progress = UserProgress.fromJson(value);
                    } else if (value is Map) {
                      // Convert _Map<dynamic,dynamic> to Map<String,dynamic>
                      final Map<String, dynamic> safeMap = {};
                      value.forEach((k, v) {
                        safeMap[k.toString()] = v;
                      });
                      progress = UserProgress.fromJson(safeMap);
                    } else {
                      continue;
                    }

                    convertedMap[chapterId] = progress;
                  } catch (e) {
                    log('Error converting progress for chapter $chapterId: $e');
                  }
                }
              }
            } catch (e) {
              log('Error iterating progress map: $e');
            }
          }

          if (convertedMap.isNotEmpty) {
            _progressByChapter = convertedMap;
            _userProgress = _progressByChapter.values.toList();
            _hasLoadedProgress = true;
            _progressUpdateController.add(_userProgress);
            _chapterProgressController.add(_progressByChapter);
            log('✅ Loaded ${_userProgress.length} progress entries from Hive');
          }
        }
      }

      // Load stats from Hive
      if (_statsBox != null) {
        final dynamic cachedStats = _statsBox!.get('user_${userId}_stats');
        if (cachedStats != null) {
          final Map<String, dynamic> convertedStats =
              _convertToMapString(cachedStats);
          if (convertedStats.isNotEmpty) {
            _overallStats = convertedStats;
            _hasLoadedOverall = true;
            _parseStatsFromMap();
            _overallStatsController.add(_overallStats);
            log('✅ Loaded stats from Hive');
            return;
          }
        }
      }

      // Try DeviceService cache
      log('Trying DeviceService cache');
      final cachedProgress =
          await deviceService.getCacheItem<Map<String, dynamic>>(
        AppConstants.allUserProgressKey,
        isUserSpecific: true,
      );

      if (cachedProgress != null) {
        final progressList = cachedProgress['progress'] as List? ?? [];
        _userProgress = [];
        for (final item in progressList) {
          try {
            Map<String, dynamic> safeMap;
            if (item is Map<String, dynamic>) {
              safeMap = item;
            } else if (item is Map) {
              // Convert _Map<dynamic,dynamic> to Map<String,dynamic>
              safeMap = {};
              item.forEach((k, v) {
                safeMap[k.toString()] = v;
              });
            } else {
              continue;
            }
            _userProgress.add(UserProgress.fromJson(safeMap));
          } catch (e) {
            log('Error parsing progress item: $e');
          }
        }
        _progressByChapter = {for (final p in _userProgress) p.chapterId: p};
        _hasLoadedProgress = true;
        _progressUpdateController.add(_userProgress);
        _chapterProgressController.add(_progressByChapter);
        await _saveProgressToHive();
      }

      final cachedStats =
          await deviceService.getCacheItem<Map<String, dynamic>>(
        AppConstants.overallStatsKey,
        isUserSpecific: true,
      );
      if (cachedStats != null) {
        _overallStats = _convertToMapString(cachedStats);
        _hasLoadedOverall = true;
        _parseStatsFromMap();
        _overallStatsController.add(_overallStats);
        await _saveStatsToHive();
      }

      if (!isOffline) {
        unawaited(_loadAllProgressFromApi());
      }
    } catch (e) {
      log('Error loading cached progress: $e');
      // Don't rethrow - just log the error and continue with empty data
    }
  }

  void _parseStatsFromMap() {
    if (_overallStats['achievements'] != null &&
        _overallStats['achievements'] is List) {
      _achievements = (_overallStats['achievements'] as List)
          .whereType<Map>()
          .map(_convertToMapString)
          .where((item) => item.isNotEmpty)
          .toList();
    }

    if (_overallStats['recent_activity'] != null &&
        _overallStats['recent_activity'] is List) {
      _recentActivity = (_overallStats['recent_activity'] as List)
          .whereType<Map>()
          .map(_convertToMapString)
          .where((item) => item.isNotEmpty)
          .toList();
    }

    if (_overallStats['streak_history'] != null &&
        _overallStats['streak_history'] is List) {
      _streakHistory = (_overallStats['streak_history'] as List)
          .map((date) => Parsers.parseDate(date) ?? DateTime.now())
          .toList();
    }
  }

  Future<void> _saveProgressToHive() async {
    try {
      final userId = await UserSession().getCurrentUserId();
      if (userId != null && _progressBox != null) {
        await _progressBox!.put('user_${userId}_progress', _progressByChapter);
        log('💾 Saved ${_userProgress.length} progress entries to Hive');
      }
    } catch (e) {
      log('Error saving progress to Hive: $e');
    }
  }

  Future<void> _saveStatsToHive() async {
    try {
      final userId = await UserSession().getCurrentUserId();
      if (userId != null && _statsBox != null) {
        await _statsBox!.put('user_${userId}_stats', _overallStats);
        log('💾 Saved stats to Hive');
      }
    } catch (e) {
      log('Error saving stats to Hive: $e');
    }
  }

  // ===== GETTERS =====
  List<UserProgress> get userProgress => List.unmodifiable(_userProgress);
  Map<String, dynamic> get overallStats => Map.unmodifiable(_overallStats);
  List<Map<String, dynamic>> get achievements =>
      List.unmodifiable(_achievements);
  List<Map<String, dynamic>> get recentActivity =>
      List.unmodifiable(_recentActivity);
  List<DateTime> get streakHistory => List.unmodifiable(_streakHistory);

  bool get hasLoadedOverall => _hasLoadedOverall;
  bool get hasLoadedProgress => _hasLoadedProgress;
  bool get isLoadingOverall => _isLoadingOverall;

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

  Future<void> _loadAllProgressFromApi() async {
    if (isOffline) return;
    await _ensureCurrentUserScope();
    if (_lastBackgroundRefresh != null &&
        DateTime.now().difference(_lastBackgroundRefresh!) <
            _minBackgroundInterval) {
      log('⏱️ Background refresh rate limited');
      return;
    }
    _lastBackgroundRefresh = DateTime.now();

    try {
      final response = await apiService.getOverallProgress();

      if (response.success && response.data != null) {
        _overallStats = _convertToMapString(response.data);
        _parseStatsFromMap();
        await _saveStatsToHive();
        deviceService.saveCacheItem(
          AppConstants.overallStatsKey,
          _overallStats,
          ttl: _cacheDuration,
          isUserSpecific: true,
        );
        _hasLoadedOverall = true;
        _overallStatsController.add(_overallStats);
        safeNotify();
        log('🔄 Background refresh complete');
      }
    } catch (e) {
      log('Error loading all progress: $e');
    }
  }

  Future<void> loadOverallProgress({
    bool forceRefresh = false,
    bool isManualRefresh = false,
  }) async {
    await _ensureCurrentUserScope();
    _apiCallCount++;
    final callId = _apiCallCount;

    log('loadOverallProgress() CALL #$callId');

    if (isManualRefresh && isOffline) {
      throw Exception(getUserFriendlyErrorMessage(
          'Network error. Please check your internet connection.'));
    }

    if (_hasLoadedOverall && !forceRefresh) {
      log('✅ Already have data, returning cached');
      setLoaded();
      _overallStatsController.add(_overallStats);
      return;
    }

    if (_isLoadingOverall && !forceRefresh) {
      log('⏳ Already loading, skipping');
      return;
    }

    _isLoadingOverall = true;
    setLoading();

    try {
      if (!forceRefresh) {
        log('STEP 1: Checking Hive cache');
        final userId = await UserSession().getCurrentUserId();
        if (userId != null && _statsBox != null) {
          final dynamic cachedStats = _statsBox!.get('user_${userId}_stats');
          if (cachedStats != null) {
            final Map<String, dynamic> convertedStats =
                _convertToMapString(cachedStats);
            if (convertedStats.isNotEmpty) {
              _overallStats = convertedStats;
              _hasLoadedOverall = true;
              _isLoadingOverall = false;
              setLoaded();
              _parseStatsFromMap();
              _overallStatsController.add(_overallStats);
              log('✅ Loaded stats from Hive');

              if (!isOffline && !isManualRefresh) {
                unawaited(_loadAllProgressFromApi());
              }
              return;
            }
          }
        }
      }

      if (!forceRefresh) {
        log('STEP 2: Checking DeviceService cache');
        final cachedStats =
            await deviceService.getCacheItem<Map<String, dynamic>>(
          AppConstants.overallStatsKey,
          isUserSpecific: true,
        );
        if (cachedStats != null) {
          _overallStats = _convertToMapString(cachedStats);
          _hasLoadedOverall = true;
          _isLoadingOverall = false;
          setLoaded();
          _parseStatsFromMap();
          _overallStatsController.add(_overallStats);
          log('✅ Loaded stats from DeviceService');
          await _saveStatsToHive();
          if (!isOffline && !isManualRefresh) {
            unawaited(_loadAllProgressFromApi());
          }
          return;
        }
      }

      if (isOffline) {
        log('STEP 3: Offline mode');
        if (_overallStats.isNotEmpty) {
          _hasLoadedOverall = true;
          _isLoadingOverall = false;
          setLoaded();
          _overallStatsController.add(_overallStats);
          log('✅ Showing cached progress offline');
          return;
        }

        setError(getUserFriendlyErrorMessage(
            'You are offline. No cached progress available.'));
        _setEmptyProgressData();
        _overallStatsController.add(_overallStats);
        _isLoadingOverall = false;
        setLoaded();

        if (isManualRefresh) {
          throw Exception(getUserFriendlyErrorMessage(
              'Network error. Please check your internet connection.'));
        }
        return;
      }

      log('STEP 4: Fetching from API');
      final response = await apiService.getOverallProgress();

      if (response.success && response.data != null) {
        _overallStats = _convertToMapString(response.data);
        _hasLoadedOverall = true;
        _isLoadingOverall = false;
        setLoaded();
        _parseStatsFromMap();
        log('✅ Received stats from API');
        await _saveStatsToHive();
        deviceService.saveCacheItem(
          AppConstants.overallStatsKey,
          _overallStats,
          ttl: _cacheDuration,
          isUserSpecific: true,
        );
        _overallStatsController.add(_overallStats);
        log('✅ Success! Overall progress loaded');
      } else {
        setError(getUserFriendlyErrorMessage(response.message));
        log('❌ API error: ${response.message}');
        final restoredFromCache = await _restoreOverallStatsFromCache();
        if (!restoredFromCache && !_hasLoadedOverall) {
          _setEmptyProgressData();
        }
        _hasLoadedOverall = true;
        _isLoadingOverall = false;
        setLoaded();
        _overallStatsController.add(_overallStats);

        if (isManualRefresh) {
          throw Exception(response.message);
        }
      }
    } catch (e) {
      log('❌ Error loading overall progress: $e');
      setError(getUserFriendlyErrorMessage(e));
      _isLoadingOverall = false;
      setLoaded();
      final restoredFromCache = await _restoreOverallStatsFromCache();
      if (!restoredFromCache && !_hasLoadedOverall) {
        _setEmptyProgressData();
      }
      _hasLoadedOverall = true;
      _overallStatsController.add(_overallStats);

      if (isManualRefresh) {
        rethrow;
      }
    } finally {
      safeNotify();
    }
  }

  void _setEmptyProgressData() {
    _overallStats = {
      'stats': {
        'total_chapters_attempted': 0,
        'chapters_completed': 0,
        'completion_percentage': 0,
        'total_available_chapters': 0,
        'overall_completion_percentage': 0,
        'total_questions_attempted': 0,
        'total_questions_correct': 0,
        'accuracy_percentage': 0.0,
        'total_notes_viewed': 0,
        'average_video_progress': 0.0,
        'videos_completed': 0,
        'study_time_hours': 0.0,
        'streak_count': 0,
        'last_streak_date': null,
        'exams_taken': 0,
        'exams_passed': 0,
        'average_exam_score': 0.0,
        'best_exam_score': 0.0,
      },
      'recent_activity': [],
      'streak_history': [],
      'achievements': [],
    };
    _achievements = [];
    _recentActivity = [];
    _streakHistory = [];
    _hasLoadedOverall = true;
  }

  Future<bool> _restoreOverallStatsFromCache() async {
    log('Attempting cache recovery for stats');
    try {
      final userId = await _ensureCurrentUserScope();
      if (userId != null && _statsBox != null) {
        final dynamic cachedStats = _statsBox!.get('user_${userId}_stats');
        if (cachedStats != null) {
          final Map<String, dynamic> convertedStats =
              _convertToMapString(cachedStats);
          if (convertedStats.isNotEmpty) {
            _overallStats = convertedStats;
            _hasLoadedOverall = true;
            _parseStatsFromMap();
            _overallStatsController.add(_overallStats);
            log('✅ Recovered stats from Hive');
            return true;
          }
        }
      }

      final cachedStats =
          await deviceService.getCacheItem<Map<String, dynamic>>(
        AppConstants.overallStatsKey,
        isUserSpecific: true,
      );
      if (cachedStats == null) return false;

      _overallStats = _convertToMapString(cachedStats);
      _hasLoadedOverall = true;
      _parseStatsFromMap();
      _overallStatsController.add(_overallStats);
      log('✅ Recovered stats from DeviceService');
      return true;
    } catch (e) {
      log('Error recovering stats: $e');
      return false;
    }
  }

  Future<void> saveChapterProgress({
    required int chapterId,
    int? videoProgress,
    bool? notesViewed,
    int? questionsAttempted,
    int? questionsCorrect,
  }) async {
    log('saveChapterProgress() for chapter $chapterId');

    try {
      await _ensureCurrentUserScope();
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
          safeNotify();

          if (!isOffline) {
            try {
              await apiService.saveUserProgress(
                chapterId: chapterId,
                videoProgress: newProgress.videoProgress,
                notesViewed: newProgress.notesViewed,
                questionsAttempted: newProgress.questionsAttempted,
                questionsCorrect: newProgress.questionsCorrect,
              );
              log('✅ Progress saved to API for chapter $chapterId');

              if (videoProgress != null ||
                  notesViewed == true ||
                  questionsAttempted != null) {
                await streakProvider.updateStreak();
              }

              await loadOverallProgress(forceRefresh: true);
              completer.complete();
            } catch (apiError) {
              log('⚠️ API error, queuing for later: $apiError');
              await _markAsPendingSync(chapterId, newProgress);
              completer.complete();
            }
          } else {
            log('📝 Offline, queuing progress for chapter $chapterId');
            await _markAsPendingSync(chapterId, newProgress);
            completer.complete();
          }
        } catch (e) {
          log('Error in debounced save: $e');
          completer.completeError(e);
        } finally {
          _pendingSaves.remove(chapterId);
          _saveDebounceTimers.remove(chapterId);
        }
      });

      return completer.future;
    } catch (e) {
      log('Error saving progress: $e');
      rethrow;
    }
  }

  Future<void> _saveToLocalCache(int chapterId, UserProgress progress) async {
    try {
      await _saveProgressToHive();

      final cacheKey = AppConstants.progressChapterKey(chapterId);
      deviceService.saveCacheItem(
        cacheKey,
        progress.toJson(),
        ttl: _cacheDuration,
        isUserSpecific: true,
      );

      const allProgressKey = AppConstants.allUserProgressKey;
      final allProgressData = {
        'progress': _userProgress.map((p) => p.toJson()).toList(),
        'last_updated': DateTime.now().toIso8601String(),
      };
      deviceService.saveCacheItem(
        allProgressKey,
        allProgressData,
        ttl: _cacheDuration,
        isUserSpecific: true,
      );

      log('✅ Progress saved to local cache');
    } catch (e) {
      log('Error saving to cache: $e');
    }
  }

  Future<void> _markAsPendingSync(int chapterId, UserProgress progress) async {
    try {
      final userId = await _ensureCurrentUserScope();
      if (userId == null) return;

      offlineQueueManager.addItem(
        type: AppConstants.queueActionSaveProgress,
        data: {
          'chapter_id': chapterId,
          'video_progress': progress.videoProgress,
          'notes_viewed': progress.notesViewed,
          'questions_attempted': progress.questionsAttempted,
          'questions_correct': progress.questionsCorrect,
          'userId': userId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      log('📝 Queued progress for chapter $chapterId');
    } catch (e) {
      log('Error marking pending sync: $e');
    }
  }

  @override
  Future<void> onBackgroundRefresh() async {
    log('Background refresh triggered');
    if (!isOffline && _hasLoadedOverall) {
      await _loadAllProgressFromApi();
    }
  }

  @override
  Future<void> onOnlineRefresh() async {
    log('Online - refreshing progress');
    await loadOverallProgress(forceRefresh: true);
  }

  Future<void> clearUserData() async {
    final session = UserSession();
    if (!session.shouldClearCacheOnLogout()) return;

    for (final timer in _saveDebounceTimers.values) {
      timer.cancel();
    }
    _saveDebounceTimers.clear();
    _pendingSaves.clear();
    _activeUserId = null;

    final userId = await session.getCurrentUserId();
    if (userId != null) {
      if (_progressBox != null) {
        await _progressBox!.delete('user_${userId}_progress');
      }
      if (_statsBox != null) {
        await _statsBox!.delete('user_${userId}_stats');
      }
    }

    await deviceService.clearCacheByPrefix('progress_');
    await deviceService.clearCacheByPrefix('pending_');
    stopBackgroundRefresh();
    _lastBackgroundRefresh = null;

    _userProgress = [];
    _progressByChapter = {};
    _overallStats = {};
    _achievements = [];
    _recentActivity = [];
    _streakHistory = [];
    _hasLoadedOverall = false;
    _hasLoadedProgress = false;
    _isLoadingOverall = false;

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

    safeNotify();
  }

  @override
  void dispose() {
    for (final timer in _saveDebounceTimers.values) {
      timer.cancel();
    }
    stopBackgroundRefresh();
    _progressUpdateController.close();
    _chapterProgressController.close();
    _overallStatsController.close();
    _progressBox?.close();
    _statsBox?.close();
    disposeSubscriptions();
    super.dispose();
  }
}

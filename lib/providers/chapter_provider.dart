// lib/providers/chapter_provider.dart
// PRODUCTION-READY FINAL VERSION - FIXED STREAM RECREATION

import 'dart:async';
import 'package:familyacademyclient/services/offline_queue_manager.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../services/user_session.dart';
import '../services/connectivity_service.dart';
import '../services/hive_service.dart';
import '../models/chapter_model.dart';
import '../utils/api_response.dart';
import '../utils/constants.dart';
import 'base_provider.dart';

class ChapterProvider extends ChangeNotifier
    with
        BaseProvider<ChapterProvider>,
        OfflineAwareProvider<ChapterProvider>,
        BackgroundRefreshMixin<ChapterProvider> {
  @override
  final ConnectivityService connectivityService;

  final ApiService apiService;
  final DeviceService deviceService;
  final HiveService hiveService;

  final Map<int, List<Chapter>> _chaptersByCourse = {};
  final Map<int, bool> _hasLoadedForCourse = {};
  final Map<int, bool> _isLoadingForCourse = {};

  static const Duration cacheDuration = AppConstants.cacheTTLChapters;
  @override
  Duration get refreshInterval => const Duration(minutes: 10);

  Box? _chaptersBox;
  int _apiCallCount = 0;

  // ✅ FIXED: Proper stream declaration with late
  late StreamController<Map<int, List<Chapter>>> _chaptersUpdateController;

  ChapterProvider({
    required this.apiService,
    required this.deviceService,
    required this.connectivityService,
    required this.hiveService,
  }) : _chaptersUpdateController =
            StreamController<Map<int, List<Chapter>>>.broadcast() {
    log('ChapterProvider constructor called');
    initializeOfflineAware(
      connectivity: connectivityService,
      queue: OfflineQueueManager(),
    );
    _init();
  }

  Future<void> _init() async {
    log('_init() START');
    await _openHiveBox();
    await _loadCachedDataForAll();

    if (_hasLoadedForCourse.isNotEmpty) {
      startBackgroundRefresh();
    }

    log('_init() END');
  }

  Future<void> _openHiveBox() async {
    try {
      if (!Hive.isBoxOpen(AppConstants.hiveChaptersBox)) {
        _chaptersBox =
            await Hive.openBox<dynamic>(AppConstants.hiveChaptersBox);
      } else {
        _chaptersBox = Hive.box<dynamic>(AppConstants.hiveChaptersBox);
      }
      log('✅ Hive box opened');
    } catch (e) {
      log('⚠️ Error opening Hive box: $e');
    }
  }

  Future<void> _loadCachedDataForAll() async {
    try {
      final userId = await UserSession().getCurrentUserId();
      if (userId == null || _chaptersBox == null) return;

      final cachedData = _chaptersBox!.get('user_${userId}_all_chapters');
      if (cachedData != null && cachedData is Map) {
        final Map<int, List<Chapter>> convertedMap = {};

        cachedData.forEach((key, value) {
          final int courseId = int.tryParse(key.toString()) ?? 0;
          if (courseId > 0 && value is List) {
            final List<Chapter> chapters = [];
            for (final item in value) {
              if (item is Chapter) {
                chapters.add(item);
              } else if (item is Map<String, dynamic>) {
                chapters.add(Chapter.fromJson(item));
              }
            }
            if (chapters.isNotEmpty) {
              convertedMap[courseId] = chapters;
            }
          }
        });

        _chaptersByCourse.addAll(convertedMap);
        for (final courseId in _chaptersByCourse.keys) {
          _hasLoadedForCourse[courseId] = true;
        }
        _chaptersUpdateController.add(_chaptersByCourse);
        log('✅ Loaded ${_chaptersByCourse.length} courses from Hive');
      }
    } catch (e) {
      log('Error loading cached data: $e');
    }
  }

  Future<void> _saveToHive() async {
    try {
      final userId = await UserSession().getCurrentUserId();
      if (userId != null && _chaptersBox != null) {
        await _chaptersBox!
            .put('user_${userId}_all_chapters', _chaptersByCourse);
        log('💾 Saved chapters to Hive');
      }
    } catch (e) {
      log('Error saving to Hive: $e');
    }
  }

  Future<void> _saveCourseToHive(int courseId, List<Chapter> chapters) async {
    try {
      final userId = await UserSession().getCurrentUserId();
      if (userId != null && _chaptersBox != null) {
        await _chaptersBox!.put(
            'user_${userId}_course_${courseId}_chapters', {courseId: chapters});
        await _saveToHive();
      }
    } catch (e) {
      log('Error saving course to Hive: $e');
    }
  }

  // ===== GETTERS =====
  Stream<Map<int, List<Chapter>>> get chaptersUpdates =>
      _chaptersUpdateController.stream;

  bool hasLoadedForCourse(int courseId) {
    return _hasLoadedForCourse[courseId] ?? false;
  }

  bool isLoadingForCourse(int courseId) {
    return _isLoadingForCourse[courseId] ?? false;
  }

  List<Chapter> getChaptersByCourse(int courseId) {
    return _chaptersByCourse[courseId] ?? [];
  }

  Chapter? getChapterById(int id) {
    for (final chapters in _chaptersByCourse.values) {
      try {
        return chapters.firstWhere((c) => c.id == id);
      } catch (e) {
        continue;
      }
    }
    return null;
  }

  // ===== LOAD CHAPTERS =====
  Future<void> loadChaptersByCourse(
    int courseId, {
    bool forceRefresh = false,
    bool isManualRefresh = false,
  }) async {
    _apiCallCount++;
    final callId = _apiCallCount;

    log('loadChaptersByCourse() CALL #$callId for course $courseId');

    if (isManualRefresh && isOffline) {
      throw Exception('Network error. Please check your internet connection.');
    }

    // Return cached data immediately if available
    if (_hasLoadedForCourse[courseId] == true && !forceRefresh) {
      log('✅ Already have data for course $courseId, returning cached');
      _chaptersUpdateController.add({courseId: _chaptersByCourse[courseId]!});
      setLoaded();
      return;
    }

    if (_isLoadingForCourse[courseId] == true && !forceRefresh) {
      log('⏳ Already loading course $courseId, waiting...');
      int attempts = 0;
      while (_isLoadingForCourse[courseId] == true && attempts < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }
      if (_hasLoadedForCourse[courseId] == true) {
        log('✅ Got chapters from existing load');
        _chaptersUpdateController.add({courseId: _chaptersByCourse[courseId]!});
        setLoaded();
        return;
      }
    }

    _isLoadingForCourse[courseId] = true;
    safeNotify();

    try {
      // STEP 1: Check memory cache first
      if (!forceRefresh && _chaptersByCourse.containsKey(courseId)) {
        log('STEP 1: Using memory cache for course $courseId');
        _hasLoadedForCourse[courseId] = true;
        _isLoadingForCourse[courseId] = false;
        setLoaded();
        _chaptersUpdateController.add({courseId: _chaptersByCourse[courseId]!});
        return;
      }

      // STEP 2: Try Hive cache
      if (!forceRefresh) {
        log('STEP 2: Checking Hive cache for course $courseId');
        final userId = await UserSession().getCurrentUserId();
        if (userId != null && _chaptersBox != null) {
          final cachedData =
              _chaptersBox!.get('user_${userId}_course_${courseId}_chapters');

          if (cachedData != null &&
              cachedData is Map &&
              cachedData[courseId] != null) {
            final dynamic chapterData = cachedData[courseId];
            if (chapterData is List) {
              final List<Chapter> chapters = [];
              for (final item in chapterData) {
                if (item is Chapter) {
                  chapters.add(item);
                } else if (item is Map<String, dynamic>) {
                  chapters.add(Chapter.fromJson(item));
                }
              }
              if (chapters.isNotEmpty) {
                _chaptersByCourse[courseId] = chapters;
                _hasLoadedForCourse[courseId] = true;
                _isLoadingForCourse[courseId] = false;
                setLoaded();
                _chaptersUpdateController.add({courseId: chapters});
                log('✅ Loaded ${chapters.length} chapters from Hive for course $courseId');

                if (!isOffline && !isManualRefresh) {
                  unawaited(_refreshInBackground(courseId));
                }
                return;
              }
            }
          }
        }
      }

      // STEP 3: Try DeviceService cache
      if (!forceRefresh) {
        log('STEP 3: Checking DeviceService cache for course $courseId');
        final cachedChapters = await deviceService.getCacheItem<List<dynamic>>(
          'chapters_course_$courseId',
          isUserSpecific: true,
        );

        if (cachedChapters != null && cachedChapters.isNotEmpty) {
          final List<Chapter> chapters = [];
          for (final json in cachedChapters) {
            if (json is Map<String, dynamic>) {
              chapters.add(Chapter.fromJson(json));
            }
          }

          if (chapters.isNotEmpty) {
            _chaptersByCourse[courseId] = chapters;
            _hasLoadedForCourse[courseId] = true;
            _isLoadingForCourse[courseId] = false;
            setLoaded();
            _chaptersUpdateController.add({courseId: chapters});

            await _saveCourseToHive(courseId, chapters);
            log('✅ Loaded ${chapters.length} chapters from DeviceService for course $courseId');

            if (!isOffline && !isManualRefresh) {
              unawaited(_refreshInBackground(courseId));
            }
            return;
          }
        }
      }

      // STEP 4: Check offline status
      if (isOffline) {
        log('STEP 4: Offline mode for course $courseId');
        if (_chaptersByCourse.containsKey(courseId)) {
          _hasLoadedForCourse[courseId] = true;
          _isLoadingForCourse[courseId] = false;
          setLoaded();
          _chaptersUpdateController
              .add({courseId: _chaptersByCourse[courseId]!});
          log('✅ Showing cached chapters offline for course $courseId');
          return;
        }

        _chaptersByCourse[courseId] = [];
        _hasLoadedForCourse[courseId] = true;
        _isLoadingForCourse[courseId] = false;
        setLoaded();
        _chaptersUpdateController.add({courseId: []});

        if (isManualRefresh) {
          throw Exception(
              'Network error. Please check your internet connection.');
        }
        return;
      }

      // STEP 5: Fetch from API with timeout
      log('STEP 5: Fetching from API for course $courseId');
      final response = await apiService.getChaptersByCourse(courseId).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          log('⏱️ API timeout for course $courseId');
          if (_chaptersByCourse.containsKey(courseId)) {
            log('✅ Using cached chapters due to timeout');
            _hasLoadedForCourse[courseId] = true;
            _isLoadingForCourse[courseId] = false;
            setLoaded();
            _chaptersUpdateController
                .add({courseId: _chaptersByCourse[courseId]!});
            return ApiResponse<List<Chapter>>(
              success: true,
              message: 'Using cached data',
              data: _chaptersByCourse[courseId],
            );
          }
          return ApiResponse<List<Chapter>>(
            success: false,
            message: 'Request timed out',
            data: [],
          );
        },
      );

      if (!response.success) {
        throw Exception(response.message);
      }

      final chapters = response.data ?? [];
      log('✅ Received ${chapters.length} chapters from API');

      _chaptersByCourse[courseId] = chapters;
      _hasLoadedForCourse[courseId] = true;
      _isLoadingForCourse[courseId] = false;
      setLoaded();

      await _saveCourseToHive(courseId, chapters);

      deviceService.saveCacheItem(
        'chapters_course_$courseId',
        chapters.map((c) => c.toJson()).toList(),
        ttl: cacheDuration,
        isUserSpecific: true,
      );

      _chaptersUpdateController.add({courseId: chapters});
      log('✅ Success! Chapters loaded for course $courseId');
    } catch (e) {
      log('❌ Error loading chapters: $e');

      if (!_chaptersByCourse.containsKey(courseId)) {
        await _recoverFromCache(courseId);
      }

      if (!_chaptersByCourse.containsKey(courseId)) {
        _chaptersByCourse[courseId] = [];
      }

      _hasLoadedForCourse[courseId] = true;
      _isLoadingForCourse[courseId] = false;
      setLoaded();
      _chaptersUpdateController.add({courseId: _chaptersByCourse[courseId]!});

      if (isManualRefresh) {
        rethrow;
      }
    } finally {
      safeNotify();
    }
  }

  // ✅ FIXED: Background refresh with rate limiting
  final Map<dynamic, dynamic> _lastBackgroundRefreshForCourse = {};
  static const Duration _minBackgroundInterval = Duration(minutes: 2);

  Future<void> _refreshInBackground(int courseId) async {
    // Rate limit background refreshes per course
    if (_lastBackgroundRefreshForCourse[courseId] != null &&
        DateTime.now().difference(_lastBackgroundRefreshForCourse[courseId]!) <
            _minBackgroundInterval) {
      log('⏱️ Background refresh rate limited for course $courseId');
      return;
    }
    _lastBackgroundRefreshForCourse[courseId] = DateTime.now();

    if (isOffline) return;

    try {
      final response = await apiService.getChaptersByCourse(courseId).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          log('⏱️ Background refresh timeout for course $courseId');
          return ApiResponse<List<Chapter>>(
            success: false,
            message: 'Timeout',
          );
        },
      );

      if (response.success && response.data != null) {
        final chapters = response.data!;

        _chaptersByCourse[courseId] = chapters;

        await _saveCourseToHive(courseId, chapters);

        deviceService.saveCacheItem(
          'chapters_course_$courseId',
          chapters.map((c) => c.toJson()).toList(),
          ttl: cacheDuration,
          isUserSpecific: true,
        );

        _chaptersUpdateController.add({courseId: chapters});
        safeNotify();
        log('🔄 Background refresh for course $courseId complete');
      }
    } catch (e) {
      log('Background refresh failed: $e');
    }
  }

  Future<void> _recoverFromCache(int courseId) async {
    log('Attempting cache recovery for course $courseId');
    final userId = await UserSession().getCurrentUserId();
    if (userId == null) return;

    if (_chaptersBox != null) {
      try {
        final cachedData =
            _chaptersBox!.get('user_${userId}_course_${courseId}_chapters');
        if (cachedData != null &&
            cachedData is Map &&
            cachedData[courseId] != null) {
          final dynamic chapterData = cachedData[courseId];
          if (chapterData is List) {
            final List<Chapter> chapters = [];
            for (final item in chapterData) {
              if (item is Chapter) {
                chapters.add(item);
              } else if (item is Map<String, dynamic>) {
                chapters.add(Chapter.fromJson(item));
              }
            }
            if (chapters.isNotEmpty) {
              _chaptersByCourse[courseId] = chapters;
              _hasLoadedForCourse[courseId] = true;
              _chaptersUpdateController.add({courseId: chapters});
              log('✅ Recovered ${chapters.length} chapters from Hive after error');
              return;
            }
          }
        }
      } catch (e) {
        log('Error recovering from Hive: $e');
      }
    }

    try {
      final cachedChapters = await deviceService.getCacheItem<List<dynamic>>(
        'chapters_course_$courseId',
        isUserSpecific: true,
      );
      if (cachedChapters != null && cachedChapters.isNotEmpty) {
        final List<Chapter> chapters = [];
        for (final json in cachedChapters) {
          if (json is Map<String, dynamic>) {
            chapters.add(Chapter.fromJson(json));
          }
        }

        if (chapters.isNotEmpty) {
          _chaptersByCourse[courseId] = chapters;
          _hasLoadedForCourse[courseId] = true;
          _chaptersUpdateController.add({courseId: chapters});
          log('✅ Recovered ${chapters.length} chapters from DeviceService after error');
        }
      }
    } catch (e) {
      log('Error recovering from DeviceService: $e');
    }
  }

  @override
  Future<void> onBackgroundRefresh() async {
    log('Background refresh triggered');
    if (isOffline) return;

    for (final courseId in _hasLoadedForCourse.keys) {
      if (_hasLoadedForCourse[courseId] == true &&
          !(_isLoadingForCourse[courseId] ?? false)) {
        unawaited(_refreshInBackground(courseId));
      }
    }
  }

  @override
  Future<void> onOnlineRefresh() async {
    log('Online - refreshing chapters');
    for (final courseId in _hasLoadedForCourse.keys) {
      if (_hasLoadedForCourse[courseId] == true) {
        await loadChaptersByCourse(courseId, forceRefresh: true);
      }
    }
  }

  // ✅ FIXED: Clear user data with proper stream recreation
  Future<void> clearUserData() async {
    final session = UserSession();
    if (!session.shouldClearCacheOnLogout()) return;

    final userId = await session.getCurrentUserId();
    if (userId != null && _chaptersBox != null) {
      final keysToDelete = _chaptersBox!.keys
          .where((key) => key.toString().contains('user_${userId}_'))
          .toList();
      for (final key in keysToDelete) {
        await _chaptersBox!.delete(key);
      }
    }

    await deviceService.clearCacheByPrefix('chapters_course_');
    _chaptersByCourse.clear();
    _hasLoadedForCourse.clear();
    _isLoadingForCourse.clear();
    _lastBackgroundRefreshForCourse.clear();
    stopBackgroundRefresh();

    // ✅ FIXED: Properly recreate stream controller
    await _chaptersUpdateController.close();
    _chaptersUpdateController =
        StreamController<Map<int, List<Chapter>>>.broadcast();
    _chaptersUpdateController.add({});

    safeNotify();
  }

  @override
  void dispose() {
    stopBackgroundRefresh();
    _chaptersUpdateController.close();
    _chaptersBox?.close();
    disposeSubscriptions();
    super.dispose();
  }
}

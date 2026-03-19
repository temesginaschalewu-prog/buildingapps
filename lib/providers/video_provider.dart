// lib/providers/video_provider.dart
// PRODUCTION-READY FINAL VERSION - WITH ALL FIXES

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../services/user_session.dart';
import '../services/connectivity_service.dart';
import '../services/hive_service.dart';
import '../services/offline_queue_manager.dart';
import '../models/video_model.dart';
import '../utils/constants.dart';
import '../utils/app_enums.dart';
import '../utils/helpers.dart';
import 'base_provider.dart';

/// PRODUCTION-READY Video Provider with Full Offline Support
class VideoProvider extends ChangeNotifier
    with
        BaseProvider<VideoProvider>,
        OfflineAwareProvider<VideoProvider>,
        BackgroundRefreshMixin<VideoProvider> {
  @override
  final ConnectivityService connectivityService;

  final ApiService apiService;
  final DeviceService deviceService;
  final HiveService hiveService;
  final OfflineQueueManager offlineQueueManager;
  final Dio _dio = Dio();

  // Video data storage
  final Map<int, List<Video>> _videosByChapter = {};
  final Map<int, bool> _hasLoadedForChapter = {};
  final Map<int, bool> _isLoadingForChapter = {};
  final Map<int, int> _videoViewCounts = {};
  final Map<int, DateTime> _lastLoadedTime = {};

  // Download management
  final Map<int, String> _downloadedVideoPaths = {};
  final Map<int, VideoQualityLevel> _downloadedQualities = {};
  final Map<int, bool> _isDownloading = {};
  final Map<int, double> _downloadProgress = {};
  final Map<int, CancelToken> _downloadCancelTokens = {};

  // Quality preferences
  final Map<int, String> _qualityPreferences = {};

  static const Duration _cacheDuration = AppConstants.cacheTTLVideos;
  static const Duration _downloadMetadataCache =
      AppConstants.cacheTTLDownloadMetadata;
  @override
  Duration get refreshInterval => const Duration(minutes: 5);

  Box? _videosBox;
  Box? _downloadsBox;
  Box? _qualityBox;

  int _apiCallCount = 0;

  // ✅ FIXED: Proper stream declaration
  late StreamController<Map<String, dynamic>> _videoUpdateController;

  // ✅ FIXED: Rate limiting
  final Map<int, DateTime?> _lastBackgroundRefreshForChapter = {};
  static const Duration _minBackgroundInterval = Duration(minutes: 2);

  VideoProvider({
    required this.apiService,
    required this.deviceService,
    required this.connectivityService,
    required this.hiveService,
    required this.offlineQueueManager,
  }) : _videoUpdateController =
            StreamController<Map<String, dynamic>>.broadcast() {
    log('VideoProvider constructor called');
    initializeOfflineAware(
      connectivity: connectivityService,
      queue: offlineQueueManager,
    );
    _init();
    _registerQueueProcessors();
  }

  void _registerQueueProcessors() {
    // Register processor for view count increments
    offlineQueueManager.registerProcessor(
      AppConstants.queueActionIncrementViewCount,
      _processViewCountIncrement,
    );
    log('✅ Registered queue processors');
  }

  Future<bool> _processViewCountIncrement(Map<String, dynamic> data) async {
    try {
      log('Processing offline view count increment');
      final videoId = data['video_id'];
      await apiService.incrementVideoViewCount(videoId);
      return true;
    } catch (e) {
      log('Error processing view count increment: $e');
      return false;
    }
  }

  Future<void> _init() async {
    log('_init() START');
    _initDio();
    await _openHiveBoxes();
    await _loadDownloadedVideos();
    await _loadQualityPreferences();

    if (_hasLoadedForChapter.isNotEmpty) {
      startBackgroundRefresh();
    }

    log('_init() END');
  }

  Future<void> _openHiveBoxes() async {
    try {
      if (!Hive.isBoxOpen(AppConstants.hiveVideosBox)) {
        _videosBox = await Hive.openBox<dynamic>(AppConstants.hiveVideosBox);
      } else {
        _videosBox = Hive.box<dynamic>(AppConstants.hiveVideosBox);
      }

      if (!Hive.isBoxOpen('downloads_box')) {
        _downloadsBox = await Hive.openBox<dynamic>('downloads_box');
      } else {
        _downloadsBox = Hive.box<dynamic>('downloads_box');
      }

      if (!Hive.isBoxOpen('quality_preferences_box')) {
        _qualityBox = await Hive.openBox<dynamic>('quality_preferences_box');
      } else {
        _qualityBox = Hive.box<dynamic>('quality_preferences_box');
      }

      log('✅ Hive boxes opened');
    } catch (e) {
      log('⚠️ Error opening Hive boxes: $e');
    }
  }

  void _initDio() {
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.sendTimeout = const Duration(seconds: 30);

    (_dio.httpClientAdapter as dynamic).onHttpClientCreate =
        (HttpClient client) {
      client.badCertificateCallback =
          (X509Certificate cert, String host, int port) {
        return true;
      };
      return client;
    };
  }

  // ===== GETTERS =====
  Stream<Map<String, dynamic>> get videoUpdates =>
      _videoUpdateController.stream;

  bool isVideoDownloaded(int videoId) {
    return _downloadedVideoPaths.containsKey(videoId);
  }

  bool isDownloading(int videoId) => _isDownloading[videoId] == true;

  double getDownloadProgress(int videoId) => _downloadProgress[videoId] ?? 0.0;

  String? getDownloadedVideoPath(int videoId) => _downloadedVideoPaths[videoId];

  VideoQualityLevel? getDownloadQuality(int videoId) =>
      _downloadedQualities[videoId];

  bool hasLoadedForChapter(int chapterId) =>
      _hasLoadedForChapter[chapterId] ?? false;

  bool isLoadingForChapter(int chapterId) =>
      _isLoadingForChapter[chapterId] ?? false;

  List<Video> getVideosByChapter(int chapterId) {
    return _videosByChapter[chapterId] ?? [];
  }

  Video? getVideoById(int id) {
    for (final videos in _videosByChapter.values) {
      try {
        return videos.firstWhere((v) => v.id == id);
      } catch (e) {
        continue;
      }
    }
    return null;
  }

  int getViewCount(int videoId) {
    return _videoViewCounts[videoId] ?? 0;
  }

  // ===== LOAD VIDEOS BY CHAPTER =====
  Future<void> loadVideosByChapter(
    int chapterId, {
    bool forceRefresh = false,
    bool isManualRefresh = false,
  }) async {
    _apiCallCount++;
    final callId = _apiCallCount;

    log('loadVideosByChapter() CALL #$callId for chapter $chapterId');

    if (isManualRefresh && isOffline) {
      throw Exception(getUserFriendlyErrorMessage(
          'Network error. Please check your internet connection.'));
    }

    // Return cached data immediately if available and not forcing refresh
    if (_hasLoadedForChapter[chapterId] == true && !forceRefresh) {
      log('✅ Already have data for chapter $chapterId, returning cached');
      _videoUpdateController.add({
        'type': 'videos_loaded_cached',
        'chapter_id': chapterId,
        'count': _videosByChapter[chapterId]?.length ?? 0,
      });
      return;
    }

    if (_isLoadingForChapter[chapterId] == true && !forceRefresh) {
      log('⏳ Already loading chapter $chapterId, skipping');
      return;
    }

    _isLoadingForChapter[chapterId] = true;
    safeNotify();

    try {
      // STEP 1: Try Hive cache first
      if (!forceRefresh) {
        log('STEP 1: Checking Hive cache for chapter $chapterId');
        final userId = await UserSession().getCurrentUserId();
        if (userId != null && _videosBox != null) {
          final cachedData =
              _videosBox!.get('user_${userId}_chapter_${chapterId}_videos');

          if (cachedData != null &&
              cachedData is Map &&
              cachedData[chapterId] != null) {
            final dynamic videoData = cachedData[chapterId];
            if (videoData is List) {
              final List<Video> videos = [];
              for (final item in videoData) {
                if (item is Video) {
                  videos.add(item);
                } else if (item is Map<String, dynamic>) {
                  videos.add(Video.fromJson(item));
                }
              }
              if (videos.isNotEmpty) {
                _videosByChapter[chapterId] = videos;
                _hasLoadedForChapter[chapterId] = true;
                _isLoadingForChapter[chapterId] = false;
                _lastLoadedTime[chapterId] = DateTime.now();

                for (final video in videos) {
                  _videoViewCounts[video.id] = video.viewCount;
                }

                _videoUpdateController.add({
                  'type': 'videos_loaded_cached',
                  'chapter_id': chapterId,
                  'count': videos.length,
                });

                log('✅ Loaded ${videos.length} videos from Hive for chapter $chapterId');

                // Only refresh in background if we're online and not manually refreshing
                // But return immediately to avoid shimering
                if (!isOffline && !isManualRefresh) {
                  unawaited(_refreshInBackground(chapterId));
                }

                // CRITICAL: Return immediately after loading from cache to avoid shimering
                return;
              }
            }
          }
        }
      }

      // STEP 2: Try DeviceService
      if (!forceRefresh) {
        log('STEP 2: Checking DeviceService cache for chapter $chapterId');
        final cached = await deviceService.getCacheItem<List<dynamic>>(
          AppConstants.videosByChapterKey(chapterId),
          isUserSpecific: true,
        );

        if (cached != null && cached.isNotEmpty) {
          final List<Video> videos = [];
          for (final json in cached) {
            if (json is Map<String, dynamic>) {
              videos.add(Video.fromJson(json));
            }
          }

          if (videos.isNotEmpty) {
            _videosByChapter[chapterId] = videos;
            _hasLoadedForChapter[chapterId] = true;
            _isLoadingForChapter[chapterId] = false;
            _lastLoadedTime[chapterId] = DateTime.now();

            for (final video in videos) {
              _videoViewCounts[video.id] = video.viewCount;
            }

            await _saveChapterToHive(chapterId, videos);

            _videoUpdateController.add({
              'type': 'videos_loaded_cached',
              'chapter_id': chapterId,
              'count': videos.length,
            });

            log('✅ Loaded ${videos.length} videos from DeviceService for chapter $chapterId');

            if (!isOffline && !isManualRefresh) {
              unawaited(_refreshInBackground(chapterId));
            }
            return;
          }
        }
      }

      // STEP 3: Check offline status
      if (isOffline) {
        log('STEP 3: Offline mode for chapter $chapterId');
        if (_videosByChapter.containsKey(chapterId)) {
          _hasLoadedForChapter[chapterId] = true;
          _isLoadingForChapter[chapterId] = false;
          _videoUpdateController.add({
            'type': 'videos_loaded',
            'chapter_id': chapterId,
            'count': _videosByChapter[chapterId]!.length,
          });
          log('✅ Showing cached videos offline for chapter $chapterId');
          return;
        }

        if (isManualRefresh) {
          throw Exception(getUserFriendlyErrorMessage(
              'Network error. Please check your internet connection.'));
        }

        _videosByChapter[chapterId] = [];
        _hasLoadedForChapter[chapterId] = true;
        _isLoadingForChapter[chapterId] = false;
        _videoUpdateController.add({
          'type': 'videos_loaded',
          'chapter_id': chapterId,
          'count': 0,
        });
        return;
      }

      // STEP 4: Fetch from API
      log('STEP 4: Fetching from API for chapter $chapterId');
      final response = await apiService.getVideosByChapter(chapterId);

      if (!response.success) {
        throw Exception(response.message);
      }

      final videos = response.data ?? [];
      log('✅ Received ${videos.length} videos from API');

      _videosByChapter[chapterId] = videos;
      _hasLoadedForChapter[chapterId] = true;
      _isLoadingForChapter[chapterId] = false;
      _lastLoadedTime[chapterId] = DateTime.now();

      for (final video in videos) {
        _videoViewCounts[video.id] = video.viewCount;
      }

      await _saveChapterToHive(chapterId, videos);

      deviceService.saveCacheItem(
        AppConstants.videosByChapterKey(chapterId),
        videos.map((v) => v.toJson()).toList(),
        ttl: _cacheDuration,
        isUserSpecific: true,
      );

      _videoUpdateController.add({
        'type': 'videos_loaded',
        'chapter_id': chapterId,
        'count': videos.length,
      });

      log('✅ Success! Videos loaded for chapter $chapterId');
    } catch (e, stackTrace) {
      log('❌ Error loading videos: $e');

      setError(getUserFriendlyErrorMessage(e));

      if (!_hasLoadedForChapter.containsKey(chapterId)) {
        await _recoverFromCache(chapterId);
      }

      _videosByChapter[chapterId] = _videosByChapter[chapterId] ?? [];
      _hasLoadedForChapter[chapterId] = true;
      _isLoadingForChapter[chapterId] = false;
      _videoUpdateController.add({
        'type': 'videos_loaded',
        'chapter_id': chapterId,
        'count': _videosByChapter[chapterId]!.length,
      });

      if (isManualRefresh) {
        rethrow;
      }
    } finally {
      safeNotify();
    }
  }

  Future<void> _saveChapterToHive(int chapterId, List<Video> videos) async {
    try {
      final userId = await UserSession().getCurrentUserId();
      if (userId != null && _videosBox != null) {
        final chapterMap = {chapterId: videos};
        await _videosBox!
            .put('user_${userId}_chapter_${chapterId}_videos', chapterMap);
      }
    } catch (e) {
      log('Error saving chapter to Hive: $e');
    }
  }

  // ✅ FIXED: Rate limited background refresh
  Future<void> _refreshInBackground(int chapterId) async {
    if (isOffline) return;

    // Rate limiting
    if (_lastBackgroundRefreshForChapter[chapterId] != null &&
        DateTime.now()
                .difference(_lastBackgroundRefreshForChapter[chapterId]!) <
            _minBackgroundInterval) {
      log('⏱️ Background refresh rate limited for chapter $chapterId');
      return;
    }
    _lastBackgroundRefreshForChapter[chapterId] = DateTime.now();

    try {
      final response = await apiService.getVideosByChapter(chapterId);
      if (response.success && response.data != null) {
        final videos = response.data!;

        _videosByChapter[chapterId] = videos;
        _lastLoadedTime[chapterId] = DateTime.now();

        for (final video in videos) {
          _videoViewCounts[video.id] = video.viewCount;
        }

        await _saveChapterToHive(chapterId, videos);

        deviceService.saveCacheItem(
          AppConstants.videosByChapterKey(chapterId),
          videos.map((v) => v.toJson()).toList(),
          ttl: _cacheDuration,
          isUserSpecific: true,
        );

        _videoUpdateController.add({
          'type': 'videos_refreshed',
          'chapter_id': chapterId,
          'count': videos.length,
        });

        log('🔄 Background refresh for chapter $chapterId complete');
      }
    } catch (e) {
      log('Background refresh error: $e');
    }
  }

  Future<void> _recoverFromCache(int chapterId) async {
    log('Attempting cache recovery for chapter $chapterId');
    final userId = await UserSession().getCurrentUserId();
    if (userId == null) return;

    // Try Hive first
    if (_videosBox != null) {
      try {
        final cachedData =
            _videosBox!.get('user_${userId}_chapter_${chapterId}_videos');
        if (cachedData != null &&
            cachedData is Map &&
            cachedData[chapterId] != null) {
          final dynamic videoData = cachedData[chapterId];
          if (videoData is List) {
            final List<Video> videos = [];
            for (final item in videoData) {
              if (item is Video) {
                videos.add(item);
              } else if (item is Map<String, dynamic>) {
                videos.add(Video.fromJson(item));
              }
            }
            if (videos.isNotEmpty) {
              _videosByChapter[chapterId] = videos;
              _hasLoadedForChapter[chapterId] = true;
              _lastLoadedTime[chapterId] = DateTime.now();
              _videoUpdateController.add({
                'type': 'videos_loaded_cached',
                'chapter_id': chapterId,
                'count': videos.length,
              });
              log('✅ Recovered ${videos.length} videos from Hive after error');
              return;
            }
          }
        }
      } catch (e) {
        log('Error recovering from Hive: $e');
      }
    }

    // Try DeviceService
    try {
      final cached = await deviceService.getCacheItem<List<dynamic>>(
        AppConstants.videosByChapterKey(chapterId),
        isUserSpecific: true,
      );
      if (cached != null && cached.isNotEmpty) {
        final List<Video> videos = [];
        for (final json in cached) {
          if (json is Map<String, dynamic>) {
            videos.add(Video.fromJson(json));
          }
        }

        if (videos.isNotEmpty) {
          _videosByChapter[chapterId] = videos;
          _hasLoadedForChapter[chapterId] = true;
          _lastLoadedTime[chapterId] = DateTime.now();
          _videoUpdateController.add({
            'type': 'videos_loaded_cached',
            'chapter_id': chapterId,
            'count': videos.length,
          });
          log('✅ Recovered ${videos.length} videos from DeviceService after error');
        }
      }
    } catch (e) {
      log('Error recovering from DeviceService: $e');
    }
  }

  // ===== VIEW COUNT METHODS =====
  Future<void> incrementViewCount(int videoId) async {
    log('incrementViewCount() for video $videoId');

    try {
      if (isOffline) {
        // Queue for later
        offlineQueueManager.addItem(
          type: AppConstants.queueActionIncrementViewCount,
          data: {
            'video_id': videoId,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
        log('📝 Queued view count for video $videoId');
        return;
      }

      await apiService.incrementVideoViewCount(videoId);

      final newCount = (_videoViewCounts[videoId] ?? 0) + 1;
      _videoViewCounts[videoId] = newCount;

      _videoUpdateController.add({
        'type': 'view_count_updated',
        'video_id': videoId,
        'view_count': newCount
      });

      log('✅ View count incremented for video $videoId');
    } catch (e) {
      log('Error incrementing view count: $e');
    }
  }

  // ===== QUALITY PREFERENCE METHODS =====
  Future<void> saveQualityPreference(int videoId, String qualityLabel) async {
    try {
      _qualityPreferences[videoId] = qualityLabel;

      if (_qualityBox != null) {
        final prefsMap = _qualityBox!.get('quality_preferences') ?? {};
        prefsMap[videoId.toString()] = qualityLabel;
        await _qualityBox!.put('quality_preferences', prefsMap);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('video_quality_$videoId', qualityLabel);

      log('💾 Saved quality preference: $qualityLabel for video $videoId');
    } catch (e) {
      log('Error saving quality preference: $e');
    }
  }

  Future<String?> getQualityPreference(int videoId) async {
    if (_qualityPreferences.containsKey(videoId)) {
      return _qualityPreferences[videoId];
    }

    try {
      if (_qualityBox != null) {
        final prefsMap = _qualityBox!.get('quality_preferences');
        if (prefsMap != null && prefsMap[videoId.toString()] != null) {
          final pref = prefsMap[videoId.toString()].toString();
          _qualityPreferences[videoId] = pref;
          return pref;
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final pref = prefs.getString('video_quality_$videoId');
      if (pref != null) {
        _qualityPreferences[videoId] = pref;

        if (_qualityBox != null) {
          final prefsMap = _qualityBox!.get('quality_preferences') ?? {};
          prefsMap[videoId.toString()] = pref;
          await _qualityBox!.put('quality_preferences', prefsMap);
        }
      }
      return pref;
    } catch (e) {
      log('Error getting quality preference: $e');
      return null;
    }
  }

  Future<void> _loadQualityPreferences() async {
    try {
      if (_qualityBox != null) {
        final prefsMap = _qualityBox!.get('quality_preferences');
        if (prefsMap != null) {
          prefsMap.forEach((key, value) {
            final videoId = int.tryParse(key.toString());
            if (videoId != null) {
              _qualityPreferences[videoId] = value.toString();
            }
          });
          log('✅ Loaded ${_qualityPreferences.length} quality prefs from Hive');
        }
      }
    } catch (e) {
      log('Error loading quality preferences: $e');
    }
  }

  // ===== DOWNLOAD METHODS =====
  Future<void> _loadDownloadedVideos() async {
    try {
      if (_downloadsBox != null) {
        final paths = _downloadsBox!.get('downloaded_paths');
        if (paths != null && paths is Map) {
          paths.forEach((key, value) {
            final id = int.tryParse(key.toString());
            final videoPath = value?.toString();
            if (id != null && videoPath != null) {
              _downloadedVideoPaths[id] = videoPath;
            }
          });
        }

        final qualities = _downloadsBox!.get('downloaded_qualities');
        if (qualities != null && qualities is Map) {
          qualities.forEach((key, value) {
            final id = int.tryParse(key.toString());
            final qualityKey = value?.toString();
            if (id != null && qualityKey != null) {
              switch (qualityKey) {
                case 'low':
                  _downloadedQualities[id] = VideoQualityLevel.low;
                  break;
                case 'medium':
                  _downloadedQualities[id] = VideoQualityLevel.medium;
                  break;
                case 'high':
                  _downloadedQualities[id] = VideoQualityLevel.high;
                  break;
                case 'highest':
                  _downloadedQualities[id] = VideoQualityLevel.highest;
                  break;
              }
            }
          });
        }
        log('📂 Loaded ${_downloadedVideoPaths.length} downloaded videos from Hive');
        return;
      }

      // Fallback to DeviceService
      final paths = await deviceService.getCacheItem<Map<String, dynamic>>(
        AppConstants.downloadedVideosKey,
        isUserSpecific: true,
      );

      if (paths != null) {
        paths.forEach((key, value) {
          final id = int.tryParse(key);
          final videoPath = value as String?;
          if (id != null && videoPath != null) {
            _downloadedVideoPaths[id] = videoPath;
          }
        });
      }

      final qualities = await deviceService.getCacheItem<Map<String, dynamic>>(
        AppConstants.downloadQualitiesKey,
        isUserSpecific: true,
      );

      if (qualities != null) {
        qualities.forEach((key, value) {
          final id = int.tryParse(key);
          final qualityKey = value as String?;
          if (id != null && qualityKey != null) {
            switch (qualityKey) {
              case 'low':
                _downloadedQualities[id] = VideoQualityLevel.low;
                break;
              case 'medium':
                _downloadedQualities[id] = VideoQualityLevel.medium;
                break;
              case 'high':
                _downloadedQualities[id] = VideoQualityLevel.high;
                break;
              case 'highest':
                _downloadedQualities[id] = VideoQualityLevel.highest;
                break;
            }
          }
        });
      }

      log('📂 Loaded ${_downloadedVideoPaths.length} downloaded videos from DeviceService');
    } catch (e) {
      log('Error loading downloads: $e');
    }
  }

  Future<void> _saveDownloadMetadata() async {
    try {
      final paths = <String, String>{};
      for (final entry in _downloadedVideoPaths.entries) {
        paths[entry.key.toString()] = entry.value;
      }

      final qualities = <String, String>{};
      for (final entry in _downloadedQualities.entries) {
        String key = '';
        switch (entry.value.height) {
          case 360:
            key = 'low';
            break;
          case 480:
            key = 'medium';
            break;
          case 720:
            key = 'high';
            break;
          case 1080:
            key = 'highest';
            break;
          default:
            key = 'medium';
        }
        qualities[entry.key.toString()] = key;
      }

      if (_downloadsBox != null) {
        await _downloadsBox!.put('downloaded_paths', paths);
        await _downloadsBox!.put('downloaded_qualities', qualities);
      }

      deviceService.saveCacheItem(
        AppConstants.downloadedVideosKey,
        paths,
        isUserSpecific: true,
        ttl: _downloadMetadataCache,
      );

      deviceService.saveCacheItem(
        AppConstants.downloadQualitiesKey,
        qualities,
        isUserSpecific: true,
        ttl: _downloadMetadataCache,
      );

      log('💾 Saved download metadata');
    } catch (e) {
      log('Error saving metadata: $e');
    }
  }

  void updateDownloadProgress(
      int videoId, double progress, int received, int total) {
    if (progress >= 1.0) {
      _isDownloading[videoId] = false;
    }
    _downloadProgress[videoId] = progress;
    _videoUpdateController.add({
      'type': 'download_progress',
      'video_id': videoId,
      'progress': progress,
      'received': received,
      'total': total,
    });
    safeNotify();
  }

  void setDownloadState(int videoId, bool isDownloading, double progress) {
    _isDownloading[videoId] = isDownloading;
    if (isDownloading) {
      _downloadProgress[videoId] = progress;
    } else {
      _downloadProgress.remove(videoId);
    }
    _videoUpdateController.add({
      'type': isDownloading ? 'download_started' : 'download_state_changed',
      'video_id': videoId,
      'is_downloading': isDownloading,
      'progress': progress,
    });
    safeNotify();
  }

  void setDownloadedVideoPath(
      int videoId, String filePath, VideoQualityLevel quality) {
    _downloadedVideoPaths[videoId] = filePath;
    _downloadedQualities[videoId] = quality;
    _isDownloading[videoId] = false;
    _downloadProgress.remove(videoId);
    _videoUpdateController.add({
      'type': 'video_downloaded',
      'video_id': videoId,
      'file_path': filePath,
      'quality': quality.label,
    });
    safeNotify();
    _saveDownloadMetadata();
  }

  void cancelDownload(int videoId) {
    if (_downloadCancelTokens.containsKey(videoId)) {
      _downloadCancelTokens[videoId]!.cancel();
      _downloadCancelTokens.remove(videoId);
    }
    _isDownloading[videoId] = false;
    _downloadProgress.remove(videoId);
    _videoUpdateController.add({
      'type': 'download_cancelled',
      'video_id': videoId,
      'is_downloading': false,
      'progress': 0.0,
    });
    safeNotify();
  }

  Future<void> removeDownloadedVideo(int videoId) async {
    log('removeDownloadedVideo() for video $videoId');

    final path = _downloadedVideoPaths[videoId];
    if (path != null) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
          log('🗑️ Deleted file for video $videoId');
        }
      } catch (e) {
        log('Error deleting file: $e');
      }
    }

    _downloadedVideoPaths.remove(videoId);
    _downloadedQualities.remove(videoId);
    await _saveDownloadMetadata();

    _videoUpdateController.add({
      'type': 'video_removed',
      'video_id': videoId,
    });
    safeNotify();
  }

  Future<void> clearAllDownloads() async {
    log('clearAllDownloads()');

    try {
      int count = 0;
      for (final path in _downloadedVideoPaths.values) {
        try {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
            count++;
          }
        } catch (e) {
          log('Error deleting file: $e');
        }
      }
      log('🗑️ Cleared $count downloaded files');
    } catch (e) {
      log('Error clearing downloads: $e');
    }

    _downloadedVideoPaths.clear();
    _downloadedQualities.clear();
    await _saveDownloadMetadata();

    _videoUpdateController.add({'type': 'all_downloads_cleared'});
    safeNotify();
  }

  @override
  Future<void> onBackgroundRefresh() async {
    log('Background refresh triggered');
    if (isOffline) return;

    for (final chapterId in _hasLoadedForChapter.keys) {
      if (_hasLoadedForChapter[chapterId] == true &&
          !(_isLoadingForChapter[chapterId] ?? false)) {
        unawaited(_refreshInBackground(chapterId));
      }
    }
  }

  @override
  Future<void> onOnlineRefresh() async {
    log('Online - refreshing videos');
    for (final chapterId in _hasLoadedForChapter.keys) {
      if (_hasLoadedForChapter[chapterId] == true) {
        await loadVideosByChapter(chapterId, forceRefresh: true);
      }
    }
  }

  // ✅ FIXED: Clear user data with proper stream recreation
  Future<void> clearUserData() async {
    final session = UserSession();
    if (!session.shouldClearCacheOnLogout()) return;

    final userId = await session.getCurrentUserId();
    if (userId != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_view_counts_$userId');

      if (_qualityBox != null) {
        await _qualityBox!.delete('quality_preferences');
      }

      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith('video_quality_')) {
          await prefs.remove(key);
        }
      }
      _qualityPreferences.clear();

      if (_videosBox != null) {
        final keysToDelete = _videosBox!.keys
            .where((key) => key.toString().contains('user_${userId}_'))
            .toList();
        for (final key in keysToDelete) {
          await _videosBox!.delete(key);
        }
      }
    }

    await deviceService.clearCacheByPrefix('videos_');
    await deviceService.clearCacheByPrefix('video_view_');

    _videosByChapter.clear();
    _hasLoadedForChapter.clear();
    _isLoadingForChapter.clear();
    _videoViewCounts.clear();
    _lastLoadedTime.clear();
    _lastBackgroundRefreshForChapter.clear();
    stopBackgroundRefresh();

    // FIX: Properly recreate stream controller
    await _videoUpdateController.close();
    _videoUpdateController = StreamController<Map<String, dynamic>>.broadcast();
    _videoUpdateController.add({'type': 'all_videos_cleared'});

    safeNotify();
  }

  @override
  void clearError() {
    super.clearError();
  }

  @override
  void dispose() {
    for (final token in _downloadCancelTokens.values) {
      token.cancel();
    }
    _downloadCancelTokens.clear();
    stopBackgroundRefresh();
    _videoUpdateController.close();
    _videosBox?.close();
    _downloadsBox?.close();
    _qualityBox?.close();
    _dio.close();
    disposeSubscriptions();
    super.dispose();
  }
}

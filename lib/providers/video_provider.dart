import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../services/user_session.dart';
import '../models/video_model.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'package:dio/dio.dart';

enum VideoQualityLevel {
  low(360, '360p'),
  medium(480, '480p'),
  high(720, '720p'),
  highest(1080, '1080p');

  final int height;
  final String label;
  const VideoQualityLevel(this.height, this.label);
}

class VideoProvider with ChangeNotifier {
  final ApiService apiService;
  final DeviceService deviceService;
  final Dio _dio = Dio();

  // State
  final List<Video> _videos = [];
  final Map<int, List<Video>> _videosByChapter = {};
  final Map<int, bool> _hasLoadedForChapter = {};
  final Map<int, bool> _isLoadingForChapter = {};
  final Map<int, int> _videoViewCounts = {};

  // Download management - SINGLE source of truth
  final Map<int, String> _downloadedVideoPaths = {};
  final Map<int, VideoQualityLevel> _downloadedQualities = {};
  final Map<int, bool> _isDownloading = {};
  final Map<int, double> _downloadProgress = {};

  final StreamController<Map<String, dynamic>> _videoUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();

  bool _isLoading = false;
  String? _error;

  static const Duration _cacheDuration = Duration(minutes: 10);
  static const Duration _downloadMetadataCache = Duration(days: 30);

  VideoProvider({required this.apiService, required this.deviceService}) {
    _initDio();
    _loadDownloadedVideos(); // Load from DeviceService only
  }

  // Getters
  List<Video> get videos => List.unmodifiable(_videos);
  bool get isLoading => _isLoading;
  String? get error => _error;
  Stream<Map<String, dynamic>> get videoUpdates =>
      _videoUpdateController.stream;

  bool isVideoDownloaded(int videoId) =>
      _downloadedVideoPaths.containsKey(videoId);
  bool isDownloading(int videoId) => _isDownloading[videoId] == true;
  double getDownloadProgress(int videoId) => _downloadProgress[videoId] ?? 0.0;
  VideoQualityLevel? getDownloadQuality(int videoId) =>
      _downloadedQualities[videoId];
  String? getDownloadedVideoPath(int videoId) => _downloadedVideoPaths[videoId];

  bool hasLoadedForChapter(int chapterId) =>
      _hasLoadedForChapter[chapterId] ?? false;
  bool isLoadingForChapter(int chapterId) =>
      _isLoadingForChapter[chapterId] ?? false;
  List<Video> getVideosByChapter(int chapterId) =>
      List.unmodifiable(_videosByChapter[chapterId] ?? []);

  void _initDio() {
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.sendTimeout = const Duration(seconds: 30);
  }

  /// Load downloaded videos metadata from DeviceService (SINGLE source)
  Future<void> _loadDownloadedVideos() async {
    try {
      final paths = await deviceService.getCacheItem<Map<String, dynamic>>(
        AppConstants.downloadedVideosKey,
        isUserSpecific: true,
      );

      if (paths != null) {
        for (final entry in paths.entries) {
          final id = int.tryParse(entry.key);
          final videoPath = entry.value as String?;
          if (id != null && videoPath != null) {
            final file = File(videoPath);
            if (await file.exists()) {
              _downloadedVideoPaths[id] = videoPath;
            }
          }
        }
      }

      final qualities = await deviceService.getCacheItem<Map<String, dynamic>>(
        AppConstants.downloadQualitiesKey,
        isUserSpecific: true,
      );

      if (qualities != null) {
        for (final entry in qualities.entries) {
          final id = int.tryParse(entry.key);
          final key = entry.value as String?;
          if (id != null && key != null) {
            switch (key) {
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
        }
      }

      debugLog('VideoProvider',
          'Loaded ${_downloadedVideoPaths.length} downloaded videos');
    } catch (e) {
      debugLog('VideoProvider', 'Error loading downloads: $e');
    }
  }

  /// Save download metadata to DeviceService
  Future<void> _saveDownloadMetadata() async {
    try {
      final paths = <String, String>{};
      for (final entry in _downloadedVideoPaths.entries) {
        paths[entry.key.toString()] = entry.value;
      }

      final qualities = <String, String>{};
      for (final entry in _downloadedQualities.entries) {
        String key = '';
        switch (entry.value) {
          case VideoQualityLevel.low:
            key = 'low';
            break;
          case VideoQualityLevel.medium:
            key = 'medium';
            break;
          case VideoQualityLevel.high:
            key = 'high';
            break;
          case VideoQualityLevel.highest:
            key = 'highest';
            break;
        }
        qualities[entry.key.toString()] = key;
      }

      await deviceService.saveCacheItem(
        AppConstants.downloadedVideosKey,
        paths,
        isUserSpecific: true,
        ttl: _downloadMetadataCache,
      );

      await deviceService.saveCacheItem(
        AppConstants.downloadQualitiesKey,
        qualities,
        isUserSpecific: true,
        ttl: _downloadMetadataCache,
      );
    } catch (e) {
      debugLog('VideoProvider', 'Error saving metadata: $e');
    }
  }

  /// Load videos for a chapter (uses SINGLE endpoint)
  Future<void> loadVideosByChapter(int chapterId,
      {bool forceRefresh = false}) async {
    if (_isLoadingForChapter[chapterId] == true) return;

    // Check cache
    if (!forceRefresh && _hasLoadedForChapter[chapterId] == true) {
      return;
    }

    _isLoadingForChapter[chapterId] = true;
    _error = null;
    notifyListeners();

    try {
      debugLog('VideoProvider', 'Loading videos for chapter: $chapterId');

      // SINGLE endpoint: /chapters/$chapterId/videos
      final response = await apiService.getVideosByChapter(chapterId);

      if (!response.success) {
        throw Exception(response.message);
      }

      final responseData = response.data;
      final videosData = responseData?['videos'] ?? [];

      final list = <Video>[];
      for (final json in videosData) {
        try {
          final video = Video.fromJson(json);
          list.add(video);
          _videoViewCounts[video.id] = video.viewCount;
        } catch (e) {
          debugLog('VideoProvider', 'Error parsing video: $e');
        }
      }

      _videosByChapter[chapterId] = list;
      _hasLoadedForChapter[chapterId] = true;

      // Update global videos list
      for (final video in list) {
        if (!_videos.any((v) => v.id == video.id)) {
          _videos.add(video);
        }
      }

      // Cache in DeviceService only
      await deviceService.saveCacheItem(
        AppConstants.videosByChapterKey(chapterId),
        list.map((v) => v.toJson()).toList(),
        ttl: _cacheDuration,
        isUserSpecific: true,
      );

      _videoUpdateController.add({
        'type': 'videos_loaded',
        'chapter_id': chapterId,
        'count': list.length
      });

      debugLog('VideoProvider',
          'Loaded ${list.length} videos for chapter $chapterId');
    } catch (e) {
      _error = e.toString();
      debugLog('VideoProvider', 'Error loading videos: $e');

      // Try cache
      final cached = await deviceService.getCacheItem<List<dynamic>>(
        AppConstants.videosByChapterKey(chapterId),
        isUserSpecific: true,
      );

      if (cached != null) {
        final list = <Video>[];
        for (final json in cached) {
          try {
            list.add(Video.fromJson(json));
          } catch (e) {
            debugLog('VideoProvider', 'Error loading downloaded videos: $e');
          }
        }
        _videosByChapter[chapterId] = list;
        _hasLoadedForChapter[chapterId] = true;

        _videoUpdateController.add({
          'type': 'videos_loaded_cached',
          'chapter_id': chapterId,
          'count': list.length
        });
      } else {
        _videosByChapter[chapterId] = [];
      }
    } finally {
      _isLoadingForChapter[chapterId] = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Download video with specific quality
  Future<void> downloadVideo(
      Video video, VideoQualityLevel quality, CancelToken cancelToken) async {
    if (_isDownloading[video.id] == true) return;

    // Get quality-specific URL
    String? qualityUrl;
    switch (quality) {
      case VideoQualityLevel.low:
        qualityUrl = video.getQualityUrl('low');
        break;
      case VideoQualityLevel.medium:
        qualityUrl = video.getQualityUrl('medium');
        break;
      case VideoQualityLevel.high:
        qualityUrl = video.getQualityUrl('high');
        break;
      case VideoQualityLevel.highest:
        qualityUrl = video.getQualityUrl('highest');
        break;
    }

    if (qualityUrl == null) {
      throw Exception('Quality not available for this video');
    }

    _isDownloading[video.id] = true;
    _downloadProgress[video.id] = 0.0;
    _downloadedQualities[video.id] = quality;
    notifyListeners();

    try {
      final cacheDir = await _getCacheDirectory();
      final fileName =
          'v${video.id}_${quality.height}_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final filePath = '${cacheDir.path}/$fileName';

      debugLog(
          'VideoProvider', 'Downloading video ${video.id} at ${quality.label}');

      await _dio.download(
        qualityUrl,
        filePath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            _downloadProgress[video.id] = received / total;
            notifyListeners();
          }
        },
      );

      final file = File(filePath);
      if (!await file.exists()) throw Exception('Download failed');

      _downloadedVideoPaths[video.id] = filePath;
      _isDownloading[video.id] = false;
      _downloadProgress.remove(video.id);
      await _saveDownloadMetadata();

      _videoUpdateController.add({
        'type': 'video_downloaded',
        'video_id': video.id,
        'quality': quality.label,
      });

      debugLog('VideoProvider', 'Download complete for video ${video.id}');
      notifyListeners();
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        debugLog('VideoProvider', 'Download cancelled');
      } else {
        debugLog('VideoProvider', 'Download error: $e');
      }
      _isDownloading[video.id] = false;
      _downloadProgress.remove(video.id);
      _downloadedQualities.remove(video.id);
      notifyListeners();
      rethrow;
    }
  }

  /// Remove downloaded video
  Future<void> removeDownload(int videoId) async {
    final path = _downloadedVideoPaths[videoId];
    if (path != null) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
          debugLog('VideoProvider', 'Deleted file for video $videoId');
        }
      } catch (e) {
        debugLog('VideoProvider', 'Error deleting file: $e');
      }
    }

    _downloadedVideoPaths.remove(videoId);
    _downloadedQualities.remove(videoId);
    await _saveDownloadMetadata();

    _videoUpdateController.add({
      'type': 'video_removed',
      'video_id': videoId,
    });

    notifyListeners();
  }

  /// Clear all downloaded videos
  Future<void> clearAllDownloads() async {
    try {
      for (final path in _downloadedVideoPaths.values) {
        try {
          final file = File(path);
          if (await file.exists()) await file.delete();
        } catch (e) {
          debugLog('VideoProvider', 'Error parsing cached video: $e');
        }
      }
    } catch (e) {
      debugLog('VideoProvider', 'Error in catch block: $e');
    }

    _downloadedVideoPaths.clear();
    _downloadedQualities.clear();
    await _saveDownloadMetadata();

    _videoUpdateController.add({'type': 'all_downloads_cleared'});
    notifyListeners();
  }

  Future<Directory> _getCacheDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${dir.path}/.cache/videos');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  Video? getVideoById(int id) {
    try {
      return _videos.firstWhere((v) => v.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Increment view count when video is watched
  Future<void> incrementViewCount(int videoId) async {
    try {
      debugLog('VideoProvider', 'Incrementing view count for video: $videoId');
      await apiService.incrementVideoViewCount(videoId);

      final index = _videos.indexWhere((v) => v.id == videoId);
      if (index != -1) {
        final video = _videos[index];
        final newCount = (_videoViewCounts[videoId] ?? video.viewCount) + 1;
        _videoViewCounts[videoId] = newCount;

        _videos[index] = Video(
          id: video.id,
          title: video.title,
          chapterId: video.chapterId,
          filePath: video.filePath,
          fileSize: video.fileSize,
          duration: video.duration,
          thumbnailUrl: video.thumbnailUrl,
          releaseDate: video.releaseDate,
          viewCount: newCount,
          createdAt: video.createdAt,
          qualities: video.qualities,
          hasQualities: video.hasQualities,
        );

        for (final chapterVideos in _videosByChapter.values) {
          final idx = chapterVideos.indexWhere((v) => v.id == videoId);
          if (idx != -1) chapterVideos[idx] = _videos[index];
        }

        _videoUpdateController.add({
          'type': 'view_count_updated',
          'video_id': videoId,
          'view_count': newCount
        });

        notifyListeners();
      }
    } catch (e) {
      debugLog('VideoProvider', 'Error incrementing view count: $e');
    }
  }

  int getViewCount(int videoId) {
    return _videoViewCounts[videoId] ?? 0;
  }

  /// 🔵 FIX: Clear user data ONLY for different user logout
  Future<void> clearUserData() async {
    debugLog('VideoProvider', 'Clearing user data');

    // Only clear if this is a different user logout
    final session = UserSession();
    final isDifferentUser = !await session.isSameUser();
    final isLoggingOut = await _isLoggingOut();

    if (!isDifferentUser || !isLoggingOut) {
      debugLog('VideoProvider', '✅ Same user - preserving video cache');
      return;
    }

    await deviceService.clearCacheByPrefix('videos_');
    await deviceService.clearCacheByPrefix('video_view_');

    _videos.clear();
    _videosByChapter.clear();
    _hasLoadedForChapter.clear();
    _isLoadingForChapter.clear();
    _videoViewCounts.clear();

    // Keep downloads (user might want to keep them after logout)
    // If you want to clear downloads on logout, uncomment:
    // await clearAllDownloads();

    _videoUpdateController.add({'type': 'all_videos_cleared'});
    notifyListeners();
  }

  Future<bool> _isLoggingOut() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.isLoggingOutKey) ?? false;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _videoUpdateController.close();
    _dio.close();
    super.dispose();
  }
}

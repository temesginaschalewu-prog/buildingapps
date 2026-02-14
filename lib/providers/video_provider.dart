import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../models/video_model.dart';
import '../utils/helpers.dart';

class VideoProvider with ChangeNotifier {
  final ApiService apiService;
  final DeviceService deviceService;

  List<Video> _videos = [];
  Map<int, List<Video>> _videosByChapter = {};
  Map<int, bool> _hasLoadedForChapter = {};
  Map<int, bool> _isLoadingForChapter = {};
  Map<int, DateTime> _lastLoadedTime = {};
  Map<int, int> _videoViewCounts = {};
  bool _isLoading = false;
  String? _error;

  StreamController<Map<String, dynamic>> _videoUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();

  static const Duration cacheDuration = Duration(minutes: 10);

  static const Duration viewCountCacheDuration = Duration(minutes: 30);

  VideoProvider({required this.apiService, required this.deviceService});

  List<Video> get videos => _videos;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Stream<Map<String, dynamic>> get videoUpdates =>
      _videoUpdateController.stream;

  bool hasLoadedForChapter(int chapterId) =>
      _hasLoadedForChapter[chapterId] ?? false;
  bool isLoadingForChapter(int chapterId) =>
      _isLoadingForChapter[chapterId] ?? false;

  List<Video> getVideosByChapter(int chapterId) {
    return _videosByChapter[chapterId] ?? [];
  }

  Future<void> loadVideosByChapter(int chapterId,
      {bool forceRefresh = false}) async {
    if (_isLoadingForChapter[chapterId] == true) {
      return;
    }

    final lastLoaded = _lastLoadedTime[chapterId];
    final hasCache = _hasLoadedForChapter[chapterId] == true;
    final isCacheValid = lastLoaded != null &&
        DateTime.now().difference(lastLoaded) < cacheDuration;

    if (hasCache && !forceRefresh && isCacheValid) {
      debugLog(
          'VideoProvider', '✅ Using cached videos for chapter: $chapterId');
      return;
    }

    _isLoadingForChapter[chapterId] = true;
    _error = null;
    notifyListeners();

    try {
      debugLog('VideoProvider', '🎥 Loading videos for chapter: $chapterId');
      final response = await apiService.getVideosByChapter(chapterId);

      final responseData = response.data ?? {};
      final videosData = responseData['videos'] ?? [];

      if (videosData is List) {
        final videoList = <Video>[];
        for (var videoJson in videosData) {
          try {
            final video = Video.fromJson(videoJson);
            videoList.add(video);

            _videoViewCounts[video.id] = video.viewCount;
          } catch (e) {
            debugLog(
                'VideoProvider', 'Error parsing video: $e, data: $videoJson');
          }
        }

        _videosByChapter[chapterId] = videoList;
        _hasLoadedForChapter[chapterId] = true;
        _lastLoadedTime[chapterId] = DateTime.now();

        for (final video in videoList) {
          if (!_videos.any((v) => v.id == video.id)) {
            _videos.add(video);
          }
        }

        await deviceService.saveCacheItem(
          'videos_chapter_$chapterId',
          videoList.map((v) => v.toJson()).toList(),
          ttl: cacheDuration,
        );

        debugLog('VideoProvider',
            '✅ Loaded ${videoList.length} videos for chapter $chapterId');

        _videoUpdateController.add({
          'type': 'videos_loaded',
          'chapter_id': chapterId,
          'count': videoList.length
        });
      } else {
        _videosByChapter[chapterId] = [];
        _hasLoadedForChapter[chapterId] = true;
        _lastLoadedTime[chapterId] = DateTime.now();
      }
    } catch (e) {
      _error = e.toString();
      debugLog('VideoProvider', '❌ loadVideosByChapter error: $e');

      try {
        final cachedVideos = await deviceService
            .getCacheItem<List<dynamic>>('videos_chapter_$chapterId');
        if (cachedVideos != null) {
          final videoList = <Video>[];
          for (var videoJson in cachedVideos) {
            try {
              videoList.add(Video.fromJson(videoJson));
            } catch (e) {}
          }
          _videosByChapter[chapterId] = videoList;
          _hasLoadedForChapter[chapterId] = true;
          _lastLoadedTime[chapterId] = DateTime.now();
        }
      } catch (cacheError) {
        debugLog('VideoProvider', 'Cache load error: $cacheError');
      }

      if (!_hasLoadedForChapter[chapterId]!) {
        _videosByChapter[chapterId] = [];
      }
    } finally {
      _isLoadingForChapter[chapterId] = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  Video? getVideoById(int id) {
    try {
      return _videos.firstWhere((v) => v.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> incrementViewCount(int videoId) async {
    try {
      debugLog('VideoProvider', '📊 incrementViewCount for videoId:$videoId');

      await apiService.incrementVideoViewCount(videoId);

      final index = _videos.indexWhere((v) => v.id == videoId);
      if (index != -1) {
        final video = _videos[index];
        final newViewCount = (_videoViewCounts[videoId] ?? video.viewCount) + 1;
        _videoViewCounts[videoId] = newViewCount;

        _videos[index] = Video(
          id: video.id,
          title: video.title,
          chapterId: video.chapterId,
          filePath: video.filePath,
          fileSize: video.fileSize,
          duration: video.duration,
          thumbnailUrl: video.thumbnailUrl,
          releaseDate: video.releaseDate,
          viewCount: newViewCount,
          createdAt: video.createdAt,
        );

        for (final chapterId in _videosByChapter.keys) {
          final videos = _videosByChapter[chapterId];
          if (videos != null) {
            final videoIndex = videos.indexWhere((v) => v.id == videoId);
            if (videoIndex != -1) {
              videos[videoIndex] = _videos[index];
            }
          }
        }

        await deviceService.saveCacheItem(
          'video_view_$videoId',
          newViewCount,
          ttl: viewCountCacheDuration,
        );

        _videoUpdateController.add({
          'type': 'view_count_updated',
          'video_id': videoId,
          'view_count': newViewCount
        });

        notifyListeners();
      }
    } catch (e) {
      debugLog('VideoProvider', '❌ incrementViewCount error: $e');

      final index = _videos.indexWhere((v) => v.id == videoId);
      if (index != -1) {
        final video = _videos[index];
        final newViewCount = (_videoViewCounts[videoId] ?? video.viewCount) + 1;
        _videoViewCounts[videoId] = newViewCount;

        _videos[index] = Video(
          id: video.id,
          title: video.title,
          chapterId: video.chapterId,
          filePath: video.filePath,
          fileSize: video.fileSize,
          duration: video.duration,
          thumbnailUrl: video.thumbnailUrl,
          releaseDate: video.releaseDate,
          viewCount: newViewCount,
          createdAt: video.createdAt,
        );

        notifyListeners();
      }
    }
  }

  int getViewCount(int videoId) {
    return _videoViewCounts[videoId] ?? 0;
  }

  Future<void> clearUserData() async {
    debugLog('VideoProvider', 'Clearing video data');

    await deviceService.clearCacheByPrefix('videos_');
    await deviceService.clearCacheByPrefix('video_view_');

    _videos.clear();
    _videosByChapter.clear();
    _hasLoadedForChapter.clear();
    _lastLoadedTime.clear();
    _isLoadingForChapter.clear();
    _videoViewCounts.clear();

    _videoUpdateController.close();
    _videoUpdateController = StreamController<Map<String, dynamic>>.broadcast();

    _videoUpdateController.add({'type': 'all_videos_cleared'});

    notifyListeners();
  }

  Future<void> clearVideosForChapter(int chapterId) async {
    _hasLoadedForChapter.remove(chapterId);
    _lastLoadedTime.remove(chapterId);

    final chapterVideos = _videosByChapter[chapterId] ?? [];
    _videos.removeWhere((video) => chapterVideos.any((v) => v.id == video.id));
    _videosByChapter.remove(chapterId);

    await deviceService.removeCacheItem('videos_chapter_$chapterId');

    _videoUpdateController
        .add({'type': 'videos_cleared', 'chapter_id': chapterId});

    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _videoUpdateController.close();
    super.dispose();
  }
}

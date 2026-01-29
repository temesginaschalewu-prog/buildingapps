import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/video_model.dart';
import '../utils/helpers.dart';

class VideoProvider with ChangeNotifier {
  final ApiService apiService;

  List<Video> _videos = [];
  Map<int, List<Video>> _videosByChapter = {};
  Map<int, bool> _hasLoadedForChapter = {};
  Map<int, bool> _isLoadingForChapter = {};
  Map<int, DateTime> _lastLoadedTime = {};
  bool _isLoading = false;
  String? _error;

  // Cache duration: 10 minutes (videos don't change often)
  static const Duration cacheDuration = Duration(minutes: 10);

  VideoProvider({required this.apiService});

  List<Video> get videos => _videos;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool hasLoadedForChapter(int chapterId) =>
      _hasLoadedForChapter[chapterId] ?? false;
  bool isLoadingForChapter(int chapterId) =>
      _isLoadingForChapter[chapterId] ?? false;

  List<Video> getVideosByChapter(int chapterId) {
    return _videosByChapter[chapterId] ?? [];
  }

  Future<void> loadVideosByChapter(int chapterId,
      {bool forceRefresh = false}) async {
    // Check if already loading for this chapter
    if (_isLoadingForChapter[chapterId] == true) {
      return;
    }

    // Check cache
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
            videoList.add(Video.fromJson(videoJson));
          } catch (e) {
            debugLog(
                'VideoProvider', 'Error parsing video: $e, data: $videoJson');
          }
        }

        // Update cache
        _videosByChapter[chapterId] = videoList;
        _hasLoadedForChapter[chapterId] = true;
        _lastLoadedTime[chapterId] = DateTime.now();

        // Add to global list, avoiding duplicates
        for (final video in videoList) {
          if (!_videos.any((v) => v.id == video.id)) {
            _videos.add(video);
          }
        }

        debugLog('VideoProvider',
            '✅ Loaded ${videoList.length} videos for chapter $chapterId');
      } else {
        _videosByChapter[chapterId] = [];
        _hasLoadedForChapter[chapterId] = true;
        _lastLoadedTime[chapterId] = DateTime.now();
      }
    } catch (e) {
      _error = e.toString();
      debugLog('VideoProvider', '❌ loadVideosByChapter error: $e');

      // If we have cache, keep it even if refresh fails
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
        _videos[index] = Video(
          id: video.id,
          title: video.title,
          chapterId: video.chapterId,
          filePath: video.filePath,
          fileSize: video.fileSize,
          duration: video.duration,
          thumbnailUrl: video.thumbnailUrl,
          releaseDate: video.releaseDate,
          viewCount: video.viewCount + 1,
          createdAt: video.createdAt,
        );
        notifyListeners();
      }
    } catch (e) {
      debugLog('VideoProvider', '❌ incrementViewCount error: $e');
    }
  }

  // Clear cache for specific chapter
  void clearVideosForChapter(int chapterId) {
    _hasLoadedForChapter.remove(chapterId);
    _lastLoadedTime.remove(chapterId);

    // Remove videos for this chapter from global list
    final chapterVideos = _videosByChapter[chapterId] ?? [];
    _videos.removeWhere((video) => chapterVideos.any((v) => v.id == video.id));
    _videosByChapter.remove(chapterId);

    notifyListeners();
  }

  // Clear all cache
  void clearAllVideos() {
    _videos.clear();
    _videosByChapter.clear();
    _hasLoadedForChapter.clear();
    _lastLoadedTime.clear();
    _isLoadingForChapter.clear();
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

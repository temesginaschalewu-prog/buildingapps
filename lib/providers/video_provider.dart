import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../models/video_model.dart';
import '../utils/helpers.dart';

class VideoProvider with ChangeNotifier {
  final ApiService apiService;

  List<Video> _videos = [];
  Map<int, List<Video>> _videosByChapter = {};
  bool _isLoading = false;
  String? _error;

  VideoProvider({required this.apiService});

  List<Video> get videos => _videos;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Video> getVideosByChapter(int chapterId) {
    return _videosByChapter[chapterId] ?? [];
  }

  Future<void> loadVideosByChapter(int chapterId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugLog('VideoProvider', 'Loading videos for chapter: $chapterId');
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
        _videosByChapter[chapterId] = videoList;
      } else {
        _videosByChapter[chapterId] = [];
      }

      _videos = [..._videos, ..._videosByChapter[chapterId]!];

      debugLog('VideoProvider',
          'Loaded ${_videosByChapter[chapterId]!.length} videos for chapter $chapterId');
    } catch (e) {
      _error = e.toString();
      debugLog('VideoProvider', 'loadVideosByChapter error: $e');
      _videosByChapter[chapterId] = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Video? getVideoById(int id) {
    return _videos.firstWhere((v) => v.id == id);
  }

  Future<void> incrementViewCount(int videoId) async {
    try {
      debugLog('VideoProvider', 'incrementViewCount for videoId:$videoId');

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
      debugLog('VideoProvider', 'incrementViewCount error: $e');
    }
  }

  void clearVideos() {
    _videos = [];
    _videosByChapter = {};
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

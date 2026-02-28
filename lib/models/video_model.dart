import 'package:familyacademyclient/utils/constants.dart';

class VideoQuality {
  final String label;
  final String url;
  final int height;
  final bool isAvailable;

  const VideoQuality({
    required this.label,
    required this.url,
    required this.height,
    this.isAvailable = true,
  });

  factory VideoQuality.fromJson(String key, String url) {
    switch (key) {
      case 'low':
        return VideoQuality(label: '360p', url: url, height: 360);
      case 'medium':
        return VideoQuality(label: '480p', url: url, height: 480);
      case 'high':
        return VideoQuality(label: '720p', url: url, height: 720);
      case 'highest':
        return VideoQuality(label: '1080p', url: url, height: 1080);
      default:
        return VideoQuality(label: '480p', url: url, height: 480);
    }
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'url': url,
        'height': height,
        'isAvailable': isAvailable,
      };
}

class Video {
  final int id;
  final String title;
  final int chapterId;
  final String filePath;
  final int fileSize;
  final int duration;
  final String? thumbnailUrl;
  final DateTime? releaseDate;
  final int viewCount;
  final DateTime createdAt;
  final Map<String, VideoQuality>? qualities;
  final bool hasQualities;

  const Video({
    required this.id,
    required this.title,
    required this.chapterId,
    required this.filePath,
    required this.fileSize,
    required this.duration,
    this.thumbnailUrl,
    this.releaseDate,
    required this.viewCount,
    required this.createdAt,
    this.qualities,
    this.hasQualities = false,
  });

  factory Video.fromJson(Map<String, dynamic> json) {
    Map<String, VideoQuality>? qualities;
    final hasQualities = json['has_qualities'] == true;

    if (hasQualities && json['qualities'] != null) {
      qualities = {};
      final qualitiesJson = json['qualities'] as Map<String, dynamic>;
      qualitiesJson.forEach((key, value) {
        if (value is String) {
          qualities![key] = VideoQuality.fromJson(key, value);
        }
      });
    }

    return Video(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      title: json['title']?.toString() ?? '',
      chapterId: json['chapter_id'] is int
          ? json['chapter_id']
          : int.tryParse(json['chapter_id']?.toString() ?? '0') ?? 0,
      filePath: json['file_path']?.toString() ?? '',
      fileSize: json['file_size'] is int
          ? json['file_size']
          : int.tryParse(json['file_size']?.toString() ?? '0') ?? 0,
      duration: json['duration'] is int
          ? json['duration']
          : int.tryParse(json['duration']?.toString() ?? '0') ?? 0,
      thumbnailUrl: json['thumbnail_url']?.toString(),
      releaseDate: json['release_date'] != null
          ? DateTime.parse(json['release_date'].toString())
          : null,
      viewCount: json['view_count'] is int
          ? json['view_count']
          : int.tryParse(json['view_count']?.toString() ?? '0') ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      qualities: qualities,
      hasQualities: hasQualities,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {
      'id': id,
      'title': title,
      'chapter_id': chapterId,
      'file_path': filePath,
      'file_size': fileSize,
      'duration': duration,
      'view_count': viewCount,
      'created_at': createdAt.toIso8601String(),
      'has_qualities': hasQualities,
    };

    if (thumbnailUrl != null) {
      json['thumbnail_url'] = thumbnailUrl;
    }

    if (releaseDate != null) {
      json['release_date'] = releaseDate!.toIso8601String();
    }

    if (qualities != null) {
      json['qualities'] =
          qualities!.map((key, value) => MapEntry(key, value.url));
    }

    return json;
  }

  /// FIXED: Get quality URL with proper extension
  String? getQualityUrl(String qualityName) {
    if (qualities?[qualityName]?.url != null) {
      String url = qualities![qualityName]!.url;

      // Ensure URL has proper format for Cloudinary
      if (url.contains('cloudinary.com') &&
          !url.contains('.mp4') &&
          !url.contains('.m3u8')) {
        // Add .mp4 extension if missing
        if (url.contains('?')) {
          final parts = url.split('?');
          url = parts[0] + '.mp4?' + parts[1];
        } else {
          url = url + '.mp4';
        }
      }

      // Ensure proper encoding
      try {
        final uri = Uri.parse(url);
        return uri.toString();
      } catch (e) {
        return url;
      }
    }
    return null;
  }

  /// FIXED: Get full video URL with proper extension
  String get fullVideoUrl {
    if (filePath.isEmpty) return '';

    // Handle already full URLs
    if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
      String url = filePath;

      // Fix Cloudinary URLs missing extension
      if (url.contains('cloudinary.com') &&
          !url.contains('.mp4') &&
          !url.contains('.m3u8')) {
        if (url.contains('?')) {
          final parts = url.split('?');
          url = parts[0] + '.mp4?' + parts[1];
        } else {
          url = url + '.mp4';
        }
      }

      return url;
    }

    if (filePath.startsWith('res.cloudinary.com')) {
      String url = 'https://$filePath';
      if (!url.contains('.mp4') && !url.contains('.m3u8')) {
        if (url.contains('?')) {
          final parts = url.split('?');
          url = parts[0] + '.mp4?' + parts[1];
        } else {
          url = url + '.mp4';
        }
      }
      return url;
    }

    final baseUrl = AppConstants.baseUrl.replaceAll('/api/v1', '');
    final cleanPath =
        filePath.startsWith('/') ? filePath.substring(1) : filePath;

    if (cleanPath.contains('uploads/')) {
      return '$baseUrl/$cleanPath';
    }

    return '$baseUrl/uploads/videos/$cleanPath';
  }

  List<VideoQuality> get availableQualities {
    if (qualities != null && qualities!.isNotEmpty) {
      final list = qualities!.values.toList();
      list.sort((a, b) => a.height.compareTo(b.height));
      return list;
    }
    return [VideoQuality(label: '480p', url: fullVideoUrl, height: 480)];
  }

  VideoQuality getRecommendedQuality([String? connectionType]) {
    final available = availableQualities;
    if (available.isEmpty) {
      return VideoQuality(label: '480p', url: fullVideoUrl, height: 480);
    }

    if (connectionType == 'mobile') {
      for (final q in available) {
        if (q.height <= 480) return q;
      }
      return available.first;
    }

    for (final q in available.reversed) {
      if (q.height >= 720) return q;
    }
    return available.last;
  }

  VideoQuality? get bestQuality {
    if (qualities == null || qualities!.isEmpty) return null;
    return qualities!.values.reduce((a, b) => a.height > b.height ? a : b);
  }

  String? get fullThumbnailUrl {
    if (thumbnailUrl == null || thumbnailUrl!.isEmpty) return null;

    if (thumbnailUrl!.startsWith('http://') ||
        thumbnailUrl!.startsWith('https://')) {
      return thumbnailUrl;
    }

    if (thumbnailUrl!.startsWith('res.cloudinary.com')) {
      return 'https://$thumbnailUrl';
    }

    final baseUrl = AppConstants.baseUrl.replaceAll('/api/v1', '');
    final cleanPath = thumbnailUrl!.startsWith('/')
        ? thumbnailUrl!.substring(1)
        : thumbnailUrl!;

    if (cleanPath.contains('uploads/')) {
      return '$baseUrl/$cleanPath';
    }

    return '$baseUrl/uploads/thumbnails/$cleanPath';
  }

  bool get hasThumbnail => fullThumbnailUrl != null;

  String get formattedDuration {
    final hours = duration ~/ 3600;
    final minutes = (duration % 3600) ~/ 60;
    final seconds = duration % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  int estimatedSizeForQuality(String quality) {
    final minutes = duration / 60;
    switch (quality) {
      case 'low':
        return (minutes * 3 * 1024 * 1024).round();
      case 'medium':
        return (minutes * 5 * 1024 * 1024).round();
      case 'high':
        return (minutes * 8 * 1024 * 1024).round();
      case 'highest':
        return (minutes * 12 * 1024 * 1024).round();
      default:
        return fileSize;
    }
  }
}

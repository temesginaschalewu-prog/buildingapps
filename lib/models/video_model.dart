import '../utils/parsers.dart';

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
      id: Parsers.parseInt(json['id']),
      title: json['title']?.toString() ?? '',
      chapterId: Parsers.parseInt(json['chapter_id']),
      filePath: json['file_path']?.toString() ?? '',
      fileSize: Parsers.parseInt(json['file_size']),
      duration: Parsers.parseInt(json['duration']),
      thumbnailUrl: json['thumbnail_url']?.toString(),
      releaseDate: Parsers.parseDate(json['release_date']),
      viewCount: Parsers.parseInt(json['view_count']),
      createdAt: Parsers.parseDate(json['created_at']) ?? DateTime.now(),
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

    if (thumbnailUrl != null) json['thumbnail_url'] = thumbnailUrl;
    if (releaseDate != null) {
      json['release_date'] = releaseDate!.toIso8601String();
    }
    if (qualities != null) {
      json['qualities'] =
          qualities!.map((key, value) => MapEntry(key, value.url));
    }

    return json;
  }

  String _normalizeUrl(String url) {
    if (url.isEmpty) return url;

    String normalized = url;

    normalized = normalized.replaceAllMapped(RegExp(r'(https?:)\/\/+'),
        (match) => match[1] == 'https:' ? 'https://' : 'http://');

    normalized = normalized.replaceAllMapped(RegExp(r'(https?:)\/+'),
        (match) => match[1] == 'https:' ? 'https://' : 'http://');

    normalized = normalized.replaceAllMapped(
        RegExp(r'([^:])\/\/(?!/)'), (match) => '${match[1]}/');

    normalized = normalized.replaceAll(RegExp(r'(?<!https?:)\/\/'), '/');

    if (normalized.startsWith('/') || normalized.startsWith('./')) {
      return 'file://$normalized';
    }

    if (normalized.contains('/Documents/.familyacademy_cache/')) {
      return 'file://${normalized.replaceFirst('https://', '').replaceFirst('http://', '')}';
    }

    if (normalized.contains('dsros0pyh.res.cloudinary.com')) {
      normalized = normalized.replaceAll(
          'dsros0pyh.res.cloudinary.com', 'res.cloudinary.com/dsros0pyh');
    }

    if (normalized.startsWith('res.cloudinary.com')) {
      normalized = 'https://$normalized';
    }

    if (normalized.startsWith('https:///')) {
      normalized = normalized.replaceFirst('https:///', 'https://');
    }
    if (normalized.startsWith('http:///')) {
      normalized = normalized.replaceFirst('http:///', 'http://');
    }

    return normalized;
  }

  String? getQualityUrl(String qualityName) {
    if (qualities?[qualityName]?.url == null) return null;
    return _normalizeUrl(qualities![qualityName]!.url);
  }

  String get fullVideoUrl {
    if (filePath.isEmpty) return '';
    return _normalizeUrl(filePath);
  }

  VideoQuality getRecommendedQuality([String? connectionType]) {
    final available = availableQualities;

    if (available.isEmpty) {
      return VideoQuality(label: '480p', url: fullVideoUrl, height: 480);
    }

    try {
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
    } catch (e) {
      return available.isNotEmpty
          ? available.first
          : VideoQuality(label: '480p', url: fullVideoUrl, height: 480);
    }
  }

  List<VideoQuality> get availableQualities {
    if (qualities != null && qualities!.isNotEmpty) {
      final list = qualities!.values.toList();
      list.sort((a, b) => a.height.compareTo(b.height));
      return list;
    }
    return [VideoQuality(label: '480p', url: fullVideoUrl, height: 480)];
  }

  VideoQuality? get bestQuality {
    if (qualities == null || qualities!.isEmpty) return null;
    return qualities!.values.reduce((a, b) => a.height > b.height ? a : b);
  }

  String? get fullThumbnailUrl {
    if (thumbnailUrl?.isEmpty ?? true) return null;
    return _normalizeUrl(thumbnailUrl!);
  }

  bool get hasThumbnail => fullThumbnailUrl != null;

  String get formattedDuration {
    final hours = duration ~/ 3600;
    final minutes = (duration % 3600) ~/ 60;
    final seconds = duration % 60;

    if (hours > 0) return '${hours}h ${minutes}m ${seconds}s';
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
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

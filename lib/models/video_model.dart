import '../utils/parsers.dart';
import '../utils/helpers.dart';
import 'package:hive/hive.dart';

part 'video_model.g.dart';

@HiveType(typeId: 4)
class VideoQuality {
  @HiveField(0)
  final String label;

  @HiveField(1)
  final String url;

  @HiveField(2)
  final int height;

  @HiveField(3)
  final bool isAvailable;

  @HiveField(4)
  final int estimatedSize;

  const VideoQuality({
    required this.label,
    required this.url,
    required this.height,
    this.isAvailable = true,
    this.estimatedSize = 0,
  });

  factory VideoQuality.fromJson(String key, String url, {int duration = 0}) {
    String label;
    int height;

    switch (key) {
      case 'low':
        label = '360p';
        height = 360;
        break;
      case 'medium':
        label = '480p';
        height = 480;
        break;
      case 'high':
        label = '720p';
        height = 720;
        break;
      case 'highest':
        label = '1080p';
        height = 1080;
        break;
      default:
        label = '480p';
        height = 480;
    }

    const bitrates = {
      360: 0.12,
      480: 0.25,
      720: 0.55,
      1080: 0.95,
    };

    final seconds = duration.toDouble();
    final bitrateMbps = bitrates[height] ?? 0.55;
    final estimatedSize = ((bitrateMbps * 1000000 / 8) * seconds).round();

    return VideoQuality(
      label: label,
      url: url,
      height: height,
      estimatedSize: estimatedSize,
    );
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'url': url,
        'height': height,
        'isAvailable': isAvailable,
        'estimatedSize': estimatedSize,
      };

  String get formattedSize {
    if (estimatedSize <= 0) return 'Unknown';
    if (estimatedSize < 1024 * 1024) {
      return '${(estimatedSize / 1024).round()} KB';
    }
    return '${(estimatedSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

@HiveType(typeId: 4) // Video itself uses typeId 4
class Video {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final int chapterId;

  @HiveField(3)
  final String filePath;

  @HiveField(4)
  final int fileSize;

  @HiveField(5)
  final int duration;

  @HiveField(6)
  final String? thumbnailUrl;

  @HiveField(7)
  final DateTime? releaseDate;

  @HiveField(8)
  final int viewCount;

  @HiveField(9)
  final DateTime createdAt;

  @HiveField(10)
  final Map<String, VideoQuality>? qualities;

  @HiveField(11)
  final bool hasQualities;

  @HiveField(12)
  final String? processingStatus;

  // ✅ FIXED: Static flags to prevent log spam
  static bool _qualityParsingLogShown = false;
  static bool _availableQualitiesLogShown = false;
  static int _lastVideoIdForLog = 0;

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
    this.processingStatus,
  });

  factory Video.fromJson(Map<String, dynamic> json) {
    Map<String, VideoQuality>? qualities;
    final hasQualities = json['has_qualities'] == true;
    final duration = Parsers.parseInt(json['duration']);

    if (json['qualities'] != null) {
      qualities = {};
      final qualitiesJson = json['qualities'];

      // Handle both Map<String, dynamic> and Map<dynamic, dynamic>
      if (qualitiesJson is Map<String, dynamic>) {
        // ✅ FIXED: Log only once per app session
        if (!_qualityParsingLogShown) {
          debugLog(
              'Video', '📦 Raw qualities: ${qualitiesJson.keys.join(', ')}');
          _qualityParsingLogShown = true;
        }
        qualitiesJson.forEach((key, value) {
          if (value is String && value.isNotEmpty) {
            qualities![key] =
                VideoQuality.fromJson(key, value, duration: duration);
          }
        });
      } else if (qualitiesJson is Map<dynamic, dynamic>) {
        if (!_qualityParsingLogShown) {
          debugLog('Video',
              '📦 Raw qualities: ${qualitiesJson.keys.map((k) => k.toString()).join(', ')}');
          _qualityParsingLogShown = true;
        }
        qualitiesJson.forEach((key, value) {
          if (key is String && value is String && value.isNotEmpty) {
            qualities![key] =
                VideoQuality.fromJson(key, value, duration: duration);
          }
        });
      }

      if (!_qualityParsingLogShown) {
        debugLog('Video', '✅ Parsed ${qualities.length} qualities');
        _qualityParsingLogShown = true;
      }
    }

    return Video(
      id: Parsers.parseInt(json['id']),
      title: json['title']?.toString().trim() ?? '',
      chapterId: Parsers.parseInt(json['chapter_id']),
      filePath: json['file_path']?.toString() ?? '',
      fileSize: Parsers.parseInt(json['file_size']),
      duration: duration,
      thumbnailUrl: json['thumbnail_url']?.toString(),
      releaseDate: Parsers.parseDate(json['release_date']),
      viewCount: Parsers.parseInt(json['view_count']),
      createdAt: Parsers.parseDate(json['created_at']) ?? DateTime.now(),
      qualities: qualities,
      hasQualities: hasQualities,
      processingStatus: json['processing_status']?.toString(),
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

    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) {
      json['thumbnail_url'] = thumbnailUrl;
    }

    if (releaseDate != null) {
      json['release_date'] = releaseDate!.toIso8601String();
    }

    if (qualities != null && qualities!.isNotEmpty) {
      json['qualities'] =
          qualities!.map((key, value) => MapEntry(key, value.url));
    }

    if (processingStatus != null) {
      json['processing_status'] = processingStatus;
    }

    return json;
  }

  String? getQualityUrl(String qualityKey) {
    if (qualities == null || !qualities!.containsKey(qualityKey)) return null;
    return qualities![qualityKey]!.url;
  }

  String get fullVideoUrl => filePath;

  String? get fullThumbnailUrl {
    final normalizedThumbnail = thumbnailUrl?.trim();
    if (normalizedThumbnail != null &&
        normalizedThumbnail.isNotEmpty &&
        normalizedThumbnail.toLowerCase() != 'null') {
      return normalizedThumbnail;
    }

    final normalizedFilePath = filePath.trim();
    if (!normalizedFilePath.contains('/upload/')) {
      return null;
    }

    final uploadIndex = normalizedFilePath.indexOf('/upload/');
    if (uploadIndex == -1) {
      return null;
    }

    final prefix = normalizedFilePath.substring(0, uploadIndex + '/upload/'.length);
    final suffix = normalizedFilePath.substring(uploadIndex + '/upload/'.length);
    final withoutTransforms = suffix.replaceFirst(RegExp(r'^.*?/v\d+/'), '');
    final publicId = withoutTransforms.replaceFirst(RegExp(r'\.[^.\/?]+(\?.*)?$'), '');

    if (publicId.isEmpty) {
      return null;
    }

    return '${prefix}so_1,w_300,c_fill,g_auto/$publicId.jpg';
  }

  bool get hasThumbnail => fullThumbnailUrl != null && fullThumbnailUrl!.isNotEmpty;

  List<VideoQuality> get availableQualities {
    if (qualities != null && qualities!.isNotEmpty) {
      final list = <VideoQuality>[];

      if (qualities!.containsKey('low')) list.add(qualities!['low']!);
      if (qualities!.containsKey('medium')) list.add(qualities!['medium']!);
      if (qualities!.containsKey('high')) list.add(qualities!['high']!);
      if (qualities!.containsKey('highest')) list.add(qualities!['highest']!);

      // ✅ FIXED: Log only once per video to prevent spam
      if (_lastVideoIdForLog != id && list.isNotEmpty) {
        debugLog(
            'Video', '📊 Video $id: ${list.map((q) => q.label).join(', ')}');
        _lastVideoIdForLog = id;
        _availableQualitiesLogShown = true;
      }

      return list;
    }

    // ✅ FIXED: Log only once
    if (!_availableQualitiesLogShown) {
      debugLog('Video', '📊 Using fallback quality for video $id');
      _availableQualitiesLogShown = true;
    }

    return [
      VideoQuality(
        label: '480p',
        url: fullVideoUrl,
        height: 480,
        estimatedSize: fileSize,
      )
    ];
  }

  VideoQuality getRecommendedQuality([String? connectionType]) {
    final available = availableQualities;

    if (available.isEmpty) {
      return VideoQuality(label: '480p', url: fullVideoUrl, height: 480);
    }

    try {
      if (connectionType == 'offline') {
        return available.first;
      }

      if (connectionType == 'mobile' ||
          connectionType == '2g' ||
          connectionType == '3g') {
        for (final q in available) {
          if (q.height <= 480) return q;
        }
        return available.first;
      }

      if (connectionType == '4g') {
        for (final q in available) {
          if (q.height == 480) return q;
        }
        return available.first;
      }

      return available.last;
    } catch (e) {
      return available.isNotEmpty ? available.first : available.first;
    }
  }

  String get formattedDuration {
    if (duration <= 0) return '00:00';

    final hours = duration ~/ 3600;
    final minutes = (duration % 3600) ~/ 60;
    final seconds = duration % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

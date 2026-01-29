import 'package:familyacademyclient/utils/constants.dart';

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

  Video({
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
  });

  factory Video.fromJson(Map<String, dynamic> json) {
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'chapter_id': chapterId,
      'file_path': filePath,
      'file_size': fileSize,
      'duration': duration,
      'thumbnail_url': thumbnailUrl,
      'release_date': releaseDate?.toIso8601String(),
      'view_count': viewCount,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // FIX: Proper URL generation for production
  String get fullVideoUrl {
    // If filePath is already a full URL (Cloudinary or other CDN)
    if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
      return filePath;
    }

    // If it's a relative path, construct URL with baseUrl
    // Ensure we use HTTPS in production
    String base = AppConstants.baseUrl;

    // Remove any leading slash from filePath
    String cleanPath =
        filePath.startsWith('/') ? filePath.substring(1) : filePath;

    // Construct full URL
    return '$base/$cleanPath';
  }

  // FIX: Proper thumbnail URL generation
  String? get fullThumbnailUrl {
    if (thumbnailUrl == null || thumbnailUrl!.isEmpty) {
      return null;
    }

    // If thumbnail is already a full URL
    if (thumbnailUrl!.startsWith('http://') ||
        thumbnailUrl!.startsWith('https://')) {
      return thumbnailUrl;
    }

    // Construct with baseUrl
    String base = AppConstants.baseUrl;
    String cleanPath = thumbnailUrl!.startsWith('/')
        ? thumbnailUrl!.substring(1)
        : thumbnailUrl!;

    return '$base/$cleanPath';
  }

  bool get hasThumbnail => fullThumbnailUrl != null;
}

class Video {
  final int id;
  final String title;
  final int chapterId;
  final String filePath;
  final int? fileSize;
  final int? duration; // in seconds
  final String? thumbnailUrl;
  final DateTime? releaseDate;
  final int viewCount;
  final DateTime createdAt;

  Video({
    required this.id,
    required this.title,
    required this.chapterId,
    required this.filePath,
    this.fileSize,
    this.duration,
    this.thumbnailUrl,
    this.releaseDate,
    required this.viewCount,
    required this.createdAt,
  });

  factory Video.fromJson(Map<String, dynamic> json) {
    return Video(
      id: json['id'],
      title: json['title'],
      chapterId: json['chapter_id'],
      filePath: json['file_path'],
      fileSize: json['file_size'],
      duration: json['duration'],
      thumbnailUrl: json['thumbnail_url'],
      releaseDate: json['release_date'] != null
          ? DateTime.parse(json['release_date'])
          : null,
      viewCount: json['view_count'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
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

  String get fullUrl => 'http://localhost:3000$filePath';

  bool get hasThumbnail => thumbnailUrl != null && thumbnailUrl!.isNotEmpty;

  String? get thumbnailUrlFull => hasThumbnail
      ? (thumbnailUrl!.startsWith('http')
          ? thumbnailUrl
          : 'http://localhost:3000$thumbnailUrl')
      : null;
}

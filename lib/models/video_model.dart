class Video {
  final int id;
  final String title;
  final int chapterId;
  final String filePath;
  final int fileSize; // Changed from int? to int
  final int duration; // Changed from int? to int
  final String? thumbnailUrl;
  final DateTime? releaseDate;
  final int viewCount;
  final DateTime createdAt;

  Video({
    required this.id,
    required this.title,
    required this.chapterId,
    required this.filePath,
    required this.fileSize, // Changed to required
    required this.duration, // Changed to required
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

  // ... rest of the class remains the same

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

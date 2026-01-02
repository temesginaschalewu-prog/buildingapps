import '../utils/constants.dart';

class Note {
  final int id;
  final String title;
  final int chapterId;
  final String content;
  final String? filePath;
  final DateTime? releaseDate;
  final DateTime createdAt;

  Note({
    required this.id,
    required this.title,
    required this.chapterId,
    required this.content,
    this.filePath,
    this.releaseDate,
    required this.createdAt,
  });

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'],
      title: json['title'],
      chapterId: json['chapter_id'],
      content: json['content'],
      filePath: json['file_path'],
      releaseDate: json['release_date'] != null
          ? DateTime.parse(json['release_date'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'chapter_id': chapterId,
      'content': content,
      'file_path': filePath,
      'release_date': releaseDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  String? get fullFilePath => filePath != null
      ? (filePath!.startsWith('http')
          ? filePath
          : '${AppConstants.baseUrl}$filePath')
      : null;
}

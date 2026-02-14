import 'package:familyacademyclient/utils/constants.dart';

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
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      title: json['title']?.toString() ?? '',
      chapterId: json['chapter_id'] is int
          ? json['chapter_id']
          : int.tryParse(json['chapter_id']?.toString() ?? '0') ?? 0,
      content: json['content']?.toString() ?? '',
      filePath: json['file_path']?.toString(),
      releaseDate: json['release_date'] != null
          ? DateTime.parse(json['release_date'].toString())
          : null,
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
      'content': content,
      'file_path': filePath,
      'release_date': releaseDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  String? get fullNoteFilePath => filePath != null
      ? (filePath!.startsWith('http')
          ? filePath
          : '${AppConstants.baseUrl}$filePath')
      : null;

  bool get hasFile => filePath != null && filePath!.isNotEmpty;

  String get formattedDate {
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }
}

import '../utils/constants.dart';
import '../utils/parsers.dart';
import 'package:hive/hive.dart'; // NEW

part 'note_model.g.dart'; // NEW

@HiveType(typeId: 5) // NEW
class Note {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final int chapterId;

  @HiveField(3)
  final String content;

  @HiveField(4)
  final String? filePath;

  @HiveField(5)
  final DateTime? releaseDate;

  @HiveField(6)
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
      id: Parsers.parseInt(json['id']),
      title: json['title']?.toString() ?? '',
      chapterId: Parsers.parseInt(json['chapter_id']),
      content: json['content']?.toString() ?? '',
      filePath: json['file_path']?.toString(),
      releaseDate: Parsers.parseDate(json['release_date']),
      createdAt: Parsers.parseDate(json['created_at']) ?? DateTime.now(),
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
          : '${AppConstants.apiBaseUrl}$filePath') // FIXED: apiBaseUrl
      : null;

  bool get hasFile => filePath?.isNotEmpty ?? false;

  String get formattedDate =>
      '${createdAt.day}/${createdAt.month}/${createdAt.year}';
}

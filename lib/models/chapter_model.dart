import '../utils/parsers.dart';

class Chapter {
  final int id;
  final String name;
  final String status;
  final DateTime? releaseDate;
  final DateTime createdAt;
  final bool accessible;

  Chapter({
    required this.id,
    required this.name,
    required this.status,
    this.releaseDate,
    required this.createdAt,
    required this.accessible,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: Parsers.parseInt(json['id']),
      name: json['name']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      releaseDate: Parsers.parseDate(json['release_date']),
      createdAt: Parsers.parseDate(json['created_at']) ?? DateTime.now(),
      accessible: Parsers.parseBool(json['accessible']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'status': status,
      'release_date': releaseDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'accessible': accessible,
    };
  }

  bool get isFree => status == 'free';
  bool get isLocked => status == 'locked';
  bool get canAccessContent => isFree || accessible;
}

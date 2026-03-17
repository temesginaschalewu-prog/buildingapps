import '../utils/parsers.dart';
import 'package:hive/hive.dart'; // NEW

part 'school_model.g.dart'; // NEW

@HiveType(typeId: 16) // NEW
class School {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final DateTime createdAt;

  @HiveField(3)
  final DateTime updatedAt;

  School({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });

  factory School.fromJson(Map<String, dynamic> json) {
    return School(
      id: Parsers.parseInt(json['id']),
      name: json['name']?.toString() ?? 'Unknown School',
      createdAt: Parsers.parseDate(json['created_at']) ?? DateTime.now(),
      updatedAt: Parsers.parseDate(json['updated_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

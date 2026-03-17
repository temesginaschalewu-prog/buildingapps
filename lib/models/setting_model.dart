import 'dart:convert';
import '../utils/parsers.dart';
import 'package:hive/hive.dart'; // NEW

part 'setting_model.g.dart'; // NEW

@HiveType(typeId: 17) // NEW
class Setting {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final String settingKey;

  @HiveField(2)
  final String? settingValue;

  @HiveField(3)
  final String displayName;

  @HiveField(4)
  final String category;

  @HiveField(5)
  final String dataType;

  @HiveField(6)
  final bool isPublic;

  @HiveField(7)
  final int displayOrder;

  @HiveField(8)
  final String? description;

  @HiveField(9)
  final DateTime createdAt;

  @HiveField(10)
  final DateTime updatedAt;

  Setting({
    required this.id,
    required this.settingKey,
    this.settingValue,
    required this.displayName,
    required this.category,
    required this.dataType,
    required this.isPublic,
    required this.displayOrder,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Setting.fromJson(Map<String, dynamic> json) {
    return Setting(
      id: Parsers.parseInt(json['id']),
      settingKey: json['setting_key']?.toString() ?? '',
      settingValue: json['setting_value']?.toString(),
      displayName: json['display_name']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      dataType: json['data_type']?.toString() ?? 'string',
      isPublic: Parsers.parseBool(json['is_public']),
      displayOrder: Parsers.parseInt(json['display_order']),
      description: json['description']?.toString(),
      createdAt: Parsers.parseDate(json['created_at']) ?? DateTime.now(),
      updatedAt: Parsers.parseDate(json['updated_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'setting_key': settingKey,
      'setting_value': settingValue,
      'display_name': displayName,
      'category': category,
      'data_type': dataType,
      'is_public': isPublic,
      'display_order': displayOrder,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isString => dataType == 'string';
  bool get isNumber => dataType == 'number';
  bool get isBoolean => dataType == 'boolean';
  bool get isJson => dataType == 'json';
  bool get isArray => dataType == 'array';

  int? get intValue =>
      settingValue != null ? Parsers.parseInt(settingValue) : null;
  double? get doubleValue =>
      settingValue != null ? Parsers.parseDouble(settingValue) : null;
  bool? get boolValue =>
      settingValue != null ? Parsers.parseBool(settingValue) : null;

  List<String>? get arrayValue {
    if (settingValue == null) return null;
    return settingValue!.split(',').map((s) => s.trim()).toList();
  }

  Map<String, dynamic>? get jsonValue {
    if (settingValue == null) return null;
    try {
      final decoded = jsonDecode(settingValue!);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (e) {}
    return null;
  }
}

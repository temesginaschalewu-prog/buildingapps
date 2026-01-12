import 'package:flutter/foundation.dart';

class Setting {
  final int id;
  final String settingKey;
  final String? settingValue;
  final String displayName;
  final String category;
  final String dataType;
  final bool isPublic;
  final int displayOrder;
  final String? description;
  final DateTime createdAt;
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
    try {
      return Setting(
        id: json['id'] is String ? int.parse(json['id']) : json['id'] ?? 0,
        settingKey: json['setting_key']?.toString() ?? '',
        settingValue: json['setting_value']?.toString(),
        displayName: json['display_name']?.toString() ?? '',
        category: json['category']?.toString() ?? '',
        dataType: json['data_type']?.toString() ?? 'string',
        isPublic: json['is_public'] == true,
        displayOrder: json['display_order'] is String
            ? int.parse(json['display_order'])
            : json['display_order'] ?? 0,
        description: json['description']?.toString(),
        createdAt: DateTime.parse(
            json['created_at']?.toString() ?? DateTime.now().toIso8601String()),
        updatedAt: DateTime.parse(
            json['updated_at']?.toString() ?? DateTime.now().toIso8601String()),
      );
    } catch (e) {
      debugPrint('Error parsing Setting: $e');
      rethrow;
    }
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

  int? get intValue {
    if (settingValue == null) return null;
    try {
      return int.parse(settingValue!);
    } catch (e) {
      return null;
    }
  }

  double? get doubleValue {
    if (settingValue == null) return null;
    try {
      return double.parse(settingValue!);
    } catch (e) {
      return null;
    }
  }

  bool? get boolValue {
    if (settingValue == null) return null;
    return settingValue!.toLowerCase() == 'true';
  }

  List<String>? get arrayValue {
    if (settingValue == null) return null;
    return settingValue!.split(',').map((s) => s.trim()).toList();
  }

  Map<String, dynamic>? get jsonValue {
    if (settingValue == null) return null;
    try {
      return Map<String, dynamic>.from(settingValue! as Map);
    } catch (e) {
      return null;
    }
  }
}

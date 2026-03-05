import 'package:flutter/foundation.dart';

class Parsers {
  static int parseInt(dynamic value, [int defaultValue = 0]) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? defaultValue;
    }
    return defaultValue;
  }

  static double parseDouble(dynamic value, [double defaultValue = 0.0]) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? defaultValue;
    }
    return defaultValue;
  }

  static bool parseBool(dynamic value, [bool defaultValue = false]) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) {
      final lower = value.toLowerCase().trim();
      if (lower == 'true' || lower == '1' || lower == 'yes' || lower == 'on')
        return true;
      if (lower == 'false' || lower == '0' || lower == 'no' || lower == 'off')
        return false;
    }
    return defaultValue;
  }

  static DateTime? parseDate(dynamic value) {
    if (value == null) return null;
    try {
      if (value is DateTime) return value.toLocal();
      if (value is String) {
        if (value.contains(' ')) {
          return DateTime.parse(value.replaceFirst(' ', 'T')).toLocal();
        }
        return DateTime.parse(value).toLocal();
      }
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      return null;
    } catch (e) {
      debugPrint('Parsers: Error parsing date: $value');
      return null;
    }
  }

  static int min(int a, int b) => a < b ? a : b;
  static int max(int a, int b) => a > b ? a : b;
}

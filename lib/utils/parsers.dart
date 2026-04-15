import 'dart:convert';

class Parsers {
  static int parseInt(dynamic value, [int defaultValue = 0]) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      try {
        return int.parse(value.trim());
      } catch (e) {
        return defaultValue;
      }
    }
    if (value is bool) return value ? 1 : 0;
    return defaultValue;
  }

  static double parseDouble(dynamic value, [double defaultValue = 0.0]) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value.trim());
      } catch (e) {
        return defaultValue;
      }
    }
    return defaultValue;
  }

  static bool parseBool(dynamic value, [bool defaultValue = false]) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) {
      final lower = value.trim().toLowerCase();
      if (lower == 'true' || lower == '1' || lower == 'yes' || lower == 'on') {
        return true;
      }
      if (lower == 'false' || lower == '0' || lower == 'no' || lower == 'off') {
        return false;
      }
    }
    return defaultValue;
  }

  static DateTime? parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value).toLocal();
      } catch (e) {
        try {
          return DateTime.parse(value.replaceFirst(' ', 'T'));
        } catch (e) {
          return null;
        }
      }
    }
    if (value is int) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  static int min(int a, int b) => a < b ? a : b;
  static int max(int a, int b) => a > b ? a : b;

  static Duration parseCacheTTL(String ttl,
      [Duration defaultValue = const Duration(hours: 24)]) {
    try {
      if (ttl.contains('days')) {
        final days = parseInt(ttl.replaceAll('days', '').trim());
        return Duration(days: days);
      }
      if (ttl.contains('hours')) {
        final hours = parseInt(ttl.replaceAll('hours', '').trim());
        return Duration(hours: hours);
      }
      if (ttl.contains('minutes')) {
        final minutes = parseInt(ttl.replaceAll('minutes', '').trim());
        return Duration(minutes: minutes);
      }
      if (ttl.contains('seconds')) {
        final seconds = parseInt(ttl.replaceAll('seconds', '').trim());
        return Duration(seconds: seconds);
      }
      return defaultValue;
    } catch (e) {
      return defaultValue;
    }
  }

  static Map<String, dynamic> parseJson(String jsonString,
      [Map<String, dynamic>? defaultValue]) {
    try {
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      return defaultValue ?? {};
    }
  }

  static List<dynamic> parseJsonArray(String jsonString,
      [List<dynamic>? defaultValue]) {
    try {
      return jsonDecode(jsonString) as List<dynamic>;
    } catch (e) {
      return defaultValue ?? [];
    }
  }

  static String formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];

    int i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }

    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  static String truncate(String text, int length, {String ellipsis = '...'}) {
    if (text.length <= length) return text;
    return '${text.substring(0, length - ellipsis.length)}$ellipsis';
  }

  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  static String toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}

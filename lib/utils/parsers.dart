import 'package:familyacademyclient/utils/app_enums.dart';
import 'package:flutter/foundation.dart';
import '../services/connectivity_service.dart';

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

  static OfflineActionType parseOfflineActionType(String type) {
    switch (type.toLowerCase()) {
      case 'saveprogress':
        return OfflineActionType.saveProgress;
      case 'submitexam':
        return OfflineActionType.submitExam;
      case 'submitpayment':
        return OfflineActionType.submitPayment;
      case 'marknotificationread':
        return OfflineActionType.markNotificationRead;
      case 'updateprofile':
        return OfflineActionType.updateProfile;
      case 'saveanswer':
        return OfflineActionType.saveAnswer;
      case 'submitexamanswer':
        return OfflineActionType.submitExamAnswer;
      default:
        return OfflineActionType.saveProgress;
    }
  }

  static Duration parseCacheTTL(String ttl,
      [Duration defaultValue = const Duration(hours: 24)]) {
    try {
      if (ttl.contains('days')) {
        final days = parseInt(ttl.replaceAll('days', '').trim());
        return Duration(days: days);
      } else if (ttl.contains('hours')) {
        final hours = parseInt(ttl.replaceAll('hours', '').trim());
        return Duration(hours: hours);
      } else if (ttl.contains('minutes')) {
        final minutes = parseInt(ttl.replaceAll('minutes', '').trim());
        return Duration(minutes: minutes);
      } else if (ttl.contains('seconds')) {
        final seconds = parseInt(ttl.replaceAll('seconds', '').trim());
        return Duration(seconds: seconds);
      }
    } catch (e) {
      debugPrint('Parsers: Error parsing TTL: $ttl');
    }
    return defaultValue;
  }

  static OfflineState parseOfflineState(String state) {
    switch (state.toLowerCase()) {
      case 'online':
        return OfflineState.online;
      case 'offline':
        return OfflineState.offline;
      case 'queued':
        return OfflineState.queued;
      case 'syncing':
        return OfflineState.syncing;
      default:
        return OfflineState.online;
    }
  }

  static CachePriority parseCachePriority(String priority) {
    switch (priority.toLowerCase()) {
      case 'critical':
        return CachePriority.critical;
      case 'high':
        return CachePriority.high;
      case 'normal':
        return CachePriority.normal;
      case 'low':
        return CachePriority.low;
      default:
        return CachePriority.normal;
    }
  }
}

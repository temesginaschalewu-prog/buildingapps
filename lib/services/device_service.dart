// lib/services/device_service.dart
// PRODUCTION-READY FINAL VERSION - WITH CACHE PRUNING

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:familyacademyclient/models/notification_model.dart';
import 'package:familyacademyclient/models/payment_model.dart';
import 'package:familyacademyclient/models/progress_model.dart';
import 'package:familyacademyclient/models/school_model.dart';
import 'package:familyacademyclient/models/setting_model.dart';
import 'package:familyacademyclient/models/subscription_model.dart';
import 'package:familyacademyclient/models/category_model.dart';
import 'package:familyacademyclient/models/course_model.dart';
import 'package:familyacademyclient/models/chapter_model.dart';
import 'package:familyacademyclient/models/exam_model.dart';
import 'package:familyacademyclient/models/exam_result_model.dart';
import 'package:familyacademyclient/models/user_model.dart';
import 'package:familyacademyclient/utils/platform_helper.dart';
import 'package:familyacademyclient/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';
import '../utils/helpers.dart';
import 'hive_service.dart';

// ✅ FIXED: CacheEntry class moved to top level
class _CacheEntry {
  final dynamic value;
  final DateTime timestamp;
  final Duration ttl;

  _CacheEntry(this.value, this.timestamp, this.ttl);

  bool isValid(DateTime now) => now.difference(timestamp) <= ttl;
}

class DeviceService {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  late SharedPreferences _prefs;
  static String? _persistentDeviceId;

  // ✅ FIXED: Use LinkedHashMap with size limit
  static const int _maxCacheSize = 100;
  final LinkedHashMap<String, _CacheEntry> _memoryCache =
      LinkedHashMap<String, _CacheEntry>();

  String? _currentUserId;
  bool _isInitialized = false;
  Future<void>? _initFuture;

  // Hive boxes
  Box? _categoriesBox;
  Box? _coursesBox;
  Box? _chaptersBox;
  Box? _videosBox;
  Box? _notesBox;
  Box? _questionsBox;
  Box? _examsBox;
  Box? _subscriptionsBox;
  Box? _paymentsBox;
  Box? _notificationsBox;
  Box? _progressBox;
  Box? _userBox;
  Box<Map<String, dynamic>>? _deviceInfoBox;

  bool get isInitialized => _isInitialized;

  DeviceService();

  Future<void> init() async {
    if (_isInitialized) return;
    if (_initFuture != null) {
      await _initFuture;
      return;
    }

    _initFuture = _doInit();
    await _initFuture;
  }

  Future<void> _doInit() async {
    debugLog('DeviceService', '🔄 Initializing...');

    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadPersistentDeviceId();
      await _loadCurrentUserId();

      await _openHiveBoxes();

      await saveDeviceInfo();

      // Load cache from prefs
      await _loadCacheFromPrefs();

      debugLog(
          'DeviceService', '✅ Cache loaded with ${_memoryCache.length} items');
      debugLog('DeviceService', '✅ Initialization complete');
      _isInitialized = true;
    } catch (e) {
      debugLog('DeviceService', '❌ Init error: $e');
      _persistentDeviceId ??=
          'fallback_${DateTime.now().millisecondsSinceEpoch}';
    } finally {
      _initFuture = null;
    }
  }

  // ✅ FIXED: Prune cache when it gets too large
  void _pruneCache() {
    while (_memoryCache.length > _maxCacheSize) {
      _memoryCache.remove(_memoryCache.keys.first);
    }
  }

  // ✅ FIXED: Clean expired entries
  void _cleanExpiredCache() {
    final now = DateTime.now();
    final expiredKeys = <String>[];
    _memoryCache.forEach((key, entry) {
      if (!entry.isValid(now)) {
        expiredKeys.add(key);
      }
    });
    for (final key in expiredKeys) {
      _memoryCache.remove(key);
    }
  }

  Future<void> saveDeviceInfo() async {
    try {
      final deviceId = await getDeviceId();
      final deviceInfo = {
        'device_id': deviceId,
        'platform': Platform.operatingSystem,
        'platform_version': Platform.operatingSystemVersion,
        'last_used': DateTime.now().toIso8601String(),
      };

      _deviceInfoBox ??=
          await Hive.openBox<Map<String, dynamic>>('device_info_box');

      await _deviceInfoBox!.put('current_device', deviceInfo);
      debugLog('DeviceService', '✅ Device info saved: $deviceId');
    } catch (e) {
      debugLog('DeviceService', 'Error saving device info: $e');
    }
  }

  Future<void> _openHiveBoxes() async {
    try {
      final hiveService = HiveService();

      _userBox = await hiveService.openBox<dynamic>(AppConstants.hiveUserBox);
      _categoriesBox =
          await hiveService.openBox<dynamic>(AppConstants.hiveCategoriesBox);
      _coursesBox =
          await hiveService.openBox<dynamic>(AppConstants.hiveCoursesBox);
      _chaptersBox =
          await hiveService.openBox<dynamic>(AppConstants.hiveChaptersBox);
      _videosBox =
          await hiveService.openBox<dynamic>(AppConstants.hiveVideosBox);
      _notesBox = await hiveService.openBox<dynamic>(AppConstants.hiveNotesBox);
      _questionsBox =
          await hiveService.openBox<dynamic>(AppConstants.hiveQuestionsBox);
      _examsBox = await hiveService.openBox<dynamic>(AppConstants.hiveExamsBox);
      _subscriptionsBox =
          await hiveService.openBox<dynamic>(AppConstants.hiveSubscriptionsBox);
      _paymentsBox =
          await hiveService.openBox<dynamic>(AppConstants.hivePaymentsBox);
      _notificationsBox =
          await hiveService.openBox<dynamic>(AppConstants.hiveNotificationsBox);
      _progressBox =
          await hiveService.openBox<dynamic>(AppConstants.hiveProgressBox);

      _deviceInfoBox =
          await hiveService.openBox<Map<String, dynamic>>('device_info_box');

      debugLog('DeviceService', '✅ Hive boxes opened');
    } catch (e) {
      debugLog('DeviceService', '⚠️ Error opening Hive boxes: $e');
    }
  }

  // ===== DEVICE ID METHODS =====
  String getDeviceIdSync() {
    return _persistentDeviceId ??
        'unknown_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<String> getDeviceId() async {
    return _persistentDeviceId ??
        'unknown_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> _loadPersistentDeviceId() async {
    _persistentDeviceId = _prefs.getString(AppConstants.persistentDeviceIdKey);

    if (_persistentDeviceId == null || _persistentDeviceId!.isEmpty) {
      _persistentDeviceId = await _generatePersistentDeviceId();
      await _prefs.setString(
          AppConstants.persistentDeviceIdKey, _persistentDeviceId!);
    }
  }

  Future<String> _generatePersistentDeviceId() async {
    try {
      if (PlatformHelper.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        if (androidInfo.id.isNotEmpty && androidInfo.id != 'unknown') {
          return '${AppConstants.androidDevicePrefix}${androidInfo.id.hashCode.abs()}';
        }
      } else if (PlatformHelper.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        if (iosInfo.identifierForVendor != null) {
          return '${AppConstants.iosDevicePrefix}${iosInfo.identifierForVendor!.hashCode.abs()}';
        }
      }
    } catch (e) {
      debugLog('DeviceService', 'Error generating device ID: $e');
    }

    return '${AppConstants.fallbackDevicePrefix}${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
  }

  // ===== USER ID METHODS =====
  Future<String?> getCurrentUserId() async {
    return _currentUserId;
  }

  Future<void> setCurrentUserId(String userId) async {
    _currentUserId = userId;
    await _prefs.setString(AppConstants.currentUserIdKey, userId);
    await saveDeviceInfo();
  }

  Future<void> clearCurrentUserId() async {
    _currentUserId = null;
    await _prefs.remove(AppConstants.currentUserIdKey);
  }

  Future<void> _loadCurrentUserId() async {
    _currentUserId = _prefs.getString(AppConstants.currentUserIdKey);
  }

  // ===== CACHE METHODS =====
  Future<T?> getCacheItem<T>(String key, {bool isUserSpecific = false}) async {
    final cacheKey = _getCacheKey(key, isUserSpecific);
    final now = DateTime.now();

    // ✅ FIXED: Check memory cache with validation
    if (_memoryCache.containsKey(cacheKey)) {
      final entry = _memoryCache[cacheKey]!;
      if (entry.isValid(now)) {
        return _decodeValue<T>(entry.value);
      } else {
        _memoryCache.remove(cacheKey);
      }
    }

    // Try Hive
    try {
      final hiveKey = 'cache_$cacheKey';
      Box? box = _getBoxForKey(key);

      if (box != null && box.containsKey(hiveKey)) {
        final value = box.get(hiveKey);
        if (value != null) {
          final ttl = _getDefaultTTLForType(T.toString());
          _memoryCache[cacheKey] = _CacheEntry(value, now, ttl);
          _pruneCache();
          return _decodeValue<T>(value);
        }
      }
    } catch (e) {
      // Fall through to SharedPreferences
    }

    // Try SharedPreferences
    try {
      final cachedStr =
          _prefs.getString('${AppConstants.cachePrefix}$cacheKey');
      if (cachedStr != null) {
        final cacheData = json.decode(cachedStr) as Map<String, dynamic>;
        final timestamp = DateTime.parse(cacheData['timestamp']);
        final ttl = Duration(
            seconds: cacheData['ttl'] ??
                _getDefaultTTLForType(T.toString()).inSeconds);

        if (now.difference(timestamp) <= ttl) {
          final value = cacheData['value'];
          _memoryCache[cacheKey] = _CacheEntry(value, timestamp, ttl);
          _pruneCache();
          return _decodeValue<T>(value);
        }
      }
    } catch (e) {
      // Cache miss or invalid
    }

    return null;
  }

  void saveCacheItem<T>(String key, T value,
      {Duration? ttl, bool isUserSpecific = false}) {
    unawaited(
        _doSaveCacheItem(key, value, ttl: ttl, isUserSpecific: isUserSpecific));
  }

  Future<void> _doSaveCacheItem<T>(String key, T value,
      {Duration? ttl, bool isUserSpecific = false}) async {
    try {
      final cacheKey = _getCacheKey(key, isUserSpecific);
      final effectiveTtl = ttl ?? _getDefaultTTLForType(T.toString());
      final now = DateTime.now();

      // Save to memory cache
      _memoryCache[cacheKey] = _CacheEntry(value, now, effectiveTtl);
      _cleanExpiredCache();
      _pruneCache();

      // Save to Hive
      try {
        final hiveKey = 'cache_$cacheKey';
        final box = _getBoxForKey(key);
        if (box != null) {
          await box.put(hiveKey, value);
        }
      } catch (e) {
        // Hive save failed, continue with SharedPreferences
      }

      // Save to SharedPreferences as backup
      final cacheData = {
        'value': _encodeValue(value),
        'timestamp': now.toIso8601String(),
        'ttl': effectiveTtl.inSeconds,
      };
      await _prefs.setString(
          '${AppConstants.cachePrefix}$cacheKey', json.encode(cacheData));
    } catch (e) {
      debugLog('DeviceService', 'Error saving cache item: $e');
    }
  }

  Box? _getBoxForKey(String key) {
    if (key.contains('user') || key.contains('profile')) return _userBox;
    if (key.contains('categories')) return _categoriesBox;
    if (key.contains('courses')) return _coursesBox;
    if (key.contains('chapters')) return _chaptersBox;
    if (key.contains('videos')) return _videosBox;
    if (key.contains('notes')) return _notesBox;
    if (key.contains('questions')) return _questionsBox;
    if (key.contains('exams')) return _examsBox;
    if (key.contains('subscriptions')) return _subscriptionsBox;
    if (key.contains('payments')) return _paymentsBox;
    if (key.contains('notifications')) return _notificationsBox;
    if (key.contains('progress')) return _progressBox;
    return null;
  }

  Future<void> removeCacheItem(String key,
      {bool isUserSpecific = false}) async {
    final cacheKey = _getCacheKey(key, isUserSpecific);
    _memoryCache.remove(cacheKey);
    await _prefs.remove('${AppConstants.cachePrefix}$cacheKey');

    try {
      final hiveKey = 'cache_$cacheKey';
      final box = _getBoxForKey(key);
      if (box?.containsKey(hiveKey) ?? false) {
        await box?.delete(hiveKey);
      }
    } catch (e) {
      // Ignore Hive errors
    }
  }

  Future<void> clearCacheByPrefix(String prefix) async {
    // Clear memory cache
    final keysToRemove = _memoryCache.keys
        .where((key) => key.startsWith(prefix) || key.contains(prefix))
        .toList();
    for (final key in keysToRemove) {
      _memoryCache.remove(key);
    }

    // Clear SharedPreferences
    for (final key in _prefs.getKeys()) {
      if (key.startsWith('${AppConstants.cachePrefix}$prefix') ||
          key.contains(prefix)) {
        await _prefs.remove(key);
      }
    }

    // Clear Hive (async, don't await)
    unawaited(_clearHiveCacheByPrefix(prefix));
  }

  Future<void> _clearHiveCacheByPrefix(String prefix) async {
    try {
      final boxes = [
        _userBox,
        _categoriesBox,
        _coursesBox,
        _chaptersBox,
        _videosBox,
        _notesBox,
        _questionsBox,
        _examsBox,
        _subscriptionsBox,
        _paymentsBox,
        _notificationsBox,
        _progressBox
      ];

      for (final box in boxes) {
        if (box == null) continue;
        final keysToDelete = box.keys
            .where((key) =>
                key.toString().startsWith('cache_$prefix') ||
                key.toString().contains(prefix))
            .toList();
        for (final key in keysToDelete) {
          await box.delete(key);
        }
      }
    } catch (e) {
      debugLog('DeviceService', 'Error clearing Hive cache: $e');
    }
  }

  // ===== TV DEVICE METHODS =====
  Future<void> saveTvDeviceId(String deviceId) async {
    await _prefs.setString(AppConstants.tvDeviceIdKey, deviceId);
  }

  Future<String?> getTvDeviceId() async {
    return _prefs.getString(AppConstants.tvDeviceIdKey);
  }

  Future<void> clearTvDeviceId() async {
    await _prefs.remove(AppConstants.tvDeviceIdKey);
  }

  // ===== CACHE UTILITY METHODS =====
  String _getCacheKey(String key, bool isUserSpecific) {
    if (!isUserSpecific || _currentUserId == null) {
      return key;
    }
    return 'user_${_currentUserId}_$key';
  }

  Duration _getDefaultTTLForType(String type) {
    if (type.contains('Category')) return AppConstants.cacheTTLCategories;
    if (type.contains('Course')) return AppConstants.cacheTTLCourses;
    if (type.contains('Chapter')) return AppConstants.cacheTTLChapters;
    if (type.contains('Video')) return AppConstants.cacheTTLVideos;
    if (type.contains('Note')) return AppConstants.cacheTTLNotes;
    if (type.contains('Question')) return AppConstants.cacheTTLQuestions;
    if (type.contains('Exam')) return AppConstants.cacheTTLExams;
    if (type.contains('Subscription'))
      return AppConstants.cacheTTLSubscriptions;
    if (type.contains('Payment')) return AppConstants.cacheTTLPayments;
    if (type.contains('Notification'))
      return AppConstants.cacheTTLNotifications;
    if (type.contains('Streak')) return AppConstants.cacheTTLStreak;
    if (type.contains('School')) return AppConstants.cacheTTLSchools;
    if (type.contains('Setting')) return AppConstants.cacheTTLSettings;
    if (type.contains('User')) return AppConstants.cacheTTLUserProfile;
    return AppConstants.defaultCacheTTL;
  }

  dynamic _encodeValue(dynamic value) {
    if (value is List) {
      return value.map(_encodeValue).toList();
    } else if (value is Map) {
      return value;
    } else if (value is Subscription)
      return value.toJson();
    else if (value is Payment)
      return value.toJson();
    else if (value is Setting)
      return value.toJson();
    else if (value is School)
      return value.toJson();
    else if (value is Category)
      return value.toJson();
    else if (value is Course)
      return value.toJson();
    else if (value is Chapter)
      return value.toJson();
    else if (value is Exam)
      return value.toJson();
    else if (value is ExamResult)
      return value.toJson();
    else if (value is UserProgress)
      return value.toJson();
    else if (value is User)
      return value.toJson();
    else if (value is Notification) return value.toJson();
    return value;
  }

  T? _decodeValue<T>(dynamic value) {
    if (value == null) return null;

    try {
      if (T == String) return value as T;
      if (T == int) return (value as num).toInt() as T;
      if (T == double) return (value as num).toDouble() as T;
      if (T == bool) return value as T;
      if (T == Map<String, dynamic>) return value as T;

      if (value is List) {
        if (T == List<Subscription>) {
          return value
              .map(
                  (item) => Subscription.fromJson(item as Map<String, dynamic>))
              .toList() as T;
        }
        if (T == List<Payment>) {
          return value
              .map((item) => Payment.fromJson(item as Map<String, dynamic>))
              .toList() as T;
        }
        if (T == List<Notification>) {
          return value
              .map(
                  (item) => Notification.fromJson(item as Map<String, dynamic>))
              .toList() as T;
        }
        if (T == List<Setting>) {
          return value
              .map((item) => Setting.fromJson(item as Map<String, dynamic>))
              .toList() as T;
        }
        if (T == List<School>) {
          return value
              .map((item) => School.fromJson(item as Map<String, dynamic>))
              .toList() as T;
        }
        if (T == List<Category>) {
          return value
              .map((item) => Category.fromJson(item as Map<String, dynamic>))
              .toList() as T;
        }
        if (T == List<Course>) {
          return value
              .map((item) => Course.fromJson(item as Map<String, dynamic>))
              .toList() as T;
        }
        if (T == List<Chapter>) {
          return value
              .map((item) => Chapter.fromJson(item as Map<String, dynamic>))
              .toList() as T;
        }
        if (T == List<Exam>) {
          return value
              .map((item) => Exam.fromJson(item as Map<String, dynamic>))
              .toList() as T;
        }
        if (T == List<ExamResult>) {
          return value
              .map((item) => ExamResult.fromJson(item as Map<String, dynamic>))
              .toList() as T;
        }
        if (T == List<UserProgress>) {
          return value
              .map(
                  (item) => UserProgress.fromJson(item as Map<String, dynamic>))
              .toList() as T;
        }
      }

      if (T == User && value is Map<String, dynamic>)
        return User.fromJson(value) as T;
      if (T == Subscription && value is Map)
        return Subscription.fromJson(value as Map<String, dynamic>) as T;
      if (T == Payment && value is Map)
        return Payment.fromJson(value as Map<String, dynamic>) as T;
      if (T == Notification && value is Map<String, dynamic>)
        return Notification.fromJson(value) as T;
      if (T == Setting && value is Map)
        return Setting.fromJson(value as Map<String, dynamic>) as T;
      if (T == School && value is Map)
        return School.fromJson(value as Map<String, dynamic>) as T;
      if (T == Category && value is Map)
        return Category.fromJson(value as Map<String, dynamic>) as T;
      if (T == Course && value is Map)
        return Course.fromJson(value as Map<String, dynamic>) as T;
      if (T == Chapter && value is Map)
        return Chapter.fromJson(value as Map<String, dynamic>) as T;
      if (T == Exam && value is Map)
        return Exam.fromJson(value as Map<String, dynamic>) as T;
      if (T == ExamResult && value is Map)
        return ExamResult.fromJson(value as Map<String, dynamic>) as T;
      if (T == UserProgress && value is Map)
        return UserProgress.fromJson(value as Map<String, dynamic>) as T;

      return value as T?;
    } catch (e) {
      debugLog('DeviceService', 'Error decoding value for type $T: $e');
      return null;
    }
  }

  Future<void> _loadCacheFromPrefs() async {
    try {
      final keys = _prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith(AppConstants.cachePrefix)) {
          final cachedStr = _prefs.getString(key);
          if (cachedStr != null) {
            try {
              final cacheData = json.decode(cachedStr) as Map<String, dynamic>;
              final timestamp = DateTime.parse(cacheData['timestamp']);
              final ttl = Duration(
                  seconds: cacheData['ttl'] ??
                      AppConstants.defaultCacheTTL.inSeconds);

              if (DateTime.now().difference(timestamp) <= ttl) {
                final cacheKey = key.substring(AppConstants.cachePrefix.length);
                _memoryCache[cacheKey] =
                    _CacheEntry(cacheData['value'], timestamp, ttl);
              } else {
                await _prefs.remove(key);
              }
            } catch (e) {
              await _prefs.remove(key);
            }
          }
        }
      }
      _pruneCache();
    } catch (e) {
      debugLog('DeviceService', 'Error loading cache: $e');
    }
  }

  Future<Map<String, dynamic>> getDeviceInfo() async {
    final deviceId = await getDeviceId();
    final info = <String, dynamic>{
      'device_id': deviceId,
      'platform': Platform.operatingSystem,
      'platform_version': Platform.operatingSystemVersion,
      'app_version': AppConstants.appVersion,
    };

    try {
      if (PlatformHelper.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        info.addAll({
          'brand': androidInfo.brand,
          'model': androidInfo.model,
          'device': androidInfo.device,
          'product': androidInfo.product,
          'hardware': androidInfo.hardware,
          'android_version': androidInfo.version.release,
          'sdk_version': androidInfo.version.sdkInt,
          'is_physical_device': androidInfo.isPhysicalDevice,
        });
      } else if (PlatformHelper.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        info.addAll({
          'name': iosInfo.name,
          'model': iosInfo.model,
          'system_name': iosInfo.systemName,
          'system_version': iosInfo.systemVersion,
          'is_physical_device': iosInfo.isPhysicalDevice,
        });
      }
    } catch (e) {
      // Ignore device info errors
    }

    return info;
  }

  Map<String, dynamic> getCacheStats() {
    _cleanExpiredCache();
    return <String, dynamic>{
      'memory_cache_size': _memoryCache.length,
      'current_user_id': _currentUserId,
      'device_id': _persistentDeviceId,
    };
  }

  void dispose() {
    _memoryCache.clear();
  }
}

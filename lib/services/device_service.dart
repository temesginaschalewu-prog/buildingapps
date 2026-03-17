// lib/services/device_service.dart
// COMPLETE FIXED VERSION - Open ALL boxes as dynamic

import 'dart:async';
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

class DeviceService {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  late SharedPreferences _prefs;
  static String? _persistentDeviceId;

  final Map<String, dynamic> _memoryCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _defaultCacheTTL = AppConstants.defaultCacheTTL;

  String? _currentUserId;
  bool _isInitialized = false;
  Future<void>? _initFuture;

  // ALL BOXES OPENED AS DYNAMIC
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

      // Open Hive boxes as dynamic
      await _openHiveBoxes();

      await saveDeviceInfo();

      unawaited(_loadCacheFromPrefs().then((_) {
        debugLog('DeviceService',
            '✅ Cache loaded with ${_memoryCache.length} items');
      }));

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

      // ALL BOXES OPENED AS DYNAMIC - NO TYPE SPECIFICATIONS
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

      debugLog('DeviceService', '✅ Hive boxes opened (ALL dynamic)');
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

    if (_memoryCache.containsKey(cacheKey)) {
      final cacheData = _memoryCache[cacheKey] as Map<String, dynamic>?;
      if (cacheData != null && _isCacheValid(cacheData)) {
        return _decodeValue<T>(cacheData['value']);
      }
    }

    try {
      final hiveKey = 'cache_$cacheKey';
      Box? box;

      if (key.contains('user') || key.contains('profile')) {
        box = _userBox;
      } else if (key.contains('categories')) {
        box = _categoriesBox;
      } else if (key.contains('courses')) {
        box = _coursesBox;
      } else if (key.contains('chapters')) {
        box = _chaptersBox;
      } else if (key.contains('videos')) {
        box = _videosBox;
      } else if (key.contains('notes')) {
        box = _notesBox;
      } else if (key.contains('questions')) {
        box = _questionsBox;
      } else if (key.contains('exams')) {
        box = _examsBox;
      } else if (key.contains('subscriptions')) {
        box = _subscriptionsBox;
      } else if (key.contains('payments')) {
        box = _paymentsBox;
      } else if (key.contains('notifications')) {
        box = _notificationsBox;
      } else if (key.contains('progress')) {
        box = _progressBox;
      }

      if (box != null && box.containsKey(hiveKey)) {
        final cached = box.get(hiveKey);
        return cached as T?;
      }
    } catch (e) {}

    try {
      final cachedStr =
          _prefs.getString('${AppConstants.cachePrefix}$cacheKey');
      if (cachedStr != null) {
        final cacheData = json.decode(cachedStr) as Map<String, dynamic>;
        if (_isCacheValid(cacheData)) {
          _memoryCache[cacheKey] = cacheData;
          _cacheTimestamps[cacheKey] = DateTime.parse(cacheData['timestamp']);
          return _decodeValue<T>(cacheData['value']);
        }
      }
    } catch (e) {}

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

      final cacheData = {
        'value': _encodeValue(value),
        'timestamp': DateTime.now().toIso8601String(),
        'ttl': (ttl ?? _getDefaultTTLForType(T.toString())).inSeconds,
      };

      _memoryCache[cacheKey] = cacheData;
      _cacheTimestamps[cacheKey] = DateTime.now();

      await _prefs.setString(
          '${AppConstants.cachePrefix}$cacheKey', json.encode(cacheData));

      try {
        final hiveKey = 'cache_$cacheKey';

        if (key.contains('user') || key.contains('profile')) {
          if (_userBox != null) await _userBox!.put(hiveKey, value);
        } else if (key.contains('categories')) {
          if (_categoriesBox != null) await _categoriesBox!.put(hiveKey, value);
        } else if (key.contains('courses')) {
          if (_coursesBox != null) await _coursesBox!.put(hiveKey, value);
        } else if (key.contains('chapters')) {
          if (_chaptersBox != null) await _chaptersBox!.put(hiveKey, value);
        } else if (key.contains('videos')) {
          if (_videosBox != null) await _videosBox!.put(hiveKey, value);
        } else if (key.contains('notes')) {
          if (_notesBox != null) await _notesBox!.put(hiveKey, value);
        } else if (key.contains('questions')) {
          if (_questionsBox != null) await _questionsBox!.put(hiveKey, value);
        } else if (key.contains('exams')) {
          if (_examsBox != null) await _examsBox!.put(hiveKey, value);
        } else if (key.contains('subscriptions')) {
          if (_subscriptionsBox != null) {
            await _subscriptionsBox!.put(hiveKey, value);
          }
        } else if (key.contains('payments')) {
          if (_paymentsBox != null) await _paymentsBox!.put(hiveKey, value);
        } else if (key.contains('notifications')) {
          if (_notificationsBox != null) {
            await _notificationsBox!.put(hiveKey, value);
          }
        } else if (key.contains('progress')) {
          if (_progressBox != null) await _progressBox!.put(hiveKey, value);
        }
      } catch (e) {}
    } catch (e) {}
  }

  Future<void> removeCacheItem(String key,
      {bool isUserSpecific = false}) async {
    final cacheKey = _getCacheKey(key, isUserSpecific);
    _memoryCache.remove(cacheKey);
    _cacheTimestamps.remove(cacheKey);
    await _prefs.remove('${AppConstants.cachePrefix}$cacheKey');

    try {
      final hiveKey = 'cache_$cacheKey';
      if (_userBox?.containsKey(hiveKey) ?? false) {
        await _userBox?.delete(hiveKey);
      }
      if (_categoriesBox?.containsKey(hiveKey) ?? false) {
        await _categoriesBox?.delete(hiveKey);
      }
      if (_coursesBox?.containsKey(hiveKey) ?? false) {
        await _coursesBox?.delete(hiveKey);
      }
      if (_chaptersBox?.containsKey(hiveKey) ?? false) {
        await _chaptersBox?.delete(hiveKey);
      }
      if (_videosBox?.containsKey(hiveKey) ?? false) {
        await _videosBox?.delete(hiveKey);
      }
      if (_notesBox?.containsKey(hiveKey) ?? false) {
        await _notesBox?.delete(hiveKey);
      }
      if (_questionsBox?.containsKey(hiveKey) ?? false) {
        await _questionsBox?.delete(hiveKey);
      }
      if (_examsBox?.containsKey(hiveKey) ?? false) {
        await _examsBox?.delete(hiveKey);
      }
      if (_subscriptionsBox?.containsKey(hiveKey) ?? false) {
        await _subscriptionsBox?.delete(hiveKey);
      }
      if (_paymentsBox?.containsKey(hiveKey) ?? false) {
        await _paymentsBox?.delete(hiveKey);
      }
      if (_notificationsBox?.containsKey(hiveKey) ?? false) {
        await _notificationsBox?.delete(hiveKey);
      }
      if (_progressBox?.containsKey(hiveKey) ?? false) {
        await _progressBox?.delete(hiveKey);
      }
    } catch (e) {}
  }

  Future<void> clearCacheByPrefix(String prefix) async {
    for (final key in _memoryCache.keys.toList()) {
      if (key.startsWith(prefix) || key.contains(prefix)) {
        _memoryCache.remove(key);
        _cacheTimestamps.remove(key);
      }
    }

    for (final key in _prefs.getKeys()) {
      if (key.startsWith('${AppConstants.cachePrefix}$prefix') ||
          key.contains(prefix)) {
        await _prefs.remove(key);
      }
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
    if (type.contains('Subscription')) {
      return AppConstants.cacheTTLSubscriptions;
    }
    if (type.contains('Payment')) return AppConstants.cacheTTLPayments;
    if (type.contains('Notification')) {
      return AppConstants.cacheTTLNotifications;
    }
    if (type.contains('Streak')) return AppConstants.cacheTTLStreak;
    if (type.contains('School')) return AppConstants.cacheTTLSchools;
    if (type.contains('Setting')) return AppConstants.cacheTTLSettings;
    if (type.contains('User')) return AppConstants.cacheTTLUserProfile;
    return _defaultCacheTTL;
  }

  bool _isCacheValid(Map<String, dynamic> cacheData) {
    try {
      final timestamp = DateTime.parse(cacheData['timestamp']);
      final ttl =
          Duration(seconds: cacheData['ttl'] ?? _defaultCacheTTL.inSeconds);
      return DateTime.now().difference(timestamp) <= ttl;
    } catch (e) {
      return false;
    }
  }

  dynamic _encodeValue(dynamic value) {
    if (value is List) {
      return value.map(_encodeValue).toList();
    } else if (value is Map) {
      return value;
    } else if (value is Subscription) {
      return value.toJson();
    } else if (value is Payment) {
      return value.toJson();
    } else if (value is Setting) {
      return value.toJson();
    } else if (value is School) {
      return value.toJson();
    } else if (value is Category) {
      return value.toJson();
    } else if (value is Course) {
      return value.toJson();
    } else if (value is Chapter) {
      return value.toJson();
    } else if (value is Exam) {
      return value.toJson();
    } else if (value is ExamResult) {
      return value.toJson();
    } else if (value is UserProgress) {
      return value.toJson();
    } else if (value is User) {
      return value.toJson();
    } else if (value is Notification) {
      return value.toJson();
    }
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

      if (T == User && value is Map<String, dynamic>) {
        return User.fromJson(value) as T;
      }
      if (T == Subscription && value is Map) {
        return Subscription.fromJson(value as Map<String, dynamic>) as T;
      }
      if (T == Payment && value is Map) {
        return Payment.fromJson(value as Map<String, dynamic>) as T;
      }
      if (T == Notification && value is Map<String, dynamic>) {
        return Notification.fromJson(value) as T;
      }
      if (T == Setting && value is Map) {
        return Setting.fromJson(value as Map<String, dynamic>) as T;
      }
      if (T == School && value is Map) {
        return School.fromJson(value as Map<String, dynamic>) as T;
      }
      if (T == Category && value is Map) {
        return Category.fromJson(value as Map<String, dynamic>) as T;
      }
      if (T == Course && value is Map) {
        return Course.fromJson(value as Map<String, dynamic>) as T;
      }
      if (T == Chapter && value is Map) {
        return Chapter.fromJson(value as Map<String, dynamic>) as T;
      }
      if (T == Exam && value is Map) {
        return Exam.fromJson(value as Map<String, dynamic>) as T;
      }
      if (T == ExamResult && value is Map) {
        return ExamResult.fromJson(value as Map<String, dynamic>) as T;
      }
      if (T == UserProgress && value is Map) {
        return UserProgress.fromJson(value as Map<String, dynamic>) as T;
      }

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
                  seconds: cacheData['ttl'] ?? _defaultCacheTTL.inSeconds);

              if (DateTime.now().difference(timestamp) <= ttl) {
                final cacheKey = key.substring(AppConstants.cachePrefix.length);
                _memoryCache[cacheKey] = cacheData;
                _cacheTimestamps[cacheKey] = timestamp;
              } else {
                await _prefs.remove(key);
              }
            } catch (e) {
              await _prefs.remove(key);
            }
          }
        }
      }
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
    } catch (e) {}

    return info;
  }

  Map<String, dynamic> getCacheStats() {
    return <String, dynamic>{
      'memory_cache_size': _memoryCache.length,
      'cache_timestamps_size': _cacheTimestamps.length,
      'current_user_id': _currentUserId,
      'device_id': _persistentDeviceId,
    };
  }

  void dispose() {}
}

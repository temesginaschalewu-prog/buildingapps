import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:familyacademyclient/models/payment_model.dart';
import 'package:familyacademyclient/models/school_model.dart';
import 'package:familyacademyclient/models/setting_model.dart';
import 'package:familyacademyclient/models/subscription_model.dart';
import 'package:familyacademyclient/models/category_model.dart';
import 'package:familyacademyclient/models/course_model.dart';
import 'package:familyacademyclient/models/chapter_model.dart';
import 'package:familyacademyclient/models/exam_model.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class DeviceService {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  late SharedPreferences _prefs;
  static String? _persistentDeviceId;
  bool _initialized = false;
  Completer<void>? _initializationCompleter;

  final Map<String, dynamic> _memoryCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _defaultCacheTTL = Duration(hours: 24);
  static const Duration _longCacheTTL = Duration(days: 7);

  String? _currentUserId;
  final Map<String, List<StreamController>> _cacheListeners = {};

  DeviceService();

  Future<void> init() async {
    if (_initialized) return _initializationCompleter?.future;

    if (_initializationCompleter != null) {
      return _initializationCompleter!.future;
    }

    _initializationCompleter = Completer<void>();

    debugLog('DeviceService', '🔄 Initializing...');

    try {
      _prefs = await SharedPreferences.getInstance();

      await _loadPersistentDeviceId();
      await _loadCurrentUserId();
      await _loadCacheFromPrefs();

      _initialized = true;
      debugLog('DeviceService',
          '✅ Initialized with Device ID: $_persistentDeviceId, Cache: ${_memoryCache.length} items');

      _initializationCompleter!.complete();
    } catch (e) {
      debugLog('DeviceService', '❌ Initialization error: $e');
      _initializationCompleter!.completeError(e);
      rethrow;
    }

    return _initializationCompleter!.future;
  }

  Future<void> ensureInitialized() async {
    if (!_initialized) {
      await init();
    }
  }

  Future<void> _loadCacheFromPrefs() async {
    try {
      final keys = _prefs.getKeys();
      int loadedCount = 0;

      for (final key in keys) {
        if (key.startsWith('cache_')) {
          final cachedStr = _prefs.getString(key);
          if (cachedStr != null) {
            try {
              final cacheData = json.decode(cachedStr) as Map<String, dynamic>;
              final timestamp = DateTime.parse(cacheData['timestamp']);
              final ttl = Duration(
                  seconds: cacheData['ttl'] ?? _defaultCacheTTL.inSeconds);

              if (DateTime.now().difference(timestamp) <= ttl) {
                final cacheKey = key.substring(6);
                _memoryCache[cacheKey] = cacheData;
                _cacheTimestamps[cacheKey] = timestamp;
                loadedCount++;
              }
            } catch (e) {
              debugLog('DeviceService', 'Error loading cache key $key: $e');
            }
          }
        }
      }

      debugLog('DeviceService', '📦 Loaded $loadedCount cache items from disk');
    } catch (e) {
      debugLog('DeviceService', 'Error loading cache from prefs: $e');
    }
  }

  Future<void> _loadPersistentDeviceId() async {
    _persistentDeviceId = _prefs.getString('persistent_device_id');

    if (_persistentDeviceId == null || _persistentDeviceId!.isEmpty) {
      _persistentDeviceId = await _generatePersistentDeviceId();
      await _prefs.setString('persistent_device_id', _persistentDeviceId!);
      debugLog('DeviceService', 'Generated new persistent device ID');
    }
  }

  Future<String> _generatePersistentDeviceId() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        final androidId = androidInfo.id;
        if (androidId != null &&
            androidId.isNotEmpty &&
            androidId != "unknown") {
          return 'ANDROID_${androidId.hashCode.abs()}';
        }
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        final vendorId = iosInfo.identifierForVendor;
        if (vendorId != null && vendorId.isNotEmpty) {
          return 'IOS_${vendorId.hashCode.abs()}';
        }
      }

      final machineInfo = {
        'hostname': Platform.localHostname,
        'platform': Platform.operatingSystem,
        'version': Platform.operatingSystemVersion,
        'timestamp': DateTime.now().microsecondsSinceEpoch,
      };

      final hash = machineInfo.hashCode.abs();
      return 'FA_${hash}_${Random().nextInt(10000)}';
    } catch (e) {
      debugLog('DeviceService', 'Error generating device ID: $e');
      return 'FA_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(10000)}';
    }
  }

  Future<String> getDeviceId() async {
    await ensureInitialized();
    return _persistentDeviceId!;
  }

  Future<void> saveCacheItem<T>(String key, T value,
      {Duration? ttl,
      bool isUserSpecific = false,
      bool notifyListeners = true}) async {
    await ensureInitialized();

    final cacheKey = _getCacheKey(key, isUserSpecific);
    final now = DateTime.now();

    final cacheData = {
      'value': _encodeValue(value),
      'timestamp': now.toIso8601String(),
      'ttl': (ttl ?? _defaultCacheTTL).inSeconds,
      'isUserSpecific': isUserSpecific,
      'type': T.toString(),
    };

    _memoryCache[cacheKey] = cacheData;
    _cacheTimestamps[cacheKey] = now;

    try {
      await _prefs.setString('cache_$cacheKey', json.encode(cacheData));

      if (notifyListeners) {
        _notifyCacheListeners(cacheKey, value);
      }

      debugLog('DeviceService', '💾 Saved cache: $cacheKey');
    } catch (e) {
      debugLog('DeviceService', 'Error saving cache item: $e');
    }
  }

  dynamic _encodeValue(dynamic value) {
    if (value is List) {
      return value.map((item) => _encodeValue(item)).toList();
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
    }
    return value;
  }

  Future<T?> getCacheItem<T>(String key, {bool isUserSpecific = false}) async {
    await ensureInitialized();

    final cacheKey = _getCacheKey(key, isUserSpecific);

    if (_memoryCache.containsKey(cacheKey)) {
      final cacheData = _memoryCache[cacheKey] as Map<String, dynamic>;
      if (_isCacheValid(cacheData)) {
        return _decodeValue<T>(cacheData['value']);
      } else {
        _memoryCache.remove(cacheKey);
        _cacheTimestamps.remove(cacheKey);

        unawaited(_prefs.remove('cache_$cacheKey'));
      }
    }

    try {
      final cachedStr = _prefs.getString('cache_$cacheKey');
      if (cachedStr != null) {
        final cacheData = json.decode(cachedStr) as Map<String, dynamic>;
        if (_isCacheValid(cacheData)) {
          _memoryCache[cacheKey] = cacheData;
          _cacheTimestamps[cacheKey] = DateTime.parse(cacheData['timestamp']);
          return _decodeValue<T>(cacheData['value']);
        } else {
          await _prefs.remove('cache_$cacheKey');
        }
      }
    } catch (e) {
      debugLog('DeviceService', 'Error reading cache item: $e');
      await _prefs.remove('cache_$cacheKey');
    }

    return null;
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

  T? _decodeValue<T>(dynamic value) {
    if (value == null) return null;

    try {
      if (T == String) return value as T;
      if (T == int) return (value as num).toInt() as T;
      if (T == double) return (value as num).toDouble() as T;
      if (T == bool) return value as T;
      if (T == Map<String, dynamic>) return value as T;

      if (value is List && T == List<Subscription>) {
        return value.map((item) => Subscription.fromJson(item)).toList() as T;
      }
      if (value is List && T == List<Payment>) {
        return value.map((item) => Payment.fromJson(item)).toList() as T;
      }
      if (value is List && T == List<Setting>) {
        return value.map((item) => Setting.fromJson(item)).toList() as T;
      }
      if (value is List && T == List<School>) {
        return value.map((item) => School.fromJson(item)).toList() as T;
      }
      if (value is List && T == List<Category>) {
        return value.map((item) => Category.fromJson(item)).toList() as T;
      }
      if (value is List && T == List<Course>) {
        return value.map((item) => Course.fromJson(item)).toList() as T;
      }
      if (value is List && T == List<Chapter>) {
        return value.map((item) => Chapter.fromJson(item)).toList() as T;
      }
      if (value is List && T == List<Exam>) {
        return value.map((item) => Exam.fromJson(item)).toList() as T;
      }

      if (T == Subscription && value is Map) {
        return Subscription.fromJson(value as Map<String, dynamic>) as T;
      }
      if (T == Payment && value is Map) {
        return Payment.fromJson(value as Map<String, dynamic>) as T;
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

      return value as T?;
    } catch (e) {
      debugLog('DeviceService', 'Error decoding value for type $T: $e');
      return null;
    }
  }

  String _getCacheKey(String key, bool isUserSpecific) {
    if (!isUserSpecific || _currentUserId == null) {
      return key;
    }
    return 'user_${_currentUserId}_$key';
  }

  Stream<T?> watchCache<T>(String key, {bool isUserSpecific = false}) {
    final controller = StreamController<T?>.broadcast();
    final cacheKey = _getCacheKey(key, isUserSpecific);

    if (!_cacheListeners.containsKey(cacheKey)) {
      _cacheListeners[cacheKey] = [];
    }
    _cacheListeners[cacheKey]!.add(controller);

    getCacheItem<T>(key, isUserSpecific: isUserSpecific).then((value) {
      if (!controller.isClosed) {
        controller.add(value);
      }
    });

    controller.onCancel = () {
      _cacheListeners[cacheKey]?.remove(controller);
      if (_cacheListeners[cacheKey]?.isEmpty ?? true) {
        _cacheListeners.remove(cacheKey);
      }
      controller.close();
    };

    return controller.stream;
  }

  void _notifyCacheListeners(String cacheKey, dynamic value) {
    if (_cacheListeners.containsKey(cacheKey)) {
      for (final controller in _cacheListeners[cacheKey]!) {
        if (!controller.isClosed) {
          controller.add(value);
        }
      }
    }
  }

  Future<void> removeCacheItem(String key,
      {bool isUserSpecific = false}) async {
    await ensureInitialized();

    final cacheKey = _getCacheKey(key, isUserSpecific);

    _memoryCache.remove(cacheKey);
    _cacheTimestamps.remove(cacheKey);
    await _prefs.remove('cache_$cacheKey');

    _notifyCacheListeners(cacheKey, null);
  }

  Future<void> clearCacheByPrefix(String prefix) async {
    await ensureInitialized();

    for (final key in _memoryCache.keys.toList()) {
      if (key.startsWith(prefix)) {
        _memoryCache.remove(key);
        _cacheTimestamps.remove(key);
      }
    }

    for (final key in _prefs.getKeys()) {
      if (key.startsWith('cache_$prefix')) {
        await _prefs.remove(key);
      }
    }
  }

  Future<void> clearUserCache() async {
    await ensureInitialized();

    debugLog(
        'DeviceService', '🧹 Clearing user cache for user: $_currentUserId');

    for (final key in _memoryCache.keys.toList()) {
      if (key.startsWith('user_${_currentUserId}_')) {
        _memoryCache.remove(key);
        _cacheTimestamps.remove(key);
      }
    }

    for (final key in _prefs.getKeys()) {
      if (key.startsWith('cache_user_${_currentUserId}_')) {
        await _prefs.remove(key);
      }
    }

    debugLog('DeviceService', '✅ User cache cleared');
  }

  Future<void> clearAllCache() async {
    await ensureInitialized();

    debugLog('DeviceService', '🧹 Clearing all cache');

    _memoryCache.clear();
    _cacheTimestamps.clear();
    _cacheListeners.clear();

    final keys = _prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith('cache_')) {
        await _prefs.remove(key);
      }
    }

    debugLog('DeviceService', '✅ All cache cleared');
  }

  Future<void> clearForLogout() async {
    await ensureInitialized();

    debugLog('DeviceService', '🚪 Clearing for logout');

    await clearUserCache();

    final keysToClear = [
      'current_user_id',
      'session_start',
      'token_saved_at',
      'registration_complete',
      'selected_school_id',
      'fcm_token',
      'notifications_enabled'
    ];

    for (final key in keysToClear) {
      await _prefs.remove(key);
    }

    debugLog('DeviceService', '✅ Logout cleanup complete');
  }

  Future<void> setCurrentUserId(String userId) async {
    await ensureInitialized();

    _currentUserId = userId;
    await _prefs.setString('current_user_id', userId);
    debugLog('DeviceService', '👤 Current user ID set to: $userId');
  }

  Future<void> clearCurrentUserId() async {
    await ensureInitialized();

    _currentUserId = null;
    await _prefs.remove('current_user_id');
    debugLog('DeviceService', '👤 Current user ID cleared');
  }

  Future<void> _loadCurrentUserId() async {
    _currentUserId = _prefs.getString('current_user_id');
    if (_currentUserId != null) {
      debugLog('DeviceService', '👤 Loaded current user ID: $_currentUserId');
    }
  }

  Future<Map<String, dynamic>> getDeviceInfo() async {
    await ensureInitialized();

    final deviceId = await getDeviceId();
    final Map<String, dynamic> info = {
      'device_id': deviceId,
      'platform': Platform.operatingSystem,
      'platform_version': Platform.operatingSystemVersion,
      'app_version': AppConstants.appVersion,
    };

    try {
      if (Platform.isAndroid) {
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
      } else if (Platform.isIOS) {
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
      debugLog('DeviceService', 'getDeviceInfo error: $e');
    }

    return info;
  }

  Future<bool> isTablet() async {
    await ensureInitialized();

    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        final model = androidInfo.model?.toLowerCase() ?? '';
        return model.contains('tab') ||
            model.contains('pad') ||
            model.contains('tablet');
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.model?.toLowerCase().contains('ipad') ?? false;
      }
    } catch (e) {
      debugLog('DeviceService', 'isTablet check error: $e');
    }
    return false;
  }

  Future<void> saveTvDeviceId(String deviceId) async {
    await ensureInitialized();

    debugLog('DeviceService', '📺 Saving TV device id: $deviceId');
    await _prefs.setString('tv_device_id', deviceId);
  }

  Future<String?> getTvDeviceId() async {
    await ensureInitialized();

    final id = _prefs.getString('tv_device_id');
    return id;
  }

  Future<void> clearTvDeviceId() async {
    await ensureInitialized();

    debugLog('DeviceService', '📺 Clearing TV device id');
    await _prefs.remove('tv_device_id');
  }

  Future<void> cleanExpiredCache() async {
    await ensureInitialized();

    final now = DateTime.now();
    final expiredKeys = <String>[];

    for (final entry in _cacheTimestamps.entries) {
      final cacheKey = entry.key;
      final timestamp = entry.value;

      if (_memoryCache.containsKey(cacheKey)) {
        final cacheData = _memoryCache[cacheKey] as Map<String, dynamic>;
        final ttl =
            Duration(seconds: cacheData['ttl'] ?? _defaultCacheTTL.inSeconds);

        if (now.difference(timestamp) > ttl) {
          expiredKeys.add(cacheKey);
        }
      }
    }

    for (final key in expiredKeys) {
      _memoryCache.remove(key);
      _cacheTimestamps.remove(key);
      await _prefs.remove('cache_$key');
    }

    if (expiredKeys.isNotEmpty) {
      debugLog('DeviceService',
          '🧹 Cleaned ${expiredKeys.length} expired cache items');
    }
  }

  Map<String, dynamic> getCacheStats() {
    return {
      'memory_cache_size': _memoryCache.length,
      'cache_timestamps_size': _cacheTimestamps.length,
      'cache_listeners': _cacheListeners.length,
      'current_user_id': _currentUserId,
      'device_id': _persistentDeviceId,
      'initialized': _initialized,
    };
  }
}

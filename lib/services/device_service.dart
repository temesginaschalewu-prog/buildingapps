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
import 'package:familyacademyclient/services/platform_service.dart';
import 'package:familyacademyclient/services/user_session.dart';
import 'package:familyacademyclient/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/helpers.dart';

class DeviceService {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  late SharedPreferences _prefs;
  static String? _persistentDeviceId;
  bool _initialized = false;
  Completer<void>? _initializationCompleter;

  final _initMutex = Lock();

  bool get isInitialized => _initialized;

  final Map<String, dynamic> _memoryCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _defaultCacheTTL = AppConstants.defaultCacheTTL;

  String? _currentUserId;
  final Map<String, List<StreamController>> _cacheListeners = {};

  DeviceService();

  Future<void> init() async {
    return _initMutex.synchronized(() async {
      debugLog('DeviceService', '🔄 init() started (mutex locked)');

      if (_initialized) {
        debugLog(
            'DeviceService', '✅ Already initialized, returning immediately');
        return;
      }

      if (_initializationCompleter != null) {
        debugLog(
            'DeviceService', '⏳ Already initializing, waiting with timeout...');
        try {
          await _initializationCompleter!.future.timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              debugLog('DeviceService',
                  '⚠️ Initialization timeout, recreating completer');
              _initializationCompleter = Completer<void>();
              return null;
            },
          );
          debugLog('DeviceService', '✅ Wait completed successfully');
          return;
        } catch (e) {
          debugLog('DeviceService', '❌ Wait failed: $e');
        }
      }

      _initializationCompleter = Completer<void>();
      debugLog('DeviceService', '📝 Created initialization completer');

      try {
        debugLog('DeviceService', 'Step 1: Getting SharedPreferences');
        _prefs = await SharedPreferences.getInstance();
        debugLog('DeviceService', '✅ Got SharedPreferences');

        debugLog('DeviceService', 'Step 2: Loading persistent device ID');
        await _loadPersistentDeviceId();
        debugLog('DeviceService',
            '✅ Loaded persistent device ID: $_persistentDeviceId');

        debugLog('DeviceService', 'Step 3: Loading current user ID');
        await _loadCurrentUserId();
        debugLog('DeviceService', '✅ Loaded current user ID: $_currentUserId');

        debugLog('DeviceService', 'Step 4: Loading cache from prefs');
        await _loadCacheFromPrefs();
        debugLog('DeviceService',
            '✅ Loaded cache with ${_memoryCache.length} items');

        debugLog('DeviceService', 'Step 5: Cleaning expired cache');
        await cleanExpiredCache();
        debugLog('DeviceService', '✅ Cleaned expired cache');

        _initialized = true;
        debugLog('DeviceService',
            '✅ Initialization complete - Device ID: $_persistentDeviceId, Cache: ${_memoryCache.length} items');

        if (_initializationCompleter != null &&
            !_initializationCompleter!.isCompleted) {
          _initializationCompleter!.complete();
        }
      } catch (e, stackTrace) {
        debugLog('DeviceService', '❌ Initialization error: $e');
        debugLog('DeviceService', 'Stack trace: $stackTrace');

        _persistentDeviceId =
            'fallback_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
        _initialized = true;
        debugLog('DeviceService',
            '⚠️ Using fallback device ID: $_persistentDeviceId');

        if (_initializationCompleter != null &&
            !_initializationCompleter!.isCompleted) {
          _initializationCompleter!.complete();
        } else {
          debugLog('DeviceService',
              '⚠️ Completer already completed or null - creating new completer');
          _initializationCompleter = Completer<void>();
          _initializationCompleter!.complete();
        }
      }
    });
  }

  Future<void> ensureInitialized() async {
    if (!_initialized) {
      debugLog(
          'DeviceService', '⚠️ ensureInitialized called - initializing...');
      await init();
    } else {
      debugLog('DeviceService', '✅ ensureInitialized - already initialized');
    }
  }

  Future<void> _loadCacheFromPrefs() async {
    try {
      final keys = _prefs.getKeys();
      int loadedCount = 0;

      _memoryCache.clear();
      _cacheTimestamps.clear();

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
                loadedCount++;
              } else {
                debugLog('DeviceService', '🗑️ Removing expired cache: $key');
                await _prefs.remove(key);
              }
            } catch (e) {
              debugLog('DeviceService', 'Error loading cache key $key: $e');
              await _prefs.remove(key);
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
    _persistentDeviceId = _prefs.getString(AppConstants.persistentDeviceIdKey);

    if (_persistentDeviceId == null || _persistentDeviceId!.isEmpty) {
      debugLog(
          'DeviceService', 'No persistent device ID found, generating new one');
      _persistentDeviceId = await _generatePersistentDeviceId();
      await _prefs.setString(
          AppConstants.persistentDeviceIdKey, _persistentDeviceId!);
      debugLog('DeviceService',
          'Generated new persistent device ID: $_persistentDeviceId');
    } else {
      debugLog('DeviceService',
          'Found existing persistent device ID: $_persistentDeviceId');
    }
  }

  Future<String> _generatePersistentDeviceId() async {
    try {
      if (PlatformService.isAndroid) {
        debugLog('DeviceService', 'Generating Android device ID');
        final androidInfo = await _deviceInfo.androidInfo;
        final androidId = androidInfo.id;
        if (androidId.isNotEmpty && androidId != 'unknown') {
          return '${AppConstants.androidDevicePrefix}${androidId.hashCode.abs()}';
        }
      } else if (PlatformService.isIOS) {
        debugLog('DeviceService', 'Generating iOS device ID');
        final iosInfo = await _deviceInfo.iosInfo;
        final vendorId = iosInfo.identifierForVendor;
        if (vendorId != null && vendorId.isNotEmpty) {
          return '${AppConstants.iosDevicePrefix}${vendorId.hashCode.abs()}';
        }
      }

      debugLog(
          'DeviceService', 'Using fallback device ID generation for desktop');
      final machineInfo = {
        'hostname': Platform.localHostname,
        'platform': Platform.operatingSystem,
        'version': Platform.operatingSystemVersion,
        'timestamp': DateTime.now().microsecondsSinceEpoch,
      };

      final hash = machineInfo.hashCode.abs();
      return '${AppConstants.fallbackDevicePrefix}${hash}_${Random().nextInt(10000)}';
    } catch (e) {
      debugLog('DeviceService', 'Error generating device ID: $e');
      return '${AppConstants.fallbackDevicePrefix}${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
    }
  }

  Future<String> getDeviceId() async {
    await ensureInitialized();
    return _persistentDeviceId ??
        'unknown_${DateTime.now().millisecondsSinceEpoch}';
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
      'ttl': (ttl ?? _getDefaultTTLForType(T.toString())).inSeconds,
      'isUserSpecific': isUserSpecific,
      'type': T.toString(),
    };

    _memoryCache[cacheKey] = cacheData;
    _cacheTimestamps[cacheKey] = now;

    try {
      await _prefs.setString(
          '${AppConstants.cachePrefix}$cacheKey', json.encode(cacheData));

      if (notifyListeners) {
        _notifyCacheListeners(cacheKey, value);
      }

      debugLog('DeviceService', '💾 Saved cache: $cacheKey');
    } catch (e) {
      debugLog('DeviceService', 'Error saving cache item: $e');
    }
  }

  Duration _getDefaultTTLForType(String type) {
    if (type.contains('Category')) return AppConstants.cacheTTLCategories;
    if (type.contains('Course')) return AppConstants.cacheTTLCourses;
    if (type.contains('Chapter')) return AppConstants.cacheTTLChapters;
    if (type.contains('Video')) return AppConstants.cacheTTLVideos;
    if (type.contains('Note')) return AppConstants.cacheTTLNotes;
    if (type.contains('Exam')) return AppConstants.cacheTTLExams;
    if (type.contains('Question')) return AppConstants.cacheTTLQuestions;
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
        await _prefs.remove('${AppConstants.cachePrefix}$cacheKey');
      }
    }

    try {
      final cachedStr =
          _prefs.getString('${AppConstants.cachePrefix}$cacheKey');
      if (cachedStr != null) {
        final cacheData = json.decode(cachedStr) as Map<String, dynamic>;
        if (_isCacheValid(cacheData)) {
          _memoryCache[cacheKey] = cacheData;
          _cacheTimestamps[cacheKey] = DateTime.parse(cacheData['timestamp']);
          return _decodeValue<T>(cacheData['value']);
        } else {
          await _prefs.remove('${AppConstants.cachePrefix}$cacheKey');
        }
      }
    } catch (e) {
      debugLog('DeviceService', 'Error reading cache item: $e');
      await _prefs.remove('${AppConstants.cachePrefix}$cacheKey');
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

      if (value is List) {
        if (T == List<Subscription>) {
          final result = <Subscription>[];
          for (final item in value) {
            try {
              if (item is Map<String, dynamic>) {
                result.add(Subscription.fromJson(item));
              } else if (item is Subscription) {
                result.add(item);
              }
            } catch (e) {
              debugLog('DeviceService', 'Error parsing Subscription: $e');
            }
          }
          return result as T;
        }
        if (T == List<Payment>) {
          final result = <Payment>[];
          for (final item in value) {
            try {
              if (item is Map<String, dynamic>) {
                result.add(Payment.fromJson(item));
              } else if (item is Payment) {
                result.add(item);
              }
            } catch (e) {
              debugLog('DeviceService', 'Error parsing Payment: $e');
            }
          }
          return result as T;
        }
        if (T == List<Notification>) {
          final result = <Notification>[];
          for (final item in value) {
            try {
              if (item is Map<String, dynamic>) {
                result.add(Notification.fromJson(item));
              } else if (item is Notification) {
                result.add(item);
              }
            } catch (e) {
              debugLog('DeviceService', 'Error parsing Notification: $e');
            }
          }
          return result as T;
        }
        if (T == List<Setting>) {
          final result = <Setting>[];
          for (final item in value) {
            try {
              if (item is Map<String, dynamic>) {
                result.add(Setting.fromJson(item));
              } else if (item is Setting) {
                result.add(item);
              }
            } catch (e) {
              debugLog('DeviceService', 'Error parsing Setting: $e');
            }
          }
          return result as T;
        }
        if (T == List<School>) {
          final result = <School>[];
          for (final item in value) {
            try {
              if (item is Map<String, dynamic>) {
                result.add(School.fromJson(item));
              } else if (item is School) {
                result.add(item);
              }
            } catch (e) {
              debugLog('DeviceService', 'Error parsing School: $e');
            }
          }
          return result as T;
        }
        if (T == List<Category>) {
          final result = <Category>[];
          for (final item in value) {
            try {
              if (item is Map<String, dynamic>) {
                result.add(Category.fromJson(item));
              } else if (item is Category) {
                result.add(item);
              }
            } catch (e) {
              debugLog('DeviceService', 'Error parsing Category: $e');
            }
          }
          return result as T;
        }
        if (T == List<Course>) {
          final result = <Course>[];
          for (final item in value) {
            try {
              if (item is Map<String, dynamic>) {
                result.add(Course.fromJson(item));
              } else if (item is Course) {
                result.add(item);
              }
            } catch (e) {
              debugLog('DeviceService', 'Error parsing Course: $e');
            }
          }
          return result as T;
        }
        if (T == List<Chapter>) {
          final result = <Chapter>[];
          for (final item in value) {
            try {
              if (item is Map<String, dynamic>) {
                result.add(Chapter.fromJson(item));
              } else if (item is Chapter) {
                result.add(item);
              }
            } catch (e) {
              debugLog('DeviceService', 'Error parsing Chapter: $e');
            }
          }
          return result as T;
        }
        if (T == List<Exam>) {
          final result = <Exam>[];
          for (final item in value) {
            try {
              if (item is Map<String, dynamic>) {
                result.add(Exam.fromJson(item));
              } else if (item is Exam) {
                result.add(item);
              }
            } catch (e) {
              debugLog('DeviceService', 'Error parsing Exam: $e');
            }
          }
          return result as T;
        }
        if (T == List<ExamResult>) {
          final result = <ExamResult>[];
          for (final item in value) {
            try {
              if (item is Map<String, dynamic>) {
                result.add(ExamResult.fromJson(item));
              } else if (item is ExamResult) {
                result.add(item);
              }
            } catch (e) {
              debugLog('DeviceService', 'Error parsing ExamResult: $e');
            }
          }
          return result as T;
        }
        if (T == List<UserProgress>) {
          final result = <UserProgress>[];
          for (final item in value) {
            try {
              if (item is Map<String, dynamic>) {
                result.add(UserProgress.fromJson(item));
              } else if (item is UserProgress) {
                result.add(item);
              }
            } catch (e) {
              debugLog('DeviceService', 'Error parsing UserProgress: $e');
            }
          }
          return result as T;
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
    await _prefs.remove('${AppConstants.cachePrefix}$cacheKey');

    _notifyCacheListeners(cacheKey, null);
  }

  Future<void> clearCacheByPrefix(String prefix) async {
    await ensureInitialized();

    final session = UserSession();
    if (!session.shouldClearCache('clear_by_prefix')) {
      debugLog(
          'DeviceService', '⚠️ Skipping clearCacheByPrefix - not authorized');
      return;
    }

    final keysToRemove = <String>[];

    for (final key in _memoryCache.keys.toList()) {
      if (key.startsWith(prefix) ||
          (prefix.contains('_') && key.contains(prefix))) {
        keysToRemove.add(key);
        _memoryCache.remove(key);
        _cacheTimestamps.remove(key);
      }
    }

    for (final key in _prefs.getKeys()) {
      if (key.startsWith('${AppConstants.cachePrefix}$prefix') ||
          (prefix.contains('_') && key.contains(prefix))) {
        await _prefs.remove(key);
      }
    }

    debugLog('DeviceService',
        '🧹 Cleared ${keysToRemove.length} cache items with prefix: $prefix');
  }

  Future<void> clearOldUserCache(String oldUserId) async {
    await ensureInitialized();

    debugLog('DeviceService', '🔄 Clearing cache for old user: $oldUserId');

    int clearedCount = 0;

    for (final key in _memoryCache.keys.toList()) {
      if (key.startsWith('user_${oldUserId}_')) {
        _memoryCache.remove(key);
        _cacheTimestamps.remove(key);
        clearedCount++;
      }
    }

    for (final key in _prefs.getKeys()) {
      if (key.startsWith('${AppConstants.cachePrefix}user_${oldUserId}_')) {
        await _prefs.remove(key);
        clearedCount++;
      }
    }

    debugLog(
        'DeviceService', '✅ Cleared $clearedCount cache items for old user');
  }

  Future<void> clearCurrentUserCache() async {
    await ensureInitialized();

    final session = UserSession();
    final isDifferentUser = !await session.isSameUser();

    if (!isDifferentUser) {
      debugLog('DeviceService', '✅ Same user - preserving current user cache');
      return;
    }

    debugLog(
        'DeviceService', '🔄 Different user - clearing current user cache');

    int clearedCount = 0;

    if (_currentUserId != null) {
      for (final key in _memoryCache.keys.toList()) {
        if (key.startsWith('user_${_currentUserId}_')) {
          _memoryCache.remove(key);
          _cacheTimestamps.remove(key);
          clearedCount++;
        }
      }

      for (final key in _prefs.getKeys()) {
        if (key
            .startsWith('${AppConstants.cachePrefix}user_${_currentUserId}_')) {
          await _prefs.remove(key);
          clearedCount++;
        }
      }
    }

    debugLog('DeviceService',
        '✅ Cleared $clearedCount cache items for current user');
  }

  Future<void> setCurrentUserId(String userId) async {
    await ensureInitialized();
    debugLog('DeviceService', '👤 Setting current user ID to: $userId');
    _currentUserId = userId;
    await _prefs.setString(AppConstants.currentUserIdKey, userId);
    debugLog('DeviceService', '✅ Current user ID set to: $userId');
  }

  Future<void> clearCurrentUserId() async {
    await ensureInitialized();
    debugLog('DeviceService', '👤 Clearing current user ID');
    _currentUserId = null;
    await _prefs.remove(AppConstants.currentUserIdKey);
    debugLog('DeviceService', '✅ Current user ID cleared');
  }

  Future<void> _loadCurrentUserId() async {
    _currentUserId = _prefs.getString(AppConstants.currentUserIdKey);
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
      if (PlatformService.isAndroid) {
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
      } else if (PlatformService.isIOS) {
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
      if (PlatformService.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        final model = androidInfo.model.toLowerCase();
        return model.contains('tab') ||
            model.contains('pad') ||
            model.contains('tablet');
      } else if (PlatformService.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.model.toLowerCase().contains('ipad');
      }
    } catch (e) {
      debugLog('DeviceService', 'isTablet check error: $e');
    }
    return false;
  }

  Future<void> saveTvDeviceId(String deviceId) async {
    await ensureInitialized();

    debugLog('DeviceService', '📺 Saving TV device id: $deviceId');
    await _prefs.setString(AppConstants.tvDeviceIdKey, deviceId);
  }

  Future<String?> getTvDeviceId() async {
    await ensureInitialized();

    final id = _prefs.getString(AppConstants.tvDeviceIdKey);
    return id;
  }

  Future<void> clearTvDeviceId() async {
    await ensureInitialized();

    debugLog('DeviceService', '📺 Clearing TV device id');
    await _prefs.remove(AppConstants.tvDeviceIdKey);
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
      await _prefs.remove('${AppConstants.cachePrefix}$key');
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

class Lock {
  bool _locked = false;
  final List<Completer> _queue = [];

  Future<T> synchronized<T>(Future<T> Function() action) async {
    if (_locked) {
      final completer = Completer<void>();
      _queue.add(completer);
      await completer.future;
    }
    _locked = true;
    try {
      return await action();
    } finally {
      _locked = false;
      if (_queue.isNotEmpty) {
        _queue.removeAt(0).complete();
      }
    }
  }
}

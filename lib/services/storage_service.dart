import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:familyacademyclient/services/user_session.dart';
import 'package:familyacademyclient/services/platform_service.dart';
import 'package:familyacademyclient/services/device_service.dart';
import '../utils/constants.dart';
import '../models/user_model.dart';
import '../utils/helpers.dart';

class StorageService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  late SharedPreferences _prefs;
  bool _initialized = false;
  final Map<String, dynamic> _memoryCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _defaultCacheTTL = AppConstants.defaultCacheTTL;

  DeviceService? _deviceService;

  bool get isInitialized => _initialized;

  void setDeviceService(DeviceService deviceService) {
    _deviceService = deviceService;
    debugLog('StorageService', '✅ DeviceService reference set');
  }

  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    await _migrateOldCache();
    _initialized = true;
    debugLog('StorageService', '✅ Initialized');
  }

  Future<void> _migrateOldCache() async {
    try {
      final keys = _prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith('cache_') && !key.contains('offline_')) {
          final value = _prefs.getString(key);
          if (value != null) {
            final newKey = key.replaceFirst('cache_', 'offline_');
            await _prefs.setString(newKey, value);
            await _prefs.remove(key);
          }
        }
      }
    } catch (e) {}
  }

  Future<void> ensureInitialized() async {
    if (!_initialized) await init();
  }

  Future<void> saveToken(String token) async {
    await ensureInitialized();
    if (!PlatformService.isMobile) {
      await _prefs.setString(AppConstants.tokenKey, token);
    } else {
      await _secureStorage.write(key: AppConstants.tokenKey, value: token);
    }
    await _setLastUpdate('token');
  }

  Future<String?> getToken() async {
    await ensureInitialized();
    if (!PlatformService.isMobile) {
      return _prefs.getString(AppConstants.tokenKey);
    }
    try {
      return await _secureStorage.read(key: AppConstants.tokenKey);
    } catch (e) {
      return null;
    }
  }

  Future<void> saveRefreshToken(String refreshToken) async {
    await ensureInitialized();
    if (!PlatformService.isMobile) {
      await _prefs.setString(AppConstants.refreshTokenKey, refreshToken);
    } else {
      await _secureStorage.write(
          key: AppConstants.refreshTokenKey, value: refreshToken);
    }
  }

  Future<String?> getRefreshToken() async {
    await ensureInitialized();
    if (!PlatformService.isMobile) {
      return _prefs.getString(AppConstants.refreshTokenKey);
    }
    return _secureStorage.read(key: AppConstants.refreshTokenKey);
  }

  Future<void> clearTokens() async {
    await ensureInitialized();
    if (!PlatformService.isMobile) {
      await _prefs.remove(AppConstants.tokenKey);
      await _prefs.remove(AppConstants.refreshTokenKey);
    } else {
      await _secureStorage.delete(key: AppConstants.tokenKey);
      await _secureStorage.delete(key: AppConstants.refreshTokenKey);
    }
    await _prefs.remove('last_update_token');
  }

  Future<void> saveUser(User user) async {
    await ensureInitialized();
    final userJson = json.encode(user.toJson());
    await _saveOfflineData(AppConstants.userDataKey, userJson);

    if (_deviceService != null) {
      await _deviceService!.saveCacheItem(
        'user_profile',
        user,
        ttl: AppConstants.cacheTTLUserProfile,
        isUserSpecific: true,
      );
      debugLog('StorageService', '💾 Also saved user to DeviceService cache');
    }

    await _setLastUpdate('user');
  }

  Future<User?> getUser() async {
    await ensureInitialized();

    if (_deviceService != null) {
      final cachedUser = await _deviceService!.getCacheItem<User>(
        'user_profile',
        isUserSpecific: true,
      );
      if (cachedUser != null) {
        debugLog('StorageService', '✅ Loaded user from DeviceService cache');
        return cachedUser;
      }
    }

    final userJson = await _getOfflineData<String>(AppConstants.userDataKey);
    if (userJson != null) {
      try {
        return User.fromJson(json.decode(userJson));
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  Future<void> clearUser() async {
    await ensureInitialized();
    await _removeOfflineData(AppConstants.userDataKey);
    await _prefs.remove('session_start');
  }

  Future<void> _saveOfflineData<T>(String key, T value, {Duration? ttl}) async {
    await ensureInitialized();
    final cacheData = {
      'value': value,
      'timestamp': DateTime.now().toIso8601String(),
      'ttl': (ttl ?? _getDefaultTTLForKey(key)).inSeconds,
      'synced': true,
    };
    _memoryCache[key] = cacheData;
    _cacheTimestamps[key] = DateTime.now();
    try {
      await _prefs.setString('offline_$key', json.encode(cacheData));
    } catch (e) {}
  }

  Duration _getDefaultTTLForKey(String key) {
    if (key.contains('categories')) return AppConstants.cacheTTLCategories;
    if (key.contains('courses')) return AppConstants.cacheTTLCourses;
    if (key.contains('chapters')) return AppConstants.cacheTTLChapters;
    if (key.contains('videos')) return AppConstants.cacheTTLVideos;
    if (key.contains('notes')) return AppConstants.cacheTTLNotes;
    if (key.contains('exams')) return AppConstants.cacheTTLExams;
    if (key.contains('questions')) return AppConstants.cacheTTLQuestions;
    if (key.contains('subscriptions'))
      return AppConstants.cacheTTLSubscriptions;
    if (key.contains('payments')) return AppConstants.cacheTTLPayments;
    if (key.contains('notifications'))
      return AppConstants.cacheTTLNotifications;
    if (key.contains('streak')) return AppConstants.cacheTTLStreak;
    if (key.contains('schools')) return AppConstants.cacheTTLSchools;
    if (key.contains('settings')) return AppConstants.cacheTTLSettings;
    if (key.contains('user')) return AppConstants.cacheTTLUserProfile;
    return _defaultCacheTTL;
  }

  Future<T?> _getOfflineData<T>(String key) async {
    await ensureInitialized();
    if (_memoryCache.containsKey(key)) {
      final cacheData = _memoryCache[key] as Map<String, dynamic>;
      if (_isCacheValid(cacheData)) {
        return cacheData['value'] as T;
      } else {
        _memoryCache.remove(key);
        _cacheTimestamps.remove(key);
      }
    }
    try {
      final cachedStr = _prefs.getString('offline_$key');
      if (cachedStr != null) {
        final cacheData = json.decode(cachedStr) as Map<String, dynamic>;
        if (_isCacheValid(cacheData)) {
          _memoryCache[key] = cacheData;
          _cacheTimestamps[key] = DateTime.parse(cacheData['timestamp']);
          return cacheData['value'] as T;
        } else {
          await _prefs.remove('offline_$key');
        }
      }
    } catch (e) {
      await _prefs.remove('offline_$key');
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

  Future<void> _removeOfflineData(String key) async {
    await ensureInitialized();
    _memoryCache.remove(key);
    _cacheTimestamps.remove(key);
    await _prefs.remove('offline_$key');
  }

  Future<void> saveData<T>(String key, T data,
      {Duration? ttl, bool syncWithBackend = false}) async {
    await ensureInitialized();
    final cacheData = {
      'value': data,
      'timestamp': DateTime.now().toIso8601String(),
      'ttl': (ttl ?? _getDefaultTTLForKey(key)).inSeconds,
      'synced': !syncWithBackend,
    };
    if (data is Map || data is List) {
      await _prefs.setString('data_$key', json.encode(cacheData));
    } else if (data is String) {
      await _prefs.setString('data_$key', json.encode(cacheData));
    } else if (data is int) {
      await _prefs.setInt('data_$key', data);
    } else if (data is double) {
      await _prefs.setDouble('data_$key', data);
    } else if (data is bool) {
      await _prefs.setBool('data_$key', data);
    }
  }

  Future<T?> getData<T>(String key) async {
    await ensureInitialized();
    try {
      if (T == Map || T == List) {
        final cachedStr = _prefs.getString('data_$key');
        if (cachedStr != null) {
          final cacheData = json.decode(cachedStr) as Map<String, dynamic>;
          if (_isCacheValid(cacheData)) {
            return cacheData['value'] as T;
          } else {
            await _prefs.remove('data_$key');
          }
        }
      } else if (T == String) {
        return _prefs.getString('data_$key') as T?;
      } else if (T == int) {
        return _prefs.getInt('data_$key') as T?;
      } else if (T == double) {
        return _prefs.getDouble('data_$key') as T?;
      } else if (T == bool) {
        return _prefs.getBool('data_$key') as T?;
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  Future<void> removeData(String key) async {
    await ensureInitialized();
    await _prefs.remove('data_$key');
  }

  Future<void> saveSessionStart() async {
    await ensureInitialized();
    await _prefs.setString(
        AppConstants.sessionStartKey, DateTime.now().toIso8601String());
  }

  Future<bool> isSessionValid(Duration sessionDuration) async {
    await ensureInitialized();
    final sessionStartStr = _prefs.getString(AppConstants.sessionStartKey);
    if (sessionStartStr == null) {
      return true;
    }
    try {
      final sessionStart = DateTime.parse(sessionStartStr);
      final sessionAge = DateTime.now().difference(sessionStart);
      return sessionAge <= sessionDuration;
    } catch (e) {
      return true;
    }
  }

  Future<void> saveSelectedSchool(int schoolId) async {
    await ensureInitialized();
    await _prefs.setInt(AppConstants.selectedSchoolIdKey, schoolId);
    await _setLastUpdate('school');
  }

  Future<int?> getSelectedSchool() async {
    await ensureInitialized();
    return _prefs.getInt(AppConstants.selectedSchoolIdKey);
  }

  Future<void> clearSelectedSchool() async {
    await ensureInitialized();
    await _prefs.remove(AppConstants.selectedSchoolIdKey);
  }

  Future<void> saveFcmToken(String fcmToken) async {
    await ensureInitialized();
    await _prefs.setString(AppConstants.fcmTokenCacheKey, fcmToken);
  }

  Future<String?> getFcmToken() async {
    await ensureInitialized();
    return _prefs.getString(AppConstants.fcmTokenCacheKey);
  }

  Future<void> saveNotificationPreferences(bool enabled) async {
    await ensureInitialized();
    await _prefs.setBool(AppConstants.notificationsEnabledKey, enabled);
  }

  Future<bool> getNotificationPreferences() async {
    await ensureInitialized();
    return _prefs.getBool(AppConstants.notificationsEnabledKey) ?? true;
  }

  Future<bool> hasCompletedRegistration() async {
    await ensureInitialized();
    return _prefs.getBool(AppConstants.registrationCompleteKey) ?? false;
  }

  Future<void> markRegistrationComplete() async {
    await ensureInitialized();
    await _prefs.setBool(AppConstants.registrationCompleteKey, true);
  }

  Future<void> clearRegistrationComplete() async {
    await ensureInitialized();
    await _prefs.remove(AppConstants.registrationCompleteKey);
  }

  Future<void> _setLastUpdate(String type) async {
    await ensureInitialized();
    await _prefs.setString(
        'last_update_$type', DateTime.now().toIso8601String());
  }

  Future<DateTime?> getLastUpdate(String type) async {
    await ensureInitialized();
    final lastUpdateStr = _prefs.getString('last_update_$type');
    if (lastUpdateStr != null) {
      try {
        return DateTime.parse(lastUpdateStr);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  Future<void> clearAllUserData() async {
    debugLog('StorageService', '⚠️ clearAllUserData called!');
    await ensureInitialized();
    final session = UserSession();
    final isDifferentUser = !await session.isSameUser();
    if (!isDifferentUser) {
      debugLog('StorageService', '✅ Same user - preserving data');
      return;
    }

    final oldUserId = await session.getOldUserIdToClear();
    debugLog('StorageService', 'Clearing data for old user: $oldUserId');

    if (oldUserId != null && PlatformService.isMobile) {
      try {
        await _secureStorage.deleteAll();
      } catch (e) {}
    }

    final keys = _prefs.getKeys();
    int removedCount = 0;
    for (final key in keys) {
      if (key.startsWith('user_') ||
          key == AppConstants.userDataKey ||
          key == AppConstants.sessionStartKey ||
          key == AppConstants.registrationCompleteKey ||
          key == AppConstants.selectedSchoolIdKey ||
          key.startsWith('last_update_') ||
          key.startsWith(AppConstants.offlineQueueKey) ||
          key.startsWith('pending_')) {
        if (oldUserId == null ||
            key.contains(oldUserId) ||
            !key.contains('_')) {
          await _prefs.remove(key);
          removedCount++;
        }
      }
    }
    debugLog('StorageService', '🧹 Removed $removedCount keys from prefs');

    if (oldUserId != null) {
      final keysToRemove =
          _memoryCache.keys.where((k) => k.contains(oldUserId)).toList();
      for (final key in keysToRemove) {
        _memoryCache.remove(key);
        _cacheTimestamps.remove(key);
      }
      debugLog('StorageService',
          '🧹 Removed ${keysToRemove.length} items from memory cache');
    }
  }

  Future<Map<String, dynamic>> getStorageStats() async {
    await ensureInitialized();
    final keys = _prefs.getKeys();
    int offlineCount = 0;
    int dataCount = 0;
    int otherCount = 0;
    for (final key in keys) {
      if (key.startsWith('offline_')) {
        offlineCount++;
      } else if (key.startsWith('data_')) {
        dataCount++;
      } else {
        otherCount++;
      }
    }
    return {
      'total_keys': keys.length,
      'offline_data': offlineCount,
      'app_data': dataCount,
      'other_data': otherCount,
      'memory_cache': _memoryCache.length,
      'has_token': (await getToken()) != null,
      'has_user': (await getUser()) != null,
      'initialized': _initialized,
      'platform': PlatformService.platformName,
    };
  }

  Future<void> clearExpiredCache() async {
    await ensureInitialized();
    final keys = _prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith('offline_') || key.startsWith('data_')) {
        try {
          final cachedStr = _prefs.getString(key);
          if (cachedStr != null) {
            final cacheData = json.decode(cachedStr) as Map<String, dynamic>;
            if (!_isCacheValid(cacheData)) {
              await _prefs.remove(key);
            }
          }
        } catch (e) {
          await _prefs.remove(key);
        }
      }
    }
    final expiredKeys = <String>[];
    for (final entry in _cacheTimestamps.entries) {
      if (_memoryCache.containsKey(entry.key)) {
        final cacheData = _memoryCache[entry.key] as Map<String, dynamic>;
        if (!_isCacheValid(cacheData)) {
          expiredKeys.add(entry.key);
        }
      }
    }
    for (final key in expiredKeys) {
      _memoryCache.remove(key);
      _cacheTimestamps.remove(key);
    }
  }

  Future<void> clearCacheByPrefix(String prefix) async {
    await ensureInitialized();
    final session = UserSession();
    if (!session.shouldClearCache('clear_by_prefix')) return;

    final keys = _prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith('offline_$prefix') || key.startsWith('data_$prefix')) {
        await _prefs.remove(key);
        final memoryKey =
            key.replaceFirst('offline_', '').replaceFirst('data_', '');
        _memoryCache.remove(memoryKey);
        _cacheTimestamps.remove(memoryKey);
      }
    }
  }
}

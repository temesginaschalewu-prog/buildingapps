import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:familyacademyclient/services/user_session.dart';
import '../utils/constants.dart';
import '../models/user_model.dart';
import '../utils/helpers.dart';

class StorageService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  late SharedPreferences _prefs;
  bool _initialized = false;
  final Map<String, dynamic> _memoryCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _defaultCacheTTL = Duration(days: 7);

  Future<void> init() async {
    if (_initialized) return;

    debugLog('StorageService', '🔄 Initializing storage service');
    _prefs = await SharedPreferences.getInstance();

    await _migrateOldCache();

    _initialized = true;
    debugLog('StorageService', '✅ Storage service initialized');
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
            debugLog('StorageService', 'Migrated cache key: $key -> $newKey');
          }
        }
      }
    } catch (e) {
      debugLog('StorageService', 'Cache migration error: $e');
    }
  }

  Future<void> ensureInitialized() async {
    if (!_initialized) await init();
  }

  Future<void> saveToken(String token) async {
    await ensureInitialized();
    await _secureStorage.write(key: AppConstants.tokenKey, value: token);
    await _setLastUpdate('token');
    debugLog('StorageService', '✅ Token saved');
  }

  Future<String?> getToken() async {
    await ensureInitialized();
    return _secureStorage.read(key: AppConstants.tokenKey);
  }

  Future<void> saveRefreshToken(String refreshToken) async {
    await ensureInitialized();
    await _secureStorage.write(
        key: AppConstants.refreshTokenKey, value: refreshToken);
    debugLog('StorageService', '✅ Refresh token saved');
  }

  Future<String?> getRefreshToken() async {
    await ensureInitialized();
    return _secureStorage.read(key: AppConstants.refreshTokenKey);
  }

  Future<void> clearTokens() async {
    await ensureInitialized();
    await _secureStorage.delete(key: AppConstants.tokenKey);
    await _secureStorage.delete(key: AppConstants.refreshTokenKey);
    await _prefs.remove('last_update_token');
    debugLog('StorageService', '✅ Tokens cleared');
  }

  Future<void> saveUser(User user) async {
    await ensureInitialized();
    final userJson = json.encode(user.toJson());
    await _saveOfflineData(AppConstants.userDataKey, userJson);
    await _setLastUpdate('user');
    debugLog('StorageService', '✅ User saved: ${user.username}');
  }

  Future<User?> getUser() async {
    await ensureInitialized();
    final userJson = await _getOfflineData<String>(AppConstants.userDataKey);
    if (userJson != null) {
      try {
        return User.fromJson(json.decode(userJson));
      } catch (e) {
        debugLog('StorageService', '❌ User parse error: $e');
      }
    }
    return null;
  }

  Future<void> clearUser() async {
    await ensureInitialized();
    await _removeOfflineData(AppConstants.userDataKey);
    await _prefs.remove('session_start');
    debugLog('StorageService', '✅ User data cleared');
  }

  Future<void> _saveOfflineData<T>(String key, T value, {Duration? ttl}) async {
    await ensureInitialized();

    final cacheData = {
      'value': value,
      'timestamp': DateTime.now().toIso8601String(),
      'ttl': (ttl ?? _defaultCacheTTL).inSeconds,
      'synced': true,
    };

    _memoryCache[key] = cacheData;
    _cacheTimestamps[key] = DateTime.now();

    try {
      await _prefs.setString('offline_$key', json.encode(cacheData));
    } catch (e) {
      debugLog('StorageService', 'Error saving offline data: $e');
    }
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
      debugLog('StorageService', 'Error reading offline data: $e');
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
      'ttl': (ttl ?? const Duration(days: 30)).inSeconds,
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

    debugLog('StorageService', '💾 Saved data: $key');
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
      debugLog('StorageService', 'Error getting data $key: $e');
    }

    return null;
  }

  Future<void> removeData(String key) async {
    await ensureInitialized();
    await _prefs.remove('data_$key');
  }

  Future<void> saveSessionStart() async {
    await ensureInitialized();
    await _prefs.setString('session_start', DateTime.now().toIso8601String());
    debugLog('StorageService', '⏰ Session start saved');
  }

  Future<bool> isSessionValid(Duration sessionDuration) async {
    await ensureInitialized();

    final sessionStartStr = _prefs.getString('session_start');
    if (sessionStartStr == null) {
      debugLog('StorageService', '⚠️ No session start found');
      return false;
    }

    try {
      final sessionStart = DateTime.parse(sessionStartStr);
      final sessionAge = DateTime.now().difference(sessionStart);
      final isValid = sessionAge <= sessionDuration;

      debugLog('StorageService',
          '⏰ Session check: age ${sessionAge.inHours}h, valid: $isValid');

      return isValid;
    } catch (e) {
      debugLog('StorageService', '❌ Session check error: $e');
      return false;
    }
  }

  Future<void> saveSelectedSchool(int schoolId) async {
    await ensureInitialized();
    await _prefs.setInt('selected_school_id', schoolId);
    await _setLastUpdate('school');
    debugLog('StorageService', '🏫 School saved: $schoolId');
  }

  Future<int?> getSelectedSchool() async {
    await ensureInitialized();
    return _prefs.getInt('selected_school_id');
  }

  Future<void> clearSelectedSchool() async {
    await ensureInitialized();
    await _prefs.remove('selected_school_id');
    debugLog('StorageService', 'Selected school cleared');
  }

  Future<void> saveFcmToken(String fcmToken) async {
    await ensureInitialized();
    await _prefs.setString('fcm_token', fcmToken);
    debugLog('StorageService', ' FCM token saved');
  }

  Future<String?> getFcmToken() async {
    await ensureInitialized();
    return _prefs.getString('fcm_token');
  }

  Future<void> saveNotificationPreferences(bool enabled) async {
    await ensureInitialized();
    await _prefs.setBool('notifications_enabled', enabled);
    debugLog('StorageService', ' Notification preferences saved: $enabled');
  }

  Future<bool> getNotificationPreferences() async {
    await ensureInitialized();
    return _prefs.getBool('notifications_enabled') ?? true;
  }

  Future<bool> hasCompletedRegistration() async {
    await ensureInitialized();
    final result = _prefs.getBool('registration_complete') ?? false;
    debugLog('StorageService', ' Registration complete: $result');
    return result;
  }

  Future<void> markRegistrationComplete() async {
    await ensureInitialized();
    await _prefs.setBool('registration_complete', true);
    debugLog('StorageService', ' Registration marked as complete');
  }

  Future<void> clearRegistrationComplete() async {
    await ensureInitialized();
    await _prefs.remove('registration_complete');
    debugLog('StorageService', ' Registration complete cleared');
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
        debugLog('StorageService', 'Error parsing last update: $e');
      }
    }
    return null;
  }

  /// Clear user data - ONLY called during logout with different user
  Future<void> clearAllUserData() async {
    await ensureInitialized();

    final session = UserSession();
    final isDifferentUser = !await session.isSameUser();

    if (!isDifferentUser) {
      debugLog('StorageService', '✅ Same user - preserving all storage');
      return;
    }

    debugLog('StorageService', '🔄 Different user - clearing old user storage');

    // Get the old user ID to clear
    final oldUserId = await session.getOldUserIdToClear();

    // Clear secure storage for old user only
    if (oldUserId != null) {
      try {
        // Can't delete by prefix with flutter_secure_storage, so we'll clear all
        // but this is acceptable since it's a different user
        await _secureStorage.deleteAll();
      } catch (e) {
        debugLog('StorageService', 'Error clearing secure storage: $e');
      }
    }

    // Clear preferences - only user-specific keys
    final keys = _prefs.getKeys();
    for (final key in keys) {
      // Keep system settings and device info
      if (key.startsWith('user_') ||
          key == AppConstants.userDataKey ||
          key == 'session_start' ||
          key == 'registration_complete' ||
          key == 'selected_school_id' ||
          key.startsWith('last_update_')) {
        // Only clear if it belongs to old user or is generic
        if (oldUserId == null ||
            key.contains(oldUserId) ||
            !key.contains('_')) {
          await _prefs.remove(key);
          debugLog('StorageService', ' Removed: $key');
        }
      }
    }

    // Clear memory cache for old user
    if (oldUserId != null) {
      final keysToRemove =
          _memoryCache.keys.where((k) => k.contains(oldUserId)).toList();
      for (final key in keysToRemove) {
        _memoryCache.remove(key);
        _cacheTimestamps.remove(key);
      }
    }

    debugLog('StorageService', '✅ User data cleared for old user');
  }

  Future<void> _clearAllOfflineData() async {
    final keys = _prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith('offline_') || key.startsWith('data_')) {
        await _prefs.remove(key);
      }
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
    };
  }

  /// Clean expired cache - safe to run periodically
  Future<void> clearExpiredCache() async {
    await ensureInitialized();
    debugLog('StorageService', ' Clearing expired cache');

    final keys = _prefs.getKeys();
    int clearedCount = 0;

    for (final key in keys) {
      if (key.startsWith('offline_') || key.startsWith('data_')) {
        try {
          final cachedStr = _prefs.getString(key);
          if (cachedStr != null) {
            final cacheData = json.decode(cachedStr) as Map<String, dynamic>;
            if (!_isCacheValid(cacheData)) {
              await _prefs.remove(key);
              clearedCount++;
            }
          }
        } catch (e) {
          await _prefs.remove(key);
          clearedCount++;
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

    debugLog('StorageService', ' Cleared $clearedCount expired cache items');
  }

  Future<void> clearCacheByPrefix(String prefix) async {
    await ensureInitialized();

    final session = UserSession();
    if (!session.shouldClearCache('clear_by_prefix')) {
      debugLog(
          'StorageService', '⚠️ Skipping clearCacheByPrefix - not authorized');
      return;
    }

    debugLog('StorageService', ' Clearing cache with prefix: $prefix');

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

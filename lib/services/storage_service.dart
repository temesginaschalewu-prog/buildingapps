import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/constants.dart';
import '../models/user_model.dart';
import '../utils/helpers.dart';

class StorageService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  late SharedPreferences _prefs;

  Future<void> init() async {
    debugLog('StorageService', 'Initializing SharedPreferences');
    _prefs = await SharedPreferences.getInstance();
    debugLog('StorageService', 'SharedPreferences initialized');
  }

  // Token Management
  Future<void> saveToken(String token) async {
    debugLog('StorageService', 'Saving token present: ${token != null}');
    await _secureStorage.write(key: AppConstants.tokenKey, value: token);
  }

  Future<String?> getToken() async {
    final token = await _secureStorage.read(key: AppConstants.tokenKey);
    debugLog('StorageService', 'getToken present: ${token != null}');
    return token;
  }

  Future<void> saveRefreshToken(String refreshToken) async {
    debugLog('StorageService', 'Saving refresh token');
    await _secureStorage.write(
      key: AppConstants.refreshTokenKey,
      value: refreshToken,
    );
  }

  Future<String?> getRefreshToken() async {
    return await _secureStorage.read(key: AppConstants.refreshTokenKey);
  }

  Future<void> clearTokens() async {
    debugLog('StorageService', 'Clearing tokens');
    await _secureStorage.delete(key: AppConstants.tokenKey);
    await _secureStorage.delete(key: AppConstants.refreshTokenKey);
  }

  // User Data Management
  Future<void> saveUser(User user) async {
    debugLog('StorageService', 'Saving user ID: ${user.id}');
    await _prefs.setString(
      AppConstants.userDataKey,
      json.encode(user.toJson()),
    );
  }

  Future<User?> getUser() async {
    final userJson = _prefs.getString(AppConstants.userDataKey);
    debugLog('StorageService', 'getUser raw: ${userJson != null}');
    if (userJson != null) {
      try {
        final user = User.fromJson(json.decode(userJson));
        debugLog('StorageService', 'getUser parsed ID: ${user.id}');
        return user;
      } catch (e) {
        debugLog('StorageService', 'getUser parse error: $e');
        return null;
      }
    }
    return null;
  }

  Future<void> clearUser() async {
    await _prefs.remove(AppConstants.userDataKey);
  }

  // Device Management
  Future<void> saveDeviceId(String deviceId) async {
    debugLog('StorageService', 'Saving deviceId: $deviceId');
    await _prefs.setString(AppConstants.deviceIdKey, deviceId);
  }

  Future<String?> getDeviceId() async {
    final id = _prefs.getString(AppConstants.deviceIdKey);
    debugLog('StorageService', 'getDeviceId: $id');
    return id;
  }

  Future<void> clearDeviceId() async {
    await _prefs.remove(AppConstants.deviceIdKey);
  }

  // Theme Management
  Future<void> saveThemeMode(String themeMode) async {
    await _prefs.setString(AppConstants.themeModeKey, themeMode);
  }

  Future<String?> getThemeMode() async {
    return _prefs.getString(AppConstants.themeModeKey);
  }

  // Notification Settings
  Future<void> saveNotificationsEnabled(bool enabled) async {
    await _prefs.setBool(AppConstants.notificationsEnabledKey, enabled);
  }

  Future<bool> getNotificationsEnabled() async {
    return _prefs.getBool(AppConstants.notificationsEnabledKey) ?? true;
  }

  // Cache Management
  Future<void> saveLastCacheCleanup(DateTime date) async {
    await _prefs.setString('last_cache_cleanup', date.toIso8601String());
  }

  Future<DateTime?> getLastCacheCleanup() async {
    final dateString = _prefs.getString('last_cache_cleanup');
    if (dateString != null) {
      try {
        return DateTime.parse(dateString);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  // App State
  Future<void> saveLastAppState(String state) async {
    await _prefs.setString('last_app_state', state);
  }

  Future<String?> getLastAppState() async {
    return _prefs.getString('last_app_state');
  }

  Future<void> clearAll() async {
    debugLog('StorageService', 'Clearing all storage');

    // Clear secure storage (tokens)
    await _secureStorage.deleteAll();

    // Clear user data but NOT device ID
    await _prefs.remove(AppConstants.userDataKey);
    await _prefs.remove(AppConstants.themeModeKey);
    await _prefs.remove(AppConstants.notificationsEnabledKey);
    // DO NOT clear device ID: await _prefs.remove(AppConstants.deviceIdKey);

    debugLog('StorageService', 'Storage cleared (device ID preserved)');
  }

  // Video Cache Management
  Future<void> saveVideoCacheInfo(String videoId, String path, int size) async {
    final cacheKey = 'video_cache_$videoId';
    await _prefs.setString(
      cacheKey,
      json.encode({
        'path': path,
        'size': size,
        'cached_at': DateTime.now().toIso8601String(),
        'accessed_at': DateTime.now().toIso8601String(),
      }),
    );
  }

  Future<Map<String, dynamic>?> getVideoCacheInfo(String videoId) async {
    final cacheKey = 'video_cache_$videoId';
    final infoJson = _prefs.getString(cacheKey);
    if (infoJson != null) {
      try {
        return json.decode(infoJson);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  Future<void> updateVideoAccessTime(String videoId) async {
    final cacheKey = 'video_cache_$videoId';
    final infoJson = _prefs.getString(cacheKey);
    if (infoJson != null) {
      try {
        final info = json.decode(infoJson);
        info['accessed_at'] = DateTime.now().toIso8601String();
        await _prefs.setString(cacheKey, json.encode(info));
      } catch (e) {
        // Ignore error
      }
    }
  }

  Future<void> removeVideoCache(String videoId) async {
    final cacheKey = 'video_cache_$videoId';
    await _prefs.remove(cacheKey);
  }

  Future<List<String>> getAllCachedVideoIds() async {
    final keys = _prefs.getKeys();
    return keys
        .where((key) => key.startsWith('video_cache_'))
        .map((key) => key.replaceFirst('video_cache_', ''))
        .toList();
  }
}

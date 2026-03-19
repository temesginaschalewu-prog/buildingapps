// lib/services/storage_service.dart
// PRODUCTION-READY FINAL VERSION

import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';
import 'package:familyacademyclient/services/user_session.dart';
import 'package:familyacademyclient/utils/platform_helper.dart';
import 'package:familyacademyclient/services/device_service.dart';
import 'package:familyacademyclient/services/hive_service.dart';
import '../utils/constants.dart';
import '../models/user_model.dart';
import '../utils/helpers.dart';

class StorageService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  late SharedPreferences _prefs;
  bool _initialized = false;

  DeviceService? _deviceService;
  HiveService? _hiveService;

  bool get isInitialized => _initialized;

  void setDeviceService(DeviceService deviceService) {
    _deviceService = deviceService;
  }

  void setHiveService(HiveService hiveService) {
    _hiveService = hiveService;
  }

  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
    debugLog('StorageService', '✅ Initialized');
  }

  Future<void> ensureInitialized() async {
    if (!_initialized) await init();
  }

  // ===== TOKEN MANAGEMENT =====
  Future<void> saveToken(String token) async {
    await ensureInitialized();
    if (!PlatformHelper.isMobile) {
      await _prefs.setString(AppConstants.tokenKey, token);
    } else {
      await _secureStorage.write(key: AppConstants.tokenKey, value: token);
    }
  }

  Future<String?> getToken() async {
    await ensureInitialized();
    if (!PlatformHelper.isMobile) {
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
    if (!PlatformHelper.isMobile) {
      await _prefs.setString(AppConstants.refreshTokenKey, refreshToken);
    } else {
      await _secureStorage.write(
          key: AppConstants.refreshTokenKey, value: refreshToken);
    }
  }

  Future<String?> getRefreshToken() async {
    await ensureInitialized();
    if (!PlatformHelper.isMobile) {
      return _prefs.getString(AppConstants.refreshTokenKey);
    }
    return _secureStorage.read(key: AppConstants.refreshTokenKey);
  }

  Future<void> clearTokens() async {
    await ensureInitialized();
    if (!PlatformHelper.isMobile) {
      await _prefs.remove(AppConstants.tokenKey);
      await _prefs.remove(AppConstants.refreshTokenKey);
    } else {
      await _secureStorage.delete(key: AppConstants.tokenKey);
      await _secureStorage.delete(key: AppConstants.refreshTokenKey);
    }
  }

  // ===== USER MANAGEMENT =====
  Future<void> saveUser(User user) async {
    await ensureInitialized();
    final userJson = json.encode(user.toJson());
    await _prefs.setString(AppConstants.userDataKey, userJson);

    // USE EXISTING BOX
    if (Hive.isBoxOpen(AppConstants.hiveUserBox)) {
      final userBox = Hive.box<dynamic>(AppConstants.hiveUserBox);
      await userBox.put('user_${user.id}_profile', user);
      debugLog('StorageService', '✅ Saved user to existing Hive box');
    } else {
      debugLog('StorageService', '⚠️ User box not open, cannot save');
    }

    if (_deviceService != null) {
      _deviceService!.saveCacheItem(
        'user_profile',
        user,
        ttl: AppConstants.cacheTTLUserProfile,
        isUserSpecific: true,
      );
    }
  }

  Future<User?> getUser() async {
    await ensureInitialized();

    // USE EXISTING BOX
    try {
      final userId = await getCurrentUserId();
      if (userId != null && Hive.isBoxOpen(AppConstants.hiveUserBox)) {
        final userBox = Hive.box<dynamic>(AppConstants.hiveUserBox);
        final cachedUser = userBox.get('user_${userId}_profile');
        if (cachedUser != null && cachedUser is User) {
          return cachedUser;
        }
      }
    } catch (e) {
      debugLog('StorageService', 'Error reading from Hive: $e');
    }

    if (_deviceService != null) {
      final cachedUser = await _deviceService!.getCacheItem<User>(
        'user_profile',
        isUserSpecific: true,
      );
      if (cachedUser != null) return cachedUser;
    }

    final userJson = _prefs.getString(AppConstants.userDataKey);
    if (userJson != null) {
      try {
        return User.fromJson(json.decode(userJson));
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  Future<String?> getCurrentUserId() async {
    return _prefs.getString(AppConstants.currentUserIdKey);
  }

  Future<void> clearUser() async {
    await ensureInitialized();
    await _prefs.remove(AppConstants.userDataKey);

    try {
      final userId = await getCurrentUserId();
      if (userId != null && Hive.isBoxOpen(AppConstants.hiveUserBox)) {
        final userBox = Hive.box<dynamic>(AppConstants.hiveUserBox);
        await userBox.delete('user_${userId}_profile');
      }
    } catch (e) {
      debugLog('StorageService', 'Error clearing Hive user: $e');
    }
  }

  // ===== SESSION MANAGEMENT =====
  Future<void> saveSessionStart() async {
    await ensureInitialized();
    await _prefs.setString(
        AppConstants.sessionStartKey, DateTime.now().toIso8601String());
  }

  Future<bool> isSessionValid(Duration sessionDuration) async {
    await ensureInitialized();
    final sessionStartStr = _prefs.getString(AppConstants.sessionStartKey);
    if (sessionStartStr == null) return true;

    try {
      final sessionStart = DateTime.parse(sessionStartStr);
      final sessionAge = DateTime.now().difference(sessionStart);
      return sessionAge <= sessionDuration;
    } catch (e) {
      return true;
    }
  }

  // ===== NOTIFICATION PREFERENCES =====
  Future<void> saveNotificationPreferences(bool enabled) async {
    await ensureInitialized();
    await _prefs.setBool(AppConstants.notificationsEnabledKey, enabled);
  }

  Future<bool> getNotificationPreferences() async {
    await ensureInitialized();
    return _prefs.getBool(AppConstants.notificationsEnabledKey) ?? true;
  }

  // ===== REGISTRATION STATUS =====
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

  // ===== SCHOOL SELECTION =====
  Future<void> saveSelectedSchool(int schoolId) async {
    await ensureInitialized();
    await _prefs.setInt(AppConstants.selectedSchoolIdKey, schoolId);
  }

  Future<int?> getSelectedSchool() async {
    await ensureInitialized();
    return _prefs.getInt(AppConstants.selectedSchoolIdKey);
  }

  Future<void> clearSelectedSchool() async {
    await ensureInitialized();
    await _prefs.remove(AppConstants.selectedSchoolIdKey);
  }

  // ===== FCM TOKEN =====
  Future<void> saveFcmToken(String fcmToken) async {
    await ensureInitialized();
    await _prefs.setString(AppConstants.fcmTokenCacheKey, fcmToken);
  }

  Future<String?> getFcmToken() async {
    await ensureInitialized();
    return _prefs.getString(AppConstants.fcmTokenCacheKey);
  }

  // ===== CLEAR USER DATA =====
  Future<void> clearAllUserData() async {
    debugLog('StorageService', 'Clearing user data');

    final session = UserSession();
    final isDifferentUser = !await session.isSameUser();
    if (!isDifferentUser) {
      debugLog('StorageService', 'Same user - preserving data');
      return;
    }

    final oldUserId = await session.getOldUserIdToClear();

    if (oldUserId != null && PlatformHelper.isMobile) {
      try {
        await _secureStorage.deleteAll();
      } catch (e) {}
    }

    final keys = _prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith('user_') ||
          key == AppConstants.userDataKey ||
          key == AppConstants.sessionStartKey ||
          key == AppConstants.registrationCompleteKey ||
          key == AppConstants.selectedSchoolIdKey) {
        if (oldUserId == null ||
            key.contains(oldUserId) ||
            !key.contains('_')) {
          await _prefs.remove(key);
        }
      }
    }

    if (oldUserId != null && _hiveService != null) {
      try {
        await _hiveService!.clearUserData(oldUserId);
      } catch (e) {
        debugLog('StorageService', 'Error clearing Hive data: $e');
      }
    }
  }

  Future<Map<String, dynamic>> getStorageStats() async {
    await ensureInitialized();
    return {
      'has_token': (await getToken()) != null,
      'has_user': (await getUser()) != null,
      'initialized': _initialized,
      'platform': PlatformHelper.platformName,
      'hive_available': Hive.isBoxOpen(AppConstants.hiveUserBox),
    };
  }
}

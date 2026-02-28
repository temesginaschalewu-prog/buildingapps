import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class AuthService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  late SharedPreferences _prefs;
  bool _initialized = false;
  String? _currentUserId;

  Future<void> init() async {
    if (_initialized) return;

    _prefs = await SharedPreferences.getInstance();
    _currentUserId = _prefs.getString('current_user_id');
    _initialized = true;
  }

  Future<void> ensureInitialized() async {
    if (!_initialized) await init();
  }

  Future<void> _getCurrentUserId() async {
    _currentUserId = _prefs.getString('current_user_id');
  }

  String _getUserSpecificKey(String key) {
    if (_currentUserId == null) return key;
    return '${key}_$_currentUserId';
  }

  Future<bool> isAuthenticated() async {
    await ensureInitialized();
    final token = await _secureStorage.read(key: AppConstants.tokenKey);
    final userData =
        _prefs.getString(_getUserSpecificKey(AppConstants.userDataKey));
    return token != null && userData != null;
  }

  Future<String?> getToken() async {
    await ensureInitialized();
    return await _secureStorage.read(key: AppConstants.tokenKey);
  }

  Future<void> saveAuthData(
      String token, String refreshToken, String userData) async {
    await ensureInitialized();
    await _secureStorage.write(key: AppConstants.tokenKey, value: token);
    await _secureStorage.write(
        key: AppConstants.refreshTokenKey, value: refreshToken);
    await _prefs.setString(
        _getUserSpecificKey(AppConstants.userDataKey), userData);
    await _prefs.setBool('auth_synced', true);
    await _prefs.setString('auth_last_sync', DateTime.now().toIso8601String());
  }

  Future<void> clearAuthData() async {
    await ensureInitialized();
    await _secureStorage.delete(key: AppConstants.tokenKey);
    await _secureStorage.delete(key: AppConstants.refreshTokenKey);
    await _prefs.remove(_getUserSpecificKey(AppConstants.userDataKey));
    await _prefs.remove('auth_synced');
    await _prefs.remove('auth_last_sync');
  }

  Future<bool> hasCompletedRegistration() async {
    await ensureInitialized();
    return _prefs.getBool(_getUserSpecificKey('registration_complete')) ??
        false;
  }

  Future<void> markRegistrationComplete() async {
    await ensureInitialized();
    await _prefs.setBool(_getUserSpecificKey('registration_complete'), true);
  }

  Future<void> clearRegistrationComplete() async {
    await ensureInitialized();
    await _prefs.remove(_getUserSpecificKey('registration_complete'));
  }

  Future<bool> hasSelectedSchool() async {
    await ensureInitialized();
    return _prefs.getInt(_getUserSpecificKey('selected_school_id')) != null;
  }

  Future<void> saveSelectedSchool(int schoolId) async {
    await ensureInitialized();
    await _prefs.setInt(_getUserSpecificKey('selected_school_id'), schoolId);
  }

  Future<int?> getSelectedSchool() async {
    await ensureInitialized();
    return _prefs.getInt(_getUserSpecificKey('selected_school_id'));
  }

  Future<void> clearSelectedSchool() async {
    await ensureInitialized();
    await _prefs.remove(_getUserSpecificKey('selected_school_id'));
  }

  Future<void> saveFcmToken(String fcmToken) async {
    await ensureInitialized();
    await _prefs.setString(_getUserSpecificKey('fcm_token'), fcmToken);
  }

  Future<String?> getFcmToken() async {
    await ensureInitialized();
    return _prefs.getString(_getUserSpecificKey('fcm_token'));
  }

  Future<void> saveNotificationPreferences(bool enabled) async {
    await ensureInitialized();
    await _prefs.setBool(_getUserSpecificKey('notifications_enabled'), enabled);
  }

  Future<bool> getNotificationPreferences() async {
    await ensureInitialized();
    return _prefs.getBool(_getUserSpecificKey('notifications_enabled')) ?? true;
  }

  Future<void> saveSessionTimestamp() async {
    await ensureInitialized();
    await _prefs.setString(_getUserSpecificKey('session_timestamp'),
        DateTime.now().toIso8601String());
  }

  Future<DateTime?> getSessionTimestamp() async {
    await ensureInitialized();
    final timestampStr =
        _prefs.getString(_getUserSpecificKey('session_timestamp'));
    if (timestampStr != null) {
      try {
        return DateTime.parse(timestampStr);
      } catch (e) {}
    }
    return null;
  }

  Future<bool> isSessionValid(Duration sessionDuration) async {
    await ensureInitialized();
    final sessionStartStr =
        _prefs.getString(_getUserSpecificKey('session_timestamp'));
    if (sessionStartStr == null) return false;
    try {
      final sessionStart = DateTime.parse(sessionStartStr);
      final sessionAge = DateTime.now().difference(sessionStart);
      return sessionAge <= sessionDuration;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isAuthSynced() async {
    await ensureInitialized();
    return _prefs.getBool('auth_synced') ?? false;
  }

  Future<DateTime?> getLastSyncTime() async {
    await ensureInitialized();
    final syncTimeStr = _prefs.getString('auth_last_sync');
    if (syncTimeStr != null) {
      try {
        return DateTime.parse(syncTimeStr);
      } catch (e) {}
    }
    return null;
  }

  Future<Map<String, dynamic>> getAuthStats() async {
    await ensureInitialized();
    return {
      'has_token': (await getToken()) != null,
      'has_user_data':
          _prefs.containsKey(_getUserSpecificKey(AppConstants.userDataKey)),
      'registration_complete': await hasCompletedRegistration(),
      'has_selected_school': await hasSelectedSchool(),
      'has_fcm_token': (await getFcmToken()) != null,
      'notifications_enabled': await getNotificationPreferences(),
      'auth_synced': await isAuthSynced(),
      'last_sync': await getLastSyncTime(),
      'session_timestamp': await getSessionTimestamp(),
    };
  }

  Future<void> clearAllAuthData() async {
    await ensureInitialized();
    await _secureStorage.deleteAll();
    final keys = _prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith('auth_') ||
          key.contains('registration_complete') ||
          key.contains('selected_school_id') ||
          key.contains('fcm_token') ||
          key.contains('notifications_enabled') ||
          key.contains('session_timestamp')) {
        await _prefs.remove(key);
      }
    }
  }

  Future<void> setCurrentUserId(String userId) async {
    await ensureInitialized();
    _currentUserId = userId;
    await _prefs.setString('current_user_id', userId);
  }

  Future<void> clearCurrentUserId() async {
    await ensureInitialized();
    _currentUserId = null;
    await _prefs.remove('current_user_id');
  }
}

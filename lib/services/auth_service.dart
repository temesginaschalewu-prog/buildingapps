import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class AuthService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  late SharedPreferences _prefs;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    debugLog('AuthService', '🔄 Initializing auth service');
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
    debugLog('AuthService', '✅ Auth service initialized');
  }

  Future<void> ensureInitialized() async {
    if (!_initialized) await init();
  }

  // 🔑 Authentication State
  Future<bool> isAuthenticated() async {
    await ensureInitialized();

    final token = await _secureStorage.read(key: AppConstants.tokenKey);
    final userData = _prefs.getString('offline_${AppConstants.userDataKey}');

    debugLog('AuthService',
        'isAuthenticated check: token=${token != null}, userData=${userData != null}');

    return token != null && userData != null;
  }

  Future<String?> getToken() async {
    await ensureInitialized();
    final token = await _secureStorage.read(key: AppConstants.tokenKey);
    debugLog('AuthService', 'getToken: ${token != null}');
    return token;
  }

  // 💾 Auth Data Management
  Future<void> saveAuthData(
    String token,
    String refreshToken,
    String userData,
  ) async {
    await ensureInitialized();

    debugLog('AuthService', '💾 Saving auth data');

    await _secureStorage.write(key: AppConstants.tokenKey, value: token);
    await _secureStorage.write(
        key: AppConstants.refreshTokenKey, value: refreshToken);

    // Save user data with offline-first approach
    await _prefs.setString('offline_${AppConstants.userDataKey}', userData);

    // Mark as synced
    await _prefs.setBool('auth_synced', true);
    await _prefs.setString('auth_last_sync', DateTime.now().toIso8601String());

    debugLog('AuthService', '✅ Auth data saved');
  }

  Future<void> clearAuthData() async {
    await ensureInitialized();
    debugLog('AuthService', '🧹 Clearing auth data');

    await _secureStorage.delete(key: AppConstants.tokenKey);
    await _secureStorage.delete(key: AppConstants.refreshTokenKey);

    // Clear user data
    await _prefs.remove('offline_${AppConstants.userDataKey}');
    await _prefs.remove('auth_synced');
    await _prefs.remove('auth_last_sync');

    debugLog('AuthService', '✅ Auth data cleared');
  }

  // 📝 Registration State
  Future<bool> hasCompletedRegistration() async {
    await ensureInitialized();
    return _prefs.getBool('registration_complete') ?? false;
  }

  Future<void> markRegistrationComplete() async {
    await ensureInitialized();
    await _prefs.setBool('registration_complete', true);
    debugLog('AuthService', '✅ Registration marked as complete');
  }

  Future<void> clearRegistrationComplete() async {
    await ensureInitialized();
    await _prefs.remove('registration_complete');
    debugLog('AuthService', '🧹 Registration complete cleared');
  }

  // 🏫 School Selection
  Future<bool> hasSelectedSchool() async {
    await ensureInitialized();
    return _prefs.getInt('selected_school_id') != null;
  }

  Future<void> saveSelectedSchool(int schoolId) async {
    await ensureInitialized();
    await _prefs.setInt('selected_school_id', schoolId);
    debugLog('AuthService', '🏫 School saved: $schoolId');
  }

  Future<int?> getSelectedSchool() async {
    await ensureInitialized();
    return _prefs.getInt('selected_school_id');
  }

  Future<void> clearSelectedSchool() async {
    await ensureInitialized();
    await _prefs.remove('selected_school_id');
    debugLog('AuthService', '🧹 Selected school cleared');
  }

  // 📱 FCM Token Management
  Future<void> saveFcmToken(String fcmToken) async {
    await ensureInitialized();
    await _prefs.setString('fcm_token', fcmToken);
    debugLog('AuthService', '📱 FCM token saved');
  }

  Future<String?> getFcmToken() async {
    await ensureInitialized();
    return _prefs.getString('fcm_token');
  }

  // 🔔 Notification Preferences
  Future<void> saveNotificationPreferences(bool enabled) async {
    await ensureInitialized();
    await _prefs.setBool('notifications_enabled', enabled);
    debugLog('AuthService', '🔔 Notification preferences saved: $enabled');
  }

  Future<bool> getNotificationPreferences() async {
    await ensureInitialized();
    return _prefs.getBool('notifications_enabled') ?? true;
  }

  // ⏰ Session Management
  Future<void> saveSessionTimestamp() async {
    await ensureInitialized();
    await _prefs.setString(
        'session_timestamp', DateTime.now().toIso8601String());
    debugLog('AuthService', '⏰ Session timestamp saved');
  }

  Future<DateTime?> getSessionTimestamp() async {
    await ensureInitialized();
    final timestampStr = _prefs.getString('session_timestamp');
    if (timestampStr != null) {
      try {
        return DateTime.parse(timestampStr);
      } catch (e) {
        debugLog('AuthService', 'Error parsing session timestamp: $e');
      }
    }
    return null;
  }

  // 🔄 Sync Status
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
      } catch (e) {
        debugLog('AuthService', 'Error parsing last sync time: $e');
      }
    }
    return null;
  }

  // 📊 Stats
  Future<Map<String, dynamic>> getAuthStats() async {
    await ensureInitialized();

    return {
      'has_token': (await getToken()) != null,
      'has_user_data':
          _prefs.containsKey('offline_${AppConstants.userDataKey}'),
      'registration_complete': await hasCompletedRegistration(),
      'has_selected_school': await hasSelectedSchool(),
      'has_fcm_token': (await getFcmToken()) != null,
      'notifications_enabled': await getNotificationPreferences(),
      'auth_synced': await isAuthSynced(),
      'last_sync': await getLastSyncTime(),
      'session_timestamp': await getSessionTimestamp(),
    };
  }

  // 🧹 Cleanup
  Future<void> clearAllAuthData() async {
    await ensureInitialized();
    debugLog('AuthService', '🚪 Clearing all auth data');

    await _secureStorage.deleteAll();

    final keys = _prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith('auth_') ||
          key == 'registration_complete' ||
          key == 'selected_school_id' ||
          key == 'fcm_token' ||
          key == 'notifications_enabled' ||
          key == 'session_timestamp') {
        await _prefs.remove(key);
      }
    }

    debugLog('AuthService', '✅ All auth data cleared');
  }
}

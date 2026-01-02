import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class AuthService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  late SharedPreferences _prefs;

  Future<void> init() async {
    debugLog('AuthService', 'Initializing SharedPreferences');
    _prefs = await SharedPreferences.getInstance();
    debugLog('AuthService', 'SharedPreferences initialized');
  }

  Future<bool> isAuthenticated() async {
    final token = await _secureStorage.read(key: AppConstants.tokenKey);
    final userData = _prefs.getString(AppConstants.userDataKey);
    debugLog('AuthService',
        'isAuthenticated check: token=${token != null}, userData=${userData != null}');
    return token != null && userData != null;
  }

  Future<String?> getToken() async {
    final token = await _secureStorage.read(key: AppConstants.tokenKey);
    debugLog('AuthService', 'getToken: ${token != null}');
    return token;
  }

  Future<String?> getDeviceId() async {
    final id = _prefs.getString(AppConstants.deviceIdKey);
    debugLog('AuthService', 'getDeviceId: $id');
    return id;
  }

  Future<void> saveAuthData(
    String token,
    String refreshToken,
    String userData,
  ) async {
    debugLog(
        'AuthService', 'Saving auth data. token present: ${token != null}');
    await _secureStorage.write(key: AppConstants.tokenKey, value: token);
    await _secureStorage.write(
      key: AppConstants.refreshTokenKey,
      value: refreshToken,
    );
    await _prefs.setString(AppConstants.userDataKey, userData);
    debugLog('AuthService', 'Auth data saved');
  }

  Future<void> clearAuthData() async {
    debugLog('AuthService', 'Clearing auth data');
    await _secureStorage.delete(key: AppConstants.tokenKey);
    await _secureStorage.delete(key: AppConstants.refreshTokenKey);
    await _prefs.remove(AppConstants.userDataKey);
    debugLog('AuthService', 'Auth data cleared');
  }

  Future<bool> hasCompletedRegistration() async {
    return _prefs.getBool('registration_complete') ?? false;
  }

  Future<void> markRegistrationComplete() async {
    await _prefs.setBool('registration_complete', true);
  }

  Future<void> clearRegistrationComplete() async {
    await _prefs.remove('registration_complete');
  }

  Future<bool> hasSelectedSchool() async {
    return _prefs.getInt('selected_school_id') != null;
  }

  Future<void> saveSelectedSchool(int schoolId) async {
    await _prefs.setInt('selected_school_id', schoolId);
  }

  Future<int?> getSelectedSchool() async {
    return _prefs.getInt('selected_school_id');
  }

  Future<void> clearSelectedSchool() async {
    await _prefs.remove('selected_school_id');
  }
}

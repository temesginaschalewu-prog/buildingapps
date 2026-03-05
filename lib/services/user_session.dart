import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class UserSession {
  static final UserSession _instance = UserSession._internal();
  factory UserSession() => _instance;
  UserSession._internal();

  String? _cachedUserId;
  bool _isLoggingOut = false;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedUserId = prefs.getString(AppConstants.currentUserIdKey);
    _isLoggingOut = prefs.getBool(AppConstants.isLoggingOutKey) ?? false;
    debugLog('UserSession', 'Initialized with user: $_cachedUserId');
  }

  Future<bool> setCurrentUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final previousUserId = prefs.getString(AppConstants.lastUserIdKey);

    await prefs.setString(AppConstants.currentUserIdKey, userId);

    final isDifferentUser = previousUserId != userId;

    if (isDifferentUser) {
      debugLog('UserSession',
          '🔄 Different user login: $userId (was: $previousUserId)');

      await prefs.setString(AppConstants.lastUserIdKey, userId);
    } else {
      debugLog('UserSession', '✅ Same user login: $userId');
    }

    _cachedUserId = userId;
    return isDifferentUser;
  }

  Future<String?> getCurrentUserId() async {
    if (_cachedUserId != null) return _cachedUserId;

    final prefs = await SharedPreferences.getInstance();
    _cachedUserId = prefs.getString(AppConstants.currentUserIdKey);
    return _cachedUserId;
  }

  Future<String?> getLastUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.lastUserIdKey);
  }

  Future<bool> isSameUser() async {
    final current = await getCurrentUserId();
    final last = await getLastUserId();
    return current == last;
  }

  Future<void> prepareForLogout() async {
    _isLoggingOut = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.isLoggingOutKey, true);
    debugLog('UserSession', '🔴 Preparing for logout');
  }

  Future<void> completeLogout() async {
    _isLoggingOut = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.isLoggingOutKey);
    await prefs.remove(AppConstants.currentUserIdKey);
    await prefs.remove(AppConstants.sessionStartKey);
    _cachedUserId = null;
    debugLog('UserSession', '✅ Logout complete - cache preserved');
  }

  bool shouldClearCache(String operation) {
    if (operation == 'navigation') return false;

    if (operation == 'logout') {
      return _isLoggingOut;
    }

    return false;
  }

  Future<bool> isDifferentUserLogin(String newUserId) async {
    final lastUserId = await getLastUserId();
    return lastUserId != null && lastUserId != newUserId;
  }

  Future<String?> getOldUserIdToClear() async {
    final current = await getCurrentUserId();
    final last = await getLastUserId();

    if (last != null && last != current) {
      return last;
    }
    return null;
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.currentUserIdKey);
    await prefs.remove(AppConstants.sessionStartKey);
    await prefs.remove(AppConstants.isLoggingOutKey);
    _cachedUserId = null;
    _isLoggingOut = false;
    debugLog('UserSession', '🔄 Session reset');
  }
}

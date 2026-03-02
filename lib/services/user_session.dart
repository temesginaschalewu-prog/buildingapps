import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class UserSession {
  static final UserSession _instance = UserSession._internal();
  factory UserSession() => _instance;
  UserSession._internal();

  String? _cachedUserId;
  bool _isLoggingOut = false;

  /// Initialize session - call on app start
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedUserId = prefs.getString(AppConstants.currentUserIdKey);
    _isLoggingOut = prefs.getBool(AppConstants.isLoggingOutKey) ?? false;
    debugLog('UserSession', 'Initialized with user: $_cachedUserId');
  }

  /// Set current user - returns true if this is a different user
  Future<bool> setCurrentUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final previousUserId = prefs.getString(AppConstants.lastUserIdKey);

    // Store current as last before updating
    await prefs.setString(AppConstants.currentUserIdKey, userId);

    final isDifferentUser = previousUserId != userId;

    if (isDifferentUser) {
      debugLog('UserSession',
          '🔄 Different user login: $userId (was: $previousUserId)');
      // Store this as the new last user
      await prefs.setString(AppConstants.lastUserIdKey, userId);
    } else {
      debugLog('UserSession', '✅ Same user login: $userId');
    }

    _cachedUserId = userId;
    return isDifferentUser;
  }

  /// Get current user ID
  Future<String?> getCurrentUserId() async {
    if (_cachedUserId != null) return _cachedUserId;

    final prefs = await SharedPreferences.getInstance();
    _cachedUserId = prefs.getString(AppConstants.currentUserIdKey);
    return _cachedUserId;
  }

  /// Get last logged in user ID
  Future<String?> getLastUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.lastUserIdKey);
  }

  /// Check if current user is the same as last user
  Future<bool> isSameUser() async {
    final current = await getCurrentUserId();
    final last = await getLastUserId();
    return current == last;
  }

  /// Prepare for logout
  Future<void> prepareForLogout() async {
    _isLoggingOut = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.isLoggingOutKey, true);
    debugLog('UserSession', '🔴 Preparing for logout');
  }

  /// Complete logout - preserve cache for potential return
  Future<void> completeLogout() async {
    _isLoggingOut = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.isLoggingOutKey);
    await prefs.remove(AppConstants.currentUserIdKey);
    await prefs.remove(AppConstants.sessionStartKey);
    _cachedUserId = null;
    debugLog('UserSession', '✅ Logout complete - cache preserved');
  }

  /// Should we clear cache for this operation?
  bool shouldClearCache(String operation) {
    // Never clear on navigation
    if (operation == 'navigation') return false;

    // Only clear on logout if it's a different user scenario
    if (operation == 'logout') {
      return _isLoggingOut;
    }

    return false;
  }

  /// Check if this is a different user login
  Future<bool> isDifferentUserLogin(String newUserId) async {
    final lastUserId = await getLastUserId();
    return lastUserId != null && lastUserId != newUserId;
  }

  /// Clear only the old user's data (for different user login)
  Future<String?> getOldUserIdToClear() async {
    final current = await getCurrentUserId();
    final last = await getLastUserId();

    // If different users, return the old user ID to clear
    if (last != null && last != current) {
      return last;
    }
    return null;
  }

  /// Clear session on app reset
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

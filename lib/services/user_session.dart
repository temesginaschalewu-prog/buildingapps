import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class UserSession {
  static final UserSession _instance = UserSession._internal();
  factory UserSession() => _instance;
  UserSession._internal();

  String? _cachedUserId;
  bool _isLoggingOut = false;
  bool _initialized = false;

  Box? _sessionBox;

  Future<void> init() async {
    if (_initialized) return;

    try {
      _sessionBox = await Hive.openBox('session_box');

      final prefs = await SharedPreferences.getInstance();
      _cachedUserId = prefs.getString(AppConstants.currentUserIdKey);
      _isLoggingOut = prefs.getBool(AppConstants.isLoggingOutKey) ?? false;

      if (_cachedUserId == null && _sessionBox != null) {
        _cachedUserId = _sessionBox!.get('current_user_id') as String?;
      }

      final hasActiveSession = _cachedUserId != null && _cachedUserId!.isNotEmpty;
      if (_isLoggingOut && hasActiveSession) {
        await _clearLogoutMarker(prefs);
        debugLog('UserSession', 'Recovered stale logout marker for active session');
      }

      debugLog('UserSession', 'Initialized with user: $_cachedUserId');
    } catch (e) {
      debugLog('UserSession', 'Error initializing: $e');
    } finally {
      _initialized = true;
    }
  }

  Future<void> setCurrentUser(String userId) async {
    await init();
    final prefs = await SharedPreferences.getInstance();
    final previousUserId = await getCurrentUserId();

    await prefs.setString(AppConstants.currentUserIdKey, userId);
    await _clearLogoutMarker(prefs);

    if (_sessionBox != null) {
      await _sessionBox!.put('current_user_id', userId);
    }

    if (previousUserId != null && previousUserId != userId) {
      await prefs.setString(AppConstants.lastUserIdKey, previousUserId);
      if (_sessionBox != null) {
        await _sessionBox!.put('last_user_id', previousUserId);
      }
      debugLog(
          'UserSession', '🔄 User changed from $previousUserId to $userId');
    }

    _cachedUserId = userId;
  }

  Future<String?> getCurrentUserId() async {
    await init();
    if (_cachedUserId != null) return _cachedUserId;

    final prefs = await SharedPreferences.getInstance();
    _cachedUserId = prefs.getString(AppConstants.currentUserIdKey);

    // Try Hive if not in prefs
    if (_cachedUserId == null && _sessionBox != null) {
      _cachedUserId = _sessionBox!.get('current_user_id') as String?;
    }

    return _cachedUserId;
  }

  Future<String?> getLastUserId() async {
    await init();
    final prefs = await SharedPreferences.getInstance();
    final lastUserId = prefs.getString(AppConstants.lastUserIdKey);

    // Try Hive if not in prefs
    if (lastUserId == null && _sessionBox != null) {
      return _sessionBox!.get('last_user_id') as String?;
    }

    return lastUserId;
  }

  Future<bool> isSameUser() async {
    final current = await getCurrentUserId();
    final last = await getLastUserId();
    return current == last;
  }

  Future<bool> isDifferentUser(String newUserId) async {
    final current = await getCurrentUserId();
    return current != null && current != newUserId;
  }

  Future<String?> getOldUserIdToClear() async {
    final current = await getCurrentUserId();
    final last = await getLastUserId();
    if (last != null && last != current) {
      return last;
    }
    return null;
  }

  Future<void> prepareForLogout() async {
    await init();
    _isLoggingOut = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.isLoggingOutKey, true);
    // Save to Hive
    if (_sessionBox != null) {
      await _sessionBox!.put('is_logging_out', true);
    }
    debugLog('UserSession', '🔴 Preparing for logout');
  }

  Future<void> completeLogout() async {
    await init();
    _isLoggingOut = false;
    final prefs = await SharedPreferences.getInstance();
    await _clearLogoutMarker(prefs);
    await prefs.remove(AppConstants.currentUserIdKey);
    // Don't remove lastUserId - we need it for cache cleanup

    // Clear from Hive but keep last_user_id
    if (_sessionBox != null) {
      await _sessionBox!.delete('is_logging_out');
      await _sessionBox!.delete('current_user_id');
    }

    _cachedUserId = null;
    debugLog('UserSession', '✅ Logout complete');
  }

  bool shouldClearCacheOnLogout() {
    return _isLoggingOut;
  }

  Future<void> reset() async {
    await init();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.currentUserIdKey);
    await prefs.remove(AppConstants.lastUserIdKey);
    await prefs.remove(AppConstants.isLoggingOutKey);

    // Clear Hive session box
    if (_sessionBox != null) {
      await _sessionBox!.clear();
    }

    _cachedUserId = null;
    _isLoggingOut = false;
    debugLog('UserSession', '🔄 Session reset');
  }

  // Get session stats
  Future<Map<String, dynamic>> getSessionStats() async {
    return {
      'current_user': await getCurrentUserId(),
      'last_user': await getLastUserId(),
      'is_logging_out': _isLoggingOut,
      'hive_available': _sessionBox != null,
    };
  }

  Future<void> dispose() async {
    await _sessionBox?.close();
    _sessionBox = null;
    _initialized = false;
  }

  Future<void> _clearLogoutMarker(SharedPreferences prefs) async {
    _isLoggingOut = false;
    await prefs.remove(AppConstants.isLoggingOutKey);
    if (_sessionBox != null) {
      await _sessionBox!.delete('is_logging_out');
    }
  }
}

// lib/services/user_session.dart
// COMPLETE PRODUCTION-READY FILE - REPLACE ENTIRE FILE

import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

/// UPDATED: Now uses Hive for better session persistence
class UserSession {
  static final UserSession _instance = UserSession._internal();
  factory UserSession() => _instance;
  UserSession._internal();

  String? _cachedUserId;
  bool _isLoggingOut = false;

  // Hive box for session data
  Box? _sessionBox;

  Future<void> init() async {
    try {
      // Open session box
      _sessionBox = await Hive.openBox('session_box');

      final prefs = await SharedPreferences.getInstance();
      _cachedUserId = prefs.getString(AppConstants.currentUserIdKey);
      _isLoggingOut = prefs.getBool(AppConstants.isLoggingOutKey) ?? false;

      // Sync with Hive
      if (_cachedUserId == null && _sessionBox != null) {
        _cachedUserId = _sessionBox!.get('current_user_id') as String?;
      }

      debugLog('UserSession', 'Initialized with user: $_cachedUserId');
    } catch (e) {
      debugLog('UserSession', 'Error initializing: $e');
    }
  }

  Future<void> setCurrentUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final previousUserId = await getCurrentUserId();

    await prefs.setString(AppConstants.currentUserIdKey, userId);

    // Save to Hive
    if (_sessionBox != null) {
      await _sessionBox!.put('current_user_id', userId);
    }

    if (previousUserId != null && previousUserId != userId) {
      await prefs.setString(AppConstants.lastUserIdKey, previousUserId);
      // Save last user to Hive
      if (_sessionBox != null) {
        await _sessionBox!.put('last_user_id', previousUserId);
      }
      debugLog(
          'UserSession', '🔄 User changed from $previousUserId to $userId');
    }

    _cachedUserId = userId;
  }

  Future<String?> getCurrentUserId() async {
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
    _isLoggingOut = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.isLoggingOutKey);
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
  }
}

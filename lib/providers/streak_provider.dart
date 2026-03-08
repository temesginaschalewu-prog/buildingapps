import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../services/user_session.dart';
import '../services/connectivity_service.dart';
import '../models/streak_model.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../utils/ui_helpers.dart';

class StreakProvider with ChangeNotifier {
  final ApiService apiService;
  final DeviceService deviceService;
  final ConnectivityService connectivityService;

  Streak? _streak;
  bool _isLoading = false;
  String? _error;
  List<DateTime> _streakHistory = [];
  Timer? _refreshTimer;
  String? _currentUserId;
  bool _isOffline = false;

  static const Duration _refreshInterval = Duration(minutes: 5);
  static const Duration _cacheDuration = AppConstants.cacheTTLStreak;

  StreakProvider({
    required this.apiService,
    required this.deviceService,
    required this.connectivityService,
  }) {
    _init();
    _setupConnectivityListener();
  }

  void _setupConnectivityListener() {
    connectivityService.onConnectivityChanged.listen((isOnline) {
      if (_isOffline != !isOnline) {
        _isOffline = !isOnline;
        if (!_isOffline) {
          loadStreak(forceRefresh: true);
        }
        notifyListeners();
      }
    });
  }

  Future<void> _init() async {
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (!_isLoading && !_isOffline) loadStreak(forceRefresh: true);
    });
    await _getCurrentUserId();
    await loadStreak();
  }

  Future<void> _getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString(AppConstants.currentUserIdKey);
  }

  Streak? get streak => _streak;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<DateTime> get streakHistory => _streakHistory;
  int get currentStreak => _streak?.currentStreak ?? 0;
  bool get isOffline => _isOffline;

  String get streakLevel => UiHelpers.getStreakLevel(currentStreak);
  Color get streakColor => UiHelpers.getStreakColor(currentStreak);
  String get motivationalMessage => UiHelpers.getStreakMessage(currentStreak);

  bool get hasStreakToday {
    final today = DateTime.now();
    return _streakHistory.any(
      (date) =>
          date.year == today.year &&
          date.month == today.month &&
          date.day == today.day,
    );
  }

  bool hasStreakOnDate(DateTime date) {
    return _streakHistory.any(
      (streakDate) =>
          streakDate.year == date.year &&
          streakDate.month == date.month &&
          streakDate.day == date.day,
    );
  }

  int getWeeklyStreak() {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    return _streakHistory.where((date) => date.isAfter(weekAgo)).length;
  }

  List<bool> getLast7DaysStreak() {
    final days = List<bool>.filled(7, false);
    final now = DateTime.now();

    for (final date in _streakHistory) {
      final diff = now.difference(date).inDays;
      if (diff < 7) days[6 - diff] = true;
    }
    return days;
  }

  Future<void> loadStreak(
      {bool forceRefresh = false, bool isManualRefresh = false}) async {
    if (_isLoading) return;

    // If this is a manual refresh, ALWAYS force refresh
    if (isManualRefresh) {
      forceRefresh = true;
    }

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      // STEP 1: ALWAYS try cache first (even when offline)
      if (!forceRefresh && _currentUserId != null) {
        final cachedStreak =
            await deviceService.getCacheItem<Map<String, dynamic>>(
                AppConstants.streakKey(_currentUserId!),
                isUserSpecific: true);
        if (cachedStreak != null) {
          _streak = Streak.fromJson(cachedStreak);
          _streakHistory = _streak?.history ?? [];
          _isLoading = false;
          _notifySafely();

          // STEP 2: If online, refresh in background
          if (!_isOffline) {
            unawaited(_refreshInBackground());
          }
          return;
        }
      }

      // STEP 3: If no cache, try API (only if online)
      if (_isOffline) {
        _error = 'You are offline. No cached streak available.';
        _isLoading = false;
        _notifySafely();

        if (isManualRefresh) {
          throw Exception(
              'Network error. Please check your internet connection.');
        }
        return;
      }

      final response = await apiService.getMyStreak();
      if (response.success && response.data != null) {
        _streak = Streak.fromJson(response.data!);
        _streakHistory = _streak?.history ?? [];

        if (_currentUserId != null) {
          await deviceService.saveCacheItem(
              AppConstants.streakKey(_currentUserId!), response.data!,
              ttl: _cacheDuration, isUserSpecific: true);
        }
      } else {
        if (isManualRefresh) {
          throw Exception(response.message ?? 'Failed to load streak');
        }
      }
    } catch (e) {
      _error = e.toString();

      if (isManualRefresh) {
        rethrow;
      }
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> _refreshInBackground() async {
    if (_isOffline) return;

    try {
      debugLog('StreakProvider', '🔄 Background refresh of streak');

      final response = await apiService.getMyStreak();
      if (response.success && response.data != null) {
        _streak = Streak.fromJson(response.data!);
        _streakHistory = _streak?.history ?? [];

        if (_currentUserId != null) {
          await deviceService.saveCacheItem(
              AppConstants.streakKey(_currentUserId!), response.data!,
              ttl: _cacheDuration, isUserSpecific: true);
        }

        _notifySafely();

        debugLog('StreakProvider', '✅ Background refresh completed');
      }
    } catch (e) {
      debugLog('StreakProvider', '⚠️ Background refresh error: $e');
    }
  }

  Future<void> updateStreak() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      if (_isOffline) {
        // Queue for offline sync
        await _queueStreakUpdateOffline();
        _isLoading = false;
        _notifySafely();
        return;
      }

      await apiService.updateStreak();
      await loadStreak(forceRefresh: true);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> _queueStreakUpdateOffline() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = await UserSession().getCurrentUserId();

      if (userId == null) return;

      const pendingKey = 'pending_streak_updates';
      final userPendingKey = '${pendingKey}_$userId';
      final existingJson = prefs.getString(userPendingKey);
      List<Map<String, dynamic>> pendingUpdates = [];

      if (existingJson != null) {
        try {
          pendingUpdates =
              List<Map<String, dynamic>>.from(jsonDecode(existingJson));
        } catch (e) {
          debugLog('StreakProvider', 'Error parsing pending updates: $e');
        }
      }

      pendingUpdates.add({
        'timestamp': DateTime.now().toIso8601String(),
        'retry_count': 0,
      });

      await prefs.setString(userPendingKey, jsonEncode(pendingUpdates));
      debugLog('StreakProvider', '📝 Queued streak update for offline sync');
    } catch (e) {
      debugLog('StreakProvider', 'Error queueing streak update: $e');
    }
  }

  Future<void> syncPendingStreakUpdates() async {
    if (_isOffline) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = await UserSession().getCurrentUserId();

      if (userId == null) return;

      const pendingKey = 'pending_streak_updates';
      final userPendingKey = '${pendingKey}_$userId';
      final existingJson = prefs.getString(userPendingKey);

      if (existingJson == null) return;

      List<Map<String, dynamic>> pendingUpdates = [];
      try {
        pendingUpdates =
            List<Map<String, dynamic>>.from(jsonDecode(existingJson));
      } catch (e) {
        debugLog('StreakProvider', 'Error parsing pending updates: $e');
        await prefs.remove(userPendingKey);
        return;
      }

      if (pendingUpdates.isEmpty) return;

      debugLog('StreakProvider',
          '🔄 Syncing ${pendingUpdates.length} pending streak updates');

      final List<Map<String, dynamic>> failedUpdates = [];

      for (final update in pendingUpdates) {
        try {
          await apiService.updateStreak();
          debugLog('StreakProvider', '✅ Synced streak update');
        } catch (e) {
          debugLog('StreakProvider', '❌ Failed to sync streak update: $e');

          final retryCount = (update['retry_count'] ?? 0) + 1;
          if (retryCount <= 3) {
            update['retry_count'] = retryCount;
            failedUpdates.add(update);
          }
        }
      }

      if (failedUpdates.isEmpty) {
        await prefs.remove(userPendingKey);
        debugLog('StreakProvider', '✅ All pending streak updates synced');
      } else {
        await prefs.setString(userPendingKey, jsonEncode(failedUpdates));
        debugLog('StreakProvider',
            '⚠️ ${failedUpdates.length} streak updates still pending');
      }

      // Refresh streak after sync
      await loadStreak(forceRefresh: true);
    } catch (e) {
      debugLog('StreakProvider', 'Error syncing pending updates: $e');
    }
  }

  Future<void> clearUserData() async {
    debugLog('StreakProvider', 'Clearing streak data');

    final session = UserSession();
    final isDifferentUser = !await session.isSameUser();
    final isLoggingOut = await _isLoggingOut();

    if (!isDifferentUser || !isLoggingOut) {
      debugLog('StreakProvider', '✅ Same user - preserving streak cache');
      return;
    }

    // Clear pending updates
    final userId = await session.getCurrentUserId();
    if (userId != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_streak_updates_$userId');
    }

    if (_currentUserId != null) {
      await deviceService.removeCacheItem(
          AppConstants.streakKey(_currentUserId!),
          isUserSpecific: true);
    }
    _streak = null;
    _streakHistory = [];
    _notifySafely();
  }

  Future<bool> _isLoggingOut() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.isLoggingOutKey) ?? false;
  }

  void clearError() {
    _error = null;
    _notifySafely();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _notifySafely() {
    if (hasListeners) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (hasListeners) notifyListeners();
      });
    }
  }
}

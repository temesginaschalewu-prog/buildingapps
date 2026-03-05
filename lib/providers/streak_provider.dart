import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../services/user_session.dart';
import '../models/streak_model.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../utils/ui_helpers.dart';

class StreakProvider with ChangeNotifier {
  final ApiService apiService;
  final DeviceService deviceService;

  Streak? _streak;
  bool _isLoading = false;
  String? _error;
  List<DateTime> _streakHistory = [];
  Timer? _refreshTimer;
  String? _currentUserId;

  static const Duration _refreshInterval = Duration(minutes: 5);
  static const Duration _cacheDuration = Duration(hours: 1);

  StreakProvider({required this.apiService, required this.deviceService}) {
    _init();
  }

  Future<void> _init() async {
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (!_isLoading) loadStreak(forceRefresh: true);
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

  Future<void> loadStreak({bool forceRefresh = false}) async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
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
          return;
        }
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
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> updateStreak() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      await apiService.updateStreak();
      await loadStreak(forceRefresh: true);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      _notifySafely();
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

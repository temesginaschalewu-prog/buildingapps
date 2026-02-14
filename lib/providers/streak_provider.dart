import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../models/streak_model.dart';
import '../utils/helpers.dart';

class StreakProvider with ChangeNotifier {
  final ApiService apiService;
  final DeviceService deviceService;

  Streak? _streak;
  bool _isLoading = false;
  String? _error;
  List<DateTime> _streakHistory = [];

  StreakProvider({required this.apiService, required this.deviceService});

  Streak? get streak => _streak;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<DateTime> get streakHistory => _streakHistory;

  int get currentStreak => _streak?.currentStreak ?? 0;

  Future<void> loadStreak({required bool forceRefresh}) async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('StreakProvider', 'Loading streak');

      final cachedStreak = await deviceService.getCacheItem<Streak>('streak');
      if (cachedStreak != null) {
        _streak = cachedStreak;
        _streakHistory = cachedStreak.history;
        _isLoading = false;
        _notifySafely();
        debugLog('StreakProvider', '✅ Loaded streak from cache');
        return;
      }

      final response = await apiService.getMyStreak();
      if (response.data != null) {
        _streak = Streak.fromJson(response.data!);

        final historyData = response.data!['history'] ?? [];
        _streakHistory = List<DateTime>.from(
          (historyData as List).map((dateStr) => DateTime.parse(dateStr)),
        );

        await deviceService.saveCacheItem('streak', _streak,
            ttl: Duration(minutes: 5));
      }
      debugLog('StreakProvider', 'Loaded streak: ${_streak?.currentStreak}');
    } catch (e) {
      _error = e.toString();
      debugLog('StreakProvider', 'loadStreak error: $e');
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
      debugLog('StreakProvider', 'Updating streak');
      await apiService.updateStreak();

      await loadStreak(forceRefresh: true);
    } catch (e) {
      _error = e.toString();
      debugLog('StreakProvider', 'updateStreak error: $e');
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

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
      if (diff < 7) {
        days[6 - diff] = true;
      }
    }

    return days;
  }

  Future<void> clearUserData() async {
    debugLog('StreakProvider', 'Clearing streak data');

    await deviceService.removeCacheItem('streak');

    _streak = null;
    _streakHistory = [];

    _notifySafely();
  }

  void clearError() {
    _error = null;
    _notifySafely();
  }

  void _notifySafely() {
    if (hasListeners) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (hasListeners) {
          notifyListeners();
        }
      });
    }
  }
}

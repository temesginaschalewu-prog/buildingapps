import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../models/streak_model.dart';

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
    _currentUserId = prefs.getString('current_user_id');
  }

  Streak? get streak => _streak;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<DateTime> get streakHistory => _streakHistory;

  int get currentStreak => _streak?.currentStreak ?? 0;

  String get streakLevel {
    final count = currentStreak;
    if (count >= 365) return 'Legendary 🔥🔥🔥';
    if (count >= 100) return 'Elite 🏆';
    if (count >= 50) return 'Master ⭐';
    if (count >= 30) return 'Dedicated 📚';
    if (count >= 14) return 'Committed 💪';
    if (count >= 7) return 'Consistent 🚀';
    if (count >= 3) return 'Growing 🌱';
    return 'New ✨';
  }

  Color get streakColor {
    final count = currentStreak;
    if (count >= 100) return const Color(0xFFFFD700);
    if (count >= 50) return const Color(0xFFC0C0C0);
    if (count >= 30) return const Color(0xFFCD7F32);
    if (count >= 14) return const Color(0xFF34C759);
    if (count >= 7) return const Color(0xFF2AABEE);
    return const Color(0xFFFF9500);
  }

  IconData get streakIcon {
    final count = currentStreak;
    if (count >= 100) return Icons.emoji_events;
    if (count >= 50) return Icons.military_tech;
    if (count >= 30) return Icons.workspace_premium;
    if (count >= 14) return Icons.star;
    if (count >= 7) return Icons.local_fire_department;
    return Icons.bolt;
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
          'streak_$_currentUserId',
          isUserSpecific: true,
        );
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
            'streak_$_currentUserId',
            response.data!,
            ttl: _cacheDuration,
            isUserSpecific: true,
          );
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

  String getMotivationalMessage() {
    final count = currentStreak;
    if (count >= 365) return "ONE YEAR! You're a true legend! 🏆";
    if (count >= 100) return "100 days! You're in the elite club! 👑";
    if (count >= 50) return "50 days of dedication! You're a master! ⭐";
    if (count >= 30) return "30 days! You've built an incredible habit! 📚";
    if (count >= 14) return 'Two weeks strong! Keep going! 💪';
    if (count >= 7) return 'One week! Consistency is your superpower! 🚀';
    if (count >= 3) return "3 days in a row! You're building momentum! 🌱";
    if (count == 2) return 'Two days! Come back tomorrow! 🔥';
    if (count == 1) return 'Great start! Make it two tomorrow! ✨';
    return 'Start your streak today! 📅';
  }

  Future<void> clearUserData() async {
    if (_currentUserId != null) {
      await deviceService.removeCacheItem('streak_$_currentUserId',
          isUserSpecific: true);
    }
    _streak = null;
    _streakHistory = [];
    _notifySafely();
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

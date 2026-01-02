import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/streak_model.dart';
import '../utils/helpers.dart';

class StreakProvider with ChangeNotifier {
  final ApiService apiService;

  Streak? _streak;
  bool _isLoading = false;
  String? _error;

  StreakProvider({required this.apiService});

  Streak? get streak => _streak;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get currentStreak => _streak?.currentStreak ?? 0;
  List<DateTime> get streakHistory => _streak?.history ?? [];

  Future<void> loadStreak() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('StreakProvider', 'Loading streak');
      final response = await apiService.getMyStreak();
      if (response.data != null) {
        _streak = Streak.fromJson(response.data!);
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

      // Reload streak after update
      await loadStreak();
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
    return streakHistory.any(
      (date) =>
          date.year == today.year &&
          date.month == today.month &&
          date.day == today.day,
    );
  }

  void clearStreak() {
    _streak = null;
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

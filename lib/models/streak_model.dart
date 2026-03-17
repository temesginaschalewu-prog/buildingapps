import '../utils/parsers.dart';
import 'package:hive/hive.dart'; // NEW

part 'streak_model.g.dart'; // NEW

@HiveType(typeId: 15) // NEW
class Streak {
  @HiveField(0)
  final int currentStreak;

  @HiveField(1)
  final int weekStreak;

  @HiveField(2)
  final bool hasStreakToday;

  @HiveField(3)
  final String streakLevel;

  @HiveField(4)
  final String longestStreak;

  @HiveField(5)
  final List<DateTime> history;

  Streak({
    required this.currentStreak,
    required this.weekStreak,
    required this.hasStreakToday,
    required this.streakLevel,
    required this.longestStreak,
    required this.history,
  });

  factory Streak.fromJson(Map<String, dynamic> json) {
    List<DateTime> parsedHistory = [];
    if (json['history'] != null && json['history'] is List) {
      parsedHistory = (json['history'] as List)
          .map((item) => item is DateTime
              ? item
              : Parsers.parseDate(item) ?? DateTime.now())
          .toList();
    }

    return Streak(
      currentStreak: Parsers.parseInt(json['current_streak']),
      weekStreak:
          Parsers.parseInt(json['week_streak'] ?? json['initialWeekStreak']),
      hasStreakToday: Parsers.parseBool(json['has_streak_today']),
      streakLevel: json['level']?.toString() ??
          json['streak_level']?.toString() ??
          '🌱 New',
      longestStreak: json['longest_streak']?.toString() ?? '0',
      history: parsedHistory,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'current_streak': currentStreak,
      'week_streak': weekStreak,
      'has_streak_today': hasStreakToday,
      'streak_level': streakLevel,
      'longest_streak': longestStreak,
      'history': history.map((x) => x.toIso8601String()).toList(),
    };
  }

  int get weekStreakCount {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    return history.where((date) => date.isAfter(weekAgo)).length;
  }

  bool get calculatedHasStreakToday {
    final today = DateTime.now();
    return history.any(
      (date) =>
          date.year == today.year &&
          date.month == today.month &&
          date.day == today.day,
    );
  }
}

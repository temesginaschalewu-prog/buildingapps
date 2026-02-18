class Streak {
  final int currentStreak;
  final int weekStreak;
  final bool hasStreakToday;
  final String streakLevel;
  final String longestStreak;
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
    // Parse history correctly from strings
    List<DateTime> parsedHistory = [];
    if (json['history'] != null && json['history'] is List) {
      parsedHistory = (json['history'] as List).map((item) {
        if (item is DateTime) return item;
        if (item is String) {
          try {
            return DateTime.parse(item).toLocal();
          } catch (e) {
            print('Error parsing date: $item');
            return DateTime.now();
          }
        }
        return DateTime.now();
      }).toList();
    }

    return Streak(
      currentStreak: json['current_streak'] ?? 0,
      weekStreak: json['week_streak'] ?? json['initialWeekStreak'] ?? 0,
      hasStreakToday: json['has_streak_today'] ?? false,
      streakLevel: json['level'] ?? json['streak_level'] ?? '🌱 New',
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

  String get calculatedStreakLevel {
    if (currentStreak >= 30) return '🔥 Legendary';
    if (currentStreak >= 20) return '⭐ Superstar';
    if (currentStreak >= 10) return '📚 Dedicated';
    if (currentStreak >= 5) return '🚀 Consistent';
    if (currentStreak >= 2) return '🌱 Growing';
    return '🌱 New';
  }
}

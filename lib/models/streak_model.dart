class Streak {
  final int currentStreak;
  final int initialWeekStreak;
  final bool hasStreakToday;
  final String streakLevel;
  final String longestStreak;
  final List<DateTime> history;

  Streak({
    required this.currentStreak,
    required this.initialWeekStreak,
    required this.hasStreakToday,
    required this.streakLevel,
    required this.longestStreak,
    required this.history,
  });

  factory Streak.fromJson(Map<String, dynamic> json) {
    return Streak(
      currentStreak: json['current_streak'] ?? 0,
      initialWeekStreak: json['week_streak'] ?? 0,
      hasStreakToday: json['has_streak_today'] ?? false,
      streakLevel: json['streak_level'] ?? '🌱 New',
      longestStreak: json['longest_streak'] ?? '0',
      history: List<DateTime>.from(
        (json['history'] as List).map((x) => DateTime.parse(x)),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'current_streak': currentStreak,
      'history': history.map((x) => x.toIso8601String()).toList(),
    };
  }

  int get weekStreak {
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

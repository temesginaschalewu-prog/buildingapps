class Streak {
  final int currentStreak;
  final List<DateTime> history;

  Streak({required this.currentStreak, required this.history});

  factory Streak.fromJson(Map<String, dynamic> json) {
    return Streak(
      currentStreak: json['current_streak'] ?? 0,
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

  bool get hasStreakToday {
    final today = DateTime.now();
    return history.any(
      (date) =>
          date.year == today.year &&
          date.month == today.month &&
          date.day == today.day,
    );
  }

  String get streakLevel {
    if (currentStreak >= 30) return '🔥 Legendary';
    if (currentStreak >= 20) return '⭐ Superstar';
    if (currentStreak >= 10) return '📚 Dedicated';
    if (currentStreak >= 5) return '🚀 Consistent';
    if (currentStreak >= 2) return '🌱 Growing';
    return '🌱 New';
  }
}

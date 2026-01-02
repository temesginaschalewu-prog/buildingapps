import 'package:flutter/material.dart';
import '../../models/streak_model.dart';

class StreakWidget extends StatelessWidget {
  final Streak? streak;

  const StreakWidget({super.key, this.streak});

  String get _streakLevel {
    final count = streak?.currentStreak ?? 0;
    if (count >= 30) return '🔥 Legendary';
    if (count >= 20) return '⭐ Superstar';
    if (count >= 10) return '📚 Dedicated';
    if (count >= 5) return '🚀 Consistent';
    if (count >= 2) return '🌱 Growing';
    return '🌱 New';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Streak',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                    Text(
                      '${streak?.currentStreak ?? 0} days',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'This Week',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                    Text(
                      '${streak?.weekStreak ?? 0}/7 days',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: (streak?.weekStreak ?? 0) / 7,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _streakLevel,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

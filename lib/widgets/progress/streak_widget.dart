import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../themes/app_themes.dart';
import '../../utils/responsive.dart';
import '../../models/streak_model.dart';

class StreakWidget extends StatelessWidget {
  final Streak? streak;
  final Function()? onTap;

  const StreakWidget({super.key, this.streak, this.onTap});

  String get _streakLevel {
    final count = streak?.currentStreak ?? 0;
    if (count >= 30) return 'Legendary';
    if (count >= 20) return 'Superstar';
    if (count >= 10) return 'Dedicated';
    if (count >= 5) return 'Consistent';
    if (count >= 2) return 'Growing';
    return 'New';
  }

  Color _getStreakColor(BuildContext context) {
    final count = streak?.currentStreak ?? 0;
    if (count >= 30) return Color(0xFFFF9500);
    if (count >= 20) return Color(0xFFAF52DE);
    if (count >= 10) return Color(0xFF34C759);
    if (count >= 5) return Color(0xFF5AC8FA);
    return Color(0xFF2AABEE);
  }

  IconData _getStreakIcon(int count) {
    if (count >= 30) return Icons.workspace_premium;
    if (count >= 20) return Icons.star_rate;
    if (count >= 10) return Icons.school;
    if (count >= 5) return Icons.trending_up;
    return Icons.emoji_events;
  }

  String _getEmoji(int count) {
    if (count >= 30) return '🔥';
    if (count >= 20) return '⭐';
    if (count >= 10) return '📚';
    if (count >= 5) return '🚀';
    if (count >= 2) return '🌱';
    return '✨';
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ScreenSize.isDesktop(context);
    final count = streak?.currentStreak ?? 0;
    final weekStreak = streak?.weekStreak ?? 0;
    final streakColor = _getStreakColor(context);
    final emoji = _getEmoji(count);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: isDesktop ? AppThemes.spacingXXL : AppThemes.spacingL,
          vertical: AppThemes.spacingM,
        ),
        padding: EdgeInsets.all(
            isDesktop ? AppThemes.spacingXL : AppThemes.spacingL),
        decoration: BoxDecoration(
          color: AppColors.getCard(context),
          borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
          border: Border.all(
            color:
                Theme.of(context).dividerTheme.color ?? AppColors.lightDivider,
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: streakColor.withOpacity(0.1),
                        borderRadius:
                            BorderRadius.circular(AppThemes.borderRadiusMedium),
                      ),
                      child: Icon(
                        _getStreakIcon(count),
                        size: 24,
                        color: streakColor,
                      ),
                    ),
                    const SizedBox(width: AppThemes.spacingM),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Learning Streak',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.getTextSecondary(context),
                          ),
                        ),
                        Text(
                          '$count days $emoji',
                          style: AppTextStyles.titleMedium.copyWith(
                            color: AppColors.getTextPrimary(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppThemes.spacingM,
                    vertical: AppThemes.spacingXS,
                  ),
                  decoration: BoxDecoration(
                    color: streakColor.withOpacity(0.1),
                    borderRadius:
                        BorderRadius.circular(AppThemes.borderRadiusFull),
                    border: Border.all(
                      color: streakColor,
                      width: 1.0,
                    ),
                  ),
                  child: Text(
                    _streakLevel,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: streakColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppThemes.spacingL),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'This Week',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.getTextPrimary(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '$weekStreak/7 days',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppThemes.spacingS),
                Stack(
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.black.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    AnimatedFractionallySizedBox(
                      widthFactor: weekStreak / 7,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOut,
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              streakColor,
                              streakColor.withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppThemes.spacingS),
                if (!isDesktop) ...[
                  _buildWeekDays(context, weekStreak),
                  const SizedBox(height: AppThemes.spacingM),
                ],
              ],
            ),
            if (count > 0)
              Container(
                margin: const EdgeInsets.only(top: AppThemes.spacingL),
                padding: const EdgeInsets.all(AppThemes.spacingM),
                decoration: BoxDecoration(
                  color: streakColor.withOpacity(0.05),
                  borderRadius:
                      BorderRadius.circular(AppThemes.borderRadiusMedium),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.psychology_outlined,
                      size: 18,
                      color: streakColor,
                    ),
                    const SizedBox(width: AppThemes.spacingS),
                    Expanded(
                      child: Text(
                        _getMotivationalTip(count),
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.getTextSecondary(context),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            if (isDesktop) ...[
              const SizedBox(height: AppThemes.spacingL),
              _buildWeekDays(context, weekStreak),
            ],
          ],
        ),
      ).animate().fadeIn().slideY(
            begin: 0.05,
            end: 0,
            duration: AppThemes.animationDurationMedium,
          ),
    );
  }

  Widget _buildWeekDays(BuildContext context, int weekStreak) {
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final now = DateTime.now();
    final todayIndex = now.weekday - 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (index) {
        final isActive = index < weekStreak;
        final isToday = index == todayIndex;

        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isToday
                ? _getStreakColor(context).withOpacity(0.2)
                : isActive
                    ? _getStreakColor(context).withOpacity(0.1)
                    : Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.04),
            borderRadius: BorderRadius.circular(AppThemes.borderRadiusSmall),
            border: isToday
                ? Border.all(color: _getStreakColor(context), width: 1.5)
                : null,
          ),
          child: Center(
            child: Text(
              days[index],
              style: AppTextStyles.labelSmall.copyWith(
                color: isActive || isToday
                    ? _getStreakColor(context)
                    : AppColors.getTextSecondary(context),
                fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        );
      }),
    );
  }

  String _getMotivationalTip(int streak) {
    if (streak >= 30) return "Legendary streak! You're unstoppable!";
    if (streak >= 20) return "Superstar! Keep inspiring others.";
    if (streak >= 10) return "Great discipline! Momentum is building.";
    if (streak >= 5) return "Consistency pays off. Keep going!";
    if (streak >= 2) return "Building habits! Every day counts.";
    return "Start strong! Learning is a journey.";
  }
}

class AnimatedFractionallySizedBox extends StatelessWidget {
  final double widthFactor;
  final Duration duration;
  final Curve curve;
  final Widget child;

  const AnimatedFractionallySizedBox({
    super.key,
    required this.widthFactor,
    required this.duration,
    required this.curve,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: widthFactor),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        return FractionallySizedBox(
          widthFactor: value,
          child: child,
        );
      },
      child: child,
    );
  }
}

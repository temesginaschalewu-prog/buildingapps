import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/responsive_values.dart';
import '../common/app_card.dart';

/// PRODUCTION-READY ACHIEVEMENT BADGE
class AchievementBadge extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool unlocked;
  final DateTime? earnedDate;

  const AchievementBadge({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.unlocked,
    this.earnedDate,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard.glass(
      child: Container(
        padding: EdgeInsets.all(ResponsiveValues.spacingS(context)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: ResponsiveValues.iconSizeXL(context) * 1.5,
              height: ResponsiveValues.iconSizeXL(context) * 1.5,
              decoration: BoxDecoration(
                gradient: unlocked
                    ? LinearGradient(
                        colors: [
                          color.withValues(alpha: 0.2),
                          color.withValues(alpha: 0.1)
                        ],
                      )
                    : LinearGradient(
                        colors: [
                          AppColors.telegramGray.withValues(alpha: 0.1),
                          AppColors.telegramGray.withValues(alpha: 0.05)
                        ],
                      ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  unlocked ? icon : Icons.lock_rounded,
                  size: ResponsiveValues.iconSizeL(context),
                  color: unlocked ? color : AppColors.telegramGray,
                ),
              ),
            ),
            SizedBox(height: ResponsiveValues.spacingXS(context)),
            Text(
              title,
              style: AppTextStyles.labelMedium(context).copyWith(
                color: unlocked ? color : AppColors.getTextSecondary(context),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (unlocked && earnedDate != null) ...[
              SizedBox(height: ResponsiveValues.spacingXXS(context)),
              Text(
                _formatDate(earnedDate!),
                style: AppTextStyles.caption(context).copyWith(
                  color: AppColors.getTextSecondary(context),
                ),
              ),
            ],
          ],
        ),
      ),
    )
        .animate()
        .scale(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1, 1),
          duration: 300.ms,
        )
        .fadeIn(duration: 300.ms);
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks week${weeks > 1 ? 's' : ''} ago';
    } else {
      return '${date.month}/${date.year}';
    }
  }
}

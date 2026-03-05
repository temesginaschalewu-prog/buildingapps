import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../themes/app_themes.dart';
import '../../utils/responsive_values.dart';
import '../common/app_card.dart';
import '../common/responsive_widgets.dart';

class AchievementBadge extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final double progress;
  final bool unlocked;
  final DateTime? earnedDate;

  const AchievementBadge({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.progress = 1.0,
    this.unlocked = false,
    this.earnedDate,
  });

  @override
  Widget build(BuildContext context) {
    final padding = ResponsiveValues.cardPadding(context);
    final iconContainerSize = ResponsiveValues.iconSizeXXL(context) * 1.5;
    final iconSize = ResponsiveValues.iconSizeXL(context);
    final titleSize = ResponsiveValues.fontTitleSmall(context);
    final descSize = ResponsiveValues.fontBodySmall(context);
    final badgeSize = ResponsiveValues.fontLabelSmall(context);

    return AppCard.glass(
      child: Padding(
        padding: padding,
        child: ResponsiveColumn(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: iconContainerSize,
                  height: iconContainerSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        color.withValues(alpha: unlocked ? 0.2 : 0.1),
                        color.withValues(alpha: unlocked ? 0.1 : 0.05),
                      ],
                    ),
                    border: Border.all(
                      color: unlocked ? color : color.withValues(alpha: 0.3),
                      width: 3,
                    ),
                  ),
                  child: Stack(
                    children: [
                      if (!unlocked && progress > 0)
                        Positioned.fill(
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 3,
                            backgroundColor: AppColors.getSurface(context),
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                        ),
                      Center(
                        child: ResponsiveIcon(
                          icon,
                          size: iconSize,
                          color:
                              unlocked ? color : color.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!unlocked)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding:
                          EdgeInsets.all(ResponsiveValues.spacingXXS(context)),
                      decoration: BoxDecoration(
                        color: AppColors.getBackground(context),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.getTextSecondary(context),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: ResponsiveValues.spacingXS(context),
                          ),
                        ],
                      ),
                      child: ResponsiveIcon(
                        Icons.lock_outline_rounded,
                        size: ResponsiveValues.iconSizeXS(context),
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                  ),
              ],
            ),
            const ResponsiveSizedBox(height: AppSpacing.m),
            ResponsiveText(
              title,
              style: AppTextStyles.titleSmall(context).copyWith(
                color: unlocked ? color : AppColors.getTextPrimary(context),
                fontWeight: FontWeight.w600,
                fontSize: titleSize,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const ResponsiveSizedBox(height: AppSpacing.xs),
            ResponsiveText(
              description,
              style: AppTextStyles.bodySmall(context).copyWith(
                color: AppColors.getTextSecondary(context),
                fontSize: descSize,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (unlocked && earnedDate != null)
              Padding(
                padding: EdgeInsets.only(
                  top: ResponsiveValues.spacingS(context),
                ),
                child: ResponsiveText(
                  _formatDate(earnedDate!),
                  style: AppTextStyles.labelSmall(context).copyWith(
                    color: color,
                    fontSize: badgeSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (!unlocked && progress > 0)
              Padding(
                padding: EdgeInsets.only(
                  top: ResponsiveValues.spacingS(context),
                ),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveValues.spacingS(context),
                    vertical: ResponsiveValues.spacingXXS(context),
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(
                      ResponsiveValues.radiusFull(context),
                    ),
                    border: Border.all(color: color),
                  ),
                  child: ResponsiveText(
                    '${(progress * 100).toInt()}%',
                    style: AppTextStyles.labelSmall(context).copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: badgeSize,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ).animate().scale(
        duration: AppThemes.animationDurationMedium,
        begin: const Offset(0.95, 0.95),
        end: const Offset(1, 1));
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) return 'Today';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

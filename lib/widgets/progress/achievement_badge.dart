import 'dart:ui';
import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../themes/app_themes.dart';
import '../../utils/responsive.dart';

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

  Widget _buildGlassContainer(BuildContext context, {required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.getCard(context).withOpacity(0.4),
                AppColors.getCard(context).withOpacity(0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: unlocked ? color : AppColors.telegramBlue.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    final padding = isMobile
        ? AppThemes.spacingL
        : (isTablet ? AppThemes.spacingXL : AppThemes.spacingXXL);
    final iconContainerSize = isMobile ? 60.0 : (isTablet ? 70.0 : 80.0);
    final iconSize = isMobile ? 28.0 : (isTablet ? 32.0 : 36.0);
    final titleSize = isMobile ? 14.0 : (isTablet ? 15.0 : 16.0);
    final descSize = isMobile ? 11.0 : (isTablet ? 12.0 : 13.0);
    final badgeSize = isMobile ? 10.0 : (isTablet ? 11.0 : 12.0);

    return _buildGlassContainer(
      context,
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
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
                        color.withOpacity(unlocked ? 0.2 : 0.1),
                        color.withOpacity(unlocked ? 0.1 : 0.05),
                      ],
                    ),
                    border: Border.all(
                      color: unlocked ? color : color.withOpacity(0.3),
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
                        child: Icon(
                          icon,
                          size: iconSize,
                          color: unlocked ? color : color.withOpacity(0.5),
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
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.getBackground(context),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.getTextSecondary(context),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4)
                        ],
                      ),
                      child: Icon(
                        Icons.lock_outline_rounded,
                        size: isMobile ? 14 : (isTablet ? 15 : 16),
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(
                height: isMobile
                    ? AppThemes.spacingM
                    : (isTablet ? AppThemes.spacingL : AppThemes.spacingXL)),
            Text(
              title,
              style: AppTextStyles.titleSmall.copyWith(
                color: unlocked ? color : AppColors.getTextPrimary(context),
                fontWeight: FontWeight.w600,
                fontSize: titleSize,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(
                height: isMobile
                    ? AppThemes.spacingXS
                    : (isTablet ? AppThemes.spacingS : AppThemes.spacingM)),
            Text(
              description,
              style: AppTextStyles.bodySmall.copyWith(
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
                    top: isMobile
                        ? AppThemes.spacingS
                        : (isTablet ? AppThemes.spacingM : AppThemes.spacingL)),
                child: Text(
                  _formatDate(earnedDate!),
                  style: AppTextStyles.labelSmall.copyWith(
                    color: color,
                    fontSize: badgeSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (!unlocked && progress > 0)
              Padding(
                padding: EdgeInsets.only(
                    top: isMobile
                        ? AppThemes.spacingS
                        : (isTablet ? AppThemes.spacingM : AppThemes.spacingL)),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile
                        ? AppThemes.spacingS
                        : (isTablet ? AppThemes.spacingM : AppThemes.spacingL),
                    vertical: isMobile
                        ? AppThemes.spacingXS
                        : (isTablet ? AppThemes.spacingS : AppThemes.spacingM),
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius:
                        BorderRadius.circular(AppThemes.borderRadiusFull),
                    border: Border.all(color: color, width: 1),
                  ),
                  child: Text(
                    '${(progress * 100).toInt()}%',
                    style: AppTextStyles.labelSmall.copyWith(
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

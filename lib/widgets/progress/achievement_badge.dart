import 'package:flutter/material.dart';
import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';
import 'package:familyacademyclient/themes/app_themes.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AchievementBadge extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final double progress;
  final bool unlocked;

  const AchievementBadge({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.progress = 1.0,
    this.unlocked = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(ScreenSize.responsiveValue(
        context: context,
        mobile: AppThemes.spacingL,
        tablet: AppThemes.spacingXL,
        desktop: AppThemes.spacingXXL,
      )),
      decoration: BoxDecoration(
        color: unlocked
            ? color.withOpacity(0.08)
            : AppColors.getSurface(context).withOpacity(0.5),
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
        border: Border.all(
          color: unlocked ? color : AppColors.getTextSecondary(context),
          width: 1.5,
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
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: ScreenSize.responsiveValue(
                  context: context,
                  mobile: 60,
                  tablet: 70,
                  desktop: 80,
                ),
                height: ScreenSize.responsiveValue(
                  context: context,
                  mobile: 60,
                  tablet: 70,
                  desktop: 80,
                ),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color:
                        unlocked ? color : AppColors.getTextSecondary(context),
                    width: 3,
                  ),
                  color:
                      unlocked ? color.withOpacity(0.15) : Colors.transparent,
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
                        size: ScreenSize.responsiveValue(
                          context: context,
                          mobile: 28,
                          tablet: 32,
                          desktop: 36,
                        ),
                        color: unlocked
                            ? color
                            : AppColors.getTextSecondary(context),
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
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.lock_outline_rounded,
                      size: ScreenSize.responsiveValue(
                        context: context,
                        mobile: 14,
                        tablet: 16,
                        desktop: 18,
                      ),
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(
            height: ScreenSize.responsiveValue(
              context: context,
              mobile: AppThemes.spacingM,
              tablet: AppThemes.spacingL,
              desktop: AppThemes.spacingXL,
            ),
          ),
          Text(
            title,
            style: AppTextStyles.titleSmall.copyWith(
              color: AppColors.getTextPrimary(context),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(
            height: ScreenSize.responsiveValue(
              context: context,
              mobile: AppThemes.spacingXS,
              tablet: AppThemes.spacingS,
              desktop: AppThemes.spacingM,
            ),
          ),
          Text(
            description,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.getTextSecondary(context),
              fontSize: ScreenSize.responsiveFontSize(
                context: context,
                mobile: 11,
                tablet: 12,
                desktop: 13,
              ),
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (!unlocked && progress > 0)
            Padding(
              padding: EdgeInsets.only(
                top: ScreenSize.responsiveValue(
                  context: context,
                  mobile: AppThemes.spacingS,
                  tablet: AppThemes.spacingM,
                  desktop: AppThemes.spacingL,
                ),
              ),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ScreenSize.responsiveValue(
                    context: context,
                    mobile: AppThemes.spacingS,
                    tablet: AppThemes.spacingM,
                    desktop: AppThemes.spacingL,
                  ),
                  vertical: ScreenSize.responsiveValue(
                    context: context,
                    mobile: AppThemes.spacingXS,
                    tablet: AppThemes.spacingS,
                    desktop: AppThemes.spacingM,
                  ),
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius:
                      BorderRadius.circular(AppThemes.borderRadiusFull),
                  border: Border.all(
                    color: color,
                    width: 1,
                  ),
                ),
                child: Text(
                  '${(progress * 100).toInt()}%',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: ScreenSize.responsiveFontSize(
                      context: context,
                      mobile: 10,
                      tablet: 11,
                      desktop: 12,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ).animate().scale(
          duration: AppThemes.animationDurationMedium,
          begin: const Offset(0.95, 0.95),
          end: const Offset(1, 1),
        );
  }
}

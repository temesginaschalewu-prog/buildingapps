import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../models/course_model.dart';
import '../../providers/settings_provider.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/responsive_values.dart';
import '../../utils/ui_helpers.dart';
import '../common/app_card.dart';

/// PRODUCTION-READY COURSE CARD
class CourseCard extends StatelessWidget {
  final Course course;
  final int categoryId;
  final VoidCallback onTap;
  final int index;

  const CourseCard({
    super.key,
    required this.course,
    required this.categoryId,
    required this.onTap,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.read<SettingsProvider>();
    final bool hasFullAccess = course.hasFullAccess(true);
    const bool hasPendingPayment = false; // This would come from provider
    final bool requiresPayment = course.requiresPayment;

    final accessColor = UiHelpers.getCourseAccessColor(
      hasFullAccess,
      hasPendingPayment,
    );

    final accessIcon = UiHelpers.getCourseAccessIcon(
      hasFullAccess,
      hasPendingPayment,
    );

    final accessText = UiHelpers.getCourseAccessText(
      hasFullAccess,
      hasPendingPayment,
      requiresPayment,
      settingsProvider: settingsProvider,
    );

    return AppCard.course(
      onTap: onTap,
      accentColor: hasFullAccess ? AppColors.telegramGreen : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius:
              BorderRadius.circular(ResponsiveValues.radiusXLarge(context)),
          splashColor: AppColors.telegramBlue.withValues(alpha: 0.1),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: ResponsiveValues.cardPadding(context),
            child: Row(
              children: [
                // Icon
                Container(
                  width: ResponsiveValues.iconSizeXXL(context),
                  height: ResponsiveValues.iconSizeXXL(context),
                  decoration: BoxDecoration(
                    color: hasFullAccess
                        ? AppColors.telegramGreen.withValues(alpha: 0.09)
                        : AppColors.telegramBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusLarge(context)),
                  ),
                  child: Icon(
                    Icons.menu_book_rounded,
                    size: ResponsiveValues.iconSizeL(context),
                    color: hasFullAccess
                        ? AppColors.telegramGreen
                        : AppColors.telegramBlue,
                  ),
                ),
                SizedBox(width: ResponsiveValues.spacingL(context)),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.name,
                        style: AppTextStyles.titleMedium(context)
                            .copyWith(fontWeight: FontWeight.w700),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (course.description != null &&
                          course.description!.isNotEmpty) ...[
                        SizedBox(height: ResponsiveValues.spacingXXS(context)),
                        Text(
                          course.description!,
                          style: AppTextStyles.caption(context).copyWith(
                              color: AppColors.getTextSecondary(context)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      SizedBox(height: ResponsiveValues.spacingXS(context)),
                      Wrap(
                        spacing: ResponsiveValues.spacingS(context),
                        runSpacing: ResponsiveValues.spacingXS(context),
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: ResponsiveValues.spacingS(context),
                              vertical: ResponsiveValues.spacingXXS(context),
                            ),
                            decoration: BoxDecoration(
                              color: accessColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(
                                  ResponsiveValues.radiusFull(context)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  accessIcon,
                                  size: ResponsiveValues.iconSizeXXS(context),
                                  color: accessColor,
                                ),
                                SizedBox(
                                    width:
                                        ResponsiveValues.spacingXXS(context)),
                                Text(
                                  accessText,
                                  style:
                                      AppTextStyles.caption(context).copyWith(
                                    color: accessColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: ResponsiveValues.spacingS(context),
                              vertical: ResponsiveValues.spacingXXS(context),
                            ),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.telegramBlue.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(
                                  ResponsiveValues.radiusFull(context)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.menu_book_rounded,
                                  size: ResponsiveValues.iconSizeXXS(context),
                                  color: AppColors.telegramBlue,
                                ),
                                SizedBox(
                                    width:
                                        ResponsiveValues.spacingXXS(context)),
                                Text(
                                  '${course.chapterCount} chapters',
                                  style:
                                      AppTextStyles.caption(context).copyWith(
                                    color: AppColors.telegramBlue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Arrow
                Container(
                  width: ResponsiveValues.iconSizeL(context),
                  height: ResponsiveValues.iconSizeL(context),
                  decoration: BoxDecoration(
                    color: AppColors.telegramBlue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: ResponsiveValues.iconSizeXS(context),
                      color: AppColors.telegramBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
          duration: 300.ms,
          delay: (index * 50).ms,
        )
        .slideX(
          begin: 0.1,
          end: 0,
          duration: 300.ms,
          delay: (index * 50).ms,
        );
  }
}

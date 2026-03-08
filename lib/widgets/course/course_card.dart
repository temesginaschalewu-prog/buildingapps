import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/course_model.dart';
import '../../providers/subscription_provider.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/responsive_values.dart';

class CourseCard extends StatelessWidget {
  final Course course;
  final int categoryId;
  final VoidCallback onTap;
  final EdgeInsetsGeometry? margin;
  final int index;

  const CourseCard({
    super.key,
    required this.course,
    required this.categoryId,
    required this.onTap,
    this.margin,
    this.index = 0,
  });

  Color _getStatusColor(bool hasFullAccess) {
    return hasFullAccess ? AppColors.telegramGreen : AppColors.telegramBlue;
  }

  Color _getStatusBackgroundColor(bool hasFullAccess) {
    return hasFullAccess ? AppColors.greenFaded : AppColors.blueFaded;
  }

  IconData _getStatusIcon(bool hasFullAccess) {
    return hasFullAccess
        ? Icons.check_circle_rounded
        : Icons.remove_red_eye_rounded;
  }

  String _getStatusText(bool hasFullAccess) {
    return hasFullAccess ? 'FULL ACCESS' : 'LIMITED';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SubscriptionProvider>(
      builder: (context, subscriptionProvider, child) {
        final hasActiveSubscription =
            subscriptionProvider.hasActiveSubscriptionForCategory(categoryId);
        final hasFullAccess = course.hasFullAccess(hasActiveSubscription);

        final statusColor = _getStatusColor(hasFullAccess);
        final statusBgColor = _getStatusBackgroundColor(hasFullAccess);
        final statusIcon = _getStatusIcon(hasFullAccess);
        final statusText = _getStatusText(hasFullAccess);

        final iconSize = ResponsiveValues.iconSizeXXL(context);
        final titleSize = ResponsiveValues.fontTitleMedium(context);
        final badgeSize = ResponsiveValues.fontBodySmall(context);
        final padding = ResponsiveValues.cardPadding(context);
        final iconSpacing = ResponsiveValues.spacingS(context);

        return Container(
          margin: margin ??
              EdgeInsets.only(bottom: ResponsiveValues.spacingL(context)),
          child: ClipRRect(
            borderRadius:
                BorderRadius.circular(ResponsiveValues.radiusXLarge(context)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.getCard(context).withValues(alpha: 0.4),
                      AppColors.getCard(context).withValues(alpha: 0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(
                      ResponsiveValues.radiusXLarge(context)),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusXLarge(context)),
                    splashColor: statusColor.withValues(alpha: 0.1),
                    highlightColor: Colors.transparent,
                    child: Padding(
                      padding: padding,
                      child: Row(
                        children: [
                          Container(
                            width: iconSize,
                            height: iconSize,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  statusColor.withValues(alpha: 0.2),
                                  statusColor.withValues(alpha: 0.05)
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(
                                  ResponsiveValues.radiusLarge(context)),
                              border: Border.all(
                                  color: statusColor.withValues(alpha: 0.3),
                                  width: 1.5),
                            ),
                            child: Icon(statusIcon,
                                size: iconSize * 0.5, color: statusColor),
                          ),
                          SizedBox(width: iconSpacing),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  course.name,
                                  style: AppTextStyles.titleMedium(context)
                                      .copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: titleSize,
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(
                                    height: ResponsiveValues.spacingS(context)),
                                Wrap(
                                  spacing: iconSpacing,
                                  runSpacing: iconSpacing,
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: iconSpacing,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.grayFaded,
                                        borderRadius: BorderRadius.circular(
                                            ResponsiveValues.radiusFull(
                                                context)),
                                        border: Border.all(
                                            color: AppColors.telegramGray
                                                .withValues(alpha: 0.2)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.menu_book_rounded,
                                            size: badgeSize * 1.2,
                                            color: AppColors.getTextSecondary(
                                                context),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${course.chapterCount} ${course.chapterCount == 1 ? 'chapter' : 'chapters'}',
                                            style: TextStyle(
                                              fontSize: badgeSize,
                                              color: AppColors.getTextSecondary(
                                                  context),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: iconSpacing,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusBgColor,
                                        borderRadius: BorderRadius.circular(
                                            ResponsiveValues.radiusFull(
                                                context)),
                                        border: Border.all(
                                            color: statusColor.withValues(
                                                alpha: 0.3)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            statusIcon,
                                            size: badgeSize * 1.2,
                                            color: statusColor,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            statusText,
                                            style: TextStyle(
                                              fontSize: badgeSize,
                                              color: statusColor,
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
                          Padding(
                            padding: EdgeInsets.only(left: iconSpacing),
                            child: Container(
                              padding: EdgeInsets.all(iconSpacing),
                              decoration: BoxDecoration(
                                color: hasFullAccess
                                    ? statusColor.withValues(alpha: 0.1)
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.chevron_right_rounded,
                                size: badgeSize * 1.5,
                                color: hasFullAccess
                                    ? statusColor
                                    : AppColors.getTextSecondary(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        )
            .animate()
            .fadeIn(
              duration: 400.ms,
              delay: (index * 50).ms,
            )
            .slideX(
              begin: 0.1,
              end: 0,
              duration: 400.ms,
              delay: (index * 50).ms,
            );
      },
    );
  }
}

import 'dart:ui';
import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import '../../models/course_model.dart';
import '../../providers/subscription_provider.dart';
import '../../themes/app_themes.dart';
import '../../utils/responsive.dart';
import '../../utils/responsive_values.dart';
import '../../utils/app_enums.dart';
import '../common/responsive_widgets.dart';

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

  Color _getAccessColor(bool hasActiveSubscription, BuildContext context) {
    final hasFullAccess = course.hasFullAccess(hasActiveSubscription);
    if (hasFullAccess) return AppColors.telegramGreen;
    if (course.hasPendingPayment) return AppColors.statusPending;
    return AppColors.telegramBlue;
  }

  Color _getAccessBackgroundColor(
      bool hasActiveSubscription, BuildContext context) {
    final hasFullAccess = course.hasFullAccess(hasActiveSubscription);
    if (hasFullAccess) return AppColors.greenFaded;
    if (course.hasPendingPayment) return AppColors.orangeFaded;
    return AppColors.blueFaded;
  }

  String _getAccessText(bool hasActiveSubscription) {
    final hasFullAccess = course.hasFullAccess(hasActiveSubscription);
    if (hasFullAccess) return 'FULL ACCESS';
    if (course.hasPendingPayment) return 'PENDING';
    return 'LIMITED';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SubscriptionProvider>(
      builder: (context, subscriptionProvider, child) {
        final hasActiveSubscription =
            subscriptionProvider.hasActiveSubscriptionForCategory(categoryId);
        final accessColor = _getAccessColor(hasActiveSubscription, context);
        final accessBgColor =
            _getAccessBackgroundColor(hasActiveSubscription, context);

        final iconSize = ResponsiveValues.iconSizeXL(context);
        final titleSize = ResponsiveValues.fontTitleMedium(context);
        final descSize = ResponsiveValues.fontBodyMedium(context);
        final badgeSize = ResponsiveValues.fontBodySmall(context);
        final padding = EdgeInsets.all(ResponsiveValues.spacingM(context));
        final iconSpacing = ResponsiveValues.spacingS(context);
        const innerSpacing = 4.0;

        return Container(
          margin: margin ??
              EdgeInsets.only(
                bottom: ResponsiveValues.spacingL(context),
              ),
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
                    color: accessColor.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusXLarge(context)),
                    splashColor: accessColor.withValues(alpha: 0.1),
                    highlightColor: Colors.transparent,
                    child: Padding(
                      padding: padding,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: iconSpacing),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  course.name,
                                  style: TextStyle(
                                    fontSize: titleSize,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.getTextPrimary(context),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (course.description != null &&
                                    course.description!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    course.description!,
                                    style: TextStyle(
                                      fontSize: descSize,
                                      color:
                                          AppColors.getTextSecondary(context),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const SizedBox(height: 8),
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
                                          ResponsiveValues.radiusFull(context),
                                        ),
                                        border: Border.all(
                                          color: AppColors.telegramGray
                                              .withValues(alpha: 0.2),
                                        ),
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
                                        color: accessBgColor,
                                        borderRadius: BorderRadius.circular(
                                          ResponsiveValues.radiusFull(context),
                                        ),
                                        border: Border.all(
                                          color: accessColor.withValues(
                                              alpha: 0.3),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const SizedBox(width: 4),
                                          Text(
                                            _getAccessText(
                                                hasActiveSubscription),
                                            style: TextStyle(
                                              fontSize: badgeSize,
                                              color: accessColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (course.message != null &&
                                    course.message!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      course.message!,
                                      style: TextStyle(
                                        fontSize: badgeSize,
                                        color: accessColor,
                                        fontStyle: FontStyle.italic,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.only(left: iconSpacing),
                            child: Container(
                              padding: EdgeInsets.all(iconSpacing),
                              decoration: BoxDecoration(
                                color: hasActiveSubscription
                                    ? accessColor.withValues(alpha: 0.1)
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.chevron_right_rounded,
                                size: badgeSize * 1.5,
                                color: hasActiveSubscription
                                    ? accessColor
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
              duration: AppThemes.animationDurationMedium,
              delay: (index * 50).ms,
            )
            .slideX(
              begin: 0.1,
              end: 0,
              duration: AppThemes.animationDurationMedium,
              delay: (index * 50).ms,
            );
      },
    );
  }
}

class CourseCardShimmer extends StatelessWidget {
  final int index;

  const CourseCardShimmer({super.key, this.index = 0});

  @override
  Widget build(BuildContext context) {
    final iconSize = ResponsiveValues.iconSizeXL(context);
    final padding = EdgeInsets.all(ResponsiveValues.spacingM(context));
    final iconSpacing = ResponsiveValues.spacingS(context);

    return Container(
      margin: EdgeInsets.only(
        bottom: ResponsiveValues.spacingL(context),
      ),
      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(ResponsiveValues.radiusXLarge(context)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.getCard(context).withValues(alpha: 0.4),
                  AppColors.getCard(context).withValues(alpha: 0.2),
                ],
              ),
              borderRadius:
                  BorderRadius.circular(ResponsiveValues.radiusXLarge(context)),
              border: Border.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Shimmer.fromColors(
                  baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
                  highlightColor: Colors.grey[100]!.withValues(alpha: 0.6),
                  child: Container(
                    width: iconSize,
                    height: iconSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusLarge(context),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: iconSpacing),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Shimmer.fromColors(
                        baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
                        highlightColor:
                            Colors.grey[100]!.withValues(alpha: 0.6),
                        child: Container(
                          width: double.infinity,
                          height: ResponsiveValues.spacingL(context),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(
                              ResponsiveValues.radiusSmall(context),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Shimmer.fromColors(
                        baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
                        highlightColor:
                            Colors.grey[100]!.withValues(alpha: 0.6),
                        child: Container(
                          width: ResponsiveValues.spacingXXXL(context) * 3,
                          height: ResponsiveValues.spacingM(context),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(
                              ResponsiveValues.radiusSmall(context),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: iconSpacing,
                        runSpacing: iconSpacing,
                        children: [
                          Shimmer.fromColors(
                            baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
                            highlightColor:
                                Colors.grey[100]!.withValues(alpha: 0.6),
                            child: Container(
                              width: ResponsiveValues.spacingXXL(context) * 2,
                              height: ResponsiveValues.spacingL(context),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(
                                  ResponsiveValues.radiusFull(context),
                                ),
                              ),
                            ),
                          ),
                          Shimmer.fromColors(
                            baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
                            highlightColor:
                                Colors.grey[100]!.withValues(alpha: 0.6),
                            child: Container(
                              width: ResponsiveValues.spacingXXL(context) * 1.5,
                              height: ResponsiveValues.spacingL(context),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(
                                  ResponsiveValues.radiusFull(context),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(left: iconSpacing),
                  child: Shimmer.fromColors(
                    baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
                    highlightColor: Colors.grey[100]!.withValues(alpha: 0.6),
                    child: Container(
                      width: ResponsiveValues.iconSizeM(context),
                      height: ResponsiveValues.iconSizeM(context),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(
          duration: AppThemes.animationDurationMedium,
          delay: (index * 50).ms,
        );
  }
}

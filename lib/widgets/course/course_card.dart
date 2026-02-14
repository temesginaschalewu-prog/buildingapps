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

class CourseCard extends StatelessWidget {
  final Course course;
  final int categoryId;
  final VoidCallback onTap;
  final EdgeInsetsGeometry? margin;
  final int index; // For staggered animations

  const CourseCard({
    super.key,
    required this.course,
    required this.categoryId,
    required this.onTap,
    this.margin,
    this.index = 0,
  });

  String _getAccessText(bool hasActiveSubscription) {
    final hasFullAccess = course.hasFullAccess(hasActiveSubscription);

    if (hasFullAccess) {
      return 'FULL ACCESS';
    } else if (course.hasPendingPayment) {
      return 'PENDING';
    } else {
      return 'LIMITED';
    }
  }

  Color _getAccessColor(bool hasActiveSubscription, BuildContext context) {
    final hasFullAccess = course.hasFullAccess(hasActiveSubscription);

    if (hasFullAccess) {
      return AppColors.telegramGreen;
    } else if (course.hasPendingPayment) {
      return AppColors.statusPending;
    } else {
      return AppColors.telegramBlue;
    }
  }

  Color _getAccessBackgroundColor(
      bool hasActiveSubscription, BuildContext context) {
    final hasFullAccess = course.hasFullAccess(hasActiveSubscription);

    if (hasFullAccess) {
      return AppColors.telegramGreen.withOpacity(0.1);
    } else if (course.hasPendingPayment) {
      return AppColors.statusPending.withOpacity(0.1);
    } else {
      return AppColors.telegramBlue.withOpacity(0.1);
    }
  }

  IconData _getAccessIcon(bool hasActiveSubscription) {
    final hasFullAccess = course.hasFullAccess(hasActiveSubscription);

    if (hasFullAccess) {
      return Icons.check_circle_rounded;
    } else if (course.hasPendingPayment) {
      return Icons.schedule_rounded;
    } else {
      return Icons.lock_rounded;
    }
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

        return Container(
          margin: margin ?? EdgeInsets.only(bottom: AppThemes.spacingL),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
              splashColor: AppColors.telegramBlue.withOpacity(0.1),
              highlightColor: Colors.transparent,
              child: Container(
                padding: EdgeInsets.all(ScreenSize.responsiveValue(
                  context: context,
                  mobile: AppThemes.spacingL,
                  tablet: AppThemes.spacingXL,
                  desktop: AppThemes.spacingXXL,
                )),
                decoration: BoxDecoration(
                  color: AppColors.getCard(context),
                  borderRadius:
                      BorderRadius.circular(AppThemes.borderRadiusLarge),
                  border: Border.all(
                    color: Theme.of(context).dividerTheme.color ??
                        AppColors.lightDivider,
                    width: 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    // Left side - Status indicator
                    Container(
                      width: ScreenSize.responsiveValue(
                        context: context,
                        mobile: 48,
                        tablet: 56,
                        desktop: 64,
                      ),
                      height: ScreenSize.responsiveValue(
                        context: context,
                        mobile: 48,
                        tablet: 56,
                        desktop: 64,
                      ),
                      decoration: BoxDecoration(
                        color: accessBgColor,
                        borderRadius:
                            BorderRadius.circular(AppThemes.borderRadiusMedium),
                        border: Border.all(
                          color: accessColor,
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        _getAccessIcon(hasActiveSubscription),
                        color: accessColor,
                        size: ScreenSize.responsiveValue(
                          context: context,
                          mobile: 24,
                          tablet: 28,
                          desktop: 32,
                        ),
                      ),
                    ),

                    SizedBox(width: AppThemes.spacingL),

                    // Middle - Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title
                          Text(
                            course.name,
                            style: AppTextStyles.titleMedium.copyWith(
                              color: AppColors.getTextPrimary(context),
                              fontSize: ScreenSize.responsiveFontSize(
                                context: context,
                                mobile: 16,
                                tablet: 18,
                                desktop: 20,
                              ),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                          SizedBox(height: AppThemes.spacingS),

                          // Description if available
                          if (course.description != null &&
                              course.description!.isNotEmpty)
                            Text(
                              course.description!,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.getTextSecondary(context),
                                fontSize: ScreenSize.responsiveFontSize(
                                  context: context,
                                  mobile: 13,
                                  tablet: 14,
                                  desktop: 15,
                                ),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),

                          SizedBox(height: AppThemes.spacingM),

                          // Bottom row - Chapter count and status badge
                          Row(
                            children: [
                              // Chapter count
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: AppThemes.spacingS,
                                  vertical: AppThemes.spacingXS,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceVariant,
                                  borderRadius: BorderRadius.circular(
                                      AppThemes.borderRadiusFull),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.menu_book_rounded,
                                      size: 12,
                                      color:
                                          AppColors.getTextSecondary(context),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      '${course.chapterCount} ${course.chapterCount == 1 ? 'chapter' : 'chapters'}',
                                      style: AppTextStyles.caption.copyWith(
                                        color:
                                            AppColors.getTextSecondary(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(width: AppThemes.spacingM),

                              // Status badge
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: AppThemes.spacingS,
                                  vertical: AppThemes.spacingXS,
                                ),
                                decoration: BoxDecoration(
                                  color: accessBgColor,
                                  borderRadius: BorderRadius.circular(
                                      AppThemes.borderRadiusFull),
                                  border: Border.all(
                                    color: accessColor,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _getAccessIcon(hasActiveSubscription),
                                      size: 12,
                                      color: accessColor,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      _getAccessText(hasActiveSubscription),
                                      style: AppTextStyles.caption.copyWith(
                                        color: accessColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          // Access message if any
                          if (course.message != null &&
                              course.message!.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(top: AppThemes.spacingM),
                              child: Text(
                                course.message!,
                                style: AppTextStyles.caption.copyWith(
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

                    // Right arrow
                    Icon(
                      Icons.chevron_right_rounded,
                      size: ScreenSize.responsiveValue(
                        context: context,
                        mobile: 20,
                        tablet: 24,
                        desktop: 28,
                      ),
                      color: AppColors.getTextSecondary(context),
                    ),
                  ],
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

// Skeleton loader for CourseCard
class CourseCardShimmer extends StatelessWidget {
  final int index;

  const CourseCardShimmer({super.key, this.index = 0});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.only(bottom: AppThemes.spacingL),
      padding: EdgeInsets.all(ScreenSize.responsiveValue(
        context: context,
        mobile: AppThemes.spacingL,
        tablet: AppThemes.spacingXL,
        desktop: AppThemes.spacingXXL,
      )),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
        border: Border.all(
          color: isDark
              ? AppColors.darkDivider.withOpacity(0.3)
              : AppColors.lightDivider.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Status indicator shimmer
          Shimmer.fromColors(
            baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
            highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
            child: Container(
              width: ScreenSize.responsiveValue(
                context: context,
                mobile: 48,
                tablet: 56,
                desktop: 64,
              ),
              height: ScreenSize.responsiveValue(
                context: context,
                mobile: 48,
                tablet: 56,
                desktop: 64,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(AppThemes.borderRadiusMedium),
              ),
            ),
          ),

          SizedBox(width: AppThemes.spacingL),

          // Content shimmer
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Shimmer.fromColors(
                  baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                  highlightColor:
                      isDark ? Colors.grey[700]! : Colors.grey[100]!,
                  child: Container(
                    width: double.infinity,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(AppThemes.borderRadiusSmall),
                    ),
                  ),
                ),
                SizedBox(height: AppThemes.spacingS),
                Shimmer.fromColors(
                  baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                  highlightColor:
                      isDark ? Colors.grey[700]! : Colors.grey[100]!,
                  child: Container(
                    width: 200,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(AppThemes.borderRadiusSmall),
                    ),
                  ),
                ),
                SizedBox(height: AppThemes.spacingM),
                Row(
                  children: [
                    Shimmer.fromColors(
                      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                      highlightColor:
                          isDark ? Colors.grey[700]! : Colors.grey[100]!,
                      child: Container(
                        width: 80,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(AppThemes.borderRadiusFull),
                        ),
                      ),
                    ),
                    SizedBox(width: AppThemes.spacingM),
                    Shimmer.fromColors(
                      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                      highlightColor:
                          isDark ? Colors.grey[700]! : Colors.grey[100]!,
                      child: Container(
                        width: 60,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(AppThemes.borderRadiusFull),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Right arrow shimmer
          Shimmer.fromColors(
            baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
            highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(
          duration: AppThemes.animationDurationMedium,
          delay: (index * 50).ms,
        );
  }
}

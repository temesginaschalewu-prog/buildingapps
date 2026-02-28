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
    return AppColors.telegramBlue; // Changed from red to blue
  }

  Color _getAccessBackgroundColor(
      bool hasActiveSubscription, BuildContext context) {
    final hasFullAccess = course.hasFullAccess(hasActiveSubscription);
    if (hasFullAccess) return AppColors.greenFaded;
    if (course.hasPendingPayment) return AppColors.orangeFaded;
    return AppColors.blueFaded; // Changed from red to blue
  }

  IconData _getAccessIcon(bool hasActiveSubscription) {
    final hasFullAccess = course.hasFullAccess(hasActiveSubscription);
    if (hasFullAccess) return Icons.check_circle_rounded;
    if (course.hasPendingPayment) return Icons.schedule_rounded;
    return Icons.lock_rounded;
  }

  String _getAccessText(bool hasActiveSubscription) {
    final hasFullAccess = course.hasFullAccess(hasActiveSubscription);
    if (hasFullAccess) return 'FULL ACCESS';
    if (course.hasPendingPayment) return 'PENDING';
    return 'LOCKED';
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

        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < 600;
        final isTablet = screenWidth >= 600 && screenWidth < 1024;

        final iconSize = isMobile ? 48.0 : (isTablet ? 56.0 : 64.0);
        final titleSize = isMobile ? 16.0 : (isTablet ? 17.0 : 18.0);
        final descSize = isMobile ? 13.0 : (isTablet ? 14.0 : 15.0);
        final padding = isMobile
            ? AppThemes.spacingL
            : (isTablet ? AppThemes.spacingXL : AppThemes.spacingXXL);

        return Container(
          margin: margin ?? EdgeInsets.only(bottom: AppThemes.spacingL),
          child: ClipRRect(
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
                    color: accessColor.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(24),
                    splashColor: accessColor.withOpacity(0.1),
                    highlightColor: Colors.transparent,
                    child: Padding(
                      padding: EdgeInsets.all(padding),
                      child: Row(
                        children: [
                          // Icon with gradient background
                          Container(
                            width: iconSize,
                            height: iconSize,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  accessColor.withOpacity(0.2),
                                  accessColor.withOpacity(0.05),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: accessColor.withOpacity(0.3),
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              _getAccessIcon(hasActiveSubscription),
                              color: accessColor,
                              size: iconSize * 0.5,
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  course.name,
                                  style: AppTextStyles.titleMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: titleSize,
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (course.description != null &&
                                    course.description!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    course.description!,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color:
                                          AppColors.getTextSecondary(context),
                                      fontSize: descSize,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const SizedBox(height: 12),

                                // Stats Row
                                Row(
                                  children: [
                                    // Chapter count
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.grayFaded,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: AppColors.telegramGray
                                              .withOpacity(0.2),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.menu_book_rounded,
                                            size: 12,
                                            color: AppColors.getTextSecondary(
                                                context),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${course.chapterCount} ${course.chapterCount == 1 ? 'chapter' : 'chapters'}',
                                            style:
                                                AppTextStyles.caption.copyWith(
                                              color: AppColors.getTextSecondary(
                                                  context),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Access status badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: accessBgColor,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: accessColor.withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _getAccessIcon(
                                                hasActiveSubscription),
                                            size: 12,
                                            color: accessColor,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _getAccessText(
                                                hasActiveSubscription),
                                            style:
                                                AppTextStyles.caption.copyWith(
                                              color: accessColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                // Message if any
                                if (course.message != null &&
                                    course.message!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
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

                          // Chevron icon
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: hasActiveSubscription
                                  ? accessColor.withOpacity(0.1)
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.chevron_right_rounded,
                              size: isMobile ? 20 : (isTablet ? 24 : 28),
                              color: hasActiveSubscription
                                  ? accessColor
                                  : AppColors.getTextSecondary(context),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    final iconSize = isMobile ? 48.0 : (isTablet ? 56.0 : 64.0);
    final padding = isMobile
        ? AppThemes.spacingL
        : (isTablet ? AppThemes.spacingXL : AppThemes.spacingXXL);

    return Container(
      margin: EdgeInsets.only(bottom: AppThemes.spacingL),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: Container(
            padding: EdgeInsets.all(padding),
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
                color: Theme.of(context).dividerColor.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Shimmer.fromColors(
                  baseColor: Colors.grey[300]!.withOpacity(0.3),
                  highlightColor: Colors.grey[100]!.withOpacity(0.6),
                  period: const Duration(milliseconds: 1500),
                  child: Container(
                    width: iconSize,
                    height: iconSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Shimmer.fromColors(
                        baseColor: Colors.grey[300]!.withOpacity(0.3),
                        highlightColor: Colors.grey[100]!.withOpacity(0.6),
                        period: const Duration(milliseconds: 1500),
                        child: Container(
                          width: double.infinity,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Shimmer.fromColors(
                        baseColor: Colors.grey[300]!.withOpacity(0.3),
                        highlightColor: Colors.grey[100]!.withOpacity(0.6),
                        period: const Duration(milliseconds: 1500),
                        child: Container(
                          width: 200,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Shimmer.fromColors(
                            baseColor: Colors.grey[300]!.withOpacity(0.3),
                            highlightColor: Colors.grey[100]!.withOpacity(0.6),
                            period: const Duration(milliseconds: 1500),
                            child: Container(
                              width: 80,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Shimmer.fromColors(
                            baseColor: Colors.grey[300]!.withOpacity(0.3),
                            highlightColor: Colors.grey[100]!.withOpacity(0.6),
                            period: const Duration(milliseconds: 1500),
                            child: Container(
                              width: 70,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Shimmer.fromColors(
                  baseColor: Colors.grey[300]!.withOpacity(0.3),
                  highlightColor: Colors.grey[100]!.withOpacity(0.6),
                  period: const Duration(milliseconds: 1500),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
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

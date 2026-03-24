import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/category_model.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/responsive_values.dart';
import '../../utils/ui_helpers.dart';

/// PRODUCTION-READY CATEGORY CARD
class CategoryCard extends StatelessWidget {
  final Category category;
  final bool hasSubscription;
  final bool hasPendingPayment;
  final VoidCallback? onTap;
  final int index;

  const CategoryCard({
    super.key,
    required this.category,
    required this.hasSubscription,
    this.hasPendingPayment = false,
    this.onTap,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final isComingSoon = category.isComingSoon;
    final isFree = category.isFree;
    final borderRadius = BorderRadius.circular(
      ResponsiveValues.radiusXLarge(context) + 8,
    );

    final accessColor = UiHelpers.getCategoryAccessColor(
      isComingSoon: isComingSoon,
      isFree: isFree,
      hasActiveSubscription: hasSubscription,
      hasPendingPayment: hasPendingPayment,
    );

    final accessIcon = UiHelpers.getCategoryAccessIcon(
      isComingSoon: isComingSoon,
      isFree: isFree,
      hasActiveSubscription: hasSubscription,
      hasPendingPayment: hasPendingPayment,
    );

    final accessLabel = UiHelpers.getCategoryAccessLabel(
      isComingSoon: isComingSoon,
      isFree: isFree,
      hasActiveSubscription: hasSubscription,
      hasPendingPayment: hasPendingPayment,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: borderRadius,
            child: Stack(
              children: [
                Positioned.fill(
                  child: category.imageUrl != null && category.imageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: category.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: AppColors.getSurface(context),
                          ),
                          errorWidget: (context, url, error) => Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.telegramBlue.withValues(alpha: 0.86),
                                  AppColors.telegramIndigo.withValues(alpha: 0.80),
                                ],
                              ),
                            ),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.telegramBlue.withValues(alpha: 0.86),
                                AppColors.telegramIndigo.withValues(alpha: 0.80),
                              ],
                            ),
                          ),
                          child: Center(
                            child: Text(
                              category.initials,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize:
                                    ResponsiveValues.fontCategoryInitials(context) *
                                        0.72,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.05),
                          Colors.black.withValues(alpha: 0.62),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: ResponsiveValues.spacingM(context),
                  left: ResponsiveValues.spacingM(context),
                  right: ResponsiveValues.spacingM(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: AppTextStyles.titleLarge(context).copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (category.description != null &&
                          category.description!.trim().isNotEmpty) ...[
                        SizedBox(height: ResponsiveValues.spacingXS(context)),
                        Text(
                          category.description!.trim(),
                          style: AppTextStyles.bodySmall(context).copyWith(
                            color: Colors.white.withValues(alpha: 0.92),
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Positioned(
                  top: ResponsiveValues.spacingM(context),
                  right: ResponsiveValues.spacingM(context),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal:
                          ResponsiveValues.categoryCardBadgePadding(context),
                      vertical: ResponsiveValues.spacingXXS(context),
                    ),
                      decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusFull(context),
                      ),
                      border: Border.all(
                        color: accessColor.withValues(alpha: 0.28),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          accessIcon,
                          size: ResponsiveValues.categoryCardBadgeIconSize(
                            context,
                          ),
                          color: Colors.white,
                        ),
                        SizedBox(width: ResponsiveValues.spacingXXS(context)),
                        Text(
                          accessLabel,
                          style: AppTextStyles.statusBadge(context).copyWith(
                            color: Colors.white,
                            fontSize:
                                ResponsiveValues.categoryCardBadgeTextSize(
                              context,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (category.price != null && category.price! > 0 && !isFree)
                  Positioned(
                    top: ResponsiveValues.spacingM(context),
                    left: ResponsiveValues.spacingM(context),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveValues.spacingS(context),
                        vertical: ResponsiveValues.spacingXXS(context),
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(
                          ResponsiveValues.radiusFull(context),
                        ),
                        border: Border.all(
                          color: AppColors.telegramBlue.withValues(alpha: 0.28),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        category.priceDisplay,
                        style: AppTextStyles.labelSmall(context).copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
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
          duration: 220.ms,
          delay: (index * 50).ms,
        )
        .scale(
          begin: const Offset(0.98, 0.98),
          end: const Offset(1, 1),
          duration: 220.ms,
          delay: (index * 50).ms,
        );
  }
}

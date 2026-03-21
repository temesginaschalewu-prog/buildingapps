import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/category_model.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/responsive_values.dart';
import '../../utils/ui_helpers.dart';
import '../common/app_card.dart';

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
    final hasAccess = isFree || hasSubscription;

    // Use UiHelpers to get access status
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

    return AppCard.category(
      onTap: onTap,
      isSelected: hasAccess,
      child: Stack(
        children: [
          // Background image or gradient
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
                            AppColors.telegramBlue.withValues(alpha: 0.8),
                            AppColors.telegramPurple.withValues(alpha: 0.8)
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
                          AppColors.telegramBlue.withValues(alpha: 0.8),
                          AppColors.telegramPurple.withValues(alpha: 0.8)
                        ],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        category.initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
          ),
          // Gradient overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7)
                  ],
                ),
              ),
            ),
          ),
          // Content
          Positioned(
            bottom: ResponsiveValues.spacingM(context),
            left: ResponsiveValues.spacingM(context),
            right: ResponsiveValues.spacingM(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  style: AppTextStyles.titleMedium(context).copyWith(
                      color: Colors.white, fontWeight: FontWeight.w700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: ResponsiveValues.spacingXS(context)),
              ],
            ),
          ),
          // ✅ FIXED: Access badge with TEXT from UiHelpers
          Positioned(
            top: ResponsiveValues.spacingM(context),
            right: ResponsiveValues.spacingM(context),
            child: ClipRRect(
              borderRadius:
                  BorderRadius.circular(ResponsiveValues.radiusFull(context)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal:
                        ResponsiveValues.categoryCardBadgePadding(context),
                    vertical: ResponsiveValues.spacingXXS(context),
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accessColor.withValues(alpha: 0.3),
                        accessColor.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusFull(context)),
                    border: Border.all(
                      color: accessColor.withValues(alpha: 0.4),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        accessIcon,
                        size:
                            ResponsiveValues.categoryCardBadgeIconSize(context),
                        color: Colors.white,
                      ),
                      SizedBox(width: ResponsiveValues.spacingXXS(context)),
                      Text(
                        accessLabel, // ✅ This is the text from UiHelpers
                        style: AppTextStyles.statusBadge(context).copyWith(
                          color: Colors.white,
                          fontSize: ResponsiveValues.categoryCardBadgeTextSize(
                              context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Price badge (if applicable)
          if (category.price != null && category.price! > 0 && !isFree) ...[
            Positioned(
              top: ResponsiveValues.spacingM(context),
              left: ResponsiveValues.spacingM(context),
              child: ClipRRect(
                borderRadius:
                    BorderRadius.circular(ResponsiveValues.radiusFull(context)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveValues.spacingS(context),
                      vertical: ResponsiveValues.spacingXXS(context),
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.telegramBlue.withValues(alpha: 0.3),
                          AppColors.telegramBlue.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(
                          ResponsiveValues.radiusFull(context)),
                      border: Border.all(
                        color: AppColors.telegramBlue.withValues(alpha: 0.4),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      category.priceDisplay,
                      style: AppTextStyles.labelSmall(context).copyWith(
                          color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    )
        .animate()
        .fadeIn(
          duration: 300.ms,
          delay: (index * 50).ms,
        )
        .scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1, 1),
          duration: 300.ms,
          delay: (index * 50).ms,
        );
  }
}

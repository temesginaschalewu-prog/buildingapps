import 'package:familyacademyclient/models/category_model.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_themes.dart';
import '../../utils/helpers.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_animate/flutter_animate.dart';

class CategoryCard extends StatelessWidget {
  final Category category;
  final bool hasSubscription;
  final bool isCheckingSubscription;
  final bool hasCachedData;
  final bool isRefreshInProgress;
  final VoidCallback? onTap;
  final int index;

  const CategoryCard({
    super.key,
    required this.category,
    required this.hasSubscription,
    this.isCheckingSubscription = false,
    this.hasCachedData = false,
    this.isRefreshInProgress = false,
    this.onTap,
    this.index = 0,
  });

  Color _getStatusColor(BuildContext context) {
    if (category.status == 'active') {
      if (category.isFree) {
        return AppColors.statusFree;
      } else if (hasSubscription) {
        return AppColors.telegramGreen;
      } else {
        return AppColors.telegramBlue;
      }
    } else if (category.status == 'coming_soon') {
      return AppColors.telegramYellow;
    } else {
      return AppColors.telegramRed;
    }
  }

  String get _statusText {
    if (isCheckingSubscription) {
      return 'CHECKING...';
    }

    if (isRefreshInProgress) {
      return 'REFRESHING...';
    }

    if (category.status == 'active') {
      if (category.isFree) {
        return 'FREE';
      } else if (hasSubscription) {
        return 'SUBSCRIBED';
      } else {
        return 'ACTIVE';
      }
    } else if (category.status == 'coming_soon') {
      return 'COMING SOON';
    } else {
      return category.status.toUpperCase();
    }
  }

  IconData get _statusIcon {
    if (isCheckingSubscription || isRefreshInProgress) {
      return Icons.refresh;
    }

    if (category.status == 'active') {
      if (category.isFree) {
        return Icons.lock_open_outlined;
      } else if (hasSubscription) {
        return Icons.check_circle_outline;
      } else {
        return Icons.lock_outline;
      }
    } else if (category.status == 'coming_soon') {
      return Icons.schedule_outlined;
    } else {
      return Icons.block_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(context);
    final isClickable = category.status == 'active' &&
        !isCheckingSubscription &&
        !isRefreshInProgress;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.all(
        ScreenSize.responsiveValue(
          context: context,
          mobile: 4,
          tablet: 6,
          desktop: 8,
        ),
      ),
      child: GestureDetector(
        onTap: isClickable ? onTap : null,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.getCard(context),
            borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
            border: Border.all(
              color: Theme.of(context).dividerTheme.color ??
                  AppColors.lightDivider,
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8.0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image Container - Fixed Height
              Container(
                height: ScreenSize.responsiveValue(
                  context: context,
                  mobile: 100,
                  tablet: 120,
                  desktop: 140,
                ),
                color: isDark ? Colors.black26 : Colors.grey[100],
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Background Image
                    CachedNetworkImage(
                      imageUrl: category.imageUrlOrDefault,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: isDark
                            ? AppColors.darkSurface
                            : AppColors.lightSurface,
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.telegramBlue,
                            ),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: isDark
                            ? AppColors.darkSurface
                            : AppColors.lightSurface,
                        child: Center(
                          child: Icon(
                            Icons.category_outlined,
                            size: 32,
                            color: AppColors.getTextSecondary(context),
                          ),
                        ),
                      ),
                    ),

                    // Gradient Overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.5),
                          ],
                        ),
                      ),
                    ),

                    // Status Badge - TOP LEFT
                    Positioned(
                      top: AppThemes.spacingM,
                      left: AppThemes.spacingM,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: 120,
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: AppThemes.spacingS,
                          vertical: AppThemes.spacingXS,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.getStatusBackground(
                            category.status == 'active'
                                ? (hasSubscription ? 'subscribed' : 'active')
                                : category.status,
                            context,
                          ),
                          borderRadius: BorderRadius.circular(
                              AppThemes.borderRadiusSmall),
                          border: Border.all(
                            color: statusColor,
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isCheckingSubscription || isRefreshInProgress)
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  valueColor: AlwaysStoppedAnimation(
                                    statusColor,
                                  ),
                                ),
                              )
                            else
                              Icon(
                                _statusIcon,
                                size: 12,
                                color: statusColor,
                              ),
                            SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                _statusText,
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Price Badge - TOP RIGHT
                    if (category.price != null &&
                        category.price! > 0 &&
                        !isCheckingSubscription)
                      Positioned(
                        top: AppThemes.spacingM,
                        right: AppThemes.spacingM,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppThemes.spacingS,
                            vertical: AppThemes.spacingXS,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(
                                AppThemes.borderRadiusSmall),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            category.priceDisplay,
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.telegramBlue,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Content Section - More Space for Description
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(AppThemes.spacingM),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title - Fixed Height
                          Text(
                            category.name,
                            style: AppTextStyles.titleMedium.copyWith(
                              color: AppColors.getTextPrimary(context),
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                          SizedBox(height: AppThemes.spacingXS),

                          // Description - Takes Available Space
                          if (category.description != null &&
                              category.description!.isNotEmpty)
                            Expanded(
                              child: Container(
                                constraints: BoxConstraints(
                                  maxHeight: constraints.maxHeight - 60,
                                ),
                                child: SingleChildScrollView(
                                  physics: const NeverScrollableScrollPhysics(),
                                  child: Text(
                                    category.description!,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color:
                                          AppColors.getTextSecondary(context),
                                      height: 1.4,
                                    ),
                                    maxLines: 4, // Increased from 2 to 4
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            )
                          else
                            Spacer(),

                          // Footer - Billing Cycle
                          if (category.status == 'active' &&
                              !category.isFree &&
                              !isCheckingSubscription)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: AppThemes.spacingS,
                                vertical: AppThemes.spacingXS,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.telegramBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(
                                    AppThemes.borderRadiusSmall),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    category.billingCycle == 'monthly'
                                        ? Icons.calendar_today_outlined
                                        : Icons.school_outlined,
                                    size: 12,
                                    color: AppColors.telegramBlue,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    category.billingCycle.toUpperCase(),
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: AppColors.telegramBlue,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 300.ms).slideY(
              begin: 0.1,
              end: 0,
              duration: 300.ms,
              delay: (index * 50).ms,
            ),
      ),
    );
  }
}

class CategoryCardShimmer extends StatelessWidget {
  final int index;

  const CategoryCardShimmer({super.key, this.index = 0});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.all(
        ScreenSize.responsiveValue(
          context: context,
          mobile: 4,
          tablet: 6,
          desktop: 8,
        ),
      ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image Shimmer - Fixed Height
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : Colors.grey[100],
            ),
            child: Shimmer.fromColors(
              baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
              highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
              child: Container(
                color: Colors.white,
              ),
            ),
          ),

          // Content Shimmer
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(AppThemes.spacingM),
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
                      width: double.infinity,
                      height: 14,
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
                      width: double.infinity,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(AppThemes.borderRadiusSmall),
                      ),
                    ),
                  ),
                  Spacer(),
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
                            BorderRadius.circular(AppThemes.borderRadiusSmall),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(
          begin: 0.1,
          end: 0,
          duration: 300.ms,
          delay: (index * 50).ms,
        );
  }
}

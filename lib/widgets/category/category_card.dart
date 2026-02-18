import 'package:familyacademyclient/models/category_model.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_themes.dart';
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

  // FIXED: Local placeholder widget
  Widget _buildLocalPlaceholder() {
    return Container(
      color: AppColors.telegramBlue.withOpacity(0.1),
      child: Center(
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.telegramBlue,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              category.initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(context);
    final isClickable = category.status == 'active' &&
        !isCheckingSubscription &&
        !isRefreshInProgress;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    final isMediumScreen = screenWidth >= 400 && screenWidth < 600;

    final titleFontSize = isSmallScreen ? 13.0 : (isMediumScreen ? 14.0 : 15.0);
    final descriptionFontSize =
        isSmallScreen ? 10.0 : (isMediumScreen ? 11.0 : 12.0);
    final badgeFontSize = isSmallScreen ? 8.0 : (isMediumScreen ? 9.0 : 10.0);
    final contentPadding = isSmallScreen ? 6.0 : (isMediumScreen ? 8.0 : 10.0);
    final borderRadius = isSmallScreen ? 8.0 : 12.0;

    return Container(
      margin: const EdgeInsets.all(4),
      child: GestureDetector(
        onTap: isClickable ? onTap : null,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.getCard(context),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Theme.of(context).dividerTheme.color ??
                  (isDark ? AppColors.darkDivider : AppColors.lightDivider),
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
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Background Image - FIXED: Use local placeholder if no image URL
                    if (category.imageUrl != null &&
                        category.imageUrl!.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: category.imageUrl!,
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
                        errorWidget: (context, url, error) =>
                            _buildLocalPlaceholder(),
                      )
                    else
                      _buildLocalPlaceholder(),

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
                      top: 8,
                      left: 8,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 100),
                        padding: EdgeInsets.symmetric(
                          horizontal: contentPadding / 1.5,
                          vertical: contentPadding / 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.getStatusBackground(
                            category.status == 'active'
                                ? (hasSubscription ? 'subscribed' : 'active')
                                : category.status,
                            context,
                          ),
                          borderRadius: BorderRadius.circular(4),
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
                                width: badgeFontSize + 2,
                                height: badgeFontSize + 2,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    statusColor,
                                  ),
                                ),
                              )
                            else
                              Icon(
                                _statusIcon,
                                size: badgeFontSize + 1,
                                color: statusColor,
                              ),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                _statusText,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: badgeFontSize,
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
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: contentPadding / 1.5,
                            vertical: contentPadding / 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(4),
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
                            style: TextStyle(
                              color: AppColors.telegramBlue,
                              fontSize: badgeFontSize,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Content Section
              Padding(
                padding: EdgeInsets.all(contentPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      category.name,
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.w600,
                        color: AppColors.getTextPrimary(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (category.description != null &&
                        category.description!.isNotEmpty)
                      Text(
                        category.description!,
                        style: TextStyle(
                          fontSize: descriptionFontSize,
                          height: 1.3,
                          color: AppColors.getTextSecondary(context),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (category.status == 'active' &&
                        !category.isFree &&
                        !isCheckingSubscription)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: contentPadding / 1.5,
                            vertical: contentPadding / 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.telegramBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                category.billingCycle == 'monthly'
                                    ? Icons.calendar_today_outlined
                                    : Icons.school_outlined,
                                size: descriptionFontSize,
                                color: AppColors.telegramBlue,
                              ),
                              const SizedBox(width: 2),
                              Flexible(
                                child: Text(
                                  category.billingCycle.toUpperCase(),
                                  style: TextStyle(
                                    color: AppColors.telegramBlue,
                                    fontSize: descriptionFontSize - 1,
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
                  ],
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    final isMediumScreen = screenWidth >= 400 && screenWidth < 600;

    final contentPadding = isSmallScreen ? 6.0 : (isMediumScreen ? 8.0 : 10.0);
    final borderRadius = isSmallScreen ? 8.0 : 12.0;

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: isDark
              ? AppColors.darkDivider.withOpacity(0.3)
              : AppColors.lightDivider.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Shimmer.fromColors(
              baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
              highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
              child: Container(
                color: Colors.white,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(contentPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Shimmer.fromColors(
                  baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                  highlightColor:
                      isDark ? Colors.grey[700]! : Colors.grey[100]!,
                  child: Container(
                    width: double.infinity,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Shimmer.fromColors(
                  baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                  highlightColor:
                      isDark ? Colors.grey[700]! : Colors.grey[100]!,
                  child: Container(
                    width: double.infinity,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Shimmer.fromColors(
                  baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                  highlightColor:
                      isDark ? Colors.grey[700]! : Colors.grey[100]!,
                  child: Container(
                    width: 60,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
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

import 'dart:ui';
import 'package:familyacademyclient/models/category_model.dart';
import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../themes/app_themes.dart';
import '../../utils/responsive.dart';
import '../../utils/responsive_values.dart';
import '../../utils/app_enums.dart';
import '../common/responsive_widgets.dart';

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

  Widget _buildGlassContainer(BuildContext context, {required Widget child}) {
    return ClipRRect(
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
            borderRadius:
                BorderRadius.circular(ResponsiveValues.radiusXLarge(context)),
            border: Border.all(
              color: AppColors.telegramBlue.withValues(alpha: 0.2),
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    final imageFontSize = ResponsiveValues.iconSizeXXL(context);

    if (category.imageUrl == null || category.imageUrl!.isEmpty) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.telegramBlue, AppColors.telegramPurple],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Text(
            category.initials,
            style: TextStyle(
              color: Colors.white,
              fontSize: imageFontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: category.imageUrl!,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.telegramBlue, AppColors.telegramPurple],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Text(
            category.initials,
            style: TextStyle(
              color: Colors.white,
              fontSize: imageFontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.telegramBlue, AppColors.telegramPurple],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Text(
            category.initials,
            style: TextStyle(
              color: Colors.white,
              fontSize: imageFontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ScreenSize.isDesktop(context);
    final titleSize = ResponsiveValues.categoryCardTitleSize(context);
    final priceSize = ResponsiveValues.categoryCardPriceSize(context);
    final badgeTextSize = ResponsiveValues.categoryCardBadgeTextSize(context);
    final badgeIconSize = ResponsiveValues.categoryCardBadgeIconSize(context);
    final badgePadding = ResponsiveValues.categoryCardBadgePadding(context);
    final spacing = ResponsiveValues.spacingM(context);

    return GestureDetector(
      onTap: onTap,
      child: _buildGlassContainer(
        context,
        child: ClipRRect(
          borderRadius:
              BorderRadius.circular(ResponsiveValues.radiusXLarge(context)),
          child: Stack(
            children: [
              // Full image covering entire card
              Positioned.fill(
                child: _buildImage(context),
              ),

              // Gradient overlay for better text visibility
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.3),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.5),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),

              // Category Name at top left
              Positioned(
                top: spacing,
                left: spacing,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 6.0 : 8.0,
                    vertical: isDesktop ? 2.0 : 4.0,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusSmall(context)),
                  ),
                  child: Text(
                    category.name,
                    style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              // Status badge at top right
              Positioned(
                top: spacing,
                right: spacing,
                child: _buildStatusBadge(
                    context, badgeIconSize, badgeTextSize, badgePadding),
              ),

              // Price at bottom left
              if (category.price != null &&
                  category.price! > 0 &&
                  !category.isFree)
                Positioned(
                  bottom: spacing,
                  left: spacing,
                  child: _buildPriceBadge(
                      context, priceSize, badgeTextSize - 1.5, badgePadding),
                ),

              // Subtle border overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusXLarge(context)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
          duration: AppThemes.animationDurationMedium,
          delay: Duration(milliseconds: index * 50),
        )
        .scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1, 1),
          duration: AppThemes.animationDurationMedium,
          delay: Duration(milliseconds: index * 50),
        );
  }

  Widget _buildStatusBadge(
      BuildContext context, double iconSize, double textSize, double padding) {
    if (category.isFree) {
      return _buildBadge(
        context,
        icon: Icons.lock_open_rounded,
        label: 'FREE',
        color: AppColors.telegramGreen,
        iconSize: iconSize,
        textSize: textSize,
        padding: padding,
      );
    }

    if (hasSubscription) {
      return _buildBadge(
        context,
        icon: Icons.check_circle_rounded,
        label: 'SUBSCIRBED',
        color: AppColors.telegramGreen,
        iconSize: iconSize,
        textSize: textSize,
        padding: padding,
      );
    }

    if (category.status == 'coming_soon') {
      return _buildBadge(
        context,
        icon: Icons.schedule_rounded,
        label: 'SOON',
        color: AppColors.telegramYellow,
        iconSize: iconSize,
        textSize: textSize,
        padding: padding,
      );
    }

    return _buildBadge(
      context,
      icon: Icons.book,
      label: 'ACTIVE',
      color: AppColors.telegramBlue,
      iconSize: iconSize,
      textSize: textSize,
      padding: padding,
    );
  }

  Widget _buildBadge(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required double iconSize,
    required double textSize,
    required double padding,
  }) {
    final isDesktop = ScreenSize.isDesktop(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: padding,
        vertical: padding / 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius:
            BorderRadius.circular(ResponsiveValues.radiusSmall(context)),
        border: Border.all(
          color: color.withValues(alpha: 0.4),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: iconSize,
            color: Colors.white,
          ),
          SizedBox(width: isDesktop ? 2 : 4),
          Text(
            label,
            style: TextStyle(
              fontSize: textSize,
              color: Colors.white,
              fontWeight: FontWeight.w600,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceBadge(BuildContext context, double priceSize,
      double smallTextSize, double padding) {
    final isDesktop = ScreenSize.isDesktop(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: padding,
        vertical: padding / 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.telegramBlue.withValues(alpha: 0.2),
        borderRadius:
            BorderRadius.circular(ResponsiveValues.radiusSmall(context)),
        border: Border.all(
          color: AppColors.telegramBlue.withValues(alpha: 0.4),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.attach_money_rounded,
            size: 8,
            color: Colors.white,
          ),
          SizedBox(width: isDesktop ? 1 : 2),
          Text(
            '${category.price!.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: priceSize,
              color: Colors.white,
              fontWeight: FontWeight.w600,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
          Text(
            '/${category.billingCycle == 'semester' ? 'sem' : 'mo'}',
            style: TextStyle(
              fontSize: smallTextSize,
              color: Colors.white.withValues(alpha: 0.8),
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CategoryCardShimmer extends StatelessWidget {
  final int index;

  const CategoryCardShimmer({super.key, this.index = 0});

  @override
  Widget build(BuildContext context) {
    final isDesktop = ScreenSize.isDesktop(context);
    final cardHeight = ResponsiveValues.categoryCardHeight(context);
    final spacing = ResponsiveValues.spacingM(context);
    final titleSize = ResponsiveValues.categoryCardTitleSize(context);
    final priceSize = ResponsiveValues.categoryCardPriceSize(context);

    return Container(
      height: cardHeight,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        borderRadius:
            BorderRadius.circular(ResponsiveValues.radiusXLarge(context)),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkDivider.withValues(alpha: 0.3)
              : AppColors.lightDivider.withValues(alpha: 0.3),
        ),
      ),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
        highlightColor: Colors.grey[100]!.withValues(alpha: 0.6),
        child: Stack(
          children: [
            // Full image shimmer
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
              ),
            ),

            // Gradient overlay shimmer
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.3),
                      Colors.transparent,
                      Colors.white.withValues(alpha: 0.5),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),

            // Name shimmer at top left
            Positioned(
              top: spacing,
              left: spacing,
              child: Container(
                width: isDesktop ? 80 : 100,
                height: titleSize * 1.5,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),

            // Status badge shimmer at top right
            Positioned(
              top: spacing,
              right: spacing,
              child: Container(
                width: isDesktop ? 60 : 70,
                height: isDesktop ? 18 : 22,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),

            // Price shimmer at bottom left
            Positioned(
              bottom: spacing,
              left: spacing,
              child: Container(
                width: isDesktop ? 50 : 60,
                height: priceSize * 1.5,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),

            // Subtle border overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(
          duration: AppThemes.animationDurationMedium,
          delay: Duration(milliseconds: index * 50),
        );
  }
}

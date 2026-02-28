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
import '../../utils/helpers.dart';

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
              color: AppColors.telegramBlue.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (category.imageUrl == null || category.imageUrl!.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.telegramBlue, AppColors.telegramPurple],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
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
      );
    }

    return CachedNetworkImage(
      imageUrl: category.imageUrl!,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.telegramBlue, AppColors.telegramPurple],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
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
      errorWidget: (context, url, error) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.telegramBlue, AppColors.telegramPurple],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    // FIXED: Calculate card height based on screen size
    final cardHeight = isMobile ? 280.0 : (isTablet ? 320.0 : 360.0);
    final imageHeight = cardHeight * 0.45; // 45% of card height for image
    final contentPadding = isMobile ? 12.0 : (isTablet ? 16.0 : 20.0);

    return GestureDetector(
      onTap: onTap,
      child: _buildGlassContainer(
        context,
        child: Container(
          height: cardHeight, // FIXED: Fixed height to prevent overflow
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image section with fixed height
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                child: SizedBox(
                  height: imageHeight,
                  width: double.infinity,
                  child: _buildImage(),
                ),
              ),

              // Content section with remaining space
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(contentPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title
                      Text(
                        category.name,
                        style: AppTextStyles.titleMedium.copyWith(
                          color: AppColors.getTextPrimary(context),
                          fontSize: isMobile ? 16 : (isTablet ? 18 : 20),
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 4),

                      // Course count
                      Row(
                        children: [
                          Icon(
                            Icons.menu_book_rounded,
                            size: 14,
                            color: AppColors.getTextSecondary(context),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${category.courseCount} courses',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.getTextSecondary(context),
                            ),
                          ),
                        ],
                      ),

                      const Spacer(),

                      // Price/Status section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Price or Free badge
                          if (category.isFree) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.telegramGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      AppColors.telegramGreen.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.lock_open_rounded,
                                    size: 12,
                                    color: AppColors.telegramGreen,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'FREE',
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: AppColors.telegramGreen,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else if (category.price != null &&
                              category.price! > 0) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.telegramBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      AppColors.telegramBlue.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.attach_money_rounded,
                                    size: 12,
                                    color: AppColors.telegramBlue,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${category.price!.toStringAsFixed(0)} ETB',
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: AppColors.telegramBlue,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '/${category.billingCycle == 'semester' ? 'sem' : 'mo'}',
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color:
                                          AppColors.getTextSecondary(context),
                                      fontSize: 8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Subscription status badge
                          if (!category.isFree) ...[
                            if (hasSubscription)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.telegramGreen.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.telegramGreen
                                        .withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      size: 12,
                                      color: AppColors.telegramGreen,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'ACTIVE',
                                      style: AppTextStyles.labelSmall.copyWith(
                                        color: AppColors.telegramGreen,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (category.status == 'coming_soon')
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.telegramYellow.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.telegramYellow
                                        .withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.schedule_rounded,
                                      size: 12,
                                      color: AppColors.telegramYellow,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'SOON',
                                      style: AppTextStyles.labelSmall.copyWith(
                                        color: AppColors.telegramYellow,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.telegramBlue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color:
                                        AppColors.telegramBlue.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.lock_rounded,
                                      size: 12,
                                      color: AppColors.telegramBlue,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'LOCKED',
                                      style: AppTextStyles.labelSmall.copyWith(
                                        color: AppColors.telegramBlue,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ],
                      ),
                    ],
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
}

class CategoryCardShimmer extends StatelessWidget {
  final int index;

  const CategoryCardShimmer({super.key, this.index = 0});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    // FIXED: Match the same height as the actual card
    final cardHeight = isMobile ? 280.0 : (isTablet ? 320.0 : 360.0);
    final imageHeight = cardHeight * 0.45;
    final contentPadding = isMobile ? 12.0 : (isTablet ? 16.0 : 20.0);

    return Container(
      height: cardHeight,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkDivider.withOpacity(0.3)
              : AppColors.lightDivider.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!.withOpacity(0.3),
        highlightColor: Colors.grey[100]!.withOpacity(0.6),
        period: const Duration(milliseconds: 1500),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image shimmer
            Container(
              height: imageHeight,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
            ),
            // Content shimmer
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(contentPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 20,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 100,
                      height: 16,
                      color: Colors.white,
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 80,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        Container(
                          width: 60,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ],
                    ),
                  ],
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

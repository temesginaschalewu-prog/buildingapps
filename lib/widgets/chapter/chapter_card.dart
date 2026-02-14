import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:familyacademyclient/models/category_model.dart';
import 'package:familyacademyclient/models/chapter_model.dart';
import 'package:familyacademyclient/providers/auth_provider.dart';
import 'package:familyacademyclient/providers/category_provider.dart';
import 'package:familyacademyclient/providers/payment_provider.dart';
import 'package:familyacademyclient/providers/subscription_provider.dart';
import 'package:familyacademyclient/themes/app_themes.dart';
import 'package:familyacademyclient/utils/helpers.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import 'package:shimmer/shimmer.dart';

class ChapterCard extends StatelessWidget {
  final Chapter chapter;
  final int courseId;
  final int categoryId;
  final String categoryName;
  final VoidCallback onTap;
  final EdgeInsetsGeometry? margin;
  final int index; // For staggered animations

  const ChapterCard({
    super.key,
    required this.chapter,
    required this.courseId,
    required this.categoryId,
    required this.categoryName,
    required this.onTap,
    this.margin,
    this.index = 0,
  });

  Color _getStatusColor(BuildContext context, bool hasAccess) {
    if (hasAccess) {
      return AppColors.telegramGreen;
    } else {
      return chapter.isFree ? AppColors.telegramBlue : AppColors.telegramRed;
    }
  }

  Color _getStatusBackgroundColor(BuildContext context, bool hasAccess) {
    if (hasAccess) {
      return AppColors.telegramGreen.withOpacity(0.1);
    } else {
      return chapter.isFree
          ? AppColors.telegramBlue.withOpacity(0.1)
          : AppColors.telegramRed.withOpacity(0.1);
    }
  }

  IconData _getStatusIcon(bool hasAccess) {
    if (hasAccess) {
      return Icons.play_circle_rounded;
    } else {
      return chapter.isFree ? Icons.schedule_rounded : Icons.lock_rounded;
    }
  }

  String _getStatusText(bool hasAccess) {
    if (hasAccess) {
      return 'START';
    } else {
      return chapter.isFree ? 'FREE' : 'LOCKED';
    }
  }

  Future<void> _handleTap(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final subscriptionProvider = context.read<SubscriptionProvider>();
    final categoryProvider = context.read<CategoryProvider>();

    if (!authProvider.isAuthenticated) {
      showSnackBar(
        context,
        'Please login to access content',
        isError: true,
      );
      return;
    }

    final category = categoryProvider.getCategoryById(categoryId);
    if (category == null) {
      showSnackBar(context, 'Category not found', isError: true);
      return;
    }

    bool hasAccess;

    if (chapter.isFree || category.isFree) {
      hasAccess = true;
    } else {
      hasAccess = await subscriptionProvider
          .checkHasActiveSubscriptionForCategory(categoryId);
    }

    if (hasAccess) {
      onTap();
    } else {
      _showAccessDialog(context, category);
    }
  }

  void _showAccessDialog(BuildContext context, Category category) {
    final paymentProvider = context.read<PaymentProvider>();

    final hasPendingPayment = paymentProvider.payments.any(
      (payment) =>
          payment.status == 'pending' &&
          payment.categoryName.toLowerCase() == category.name.toLowerCase(),
    );

    if (hasPendingPayment) {
      _showPendingPaymentDialog(context);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
        ),
        backgroundColor: AppColors.getCard(context),
        child: Padding(
          padding: EdgeInsets.all(AppThemes.spacingXL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(AppThemes.spacingL),
                decoration: BoxDecoration(
                  color: AppColors.telegramBlue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_rounded,
                  color: AppColors.telegramBlue,
                  size: 32,
                ),
              ),
              SizedBox(height: AppThemes.spacingL),
              Text(
                'Unlock Content',
                style: AppTextStyles.titleLarge.copyWith(
                  color: AppColors.getTextPrimary(context),
                ),
              ),
              SizedBox(height: AppThemes.spacingM),
              Text(
                'This chapter requires access to "${category.name}".',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.getTextSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppThemes.spacingXL),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.getTextSecondary(context),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              AppThemes.borderRadiusMedium),
                        ),
                        padding:
                            EdgeInsets.symmetric(vertical: AppThemes.spacingM),
                      ),
                      child: Text('Cancel', style: AppTextStyles.buttonMedium),
                    ),
                  ),
                  SizedBox(width: AppThemes.spacingM),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        context.push(
                          '/payment',
                          extra: {
                            'category': category,
                            'paymentType': 'first_time',
                          },
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.telegramBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              AppThemes.borderRadiusMedium),
                        ),
                        padding:
                            EdgeInsets.symmetric(vertical: AppThemes.spacingM),
                      ),
                      child:
                          Text('Purchase', style: AppTextStyles.buttonMedium),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPendingPaymentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
        ),
        backgroundColor: AppColors.getCard(context),
        child: Padding(
          padding: EdgeInsets.all(AppThemes.spacingXL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(AppThemes.spacingL),
                decoration: BoxDecoration(
                  color: AppColors.statusPending.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.schedule_rounded,
                  color: AppColors.statusPending,
                  size: 32,
                ),
              ),
              SizedBox(height: AppThemes.spacingL),
              Text(
                'Payment Pending',
                style: AppTextStyles.titleLarge.copyWith(
                  color: AppColors.getTextPrimary(context),
                ),
              ),
              SizedBox(height: AppThemes.spacingM),
              Text(
                'You have a pending payment for this category. '
                'Please wait for admin verification (1-3 working days).',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.getTextSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppThemes.spacingXL),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.telegramBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppThemes.borderRadiusMedium),
                    ),
                    padding: EdgeInsets.symmetric(vertical: AppThemes.spacingM),
                  ),
                  child: Text('OK', style: AppTextStyles.buttonMedium),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SubscriptionProvider>(
      builder: (context, subscriptionProvider, child) {
        final categoryProvider = context.watch<CategoryProvider>();
        final category = categoryProvider.getCategoryById(categoryId);
        final isCategoryFree = category?.isFree ?? false;

        final hasCachedAccess = isCategoryFree ||
            subscriptionProvider.hasActiveSubscriptionForCategory(categoryId);
        final hasAccess = chapter.isFree || hasCachedAccess;
        final statusColor = _getStatusColor(context, hasAccess);
        final statusBgColor = _getStatusBackgroundColor(context, hasAccess);

        return Container(
          margin: margin ?? EdgeInsets.only(bottom: AppThemes.spacingL),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _handleTap(context),
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
                        color: statusBgColor,
                        borderRadius:
                            BorderRadius.circular(AppThemes.borderRadiusMedium),
                        border: Border.all(
                          color: statusColor,
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        _getStatusIcon(hasAccess),
                        color: statusColor,
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
                            chapter.name,
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

                          // Status badge
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppThemes.spacingS,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: statusBgColor,
                              borderRadius: BorderRadius.circular(
                                  AppThemes.borderRadiusFull),
                              border: Border.all(
                                color: statusColor,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getStatusIcon(hasAccess),
                                  size: 12,
                                  color: statusColor,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  _getStatusText(hasAccess),
                                  style: AppTextStyles.caption.copyWith(
                                    color: statusColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Access message if locked
                          if (!hasAccess && !chapter.isFree)
                            Padding(
                              padding: EdgeInsets.only(top: AppThemes.spacingS),
                              child: Text(
                                'Purchase "$categoryName" to unlock',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.telegramRed,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Right arrow
                    Icon(
                      hasAccess
                          ? Icons.chevron_right_rounded
                          : Icons.lock_rounded,
                      size: ScreenSize.responsiveValue(
                        context: context,
                        mobile: 20,
                        tablet: 24,
                        desktop: 28,
                      ),
                      color: hasAccess
                          ? AppColors.telegramBlue
                          : AppColors.getTextSecondary(context),
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

// Skeleton loader for ChapterCard
class ChapterCardShimmer extends StatelessWidget {
  final int index;

  const ChapterCardShimmer({super.key, this.index = 0});

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
                    width: 80,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(AppThemes.borderRadiusFull),
                    ),
                  ),
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

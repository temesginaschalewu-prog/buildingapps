import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/chapter_model.dart';
import '../../models/category_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/category_provider.dart';
import '../../services/connectivity_service.dart';
import '../../services/snackbar_service.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/responsive_values.dart';
import '../../utils/helpers.dart';
import '../common/app_card.dart';
import '../common/app_dialog.dart';

/// PRODUCTION-READY CHAPTER CARD with Payment Dialog
class ChapterCard extends StatelessWidget {
  final Chapter chapter;
  final int courseId;
  final int categoryId;
  final String categoryName;
  final VoidCallback onTap;
  final int index;

  const ChapterCard({
    super.key,
    required this.chapter,
    required this.courseId,
    required this.categoryId,
    required this.categoryName,
    required this.onTap,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final bool canAccess = chapter.canAccessContent;
    final bool isFree = chapter.isFree;
    final bool isComingSoon = chapter.status.toLowerCase() == 'coming_soon';

    return AppCard.chapter(
      hasAccess: canAccess,
      onTap: () => _handleTap(context),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleTap(context),
          borderRadius:
              BorderRadius.circular(ResponsiveValues.radiusXLarge(context)),
          splashColor: AppColors.telegramBlue.withValues(alpha: 0.1),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: ResponsiveValues.cardPadding(context),
            child: Row(
              children: [
                // Icon with status
                Container(
                  width: ResponsiveValues.iconSizeXXL(context),
                  height: ResponsiveValues.iconSizeXXL(context),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isComingSoon
                          ? [
                              AppColors.telegramYellow.withValues(alpha: 0.2),
                              AppColors.telegramYellow.withValues(alpha: 0.1)
                            ]
                          : (canAccess
                              ? [
                                  AppColors.telegramGreen
                                      .withValues(alpha: 0.2),
                                  AppColors.telegramGreen.withValues(alpha: 0.1)
                                ]
                              : [
                                  AppColors.telegramGray.withValues(alpha: 0.2),
                                  AppColors.telegramGray.withValues(alpha: 0.1)
                                ]),
                    ),
                    borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusLarge(context)),
                  ),
                  child: Icon(
                    isComingSoon
                        ? Icons.schedule_rounded
                        : (canAccess
                            ? Icons.lock_open_rounded
                            : Icons.lock_rounded),
                    size: ResponsiveValues.iconSizeL(context),
                    color: isComingSoon
                        ? AppColors.telegramYellow
                        : (canAccess
                            ? AppColors.telegramGreen
                            : AppColors.telegramGray),
                  ),
                ),
                SizedBox(width: ResponsiveValues.spacingL(context)),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chapter.name,
                        style: AppTextStyles.titleMedium(context)
                            .copyWith(fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: ResponsiveValues.spacingXS(context)),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: ResponsiveValues.iconSizeXXS(context),
                            color: AppColors.getTextSecondary(context),
                          ),
                          SizedBox(width: ResponsiveValues.spacingXXS(context)),
                          Text(
                            chapter.releaseDate != null
                                ? 'Available: ${formatDate(chapter.releaseDate!)}'
                                : 'Available now',
                            style: AppTextStyles.caption(context).copyWith(
                                color: AppColors.getTextSecondary(context)),
                          ),
                        ],
                      ),
                      if (isFree)
                        Padding(
                          padding: EdgeInsets.only(
                              top: ResponsiveValues.spacingXS(context)),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: ResponsiveValues.spacingS(context),
                              vertical: ResponsiveValues.spacingXXS(context),
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [
                                AppColors.telegramGreen,
                                Color(0xFF34D399)
                              ]),
                              borderRadius: BorderRadius.circular(
                                  ResponsiveValues.radiusFull(context)),
                            ),
                            child: Text(
                              'FREE PREVIEW',
                              style:
                                  AppTextStyles.statusBadge(context).copyWith(
                                color: Colors.white,
                                fontSize:
                                    ResponsiveValues.fontStatusBadge(context) *
                                        0.9,
                              ),
                            ),
                          ),
                        )
                      else if (isComingSoon)
                        Padding(
                          padding: EdgeInsets.only(
                              top: ResponsiveValues.spacingXS(context)),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: ResponsiveValues.spacingS(context),
                              vertical: ResponsiveValues.spacingXXS(context),
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.telegramYellow
                                      .withValues(alpha: 0.2),
                                  AppColors.telegramYellow
                                      .withValues(alpha: 0.1)
                                ],
                              ),
                              borderRadius: BorderRadius.circular(
                                  ResponsiveValues.radiusFull(context)),
                            ),
                            child: Text(
                              'COMING SOON',
                              style:
                                  AppTextStyles.statusBadge(context).copyWith(
                                color: AppColors.telegramYellow,
                                fontSize:
                                    ResponsiveValues.fontStatusBadge(context) *
                                        0.9,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Arrow
                Container(
                  width: ResponsiveValues.iconSizeL(context),
                  height: ResponsiveValues.iconSizeL(context),
                  decoration: BoxDecoration(
                    color: canAccess
                        ? AppColors.telegramBlue.withValues(alpha: 0.1)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      canAccess
                          ? Icons.arrow_forward_ios_rounded
                          : Icons.lock_rounded,
                      size: ResponsiveValues.iconSizeXS(context),
                      color: canAccess
                          ? AppColors.telegramBlue
                          : AppColors.getTextSecondary(context),
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
          duration: 300.ms,
          delay: (index * 50).ms,
        )
        .slideX(
          begin: 0.1,
          end: 0,
          duration: 300.ms,
          delay: (index * 50).ms,
        );
  }

  Future<void> _handleTap(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final subscriptionProvider = context.read<SubscriptionProvider>();
    final categoryProvider = context.read<CategoryProvider>();
    final connectivity = context.read<ConnectivityService>();

    if (!authProvider.isAuthenticated) {
      SnackbarService().showError(context, 'Please login to access content');
      return;
    }

    final category = categoryProvider.getCategoryById(categoryId);
    if (category == null) {
      SnackbarService().showError(context, 'Category not found');
      return;
    }

    final bool isComingSoon = chapter.status.toLowerCase() == 'coming_soon';

    if (isComingSoon) {
      SnackbarService().showInfo(context, 'This chapter is coming soon!');
      return;
    }

    // ✅ FIX: Check if we can access content (either free or have access)
    final bool hasAccess = chapter.canAccessContent ||
        subscriptionProvider.hasActiveSubscriptionForCategory(categoryId);

    if (hasAccess) {
      // Can access regardless of online/offline
      onTap();
      return;
    }

    // If no access, check if online to show payment dialog
    if (!connectivity.isOnline) {
      SnackbarService().showOffline(context, action: 'make payment');
      return;
    }

    // Show payment dialog
    _showPaymentDialog(context, category);
  }

  void _showPaymentDialog(BuildContext context, Category category) {
    // ✅ FIXED: Check if this is a renewal (user has expired subscription)
    final subscriptionProvider = context.read<SubscriptionProvider>();
    final hasExpiredSubscription = subscriptionProvider.expiredSubscriptions
        .any((sub) => sub.categoryId == category.id);

    final paymentType = hasExpiredSubscription ? 'repayment' : 'first_time';

    AppDialog.confirm(
      context: context,
      title: 'Unlock Content',
      message: hasExpiredSubscription
          ? 'Your subscription for "${category.name}" has expired. Renew to access this chapter.'
          : 'This chapter requires access to "${category.name}". Purchase to unlock all content.',
      confirmText: hasExpiredSubscription ? 'Renew Now' : 'Purchase Access',
    ).then((confirmed) {
      if (confirmed == true && context.mounted) {
        context.push('/payment', extra: {
          'category': category,
          'paymentType': paymentType,
        });
      }
    });
  }
}

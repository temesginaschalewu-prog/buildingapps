import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/chapter_model.dart';
import '../../models/category_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/payment_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../themes/app_themes.dart';
import '../../utils/responsive_values.dart';
import '../../utils/helpers.dart';
import '../common/app_dialog.dart';

class ChapterCard extends StatelessWidget {
  final Chapter chapter;
  final int courseId;
  final int categoryId;
  final String categoryName;
  final VoidCallback onTap;
  final EdgeInsetsGeometry? margin;
  final int index;

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
    if (hasAccess) return AppColors.telegramGreen;
    return chapter.isFree ? AppColors.telegramBlue : AppColors.telegramBlue;
  }

  Color _getStatusBackgroundColor(BuildContext context, bool hasAccess) {
    if (hasAccess) return AppColors.greenFaded;
    return chapter.isFree ? AppColors.blueFaded : AppColors.blueFaded;
  }

  IconData _getStatusIcon(bool hasAccess) {
    if (hasAccess) return Icons.play_circle_rounded;
    return chapter.isFree ? Icons.schedule_rounded : Icons.lock_rounded;
  }

  String _getStatusText(bool hasAccess) {
    if (hasAccess) return 'START';
    return chapter.isFree ? 'FREE' : 'LOCKED';
  }

  Future<void> _handleTap(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final subscriptionProvider = context.read<SubscriptionProvider>();
    final categoryProvider = context.read<CategoryProvider>();

    if (!authProvider.isAuthenticated) {
      showTopSnackBar(context, 'Please login to access content', isError: true);
      return;
    }

    final category = categoryProvider.getCategoryById(categoryId);
    if (category == null) {
      showTopSnackBar(context, 'Category not found', isError: true);
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

    _showPurchaseDialog(context, category);
  }

  void _showPurchaseDialog(BuildContext context, Category category) {
    AppDialog.confirm(
      context: context,
      title: 'Purchase Required',
      message:
          'You need to purchase "${category.name}" to access this chapter.',
      confirmText: 'Purchase Now',
    ).then((confirmed) {
      if (confirmed == true) {
        context.push('/payment', extra: {
          'category': category,
          'paymentType': 'first_time',
        });
      }
    });
  }

  void _showPendingPaymentDialog(BuildContext context) {
    AppDialog.info(
      context: context,
      title: 'Payment Pending',
      message:
          'You have a pending payment for this category. Please wait for admin verification (1-3 working days).',
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

        final iconSize = ResponsiveValues.iconSizeXXL(context);
        final titleSize = ResponsiveValues.fontTitleMedium(context);
        final badgeSize = ResponsiveValues.fontBodySmall(context);
        final padding = ResponsiveValues.cardPadding(context);
        final iconSpacing = ResponsiveValues.spacingS(context);

        return Container(
          margin: margin ??
              EdgeInsets.only(bottom: ResponsiveValues.spacingL(context)),
          child: ClipRRect(
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
                  borderRadius: BorderRadius.circular(
                      ResponsiveValues.radiusXLarge(context)),
                  border: Border.all(
                    color: hasAccess
                        ? AppColors.telegramGreen.withValues(alpha: 0.3)
                        : chapter.isFree
                            ? AppColors.telegramBlue.withValues(alpha: 0.3)
                            : AppColors.getTextSecondary(context)
                                .withValues(alpha: 0.1),
                    width: 1.5,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _handleTap(context),
                    borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusXLarge(context)),
                    child: Padding(
                      padding: padding,
                      child: Row(
                        children: [
                          Container(
                            width: iconSize,
                            height: iconSize,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  statusColor.withValues(alpha: 0.2),
                                  statusColor.withValues(alpha: 0.05)
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(
                                  ResponsiveValues.radiusLarge(context)),
                              border: Border.all(
                                  color: statusColor.withValues(alpha: 0.3),
                                  width: 1.5),
                            ),
                            child: Icon(_getStatusIcon(hasAccess),
                                size: iconSize * 0.5, color: statusColor),
                          ),
                          SizedBox(width: iconSpacing),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  chapter.name,
                                  style: AppTextStyles.titleMedium(context)
                                      .copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: titleSize,
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(
                                    height: ResponsiveValues.spacingS(context)),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: iconSpacing,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusBgColor,
                                    borderRadius: BorderRadius.circular(
                                        ResponsiveValues.radiusFull(context)),
                                    border: Border.all(
                                        color:
                                            statusColor.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(_getStatusIcon(hasAccess),
                                          size: badgeSize * 1.2,
                                          color: statusColor),
                                      const SizedBox(width: 4),
                                      Text(
                                        _getStatusText(hasAccess),
                                        style: TextStyle(
                                          fontSize: badgeSize,
                                          color: statusColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.only(left: iconSpacing),
                            child: Container(
                              padding: EdgeInsets.all(iconSpacing),
                              decoration: BoxDecoration(
                                color: hasAccess
                                    ? AppColors.telegramBlue
                                        .withValues(alpha: 0.1)
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                hasAccess
                                    ? Icons.chevron_right_rounded
                                    : Icons.lock_rounded,
                                size: badgeSize * 1.5,
                                color: hasAccess
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
              ),
            ),
          ),
        )
            .animate()
            .fadeIn(
              duration: AppThemes.animationMedium,
              delay: (index * 50).ms,
            )
            .slideX(
              begin: 0.1,
              end: 0,
              duration: AppThemes.animationMedium,
              delay: (index * 50).ms,
            );
      },
    );
  }
}

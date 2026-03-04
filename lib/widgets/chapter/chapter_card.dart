import 'dart:ui';
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
import 'package:familyacademyclient/utils/responsive_values.dart';
import 'package:shimmer/shimmer.dart';
import '../common/responsive_widgets.dart';

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

  Widget _buildGlassBottomSheet(BuildContext context, {required Widget child}) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(24),
        topRight: Radius.circular(24),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
            border: Border.all(
              color: AppColors.telegramBlue.withValues(alpha: 0.2),
            ),
          ),
          child: Padding(
            padding: ResponsiveValues.dialogPadding(context),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSheetHandle(BuildContext context) {
    return Center(
      child: Container(
        width: ResponsiveValues.spacingXXL(context),
        height: ResponsiveValues.spacingXS(context),
        decoration: BoxDecoration(
          color: AppColors.getTextSecondary(context).withValues(alpha: 0.3),
          borderRadius:
              BorderRadius.circular(ResponsiveValues.radiusSmall(context)),
        ),
      ),
    );
  }

  Widget _buildGradientButton({
    required String label,
    required VoidCallback onPressed,
    required List<Color> gradient,
  }) {
    return Builder(
      builder: (context) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
          borderRadius:
              BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withValues(alpha: 0.3),
              blurRadius: ResponsiveValues.spacingS(context),
              offset: Offset(0, ResponsiveValues.spacingXS(context)),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius:
                BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
            child: Container(
              padding: EdgeInsets.symmetric(
                vertical: ResponsiveValues.spacingM(context),
              ),
              alignment: Alignment.center,
              child: ResponsiveText(
                label,
                style: AppTextStyles.labelLarge(context).copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDialogContent(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required String buttonText,
    required VoidCallback onButtonPressed,
  }) {
    return ResponsiveColumn(
      children: [
        ResponsiveRow(
          children: [
            Container(
              padding: EdgeInsets.all(ResponsiveValues.spacingL(context)),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: ResponsiveIcon(
                icon,
                size: ResponsiveValues.iconSizeL(context),
                color: iconColor,
              ),
            ),
            const ResponsiveSizedBox(width: AppSpacing.l),
            Expanded(
              child: ResponsiveColumn(
                children: [
                  ResponsiveText(
                    title,
                    style: AppTextStyles.titleMedium(context).copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const ResponsiveSizedBox(height: AppSpacing.xs),
                  ResponsiveText(
                    message,
                    style: AppTextStyles.bodySmall(context).copyWith(
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const ResponsiveSizedBox(height: AppSpacing.xl),
        ResponsiveRow(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    vertical: ResponsiveValues.spacingM(context),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      ResponsiveValues.radiusMedium(context),
                    ),
                  ),
                ),
                child: ResponsiveText(
                  'Cancel',
                  style: AppTextStyles.labelLarge(context).copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
              ),
            ),
            const ResponsiveSizedBox(width: AppSpacing.m),
            Expanded(
              child: _buildGradientButton(
                label: buttonText,
                onPressed: onButtonPressed,
                gradient: AppColors.blueGradient,
              ),
            ),
          ],
        ),
      ],
    );
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildGlassBottomSheet(
        context,
        child: ResponsiveColumn(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBottomSheetHandle(context),
            const ResponsiveSizedBox(height: AppSpacing.xl),
            _buildDialogContent(
              context,
              icon: Icons.lock_open_rounded,
              iconColor: AppColors.telegramBlue,
              title: 'Purchase Required',
              message:
                  'You need to purchase "${category.name}" to access this chapter.',
              buttonText: 'Purchase Now',
              onButtonPressed: () {
                Navigator.pop(context);
                context.push('/payment', extra: {
                  'category': category,
                  'paymentType': 'first_time',
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPendingPaymentDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildGlassBottomSheet(
        context,
        child: ResponsiveColumn(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBottomSheetHandle(context),
            const ResponsiveSizedBox(height: AppSpacing.xl),
            _buildDialogContent(
              context,
              icon: Icons.schedule_rounded,
              iconColor: AppColors.statusPending,
              title: 'Payment Pending',
              message:
                  'You have a pending payment for this category. Please wait for admin verification (1-3 working days).',
              buttonText: 'OK',
              onButtonPressed: () => Navigator.pop(context),
            ),
          ],
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

        final iconSize = ResponsiveValues.iconSizeXXL(context);
        final titleSize = ResponsiveValues.fontTitleMedium(context);
        final padding = ResponsiveValues.cardPadding(context);

        return Container(
          margin: margin ??
              EdgeInsets.only(
                bottom: ResponsiveValues.spacingL(context),
              ),
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
                      child: ResponsiveRow(
                        children: [
                          Container(
                            width: iconSize,
                            height: iconSize,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  statusColor.withValues(alpha: 0.2),
                                  statusColor.withValues(alpha: 0.05),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(
                                ResponsiveValues.radiusLarge(context),
                              ),
                              border: Border.all(
                                color: statusColor.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                            ),
                            child: ResponsiveIcon(
                              _getStatusIcon(hasAccess),
                              size: iconSize * 0.5,
                              color: statusColor,
                            ),
                          ),
                          const ResponsiveSizedBox(width: AppSpacing.l),
                          Expanded(
                            child: ResponsiveColumn(
                              children: [
                                ResponsiveText(
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
                                const ResponsiveSizedBox(height: AppSpacing.s),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal:
                                        ResponsiveValues.spacingS(context),
                                    vertical:
                                        ResponsiveValues.spacingXXS(context),
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusBgColor,
                                    borderRadius: BorderRadius.circular(
                                      ResponsiveValues.radiusFull(context),
                                    ),
                                    border: Border.all(
                                      color: statusColor.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: ResponsiveRow(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ResponsiveIcon(
                                        _getStatusIcon(hasAccess),
                                        size: ResponsiveValues.iconSizeXXS(
                                            context),
                                        color: statusColor,
                                      ),
                                      const ResponsiveSizedBox(
                                          width: AppSpacing.xs),
                                      ResponsiveText(
                                        _getStatusText(hasAccess),
                                        style: AppTextStyles.caption(context)
                                            .copyWith(
                                          color: statusColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!hasAccess && !chapter.isFree)
                                  Padding(
                                    padding: EdgeInsets.only(
                                      top: ResponsiveValues.spacingS(context),
                                    ),
                                    child: ResponsiveText(
                                      'Purchase "$categoryName" to unlock',
                                      style: AppTextStyles.caption(context)
                                          .copyWith(
                                        color:
                                            AppColors.getTextSecondary(context),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.all(
                                ResponsiveValues.spacingS(context)),
                            decoration: BoxDecoration(
                              color: hasAccess
                                  ? AppColors.telegramBlue
                                      .withValues(alpha: 0.1)
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            child: ResponsiveIcon(
                              hasAccess
                                  ? Icons.chevron_right_rounded
                                  : Icons.lock_rounded,
                              size: ResponsiveValues.iconSizeL(context),
                              color: hasAccess
                                  ? AppColors.telegramBlue
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
                delay: (index * 50).ms)
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

class ChapterCardShimmer extends StatelessWidget {
  final int index;

  const ChapterCardShimmer({super.key, this.index = 0});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconSize = ResponsiveValues.iconSizeXXL(context);
    final padding = ResponsiveValues.cardPadding(context);

    return Container(
      margin: EdgeInsets.only(
        bottom: ResponsiveValues.spacingL(context),
      ),
      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(ResponsiveValues.radiusXLarge(context)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: Container(
            padding: padding,
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
                color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
              ),
            ),
            child: ResponsiveRow(
              children: [
                Shimmer.fromColors(
                  baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                  highlightColor:
                      isDark ? Colors.grey[700]! : Colors.grey[100]!,
                  child: Container(
                    width: iconSize,
                    height: iconSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusLarge(context),
                      ),
                    ),
                  ),
                ),
                const ResponsiveSizedBox(width: AppSpacing.l),
                Expanded(
                  child: ResponsiveColumn(
                    children: [
                      Shimmer.fromColors(
                        baseColor:
                            isDark ? Colors.grey[800]! : Colors.grey[300]!,
                        highlightColor:
                            isDark ? Colors.grey[700]! : Colors.grey[100]!,
                        child: Container(
                          width: double.infinity,
                          height: ResponsiveValues.spacingXL(context),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(
                              ResponsiveValues.radiusSmall(context),
                            ),
                          ),
                        ),
                      ),
                      const ResponsiveSizedBox(height: AppSpacing.m),
                      Shimmer.fromColors(
                        baseColor:
                            isDark ? Colors.grey[800]! : Colors.grey[300]!,
                        highlightColor:
                            isDark ? Colors.grey[700]! : Colors.grey[100]!,
                        child: Container(
                          width: ResponsiveValues.spacingXXL(context) * 2,
                          height: ResponsiveValues.spacingXL(context),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(
                              ResponsiveValues.radiusFull(context),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Shimmer.fromColors(
                  baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                  highlightColor:
                      isDark ? Colors.grey[700]! : Colors.grey[100]!,
                  child: Container(
                    width: ResponsiveValues.iconSizeL(context),
                    height: ResponsiveValues.iconSizeL(context),
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
        duration: AppThemes.animationDurationMedium, delay: (index * 50).ms);
  }
}

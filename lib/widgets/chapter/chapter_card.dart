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
import 'package:familyacademyclient/utils/responsive.dart';
import 'package:shimmer/shimmer.dart';

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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildGlassBottomSheet(
        context,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBottomSheetHandle(context),
            const SizedBox(height: 20),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBottomSheetHandle(context),
            const SizedBox(height: 20),
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
                AppColors.getCard(context).withOpacity(0.4),
                AppColors.getCard(context).withOpacity(0.2),
              ],
            ),
            border: Border.all(
              color: AppColors.telegramBlue.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSheetHandle(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.getTextSecondary(context).withOpacity(0.3),
          borderRadius: BorderRadius.circular(2),
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
    return Column(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildGradientButton(
                label: buttonText,
                onPressed: onButtonPressed,
                gradient: const [Color(0xFF2AABEE), Color(0xFF5856D6)],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGradientButton({
    required String label,
    required VoidCallback onPressed,
    required List<Color> gradient,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            child: Text(
              label,
              style: AppTextStyles.labelLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
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

        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < 600;
        final isTablet = screenWidth >= 600 && screenWidth < 1024;

        final iconSize = isMobile ? 48.0 : (isTablet ? 56.0 : 64.0);
        final titleSize = isMobile ? 15.0 : (isTablet ? 16.0 : 17.0);
        final padding = isMobile
            ? AppThemes.spacingL
            : (isTablet ? AppThemes.spacingXL : AppThemes.spacingXXL);

        return Container(
          margin: margin ?? EdgeInsets.only(bottom: AppThemes.spacingL),
          child: ClipRRect(
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
                    color: hasAccess
                        ? AppColors.telegramGreen.withOpacity(0.3)
                        : chapter.isFree
                            ? AppColors.telegramBlue.withOpacity(0.3)
                            : AppColors.getTextSecondary(context)
                                .withOpacity(0.1),
                    width: 1.5,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _handleTap(context),
                    borderRadius: BorderRadius.circular(24),
                    child: Padding(
                      padding: EdgeInsets.all(padding),
                      child: Row(
                        children: [
                          Container(
                            width: iconSize,
                            height: iconSize,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  statusColor.withOpacity(0.2),
                                  statusColor.withOpacity(0.05),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: statusColor.withOpacity(0.3),
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              _getStatusIcon(hasAccess),
                              color: statusColor,
                              size: iconSize * 0.5,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  chapter.name,
                                  style: AppTextStyles.titleMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: titleSize,
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusBgColor,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: statusColor.withOpacity(0.3),
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
                                      const SizedBox(width: 4),
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
                                if (!hasAccess && !chapter.isFree)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      'Purchase "$categoryName" to unlock',
                                      style: AppTextStyles.caption.copyWith(
                                        color:
                                            AppColors.getTextSecondary(context),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: hasAccess
                                  ? AppColors.telegramBlue.withOpacity(0.1)
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              hasAccess
                                  ? Icons.chevron_right_rounded
                                  : Icons.lock_rounded,
                              size: isMobile ? 20 : (isTablet ? 24 : 28),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    final iconSize = isMobile ? 48.0 : (isTablet ? 56.0 : 64.0);
    final padding = isMobile
        ? AppThemes.spacingL
        : (isTablet ? AppThemes.spacingXL : AppThemes.spacingXXL);

    return Container(
      margin: EdgeInsets.only(bottom: AppThemes.spacingL),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: Container(
            padding: EdgeInsets.all(padding),
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
                color: Theme.of(context).dividerColor.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Row(
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
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Shimmer.fromColors(
                        baseColor:
                            isDark ? Colors.grey[800]! : Colors.grey[300]!,
                        highlightColor:
                            isDark ? Colors.grey[700]! : Colors.grey[100]!,
                        child: Container(
                          width: double.infinity,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Shimmer.fromColors(
                        baseColor:
                            isDark ? Colors.grey[800]! : Colors.grey[300]!,
                        highlightColor:
                            isDark ? Colors.grey[700]! : Colors.grey[100]!,
                        child: Container(
                          width: 80,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
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
                    width: 32,
                    height: 32,
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

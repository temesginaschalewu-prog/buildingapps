// lib/widgets/chapter/chapter_card.dart
// PRODUCTION-READY FINAL VERSION - WITH PENDING PAYMENT CHECK

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/chapter_model.dart';
import '../../models/category_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/payment_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/connectivity_service.dart';
import '../../services/snackbar_service.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/responsive_values.dart';
import '../common/app_card.dart';
import '../common/app_dialog.dart';

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
    final settingsProvider = context.read<SettingsProvider>();

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
                Container(
                  width: ResponsiveValues.iconSizeXXL(context),
                  height: ResponsiveValues.iconSizeXXL(context),
                  decoration: BoxDecoration(
                    color: isComingSoon
                        ? AppColors.telegramYellow.withValues(alpha: 0.10)
                        : (canAccess
                            ? AppColors.telegramGreen.withValues(alpha: 0.09)
                            : AppColors.telegramGray.withValues(alpha: 0.08)),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chapter.name,
                        style: AppTextStyles.titleMedium(context)
                            .copyWith(fontWeight: FontWeight.w700),
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
                            settingsProvider
                                .getChapterAvailableLabel(chapter.releaseDate),
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
                              color:
                                  AppColors.telegramGreen.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(
                                  ResponsiveValues.radiusFull(context)),
                            ),
                            child: Text(
                              settingsProvider.getChapterFreePreviewBadge(),
                              style:
                                  AppTextStyles.statusBadge(context).copyWith(
                                color: AppColors.telegramGreen,
                                fontSize:
                                    ResponsiveValues.fontStatusBadge(context) *
                                        0.9,
                                fontWeight: FontWeight.w700,
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
                              color:
                                  AppColors.telegramYellow.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(
                                  ResponsiveValues.radiusFull(context)),
                            ),
                            child: Text(
                              settingsProvider.getChapterComingSoonBadge(),
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
    final paymentProvider = context.read<PaymentProvider>();
    final categoryProvider = context.read<CategoryProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    final connectivity = context.read<ConnectivityService>();

    if (!authProvider.isAuthenticated) {
      SnackbarService()
          .showError(context, settingsProvider.getChapterLoginRequiredMessage());
      return;
    }

    final category = categoryProvider.getCategoryById(categoryId);
    if (category == null) {
      SnackbarService()
          .showError(context, settingsProvider.getChapterCategoryMissingMessage());
      return;
    }

    final bool isComingSoon = chapter.status.toLowerCase() == 'coming_soon';

    if (isComingSoon) {
      SnackbarService().showInfo(
        context,
        settingsProvider.getChapterComingSoonMessage(),
      );
      return;
    }

    final bool hasAccess = chapter.canAccessContent ||
        subscriptionProvider.hasActiveSubscriptionForCategory(categoryId);

    if (hasAccess) {
      onTap();
      return;
    }

    final hasPendingPayment = paymentProvider.getPendingPayments().any(
          (payment) =>
              payment.categoryId == categoryId ||
              payment.categoryName.toLowerCase() == category.name.toLowerCase(),
        );

    if (hasPendingPayment) {
      await AppDialog.info(
        context: context,
        title: settingsProvider.getChapterPaymentPendingTitle(),
        message: settingsProvider.getChapterPaymentPendingMessage(category.name),
      );
      return;
    }

    if (!connectivity.isOnline && await _hasOfflineChapterContent(authProvider)) {
      onTap();
      return;
    }

    if (!connectivity.isOnline) {
      SnackbarService().showOffline(context, action: 'make payment');
      return;
    }

    _showPaymentDialog(context, category);
  }

  void _showPaymentDialog(BuildContext context, Category category) {
    final subscriptionProvider = context.read<SubscriptionProvider>();
    final hasExpiredSubscription = subscriptionProvider.expiredSubscriptions
        .any((sub) => sub.categoryId == category.id);

    final paymentType = hasExpiredSubscription ? 'repayment' : 'first_time';

    AppDialog.confirm(
      context: context,
      title: context.read<SettingsProvider>().getChapterUnlockTitle(),
      message: hasExpiredSubscription
          ? context
              .read<SettingsProvider>()
              .getChapterUnlockExpiredMessage(category.name)
          : context
              .read<SettingsProvider>()
              .getChapterUnlockPurchaseMessage(category.name),
      confirmText: hasExpiredSubscription
          ? context.read<SettingsProvider>().getChapterUnlockRenewButton()
          : context.read<SettingsProvider>().getChapterUnlockPurchaseButton(),
    ).then((confirmed) {
      if (confirmed == true && context.mounted) {
        context.push('/payment', extra: {
          'category': category,
          'paymentType': paymentType,
        });
      }
    });
  }

  Future<bool> _hasOfflineChapterContent(AuthProvider authProvider) async {
    final userId = authProvider.currentUser?.id;
    if (userId == null) return false;

    final deviceService = authProvider.deviceService;
    final videoPaths = await deviceService.getCacheItem<Map<String, dynamic>>(
      'cached_videos_chapter_${chapter.id}_$userId',
      isUserSpecific: true,
    );
    if (videoPaths != null && videoPaths.isNotEmpty) {
      return true;
    }

    final notePaths = await deviceService.getCacheItem<Map<String, dynamic>>(
      'cached_notes_chapter_${chapter.id}_$userId',
      isUserSpecific: true,
    );
    return notePaths != null && notePaths.isNotEmpty;
  }
}

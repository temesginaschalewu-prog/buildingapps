import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/subscription_model.dart';
import '../../providers/settings_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../services/snackbar_service.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/common/base_screen_mixin.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_button.dart';
import '../../themes/app_themes.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/responsive_values.dart';
import '../../utils/helpers.dart';
import '../../utils/constants.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen>
    with BaseScreenMixin<SubscriptionScreen>, TickerProviderStateMixin {
  Timer? _refreshTimer;
  String? _errorMessage;

  late SubscriptionProvider _subscriptionProvider;
  late SettingsProvider _settingsProvider;

  @override
  String get screenTitle => AppStrings.mySubscriptions;

  @override
  String? get screenSubtitle => isRefreshing
      ? AppStrings.refreshing
      : (isOffline ? AppStrings.offlineMode : AppStrings.manageSubscriptions);

  @override
  bool get isLoading =>
      _subscriptionProvider.isLoading && !_subscriptionProvider.hasInitialData;

  @override
  bool get hasCachedData => _subscriptionProvider.hasInitialData;

  @override
  dynamic get errorMessage => _errorMessage;

  // ✅ Shimmer type for subscriptions
  @override
  ShimmerType get shimmerType => ShimmerType.subscriptionCard;

  @override
  int get shimmerItemCount => 3;

  @override
  Widget? get appBarLeading => IconButton(
        icon: Icon(
          Icons.arrow_back_rounded,
          color: AppColors.getTextPrimary(context),
        ),
        onPressed: () => context.pop(),
      );

  @override
  void initState() {
    super.initState();

    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (isMounted && !isOffline) {
        _subscriptionProvider.loadSubscriptions(forceRefresh: true);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _subscriptionProvider = Provider.of<SubscriptionProvider>(context);
    _settingsProvider = Provider.of<SettingsProvider>(context);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Future<void> onRefresh() async {
    if (isOffline) {
      SnackbarService().showOffline(context, action: AppStrings.refresh);
      return;
    }

    try {
      await _subscriptionProvider.loadSubscriptions(
        forceRefresh: true,
        isManualRefresh: true,
      );
      setState(() {
        _errorMessage = null;
      });
    } catch (e) {
      if (isNetworkError(e)) {
        setState(() {
          _errorMessage = null;
        });
        SnackbarService().showOffline(context, action: AppStrings.refresh);
      } else {
        if (_subscriptionProvider.hasInitialData) {
          setState(() => _errorMessage = null);
          SnackbarService().showInfo(
            context,
            _settingsProvider.getSubscriptionRefreshSavedMessage(),
          );
        } else {
          setState(() => _errorMessage = getUserFriendlyErrorMessage(e));
          SnackbarService().showError(context, AppStrings.refreshFailed);
        }
      }
    }
  }

  Color _getStatusColor(String status) =>
      UiHelpers.getSubscriptionStatusColor(status);
  String _getStatusText(String status) =>
      UiHelpers.getSubscriptionStatusText(status);

  IconData _getCategoryIcon(String categoryName) {
    final name = categoryName.toLowerCase();
    if (name.contains('math')) return Icons.calculate_rounded;
    if (name.contains('science')) return Icons.science_rounded;
    if (name.contains('language')) return Icons.language_rounded;
    if (name.contains('history')) return Icons.history_edu_rounded;
    if (name.contains('art')) return Icons.palette_rounded;
    if (name.contains('music')) return Icons.music_note_rounded;
    if (name.contains('computer')) return Icons.computer_rounded;
    return Icons.category_rounded;
  }

  Widget _buildSubscriptionCard(Subscription subscription) {
    final isActive = subscription.isActive;
    final isExpired = subscription.isExpired;
    final isExpiringSoon = subscription.isExpiringSoon;

    final status =
        isExpired ? 'expired' : (isExpiringSoon ? 'expiring_soon' : 'active');
    final statusColor = _getStatusColor(status);

    final daysRemaining = subscription.daysRemaining;
    final progressValue = daysRemaining / 30;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: ResponsiveValues.spacingL(context),
        vertical: ResponsiveValues.spacingS(context),
      ),
      child: AppCard.subscription(
        statusColor: statusColor,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: (isExpired || isExpiringSoon) && !isOffline
                ? () {
                    context.push(
                      '/payment',
                      extra: {
                        'category': {
                          'id': subscription.categoryId,
                          'name':
                              subscription.categoryName ?? AppStrings.category,
                          'price': subscription.price,
                          'billing_cycle': subscription.billingCycle,
                          'isFree': false,
                        },
                        'paymentType': 'repayment',
                        'months': _settingsProvider
                            .getBillingCycleMonths(subscription.billingCycle),
                        'duration_text': _settingsProvider
                            .getBillingCycleDurationText(
                                subscription.billingCycle),
                      },
                    );
                  }
                : null,
            borderRadius: BorderRadius.circular(
              ResponsiveValues.radiusXLarge(context),
            ),
            splashColor: AppColors.telegramBlue.withValues(alpha: 0.1),
            highlightColor: Colors.transparent,
            child: Padding(
              padding: ResponsiveValues.cardPadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width:
                            ResponsiveValues.featureCardIconContainerSize(
                                context),
                        height:
                            ResponsiveValues.featureCardIconContainerSize(
                                context),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              statusColor.withValues(alpha: 0.2),
                              statusColor.withValues(alpha: 0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(
                            ResponsiveValues.radiusMedium(context),
                          ),
                          border: Border.all(
                            color: statusColor,
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            _getCategoryIcon(
                              subscription.categoryName ?? '',
                            ),
                            size: ResponsiveValues.iconSizeL(context),
                            color: statusColor,
                          ),
                        ),
                      ),
                      SizedBox(width: ResponsiveValues.spacingL(context)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subscription.categoryName ??
                                  AppStrings.unknownCategory,
                              style: AppTextStyles.titleMedium(
                                context,
                              ).copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(
                              height: ResponsiveValues.spacingXS(context),
                            ),
                            Text(
                              _settingsProvider.getBillingCyclePlanLabel(
                                subscription.billingCycle,
                              ),
                              style: AppTextStyles.bodySmall(context).copyWith(
                                color: AppColors.getTextSecondary(
                                  context,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveValues.spacingM(context),
                          vertical: ResponsiveValues.spacingXS(context),
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              statusColor.withValues(alpha: 0.2),
                              statusColor.withValues(alpha: 0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(
                            ResponsiveValues.radiusFull(context),
                          ),
                          border: Border.all(color: statusColor),
                        ),
                        child: Text(
                          _getStatusText(status),
                          style: AppTextStyles.statusBadge(context).copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: ResponsiveValues.spacingL(context)),
                  if (isActive && !isExpired && isExpiringSoon)
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_settingsProvider.getSubscriptionExpiresInPrefix()} $daysRemaining ${AppStrings.days}',
                              style: AppTextStyles.labelSmall(context).copyWith(
                                color: AppColors.getTextSecondary(
                                  context,
                                ),
                              ),
                            ),
                            Text(
                              '${((1 - progressValue) * 100).toInt()}% ${AppStrings.used}',
                              style: AppTextStyles.labelSmall(context).copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                          height: ResponsiveValues.spacingS(context),
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(
                            ResponsiveValues.radiusFull(context),
                          ),
                          child: LinearProgressIndicator(
                            value: progressValue.clamp(0.0, 1.0),
                            backgroundColor: AppColors.getSurface(
                              context,
                            ).withValues(alpha: 0.3),
                            color: statusColor,
                            minHeight: ResponsiveValues.progressBarHeight(
                              context,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: ResponsiveValues.spacingL(context),
                        ),
                      ],
                    ),
                  AppCard.glass(
                    child: Padding(
                      padding: ResponsiveValues.cardPadding(context),
                      child: Column(
                        children: [
                          _buildInfoRow(
                            icon: Icons.calendar_today_rounded,
                            label: AppStrings.startDate,
                            value: _formatDate(subscription.startDate),
                          ),
                          SizedBox(
                            height: ResponsiveValues.spacingM(context),
                          ),
                          _buildInfoRow(
                            icon: isExpired
                                ? Icons.event_busy_rounded
                                : Icons.calendar_month_rounded,
                            label: AppStrings.expiryDate,
                            value: _formatDate(subscription.expiryDate),
                            valueColor: isExpired ? statusColor : null,
                          ),
                          SizedBox(
                            height: ResponsiveValues.spacingM(context),
                          ),
                          _buildInfoRow(
                            icon: Icons.repeat_rounded,
                            label: AppStrings.billingCycle,
                            value: _settingsProvider.getBillingCyclePlanLabel(
                              subscription.billingCycle,
                            ),
                          ),
                          if (subscription.price != null) ...[
                            SizedBox(
                              height: ResponsiveValues.spacingM(context),
                            ),
                            _buildInfoRow(
                              icon: Icons.payments_rounded,
                              label: AppStrings.price,
                              value:
                                  '${subscription.price!.toStringAsFixed(0)} ${AppStrings.currencyLabel}',
                              valueColor: AppColors.telegramBlue,
                            ),
                          ],
                          if (isActive && !isExpired) ...[
                            SizedBox(
                              height: ResponsiveValues.spacingM(context),
                            ),
                            _buildInfoRow(
                              icon: Icons.timer_rounded,
                              label: _settingsProvider
                                  .getSubscriptionDaysRemainingLabel(),
                              value: '$daysRemaining ${AppStrings.days}',
                              valueColor: isExpiringSoon ? statusColor : null,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if ((isExpired || isExpiringSoon) && !isOffline) ...[
                    SizedBox(height: ResponsiveValues.spacingXL(context)),
                    SizedBox(
                      width: double.infinity,
                      child: isExpired
                          ? AppButton.danger(
                              label:
                                  _settingsProvider.getSubscriptionRenewNowLabel(),
                              onPressed: () {
                                context.push(
                                  '/payment',
                                  extra: {
                                    'category': {
                                      'id': subscription.categoryId,
                                      'name': subscription.categoryName ??
                                          AppStrings.category,
                                      'price': subscription.price,
                                      'billing_cycle':
                                          subscription.billingCycle,
                                      'isFree': false,
                                    },
                                    'paymentType': 'repayment',
                                  },
                                );
                              },
                              expanded: true,
                            )
                          : AppButton.primary(
                              label: _settingsProvider
                                  .getSubscriptionExtendNowLabel(),
                              onPressed: () {
                                context.push(
                                  '/payment',
                                  extra: {
                                    'category': {
                                      'id': subscription.categoryId,
                                      'name': subscription.categoryName ??
                                          AppStrings.category,
                                      'price': subscription.price,
                                      'billing_cycle':
                                          subscription.billingCycle,
                                      'isFree': false,
                                    },
                                    'paymentType': 'repayment',
                                  },
                                );
                              },
                              expanded: true,
                            ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: AppThemes.animationMedium)
        .slideY(begin: 0.1, end: 0, duration: AppThemes.animationMedium);
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: ResponsiveValues.iconSizeL(context),
          height: ResponsiveValues.iconSizeL(context),
          decoration: BoxDecoration(
            color: AppColors.telegramBlue.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: ResponsiveValues.iconSizeXS(context),
            color: AppColors.telegramBlue,
          ),
        ),
        SizedBox(width: ResponsiveValues.spacingM(context)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.labelMedium(context).copyWith(
                  color: AppColors.getTextSecondary(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: ResponsiveValues.spacingXXS(context)),
              Text(
                value,
                style: AppTextStyles.bodyMedium(context).copyWith(
                  color: valueColor ?? AppColors.getTextPrimary(context),
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget buildContent(BuildContext context) {
    final activeSubscriptions = _subscriptionProvider.activeSubscriptions;
    final expiredSubscriptions = _subscriptionProvider.expiredSubscriptions;
    final allSubscriptions = _subscriptionProvider.allSubscriptions;

    if (_errorMessage != null) {
      return Center(
        child: buildErrorWidget(_errorMessage!, onRetry: onRefresh),
      );
    }

    // ✅ Show empty state only if no subscriptions AND provider has finished loading
    final shouldShowEmpty = allSubscriptions.isEmpty &&
        (_subscriptionProvider.hasLoaded ||
            _subscriptionProvider.hasInitialData);

    if (shouldShowEmpty && !isLoading) {
      return Center(
        child: isOffline
            ? buildEmptyWidget(
                dataType: AppStrings.subscriptions,
                customMessage: AppStrings.noCachedSubscriptions,
                isOffline: true,
              )
            : buildEmptyWidget(
                dataType: AppStrings.subscriptions,
                customMessage: AppStrings.noSubscriptionsYet,
              ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.telegramBlue,
      backgroundColor: AppColors.getSurface(context),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (activeSubscriptions.isNotEmpty) ...[
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                ResponsiveValues.spacingL(context),
                ResponsiveValues.spacingM(context),
                ResponsiveValues.spacingL(context),
                ResponsiveValues.spacingS(context),
              ),
              sliver: SliverToBoxAdapter(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppStrings.active,
                      style: AppTextStyles.titleLarge(
                        context,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveValues.spacingXS(context),
                        vertical: ResponsiveValues.spacingXXS(context),
                      ),
                      child: Text(
                        '${activeSubscriptions.length}',
                        style: AppTextStyles.labelMedium(context).copyWith(
                          color: AppColors.telegramGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveValues.spacingL(context),
                  ),
                  child: _buildSubscriptionCard(activeSubscriptions[index]),
                ),
                childCount: activeSubscriptions.length,
              ),
            ),
          ],
          if (expiredSubscriptions.isNotEmpty) ...[
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                ResponsiveValues.spacingL(context),
                ResponsiveValues.spacingXXL(context),
                ResponsiveValues.spacingL(context),
                ResponsiveValues.spacingS(context),
              ),
              sliver: SliverToBoxAdapter(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppStrings.expired,
                      style: AppTextStyles.titleLarge(
                        context,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveValues.spacingXS(context),
                        vertical: ResponsiveValues.spacingXXS(context),
                      ),
                      child: Text(
                        '${expiredSubscriptions.length}',
                        style: AppTextStyles.labelMedium(context).copyWith(
                          color: AppColors.telegramRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveValues.spacingL(context),
                  ),
                  child: _buildSubscriptionCard(expiredSubscriptions[index]),
                ),
                childCount: expiredSubscriptions.length,
              ),
            ),
          ],
          if (isLoading && allSubscriptions.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: ResponsiveValues.sectionLoadingPadding(context),
                child: const Center(
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.telegramBlue,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: SizedBox(height: ResponsiveValues.spacingXXL(context)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return buildScreen(
      content: buildContent(context),
      showRefreshIndicator: false,
    );
  }
}

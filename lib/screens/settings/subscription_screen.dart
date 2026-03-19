// lib/screens/settings/subscription_screen.dart
// COMPLETE FIXED VERSION - NULL SAFETY IN INITSTATE

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/subscription_model.dart';
import '../../providers/subscription_provider.dart';
import '../../services/connectivity_service.dart';
import '../../services/snackbar_service.dart';
import '../../services/offline_queue_manager.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_shimmer.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_bar.dart';
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
    with TickerProviderStateMixin {
  bool _isRefreshing = false;
  bool _isOffline = false;
  int _pendingCount = 0;
  Timer? _refreshTimer;
  StreamSubscription? _connectivitySubscription;
  String? _errorMessage;
  bool _isMounted = false; // ✅ Track mounted state

  bool _hasCachedData = false;

  @override
  void initState() {
    super.initState();
    _isMounted = true;

    // ✅ DON'T access context here - use post frame callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isMounted) {
        _initialize();
      }
    });

    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_isMounted && !_isOffline) {
        _loadSubscriptions(forceRefresh: true);
      }
    });
  }

  @override
  void dispose() {
    _isMounted = false; // ✅ Mark as unmounted immediately
    _refreshTimer?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    if (!_isMounted) return;

    await _checkConnectivity();
    _setupConnectivityListener();
    _checkPendingCount();
    _checkCachedData();
    _loadSubscriptions();
  }

  void _setupConnectivityListener() {
    if (!_isMounted) return;

    final connectivityService = context.read<ConnectivityService>();
    _connectivitySubscription =
        connectivityService.onConnectivityChanged.listen((isOnline) {
      if (!_isMounted) return;

      setState(() {
        _isOffline = !isOnline;
        final queueManager = context.read<OfflineQueueManager>();
        _pendingCount = queueManager.pendingCount;
      });

      if (isOnline && !_isRefreshing) {
        _loadSubscriptions(forceRefresh: true);
      }
    });
  }

  Future<void> _checkConnectivity() async {
    if (!_isMounted) return;

    final connectivityService = context.read<ConnectivityService>();
    await connectivityService.checkConnectivity();
    if (!_isMounted) return;

    setState(() {
      _isOffline = !connectivityService.isOnline;
      final queueManager = context.read<OfflineQueueManager>();
      _pendingCount = queueManager.pendingCount;
    });
  }

  Future<void> _checkPendingCount() async {
    final queueManager = context.read<OfflineQueueManager>();
    if (_isMounted) {
      setState(() => _pendingCount = queueManager.pendingCount);
    }
  }

  void _checkCachedData() {
    final subscriptionProvider = context.read<SubscriptionProvider>();
    _hasCachedData = subscriptionProvider.isLoaded &&
        subscriptionProvider.allSubscriptions.isNotEmpty;
  }

  Future<void> _loadSubscriptions({bool forceRefresh = false}) async {
    if (!_isMounted) return;

    final subscriptionProvider = context.read<SubscriptionProvider>();
    try {
      await subscriptionProvider.loadSubscriptions(
          forceRefresh: forceRefresh && !_isOffline);
      if (_isMounted) {
        setState(() {
          _hasCachedData = subscriptionProvider.isLoaded &&
              subscriptionProvider.allSubscriptions.isNotEmpty;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (_isMounted) {
        setState(() {
          _errorMessage = getUserFriendlyErrorMessage(e);
        });
      }
    }
  }

  Future<void> _manualRefresh() async {
    if (_isRefreshing || !_isMounted) return;

    final connectivityService = context.read<ConnectivityService>();
    if (!connectivityService.isOnline) {
      setState(() => _isOffline = true);
      SnackbarService().showOffline(context, action: AppStrings.refresh);
      return;
    }

    setState(() => _isRefreshing = true);

    try {
      final subscriptionProvider = context.read<SubscriptionProvider>();
      await subscriptionProvider.loadSubscriptions(
          forceRefresh: true, isManualRefresh: true);
      setState(() {
        _isOffline = false;
        _errorMessage = null;
      });
      SnackbarService().showSuccess(context, AppStrings.subscriptionsUpdated);
    } catch (e) {
      if (isNetworkError(e)) {
        setState(() => _isOffline = true);
        SnackbarService().showOffline(context, action: AppStrings.refresh);
      } else {
        setState(() => _errorMessage = getUserFriendlyErrorMessage(e));
        SnackbarService().showError(context, AppStrings.refreshFailed);
      }
    } finally {
      if (_isMounted) setState(() => _isRefreshing = false);
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
            onTap: (isExpired || isExpiringSoon) && !_isOffline
                ? () {
                    context.push('/payment', extra: {
                      'category': {
                        'id': subscription.categoryId,
                        'name':
                            subscription.categoryName ?? AppStrings.category,
                        'price': subscription.price,
                        'billing_cycle': subscription.billingCycle,
                        'isFree': false,
                      },
                      'paymentType': 'repayment',
                      'months': subscription.billingCycle == 'semester' ? 4 : 1,
                      'duration_text': subscription.billingCycle == 'semester'
                          ? AppStrings.fourMonths
                          : AppStrings.oneMonth,
                    });
                  }
                : null,
            borderRadius:
                BorderRadius.circular(ResponsiveValues.radiusXLarge(context)),
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
                        width: ResponsiveValues.iconSizeXL(context) * 1.5,
                        height: ResponsiveValues.iconSizeXL(context) * 1.5,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              statusColor.withValues(alpha: 0.2),
                              statusColor.withValues(alpha: 0.05)
                            ],
                          ),
                          borderRadius: BorderRadius.circular(
                              ResponsiveValues.radiusMedium(context)),
                          border: Border.all(color: statusColor, width: 1.5),
                        ),
                        child: Center(
                          child: Icon(
                            _getCategoryIcon(subscription.categoryName ?? ''),
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
                              style: AppTextStyles.titleMedium(context)
                                  .copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(
                                height: ResponsiveValues.spacingXS(context)),
                            Text(
                              subscription.billingCycle == 'monthly'
                                  ? AppStrings.monthlySubscription
                                  : AppStrings.semesterSubscription,
                              style: AppTextStyles.bodySmall(context).copyWith(
                                  color: AppColors.getTextSecondary(context)),
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
                              statusColor.withValues(alpha: 0.05)
                            ],
                          ),
                          borderRadius: BorderRadius.circular(
                              ResponsiveValues.radiusFull(context)),
                          border: Border.all(color: statusColor),
                        ),
                        child: Text(
                          _getStatusText(status),
                          style: AppTextStyles.statusBadge(context).copyWith(
                              color: statusColor, fontWeight: FontWeight.w600),
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
                              '${AppStrings.expiresIn} $daysRemaining ${AppStrings.days}',
                              style: AppTextStyles.labelSmall(context).copyWith(
                                  color: AppColors.getTextSecondary(context)),
                            ),
                            Text(
                              '${((1 - progressValue) * 100).toInt()}% ${AppStrings.used}',
                              style: AppTextStyles.labelSmall(context).copyWith(
                                  color: statusColor,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        SizedBox(height: ResponsiveValues.spacingS(context)),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(
                              ResponsiveValues.radiusFull(context)),
                          child: LinearProgressIndicator(
                            value: progressValue.clamp(0.0, 1.0),
                            backgroundColor: AppColors.getSurface(context)
                                .withValues(alpha: 0.3),
                            color: statusColor,
                            minHeight:
                                ResponsiveValues.progressBarHeight(context),
                          ),
                        ),
                        SizedBox(height: ResponsiveValues.spacingL(context)),
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
                          SizedBox(height: ResponsiveValues.spacingM(context)),
                          _buildInfoRow(
                            icon: isExpired
                                ? Icons.event_busy_rounded
                                : Icons.calendar_month_rounded,
                            label: AppStrings.expiryDate,
                            value: _formatDate(subscription.expiryDate),
                            valueColor: isExpired ? statusColor : null,
                          ),
                          SizedBox(height: ResponsiveValues.spacingM(context)),
                          _buildInfoRow(
                            icon: Icons.repeat_rounded,
                            label: AppStrings.billingCycle,
                            value: subscription.billingCycle == 'monthly'
                                ? AppStrings.monthly
                                : AppStrings.semester,
                          ),
                          if (subscription.price != null) ...[
                            SizedBox(
                                height: ResponsiveValues.spacingM(context)),
                            _buildInfoRow(
                              icon: Icons.payments_rounded,
                              label: AppStrings.price,
                              value:
                                  '${subscription.price!.toStringAsFixed(0)} ETB',
                              valueColor: AppColors.telegramBlue,
                            ),
                          ],
                          if (isActive && !isExpired) ...[
                            SizedBox(
                                height: ResponsiveValues.spacingM(context)),
                            _buildInfoRow(
                              icon: Icons.timer_rounded,
                              label: AppStrings.daysRemaining,
                              value: '$daysRemaining ${AppStrings.days}',
                              valueColor: isExpiringSoon ? statusColor : null,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if ((isExpired || isExpiringSoon) && !_isOffline) ...[
                    SizedBox(height: ResponsiveValues.spacingXL(context)),
                    SizedBox(
                      width: double.infinity,
                      child: isExpired
                          ? AppButton.danger(
                              label: AppStrings.renewNow,
                              onPressed: () {
                                context.push('/payment', extra: {
                                  'category': {
                                    'id': subscription.categoryId,
                                    'name': subscription.categoryName ??
                                        AppStrings.category,
                                    'price': subscription.price,
                                    'billing_cycle': subscription.billingCycle,
                                    'isFree': false,
                                  },
                                  'paymentType': 'repayment',
                                });
                              },
                              expanded: true,
                            )
                          : AppButton.primary(
                              label: AppStrings.extendNow,
                              onPressed: () {
                                context.push('/payment', extra: {
                                  'category': {
                                    'id': subscription.categoryId,
                                    'name': subscription.categoryName ??
                                        AppStrings.category,
                                    'price': subscription.price,
                                    'billing_cycle': subscription.billingCycle,
                                    'isFree': false,
                                  },
                                  'paymentType': 'repayment',
                                });
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
      children: [
        Container(
          width: ResponsiveValues.iconSizeL(context),
          height: ResponsiveValues.iconSizeL(context),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.telegramBlue.withValues(alpha: 0.2),
                AppColors.telegramPurple.withValues(alpha: 0.1)
              ],
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(icon,
              size: ResponsiveValues.iconSizeXS(context),
              color: AppColors.telegramBlue),
        ),
        SizedBox(width: ResponsiveValues.spacingM(context)),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodyMedium(context)
                .copyWith(color: AppColors.getTextSecondary(context)),
          ),
        ),
        Text(
          value,
          style: AppTextStyles.bodyMedium(context).copyWith(
            color: valueColor ?? AppColors.getTextPrimary(context),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Widget _buildSkeletonLoader() {
    return Center(
      child: AppCard.glass(
        child: Padding(
          padding: ResponsiveValues.cardPadding(context),
          child: Column(
            children: List.generate(
              5,
              (index) => Padding(
                padding:
                    EdgeInsets.only(bottom: ResponsiveValues.spacingL(context)),
                child: Row(
                  children: [
                    AppShimmer(
                      type: ShimmerType.circle,
                      customWidth: ResponsiveValues.iconSizeXL(context) * 1.5,
                      customHeight: ResponsiveValues.iconSizeXL(context) * 1.5,
                    ),
                    SizedBox(width: ResponsiveValues.spacingL(context)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AppShimmer(
                              type: ShimmerType.textLine, customHeight: 20),
                          SizedBox(height: ResponsiveValues.spacingS(context)),
                          const AppShimmer(
                              type: ShimmerType.textLine,
                              customWidth: 150,
                              customHeight: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionProvider = context.watch<SubscriptionProvider>();

    final activeSubscriptions = subscriptionProvider.activeSubscriptions;
    final expiredSubscriptions = subscriptionProvider.expiredSubscriptions;
    final allSubscriptions = subscriptionProvider.allSubscriptions;

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: CustomAppBar(
          title: AppStrings.mySubscriptions,
          subtitle: AppStrings.error,
          leading: AppButton.icon(
              icon: Icons.arrow_back_rounded, onPressed: () => context.pop()),
          showOfflineIndicator: _isOffline,
        ),
        body: Center(
          child: AppEmptyState.error(
            title: AppStrings.error,
            message: _errorMessage!,
            onRetry: _manualRefresh,
          ),
        ),
      );
    }

    if (subscriptionProvider.isLoading && !_hasCachedData) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: CustomAppBar(
          title: AppStrings.mySubscriptions,
          subtitle: AppStrings.loading,
          leading: AppButton.icon(
              icon: Icons.arrow_back_rounded, onPressed: () => context.pop()),
          showOfflineIndicator: _isOffline,
        ),
        body: Center(child: _buildSkeletonLoader()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: CustomAppBar(
        title: AppStrings.mySubscriptions,
        subtitle: _isRefreshing
            ? AppStrings.refreshing
            : (_isOffline
                ? AppStrings.offlineMode
                : AppStrings.manageSubscriptions),
        leading: AppButton.icon(
            icon: Icons.arrow_back_rounded, onPressed: () => context.pop()),
        showOfflineIndicator: _isOffline,
      ),
      body: RefreshIndicator(
        onRefresh: _manualRefresh,
        color: AppColors.telegramBlue,
        backgroundColor: AppColors.getSurface(context),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (_isOffline && _pendingCount > 0)
              SliverToBoxAdapter(
                child: Container(
                  margin: EdgeInsets.all(ResponsiveValues.spacingM(context)),
                  padding: ResponsiveValues.cardPadding(context),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.info.withValues(alpha: 0.2),
                        AppColors.info.withValues(alpha: 0.1)
                      ],
                    ),
                    borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusMedium(context)),
                    border: Border.all(
                        color: AppColors.info.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.schedule_rounded,
                          color: AppColors.info,
                          size: ResponsiveValues.iconSizeS(context)),
                      SizedBox(width: ResponsiveValues.spacingM(context)),
                      Expanded(
                        child: Text(
                          '$_pendingCount pending action${_pendingCount > 1 ? 's' : ''}',
                          style: AppTextStyles.bodySmall(context)
                              .copyWith(color: AppColors.info),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveValues.spacingL(context),
                vertical: ResponsiveValues.spacingL(context),
              ),
              sliver: SliverToBoxAdapter(
                child: Text(
                  _isOffline
                      ? AppStrings.offlineCachedSubscriptions
                      : AppStrings.yourActiveExpiredSubscriptions,
                  style: AppTextStyles.bodyMedium(context)
                      .copyWith(color: AppColors.getTextSecondary(context)),
                ),
              ),
            ),
            if (activeSubscriptions.isNotEmpty) ...[
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  ResponsiveValues.spacingL(context),
                  ResponsiveValues.spacingL(context),
                  ResponsiveValues.spacingL(context),
                  ResponsiveValues.spacingS(context),
                ),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppStrings.active,
                        style: AppTextStyles.titleLarge(context)
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveValues.spacingM(context),
                          vertical: ResponsiveValues.spacingXS(context),
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.telegramGreen.withValues(alpha: 0.2),
                              AppColors.telegramGreen.withValues(alpha: 0.1)
                            ],
                          ),
                          borderRadius: BorderRadius.circular(
                              ResponsiveValues.radiusFull(context)),
                        ),
                        child: Text(
                          '${activeSubscriptions.length}',
                          style: AppTextStyles.labelMedium(context).copyWith(
                              color: AppColors.telegramGreen,
                              fontWeight: FontWeight.w600),
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
                        horizontal: ResponsiveValues.spacingL(context)),
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
                        style: AppTextStyles.titleLarge(context)
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveValues.spacingM(context),
                          vertical: ResponsiveValues.spacingXS(context),
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.telegramRed.withValues(alpha: 0.2),
                              AppColors.telegramRed.withValues(alpha: 0.1)
                            ],
                          ),
                          borderRadius: BorderRadius.circular(
                              ResponsiveValues.radiusFull(context)),
                        ),
                        child: Text(
                          '${expiredSubscriptions.length}',
                          style: AppTextStyles.labelMedium(context).copyWith(
                              color: AppColors.telegramRed,
                              fontWeight: FontWeight.w600),
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
                        horizontal: ResponsiveValues.spacingL(context)),
                    child: _buildSubscriptionCard(expiredSubscriptions[index]),
                  ),
                  childCount: expiredSubscriptions.length,
                ),
              ),
            ],
            if (allSubscriptions.isEmpty && !subscriptionProvider.isLoading)
              SliverFillRemaining(
                child: Center(
                  child: _isOffline
                      ? AppEmptyState.offline(
                          message: AppStrings.noCachedSubscriptions,
                          onRetry: () {
                            setState(() => _isOffline = false);
                            _checkConnectivity();
                            _manualRefresh();
                          },
                          pendingCount: _pendingCount,
                        )
                      : AppEmptyState.noData(
                          dataType: AppStrings.subscriptions,
                          customMessage: AppStrings.noSubscriptionsYet,
                          onRefresh: () => context.go('/'),
                        ),
                ),
              ),
            if (subscriptionProvider.isLoading && allSubscriptions.isNotEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: AppShimmer(type: ShimmerType.circle),
                    ),
                  ),
                ),
              ),
            SliverToBoxAdapter(
                child: SizedBox(height: ResponsiveValues.spacingXXL(context))),
          ],
        ),
      ),
      floatingActionButton: allSubscriptions.isEmpty && !_isOffline
          ? FloatingActionButton(
              onPressed: () => context.go('/'),
              backgroundColor: AppColors.telegramBlue,
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              child: const Icon(Icons.explore_rounded),
            )
          : null,
    ).animate().fadeIn(duration: AppThemes.animationMedium);
  }
}

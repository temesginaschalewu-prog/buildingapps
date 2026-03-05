import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/subscription_model.dart';
import '../../providers/subscription_provider.dart';
import '../../services/connectivity_service.dart';
import '../../services/snackbar_service.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_shimmer.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../themes/app_themes.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/responsive.dart';
import '../../utils/responsive_values.dart';
import '../../utils/helpers.dart';
import '../../widgets/common/responsive_widgets.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen>
    with TickerProviderStateMixin {
  bool _isRefreshing = false;
  bool _isOffline = false;
  Timer? _refreshTimer;
  String _refreshSubtitle = '';
  StreamSubscription? _connectivitySubscription;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkConnectivity();
      _loadSubscriptions();
    });
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (mounted && !_isOffline) _loadSubscriptions(forceRefresh: true);
    });

    _setupConnectivityListener();
  }

  void _setupConnectivityListener() {
    final connectivityService = context.read<ConnectivityService>();
    _connectivitySubscription =
        connectivityService.onConnectivityChanged.listen((isOnline) {
      if (mounted) {
        setState(() => _isOffline = !isOnline);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    final connectivityService = context.read<ConnectivityService>();
    setState(() => _isOffline = !connectivityService.isOnline);
  }

  Future<void> _loadSubscriptions({bool forceRefresh = false}) async {
    final subscriptionProvider = context.read<SubscriptionProvider>();
    await subscriptionProvider.loadSubscriptions(
        forceRefresh: forceRefresh && !_isOffline);
  }

  Future<void> _manualRefresh() async {
    if (_isRefreshing) return;

    final connectivityService = context.read<ConnectivityService>();
    if (!connectivityService.isOnline) {
      setState(() => _isOffline = true);
      SnackbarService().showOffline(context);
      return;
    }

    setState(() {
      _isRefreshing = true;
      _refreshSubtitle = 'Refreshing...';
    });

    try {
      final subscriptionProvider = context.read<SubscriptionProvider>();
      await subscriptionProvider.loadSubscriptions(forceRefresh: true);
      setState(() => _isOffline = false);
      SnackbarService().showSuccess(context, 'Subscriptions refreshed');
    } catch (e) {
      SnackbarService().showError(context, 'Refresh failed: $e');
    } finally {
      setState(() {
        _isRefreshing = false;
        _refreshSubtitle = '';
      });
    }
  }

  Color _getStatusColor(String status) {
    return UiHelpers.getSubscriptionStatusColor(status);
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'active':
        return 'ACTIVE';
      case 'expiring_soon':
        return 'EXPIRING SOON';
      case 'expired':
        return 'EXPIRED';
      default:
        return status.toUpperCase();
    }
  }

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
                        'name': subscription.categoryName ?? 'Category',
                        'price': subscription.price,
                        'billing_cycle': subscription.billingCycle,
                        'isFree': false,
                      },
                      'paymentType': 'repayment',
                      'months': subscription.billingCycle == 'semester' ? 4 : 1,
                      'duration_text': subscription.billingCycle == 'semester'
                          ? '4 months'
                          : '1 month',
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
                              statusColor.withValues(alpha: 0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(
                            ResponsiveValues.radiusMedium(context),
                          ),
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
                      const ResponsiveSizedBox(width: AppSpacing.l),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subscription.categoryName ?? 'Unknown Category',
                              style:
                                  AppTextStyles.titleMedium(context).copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const ResponsiveSizedBox(height: AppSpacing.xs),
                            Text(
                              subscription.billingCycle == 'monthly'
                                  ? 'Monthly Subscription'
                                  : 'Semester Subscription',
                              style: AppTextStyles.bodySmall(context).copyWith(
                                color: AppColors.getTextSecondary(context),
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
                  const ResponsiveSizedBox(height: AppSpacing.l),
                  if (isActive && !isExpired && isExpiringSoon)
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Expires in $daysRemaining days',
                              style: AppTextStyles.labelSmall(context).copyWith(
                                color: AppColors.getTextSecondary(context),
                              ),
                            ),
                            Text(
                              '${((1 - progressValue) * 100).toInt()}% used',
                              style: AppTextStyles.labelSmall(context).copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const ResponsiveSizedBox(height: AppSpacing.s),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(
                            ResponsiveValues.radiusFull(context),
                          ),
                          child: LinearProgressIndicator(
                            value: progressValue.clamp(0.0, 1.0),
                            backgroundColor: AppColors.getSurface(context)
                                .withValues(alpha: 0.3),
                            color: statusColor,
                            minHeight:
                                ResponsiveValues.progressBarHeight(context),
                          ),
                        ),
                        const ResponsiveSizedBox(height: AppSpacing.l),
                      ],
                    ),
                  AppCard.glass(
                    child: Padding(
                      padding: ResponsiveValues.cardPadding(context),
                      child: Column(
                        children: [
                          _buildInfoRow(
                            icon: Icons.calendar_today_rounded,
                            label: 'Start Date',
                            value: _formatDate(subscription.startDate),
                          ),
                          const ResponsiveSizedBox(height: AppSpacing.m),
                          _buildInfoRow(
                            icon: isExpired
                                ? Icons.event_busy_rounded
                                : Icons.calendar_month_rounded,
                            label: 'Expiry Date',
                            value: _formatDate(subscription.expiryDate),
                            valueColor: isExpired ? statusColor : null,
                          ),
                          const ResponsiveSizedBox(height: AppSpacing.m),
                          _buildInfoRow(
                            icon: Icons.repeat_rounded,
                            label: 'Billing Cycle',
                            value: subscription.billingCycle == 'monthly'
                                ? 'Monthly'
                                : 'Semester',
                          ),
                          if (subscription.price != null) ...[
                            const ResponsiveSizedBox(height: AppSpacing.m),
                            _buildInfoRow(
                              icon: Icons.payments_rounded,
                              label: 'Price',
                              value:
                                  '${subscription.price!.toStringAsFixed(0)} ETB',
                              valueColor: AppColors.telegramBlue,
                            ),
                          ],
                          if (isActive && !isExpired) ...[
                            const ResponsiveSizedBox(height: AppSpacing.m),
                            _buildInfoRow(
                              icon: Icons.timer_rounded,
                              label: 'Days Remaining',
                              value: '$daysRemaining days',
                              valueColor: isExpiringSoon ? statusColor : null,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if ((isExpired || isExpiringSoon) && !_isOffline) ...[
                    const ResponsiveSizedBox(height: AppSpacing.xl),
                    SizedBox(
                      width: double.infinity,
                      child: isExpired
                          ? AppButton.danger(
                              label: 'Renew Now',
                              onPressed: () {
                                context.push('/payment', extra: {
                                  'category': {
                                    'id': subscription.categoryId,
                                    'name':
                                        subscription.categoryName ?? 'Category',
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
                              label: 'Extend Now',
                              onPressed: () {
                                context.push('/payment', extra: {
                                  'category': {
                                    'id': subscription.categoryId,
                                    'name':
                                        subscription.categoryName ?? 'Category',
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
    ).animate().fadeIn(duration: AppThemes.animationDurationMedium).slideY(
        begin: 0.1, end: 0, duration: AppThemes.animationDurationMedium);
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
                AppColors.telegramPurple.withValues(alpha: 0.1),
              ],
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: ResponsiveValues.iconSizeXS(context),
            color: AppColors.telegramBlue,
          ),
        ),
        const ResponsiveSizedBox(width: AppSpacing.m),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodyMedium(context).copyWith(
              color: AppColors.getTextSecondary(context),
            ),
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
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: ResponsiveValues.spacingL(context),
      ),
      child: AppCard.glass(
        child: Padding(
          padding: ResponsiveValues.cardPadding(context),
          child: Column(
            children: List.generate(
              5,
              (index) => Padding(
                padding: EdgeInsets.only(
                  bottom: ResponsiveValues.spacingL(context),
                ),
                child: Row(
                  children: [
                    AppShimmer(
                      type: ShimmerType.circle,
                      customWidth: ResponsiveValues.iconSizeXL(context) * 1.5,
                      customHeight: ResponsiveValues.iconSizeXL(context) * 1.5,
                    ),
                    const ResponsiveSizedBox(width: AppSpacing.l),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppShimmer(
                              type: ShimmerType.textLine, customHeight: 20),
                          ResponsiveSizedBox(height: AppSpacing.s),
                          AppShimmer(
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

  Widget _buildMobileLayout(SubscriptionProvider subscriptionProvider) {
    final activeSubscriptions = subscriptionProvider.activeSubscriptions;
    final expiredSubscriptions = subscriptionProvider.expiredSubscriptions;
    final allSubscriptions = subscriptionProvider.allSubscriptions;

    if (subscriptionProvider.isLoading && allSubscriptions.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          leading: AppButton.icon(
            icon: Icons.arrow_back_rounded,
            onPressed: () => context.pop(),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Center(child: _buildSkeletonLoader()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: RefreshIndicator(
        onRefresh: _manualRefresh,
        color: AppColors.telegramBlue,
        backgroundColor: AppColors.getSurface(context),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(
                  left: ResponsiveValues.spacingL(context),
                  right: ResponsiveValues.spacingL(context),
                  top: MediaQuery.of(context).padding.top +
                      ResponsiveValues.spacingM(context),
                  bottom: ResponsiveValues.spacingS(context),
                ),
                child: Row(
                  children: [
                    AppButton.icon(
                      icon: Icons.arrow_back_rounded,
                      onPressed: () => context.pop(),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'My Subscriptions',
                            style:
                                AppTextStyles.headlineSmall(context).copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isRefreshing
                                ? 'Refreshing...'
                                : (_isOffline
                                    ? 'Offline mode'
                                    : 'Manage your subscriptions'),
                            style: AppTextStyles.bodySmall(context).copyWith(
                              color: AppColors.getTextSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveValues.spacingL(context),
                  vertical: ResponsiveValues.spacingL(context),
                ),
                child: Text(
                  _isOffline
                      ? 'Offline mode - showing cached subscriptions'
                      : 'Your active and expired subscriptions',
                  style: AppTextStyles.bodyMedium(context).copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
              ),
            ),
            if (_isOffline && allSubscriptions.isNotEmpty)
              SliverToBoxAdapter(
                child: Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: ResponsiveValues.spacingL(context),
                  ),
                  padding: ResponsiveValues.cardPadding(context),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.telegramYellow.withValues(alpha: 0.2),
                        AppColors.telegramYellow.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(
                      ResponsiveValues.radiusMedium(context),
                    ),
                    border: Border.all(
                      color: AppColors.telegramYellow.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_off_rounded,
                          color: AppColors.telegramYellow, size: 20),
                      const ResponsiveSizedBox(width: AppSpacing.m),
                      Expanded(
                        child: Text(
                          'Offline mode - showing cached subscriptions',
                          style: AppTextStyles.bodySmall(context).copyWith(
                            color: AppColors.telegramYellow,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (activeSubscriptions.isNotEmpty) ...[
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  ResponsiveValues.spacingL(context),
                  ResponsiveValues.spacingXL(context),
                  ResponsiveValues.spacingL(context),
                  ResponsiveValues.spacingS(context),
                ),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Active',
                        style: AppTextStyles.titleLarge(context).copyWith(
                          fontWeight: FontWeight.w600,
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
                              AppColors.telegramGreen.withValues(alpha: 0.2),
                              AppColors.telegramGreen.withValues(alpha: 0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(
                            ResponsiveValues.radiusFull(context),
                          ),
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
                  (context, index) =>
                      _buildSubscriptionCard(activeSubscriptions[index]),
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
                        'Expired',
                        style: AppTextStyles.titleLarge(context).copyWith(
                          fontWeight: FontWeight.w600,
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
                              AppColors.telegramRed.withValues(alpha: 0.2),
                              AppColors.telegramRed.withValues(alpha: 0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(
                            ResponsiveValues.radiusFull(context),
                          ),
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
                  (context, index) =>
                      _buildSubscriptionCard(expiredSubscriptions[index]),
                  childCount: expiredSubscriptions.length,
                ),
              ),
            ],
            if (allSubscriptions.isEmpty && !subscriptionProvider.isLoading)
              SliverFillRemaining(
                child: Center(
                  child: _isOffline
                      ? AppEmptyState.offline(
                          message: 'No cached subscriptions available.',
                          onRetry: () {
                            setState(() => _isOffline = false);
                            _checkConnectivity();
                            _manualRefresh();
                          },
                        )
                      : AppEmptyState.noData(
                          dataType: 'subscriptions',
                          customMessage:
                              'You don\'t have any subscriptions yet.\nBrowse categories to get started.',
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
            const SliverToBoxAdapter(
              child: ResponsiveSizedBox(height: AppSpacing.xxl),
            ),
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
    );
  }

  Widget _buildDesktopLayout(SubscriptionProvider subscriptionProvider) {
    return _buildMobileLayout(subscriptionProvider);
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionProvider = context.watch<SubscriptionProvider>();

    return ResponsiveLayout(
      mobile: _buildMobileLayout(subscriptionProvider),
      tablet: _buildDesktopLayout(subscriptionProvider),
      desktop: _buildDesktopLayout(subscriptionProvider),
    );
  }
}

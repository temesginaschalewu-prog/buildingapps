import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:familyacademyclient/utils/helpers.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import 'package:familyacademyclient/themes/app_themes.dart';
import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';
import 'package:shimmer/shimmer.dart';
import '../../providers/subscription_provider.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/empty_state.dart';
import '../../models/subscription_model.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen>
    with TickerProviderStateMixin {
  bool _isRefreshing = false;
  Timer? _refreshTimer;
  late AnimationController _pulseAnimationController;

  @override
  void initState() {
    super.initState();

    _pulseAnimationController =
        AnimationController(vsync: this, duration: 1.seconds)
          ..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSubscriptions());
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (mounted) _loadSubscriptions(forceRefresh: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _pulseAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadSubscriptions({bool forceRefresh = false}) async {
    final subscriptionProvider =
        Provider.of<SubscriptionProvider>(context, listen: false);
    await subscriptionProvider.loadSubscriptions(forceRefresh: forceRefresh);
  }

  Future<void> _refreshData() async {
    setState(() => _isRefreshing = true);

    try {
      final subscriptionProvider =
          Provider.of<SubscriptionProvider>(context, listen: false);
      await subscriptionProvider.loadSubscriptions(forceRefresh: true);
      showTopSnackBar(context, 'Subscriptions refreshed');
    } catch (e) {
      showTopSnackBar(context, 'Refresh failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Widget _buildGlassContainer({required Widget child}) {
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
                AppColors.getCard(context).withValues(alpha: 0.4),
                AppColors.getCard(context).withValues(alpha: 0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.telegramBlue.withValues(alpha: 0.2),
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildSubscriptionCard(Subscription subscription) {
    final isActive = subscription.isActive;
    final isExpired = subscription.isExpired;
    final isExpiringSoon = subscription.isExpiringSoon;

    final status =
        isExpired ? 'expired' : (isExpiringSoon ? 'expiring_soon' : 'active');
    final statusColor = AppColors.getStatusColor(status, context);
    final statusBgColor = AppColors.getStatusBackground(status, context);

    final daysRemaining = subscription.daysRemaining;
    final progressValue = daysRemaining / 30;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: ScreenSize.responsiveValue(
            context: context, mobile: 16, tablet: 20, desktop: 24),
        vertical: 8,
      ),
      child: _buildGlassContainer(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: (isExpired || isExpiringSoon)
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
            borderRadius: BorderRadius.circular(24),
            splashColor: AppColors.telegramBlue.withValues(alpha: 0.1),
            highlightColor: Colors.transparent,
            child: Padding(
              padding: EdgeInsets.all(ScreenSize.responsiveValue(
                  context: context, mobile: 16, tablet: 20, desktop: 24)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              statusColor.withValues(alpha: 0.2),
                              statusColor.withValues(alpha: 0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: statusColor, width: 1.5),
                        ),
                        child: Icon(
                            _getCategoryIcon(subscription.categoryName ?? ''),
                            color: statusColor,
                            size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subscription.categoryName ?? 'Unknown Category',
                              style: AppTextStyles.titleMedium.copyWith(
                                color: AppColors.getTextPrimary(context),
                                fontSize: ScreenSize.responsiveFontSize(
                                    context: context,
                                    mobile: 16,
                                    tablet: 18,
                                    desktop: 20),
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subscription.billingCycle == 'monthly'
                                  ? 'Monthly Subscription'
                                  : 'Semester Subscription',
                              style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.getTextSecondary(context)),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              statusColor.withValues(alpha: 0.2),
                              statusColor.withValues(alpha: 0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: statusColor),
                        ),
                        child: Text(
                          _getStatusText(status),
                          style: AppTextStyles.statusBadge.copyWith(
                            color: statusColor,
                            fontSize: ScreenSize.responsiveFontSize(
                                context: context,
                                mobile: 10,
                                tablet: 11,
                                desktop: 12),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (isActive && !isExpired && isExpiringSoon)
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Expires in $daysRemaining days',
                                style: AppTextStyles.labelSmall.copyWith(
                                    color:
                                        AppColors.getTextSecondary(context))),
                            Text('${((1 - progressValue) * 100).toInt()}% used',
                                style: AppTextStyles.labelSmall.copyWith(
                                    color: statusColor,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: LinearProgressIndicator(
                            value: progressValue.clamp(0.0, 1.0),
                            backgroundColor:
                                AppColors.getSurface(context).withValues(alpha: 0.3),
                            color: statusColor,
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  _buildGlassContainer(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          _buildInfoRow(
                              icon: Icons.calendar_today_rounded,
                              label: 'Start Date',
                              value: _formatDate(subscription.startDate)),
                          const SizedBox(height: 12),
                          _buildInfoRow(
                              icon: isExpired
                                  ? Icons.event_busy_rounded
                                  : Icons.calendar_month_rounded,
                              label: 'Expiry Date',
                              value: _formatDate(subscription.expiryDate),
                              valueColor: isExpired ? statusColor : null),
                          const SizedBox(height: 12),
                          _buildInfoRow(
                              icon: Icons.repeat_rounded,
                              label: 'Billing Cycle',
                              value: subscription.billingCycle == 'monthly'
                                  ? 'Monthly'
                                  : 'Semester'),
                          if (subscription.price != null) ...[
                            const SizedBox(height: 12),
                            _buildInfoRow(
                                icon: Icons.payments_rounded,
                                label: 'Price',
                                value:
                                    '${subscription.price!.toStringAsFixed(0)} ETB',
                                valueColor: AppColors.telegramBlue),
                          ],
                          if (isActive && !isExpired) ...[
                            const SizedBox(height: 12),
                            _buildInfoRow(
                                icon: Icons.timer_rounded,
                                label: 'Days Remaining',
                                value: '$daysRemaining days',
                                valueColor:
                                    isExpiringSoon ? statusColor : null),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (isExpired || isExpiringSoon) ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isExpired
                                ? [
                                    AppColors.telegramRed,
                                    AppColors.telegramOrange
                                  ]
                                : [
                                    AppColors.telegramBlue,
                                    AppColors.telegramPurple
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(
                              AppThemes.borderRadiusMedium),
                          boxShadow: [
                            BoxShadow(
                              color: statusColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            context.push('/payment', extra: {
                              'category': {
                                'id': subscription.categoryId,
                                'name': subscription.categoryName ?? 'Category',
                                'price': subscription.price,
                                'billing_cycle': subscription.billingCycle,
                                'isFree': false,
                              },
                              'paymentType': 'repayment',
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    AppThemes.borderRadiusMedium)),
                          ),
                          child: Text(isExpired ? 'Renew Now' : 'Extend Now',
                              style: AppTextStyles.buttonMedium
                                  .copyWith(color: Colors.white)),
                        ),
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

  Widget _buildInfoRow(
      {required IconData icon,
      required String label,
      required String value,
      Color? valueColor}) {
    return Row(
      children: [
        Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.telegramBlue.withValues(alpha: 0.2),
                    AppColors.telegramPurple.withValues(alpha: 0.1),
                  ],
                ),
                shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: AppColors.telegramBlue)),
        const SizedBox(width: 12),
        Expanded(
            child: Text(label,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.getTextSecondary(context)))),
        Text(value,
            style: AppTextStyles.bodyMedium.copyWith(
                color: valueColor ?? AppColors.getTextPrimary(context),
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Widget _buildExpiringSoonBanner(int count) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: ScreenSize.responsiveValue(
            context: context, mobile: 16, tablet: 20, desktop: 24),
        vertical: 8,
      ),
      child: _buildGlassContainer(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              AnimatedBuilder(
                animation: _pulseAnimationController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1 + _pulseAnimationController.value * 0.1,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.statusPending.withValues(alpha: 0.2),
                            AppColors.statusPending.withValues(alpha: 0.1),
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.warning_amber_rounded,
                          color: AppColors.statusPending, size: 24),
                    ),
                  );
                },
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Renewal Needed',
                        style: AppTextStyles.titleSmall.copyWith(
                            color: AppColors.statusPending,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                        count == 1
                            ? '1 subscription is expiring soon'
                            : '$count subscriptions are expiring soon',
                        style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.getTextSecondary(context))),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: AppColors.statusPending),
            ],
          ),
        ),
      ),
    ).animate().shake(duration: 1.seconds, delay: 500.ms);
  }

  Widget _buildSkeletonLoader() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: _buildGlassContainer(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: List.generate(
                5,
                (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          Shimmer.fromColors(
                            baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
                            highlightColor: Colors.grey[100]!.withValues(alpha: 0.6),
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Shimmer.fromColors(
                                  baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
                                  highlightColor:
                                      Colors.grey[100]!.withValues(alpha: 0.6),
                                  child: Container(
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Shimmer.fromColors(
                                  baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
                                  highlightColor:
                                      Colors.grey[100]!.withValues(alpha: 0.6),
                                  child: Container(
                                    height: 16,
                                    width: 100,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(SubscriptionProvider subscriptionProvider) {
    final activeSubscriptions = subscriptionProvider.activeSubscriptions;
    final expiredSubscriptions = subscriptionProvider.expiredSubscriptions;
    final expiringSoonSubscriptions =
        subscriptionProvider.expiringSoonSubscriptions;
    final allSubscriptions = subscriptionProvider.allSubscriptions;

    if (subscriptionProvider.isLoading && allSubscriptions.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: _buildAppBar(),
        body: _buildSkeletonLoader(),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: _buildAppBar(),
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(ScreenSize.responsiveValue(
                  context: context, mobile: 16, tablet: 20, desktop: 24)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Subscriptions',
                      style: AppTextStyles.displaySmall
                          .copyWith(color: AppColors.getTextPrimary(context))),
                  const SizedBox(height: 8),
                  Text('Manage your course access and renewals',
                      style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.getTextSecondary(context))),
                ],
              ),
            ),
          ),
          if (expiringSoonSubscriptions.isNotEmpty)
            SliverToBoxAdapter(
                child:
                    _buildExpiringSoonBanner(expiringSoonSubscriptions.length)),
          if (activeSubscriptions.isNotEmpty) ...[
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                ScreenSize.responsiveValue(
                    context: context, mobile: 16, tablet: 20, desktop: 24),
                24,
                ScreenSize.responsiveValue(
                    context: context, mobile: 16, tablet: 20, desktop: 24),
                8,
              ),
              sliver: SliverToBoxAdapter(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Active',
                        style: AppTextStyles.titleLarge.copyWith(
                            color: AppColors.getTextPrimary(context),
                            fontWeight: FontWeight.w600)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.telegramGreen.withValues(alpha: 0.2),
                              AppColors.telegramGreen.withValues(alpha: 0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text('${activeSubscriptions.length}',
                          style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.telegramGreen,
                              fontWeight: FontWeight.w600)),
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
                ScreenSize.responsiveValue(
                    context: context, mobile: 16, tablet: 20, desktop: 24),
                32,
                ScreenSize.responsiveValue(
                    context: context, mobile: 16, tablet: 20, desktop: 24),
                8,
              ),
              sliver: SliverToBoxAdapter(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Expired',
                        style: AppTextStyles.titleLarge.copyWith(
                            color: AppColors.getTextPrimary(context),
                            fontWeight: FontWeight.w600)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.telegramRed.withValues(alpha: 0.2),
                              AppColors.telegramRed.withValues(alpha: 0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text('${expiredSubscriptions.length}',
                          style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.telegramRed,
                              fontWeight: FontWeight.w600)),
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
                child: EmptyState(
                  lottieAsset: 'assets/lottie/empty_subscriptions.json',
                  title: 'No Subscriptions',
                  message:
                      'You don\'t have any subscriptions yet.\nBrowse categories to get started.',
                  actionText: 'Browse Categories',
                  onAction: () => context.go('/'),
                  type: EmptyStateType.noData,
                ),
              ),
            ),
          if (subscriptionProvider.isLoading && allSubscriptions.isNotEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                    child: LoadingIndicator(
                        size: 32,
                        color: AppColors.telegramBlue)),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
      floatingActionButton: allSubscriptions.isEmpty
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

  AppBar _buildAppBar() {
    return AppBar(
      title: Text('My Subscriptions',
          style: AppTextStyles.appBarTitle
              .copyWith(color: AppColors.getTextPrimary(context))),
      backgroundColor: AppColors.getBackground(context),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      actions: [
        IconButton(
          icon: _isRefreshing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.telegramBlue))
              : Icon(Icons.refresh_rounded,
                  color: AppColors.getTextSecondary(context)),
          onPressed: _isRefreshing ? null : _refreshData,
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(SubscriptionProvider subscriptionProvider) {
    final activeSubscriptions = subscriptionProvider.activeSubscriptions;
    final expiredSubscriptions = subscriptionProvider.expiredSubscriptions;
    final expiringSoonSubscriptions =
        subscriptionProvider.expiringSoonSubscriptions;
    final allSubscriptions = subscriptionProvider.allSubscriptions;

    if (subscriptionProvider.isLoading && allSubscriptions.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: _buildAppBar(),
        body: Center(child: _buildSkeletonLoader()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: AdaptiveContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: ScreenSize.responsiveValue(
                        context: context, mobile: 16, tablet: 20, desktop: 24)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Subscriptions',
                        style: AppTextStyles.displaySmall.copyWith(
                            color: AppColors.getTextPrimary(context))),
                    const SizedBox(height: 8),
                    Text('Manage your course subscriptions and renewals',
                        style: AppTextStyles.bodyLarge.copyWith(
                            color: AppColors.getTextSecondary(context))),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              if (expiringSoonSubscriptions.isNotEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: ScreenSize.responsiveValue(
                          context: context,
                          mobile: 16,
                          tablet: 20,
                          desktop: 24)),
                  child: _buildExpiringSoonBanner(
                      expiringSoonSubscriptions.length),
                ),
              if (expiringSoonSubscriptions.isNotEmpty)
                const SizedBox(height: 32),
              if (activeSubscriptions.isNotEmpty) ...[
                Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: ScreenSize.responsiveValue(
                          context: context,
                          mobile: 16,
                          tablet: 20,
                          desktop: 24)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Active Subscriptions',
                          style: AppTextStyles.headlineMedium.copyWith(
                              color: AppColors.getTextPrimary(context),
                              fontWeight: FontWeight.w600)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.telegramGreen.withValues(alpha: 0.2),
                                AppColors.telegramGreen.withValues(alpha: 0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20)),
                        child: Text('${activeSubscriptions.length} active',
                            style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.telegramGreen,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ...activeSubscriptions.map((subscription) => Padding(
                      padding: EdgeInsets.only(
                        bottom: 16,
                        left: ScreenSize.responsiveValue(
                            context: context,
                            mobile: 16,
                            tablet: 20,
                            desktop: 24),
                        right: ScreenSize.responsiveValue(
                            context: context,
                            mobile: 16,
                            tablet: 20,
                            desktop: 24),
                      ),
                      child: _buildSubscriptionCard(subscription),
                    )),
                const SizedBox(height: 32),
              ],
              if (expiredSubscriptions.isNotEmpty) ...[
                Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: ScreenSize.responsiveValue(
                          context: context,
                          mobile: 16,
                          tablet: 20,
                          desktop: 24)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Expired Subscriptions',
                          style: AppTextStyles.headlineMedium.copyWith(
                              color: AppColors.getTextPrimary(context),
                              fontWeight: FontWeight.w600)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.telegramRed.withValues(alpha: 0.2),
                                AppColors.telegramRed.withValues(alpha: 0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20)),
                        child: Text('${expiredSubscriptions.length} expired',
                            style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.telegramRed,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ...expiredSubscriptions.map((subscription) => Padding(
                      padding: EdgeInsets.only(
                        bottom: 16,
                        left: ScreenSize.responsiveValue(
                            context: context,
                            mobile: 16,
                            tablet: 20,
                            desktop: 24),
                        right: ScreenSize.responsiveValue(
                            context: context,
                            mobile: 16,
                            tablet: 20,
                            desktop: 24),
                      ),
                      child: _buildSubscriptionCard(subscription),
                    )),
                const SizedBox(height: 32),
              ],
              if (allSubscriptions.isEmpty && !subscriptionProvider.isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 64),
                  child: Center(
                    child: EmptyState(
                      lottieAsset: 'assets/lottie/empty_subscriptions.json',
                      title: 'No Subscriptions Found',
                      message:
                          'You don\'t have any active subscriptions.\nBrowse categories to start learning.',
                      actionText: 'Browse Categories',
                      onAction: () => context.go('/'),
                      type: EmptyStateType.noData,
                    ),
                  ),
                ),
              if (subscriptionProvider.isLoading && allSubscriptions.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                      child: LoadingIndicator(
                          size: 40,
                          color: AppColors.telegramBlue)),
                ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
      floatingActionButton: allSubscriptions.isEmpty
          ? FloatingActionButton.extended(
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.explore_rounded, color: Colors.white),
              label: Text('Browse Categories',
                  style:
                      AppTextStyles.buttonMedium.copyWith(color: Colors.white)),
              backgroundColor: AppColors.telegramBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppThemes.borderRadiusLarge)),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context);

    return ResponsiveLayout(
      mobile: _buildMobileLayout(subscriptionProvider),
      tablet: _buildDesktopLayout(subscriptionProvider),
      desktop: _buildDesktopLayout(subscriptionProvider),
    );
  }
}

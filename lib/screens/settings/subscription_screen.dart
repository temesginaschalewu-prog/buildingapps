import 'dart:async';
import 'dart:ui';
import 'package:familyacademyclient/services/user_session.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:familyacademyclient/utils/helpers.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import 'package:familyacademyclient/utils/responsive_values.dart';
import 'package:familyacademyclient/themes/app_themes.dart';
import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';
import 'package:shimmer/shimmer.dart';
import '../../providers/subscription_provider.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/empty_state.dart';
import '../../models/subscription_model.dart';
import '../../widgets/common/responsive_widgets.dart';
import '../../widgets/common/app_bar.dart';

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
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Widget _buildGlassContainer({required Widget child}) {
    return ClipRRect(
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
            borderRadius:
                BorderRadius.circular(ResponsiveValues.radiusXLarge(context)),
            border: Border.all(
              color: AppColors.telegramBlue.withValues(alpha: 0.2),
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildGradientButton({
    required String label,
    required VoidCallback? onPressed,
    required List<Color> gradient,
    bool isLoading = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: onPressed != null ? LinearGradient(colors: gradient) : null,
        borderRadius:
            BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
        boxShadow: onPressed != null
            ? [
                BoxShadow(
                  color: gradient.first.withValues(alpha: 0.3),
                  blurRadius: ResponsiveValues.spacingS(context),
                  offset: Offset(0, ResponsiveValues.spacingXS(context)),
                ),
              ]
            : null,
      ),
      child: Material(
        color: onPressed != null ? Colors.transparent : Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius:
              BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: ResponsiveValues.spacingL(context),
            ),
            alignment: Alignment.center,
            child: isLoading
                ? SizedBox(
                    width: ResponsiveValues.iconSizeM(context),
                    height: ResponsiveValues.iconSizeM(context),
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : ResponsiveText(
                    label,
                    style: AppTextStyles.buttonMedium(context).copyWith(
                      color: onPressed != null
                          ? Colors.white
                          : AppColors.getTextSecondary(context),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _checkConnectivity() async {
    final hasConnection = await hasInternetConnection();
    if (!hasConnection) {
      setState(() => _isOffline = true);
      showOfflineMessage(context);
    }
  }

  Future<void> _loadSubscriptions({bool forceRefresh = false}) async {
    final subscriptionProvider =
        Provider.of<SubscriptionProvider>(context, listen: false);
    await subscriptionProvider.loadSubscriptions(
        forceRefresh: forceRefresh && !_isOffline);
  }

  Future<void> _manualRefresh() async {
    if (_isRefreshing) return;

    final hasConnection = await hasInternetConnection();
    if (!hasConnection) {
      setState(() => _isOffline = true);
      showTopSnackBar(context, 'You are offline. Using cached data.',
          isError: true);
      return;
    }

    setState(() {
      _isRefreshing = true;
      _refreshSubtitle = 'Refreshing...';
    });

    try {
      final subscriptionProvider =
          Provider.of<SubscriptionProvider>(context, listen: false);
      await subscriptionProvider.loadSubscriptions(forceRefresh: true);
      setState(() => _isOffline = false);
      showTopSnackBar(context, 'Subscriptions refreshed');
    } catch (e) {
      showTopSnackBar(context, 'Refresh failed: $e', isError: true);
    } finally {
      setState(() {
        _isRefreshing = false;
        _refreshSubtitle = '';
      });
    }
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
        horizontal: ResponsiveValues.spacingL(context),
        vertical: ResponsiveValues.spacingS(context),
      ),
      child: _buildGlassContainer(
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
              child: ResponsiveColumn(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ResponsiveRow(
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
                          child: ResponsiveIcon(
                            _getCategoryIcon(subscription.categoryName ?? ''),
                            size: ResponsiveValues.iconSizeL(context),
                            color: statusColor,
                          ),
                        ),
                      ),
                      ResponsiveSizedBox(width: AppSpacing.l),
                      Expanded(
                        child: ResponsiveColumn(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ResponsiveText(
                              subscription.categoryName ?? 'Unknown Category',
                              style:
                                  AppTextStyles.titleMedium(context).copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            ResponsiveSizedBox(height: AppSpacing.xs),
                            ResponsiveText(
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
                        child: ResponsiveText(
                          _getStatusText(status),
                          style: AppTextStyles.statusBadge(context).copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  ResponsiveSizedBox(height: AppSpacing.l),
                  if (isActive && !isExpired && isExpiringSoon)
                    ResponsiveColumn(
                      children: [
                        ResponsiveRow(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ResponsiveText(
                              'Expires in $daysRemaining days',
                              style: AppTextStyles.labelSmall(context).copyWith(
                                color: AppColors.getTextSecondary(context),
                              ),
                            ),
                            ResponsiveText(
                              '${((1 - progressValue) * 100).toInt()}% used',
                              style: AppTextStyles.labelSmall(context).copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        ResponsiveSizedBox(height: AppSpacing.s),
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
                        ResponsiveSizedBox(height: AppSpacing.l),
                      ],
                    ),
                  _buildGlassContainer(
                    child: Padding(
                      padding: ResponsiveValues.cardPadding(context),
                      child: ResponsiveColumn(
                        children: [
                          _buildInfoRow(
                            icon: Icons.calendar_today_rounded,
                            label: 'Start Date',
                            value: _formatDate(subscription.startDate),
                          ),
                          ResponsiveSizedBox(height: AppSpacing.m),
                          _buildInfoRow(
                            icon: isExpired
                                ? Icons.event_busy_rounded
                                : Icons.calendar_month_rounded,
                            label: 'Expiry Date',
                            value: _formatDate(subscription.expiryDate),
                            valueColor: isExpired ? statusColor : null,
                          ),
                          ResponsiveSizedBox(height: AppSpacing.m),
                          _buildInfoRow(
                            icon: Icons.repeat_rounded,
                            label: 'Billing Cycle',
                            value: subscription.billingCycle == 'monthly'
                                ? 'Monthly'
                                : 'Semester',
                          ),
                          if (subscription.price != null) ...[
                            ResponsiveSizedBox(height: AppSpacing.m),
                            _buildInfoRow(
                              icon: Icons.payments_rounded,
                              label: 'Price',
                              value:
                                  '${subscription.price!.toStringAsFixed(0)} ETB',
                              valueColor: AppColors.telegramBlue,
                            ),
                          ],
                          if (isActive && !isExpired) ...[
                            ResponsiveSizedBox(height: AppSpacing.m),
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
                    ResponsiveSizedBox(height: AppSpacing.xl),
                    SizedBox(
                      width: double.infinity,
                      child: _buildGradientButton(
                        label: isExpired ? 'Renew Now' : 'Extend Now',
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
                        gradient: isExpired
                            ? [AppColors.telegramRed, AppColors.telegramOrange]
                            : AppColors.blueGradient,
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

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return ResponsiveRow(
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
        ResponsiveSizedBox(width: AppSpacing.m),
        Expanded(
          child: ResponsiveText(
            label,
            style: AppTextStyles.bodyMedium(context).copyWith(
              color: AppColors.getTextSecondary(context),
            ),
          ),
        ),
        ResponsiveText(
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
      child: _buildGlassContainer(
        child: Padding(
          padding: ResponsiveValues.cardPadding(context),
          child: ResponsiveColumn(
            children: List.generate(
              5,
              (index) => Padding(
                padding: EdgeInsets.only(
                  bottom: ResponsiveValues.spacingL(context),
                ),
                child: ResponsiveRow(
                  children: [
                    Shimmer.fromColors(
                      baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
                      highlightColor: Colors.grey[100]!.withValues(alpha: 0.6),
                      child: Container(
                        width: ResponsiveValues.iconSizeXL(context) * 1.5,
                        height: ResponsiveValues.iconSizeXL(context) * 1.5,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    ResponsiveSizedBox(width: AppSpacing.l),
                    Expanded(
                      child: ResponsiveColumn(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Shimmer.fromColors(
                            baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
                            highlightColor:
                                Colors.grey[100]!.withValues(alpha: 0.6),
                            child: Container(
                              height: ResponsiveValues.spacingXL(context),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(
                                  ResponsiveValues.radiusSmall(context),
                                ),
                              ),
                            ),
                          ),
                          ResponsiveSizedBox(height: AppSpacing.s),
                          Shimmer.fromColors(
                            baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
                            highlightColor:
                                Colors.grey[100]!.withValues(alpha: 0.6),
                            child: Container(
                              width: ResponsiveValues.spacingXXXL(context) * 2,
                              height: ResponsiveValues.spacingL(context),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(
                                  ResponsiveValues.radiusSmall(context),
                                ),
                              ),
                            ),
                          ),
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
          leading: IconButton(
            icon: ResponsiveIcon(
              Icons.arrow_back_rounded,
              color: AppColors.getTextPrimary(context),
            ),
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
            // App bar with back button
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
                    Container(
                      width: ResponsiveValues.appBarButtonSize(context),
                      height: ResponsiveValues.appBarButtonSize(context),
                      decoration: BoxDecoration(
                        color: AppColors.getSurface(context)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(
                          ResponsiveValues.radiusFull(context) / 2,
                        ),
                      ),
                      child: IconButton(
                        icon: ResponsiveIcon(
                          Icons.arrow_back_rounded,
                          size: ResponsiveValues.appBarIconSize(context),
                          color: AppColors.getTextPrimary(context),
                        ),
                        onPressed: () => context.pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
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
                child: ResponsiveText(
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
                  child: ResponsiveRow(
                    children: [
                      const Icon(Icons.wifi_off_rounded,
                          color: AppColors.telegramYellow, size: 20),
                      ResponsiveSizedBox(width: AppSpacing.m),
                      Expanded(
                        child: ResponsiveText(
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
                  child: ResponsiveRow(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ResponsiveText(
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
                        child: ResponsiveText(
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
                  child: ResponsiveRow(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ResponsiveText(
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
                        child: ResponsiveText(
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
                      ? OfflineState(
                          dataType: 'subscriptions',
                          message: 'No cached subscriptions available.',
                          onRetry: () {
                            setState(() => _isOffline = false);
                            _checkConnectivity();
                            _manualRefresh();
                          },
                        )
                      : EmptyState(
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
                      color: AppColors.telegramBlue,
                    ),
                  ),
                ),
              ),
            SliverToBoxAdapter(
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
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context);

    return ResponsiveLayout(
      mobile: _buildMobileLayout(subscriptionProvider),
      tablet: _buildDesktopLayout(subscriptionProvider),
      desktop: _buildDesktopLayout(subscriptionProvider),
    );
  }
}

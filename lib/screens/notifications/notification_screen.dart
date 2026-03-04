import 'dart:async';
import 'dart:ui';
import 'package:familyacademyclient/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:familyacademyclient/models/notification_model.dart'
    as AppNotification;
import 'package:familyacademyclient/services/user_session.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import 'package:familyacademyclient/utils/responsive_values.dart';
import 'package:shimmer/shimmer.dart';
import '../../providers/notification_provider.dart';
import '../../themes/app_themes.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/helpers.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/responsive_widgets.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  bool _isInitialLoad = true;
  bool _isRefreshing = false;
  bool _isLoadingMore = false;
  bool _isOffline = false;
  final ScrollController _scrollController = ScrollController();
  bool _showFAB = true;
  Timer? _scrollTimer;
  int _page = 1;
  final int _pageSize = 20;
  bool _hasMore = true;
  String? _currentUserId;

  late AnimationController _fabAnimationController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _fabAnimationController = AnimationController(
        vsync: this, duration: AppThemes.animationDurationMedium);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getCurrentUserId();
      _checkConnectivity();
      _loadNotifications();
    });

    _scrollController.addListener(() {
      if (_scrollTimer != null) _scrollTimer!.cancel();
      _scrollTimer = Timer(const Duration(milliseconds: 200), () {
        if (mounted) {
          final show = _scrollController.offset <= 100;
          if (_showFAB != show) {
            setState(() => _showFAB = show);
            if (show) {
              _fabAnimationController.forward();
            } else {
              _fabAnimationController.reverse();
            }
          }
        }
      });

      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        if (!_isLoadingMore && _hasMore && !_isRefreshing && !_isOffline) {
          _loadMoreNotifications();
        }
      }
    });
  }

  Future<void> _getCurrentUserId() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _currentUserId = authProvider.currentUser?.id.toString();
  }

  Future<void> _checkConnectivity() async {
    final hasConnection = await hasInternetConnection();
    if (!hasConnection) {
      setState(() => _isOffline = true);
      showOfflineMessage(context);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _scrollTimer?.cancel();
    _fabAnimationController.dispose();
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
    required VoidCallback onPressed,
    required List<Color> gradient,
    IconData? icon,
  }) {
    return Container(
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
            child: ResponsiveRow(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: ResponsiveValues.iconSizeS(context),
                    color: Colors.white,
                  ),
                  ResponsiveSizedBox(width: AppSpacing.s),
                ],
                ResponsiveText(
                  label,
                  style: AppTextStyles.labelLarge(context).copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Shimmer.fromColors(
          baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
          highlightColor: Colors.grey[100]!.withValues(alpha: 0.6),
          child: Container(
            width: ResponsiveValues.spacingXXXL(context) * 3,
            height: ResponsiveValues.spacingXL(context),
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
      ),
      body: ListView.builder(
        padding: ResponsiveValues.screenPadding(context),
        itemCount: 5,
        itemBuilder: (context, index) => Padding(
          padding: EdgeInsets.only(
            bottom: ResponsiveValues.spacingL(context),
          ),
          child: _buildGlassContainer(
            child: Padding(
              padding: ResponsiveValues.cardPadding(context),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Shimmer.fromColors(
                    baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
                    highlightColor: Colors.grey[100]!.withValues(alpha: 0.6),
                    child: Container(
                      width: ResponsiveValues.iconSizeXL(context) * 1.5,
                      height: ResponsiveValues.iconSizeXL(context) * 1.5,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(
                          ResponsiveValues.radiusMedium(context),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Shimmer.fromColors(
                          baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
                          highlightColor:
                              Colors.grey[100]!.withValues(alpha: 0.6),
                          child: Container(
                            height: 18,
                            width: double.infinity,
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
                            height: 14,
                            width: 200,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Shimmer.fromColors(
                              baseColor:
                                  Colors.grey[300]!.withValues(alpha: 0.3),
                              highlightColor:
                                  Colors.grey[100]!.withValues(alpha: 0.6),
                              child: Container(
                                width: 60,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                            const Spacer(),
                            Shimmer.fromColors(
                              baseColor:
                                  Colors.grey[300]!.withValues(alpha: 0.3),
                              highlightColor:
                                  Colors.grey[100]!.withValues(alpha: 0.6),
                              child: Container(
                                width: 40,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
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
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isOffline) {
      _refreshUnreadCount();
    }
  }

  Future<void> _loadNotifications() async {
    final provider = Provider.of<NotificationProvider>(context, listen: false);
    if (_isInitialLoad) {
      setState(() => _isRefreshing = true);
      try {
        await provider.loadNotifications(forceRefresh: !_isOffline);
        _page = 1;
        _hasMore = provider.notifications.length >= _pageSize;
      } finally {
        if (mounted) {
          setState(() {
            _isInitialLoad = false;
            _isRefreshing = false;
          });
        }
      }
    }
  }

  Future<void> _refreshNotifications() async {
    if (_isRefreshing) return;

    final hasConnection = await hasInternetConnection();
    if (!hasConnection) {
      setState(() => _isOffline = true);
      showTopSnackBar(context, 'You are offline. Using cached notifications.',
          isError: true);
      return;
    }

    setState(() => _isRefreshing = true);
    final provider = Provider.of<NotificationProvider>(context, listen: false);
    try {
      await provider.loadNotifications(forceRefresh: true);
      _page = 1;
      _hasMore = provider.notifications.length >= _pageSize;
      setState(() => _isOffline = false);
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _loadMoreNotifications() async {
    if (_isLoadingMore || !_hasMore) return;

    final hasConnection = await hasInternetConnection();
    if (!hasConnection) return;

    setState(() => _isLoadingMore = true);
    final provider = Provider.of<NotificationProvider>(context, listen: false);
    try {
      _page++;
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _refreshUnreadCount() async {
    final provider = Provider.of<NotificationProvider>(context, listen: false);
    await provider.refreshUnreadCount();
  }

  Future<void> _deleteNotification(AppNotification.Notification notification,
      NotificationProvider provider) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      await provider.deleteNotification(notification.logId);

      if (mounted) {
        Navigator.of(context).pop();
        showTopSnackBar(context, 'Notification deleted');
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        showTopSnackBar(context, 'Failed to delete notification',
            isError: true);

        final hasConnection = await hasInternetConnection();
        if (hasConnection) {
          await provider.loadNotifications(forceRefresh: true);
        }
      }
    }
  }

  Widget _buildMobileNotifications() {
    final provider = Provider.of<NotificationProvider>(context);

    if (_isInitialLoad && provider.isLoading) {
      return _buildSkeletonLoader();
    }

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: ResponsiveText(
          'Notifications',
          style: AppTextStyles.appBarTitle(context),
        ),
        centerTitle: false,
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: ResponsiveIcon(
            Icons.arrow_back_rounded,
            color: AppColors.getTextPrimary(context),
          ),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (provider.unreadNotifications.isNotEmpty && !_isOffline)
            Container(
              margin: const EdgeInsets.only(right: 4),
              child: IconButton(
                icon: const Icon(Icons.mark_email_read_rounded,
                    color: AppColors.telegramBlue),
                onPressed: () => _showMarkAllAsReadDialog(context, provider),
                tooltip: 'Mark all as read',
              ),
            ),
          IconButton(
            icon: _isRefreshing
                ? SizedBox(
                    width: ResponsiveValues.iconSizeS(context),
                    height: ResponsiveValues.iconSizeS(context),
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.telegramBlue),
                    ),
                  )
                : ResponsiveIcon(
                    _isOffline ? Icons.wifi_off_rounded : Icons.refresh_rounded,
                    color: _isOffline
                        ? AppColors.telegramGray
                        : AppColors.telegramBlue,
                  ),
            onPressed: _isRefreshing ? null : _refreshNotifications,
            tooltip: _isOffline ? 'Offline' : 'Refresh',
          ),
        ],
      ),
      body: _buildNotificationsContent(provider),
      floatingActionButton: _showFAB &&
              provider.unreadNotifications.isNotEmpty &&
              !_isOffline
          ? ScaleTransition(
              scale: _fabAnimationController,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: AppColors.blueGradient,
                  ),
                  borderRadius: BorderRadius.circular(
                    ResponsiveValues.radiusLarge(context),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.telegramBlue.withValues(alpha: 0.3),
                      blurRadius: ResponsiveValues.spacingS(context),
                      offset: Offset(0, ResponsiveValues.spacingXXS(context)),
                    ),
                  ],
                ),
                child: FloatingActionButton.extended(
                  onPressed: () => _showMarkAllAsReadDialog(context, provider),
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.mark_email_read_rounded, size: 20),
                  label: const Text('Mark all read'),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      ResponsiveValues.radiusLarge(context),
                    ),
                  ),
                ).animate().fadeIn(duration: AppThemes.animationDurationMedium),
              ),
            )
          : null,
    );
  }

  Widget _buildNotificationsContent(NotificationProvider provider) {
    if (provider.error != null && provider.notifications.isEmpty) {
      return Center(
        child: Padding(
          padding: ResponsiveValues.dialogPadding(context),
          child: ResponsiveColumn(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildGlassContainer(
                child: Container(
                  padding: ResponsiveValues.dialogPadding(context),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.telegramRed.withValues(alpha: 0.2),
                        AppColors.telegramRed.withValues(alpha: 0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.error_outline_rounded,
                      size: 48, color: AppColors.telegramRed),
                ),
              ),
              ResponsiveSizedBox(height: AppSpacing.xl),
              ResponsiveText(
                'Failed to Load',
                style: AppTextStyles.titleLarge(context),
              ),
              ResponsiveSizedBox(height: AppSpacing.l),
              ResponsiveText(
                provider.error!,
                style: AppTextStyles.bodyMedium(context).copyWith(
                  color: AppColors.getTextSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),
              ResponsiveSizedBox(height: AppSpacing.xl),
              if (!_isOffline)
                _buildGradientButton(
                  label: 'Try Again',
                  onPressed: _refreshNotifications,
                  gradient: AppColors.blueGradient,
                  icon: Icons.refresh_rounded,
                ),
            ],
          ),
        ),
      );
    }

    if (provider.notifications.isEmpty) {
      return Center(
        child: _isOffline
            ? OfflineState(
                dataType: 'notifications',
                message: 'You are offline. No cached notifications available.',
                onRetry: () {
                  setState(() => _isOffline = false);
                  _checkConnectivity();
                  _refreshNotifications();
                },
              )
            : ResponsiveColumn(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildGlassContainer(
                    child: Container(
                      padding: ResponsiveValues.dialogPadding(context),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.telegramGray.withValues(alpha: 0.2),
                            AppColors.telegramGray.withValues(alpha: 0.1),
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.notifications_off_rounded,
                          size: 48, color: AppColors.telegramGray),
                    ),
                  ),
                  ResponsiveSizedBox(height: AppSpacing.xl),
                  ResponsiveText(
                    'No Notifications',
                    style: AppTextStyles.titleLarge(context),
                  ),
                  ResponsiveSizedBox(height: AppSpacing.l),
                  ResponsiveText(
                    'You\'ll see notifications here\nwhen you receive them.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium(context).copyWith(
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                  ResponsiveSizedBox(height: AppSpacing.xl),
                  _buildGradientButton(
                    label: 'Refresh',
                    onPressed: _refreshNotifications,
                    gradient: AppColors.blueGradient,
                    icon: Icons.refresh_rounded,
                  ),
                ],
              ),
      );
    }

    final unreadNotifications = provider.unreadNotifications;
    final readNotifications = provider.readNotifications;

    return RefreshIndicator(
      onRefresh: _refreshNotifications,
      backgroundColor: AppColors.getSurface(context),
      color: AppColors.telegramBlue,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (_isOffline)
            SliverToBoxAdapter(
              child: Container(
                margin: ResponsiveValues.screenPadding(context),
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
                        'Offline mode - showing cached notifications',
                        style: AppTextStyles.bodySmall(context).copyWith(
                          color: AppColors.telegramYellow,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SliverToBoxAdapter(child: ResponsiveSizedBox(height: AppSpacing.s)),
          if (unreadNotifications.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _buildSectionHeader('Unread', unreadNotifications.length),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildNotificationItem(
                    unreadNotifications[index], provider, index),
                childCount: unreadNotifications.length,
              ),
            ),
          ],
          if (readNotifications.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                  unreadNotifications.isEmpty ? 'Notifications' : 'Earlier',
                  readNotifications.length),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildNotificationItem(
                    readNotifications[index],
                    provider,
                    index + (unreadNotifications.length)),
                childCount: readNotifications.length,
              ),
            ),
          ],
          if (_isLoadingMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(ResponsiveValues.spacingL(context)),
                child: Center(
                  child: SizedBox(
                    width: ResponsiveValues.iconSizeL(context),
                    height: ResponsiveValues.iconSizeL(context),
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.telegramBlue),
                    ),
                  ),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: ResponsiveSizedBox(height: AppSpacing.xxxl),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        ResponsiveValues.spacingL(context),
        ResponsiveValues.spacingL(context),
        ResponsiveValues.spacingL(context),
        ResponsiveValues.spacingS(context),
      ),
      child: ResponsiveRow(
        children: [
          ResponsiveText(
            title,
            style: AppTextStyles.labelLarge(context).copyWith(
              color: AppColors.getTextSecondary(context),
            ),
          ),
          ResponsiveSizedBox(width: AppSpacing.m),
          _buildGlassContainer(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveValues.spacingS(context),
                vertical: ResponsiveValues.spacingXXS(context),
              ),
              child: ResponsiveText(
                count.toString(),
                style: AppTextStyles.labelSmall(context).copyWith(
                  color: AppColors.telegramBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(AppNotification.Notification notification,
      NotificationProvider provider, int index) {
    final isUnread = !notification.isRead;
    final iconData = _getNotificationIcon(notification);
    final iconColor = _getNotificationColor(notification);
    final timeText = notification.timeAgo;

    return Dismissible(
      key: Key('notification_${notification.logId}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(
          right: ResponsiveValues.spacingL(context),
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF3B30), Color(0xFFE6204A)],
          ),
          borderRadius:
              BorderRadius.circular(ResponsiveValues.radiusXLarge(context)),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return _showDeleteConfirmation(context, notification, provider);
      },
      onDismissed: (direction) {},
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: ResponsiveValues.spacingL(context),
          vertical: ResponsiveValues.spacingXS(context),
        ),
        child: _buildGlassContainer(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _handleNotificationTap(notification, provider),
              onLongPress: () =>
                  _showActionSheet(context, notification, provider),
              borderRadius:
                  BorderRadius.circular(ResponsiveValues.radiusXLarge(context)),
              child: Padding(
                padding: ResponsiveValues.cardPadding(context),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: ResponsiveValues.iconSizeXL(context) * 1.5,
                      height: ResponsiveValues.iconSizeXL(context) * 1.5,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            iconColor.withValues(alpha: 0.2),
                            iconColor.withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(
                          ResponsiveValues.radiusMedium(context),
                        ),
                      ),
                      child: Center(
                        child: ResponsiveIcon(
                          iconData,
                          size: ResponsiveValues.iconSizeL(context),
                          color: iconColor,
                        ),
                      ),
                    ),
                    ResponsiveSizedBox(width: AppSpacing.l),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  notification.title,
                                  style: AppTextStyles.titleSmall(context)
                                      .copyWith(
                                    fontWeight: isUnread
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isUnread)
                                Container(
                                  width: ResponsiveValues.spacingS(context),
                                  height: ResponsiveValues.spacingS(context),
                                  margin: const EdgeInsets.only(left: 4),
                                  decoration: const BoxDecoration(
                                    color: AppColors.telegramBlue,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            notification.message,
                            style: AppTextStyles.bodySmall(context).copyWith(
                              color: AppColors.getTextSecondary(context),
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 12,
                                color: AppColors.getTextSecondary(context)
                                    .withValues(alpha: 0.5),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                timeText,
                                style: AppTextStyles.caption(context).copyWith(
                                  color: AppColors.getTextSecondary(context)
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                              const Spacer(),
                              if (!notification.isRead)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.telegramBlue
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.telegramBlue
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    'NEW',
                                    style: AppTextStyles.statusBadge(context)
                                        .copyWith(
                                      color: AppColors.telegramBlue,
                                      fontSize: 9,
                                    ),
                                  ),
                                ),
                            ],
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
    )
        .animate()
        .fadeIn(
            duration: AppThemes.animationDurationMedium, delay: (index * 30).ms)
        .slideX(
          begin: -0.1,
          end: 0,
          duration: AppThemes.animationDurationMedium,
          delay: (index * 30).ms,
        );
  }

  Color _getNotificationColor(AppNotification.Notification notification) {
    final title = notification.title.toLowerCase();
    if (title.contains('payment')) return AppColors.telegramGreen;
    if (title.contains('exam') || title.contains('result')) {
      return AppColors.telegramYellow;
    }
    if (title.contains('streak') || title.contains('progress')) {
      return AppColors.telegramGreen;
    }
    if (title.contains('expiring') || title.contains('expired')) {
      return AppColors.telegramRed;
    }
    if (title.contains('system') || title.contains('announcement')) {
      return AppColors.telegramBlue;
    }
    return AppColors.telegramBlue;
  }

  IconData _getNotificationIcon(AppNotification.Notification notification) {
    final title = notification.title.toLowerCase();
    if (title.contains('payment')) return Icons.payment_rounded;
    if (title.contains('exam')) return Icons.assignment_rounded;
    if (title.contains('streak')) return Icons.local_fire_department_rounded;
    if (title.contains('expiring')) return Icons.timer_rounded;
    if (title.contains('system')) return Icons.announcement_rounded;
    if (title.contains('result')) return Icons.assessment_rounded;
    return Icons.notifications_rounded;
  }

  void _handleNotificationTap(AppNotification.Notification notification,
      NotificationProvider provider) {
    if (!notification.isRead && !_isOffline) {
      provider.markAsRead(notification.logId);
    }
    _showNotificationDetails(context, notification, provider);
  }

  void _showNotificationDetails(
      BuildContext context,
      AppNotification.Notification notification,
      NotificationProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildNotificationDetails(notification, provider),
    );
  }

  Widget _buildNotificationDetails(AppNotification.Notification notification,
      NotificationProvider provider) {
    final iconData = _getNotificationIcon(notification);
    final iconColor = _getNotificationColor(notification);

    return _buildGlassContainer(
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return ResponsiveColumn(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: ResponsiveValues.spacingXXL(context),
                height: ResponsiveValues.spacingXS(context),
                margin: EdgeInsets.symmetric(
                  vertical: ResponsiveValues.spacingL(context),
                ),
                decoration: BoxDecoration(
                  color: AppColors.getTextSecondary(context)
                      .withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(
                    ResponsiveValues.radiusSmall(context),
                  ),
                ),
              ),
              Padding(
                padding: ResponsiveValues.screenPadding(context),
                child: ResponsiveRow(
                  children: [
                    Container(
                      width: ResponsiveValues.iconSizeXXL(context) * 1.5,
                      height: ResponsiveValues.iconSizeXXL(context) * 1.5,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            iconColor.withValues(alpha: 0.2),
                            iconColor.withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(
                          ResponsiveValues.radiusMedium(context),
                        ),
                      ),
                      child: ResponsiveIcon(
                        iconData,
                        size: ResponsiveValues.iconSizeXL(context),
                        color: iconColor,
                      ),
                    ),
                    ResponsiveSizedBox(width: AppSpacing.l),
                    Expanded(
                      child: ResponsiveColumn(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ResponsiveText(
                            notification.title,
                            style: AppTextStyles.titleLarge(context).copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          ResponsiveSizedBox(height: AppSpacing.xs),
                          ResponsiveText(
                            notification.timeAgo,
                            style: AppTextStyles.bodySmall(context).copyWith(
                              color: AppColors.getTextSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!notification.isRead && !_isOffline)
                      IconButton(
                        icon: const Icon(Icons.mark_email_read_rounded,
                            color: AppColors.telegramBlue),
                        onPressed: () {
                          provider.markAsRead(notification.logId);
                          Navigator.pop(context);
                        },
                      ),
                  ],
                ),
              ),
              Divider(
                color: AppColors.getDivider(context),
                height: ResponsiveValues.spacingL(context),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: ResponsiveValues.screenPadding(context),
                  child: ResponsiveText(
                    notification.message,
                    style: AppTextStyles.bodyLarge(context).copyWith(
                      height: 1.6,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: ResponsiveValues.screenPadding(context),
                child: ResponsiveRow(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.getTextSecondary(context),
                          side: BorderSide(
                            color: AppColors.getTextSecondary(context),
                          ),
                          padding: EdgeInsets.symmetric(
                            vertical: ResponsiveValues.spacingL(context),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              ResponsiveValues.radiusMedium(context),
                            ),
                          ),
                        ),
                        child: const Text('Close'),
                      ),
                    ),
                    ResponsiveSizedBox(width: AppSpacing.m),
                    Expanded(
                      child: _buildGradientButton(
                        label: 'Delete',
                        onPressed: () {
                          Navigator.pop(context);
                          _deleteNotification(notification, provider);
                        },
                        gradient: AppColors.pinkGradient,
                        icon: Icons.delete_rounded,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ).animate().slideY(
          begin: 1,
          end: 0,
          duration: AppThemes.animationDurationMedium,
        );
  }

  void _showActionSheet(
      BuildContext context,
      AppNotification.Notification notification,
      NotificationProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildGlassContainer(
        child: ResponsiveColumn(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: ResponsiveValues.spacingXXL(context),
              height: ResponsiveValues.spacingXS(context),
              margin: EdgeInsets.symmetric(
                vertical: ResponsiveValues.spacingL(context),
              ),
              decoration: BoxDecoration(
                color:
                    AppColors.getTextSecondary(context).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(
                  ResponsiveValues.radiusSmall(context),
                ),
              ),
            ),
            ListTile(
              leading: _buildGlassContainer(
                child: Container(
                  width: ResponsiveValues.iconSizeXL(context),
                  height: ResponsiveValues.iconSizeXL(context),
                  padding: EdgeInsets.all(ResponsiveValues.spacingS(context)),
                  child: const Icon(Icons.delete_rounded,
                      color: AppColors.telegramRed),
                ),
              ),
              title: ResponsiveText(
                'Delete',
                style: AppTextStyles.bodyLarge(context).copyWith(
                  color: AppColors.telegramRed,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _deleteNotification(notification, provider);
              },
            ),
            if (!notification.isRead && !_isOffline)
              ListTile(
                leading: _buildGlassContainer(
                  child: Container(
                    width: ResponsiveValues.iconSizeXL(context),
                    height: ResponsiveValues.iconSizeXL(context),
                    padding: EdgeInsets.all(ResponsiveValues.spacingS(context)),
                    child: const Icon(Icons.mark_email_read_rounded,
                        color: AppColors.telegramBlue),
                  ),
                ),
                title: ResponsiveText(
                  'Mark as read',
                  style: AppTextStyles.bodyLarge(context).copyWith(
                    color: AppColors.telegramBlue,
                  ),
                ),
                onTap: () {
                  provider.markAsRead(notification.logId);
                  Navigator.pop(context);
                },
              ),
            ListTile(
              leading: _buildGlassContainer(
                child: Container(
                  width: ResponsiveValues.iconSizeXL(context),
                  height: ResponsiveValues.iconSizeXL(context),
                  padding: EdgeInsets.all(ResponsiveValues.spacingS(context)),
                  child: Icon(Icons.close_rounded,
                      color: AppColors.getTextSecondary(context)),
                ),
              ),
              title: ResponsiveText(
                'Cancel',
                style: AppTextStyles.bodyLarge(context).copyWith(
                  color: AppColors.getTextSecondary(context),
                ),
              ),
              onTap: () => Navigator.pop(context),
            ),
            ResponsiveSizedBox(height: AppSpacing.l),
          ],
        ),
      ),
    );
  }

  Future<bool> _showDeleteConfirmation(
      BuildContext context,
      AppNotification.Notification notification,
      NotificationProvider provider) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: _buildGlassContainer(
          child: Padding(
            padding: ResponsiveValues.dialogPadding(context),
            child: ResponsiveColumn(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: ResponsiveValues.iconSizeXL(context) * 1.5,
                  height: ResponsiveValues.iconSizeXL(context) * 1.5,
                  padding: EdgeInsets.all(ResponsiveValues.spacingM(context)),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.telegramRed.withValues(alpha: 0.2),
                        AppColors.telegramRed.withValues(alpha: 0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_rounded,
                      color: AppColors.telegramRed, size: 32),
                ),
                ResponsiveSizedBox(height: AppSpacing.l),
                ResponsiveText(
                  'Delete notification',
                  style: AppTextStyles.titleLarge(context).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                ResponsiveSizedBox(height: AppSpacing.m),
                ResponsiveText(
                  'Are you sure you want to delete this notification?',
                  style: AppTextStyles.bodyMedium(context).copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                ResponsiveSizedBox(height: AppSpacing.xl),
                ResponsiveRow(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.getTextSecondary(context),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              ResponsiveValues.radiusMedium(context),
                            ),
                          ),
                          padding: EdgeInsets.symmetric(
                            vertical: ResponsiveValues.spacingM(context),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    ResponsiveSizedBox(width: AppSpacing.m),
                    Expanded(
                      child: _buildGradientButton(
                        label: 'Delete',
                        onPressed: () => Navigator.pop(context, true),
                        gradient: AppColors.pinkGradient,
                        icon: Icons.delete_rounded,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result == true) {
      await _deleteNotification(notification, provider);
    }
    return result ?? false;
  }

  void _showMarkAllAsReadDialog(
      BuildContext context, NotificationProvider provider) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: _buildGlassContainer(
          child: Padding(
            padding: ResponsiveValues.dialogPadding(context),
            child: ResponsiveColumn(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: ResponsiveValues.iconSizeXL(context) * 1.5,
                  height: ResponsiveValues.iconSizeXL(context) * 1.5,
                  padding: EdgeInsets.all(ResponsiveValues.spacingM(context)),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.telegramBlue.withValues(alpha: 0.2),
                        AppColors.telegramPurple.withValues(alpha: 0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mark_email_read_rounded,
                      color: AppColors.telegramBlue, size: 32),
                ),
                ResponsiveSizedBox(height: AppSpacing.l),
                ResponsiveText(
                  'Mark all as read',
                  style: AppTextStyles.titleLarge(context).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                ResponsiveSizedBox(height: AppSpacing.m),
                ResponsiveText(
                  'Mark all notifications as read?',
                  style: AppTextStyles.bodyMedium(context).copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                ResponsiveSizedBox(height: AppSpacing.xl),
                ResponsiveRow(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.getTextSecondary(context),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              ResponsiveValues.radiusMedium(context),
                            ),
                          ),
                          padding: EdgeInsets.symmetric(
                            vertical: ResponsiveValues.spacingM(context),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    ResponsiveSizedBox(width: AppSpacing.m),
                    Expanded(
                      child: _buildGradientButton(
                        label: 'Mark all',
                        onPressed: () {
                          provider.markAllAsRead();
                          Navigator.pop(context);
                          showTopSnackBar(
                              context, 'All notifications marked as read');
                        },
                        gradient: AppColors.blueGradient,
                        icon: Icons.mark_email_read_rounded,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: _buildMobileNotifications(),
      tablet: _buildMobileNotifications(),
      desktop: _buildMobileNotifications(),
    );
  }
}

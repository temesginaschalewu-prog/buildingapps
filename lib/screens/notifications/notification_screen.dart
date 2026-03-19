// lib/screens/notifications/notification_screen.dart
// COMPLETE PRODUCTION-READY FILE - FIXED PENDING COUNT

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/notification_model.dart' as AppNotification;
import '../../providers/notification_provider.dart';
import '../../services/connectivity_service.dart';
import '../../services/snackbar_service.dart';
import '../../services/offline_queue_manager.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_shimmer.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_dialog.dart';
import '../../widgets/common/app_bar.dart';
import '../../themes/app_themes.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/responsive_values.dart';
import '../../utils/helpers.dart';
import '../../utils/constants.dart';

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
  int _pendingCount = 0;
  final ScrollController _scrollController = ScrollController();
  bool _showFAB = true;
  Timer? _scrollTimer;
  final int _pageSize = 20;
  bool _hasMore = true;

  late AnimationController _fabAnimationController;
  StreamSubscription? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _fabAnimationController =
        AnimationController(vsync: this, duration: AppThemes.animationMedium);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _scrollTimer?.cancel();
    _fabAnimationController.dispose();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    await _checkConnectivity();
    _setupConnectivityListener();
    unawaited(_checkPendingCount());
    final provider = context.read<NotificationProvider>();
    if (provider.notifications.isNotEmpty) {
      setState(() {
        _isInitialLoad = false;
        _hasMore = provider.notifications.length >= _pageSize;
      });
      if (!_isOffline) {
        unawaited(provider.loadNotifications());
      }
      return;
    }

    unawaited(_loadNotifications());
  }

  void _setupConnectivityListener() {
    final connectivityService = context.read<ConnectivityService>();
    _connectivitySubscription =
        connectivityService.onConnectivityChanged.listen((isOnline) {
      if (mounted) {
        setState(() {
          _isOffline = !isOnline;
          final queueManager = context.read<OfflineQueueManager>();
          _pendingCount = queueManager.pendingCount;
        });

        if (isOnline) {
          _syncPendingActions();
        }
      }
    });
  }

  Future<void> _syncPendingActions() async {
    final queueManager = context.read<OfflineQueueManager>();
    await queueManager.processQueue();
  }

  Future<void> _checkConnectivity() async {
    final connectivityService = context.read<ConnectivityService>();
    await connectivityService.checkConnectivity();
    if (mounted) {
      setState(() {
        _isOffline = !connectivityService.isOnline;
        final queueManager = context.read<OfflineQueueManager>();
        _pendingCount = queueManager.pendingCount;
      });
    }
  }

  Future<void> _checkPendingCount() async {
    final queueManager = context.read<OfflineQueueManager>();
    if (mounted) {
      setState(() => _pendingCount = queueManager.pendingCount);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isOffline) {
      _refreshUnreadCount();
    }
  }

  Future<void> _loadNotifications() async {
    final provider = context.read<NotificationProvider>();

    if (provider.isLoaded && provider.notifications.isNotEmpty) {
      setState(() {
        _isInitialLoad = false;
        _hasMore = provider.notifications.length >= _pageSize;
      });
      return;
    }

    setState(() => _isRefreshing = true);
    try {
      await provider.loadNotifications();
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

  Future<void> _refreshNotifications() async {
    if (_isRefreshing) return;

    final connectivityService = context.read<ConnectivityService>();
    if (!connectivityService.isOnline) {
      setState(() => _isOffline = true);
      SnackbarService().showOffline(context);
      return;
    }

    setState(() => _isRefreshing = true);
    final provider = context.read<NotificationProvider>();
    try {
      await provider.loadNotifications(
          forceRefresh: true, isManualRefresh: true);
      _hasMore = provider.notifications.length >= _pageSize;
      setState(() => _isOffline = false);
      SnackbarService().showSuccess(context, AppStrings.notificationsUpdated);
    } catch (e) {
      if (isNetworkError(e)) {
        setState(() => _isOffline = true);
        SnackbarService().showOffline(context);
      } else {
        SnackbarService().showError(context, AppStrings.refreshFailed);
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _loadMoreNotifications() async {
    if (_isLoadingMore || !_hasMore) return;

    final connectivityService = context.read<ConnectivityService>();
    if (!connectivityService.isOnline) return;

    setState(() => _isLoadingMore = true);
    try {
      await Future.delayed(const Duration(milliseconds: 500));
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _refreshUnreadCount() async {
    final provider = context.read<NotificationProvider>();
    await provider.refreshUnreadCount();
  }

  Future<void> _deleteNotification(AppNotification.Notification notification,
      NotificationProvider provider) async {
    try {
      AppDialog.showLoading(context, message: AppStrings.deleting);
      await provider.deleteNotification(notification.logId);
      AppDialog.hideLoading(context);

      if (_isOffline) {
        SnackbarService().showQueued(context, action: AppStrings.delete);
      } else {
        SnackbarService().showSuccess(context, AppStrings.notificationDeleted);
      }
    } catch (e) {
      AppDialog.hideLoading(context);
      SnackbarService()
          .showError(context, AppStrings.failedToDeleteNotification);

      final connectivityService = context.read<ConnectivityService>();
      if (connectivityService.isOnline) {
        await provider.loadNotifications(forceRefresh: true);
      }
    }
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
    if (!notification.isRead) {
      provider.markAsRead(notification.logId);
    }
    _showNotificationDetails(context, notification, provider);
  }

  void _showNotificationDetails(
      BuildContext context,
      AppNotification.Notification notification,
      NotificationProvider provider) {
    AppDialog.showBottomSheet(
      context: context,
      child: _buildNotificationDetails(notification, provider),
    );
  }

  Widget _buildNotificationDetails(AppNotification.Notification notification,
      NotificationProvider provider) {
    final iconData = _getNotificationIcon(notification);
    final iconColor = _getNotificationColor(notification);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: ResponsiveValues.screenPadding(context),
          child: Row(
            children: [
              Container(
                width: ResponsiveValues.iconSizeXXL(context) * 1.5,
                height: ResponsiveValues.iconSizeXXL(context) * 1.5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      iconColor.withValues(alpha: 0.2),
                      iconColor.withValues(alpha: 0.05)
                    ],
                  ),
                  borderRadius: BorderRadius.circular(
                      ResponsiveValues.radiusMedium(context)),
                ),
                child: Icon(iconData,
                    size: ResponsiveValues.iconSizeXL(context),
                    color: iconColor),
              ),
              SizedBox(width: ResponsiveValues.spacingL(context)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: AppTextStyles.titleLarge(context)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: ResponsiveValues.spacingXS(context)),
                    Text(
                      notification.timeAgo,
                      style: AppTextStyles.bodySmall(context)
                          .copyWith(color: AppColors.getTextSecondary(context)),
                    ),
                  ],
                ),
              ),
              if (!notification.isRead)
                AppButton.icon(
                  icon: Icons.mark_email_read_rounded,
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
            height: ResponsiveValues.spacingL(context)),
        Expanded(
          child: SingleChildScrollView(
            padding: ResponsiveValues.screenPadding(context),
            child: Text(
              notification.message,
              style: AppTextStyles.bodyLarge(context).copyWith(height: 1.6),
            ),
          ),
        ),
        Padding(
          padding: ResponsiveValues.screenPadding(context),
          child: Row(
            children: [
              Expanded(
                child: AppButton.outline(
                  label: AppStrings.close,
                  onPressed: () => Navigator.pop(context),
                  expanded: true,
                ),
              ),
              SizedBox(width: ResponsiveValues.spacingM(context)),
              Expanded(
                child: AppButton.danger(
                  label: AppStrings.delete,
                  icon: Icons.delete_rounded,
                  onPressed: () {
                    Navigator.pop(context);
                    _deleteNotification(notification, provider);
                  },
                  expanded: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showActionSheet(
      BuildContext context,
      AppNotification.Notification notification,
      NotificationProvider provider) {
    AppDialog.showBottomSheet(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: AppCard.glass(
              child: Container(
                width: ResponsiveValues.iconSizeXL(context),
                height: ResponsiveValues.iconSizeXL(context),
                padding: EdgeInsets.all(ResponsiveValues.spacingS(context)),
                child: const Icon(Icons.delete_rounded,
                    color: AppColors.telegramRed),
              ),
            ),
            title: Text(
              AppStrings.delete,
              style: AppTextStyles.bodyLarge(context)
                  .copyWith(color: AppColors.telegramRed),
            ),
            onTap: () {
              Navigator.pop(context);
              _deleteNotification(notification, provider);
            },
          ),
          if (!notification.isRead)
            ListTile(
              leading: AppCard.glass(
                child: Container(
                  width: ResponsiveValues.iconSizeXL(context),
                  height: ResponsiveValues.iconSizeXL(context),
                  padding: EdgeInsets.all(ResponsiveValues.spacingS(context)),
                  child: const Icon(Icons.mark_email_read_rounded,
                      color: AppColors.telegramBlue),
                ),
              ),
              title: Text(
                AppStrings.markAsRead,
                style: AppTextStyles.bodyLarge(context)
                    .copyWith(color: AppColors.telegramBlue),
              ),
              onTap: () {
                provider.markAsRead(notification.logId);
                Navigator.pop(context);
              },
            ),
          ListTile(
            leading: AppCard.glass(
              child: Container(
                width: ResponsiveValues.iconSizeXL(context),
                height: ResponsiveValues.iconSizeXL(context),
                padding: EdgeInsets.all(ResponsiveValues.spacingS(context)),
                child: Icon(Icons.close_rounded,
                    color: AppColors.getTextSecondary(context)),
              ),
            ),
            title: Text(
              AppStrings.cancel,
              style: AppTextStyles.bodyLarge(context)
                  .copyWith(color: AppColors.getTextSecondary(context)),
            ),
            onTap: () => Navigator.pop(context),
          ),
          SizedBox(height: ResponsiveValues.spacingL(context)),
        ],
      ),
    );
  }

  Future<bool> _showDeleteConfirmation(
      BuildContext context,
      AppNotification.Notification notification,
      NotificationProvider provider) async {
    final result = await AppDialog.delete(
      context: context,
      title: AppStrings.deleteNotification,
      message: AppStrings.deleteNotificationConfirm,
    );

    if (result == true) {
      await _deleteNotification(notification, provider);
    }
    return result ?? false;
  }

  void _showMarkAllAsReadDialog(
      BuildContext context, NotificationProvider provider) {
    if (_isOffline) {
      AppDialog.confirm(
        context: context,
        title: AppStrings.markAllAsRead,
        message: AppStrings.markAllAsReadOffline,
        confirmText: AppStrings.queue,
      ).then((confirmed) {
        if (confirmed == true) {
          provider.markAllAsRead();
          SnackbarService()
              .showQueued(context, action: AppStrings.markAllAsRead);
        }
      });
      return;
    }

    AppDialog.confirm(
      context: context,
      title: AppStrings.markAllAsRead,
      message: AppStrings.markAllAsReadConfirm,
      confirmText: AppStrings.markAll,
    ).then((confirmed) {
      if (confirmed == true) {
        provider.markAllAsRead();
        SnackbarService()
            .showSuccess(context, AppStrings.allNotificationsMarkedRead);
      }
    });
  }

  Widget _buildSkeletonLoader() {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: CustomAppBar(
        title: AppStrings.notifications,
        subtitle: AppStrings.loading,
        showOfflineIndicator: _isOffline,
      ),
      body: ListView.builder(
        padding: ResponsiveValues.screenPadding(context),
        itemCount: 5,
        itemBuilder: (context, index) => Padding(
          padding: EdgeInsets.only(bottom: ResponsiveValues.spacingL(context)),
          child: AppShimmer(type: ShimmerType.notificationCard, index: index),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        ResponsiveValues.spacingL(context),
        ResponsiveValues.spacingXL(context),
        ResponsiveValues.spacingL(context),
        ResponsiveValues.spacingS(context),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: ResponsiveValues.spacingXL(context),
            decoration: BoxDecoration(
              color: AppColors.telegramBlue,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          SizedBox(width: ResponsiveValues.spacingM(context)),
          Text(
            title,
            style: AppTextStyles.titleLarge(context).copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(width: ResponsiveValues.spacingS(context)),
          AppCard.glass(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveValues.spacingS(context),
                vertical: ResponsiveValues.spacingXXS(context),
              ),
              child: Text(
                count.toString(),
                style: AppTextStyles.labelSmall(context).copyWith(
                    color: AppColors.telegramBlue, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(NotificationProvider provider) {
    final unreadCount = provider.unreadNotifications.length;
    final totalCount = provider.notifications.length;
    final readCount = totalCount - unreadCount;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        ResponsiveValues.spacingL(context),
        ResponsiveValues.spacingM(context),
        ResponsiveValues.spacingL(context),
        ResponsiveValues.spacingL(context),
      ),
      child: AppCard.glass(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.telegramBlue.withValues(alpha: 0.1),
                AppColors.telegramPurple.withValues(alpha: 0.06),
                Colors.transparent,
              ],
            ),
            borderRadius:
                BorderRadius.circular(ResponsiveValues.radiusLarge(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Stay on top of updates.',
                style: AppTextStyles.displaySmall(context).copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: ResponsiveValues.spacingS(context)),
              Text(
                'Important account activity, study updates, and payment status all live here.',
                style: AppTextStyles.bodyMedium(context).copyWith(
                  color: AppColors.getTextSecondary(context),
                ),
              ),
              SizedBox(height: ResponsiveValues.spacingL(context)),
              Wrap(
                spacing: ResponsiveValues.spacingM(context),
                runSpacing: ResponsiveValues.spacingM(context),
                children: [
                  _buildHeroMetric(
                    label: 'Unread',
                    value: '$unreadCount',
                    icon: Icons.mark_email_unread_rounded,
                    color: AppColors.telegramBlue,
                  ),
                  _buildHeroMetric(
                    label: 'Read',
                    value: '$readCount',
                    icon: Icons.done_all_rounded,
                    color: AppColors.telegramGreen,
                  ),
                  _buildHeroMetric(
                    label: 'Sync',
                    value:
                        _isOffline ? AppStrings.offlineMode : AppStrings.active,
                    icon: _isOffline
                        ? Icons.wifi_off_rounded
                        : Icons.cloud_done_rounded,
                    color:
                        _isOffline ? AppColors.warning : AppColors.telegramTeal,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroMetric({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 110),
      padding: EdgeInsets.all(ResponsiveValues.spacingM(context)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius:
            BorderRadius.circular(ResponsiveValues.radiusLarge(context)),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: ResponsiveValues.iconSizeS(context)),
          SizedBox(height: ResponsiveValues.spacingS(context)),
          Text(
            value,
            style: AppTextStyles.titleLarge(context).copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: AppTextStyles.labelMedium(context).copyWith(color: color),
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
        padding: EdgeInsets.only(right: ResponsiveValues.spacingL(context)),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: AppColors.pinkGradient),
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
        child: AppCard.notification(
          isUnread: isUnread,
          isOffline: _isOffline,
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
                            iconColor.withValues(alpha: 0.05)
                          ],
                        ),
                        borderRadius: BorderRadius.circular(
                            ResponsiveValues.radiusMedium(context)),
                      ),
                      child: Center(
                        child: Icon(iconData,
                            size: ResponsiveValues.iconSizeL(context),
                            color: iconColor),
                      ),
                    ),
                    SizedBox(width: ResponsiveValues.spacingL(context)),
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
                                      shape: BoxShape.circle),
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
                                size: ResponsiveValues.iconSizeXXS(context),
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
                              if (notification.isFailed)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.telegramRed
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: AppColors.telegramRed
                                            .withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    AppStrings.failed,
                                    style: AppTextStyles.statusBadge(context)
                                        .copyWith(
                                            color: AppColors.telegramRed,
                                            fontSize: ResponsiveValues
                                                .fontNotificationBadge(
                                                    context)),
                                  ),
                                )
                              else if (notification.isPending)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: AppColors.warning
                                            .withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    AppStrings.pending,
                                    style: AppTextStyles.statusBadge(context)
                                        .copyWith(
                                            color: AppColors.warning,
                                            fontSize: ResponsiveValues
                                                .fontNotificationBadge(
                                                    context)),
                                  ),
                                )
                              else if (!notification.isRead && !_isOffline)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.telegramBlue
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: AppColors.telegramBlue
                                            .withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    AppStrings.new_,
                                    style: AppTextStyles.statusBadge(context)
                                        .copyWith(
                                            color: AppColors.telegramBlue,
                                            fontSize: ResponsiveValues
                                                .fontNotificationBadge(
                                                    context)),
                                  ),
                                )
                              else if (_isOffline && !notification.isRead)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: AppColors.warning
                                            .withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    AppStrings.pending,
                                    style: AppTextStyles.statusBadge(context)
                                        .copyWith(
                                            color: AppColors.warning,
                                            fontSize: ResponsiveValues
                                                .fontNotificationBadge(
                                                    context)),
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
          duration: AppThemes.animationMedium,
          delay: (index * 30).ms,
        )
        .slideX(
          begin: -0.1,
          end: 0,
          duration: AppThemes.animationMedium,
          delay: (index * 30).ms,
        );
  }

  Widget _buildNotificationsContent(NotificationProvider provider) {
    if (provider.errorMessage != null && provider.notifications.isEmpty) {
      return Center(
        child: Padding(
          padding: ResponsiveValues.dialogPadding(context),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppCard.glass(
                child: Container(
                  padding: ResponsiveValues.dialogPadding(context),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.telegramRed.withValues(alpha: 0.2),
                        AppColors.telegramRed.withValues(alpha: 0.1)
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.error_outline_rounded,
                      size: 48, color: AppColors.telegramRed),
                ),
              ),
              SizedBox(height: ResponsiveValues.spacingXL(context)),
              Text(AppStrings.failedToLoad,
                  style: AppTextStyles.titleLarge(context)),
              SizedBox(height: ResponsiveValues.spacingL(context)),
              Text(
                provider.errorMessage!,
                style: AppTextStyles.bodyMedium(context)
                    .copyWith(color: AppColors.getTextSecondary(context)),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: ResponsiveValues.spacingXL(context)),
              if (!_isOffline)
                AppButton.primary(
                  label: AppStrings.tryAgain,
                  icon: Icons.refresh_rounded,
                  onPressed: _refreshNotifications,
                ),
            ],
          ),
        ),
      );
    }

    if (provider.notifications.isEmpty) {
      return Center(
        child: _isOffline
            ? AppEmptyState.offline(
                message: _pendingCount > 0
                    ? '${AppStrings.noCachedNotifications} $_pendingCount ${AppStrings.actionQueued}'
                    : AppStrings.noCachedNotificationsAvailable,
                onRetry: () {
                  setState(() => _isOffline = false);
                  _checkConnectivity();
                  _refreshNotifications();
                },
                pendingCount: _pendingCount,
              )
            : AppEmptyState.noData(
                dataType: AppStrings.notifications,
                customMessage: AppStrings.notificationsWillAppearHere,
                onRefresh: _refreshNotifications,
              ),
      );
    }

    final unreadNotifications = provider.unreadNotifications;
    final readNotifications = provider.readNotifications;
    final visibleNotifications =
        unreadNotifications.length + readNotifications.length;

    return RefreshIndicator(
      onRefresh: _refreshNotifications,
      backgroundColor: AppColors.getSurface(context),
      color: AppColors.telegramBlue,
      child: CustomScrollView(
        controller: _scrollController,
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
                  border:
                      Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.schedule_rounded,
                        color: AppColors.info,
                        size: ResponsiveValues.iconSizeS(context)),
                    SizedBox(width: ResponsiveValues.spacingM(context)),
                    Expanded(
                      child: Text(
                        AppStrings.pendingActionsSyncLabel(_pendingCount),
                        style: AppTextStyles.bodySmall(context)
                            .copyWith(color: AppColors.info),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (unreadNotifications.isNotEmpty) ...[
            SliverToBoxAdapter(
                child: _buildSectionHeader(
                    AppStrings.unread, unreadNotifications.length)),
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
                unreadNotifications.isEmpty
                    ? AppStrings.notifications
                    : AppStrings.earlier,
                readNotifications.length,
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildNotificationItem(
                  readNotifications[index],
                  provider,
                  index + (unreadNotifications.length),
                ),
                childCount: readNotifications.length,
              ),
            ),
          ],
          if (visibleNotifications == 0)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: AppEmptyState.noData(
                  dataType: AppStrings.notifications,
                  customMessage: AppStrings.notificationsLoadedButEmpty,
                  onRefresh: _refreshNotifications,
                ),
              ),
            ),
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
              child: SizedBox(height: ResponsiveValues.spacingXXXL(context))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final hasUnread = provider.notifications.any((n) => !n.isRead);

    final hasCachedData =
        provider.isLoaded && provider.notifications.isNotEmpty;

    if (_isInitialLoad && provider.isLoading && !hasCachedData) {
      return _buildSkeletonLoader();
    }

    if (hasCachedData && _isInitialLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _isInitialLoad = false);
        }
      });
    }

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: CustomAppBar(
        title: AppStrings.notifications,
        subtitle:
            _isOffline ? AppStrings.offlineMode : 'Inbox, alerts, and updates',
        leading: AppButton.icon(
            icon: Icons.arrow_back_rounded, onPressed: () => context.pop()),
        showOfflineIndicator: _isOffline,
        actions: [
          if (hasUnread)
            Container(
              margin: const EdgeInsets.only(right: 4),
              child: AppButton.icon(
                icon: Icons.mark_email_read_rounded,
                onPressed: () => _showMarkAllAsReadDialog(context, provider),
              ),
            ),
          if (_isRefreshing)
            Container(
              width: ResponsiveValues.appBarButtonSize(context),
              height: ResponsiveValues.appBarButtonSize(context),
              decoration: BoxDecoration(
                color: AppColors.getSurface(context).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: SizedBox(
                  width: ResponsiveValues.iconSizeS(context),
                  height: ResponsiveValues.iconSizeS(context),
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.telegramBlue),
                  ),
                ),
              ),
            )
          else
            AppButton.icon(
              icon: _isOffline ? Icons.wifi_off_rounded : Icons.refresh_rounded,
              onPressed: _isRefreshing ? null : _refreshNotifications,
              requiresOnline: !_isOffline,
              offlineTooltip: AppStrings.cannotRefreshOffline,
            ),
        ],
      ),
      body: _buildNotificationsContent(provider),
      floatingActionButton: _showFAB && hasUnread
          ? ScaleTransition(
              scale: _fabAnimationController,
              child: Container(
                decoration: BoxDecoration(
                  gradient:
                      const LinearGradient(colors: AppColors.blueGradient),
                  borderRadius: BorderRadius.circular(
                      ResponsiveValues.radiusLarge(context)),
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
                  icon: Icon(Icons.mark_email_read_rounded,
                      size: ResponsiveValues.iconSizeS(context)),
                  label: Text(_isOffline
                      ? AppStrings.queueAllRead
                      : AppStrings.markAllRead),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusLarge(context)),
                  ),
                ).animate().fadeIn(duration: AppThemes.animationMedium),
              ),
            )
          : null,
    );
  }
}

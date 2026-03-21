// lib/screens/notifications/notification_screen.dart
// PRODUCTION STANDARD - PROPER EMPTY STATE & SHIMMER TYPE

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/notification_model.dart' as AppNotification;
import '../../providers/notification_provider.dart';
import '../../services/snackbar_service.dart';
import '../../widgets/common/base_screen_mixin.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_shimmer.dart';
import '../../widgets/common/app_dialog.dart';
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
    with BaseScreenMixin<NotificationsScreen>, TickerProviderStateMixin {
  bool _isInitialLoad = true;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();
  bool _showFAB = true;
  Timer? _scrollTimer;
  final int _pageSize = 20;
  bool _hasMore = true;

  late AnimationController _fabAnimationController;
  late NotificationProvider _provider;

  @override
  String get screenTitle => AppStrings.notifications;

  @override
  String? get screenSubtitle =>
      isOffline ? AppStrings.offlineMode : 'Inbox, alerts, and updates';

  @override
  bool get isLoading =>
      _isInitialLoad && _provider.isLoading && !_provider.isLoaded;

  @override
  bool get hasCachedData =>
      _provider.isLoaded && _provider.notifications.isNotEmpty;

  @override
  dynamic get errorMessage => _provider.errorMessage;

  // ✅ Shimmer type for notifications
  @override
  ShimmerType get shimmerType => ShimmerType.notificationCard;

  @override
  int get shimmerItemCount => 5;

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

    _fabAnimationController = AnimationController(
      vsync: this,
      duration: AppThemes.animationMedium,
    );

    _scrollController.addListener(() {
      if (_scrollTimer != null) _scrollTimer!.cancel();
      _scrollTimer = Timer(const Duration(milliseconds: 200), () {
        if (isMounted) {
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
        if (!_isLoadingMore && _hasMore && !isRefreshing && !isOffline) {
          _loadMoreNotifications();
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider = Provider.of<NotificationProvider>(context);

    if (_provider.notifications.isNotEmpty) {
      setState(() {
        _isInitialLoad = false;
        _hasMore = _provider.notifications.length >= _pageSize;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _scrollTimer?.cancel();
    _fabAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadMoreNotifications() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      await Future.delayed(const Duration(milliseconds: 500));
    } finally {
      if (isMounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  Future<void> onRefresh() async {
    await _provider.loadNotifications(
      forceRefresh: true,
      isManualRefresh: true,
    );
    _hasMore = _provider.notifications.length >= _pageSize;
    setState(() {
      _isInitialLoad = false;
    });
  }

  Future<void> _deleteNotification(
    AppNotification.Notification notification,
  ) async {
    try {
      AppDialog.showLoading(context, message: AppStrings.deleting);
      await _provider.deleteNotification(notification.logId);
      AppDialog.hideLoading(context);

      if (isOffline) {
        SnackbarService().showQueued(context, action: AppStrings.delete);
      } else {
        SnackbarService().showSuccess(context, AppStrings.notificationDeleted);
      }
    } catch (e) {
      AppDialog.hideLoading(context);
      SnackbarService().showError(
        context,
        AppStrings.failedToDeleteNotification,
      );
      if (!isOffline) {
        await _provider.loadNotifications(forceRefresh: true);
      }
    }
  }

  Color _getNotificationColor(AppNotification.Notification notification) {
    final title = notification.title.toLowerCase();
    if (title.contains('payment')) return AppColors.telegramGreen;
    if (title.contains('exam') || title.contains('result'))
      return AppColors.telegramYellow;
    if (title.contains('streak') || title.contains('progress'))
      return AppColors.telegramGreen;
    if (title.contains('expiring') || title.contains('expired'))
      return AppColors.telegramRed;
    if (title.contains('system') || title.contains('announcement'))
      return AppColors.telegramBlue;
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

  void _handleNotificationTap(AppNotification.Notification notification) {
    if (!notification.isRead) {
      _provider.markAsRead(notification.logId);
    }
    _showNotificationDetails(notification);
  }

  void _showNotificationDetails(AppNotification.Notification notification) {
    AppDialog.showBottomSheet(
      context: context,
      child: _buildNotificationDetails(notification),
    );
  }

  Widget _buildNotificationDetails(AppNotification.Notification notification) {
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
                      iconColor.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(
                    ResponsiveValues.radiusMedium(context),
                  ),
                ),
                child: Icon(
                  iconData,
                  size: ResponsiveValues.iconSizeXL(context),
                  color: iconColor,
                ),
              ),
              SizedBox(width: ResponsiveValues.spacingL(context)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: AppTextStyles.titleLarge(
                        context,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: ResponsiveValues.spacingXS(context)),
                    Text(
                      notification.timeAgo,
                      style: AppTextStyles.bodySmall(
                        context,
                      ).copyWith(color: AppColors.getTextSecondary(context)),
                    ),
                  ],
                ),
              ),
              if (!notification.isRead)
                AppButton.icon(
                  icon: Icons.mark_email_read_rounded,
                  onPressed: () {
                    _provider.markAsRead(notification.logId);
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
                    _deleteNotification(notification);
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

  void _showActionSheet(AppNotification.Notification notification) {
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
                child: const Icon(
                  Icons.delete_rounded,
                  color: AppColors.telegramRed,
                ),
              ),
            ),
            title: Text(
              AppStrings.delete,
              style: AppTextStyles.bodyLarge(
                context,
              ).copyWith(color: AppColors.telegramRed),
            ),
            onTap: () {
              Navigator.pop(context);
              _deleteNotification(notification);
            },
          ),
          if (!notification.isRead)
            ListTile(
              leading: AppCard.glass(
                child: Container(
                  width: ResponsiveValues.iconSizeXL(context),
                  height: ResponsiveValues.iconSizeXL(context),
                  padding: EdgeInsets.all(ResponsiveValues.spacingS(context)),
                  child: const Icon(
                    Icons.mark_email_read_rounded,
                    color: AppColors.telegramBlue,
                  ),
                ),
              ),
              title: Text(
                AppStrings.markAsRead,
                style: AppTextStyles.bodyLarge(
                  context,
                ).copyWith(color: AppColors.telegramBlue),
              ),
              onTap: () {
                _provider.markAsRead(notification.logId);
                Navigator.pop(context);
              },
            ),
          ListTile(
            leading: AppCard.glass(
              child: Container(
                width: ResponsiveValues.iconSizeXL(context),
                height: ResponsiveValues.iconSizeXL(context),
                padding: EdgeInsets.all(ResponsiveValues.spacingS(context)),
                child: Icon(
                  Icons.close_rounded,
                  color: AppColors.getTextSecondary(context),
                ),
              ),
            ),
            title: Text(
              AppStrings.cancel,
              style: AppTextStyles.bodyLarge(
                context,
              ).copyWith(color: AppColors.getTextSecondary(context)),
            ),
            onTap: () => Navigator.pop(context),
          ),
          SizedBox(height: ResponsiveValues.spacingL(context)),
        ],
      ),
    );
  }

  Future<bool> _showDeleteConfirmation(
    AppNotification.Notification notification,
  ) async {
    final result = await AppDialog.delete(
      context: context,
      title: AppStrings.deleteNotification,
      message: AppStrings.deleteNotificationConfirm,
    );

    if (result == true) {
      await _deleteNotification(notification);
    }
    return result ?? false;
  }

  void _showMarkAllAsReadDialog() {
    if (isOffline) {
      AppDialog.confirm(
        context: context,
        title: AppStrings.markAllAsRead,
        message: AppStrings.markAllAsReadOffline,
        confirmText: AppStrings.queue,
      ).then((confirmed) {
        if (confirmed == true) {
          _provider.markAllAsRead();
          SnackbarService().showQueued(
            context,
            action: AppStrings.markAllAsRead,
          );
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
        _provider.markAllAsRead();
        SnackbarService().showSuccess(
          context,
          AppStrings.allNotificationsMarkedRead,
        );
      }
    });
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
            style: AppTextStyles.titleLarge(
              context,
            ).copyWith(fontWeight: FontWeight.w800),
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

  Widget _buildHeroCard() {
    final unreadCount = _provider.unreadNotifications.length;
    final totalCount = _provider.notifications.length;
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
            borderRadius: BorderRadius.circular(
              ResponsiveValues.radiusLarge(context),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Stay on top of updates.',
                style: AppTextStyles.displaySmall(
                  context,
                ).copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.3),
              ),
              SizedBox(height: ResponsiveValues.spacingS(context)),
              Text(
                'Important account activity, study updates, and payment status all live here.',
                style: AppTextStyles.bodyMedium(
                  context,
                ).copyWith(color: AppColors.getTextSecondary(context)),
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
                        isOffline ? AppStrings.offlineMode : AppStrings.active,
                    icon: isOffline
                        ? Icons.wifi_off_rounded
                        : Icons.cloud_done_rounded,
                    color:
                        isOffline ? AppColors.warning : AppColors.telegramTeal,
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
        borderRadius: BorderRadius.circular(
          ResponsiveValues.radiusLarge(context),
        ),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: ResponsiveValues.iconSizeS(context)),
          SizedBox(height: ResponsiveValues.spacingS(context)),
          Text(
            value,
            style: AppTextStyles.titleLarge(
              context,
            ).copyWith(fontWeight: FontWeight.w800),
          ),
          Text(
            label,
            style: AppTextStyles.labelMedium(context).copyWith(color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(
    AppNotification.Notification notification,
    int index,
  ) {
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
          borderRadius: BorderRadius.circular(
            ResponsiveValues.radiusXLarge(context),
          ),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return _showDeleteConfirmation(notification);
      },
      onDismissed: (direction) {},
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: ResponsiveValues.spacingL(context),
          vertical: ResponsiveValues.spacingXS(context),
        ),
        child: AppCard.notification(
          isUnread: isUnread,
          isOffline: isOffline,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _handleNotificationTap(notification),
              onLongPress: () => _showActionSheet(notification),
              borderRadius: BorderRadius.circular(
                ResponsiveValues.radiusXLarge(context),
              ),
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
                        child: Icon(
                          iconData,
                          size: ResponsiveValues.iconSizeL(context),
                          color: iconColor,
                        ),
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
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.telegramRed.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.telegramRed
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    AppStrings.failed,
                                    style: AppTextStyles.statusBadge(
                                      context,
                                    ).copyWith(
                                      color: AppColors.telegramRed,
                                      fontSize: ResponsiveValues
                                          .fontNotificationBadge(
                                        context,
                                      ),
                                    ),
                                  ),
                                )
                              else if (notification.isPending)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.warning.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    AppStrings.pending,
                                    style: AppTextStyles.statusBadge(
                                      context,
                                    ).copyWith(
                                      color: AppColors.warning,
                                      fontSize: ResponsiveValues
                                          .fontNotificationBadge(
                                        context,
                                      ),
                                    ),
                                  ),
                                )
                              else if (!notification.isRead && !isOffline)
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
                                    AppStrings.new_,
                                    style: AppTextStyles.statusBadge(
                                      context,
                                    ).copyWith(
                                      color: AppColors.telegramBlue,
                                      fontSize: ResponsiveValues
                                          .fontNotificationBadge(
                                        context,
                                      ),
                                    ),
                                  ),
                                )
                              else if (isOffline && !notification.isRead)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.warning.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    AppStrings.pending,
                                    style: AppTextStyles.statusBadge(
                                      context,
                                    ).copyWith(
                                      color: AppColors.warning,
                                      fontSize: ResponsiveValues
                                          .fontNotificationBadge(
                                        context,
                                      ),
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
        .fadeIn(duration: AppThemes.animationMedium, delay: (index * 30).ms)
        .slideX(
          begin: -0.1,
          end: 0,
          duration: AppThemes.animationMedium,
          delay: (index * 30).ms,
        );
  }

  @override
  Widget buildContent(BuildContext context) {
    final unreadNotifications = _provider.unreadNotifications;
    final readNotifications = _provider.readNotifications;
    final visibleNotifications =
        unreadNotifications.length + readNotifications.length;

    // ✅ PROPER EMPTY STATE - matches HomeScreen pattern
    final shouldShowEmpty = visibleNotifications == 0 &&
        (_provider.isLoaded || !_provider.isLoading);

    if (shouldShowEmpty) {
      return Center(
        child: buildEmptyWidget(
          dataType: AppStrings.notifications,
          customMessage: isOffline
              ? AppStrings.noCachedNotificationsAvailable
              : AppStrings.notificationsWillAppearHere,
          isOffline: isOffline,
        ),
      );
    }

    return CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (isOffline && pendingCount > 0)
          SliverToBoxAdapter(
            child: Container(
              margin: EdgeInsets.all(ResponsiveValues.spacingM(context)),
              padding: ResponsiveValues.cardPadding(context),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.info.withValues(alpha: 0.2),
                    AppColors.info.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(
                  ResponsiveValues.radiusMedium(context),
                ),
                border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    color: AppColors.info,
                    size: ResponsiveValues.iconSizeS(context),
                  ),
                  SizedBox(width: ResponsiveValues.spacingM(context)),
                  Expanded(
                    child: Text(
                      AppStrings.pendingActionsSyncLabel(pendingCount),
                      style: AppTextStyles.bodySmall(
                        context,
                      ).copyWith(color: AppColors.info),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (unreadNotifications.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _buildSectionHeader(
              AppStrings.unread,
              unreadNotifications.length,
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) =>
                  _buildNotificationItem(unreadNotifications[index], index),
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
                index + (unreadNotifications.length),
              ),
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
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.telegramBlue,
                    ),
                  ),
                ),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: SizedBox(height: ResponsiveValues.spacingXXXL(context)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: buildAppBar(),
      body: RefreshIndicator(
        onRefresh: onRefresh,
        color: AppColors.telegramBlue,
        backgroundColor: AppColors.getSurface(context),
        child: buildContent(context),
      ),
      floatingActionButton: _showFAB && _provider.unreadNotifications.isNotEmpty
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
                  onPressed: _showMarkAllAsReadDialog,
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  icon: Icon(
                    Icons.mark_email_read_rounded,
                    size: ResponsiveValues.iconSizeS(context),
                  ),
                  label: Text(
                    isOffline
                        ? AppStrings.queueAllRead
                        : AppStrings.markAllRead,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      ResponsiveValues.radiusLarge(context),
                    ),
                  ),
                ).animate().fadeIn(duration: AppThemes.animationMedium),
              ),
            )
          : null,
    );
  }
}

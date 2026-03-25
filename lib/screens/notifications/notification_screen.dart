import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/notification_model.dart' as AppNotification;
import '../../providers/notification_provider.dart';
import '../../services/snackbar_service.dart';
import '../../widgets/common/base_screen_mixin.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_dialog.dart';
import '../../themes/app_themes.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/responsive_values.dart';
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
  bool _providerBound = false;

  @override
  String get screenTitle => AppStrings.notifications;

  @override
  String? get screenSubtitle =>
      isOffline ? AppStrings.offlineMode : null;

  @override
  bool get showNotification => false;

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
  List<Widget>? get appBarActions => _providerBound &&
          _provider.notifications.isNotEmpty
      ? [
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert_rounded,
              color: AppColors.getTextPrimary(context),
            ),
            onSelected: (value) {
              switch (value) {
                case 'mark_all_read':
                  _showMarkAllAsReadDialog();
                  break;
                case 'delete_all':
                  _showDeleteAllDialog();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'mark_all_read',
                child: Row(
                  children: [
                    const Icon(Icons.mark_email_read_rounded, size: 18),
                    SizedBox(width: ResponsiveValues.spacingS(context)),
                    Expanded(
                      child: Text(
                        isOffline
                            ? AppStrings.queueAllRead
                            : AppStrings.markAllRead,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'delete_all',
                child: Row(
                  children: [
                    const Icon(
                      Icons.delete_sweep_rounded,
                      size: 18,
                      color: AppColors.telegramRed,
                    ),
                    SizedBox(width: ResponsiveValues.spacingS(context)),
                    const Expanded(
                      child: Text(
                        AppStrings.deleteAll,
                        style: TextStyle(color: AppColors.telegramRed),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ]
      : null;

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
    if (_providerBound) return;

    _provider = context.read<NotificationProvider>();
    _provider.addListener(_handleProviderChanged);
    _providerBound = true;

    _handleProviderChanged();

    if (!_provider.isLoaded &&
        _provider.notifications.isEmpty &&
        !_provider.isLoading &&
        !isOffline) {
      unawaited(_loadInitialNotifications());
    }
  }

  void _handleProviderChanged() {
    if (!isMounted) return;

    final hasNotifications = _provider.notifications.isNotEmpty;
    setState(() {
      _hasMore = _provider.notifications.length >= _pageSize;
      if (!hasNotifications) {
        _isLoadingMore = false;
      }
    });
  }

  Future<void> _loadInitialNotifications() async {
    if (!isMounted) return;

    setState(() {
      _isInitialLoad = true;
    });

    try {
      await _provider.loadNotifications();
    } finally {
      if (isMounted) {
        setState(() {
          _isInitialLoad = false;
          _hasMore = _provider.notifications.length >= _pageSize;
        });
      }
    }
  }

  @override
  void dispose() {
    if (_providerBound) {
      _provider.removeListener(_handleProviderChanged);
    }
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

  DateTime _notificationMoment(AppNotification.Notification notification) {
    return notification.primaryTimestamp;
  }

  String _formatNotificationTimestamp(AppNotification.Notification notification) {
    final timestamp = _notificationMoment(notification);
    return DateFormat('MMM d, yyyy • h:mm a').format(timestamp);
  }

  String _notificationCategoryLabel(AppNotification.Notification notification) {
    final title = notification.title.toLowerCase();
    if (title.contains('payment') || title.contains('subscription')) {
      return 'Payment';
    }
    if (title.contains('exam')) return 'Exam';
    if (title.contains('video')) return 'Video';
    if (title.contains('note')) return 'Note';
    if (title.contains('chapter')) return 'Chapter';
    if (title.contains('streak') || title.contains('progress')) return 'Progress';
    if (title.contains('motivation') || title.contains('reminder')) return 'Reminder';
    return 'Notification';
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: ResponsiveValues.iconSizeXXL(context) * 1.3,
                    height: ResponsiveValues.iconSizeXXL(context) * 1.3,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
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
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: ResponsiveValues.spacingXS(context)),
                        Text(
                          notification.timeAgo,
                          style: AppTextStyles.bodySmall(context).copyWith(
                            color: AppColors.getTextSecondary(context),
                          ),
                        ),
                        SizedBox(height: ResponsiveValues.spacingXS(context)),
                        Text(
                          _formatNotificationTimestamp(notification),
                          style: AppTextStyles.bodySmall(context).copyWith(
                            color: AppColors.getTextSecondary(context)
                                .withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: ResponsiveValues.spacingM(context)),
              Wrap(
                spacing: ResponsiveValues.spacingS(context),
                runSpacing: ResponsiveValues.spacingS(context),
                children: [
                  _buildDetailPill(
                    icon: Icons.sell_rounded,
                    label: _notificationCategoryLabel(notification),
                    color: AppColors.telegramBlue,
                  ),
                  _buildDetailPill(
                    icon: notification.isRead
                        ? Icons.drafts_rounded
                        : Icons.mark_email_unread_rounded,
                    label: notification.isRead ? 'Read' : 'Unread',
                    color: notification.isRead
                        ? AppColors.telegramGray
                        : AppColors.telegramBlue,
                  ),
                  _buildDetailPill(
                    icon: notification.isPending
                        ? Icons.schedule_rounded
                        : Icons.notifications_active_rounded,
                    label: notification.isPending
                        ? 'Queued'
                        : (notification.isFailed ? 'Failed' : 'Delivered'),
                    color: notification.isPending
                        ? AppColors.warning
                        : (notification.isFailed
                            ? AppColors.telegramRed
                            : AppColors.telegramGreen),
                  ),
                ],
              ),
            ],
          ),
        ),
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.35,
            ),
            child: SingleChildScrollView(
              padding: ResponsiveValues.screenPadding(context),
              child: Container(
                width: double.infinity,
                padding: ResponsiveValues.cardPadding(context),
                decoration: BoxDecoration(
                  color: AppColors.getSurface(context).withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(
                    ResponsiveValues.radiusLarge(context),
                  ),
                ),
                child: Text(
                  notification.message,
                  style: AppTextStyles.bodyLarge(context).copyWith(height: 1.6),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: ResponsiveValues.screenPadding(context),
          child: Row(
            children: [
              if (!notification.isRead) ...[
                Expanded(
                  child: AppButton.glass(
                    label: AppStrings.markAsRead,
                    icon: Icons.mark_email_read_rounded,
                    onPressed: () {
                      _provider.markAsRead(notification.logId);
                      Navigator.pop(context);
                    },
                    expanded: true,
                  ),
                ),
                SizedBox(width: ResponsiveValues.spacingM(context)),
              ],
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

  Widget _buildDetailPill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final pillBackground = color.withValues(alpha: 0.18);
    final pillBorder = color.withValues(alpha: 0.36);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveValues.spacingM(context),
        vertical: ResponsiveValues.spacingS(context),
      ),
      decoration: BoxDecoration(
        color: pillBackground,
        borderRadius:
            BorderRadius.circular(ResponsiveValues.radiusLarge(context)),
        border: Border.all(color: pillBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: ResponsiveValues.iconSizeS(context), color: color),
          SizedBox(width: ResponsiveValues.spacingXS(context)),
          Text(
            label,
            style: AppTextStyles.labelSmall(context).copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  void _showActionSheet(AppNotification.Notification notification) {
    AppDialog.showBottomSheet(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Container(
              width: ResponsiveValues.iconSizeXL(context),
              height: ResponsiveValues.iconSizeXL(context),
              decoration: BoxDecoration(
                color: AppColors.telegramRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(
                  ResponsiveValues.radiusMedium(context),
                ),
              ),
              padding: EdgeInsets.all(ResponsiveValues.spacingS(context)),
              child: const Icon(
                Icons.delete_rounded,
                color: AppColors.telegramRed,
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
              leading: Container(
                width: ResponsiveValues.iconSizeXL(context),
                height: ResponsiveValues.iconSizeXL(context),
                decoration: BoxDecoration(
                  color: AppColors.telegramBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(
                    ResponsiveValues.radiusMedium(context),
                  ),
                ),
                padding: EdgeInsets.all(ResponsiveValues.spacingS(context)),
                child: const Icon(
                  Icons.mark_email_read_rounded,
                  color: AppColors.telegramBlue,
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
            leading: Container(
              width: ResponsiveValues.iconSizeXL(context),
              height: ResponsiveValues.iconSizeXL(context),
              decoration: BoxDecoration(
                color: AppColors.getSurface(context),
                borderRadius: BorderRadius.circular(
                  ResponsiveValues.radiusMedium(context),
                ),
              ),
              padding: EdgeInsets.all(ResponsiveValues.spacingS(context)),
              child: Icon(
                Icons.close_rounded,
                color: AppColors.getTextSecondary(context),
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

  void _showDeleteAllDialog() {
    if (isOffline) {
      SnackbarService().showOffline(context, action: AppStrings.deleteAll);
      return;
    }

    AppDialog.delete(
      context: context,
      title: AppStrings.deleteAllNotifications,
      message: AppStrings.deleteAllNotificationsConfirm,
    ).then((confirmed) async {
      if (confirmed == true) {
        try {
          AppDialog.showLoading(context, message: AppStrings.deleting);
          await _provider.deleteAllNotifications();
          AppDialog.hideLoading(context);
          SnackbarService().showSuccess(
            context,
            AppStrings.allNotificationsDeleted,
          );
        } catch (e) {
          AppDialog.hideLoading(context);
          SnackbarService().showError(
            context,
            AppStrings.failedToDeleteNotification,
          );
          await _provider.loadNotifications(forceRefresh: true);
        }
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
          Text(
            title,
            style: AppTextStyles.titleSmall(context).copyWith(
              color: AppColors.getTextSecondary(context),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(width: ResponsiveValues.spacingS(context)),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveValues.spacingS(context),
              vertical: ResponsiveValues.spacingXXS(context),
            ),
            decoration: BoxDecoration(
              color: AppColors.telegramBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(
                ResponsiveValues.radiusFull(context),
              ),
            ),
            child: Text(
              '$count',
              style: AppTextStyles.labelSmall(context).copyWith(
                color: AppColors.telegramBlue,
                fontWeight: FontWeight.w700,
              ),
            ),
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
                      width:
                          ResponsiveValues.featureCardIconContainerSize(
                              context),
                      height:
                          ResponsiveValues.featureCardIconContainerSize(
                              context),
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
                                  margin: EdgeInsets.only(
                                    left: ResponsiveValues.spacingXXS(context),
                                  ),
                                  decoration: const BoxDecoration(
                                    color: AppColors.telegramBlue,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: ResponsiveValues.spacingXXS(context)),
                          Text(
                            notification.message,
                            style: AppTextStyles.bodySmall(context).copyWith(
                              color: AppColors.getTextSecondary(context),
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: ResponsiveValues.spacingS(context)),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: ResponsiveValues.iconSizeXXS(context),
                                color: AppColors.getTextSecondary(context)
                                    .withValues(alpha: 0.5),
                              ),
                              SizedBox(
                                width: ResponsiveValues.spacingXXS(context),
                              ),
                              Text(
                                timeText,
                                style: AppTextStyles.caption(context).copyWith(
                                  color: AppColors.getTextSecondary(context)
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _formatNotificationTimestamp(notification),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.caption(context).copyWith(
                                    color: AppColors.getTextSecondary(context)
                                        .withValues(alpha: 0.45),
                                  ),
                                  textAlign: TextAlign.end,
                                ),
                              ),
                              if (notification.isFailed)
                                Padding(
                                  padding: EdgeInsets.only(
                                    left: ResponsiveValues.spacingS(context),
                                  ),
                                  child: _buildStatusBadge(
                                    label: AppStrings.failed,
                                    color: AppColors.telegramRed,
                                  ),
                                )
                              else if (!notification.isRead && !isOffline)
                                Padding(
                                  padding: EdgeInsets.only(
                                    left: ResponsiveValues.spacingS(context),
                                  ),
                                  child: _buildStatusBadge(
                                    label: AppStrings.new_,
                                    color: AppColors.telegramBlue,
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

  Widget _buildStatusBadge({
    required String label,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveValues.spacingS(context),
        vertical: ResponsiveValues.spacingXXS(context),
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(
          ResponsiveValues.radiusLarge(context),
        ),
        border: Border.all(
          color: color.withValues(alpha: 0.38),
        ),
      ),
      child: Text(
        label,
        style: AppTextStyles.statusBadge(context).copyWith(
          color: color,
          fontSize: ResponsiveValues.fontNotificationBadge(context),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget buildContent(BuildContext context) {
    final unreadNotifications = _provider.unreadNotifications;
    final readNotifications = _provider.readNotifications;
    final visibleNotifications =
        unreadNotifications.length + readNotifications.length;

    // ✅ PROPER EMPTY STATE - matches HomeScreen pattern
    final shouldShowEmpty = !_isInitialLoad &&
        visibleNotifications == 0 &&
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

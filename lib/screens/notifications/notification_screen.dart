import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:familyacademyclient/models/notification_model.dart'
    as AppNotification;
import 'package:familyacademyclient/utils/responsive.dart';
import '../../providers/notification_provider.dart';
import '../../themes/app_themes.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/empty_state.dart';
import '../../utils/helpers.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with TickerProviderStateMixin {
  bool _isInitialLoad = true;
  bool _isRefreshing = false;
  final ScrollController _scrollController = ScrollController();
  bool _showFAB = true;
  Timer? _scrollTimer;

  late AnimationController _fabAnimationController;

  @override
  void initState() {
    super.initState();

    _fabAnimationController = AnimationController(
      vsync: this,
      duration: AppThemes.animationDurationMedium,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNotifications();
    });

    _scrollController.addListener(() {
      if (_scrollTimer != null) {
        _scrollTimer!.cancel();
      }
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
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _scrollTimer?.cancel();
    _fabAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    final provider = Provider.of<NotificationProvider>(context, listen: false);
    if (_isInitialLoad) {
      setState(() => _isRefreshing = true);
      try {
        await provider.loadNotifications();
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

    setState(() => _isRefreshing = true);
    final provider = Provider.of<NotificationProvider>(context, listen: false);
    try {
      await provider.loadNotifications(forceRefresh: true);
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Widget _buildMobileNotifications() {
    final provider = Provider.of<NotificationProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: AppTextStyles.appBarTitle.copyWith(
            color: AppColors.getTextPrimary(context),
          ),
        ),
        centerTitle: false,
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: AppColors.getTextPrimary(context),
          ),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (provider.unreadNotifications.isNotEmpty)
            Container(
              margin: EdgeInsets.only(right: AppThemes.spacingXS),
              child: IconButton(
                icon: Icon(
                  Icons.mark_email_read_rounded,
                  color: AppColors.telegramBlue,
                ),
                onPressed: () => _showMarkAllAsReadDialog(context, provider),
                tooltip: 'Mark all as read',
              ),
            ),
          IconButton(
            icon: _isRefreshing
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.telegramBlue,
                      ),
                    ),
                  )
                : Icon(
                    Icons.refresh_rounded,
                    color: AppColors.telegramBlue,
                  ),
            onPressed: _isRefreshing ? null : _refreshNotifications,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildNotificationsContent(provider),
      floatingActionButton: _showFAB && provider.unreadNotifications.isNotEmpty
          ? ScaleTransition(
              scale: _fabAnimationController,
              child: FloatingActionButton.extended(
                onPressed: () => _showMarkAllAsReadDialog(context, provider),
                backgroundColor: AppColors.telegramBlue,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.mark_email_read_rounded, size: 20),
                label: const Text('Mark all read'),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppThemes.borderRadiusLarge),
                ),
              ).animate().fadeIn(
                    duration: AppThemes.animationDurationMedium,
                  ),
            )
          : null,
    );
  }

  Widget _buildNotificationsContent(NotificationProvider provider) {
    if (_isInitialLoad && provider.isLoading) {
      return Center(
        child: LoadingIndicator(
          message: 'Loading notifications...',
          type: LoadingType.circular,
          color: AppColors.telegramBlue,
        ),
      );
    }

    if (provider.error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(AppThemes.spacingXL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(AppThemes.spacingXL),
                decoration: BoxDecoration(
                  color: AppColors.telegramRed.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: AppColors.telegramRed,
                ),
              ),
              SizedBox(height: AppThemes.spacingXL),
              Text(
                'Failed to Load',
                style: AppTextStyles.titleLarge.copyWith(
                  color: AppColors.getTextPrimary(context),
                ),
              ),
              SizedBox(height: AppThemes.spacingM),
              Text(
                provider.error!,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.getTextSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppThemes.spacingXL),
              ElevatedButton(
                onPressed: _refreshNotifications,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.telegramBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppThemes.borderRadiusMedium),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: AppThemes.spacingXL,
                    vertical: AppThemes.spacingM,
                  ),
                ),
                child: Text('Try Again', style: AppTextStyles.buttonMedium),
              ),
            ],
          ),
        ),
      );
    }

    if (provider.notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(AppThemes.spacingXL),
              decoration: BoxDecoration(
                color: AppColors.telegramGray.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_off_rounded,
                size: 48,
                color: AppColors.telegramGray,
              ),
            ),
            SizedBox(height: AppThemes.spacingXL),
            Text(
              'No Notifications',
              style: AppTextStyles.titleLarge.copyWith(
                color: AppColors.getTextPrimary(context),
              ),
            ),
            SizedBox(height: AppThemes.spacingM),
            Text(
              'You\'ll see notifications here\nwhen you receive them.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.getTextSecondary(context),
              ),
            ),
            SizedBox(height: AppThemes.spacingXL),
            ElevatedButton(
              onPressed: _refreshNotifications,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.telegramBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppThemes.borderRadiusMedium),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: AppThemes.spacingXL,
                  vertical: AppThemes.spacingM,
                ),
              ),
              child: Text('Refresh', style: AppTextStyles.buttonMedium),
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
          SliverToBoxAdapter(child: SizedBox(height: AppThemes.spacingS)),

          // Unread section
          if (unreadNotifications.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _buildSectionHeader('Unread', unreadNotifications.length),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final notification = unreadNotifications[index];
                  return _buildNotificationItem(notification, provider, index);
                },
                childCount: unreadNotifications.length,
              ),
            ),
          ],

          // Read section
          if (readNotifications.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                unreadNotifications.isEmpty ? 'Notifications' : 'Earlier',
                readNotifications.length,
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final notification = readNotifications[index];
                  return _buildNotificationItem(
                    notification,
                    provider,
                    index + (unreadNotifications.length),
                  );
                },
                childCount: readNotifications.length,
              ),
            ),
          ],

          SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppThemes.spacingL,
        AppThemes.spacingL,
        AppThemes.spacingL,
        AppThemes.spacingS,
      ),
      child: Row(
        children: [
          Text(
            title,
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.getTextSecondary(context),
            ),
          ),
          SizedBox(width: AppThemes.spacingM),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppThemes.spacingS,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: AppColors.telegramBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppThemes.borderRadiusFull),
            ),
            child: Text(
              count.toString(),
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.telegramBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(
    AppNotification.Notification notification,
    NotificationProvider provider,
    int index,
  ) {
    final isUnread = !notification.isRead;
    final iconData = _getNotificationIcon(notification);
    final iconColor = _getNotificationColor(notification);
    final timeText = notification.timeAgo;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppThemes.spacingL,
        vertical: 4,
      ),
      child: Material(
        color: isUnread
            ? AppColors.telegramBlue.withOpacity(0.03)
            : AppColors.getCard(context),
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
        child: InkWell(
          onTap: () => _handleNotificationTap(notification, provider),
          onLongPress: () => _showActionSheet(context, notification, provider),
          borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
          child: Container(
            padding: EdgeInsets.all(AppThemes.spacingL),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius:
                        BorderRadius.circular(AppThemes.borderRadiusMedium),
                  ),
                  child: Icon(
                    iconData,
                    size: 24,
                    color: iconColor,
                  ),
                ),

                SizedBox(width: AppThemes.spacingL),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: AppTextStyles.titleSmall.copyWith(
                                fontWeight: isUnread
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: AppColors.getTextPrimary(context),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isUnread)
                            Container(
                              width: 8,
                              height: 8,
                              margin:
                                  EdgeInsets.only(left: AppThemes.spacingXS),
                              decoration: BoxDecoration(
                                color: AppColors.telegramBlue,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),

                      SizedBox(height: AppThemes.spacingXS),

                      Text(
                        notification.message,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.getTextSecondary(context),
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      SizedBox(height: AppThemes.spacingM),

                      // Time and actions row
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 12,
                            color: AppColors.getTextSecondary(context)
                                .withOpacity(0.5),
                          ),
                          SizedBox(width: 4),
                          Text(
                            timeText,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.getTextSecondary(context)
                                  .withOpacity(0.5),
                            ),
                          ),
                          Spacer(),
                          if (!notification.isRead)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: AppThemes.spacingS,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.telegramBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(
                                    AppThemes.borderRadiusFull),
                              ),
                              child: Text(
                                'NEW',
                                style: AppTextStyles.statusBadge.copyWith(
                                  color: AppColors.telegramBlue,
                                  fontSize: 8,
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
    )
        .animate()
        .fadeIn(
          duration: AppThemes.animationDurationMedium,
          delay: (index * 30).ms,
        )
        .slideX(
          begin: -0.1,
          end: 0,
          duration: AppThemes.animationDurationMedium,
          delay: (index * 30).ms,
        );
  }

  Color _getNotificationColor(AppNotification.Notification notification) {
    final title = notification.title.toLowerCase();

    if (title.contains('payment')) {
      return AppColors.telegramGreen;
    } else if (title.contains('exam') || title.contains('result')) {
      return AppColors.telegramYellow;
    } else if (title.contains('streak') || title.contains('progress')) {
      return AppColors.telegramGreen;
    } else if (title.contains('expiring') || title.contains('expired')) {
      return AppColors.telegramRed;
    } else if (title.contains('system') || title.contains('announcement')) {
      return AppColors.telegramBlue;
    }
    return AppColors.telegramBlue;
  }

  IconData _getNotificationIcon(AppNotification.Notification notification) {
    final title = notification.title.toLowerCase();

    if (title.contains('payment')) {
      return Icons.payment_rounded;
    } else if (title.contains('exam')) {
      return Icons.assignment_rounded;
    } else if (title.contains('streak')) {
      return Icons.local_fire_department_rounded;
    } else if (title.contains('expiring')) {
      return Icons.timer_rounded;
    } else if (title.contains('system')) {
      return Icons.announcement_rounded;
    } else if (title.contains('result')) {
      return Icons.assessment_rounded;
    }
    return Icons.notifications_rounded;
  }

  void _handleNotificationTap(
    AppNotification.Notification notification,
    NotificationProvider provider,
  ) {
    if (!notification.isRead) {
      provider.markAsRead(notification.logId);
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildNotificationDetails(notification, provider),
    );
  }

  Widget _buildNotificationDetails(
    AppNotification.Notification notification,
    NotificationProvider provider,
  ) {
    final iconData = _getNotificationIcon(notification);
    final iconColor = _getNotificationColor(notification);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.getCard(context),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppThemes.borderRadiusLarge),
        ),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.symmetric(vertical: AppThemes.spacingM),
                decoration: BoxDecoration(
                  color: AppColors.getTextSecondary(context).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppThemes.spacingL),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.1),
                        borderRadius:
                            BorderRadius.circular(AppThemes.borderRadiusMedium),
                      ),
                      child: Icon(
                        iconData,
                        size: 28,
                        color: iconColor,
                      ),
                    ),
                    SizedBox(width: AppThemes.spacingL),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notification.title,
                            style: AppTextStyles.titleLarge.copyWith(
                              color: AppColors.getTextPrimary(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: AppThemes.spacingXS),
                          Text(
                            notification.timeAgo,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.getTextSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!notification.isRead)
                      IconButton(
                        icon: Icon(
                          Icons.mark_email_read_rounded,
                          color: AppColors.telegramBlue,
                        ),
                        onPressed: () {
                          provider.markAsRead(notification.logId);
                          Navigator.pop(context);
                        },
                      ),
                  ],
                ),
              ),

              Divider(
                color: Theme.of(context).dividerColor,
                height: AppThemes.spacingL,
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: EdgeInsets.all(AppThemes.spacingL),
                  child: Text(
                    notification.message,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.getTextPrimary(context),
                      height: 1.6,
                    ),
                  ),
                ),
              ),

              // Close button
              Padding(
                padding: EdgeInsets.all(AppThemes.spacingL),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.telegramBlue,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        vertical: AppThemes.spacingL,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppThemes.borderRadiusMedium),
                      ),
                    ),
                    child: Text(
                      'Close',
                      style: AppTextStyles.buttonMedium.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
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
    NotificationProvider provider,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.getCard(context),
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppThemes.borderRadiusLarge),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.symmetric(vertical: AppThemes.spacingM),
              decoration: BoxDecoration(
                color: AppColors.getTextSecondary(context).withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.telegramRed.withOpacity(0.1),
                  borderRadius:
                      BorderRadius.circular(AppThemes.borderRadiusMedium),
                ),
                child: Icon(
                  Icons.delete_rounded,
                  color: AppColors.telegramRed,
                ),
              ),
              title: Text(
                'Delete',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.telegramRed,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(context, notification, provider);
              },
            ),
            if (!notification.isRead)
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.telegramBlue.withOpacity(0.1),
                    borderRadius:
                        BorderRadius.circular(AppThemes.borderRadiusMedium),
                  ),
                  child: Icon(
                    Icons.mark_email_read_rounded,
                    color: AppColors.telegramBlue,
                  ),
                ),
                title: Text(
                  'Mark as read',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.telegramBlue,
                  ),
                ),
                onTap: () {
                  provider.markAsRead(notification.logId);
                  Navigator.pop(context);
                },
              ),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.getTextSecondary(context).withOpacity(0.1),
                  borderRadius:
                      BorderRadius.circular(AppThemes.borderRadiusMedium),
                ),
                child: Icon(
                  Icons.close_rounded,
                  color: AppColors.getTextSecondary(context),
                ),
              ),
              title: Text(
                'Cancel',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.getTextSecondary(context),
                ),
              ),
              onTap: () => Navigator.pop(context),
            ),
            SizedBox(height: AppThemes.spacingM),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    AppNotification.Notification notification,
    NotificationProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.getCard(context),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
        ),
        child: Padding(
          padding: EdgeInsets.all(AppThemes.spacingXL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.telegramRed.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete_rounded,
                  color: AppColors.telegramRed,
                  size: 24,
                ),
              ),
              SizedBox(height: AppThemes.spacingL),
              Text(
                'Delete notification',
                style: AppTextStyles.titleLarge.copyWith(
                  color: AppColors.getTextPrimary(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: AppThemes.spacingM),
              Text(
                'Are you sure you want to delete this notification?',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.getTextSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppThemes.spacingXL),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.getTextSecondary(context),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              AppThemes.borderRadiusMedium),
                        ),
                        padding:
                            EdgeInsets.symmetric(vertical: AppThemes.spacingM),
                      ),
                      child: Text('Cancel', style: AppTextStyles.buttonMedium),
                    ),
                  ),
                  SizedBox(width: AppThemes.spacingM),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        provider.deleteNotification(notification.logId);
                        Navigator.pop(context);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Notification deleted'),
                            backgroundColor: AppColors.telegramGreen,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppThemes.borderRadiusMedium),
                            ),
                            margin: EdgeInsets.all(AppThemes.spacingL),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.telegramRed,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              AppThemes.borderRadiusMedium),
                        ),
                        padding:
                            EdgeInsets.symmetric(vertical: AppThemes.spacingM),
                      ),
                      child: Text('Delete', style: AppTextStyles.buttonMedium),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMarkAllAsReadDialog(
    BuildContext context,
    NotificationProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.getCard(context),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
        ),
        child: Padding(
          padding: EdgeInsets.all(AppThemes.spacingXL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.telegramBlue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mark_email_read_rounded,
                  color: AppColors.telegramBlue,
                  size: 24,
                ),
              ),
              SizedBox(height: AppThemes.spacingL),
              Text(
                'Mark all as read',
                style: AppTextStyles.titleLarge.copyWith(
                  color: AppColors.getTextPrimary(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: AppThemes.spacingM),
              Text(
                'Mark all notifications as read?',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.getTextSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppThemes.spacingXL),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.getTextSecondary(context),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              AppThemes.borderRadiusMedium),
                        ),
                        padding:
                            EdgeInsets.symmetric(vertical: AppThemes.spacingM),
                      ),
                      child: Text('Cancel', style: AppTextStyles.buttonMedium),
                    ),
                  ),
                  SizedBox(width: AppThemes.spacingM),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        provider.markAllAsRead();
                        Navigator.pop(context);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('All notifications marked as read'),
                            backgroundColor: AppColors.telegramGreen,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppThemes.borderRadiusMedium),
                            ),
                            margin: EdgeInsets.all(AppThemes.spacingL),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.telegramBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              AppThemes.borderRadiusMedium),
                        ),
                        padding:
                            EdgeInsets.symmetric(vertical: AppThemes.spacingM),
                      ),
                      child:
                          Text('Mark all', style: AppTextStyles.buttonMedium),
                    ),
                  ),
                ],
              ),
            ],
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
      animateTransition: true,
    );
  }
}

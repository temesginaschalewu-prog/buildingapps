import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:familyacademyclient/models/notification_model.dart'
    as AppNotification;
import 'package:familyacademyclient/utils/responsive.dart';
import 'package:shimmer/shimmer.dart';
import '../../providers/notification_provider.dart';
import '../../themes/app_themes.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/helpers.dart';

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
  final ScrollController _scrollController = ScrollController();
  bool _showFAB = true;
  Timer? _scrollTimer;
  int _page = 1;
  final int _pageSize = 20;
  bool _hasMore = true;

  late AnimationController _fabAnimationController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _fabAnimationController = AnimationController(
        vsync: this, duration: AppThemes.animationDurationMedium);

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadNotifications());

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

      // Load more when scrolling near bottom
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        if (!_isLoadingMore && _hasMore && !_isRefreshing) {
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
    super.dispose();
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

  Widget _buildSkeletonLoader() {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Shimmer.fromColors(
          baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
          highlightColor: Colors.grey[100]!.withValues(alpha: 0.6),
          child: Container(
            width: 150,
            height: 24,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildGlassContainer(
            child: Padding(
              padding: const EdgeInsets.all(16),
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
                          highlightColor: Colors.grey[100]!.withValues(alpha: 0.6),
                          child: Container(
                            height: 20,
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
                          highlightColor: Colors.grey[100]!.withValues(alpha: 0.6),
                          child: Container(
                            height: 16,
                            width: 200,
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
            ),
          ),
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshUnreadCount();
    }
  }

  Future<void> _loadNotifications() async {
    final provider = Provider.of<NotificationProvider>(context, listen: false);
    if (_isInitialLoad) {
      setState(() => _isRefreshing = true);
      try {
        await provider.loadNotifications(forceRefresh: true);
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

    setState(() => _isRefreshing = true);
    final provider = Provider.of<NotificationProvider>(context, listen: false);
    try {
      await provider.loadNotifications(forceRefresh: true);
      _page = 1;
      _hasMore = provider.notifications.length >= _pageSize;
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _loadMoreNotifications() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);
    final provider = Provider.of<NotificationProvider>(context, listen: false);
    try {
      // Implement pagination in your provider if needed
      // await provider.loadMoreNotifications(page: _page + 1);
      _page++;
      // _hasMore = provider.hasMore;
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
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      await provider.deleteNotification(notification.logId);

      if (mounted) {
        Navigator.of(context).pop(); // Remove loading dialog
        showTopSnackBar(context, 'Notification deleted');
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Remove loading dialog
        showTopSnackBar(context, 'Failed to delete notification',
            isError: true);
        // Force refresh to sync with backend
        await provider.loadNotifications(forceRefresh: true);
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
        title: Text('Notifications',
            style: AppTextStyles.appBarTitle
                .copyWith(color: AppColors.getTextPrimary(context))),
        centerTitle: false,
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded,
                color: AppColors.getTextPrimary(context)),
            onPressed: () => context.pop()),
        actions: [
          if (provider.unreadNotifications.isNotEmpty)
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
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.telegramBlue)))
                : const Icon(Icons.refresh_rounded, color: AppColors.telegramBlue),
            onPressed: _isRefreshing ? null : _refreshNotifications,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildNotificationsContent(provider),
      floatingActionButton: _showFAB && provider.unreadNotifications.isNotEmpty
          ? ScaleTransition(
              scale: _fabAnimationController,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2AABEE), Color(0xFF5856D6)],
                  ),
                  borderRadius:
                      BorderRadius.circular(AppThemes.borderRadiusLarge),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.telegramBlue.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
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
                      borderRadius:
                          BorderRadius.circular(AppThemes.borderRadiusLarge)),
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
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildGlassContainer(
                child: Container(
                  padding: const EdgeInsets.all(24),
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
              const SizedBox(height: 24),
              Text('Failed to Load',
                  style: AppTextStyles.titleLarge
                      .copyWith(color: AppColors.getTextPrimary(context))),
              const SizedBox(height: 16),
              Text(provider.error!,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.getTextSecondary(context)),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2AABEE), Color(0xFF5856D6)],
                  ),
                  borderRadius:
                      BorderRadius.circular(AppThemes.borderRadiusMedium),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.telegramBlue.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _refreshNotifications,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                            AppThemes.borderRadiusMedium)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  child: const Text('Try Again'),
                ),
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
            _buildGlassContainer(
              child: Container(
                padding: const EdgeInsets.all(24),
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
            const SizedBox(height: 24),
            Text('No Notifications',
                style: AppTextStyles.titleLarge
                    .copyWith(color: AppColors.getTextPrimary(context))),
            const SizedBox(height: 16),
            Text('You\'ll see notifications here\nwhen you receive them.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.getTextSecondary(context))),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2AABEE), Color(0xFF5856D6)],
                ),
                borderRadius:
                    BorderRadius.circular(AppThemes.borderRadiusMedium),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.telegramBlue.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _refreshNotifications,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppThemes.borderRadiusMedium)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Refresh'),
              ),
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
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          if (unreadNotifications.isNotEmpty) ...[
            SliverToBoxAdapter(
                child:
                    _buildSectionHeader('Unread', unreadNotifications.length)),
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
                    readNotifications.length)),
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
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.telegramBlue),
                  ),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Text(title,
              style: AppTextStyles.labelLarge
                  .copyWith(color: AppColors.getTextSecondary(context))),
          const SizedBox(width: 12),
          _buildGlassContainer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Text(count.toString(),
                  style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.telegramBlue,
                      fontWeight: FontWeight.w600)),
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
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF3B30), Color(0xFFE6204A)],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return _showDeleteConfirmation(context, notification, provider);
      },
      onDismissed: (direction) {
        // Already handled by confirmDismiss
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: _buildGlassContainer(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _handleNotificationTap(notification, provider),
              onLongPress: () =>
                  _showActionSheet(context, notification, provider),
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            iconColor.withValues(alpha: 0.2),
                            iconColor.withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(iconData, size: 24, color: iconColor),
                    ),
                    const SizedBox(width: 16),
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
                                    margin: const EdgeInsets.only(left: 4),
                                    decoration: const BoxDecoration(
                                        color: AppColors.telegramBlue,
                                        shape: BoxShape.circle)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(notification.message,
                              style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.getTextSecondary(context),
                                  height: 1.4),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.access_time_rounded,
                                  size: 12,
                                  color: AppColors.getTextSecondary(context)
                                      .withValues(alpha: 0.5)),
                              const SizedBox(width: 4),
                              Text(timeText,
                                  style: AppTextStyles.caption.copyWith(
                                      color: AppColors.getTextSecondary(context)
                                          .withValues(alpha: 0.5))),
                              const Spacer(),
                              if (!notification.isRead)
                                _buildGlassContainer(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    child: Text('NEW',
                                        style: AppTextStyles.statusBadge
                                            .copyWith(
                                                color: AppColors.telegramBlue,
                                                fontSize: 8)),
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
    if (!notification.isRead) {
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
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                      color:
                          AppColors.getTextSecondary(context).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                iconColor.withValues(alpha: 0.2),
                                iconColor.withValues(alpha: 0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16)),
                        child: Icon(iconData, size: 28, color: iconColor)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(notification.title,
                              style: AppTextStyles.titleLarge.copyWith(
                                  color: AppColors.getTextPrimary(context),
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(notification.timeAgo,
                              style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.getTextSecondary(context))),
                        ],
                      ),
                    ),
                    if (!notification.isRead)
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
              Divider(color: Theme.of(context).dividerColor, height: 16),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  child: Text(notification.message,
                      style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.getTextPrimary(context),
                          height: 1.6)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.getTextSecondary(context),
                          side: BorderSide(
                              color: AppColors.getTextSecondary(context)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppThemes.borderRadiusMedium)),
                        ),
                        child: const Text('Close'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF3B30), Color(0xFFE6204A)],
                          ),
                          borderRadius: BorderRadius.circular(
                              AppThemes.borderRadiusMedium),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.telegramRed.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _deleteNotification(notification, provider);
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
                          child: const Text('Delete'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    )
        .animate()
        .slideY(begin: 1, end: 0, duration: AppThemes.animationDurationMedium);
  }

  void _showActionSheet(
      BuildContext context,
      AppNotification.Notification notification,
      NotificationProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildGlassContainer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                    color: AppColors.getTextSecondary(context).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2))),
            ListTile(
              leading: _buildGlassContainer(
                child: Container(
                    width: 40,
                    height: 40,
                    padding: const EdgeInsets.all(8),
                    child: const Icon(Icons.delete_rounded,
                        color: AppColors.telegramRed)),
              ),
              title: Text('Delete',
                  style: AppTextStyles.bodyLarge
                      .copyWith(color: AppColors.telegramRed)),
              onTap: () {
                Navigator.pop(context);
                _deleteNotification(notification, provider);
              },
            ),
            if (!notification.isRead)
              ListTile(
                leading: _buildGlassContainer(
                  child: Container(
                      width: 40,
                      height: 40,
                      padding: const EdgeInsets.all(8),
                      child: const Icon(Icons.mark_email_read_rounded,
                          color: AppColors.telegramBlue)),
                ),
                title: Text('Mark as read',
                    style: AppTextStyles.bodyLarge
                        .copyWith(color: AppColors.telegramBlue)),
                onTap: () {
                  provider.markAsRead(notification.logId);
                  Navigator.pop(context);
                },
              ),
            ListTile(
              leading: _buildGlassContainer(
                child: Container(
                    width: 40,
                    height: 40,
                    padding: const EdgeInsets.all(8),
                    child: Icon(Icons.close_rounded,
                        color: AppColors.getTextSecondary(context))),
              ),
              title: Text('Cancel',
                  style: AppTextStyles.bodyLarge
                      .copyWith(color: AppColors.getTextSecondary(context))),
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 16),
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
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 48,
                    height: 48,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.telegramRed.withValues(alpha: 0.2),
                            AppColors.telegramRed.withValues(alpha: 0.1),
                          ],
                        ),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.delete_rounded,
                        color: AppColors.telegramRed, size: 24)),
                const SizedBox(height: 16),
                Text('Delete notification',
                    style: AppTextStyles.titleLarge.copyWith(
                        color: AppColors.getTextPrimary(context),
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Text('Are you sure you want to delete this notification?',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.getTextSecondary(context)),
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.getTextSecondary(context),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppThemes.borderRadiusMedium)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF3B30), Color(0xFFE6204A)],
                          ),
                          borderRadius: BorderRadius.circular(
                              AppThemes.borderRadiusMedium),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.telegramRed.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    AppThemes.borderRadiusMedium)),
                          ),
                          child: const Text('Delete'),
                        ),
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
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 48,
                    height: 48,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.telegramBlue.withValues(alpha: 0.2),
                            AppColors.telegramPurple.withValues(alpha: 0.1),
                          ],
                        ),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.mark_email_read_rounded,
                        color: AppColors.telegramBlue, size: 24)),
                const SizedBox(height: 16),
                Text('Mark all as read',
                    style: AppTextStyles.titleLarge.copyWith(
                        color: AppColors.getTextPrimary(context),
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Text('Mark all notifications as read?',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.getTextSecondary(context)),
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.getTextSecondary(context),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppThemes.borderRadiusMedium)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2AABEE), Color(0xFF5856D6)],
                          ),
                          borderRadius: BorderRadius.circular(
                              AppThemes.borderRadiusMedium),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.telegramBlue.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            provider.markAllAsRead();
                            Navigator.pop(context);
                            showTopSnackBar(
                                context, 'All notifications marked as read');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    AppThemes.borderRadiusMedium)),
                          ),
                          child: const Text('Mark all'),
                        ),
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

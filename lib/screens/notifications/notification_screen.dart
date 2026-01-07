import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/empty_state.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isInitialLoad = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNotifications();
    });
  }

  Future<void> _loadNotifications() async {
    final provider = Provider.of<NotificationProvider>(context, listen: false);
    if (_isInitialLoad) {
      await provider.loadNotifications();
      setState(() => _isInitialLoad = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<NotificationProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (provider.notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.mark_email_read),
              onPressed: () => _showMarkAllAsReadDialog(context, provider),
              tooltip: 'Mark all as read',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await provider.loadNotifications();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isInitialLoad && provider.isLoading
          ? const LoadingIndicator()
          : RefreshIndicator(
              onRefresh: () => provider.loadNotifications(),
              child: _buildNotificationsList(provider, theme),
            ),
    );
  }

  Widget _buildNotificationsList(
      NotificationProvider provider, ThemeData theme) {
    if (provider.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Failed to load notifications',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              provider.error!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => provider.loadNotifications(),
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (provider.notifications.isEmpty) {
      return const EmptyState(
        icon: Icons.notifications_none,
        title: 'No Notifications',
        message: 'You don\'t have any notifications yet.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: provider.notifications.length,
      itemBuilder: (context, index) {
        final notification = provider.notifications[index];
        return _buildNotificationItem(notification, provider, theme);
      },
    );
  }

  Widget _buildNotificationItem(
    notification, // Your existing Notification model
    NotificationProvider provider,
    ThemeData theme,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: notification.isDelivered
          ? theme.cardTheme.color
          : theme.colorScheme.surfaceVariant.withOpacity(0.5),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getNotificationColor(notification, theme),
          child: Text(
            _getNotificationIcon(notification),
            style: const TextStyle(fontSize: 18),
          ),
        ),
        title: Text(
          notification.title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight:
                notification.isDelivered ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(notification.message),
            const SizedBox(height: 8),
            Text(
              notification.timeAgo,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) => _handleMenuItemSelected(
            value,
            notification.id,
            provider,
            context,
          ),
          itemBuilder: (context) => [
            if (!notification.isDelivered)
              const PopupMenuItem(
                value: 'mark_read',
                child: Row(
                  children: [
                    Icon(Icons.mark_email_read, size: 20),
                    SizedBox(width: 8),
                    Text('Mark as Read'),
                  ],
                ),
              ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        onTap: () {
          if (!notification.isDelivered) {
            provider.markAsRead(notification.id);
          }
          _handleNotificationTap(notification, context);
        },
      ),
    );
  }

  Color _getNotificationColor(notification, ThemeData theme) {
    // Customize based on your notification types
    if (notification.title.contains('Payment')) return Colors.green;
    if (notification.title.contains('Exam')) return Colors.blue;
    if (notification.title.contains('Streak')) return Colors.orange;
    return theme.colorScheme.primary;
  }

  String _getNotificationIcon(notification) {
    // Customize based on your notification types
    if (notification.title.contains('Payment')) return '💰';
    if (notification.title.contains('Exam')) return '📝';
    if (notification.title.contains('Streak')) return '🔥';
    if (notification.title.contains('Expiring')) return '⏰';
    return '📢';
  }

  void _handleMenuItemSelected(
    String value,
    int notificationId,
    NotificationProvider provider,
    BuildContext context,
  ) {
    switch (value) {
      case 'mark_read':
        provider.markAsRead(notificationId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marked as read')),
        );
        break;
      case 'delete':
        _showDeleteDialog(context, notificationId, provider);
        break;
    }
  }

  void _handleNotificationTap(notification, BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(notification.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(notification.message),
              const SizedBox(height: 16),
              Text(
                'Received: ${notification.timeAgo}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (notification.sentAt != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Sent: ${notification.sentAt!.toLocal()}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => GoRouter.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    int notificationId,
    NotificationProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notification'),
        content:
            const Text('Are you sure you want to delete this notification?'),
        actions: [
          TextButton(
            onPressed: () => GoRouter.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // You need to add delete method to provider
              // provider.deleteNotification(notificationId);
              GoRouter.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notification deleted')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showMarkAllAsReadDialog(
    BuildContext context,
    NotificationProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark All as Read'),
        content: const Text(
            'Are you sure you want to mark all notifications as read?'),
        actions: [
          TextButton(
            onPressed: () => GoRouter.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.markAllAsRead();
              GoRouter.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('All notifications marked as read')),
              );
            },
            child: const Text('Mark All'),
          ),
        ],
      ),
    );
  }
}

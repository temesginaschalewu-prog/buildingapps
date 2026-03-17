import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:badges/badges.dart' as badges;
import '../../../providers/notification_provider.dart';
import '../../../services/connectivity_service.dart';
import '../../../themes/app_colors.dart';
import '../../../utils/responsive_values.dart';

class NotificationButton extends StatefulWidget {
  final double? size;
  final Color? iconColor;
  final VoidCallback? onTap;

  const NotificationButton({
    super.key,
    this.size,
    this.iconColor,
    this.onTap,
  });

  @override
  State<NotificationButton> createState() => _NotificationButtonState();
}

class _NotificationButtonState extends State<NotificationButton> {
  StreamSubscription? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshUnreadCount());
    _setupConnectivityListener();
  }

  void _setupConnectivityListener() {
    final connectivityService = context.read<ConnectivityService>();
    _connectivitySubscription =
        connectivityService.onConnectivityChanged.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _refreshUnreadCount() async {
    final notificationProvider =
        Provider.of<NotificationProvider>(context, listen: false);
    await notificationProvider.refreshUnreadCount();
    if (!mounted) return;
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<NotificationProvider, ConnectivityService>(
      builder: (context, provider, connectivity, child) {
        final unreadCount = provider.unreadCount;
        final isOffline = !connectivity.isOnline;
        final buttonSize =
            widget.size ?? ResponsiveValues.appBarButtonSize(context);

        return Container(
          width: buttonSize,
          height: buttonSize,
          decoration: BoxDecoration(
            color: AppColors.getSurface(context).withValues(alpha: 0.15),
            borderRadius:
                BorderRadius.circular(ResponsiveValues.radiusFull(context) / 2),
          ),
          child: ClipRRect(
            borderRadius:
                BorderRadius.circular(ResponsiveValues.radiusFull(context) / 2),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap ??
                    () async {
                      // Always load from cache first, refresh in background if online
                      await provider.loadNotifications();
                      if (!mounted) return;
                      if (context.mounted) {
                        await GoRouter.of(context).push('/notifications');
                        if (!mounted) return;
                      }
                    },
                borderRadius: BorderRadius.circular(
                    ResponsiveValues.radiusFull(context) / 2),
                splashColor: AppColors.telegramBlue.withValues(alpha: 0.2),
                highlightColor: Colors.transparent,
                child: Center(
                  child: unreadCount > 0
                      ? badges.Badge(
                          position: badges.BadgePosition.topEnd(
                            top: -ResponsiveValues.spacingXXS(context),
                            end: -ResponsiveValues.spacingXXS(context),
                          ),
                          badgeContent: Text(
                            unreadCount > 9 ? '9+' : unreadCount.toString(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize:
                                  ResponsiveValues.fontLabelSmall(context),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          badgeStyle: badges.BadgeStyle(
                            badgeColor: isOffline
                                ? AppColors.warning
                                : AppColors.telegramRed,
                            padding: EdgeInsets.all(
                                ResponsiveValues.spacingXXS(context)),
                          ),
                          child: Icon(
                            Icons.notifications_outlined,
                            size: ResponsiveValues.appBarIconSize(context),
                            color: widget.iconColor ??
                                (isOffline
                                    ? AppColors.warning
                                    : AppColors.getTextPrimary(context)),
                          ),
                        )
                      : Icon(
                          isOffline
                              ? Icons.wifi_off_rounded
                              : Icons.notifications_outlined,
                          size: ResponsiveValues.appBarIconSize(context),
                          color: widget.iconColor ??
                              (isOffline
                                  ? AppColors.warning
                                  : AppColors.getTextPrimary(context)),
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

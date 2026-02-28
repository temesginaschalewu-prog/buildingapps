import 'dart:async';

import 'package:familyacademyclient/themes/app_themes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:badges/badges.dart' as badges;
import '../../../providers/notification_provider.dart';
import '../../../themes/app_colors.dart';
import '../../../themes/app_text_styles.dart';

class NotificationButton extends StatefulWidget {
  final double? size;
  final Color? iconColor;
  final VoidCallback? onTap;

  const NotificationButton({
    super.key,
    this.size = 40,
    this.iconColor,
    this.onTap,
  });

  @override
  State<NotificationButton> createState() => _NotificationButtonState();
}

class _NotificationButtonState extends State<NotificationButton> {
  late StreamSubscription _notificationSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshUnreadCount();
    });
  }

  Future<void> _refreshUnreadCount() async {
    final notificationProvider =
        Provider.of<NotificationProvider>(context, listen: false);
    await notificationProvider.refreshUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, provider, child) {
        final unreadCount = provider.unreadCount;

        return GestureDetector(
          onTap: widget.onTap ??
              () async {
                await provider.loadNotifications();
                if (context.mounted) {
                  GoRouter.of(context).push('/notifications');
                }
              },
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: AppColors.getSurface(context),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: unreadCount > 0
                  ? badges.Badge(
                      position: badges.BadgePosition.topEnd(top: -4, end: -4),
                      badgeContent: Text(
                        unreadCount > 9 ? '9+' : unreadCount.toString(),
                        style: AppTextStyles.labelSmall.copyWith(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      badgeStyle: badges.BadgeStyle(
                        badgeColor: AppColors.telegramRed,
                        padding: const EdgeInsets.all(4),
                        borderRadius:
                            BorderRadius.circular(AppThemes.borderRadiusFull),
                      ),
                      child: Icon(
                        Icons.notifications_outlined,
                        size: (widget.size! * 0.55).clamp(18, 24),
                        color: widget.iconColor ??
                            AppColors.getTextPrimary(context),
                      ),
                    )
                  : Icon(
                      Icons.notifications_outlined,
                      size: (widget.size! * 0.55).clamp(18, 24),
                      color:
                          widget.iconColor ?? AppColors.getTextPrimary(context),
                    ),
            ),
          ),
        );
      },
    );
  }
}

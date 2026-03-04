import 'dart:async';
import 'package:familyacademyclient/themes/app_themes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:badges/badges.dart' as badges;
import '../../../providers/notification_provider.dart';
import '../../../themes/app_colors.dart';
import '../../../themes/app_text_styles.dart';
import '../../../utils/responsive.dart';
import '../../../utils/responsive_values.dart';
import '../../../utils/app_enums.dart';

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
        final buttonSize =
            widget.size ?? ResponsiveValues.appBarButtonSize(context);

        return Container(
          width: buttonSize,
          height: buttonSize,
          decoration: BoxDecoration(
            color: AppColors.getSurface(context).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(
              ResponsiveValues.radiusFull(context) / 2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(
              ResponsiveValues.radiusFull(context) / 2,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap ??
                    () async {
                      await provider.loadNotifications();
                      if (context.mounted) {
                        GoRouter.of(context).push('/notifications');
                      }
                    },
                borderRadius: BorderRadius.circular(
                  ResponsiveValues.radiusFull(context) / 2,
                ),
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
                            badgeColor: AppColors.telegramRed,
                            padding: EdgeInsets.all(
                              ResponsiveValues.spacingXXS(context),
                            ),
                          ),
                          child: Icon(
                            Icons.notifications_outlined,
                            size: ResponsiveValues.appBarIconSize(context),
                            color: widget.iconColor ??
                                AppColors.getTextPrimary(context),
                          ),
                        )
                      : Icon(
                          Icons.notifications_outlined,
                          size: ResponsiveValues.appBarIconSize(context),
                          color: widget.iconColor ??
                              AppColors.getTextPrimary(context),
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

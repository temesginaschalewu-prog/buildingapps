import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:badges/badges.dart' as badges;
import '../../../providers/notification_provider.dart';
import '../../../themes/app_colors.dart';
import '../../../utils/responsive_values.dart';

class NotificationButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, provider, child) {
        final unreadCount = provider.unreadCount;
        final buttonSize = size ?? ResponsiveValues.appBarButtonSize(context);

        return Container(
          width: buttonSize,
          height: buttonSize,
          decoration: BoxDecoration(
            color: AppColors.getSurface(context).withValues(alpha: 0.12),
            borderRadius:
                BorderRadius.circular(ResponsiveValues.radiusFull(context) / 2),
          ),
          child: ClipRRect(
            borderRadius:
                BorderRadius.circular(ResponsiveValues.radiusFull(context) / 2),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap ?? () => context.push('/notifications'),
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
                            badgeColor: AppColors.telegramRed,
                            padding: EdgeInsets.all(
                                ResponsiveValues.spacingXXS(context)),
                          ),
                          child: Icon(
                            Icons.notifications_outlined,
                            size: ResponsiveValues.appBarIconSize(context),
                            color: iconColor ?? AppColors.getTextPrimary(context),
                          ),
                        )
                      : Icon(
                          Icons.notifications_outlined,
                          size: ResponsiveValues.appBarIconSize(context),
                          color: iconColor ?? AppColors.getTextPrimary(context),
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

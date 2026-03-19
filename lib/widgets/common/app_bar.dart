// lib/widgets/common/app_bar.dart
// PRODUCTION FINAL - WITH CONNECTION QUALITY & SYNC FEEDBACK

import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/connectivity_service.dart';
import '../../services/offline_queue_manager.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/responsive_values.dart';
import 'notification_button.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget>? actions;
  final bool showThemeToggle;
  final bool showNotification;
  final Widget? customTrailing;
  final bool showOfflineIndicator;

  const CustomAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions,
    this.showThemeToggle = true,
    this.showNotification = true,
    this.customTrailing,
    this.showOfflineIndicator = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 32);

  String _getQualityMessage(ConnectionQuality quality) {
    switch (quality) {
      case ConnectionQuality.none:
        return 'Offline';
      case ConnectionQuality.poor:
        return 'Poor connection - videos may buffer';
      case ConnectionQuality.fair:
        return 'Fair connection';
      case ConnectionQuality.good:
        return 'Good connection';
      case ConnectionQuality.excellent:
        return 'Excellent connection';
    }
  }

  Color _getQualityColor(ConnectionQuality quality) {
    switch (quality) {
      case ConnectionQuality.none:
        return Colors.red;
      case ConnectionQuality.poor:
        return Colors.orange;
      case ConnectionQuality.fair:
        return Colors.yellow;
      case ConnectionQuality.good:
        return Colors.green;
      case ConnectionQuality.excellent:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<ConnectivityService, ThemeProvider, OfflineQueueManager>(
      builder: (context, connectivity, themeProvider, queueManager, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final isOnline = connectivity.isOnline;
        final pendingCount = queueManager.pendingCount;
        final isProcessing = queueManager.isProcessing;
        final quality = connectivity.connectionQuality;
        final topInset = MediaQuery.of(context).padding.top;
        final safeTopInset = math.min(topInset, 20.0);

        final backgroundColor = isDark
            ? AppColors.darkSurface.withValues(alpha: 0.95)
            : const Color(0xFFF9F4F7).withValues(alpha: 0.96);
        final gradientStart =
            isDark ? AppColors.darkCard : const Color(0xFFF6EEF3);
        final gradientEnd =
            isDark ? AppColors.darkBackground : const Color(0xFFEFF3F7);

        return ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              height: kToolbarHeight + 24,
              padding: EdgeInsets.only(
                left: ResponsiveValues.spacingL(context),
                right: ResponsiveValues.spacingL(context),
                top: safeTopInset + 6,
                bottom: 6,
              ),
              decoration: BoxDecoration(
                color: backgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.3)
                        : const Color(0xFFB6A9B3).withValues(alpha: 0.22),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                    spreadRadius: 1,
                  ),
                ],
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [gradientStart, gradientEnd],
                ),
                border: Border(
                  bottom: BorderSide(
                      color: isDark
                          ? AppColors.telegramBlue.withValues(alpha: 0.15)
                          : const Color(0xFFD7C8D2).withValues(alpha: 0.85)),
                ),
              ),
              child: Row(
                children: [
                  if (leading != null) leading!,
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final canShowSubtitle =
                            subtitle != null && constraints.maxHeight >= 34;
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Text(
                                  title,
                                  style: AppTextStyles.headlineSmall(context)
                                      .copyWith(fontWeight: FontWeight.w700),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),

                                // Connection Quality Indicator
                                if (quality != ConnectionQuality.good &&
                                    quality != ConnectionQuality.excellent)
                                  Padding(
                                    padding: EdgeInsets.only(
                                        left: ResponsiveValues.spacingXS(
                                            context)),
                                    child: Tooltip(
                                      message: _getQualityMessage(quality),
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: _getQualityColor(quality),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                  ),

                                // Sync/Pending Indicator
                                if (isProcessing)
                                  Padding(
                                    padding: EdgeInsets.only(
                                        left: ResponsiveValues.spacingXS(
                                            context)),
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                AppColors.info),
                                      ),
                                    ),
                                  )
                                else if (pendingCount > 0 && isOnline)
                                  Padding(
                                    padding: EdgeInsets.only(
                                        left: ResponsiveValues.spacingXS(
                                            context)),
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: AppColors.info,
                                        shape: BoxShape.circle,
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 18,
                                        minHeight: 18,
                                      ),
                                      child: Center(
                                        child: Text(
                                          pendingCount > 9
                                              ? '9+'
                                              : pendingCount.toString(),
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize:
                                                ResponsiveValues.fontBadgeSmall(
                                                    context),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                // Offline Indicator
                                if (showOfflineIndicator && !isOnline)
                                  Padding(
                                    padding: EdgeInsets.only(
                                        left: ResponsiveValues.spacingXS(
                                            context)),
                                    child: Icon(
                                      Icons.wifi_off_rounded,
                                      size:
                                          ResponsiveValues.iconSizeXS(context),
                                      color: AppColors.warning,
                                    ),
                                  ),
                              ],
                            ),
                            if (canShowSubtitle) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtitle!,
                                style:
                                    AppTextStyles.bodySmall(context).copyWith(
                                  color: AppColors.getTextSecondary(context),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                  _buildButtonRow(
                      context, themeProvider, isOnline, pendingCount),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildButtonRow(BuildContext context, ThemeProvider themeProvider,
      bool isOnline, int pendingCount) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showThemeToggle) ...[
          Padding(
            padding: EdgeInsets.only(
                right: ResponsiveValues.appBarButtonSpacing(context)),
            child: _buildIconButton(
              context: context,
              onTap: themeProvider.toggleTheme,
              icon: themeProvider.themeMode == ThemeMode.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              color: AppColors.getTextPrimary(context),
            ),
          ),
        ],
        if (showNotification) ...[
          Padding(
            padding: EdgeInsets.only(
                right: ResponsiveValues.appBarButtonSpacing(context)),
            child: const NotificationButton(),
          ),
        ],
        if (customTrailing != null) ...[
          Padding(
            padding: EdgeInsets.only(
                right: ResponsiveValues.appBarButtonSpacing(context)),
            child: customTrailing,
          ),
        ],
        if (actions != null) ...actions!,
      ],
    );
  }

  Widget _buildIconButton({
    required BuildContext context,
    required VoidCallback? onTap,
    IconData? icon,
    Color? color,
    Widget? customChild,
  }) {
    return Container(
      width: ResponsiveValues.appBarButtonSize(context),
      height: ResponsiveValues.appBarButtonSize(context),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context).withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius:
                BorderRadius.circular(ResponsiveValues.radiusFull(context) / 2),
            splashColor: AppColors.telegramBlue.withValues(alpha: 0.3),
            highlightColor: Colors.transparent,
            child: Center(
              child: customChild ??
                  Icon(icon,
                      size: ResponsiveValues.appBarIconSize(context),
                      color: color),
            ),
          ),
        ),
      ),
    );
  }
}

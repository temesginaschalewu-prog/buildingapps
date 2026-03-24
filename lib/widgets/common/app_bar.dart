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
  Size get preferredSize {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final topInset = view.viewPadding.top / view.devicePixelRatio;
    return Size.fromHeight(kToolbarHeight + 24 + topInset);
  }

  Color _getQualityColor(ConnectionQuality quality) {
    switch (quality) {
      case ConnectionQuality.none:
        return AppColors.warning;
      case ConnectionQuality.poor:
        return AppColors.telegramOrange;
      case ConnectionQuality.fair:
        return AppColors.telegramYellow;
      case ConnectionQuality.good:
        return AppColors.telegramGreen;
      case ConnectionQuality.excellent:
        return AppColors.telegramGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<ConnectivityService, ThemeProvider, OfflineQueueManager>(
      builder: (context, connectivity, themeProvider, queueManager, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final isProcessing = queueManager.isProcessing;
        final quality = connectivity.connectionQuality;
        final baseColor = isDark
            ? const Color(0xFF101A2A)
            : const Color(0xFFF7FAFF);
        final topWash = isDark
            ? const Color(0xFF1C3154).withValues(alpha: 0.86)
            : const Color(0xFFEAF3FF).withValues(alpha: 0.96);
        final bottomWash = isDark
            ? const Color(0xFF0F1725).withValues(alpha: 0.96)
            : const Color(0xFFFDFEFF).withValues(alpha: 0.98);
        final fullTintTop = isDark
            ? AppColors.telegramBlue.withValues(alpha: 0.22)
            : AppColors.telegramBlue.withValues(alpha: 0.16);
        final fullTintMiddle = isDark
            ? AppColors.telegramBlueLight.withValues(alpha: 0.14)
            : AppColors.telegramBlueLight.withValues(alpha: 0.11);
        final fullTintBottom = isDark
            ? AppColors.telegramTeal.withValues(alpha: 0.06)
            : AppColors.telegramTeal.withValues(alpha: 0.05);
        final edgeStroke = isDark
            ? Colors.white.withValues(alpha: 0.06)
            : const Color(0xFFDDE7F5);
        final titleColor =
            isDark ? const Color(0xFFF7FAFE) : const Color(0xFF12243D);
        final subtitleColor =
            isDark ? const Color(0xFF9CB0C7) : const Color(0xFF6A7C93);

        return Container(
          height: preferredSize.height,
          decoration: BoxDecoration(
            color: baseColor.withValues(alpha: isDark ? 0.90 : 0.88),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                topWash,
                bottomWash,
              ],
            ),
            border: Border(
              bottom: BorderSide(color: edgeStroke),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.20)
                    : const Color(0xFFB8C8DE).withValues(alpha: 0.10),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.45, 1.0],
                      colors: [
                        fullTintTop,
                        fullTintMiddle,
                        fullTintBottom,
                      ],
                    ),
                  ),
                ),
              ),
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.25),
                      radius: 1.15,
                      colors: [
                        Colors.white.withValues(alpha: isDark ? 0.04 : 0.22),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              IgnorePointer(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    height: 14,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: isDark ? 0.05 : 0.38),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: ResponsiveValues.spacingM(context),
                    right: ResponsiveValues.spacingM(context),
                    top: 3,
                    bottom: 9,
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
                                    Flexible(
                                      child: Text(
                                        title,
                                        style: AppTextStyles.titleLarge(context)
                                            .copyWith(
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -0.2,
                                          color: titleColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.only(
                                        left: ResponsiveValues.spacingXS(context),
                                      ),
                                      child: Container(
                                        width: 7,
                                        height: 7,
                                        decoration: BoxDecoration(
                                          color: _getQualityColor(quality),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                    if (isProcessing)
                                      Padding(
                                        padding: EdgeInsets.only(
                                          left:
                                              ResponsiveValues.spacingXS(context),
                                        ),
                                        child: const SizedBox(
                                          width: 15,
                                          height: 15,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              AppColors.info,
                                            ),
                                          ),
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
                                      color: subtitleColor,
                                      fontWeight: FontWeight.w500,
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
                      _buildButtonRow(context, themeProvider),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildButtonRow(BuildContext context, ThemeProvider themeProvider) {
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
        color: AppColors.getSurface(context).withValues(alpha: 0.15),
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

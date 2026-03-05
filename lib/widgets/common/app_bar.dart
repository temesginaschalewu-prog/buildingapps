import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:familyacademyclient/providers/theme_provider.dart';
import 'package:familyacademyclient/widgets/common/notification_button.dart';
import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';
import 'package:familyacademyclient/utils/responsive_values.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget>? actions;
  final bool showThemeToggle;
  final bool showNotification;
  final Widget? customTrailing;

  const CustomAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions,
    this.showThemeToggle = true,
    this.showNotification = true,
    this.customTrailing,
  });

  @override
  Size get preferredSize {
    // Using a builder to get context would be complicated, so we use a reasonable default
    return const Size.fromHeight(kToolbarHeight + 32);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        // Use AppColors for all colors
        final backgroundColor = isDark
            ? AppColors.darkSurface.withValues(alpha: 0.95)
            : AppColors.lightSurface.withValues(alpha: 0.95);

        final gradientStart = isDark ? AppColors.darkCard : AppColors.lightCard;

        final gradientEnd =
            isDark ? AppColors.darkBackground : AppColors.lightBackground;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              child: Container(
                height: kToolbarHeight + 24,
                padding: EdgeInsets.only(
                  left: ResponsiveValues.spacingL(context),
                  right: ResponsiveValues.spacingL(context),
                  top: MediaQuery.of(context).padding.top + 8,
                  bottom: 8,
                ),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.3)
                          : AppColors.telegramBlue.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                      spreadRadius: 1,
                    ),
                  ],
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      gradientStart,
                      gradientEnd,
                    ],
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.telegramBlue.withValues(alpha: 0.15),
                    ),
                  ),
                ),
                child: Stack(
                  children: [
                    // Sparkle/fleck overlay
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: SparklePainter(
                            color: AppColors.telegramBlue,
                            density: 0.15,
                            maxOpacity: 0.25,
                          ),
                        ),
                      ),
                    ),
                    // Main content
                    Row(
                      children: [
                        if (leading != null) leading!,
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title,
                                style: AppTextStyles.headlineSmall(context)
                                    .copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (subtitle != null) ...[
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
                          ),
                        ),
                        _buildButtonRow(context, themeProvider),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Small bottom padding to separate from content
            SizedBox(height: ResponsiveValues.spacingXS(context)),
          ],
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
              right: ResponsiveValues.appBarButtonSpacing(context),
            ),
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
              right: ResponsiveValues.appBarButtonSpacing(context),
            ),
            child: const NotificationButton(),
          ),
        ],
        if (customTrailing != null) ...[
          Padding(
            padding: EdgeInsets.only(
              right: ResponsiveValues.appBarButtonSpacing(context),
            ),
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
            borderRadius: BorderRadius.circular(
              ResponsiveValues.radiusFull(context) / 2,
            ),
            splashColor: AppColors.telegramBlue.withValues(alpha: 0.3),
            highlightColor: Colors.transparent,
            child: Center(
              child: customChild ??
                  Icon(
                    icon,
                    size: ResponsiveValues.appBarIconSize(context),
                    color: color,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class SparklePainter extends CustomPainter {
  final Color color;
  final double density;
  final double minOpacity;
  final double maxOpacity;
  final math.Random _random = math.Random(42);

  SparklePainter({
    required this.color,
    required this.density,
    this.minOpacity = 0.1,
    this.maxOpacity = 0.3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final area = size.width * size.height;
    final sparkleCount = (area * density / 1000).round();

    for (int i = 0; i < sparkleCount; i++) {
      final x = _random.nextDouble() * size.width;
      final y = _random.nextDouble() * size.height;
      final sparkleSize = 1.0 + _random.nextDouble() * 2.0;
      final opacity =
          minOpacity + _random.nextDouble() * (maxOpacity - minOpacity);

      paint.color = color.withValues(alpha: opacity);
      canvas.drawCircle(Offset(x, y), sparkleSize, paint);

      if (_random.nextDouble() < 0.2) {
        final biggerSize = sparkleSize * 1.5;
        final biggerOpacity = opacity * 1.2;
        paint.color =
            color.withValues(alpha: biggerOpacity.clamp(0.0, maxOpacity));
        canvas.drawCircle(Offset(x + 1, y - 1), biggerSize, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

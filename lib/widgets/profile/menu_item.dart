import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import '../../themes/app_themes.dart';
import '../../themes/app_text_styles.dart';
import '../../themes/app_colors.dart';

class MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Widget? trailing;
  final Color? iconColor;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;
  final bool showDivider;
  final bool isDestructive;
  final bool isPremium;
  final String? badgeText;

  const MenuItem({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailing,
    this.iconColor,
    this.backgroundColor,
    this.padding,
    this.showDivider = false,
    this.isDestructive = false,
    this.isPremium = false,
    this.badgeText,
  });

  Widget _buildGlassContainer(BuildContext context, {required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.getCard(context).withOpacity(0.4),
                AppColors.getCard(context).withOpacity(0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.telegramBlue.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    final defaultIconColor = isDestructive
        ? AppColors.telegramRed
        : isPremium
            ? const Color(0xFFFF9500)
            : AppColors.getTextPrimary(context);

    final defaultBackgroundColor =
        isDark ? Colors.transparent : AppColors.lightSurface;

    final iconSize = isMobile ? 36.0 : (isTablet ? 40.0 : 44.0);
    final iconInnerSize = isMobile ? 18.0 : (isTablet ? 20.0 : 22.0);
    final titleSize = isMobile ? 15.0 : (isTablet ? 16.0 : 17.0);
    final badgeSize = isMobile ? 10.0 : (isTablet ? 11.0 : 12.0);
    final horizontalPadding = isMobile
        ? AppThemes.spacingL
        : (isTablet ? AppThemes.spacingXL : AppThemes.spacingXXL);
    final verticalPadding = isMobile
        ? AppThemes.spacingM
        : (isTablet ? AppThemes.spacingL : AppThemes.spacingXL);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.telegramBlue.withOpacity(0.1),
        highlightColor: Colors.transparent,
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: horizontalPadding),
          padding: padding ??
              EdgeInsets.symmetric(
                  vertical: verticalPadding, horizontal: AppThemes.spacingS),
          decoration: BoxDecoration(
            border: showDivider
                ? Border(
                    bottom: BorderSide(
                        color: isDark
                            ? AppColors.darkDivider
                            : AppColors.lightDivider,
                        width: 0.5),
                  )
                : null,
          ),
          child: Row(
            children: [
              _buildGlassContainer(
                context,
                child: Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    color: backgroundColor ??
                        (isPremium
                            ? const Color(0xFFFF9500).withOpacity(0.1)
                            : isDestructive
                                ? AppColors.telegramRed.withOpacity(0.1)
                                : AppColors.telegramBlue.withOpacity(0.1)),
                    borderRadius:
                        BorderRadius.circular(AppThemes.borderRadiusMedium),
                  ),
                  child: Icon(icon,
                      size: iconInnerSize,
                      color: iconColor ?? defaultIconColor),
                ),
              ),
              SizedBox(
                  width: isMobile
                      ? AppThemes.spacingL
                      : (isTablet
                          ? AppThemes.spacingXL
                          : AppThemes.spacingXXL)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: isDestructive
                            ? AppColors.telegramRed
                            : AppColors.getTextPrimary(context),
                        fontSize: titleSize,
                      ),
                    ),
                    if (isPremium)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Premium',
                          style: AppTextStyles.caption.copyWith(
                            color: const Color(0xFFFF9500),
                            fontWeight: FontWeight.w600,
                            fontSize: badgeSize,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (badgeText != null)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppColors.telegramBlue,
                      borderRadius: BorderRadius.circular(12)),
                  child: Text(badgeText!,
                      style: AppTextStyles.labelSmall
                          .copyWith(color: Colors.white, fontSize: 10)),
                ),
              trailing ??
                  Icon(
                    Icons.arrow_forward_ios,
                    size: isMobile ? 16 : (isTablet ? 18 : 20),
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(
        duration: AppThemes.animationDurationMedium,
        delay: Duration(milliseconds: key.hashCode % 300));
  }
}

class MenuSection extends StatelessWidget {
  final String? title;
  final List<MenuItem> items;
  final EdgeInsetsGeometry padding;
  final bool showBackground;

  const MenuSection({
    super.key,
    this.title,
    required this.items,
    this.padding = const EdgeInsets.only(
        top: AppThemes.spacingL, bottom: AppThemes.spacingM),
    this.showBackground = false,
  });

  Widget _buildGlassContainer(BuildContext context, {required Widget child}) {
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
                AppColors.getCard(context).withOpacity(0.4),
                AppColors.getCard(context).withOpacity(0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.telegramBlue.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    final horizontalPadding = isMobile
        ? AppThemes.spacingL
        : (isTablet ? AppThemes.spacingXL : AppThemes.spacingXXL);

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: EdgeInsets.only(
                left: horizontalPadding, bottom: AppThemes.spacingM),
            child: Text(
              title!.toUpperCase(),
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.getTextSecondary(context),
                fontSize: isMobile ? 12 : (isTablet ? 13 : 14),
                letterSpacing: 0.5,
              ),
            ),
          ),
        ...items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Column(
            children: [
              MenuItem(
                key: ValueKey('${item.title}_$index'),
                icon: item.icon,
                title: item.title,
                onTap: item.onTap,
                trailing: item.trailing,
                iconColor: item.iconColor,
                backgroundColor: item.backgroundColor,
                padding: item.padding,
                showDivider: index < items.length - 1,
                isDestructive: item.isDestructive,
                isPremium: item.isPremium,
                badgeText: item.badgeText,
              ),
              if (index < items.length - 1 &&
                  !item.showDivider &&
                  showBackground)
                Container(
                  height: 0.5,
                  margin: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  color:
                      isDark ? AppColors.darkDivider : AppColors.lightDivider,
                ),
            ],
          );
        }),
      ],
    );

    if (showBackground) {
      return _buildGlassContainer(context,
          child: Padding(padding: padding, child: content));
    }

    return Padding(padding: padding, child: content);
  }
}

class MenuHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? color;
  final Widget? action;
  final bool elevated;

  const MenuHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.color,
    this.action,
    this.elevated = false,
  });

  Widget _buildGlassContainer(BuildContext context, {required Widget child}) {
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
                AppColors.getCard(context).withOpacity(0.4),
                AppColors.getCard(context).withOpacity(0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.telegramBlue.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    final headerColor =
        color ?? (isDark ? AppColors.darkSurface : AppColors.telegramBlueLight);
    final horizontalPadding = isMobile
        ? AppThemes.spacingL
        : (isTablet ? AppThemes.spacingXL : AppThemes.spacingXXL);
    final iconSize = isMobile ? 48.0 : (isTablet ? 56.0 : 64.0);
    final iconInnerSize = isMobile ? 24.0 : (isTablet ? 28.0 : 32.0);
    final titleSize = isMobile ? 20.0 : (isTablet ? 22.0 : 24.0);
    final subtitleSize = isMobile ? 14.0 : (isTablet ? 15.0 : 16.0);

    return Container(
      margin: EdgeInsets.symmetric(
          horizontal: horizontalPadding, vertical: AppThemes.spacingM),
      child: _buildGlassContainer(
        context,
        child: Padding(
          padding: EdgeInsets.all(horizontalPadding),
          child: Row(
            children: [
              if (icon != null)
                Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius:
                          BorderRadius.circular(AppThemes.borderRadiusMedium)),
                  child: Icon(icon, size: iconInnerSize, color: Colors.white),
                ),
              SizedBox(width: icon != null ? AppThemes.spacingL : 0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: AppTextStyles.headlineMedium.copyWith(
                            color: Colors.white, fontSize: titleSize)),
                    if (subtitle != null)
                      Padding(
                        padding:
                            const EdgeInsets.only(top: AppThemes.spacingXS),
                        child: Text(subtitle!,
                            style: AppTextStyles.bodyMedium.copyWith(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: subtitleSize),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ),
                  ],
                ),
              ),
              if (action != null) ...[
                const SizedBox(width: AppThemes.spacingM),
                action!,
              ],
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn()
        .slideY(begin: 0.1, end: 0, duration: AppThemes.animationDurationSlow);
  }
}

class MenuCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final bool elevated;

  const MenuCard({
    super.key,
    required this.child,
    this.margin,
    this.padding,
    this.elevated = true,
  });

  Widget _buildGlassContainer(BuildContext context, {required Widget child}) {
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
                AppColors.getCard(context).withOpacity(0.4),
                AppColors.getCard(context).withOpacity(0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.telegramBlue.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    final horizontalMargin = margin ??
        EdgeInsets.symmetric(
          horizontal: isMobile
              ? AppThemes.spacingL
              : (isTablet ? AppThemes.spacingXL : AppThemes.spacingXXL),
          vertical: AppThemes.spacingM,
        );

    final internalPadding = padding ??
        EdgeInsets.all(
          isMobile
              ? AppThemes.spacingL
              : (isTablet ? AppThemes.spacingXL : AppThemes.spacingXXL),
        );

    return Container(
      margin: horizontalMargin,
      child: _buildGlassContainer(
        context,
        child: Padding(
          padding: internalPadding,
          child: child,
        ),
      ),
    ).animate().fadeIn().scale(
        begin: const Offset(0.95, 0.95),
        end: const Offset(1, 1),
        duration: AppThemes.animationDurationMedium);
  }
}

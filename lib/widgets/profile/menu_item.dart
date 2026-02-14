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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultIconColor = isDestructive
        ? AppColors.telegramRed
        : isPremium
            ? const Color(0xFFFF9500)
            : AppColors.getTextPrimary(context);

    final defaultBackgroundColor =
        isDark ? Colors.transparent : AppColors.lightSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.telegramBlue.withOpacity(0.1),
        highlightColor: Colors.transparent,
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
        child: Container(
          margin: EdgeInsets.symmetric(
            horizontal: ScreenSize.responsiveValue(
              context: context,
              mobile: AppThemes.spacingL,
              tablet: AppThemes.spacingXL,
              desktop: AppThemes.spacingXXL,
            ),
          ),
          padding: padding ??
              EdgeInsets.symmetric(
                vertical: ScreenSize.responsiveValue(
                  context: context,
                  mobile: AppThemes.spacingM,
                  tablet: AppThemes.spacingL,
                  desktop: AppThemes.spacingXL,
                ),
                horizontal: ScreenSize.responsiveValue(
                  context: context,
                  mobile: AppThemes.spacingS,
                  tablet: AppThemes.spacingM,
                  desktop: AppThemes.spacingL,
                ),
              ),
          decoration: BoxDecoration(
            border: showDivider
                ? Border(
                    bottom: BorderSide(
                      color: isDark
                          ? AppColors.darkDivider
                          : AppColors.lightDivider,
                      width: 0.5,
                    ),
                  )
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: ScreenSize.responsiveValue(
                  context: context,
                  mobile: 36,
                  tablet: 40,
                  desktop: 44,
                ),
                height: ScreenSize.responsiveValue(
                  context: context,
                  mobile: 36,
                  tablet: 40,
                  desktop: 44,
                ),
                decoration: BoxDecoration(
                  color: backgroundColor ??
                      (isPremium
                          ? const Color(0xFFFF9500).withOpacity(0.1)
                          : isDestructive
                              ? AppColors.telegramRed.withOpacity(0.1)
                              : AppColors.telegramBlue.withOpacity(0.1)),
                  borderRadius: BorderRadius.circular(
                    AppThemes.borderRadiusMedium,
                  ),
                ),
                child: Icon(
                  icon,
                  size: ScreenSize.responsiveValue(
                    context: context,
                    mobile: 18,
                    tablet: 20,
                    desktop: 22,
                  ),
                  color: iconColor ?? defaultIconColor,
                ),
              ),
              SizedBox(
                width: ScreenSize.responsiveValue(
                  context: context,
                  mobile: AppThemes.spacingL,
                  tablet: AppThemes.spacingXL,
                  desktop: AppThemes.spacingXXL,
                ),
              ),
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
                        fontSize: ScreenSize.responsiveFontSize(
                          context: context,
                          mobile: 15,
                          tablet: 16,
                          desktop: 17,
                        ),
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
                            fontSize: ScreenSize.responsiveFontSize(
                              context: context,
                              mobile: 10,
                              tablet: 11,
                              desktop: 12,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (badgeText != null)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.telegramBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badgeText!,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                  ),
                ),
              trailing ??
                  Icon(
                    Icons.arrow_forward_ios,
                    size: ScreenSize.responsiveValue(
                      context: context,
                      mobile: 16,
                      tablet: 18,
                      desktop: 20,
                    ),
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
          delay: Duration(milliseconds: key.hashCode % 300),
        );
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
      top: AppThemes.spacingL,
      bottom: AppThemes.spacingM,
    ),
    this.showBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: padding,
      decoration: showBackground
          ? BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: EdgeInsets.only(
                left: ScreenSize.responsiveValue(
                  context: context,
                  mobile: AppThemes.spacingL,
                  tablet: AppThemes.spacingXL,
                  desktop: AppThemes.spacingXXL,
                ),
                bottom: AppThemes.spacingM,
              ),
              child: Text(
                title!.toUpperCase(),
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.getTextSecondary(context),
                  fontSize: ScreenSize.responsiveFontSize(
                    context: context,
                    mobile: 12,
                    tablet: 13,
                    desktop: 14,
                  ),
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
                    margin: EdgeInsets.symmetric(
                      horizontal: ScreenSize.responsiveValue(
                        context: context,
                        mobile: AppThemes.spacingL,
                        tablet: AppThemes.spacingXL,
                        desktop: AppThemes.spacingXXL,
                      ),
                    ),
                    color:
                        isDark ? AppColors.darkDivider : AppColors.lightDivider,
                  ),
              ],
            );
          }),
        ],
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerColor =
        color ?? (isDark ? AppColors.darkSurface : AppColors.telegramBlueLight);

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: ScreenSize.responsiveValue(
          context: context,
          mobile: AppThemes.spacingL,
          tablet: AppThemes.spacingXL,
          desktop: AppThemes.spacingXXL,
        ),
        vertical: AppThemes.spacingM,
      ),
      padding: EdgeInsets.all(
        ScreenSize.responsiveValue(
          context: context,
          mobile: AppThemes.spacingL,
          tablet: AppThemes.spacingXL,
          desktop: AppThemes.spacingXXL,
        ),
      ),
      decoration: BoxDecoration(
        color: headerColor,
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          if (icon != null)
            Container(
              width: ScreenSize.responsiveValue(
                context: context,
                mobile: 48,
                tablet: 56,
                desktop: 64,
              ),
              height: ScreenSize.responsiveValue(
                context: context,
                mobile: 48,
                tablet: 56,
                desktop: 64,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius:
                    BorderRadius.circular(AppThemes.borderRadiusMedium),
              ),
              child: Icon(
                icon,
                size: ScreenSize.responsiveValue(
                  context: context,
                  mobile: 24,
                  tablet: 28,
                  desktop: 32,
                ),
                color: Colors.white,
              ),
            ),
          SizedBox(width: icon != null ? AppThemes.spacingL : 0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.headlineMedium.copyWith(
                    color: Colors.white,
                    fontSize: ScreenSize.responsiveFontSize(
                      context: context,
                      mobile: 20,
                      tablet: 22,
                      desktop: 24,
                    ),
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppThemes.spacingXS),
                    child: Text(
                      subtitle!,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: ScreenSize.responsiveFontSize(
                          context: context,
                          mobile: 14,
                          tablet: 15,
                          desktop: 16,
                        ),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
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
    ).animate().fadeIn().slideY(
          begin: 0.1,
          end: 0,
          duration: AppThemes.animationDurationSlow,
        );
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: margin ??
          EdgeInsets.symmetric(
            horizontal: ScreenSize.responsiveValue(
              context: context,
              mobile: AppThemes.spacingL,
              tablet: AppThemes.spacingXL,
              desktop: AppThemes.spacingXXL,
            ),
            vertical: AppThemes.spacingM,
          ),
      padding: padding ??
          EdgeInsets.all(
            ScreenSize.responsiveValue(
              context: context,
              mobile: AppThemes.spacingL,
              tablet: AppThemes.spacingXL,
              desktop: AppThemes.spacingXXL,
            ),
          ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
        border: !elevated
            ? Border.all(
                color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                width: 0.5,
              )
            : null,
      ),
      child: child,
    ).animate().fadeIn().scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1, 1),
          duration: AppThemes.animationDurationMedium,
        );
  }
}

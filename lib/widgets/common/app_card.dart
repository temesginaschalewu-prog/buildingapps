import 'dart:ui';
import 'package:flutter/material.dart';
import '../../themes/app_colors.dart';
import '../../utils/responsive_values.dart';
import '../../utils/app_enums.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final CardVariant variant;
  final CardSize size;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? borderColor;
  final double? borderRadius;
  final VoidCallback? onTap;
  final bool hasShadow;
  final Color? backgroundColor;

  const AppCard({
    super.key,
    required this.child,
    this.variant = CardVariant.glass,
    this.size = CardSize.medium,
    this.padding,
    this.margin,
    this.borderColor,
    this.borderRadius,
    this.onTap,
    this.hasShadow = true,
    this.backgroundColor,
  });

  const AppCard.glass({
    super.key,
    required this.child,
    this.size = CardSize.medium,
    this.padding,
    this.margin,
    this.borderColor,
    this.borderRadius,
    this.onTap,
    this.hasShadow = true,
  })  : variant = CardVariant.glass,
        backgroundColor = null;

  const AppCard.solid({
    super.key,
    required this.child,
    this.size = CardSize.medium,
    this.padding,
    this.margin,
    this.borderColor,
    this.borderRadius,
    this.onTap,
    this.backgroundColor,
    this.hasShadow = true,
  }) : variant = CardVariant.solid;

  factory AppCard.category({
    required Widget child,
    VoidCallback? onTap,
    bool isSelected = false,
  }) {
    return AppCard.glass(
      onTap: onTap,
      borderColor: isSelected ? AppColors.telegramBlue : null,
      child: child,
    );
  }

  factory AppCard.course({
    required Widget child,
    VoidCallback? onTap,
    Color? accentColor,
  }) {
    return AppCard.glass(
      onTap: onTap,
      borderColor: accentColor,
      child: child,
    );
  }

  factory AppCard.chapter({
    required Widget child,
    VoidCallback? onTap,
    bool hasAccess = false,
  }) {
    return AppCard.glass(
      onTap: onTap,
      borderColor: hasAccess ? AppColors.telegramGreen : null,
      child: child,
    );
  }

  factory AppCard.video({
    required Widget child,
    VoidCallback? onTap,
    bool isDownloaded = false,
  }) {
    return AppCard.glass(
      onTap: onTap,
      borderColor: isDownloaded ? AppColors.telegramGreen : null,
      child: child,
    );
  }

  factory AppCard.note({
    required Widget child,
    VoidCallback? onTap,
    bool isDownloaded = false,
  }) {
    return AppCard.glass(
      onTap: onTap,
      borderColor: isDownloaded ? AppColors.telegramGreen : null,
      child: child,
    );
  }

  factory AppCard.exam({
    required Widget child,
    VoidCallback? onTap,
    Color? statusColor,
  }) {
    return AppCard.glass(
      onTap: onTap,
      borderColor: statusColor,
      child: child,
    );
  }

  factory AppCard.notification({
    required Widget child,
    VoidCallback? onTap,
    bool isUnread = false,
  }) {
    return AppCard.glass(
      onTap: onTap,
      borderColor: isUnread ? AppColors.telegramBlue : null,
      child: child,
    );
  }

  factory AppCard.school({
    required Widget child,
    VoidCallback? onTap,
    bool isSelected = false,
  }) {
    return AppCard.glass(
      onTap: onTap,
      borderColor: isSelected ? AppColors.telegramBlue : null,
      child: child,
    );
  }

  factory AppCard.subscription({
    required Widget child,
    VoidCallback? onTap,
    Color? statusColor,
  }) {
    return AppCard.glass(
      onTap: onTap,
      borderColor: statusColor,
      child: child,
    );
  }

  factory AppCard.paymentMethod({
    required Widget child,
    VoidCallback? onTap,
    bool isSelected = false,
  }) {
    return AppCard.glass(
      onTap: onTap,
      borderColor: isSelected ? AppColors.telegramBlue : null,
      child: child,
    );
  }

  factory AppCard.contact({
    required Widget child,
    VoidCallback? onTap,
    Color? accentColor,
  }) {
    return AppCard.glass(
      onTap: onTap,
      borderColor: accentColor,
      child: child,
    );
  }

  factory AppCard.menu({
    required Widget child,
    VoidCallback? onTap,
  }) {
    return AppCard.glass(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: child,
    );
  }

  factory AppCard.stats({
    required Widget child,
  }) {
    return AppCard.glass(
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? _getDefaultMargin(context),
      child: _buildCard(context),
    );
  }

  Widget _buildCard(BuildContext context) {
    final borderRadiusValue = borderRadius ?? _getBorderRadius(context);

    Widget card = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadiusValue),
      child: _buildContent(context, borderRadiusValue),
    );

    if (onTap != null) {
      card = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadiusValue),
          splashColor: AppColors.telegramBlue.withValues(alpha: 0.1),
          highlightColor: Colors.transparent,
          child: card,
        ),
      );
    }

    return card;
  }

  Widget _buildContent(BuildContext context, double borderRadius) {
    switch (variant) {
      case CardVariant.glass:
        return _buildGlassCard(context, borderRadius);
      case CardVariant.solid:
        return _buildSolidCard(context, borderRadius);
      case CardVariant.outline:
        return _buildOutlineCard(context, borderRadius);
      case CardVariant.elevated:
        return _buildElevatedCard(context, borderRadius);
      case CardVariant.flat:
        return _buildFlatCard(context, borderRadius);
    }
  }

  Widget _buildGlassCard(BuildContext context, double borderRadius) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.getCard(context).withValues(alpha: 0.4),
              AppColors.getCard(context).withValues(alpha: 0.2),
            ],
          ),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: borderColor?.withValues(alpha: 0.3) ??
                AppColors.telegramBlue.withValues(alpha: 0.2),
          ),
        ),
        padding: padding ?? _getDefaultPadding(context),
        child: child,
      ),
    );
  }

  Widget _buildSolidCard(BuildContext context, double borderRadius) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.getCard(context),
        borderRadius: BorderRadius.circular(borderRadius),
        border: borderColor != null ? Border.all(color: borderColor!) : null,
        boxShadow: hasShadow
            ? [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ]
            : null,
      ),
      padding: padding ?? _getDefaultPadding(context),
      child: child,
    );
  }

  Widget _buildOutlineCard(BuildContext context, double borderRadius) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor ?? AppColors.getDivider(context)),
      ),
      padding: padding ?? _getDefaultPadding(context),
      child: child,
    );
  }

  Widget _buildElevatedCard(BuildContext context, double borderRadius) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.getCard(context),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: AppColors.telegramBlue.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: padding ?? _getDefaultPadding(context),
      child: child,
    );
  }

  Widget _buildFlatCard(BuildContext context, double borderRadius) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      padding: padding ?? _getDefaultPadding(context),
      child: child,
    );
  }

  EdgeInsets _getDefaultPadding(BuildContext context) {
    switch (size) {
      case CardSize.small:
        return EdgeInsets.all(ResponsiveValues.spacingS(context));
      case CardSize.medium:
        return EdgeInsets.all(ResponsiveValues.spacingM(context));
      case CardSize.large:
        return EdgeInsets.all(ResponsiveValues.spacingL(context));
      case CardSize.compact:
        return EdgeInsets.symmetric(
          horizontal: ResponsiveValues.spacingM(context),
          vertical: ResponsiveValues.spacingXS(context),
        );
    }
  }

  EdgeInsets _getDefaultMargin(BuildContext context) {
    return EdgeInsets.only(bottom: ResponsiveValues.spacingM(context));
  }

  double _getBorderRadius(BuildContext context) =>
      ResponsiveValues.radiusXLarge(context);
}

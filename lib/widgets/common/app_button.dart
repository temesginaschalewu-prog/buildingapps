import 'package:flutter/material.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/responsive_values.dart';
import '../../utils/app_enums.dart';

class AppButton extends StatelessWidget {
  final String? label;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final ButtonSize size;
  final IconData? icon;
  final Widget? customIcon;
  final bool isLoading;
  final bool expanded;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;

  const AppButton({
    super.key,
    this.label,
    this.onPressed,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.medium,
    this.icon,
    this.customIcon,
    this.isLoading = false,
    this.expanded = false,
    this.padding,
    this.borderRadius,
  });

  const AppButton.primary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expanded = false,
  })  : variant = ButtonVariant.primary,
        size = ButtonSize.medium,
        customIcon = null,
        padding = null,
        borderRadius = null;

  const AppButton.glass({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expanded = false,
  })  : variant = ButtonVariant.secondary,
        size = ButtonSize.medium,
        customIcon = null,
        padding = null,
        borderRadius = null;

  const AppButton.success({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expanded = false,
  })  : variant = ButtonVariant.success,
        size = ButtonSize.medium,
        customIcon = null,
        padding = null,
        borderRadius = null;

  const AppButton.danger({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expanded = false,
  })  : variant = ButtonVariant.danger,
        size = ButtonSize.medium,
        customIcon = null,
        padding = null,
        borderRadius = null;

  const AppButton.outline({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expanded = false,
  })  : variant = ButtonVariant.outline,
        size = ButtonSize.medium,
        customIcon = null,
        padding = null,
        borderRadius = null;

  const AppButton.text({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expanded = false,
  })  : variant = ButtonVariant.text,
        size = ButtonSize.medium,
        customIcon = null,
        padding = null,
        borderRadius = null;

  const AppButton.icon({
    super.key,
    required this.icon,
    this.onPressed,
    this.isLoading = false,
    this.customIcon,
  })  : label = null,
        variant = ButtonVariant.icon,
        size = ButtonSize.medium,
        expanded = false,
        padding = null,
        borderRadius = null;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null && !isLoading;
    final borderRadiusValue =
        borderRadius ?? ResponsiveValues.radiusMedium(context);

    Widget button = Container(
      width: expanded ? double.infinity : null,
      decoration: _getDecoration(context, isEnabled, borderRadiusValue),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? onPressed : null,
          borderRadius: BorderRadius.circular(borderRadiusValue),
          splashColor: _getSplashColor(context),
          highlightColor: Colors.transparent,
          child: Container(
            padding: padding ?? _getDefaultPadding(context),
            child: _buildContent(context, isEnabled),
          ),
        ),
      ),
    );

    return button;
  }

  Widget _buildContent(BuildContext context, bool isEnabled) {
    if (variant == ButtonVariant.icon)
      return _buildIconContent(context, isEnabled);
    return _buildLabelContent(context, isEnabled);
  }

  Widget _buildLabelContent(BuildContext context, bool isEnabled) {
    final textColor = _getTextColor(context, isEnabled);

    return Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          SizedBox(
            width: _getIconSize(context),
            height: _getIconSize(context),
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(textColor),
            ),
          )
        else ...[
          if (icon != null) ...[
            Icon(icon, size: _getIconSize(context), color: textColor),
            SizedBox(width: _getSpacing(context)),
          ],
          if (label != null)
            Text(
              label!,
              style: _getTextStyle(context, textColor),
              textAlign: TextAlign.center,
            ),
        ],
      ],
    );
  }

  Widget _buildIconContent(BuildContext context, bool isEnabled) {
    return Container(
      width: _getIconContainerSize(context),
      height: _getIconContainerSize(context),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context).withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isEnabled ? onPressed : null,
            borderRadius:
                BorderRadius.circular(ResponsiveValues.radiusFull(context) / 2),
            splashColor: AppColors.telegramBlue.withValues(alpha: 0.2),
            highlightColor: Colors.transparent,
            child: Center(
              child: customIcon ??
                  (icon != null
                      ? Icon(
                          icon,
                          size: _getIconSize(context),
                          color: isEnabled
                              ? AppColors.telegramBlue
                              : AppColors.getTextSecondary(context),
                        )
                      : null),
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _getDecoration(
      BuildContext context, bool isEnabled, double borderRadius) {
    switch (variant) {
      case ButtonVariant.primary:
        return BoxDecoration(
          gradient: isEnabled
              ? const LinearGradient(colors: AppColors.blueGradient)
              : null,
          color:
              isEnabled ? null : AppColors.telegramGray.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                      color: AppColors.telegramBlue.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ]
              : null,
        );

      case ButtonVariant.secondary:
        return BoxDecoration(
          gradient: isEnabled
              ? LinearGradient(colors: [
                  AppColors.getCard(context).withValues(alpha: 0.4),
                  AppColors.getCard(context).withValues(alpha: 0.2)
                ])
              : null,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: isEnabled
                ? AppColors.telegramBlue.withValues(alpha: 0.3)
                : AppColors.getTextSecondary(context).withValues(alpha: 0.1),
          ),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                      color: AppColors.telegramBlue.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ]
              : null,
        );

      case ButtonVariant.success:
        return BoxDecoration(
          gradient: isEnabled
              ? const LinearGradient(colors: AppColors.greenGradient)
              : null,
          color:
              isEnabled ? null : AppColors.telegramGray.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                      color: AppColors.telegramGreen.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ]
              : null,
        );

      case ButtonVariant.danger:
        return BoxDecoration(
          gradient: isEnabled
              ? const LinearGradient(colors: AppColors.pinkGradient)
              : null,
          color:
              isEnabled ? null : AppColors.telegramGray.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                      color: AppColors.telegramRed.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ]
              : null,
        );

      case ButtonVariant.outline:
        return BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: isEnabled
                ? AppColors.telegramBlue
                : AppColors.getTextSecondary(context).withValues(alpha: 0.3),
            width: 1.5,
          ),
        );

      case ButtonVariant.text:
        return BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(borderRadius),
        );

      case ButtonVariant.icon:
        return const BoxDecoration();
    }
  }

  Color _getSplashColor(BuildContext context) {
    switch (variant) {
      case ButtonVariant.secondary:
        return AppColors.telegramBlue.withValues(alpha: 0.1);
      default:
        return Colors.white.withValues(alpha: 0.2);
    }
  }

  Color _getTextColor(BuildContext context, bool isEnabled) {
    if (!isEnabled) return AppColors.getTextSecondary(context);

    switch (variant) {
      case ButtonVariant.primary:
      case ButtonVariant.success:
      case ButtonVariant.danger:
        return Colors.white;
      case ButtonVariant.secondary:
      case ButtonVariant.outline:
      case ButtonVariant.text:
      case ButtonVariant.icon:
        return AppColors.telegramBlue;
    }
  }

  TextStyle _getTextStyle(BuildContext context, Color color) {
    switch (size) {
      case ButtonSize.small:
        return AppTextStyles.labelSmall(context)
            .copyWith(color: color, fontWeight: FontWeight.w600);
      case ButtonSize.medium:
        return AppTextStyles.labelLarge(context)
            .copyWith(color: color, fontWeight: FontWeight.w600);
      case ButtonSize.large:
        return AppTextStyles.buttonLarge(context)
            .copyWith(color: color, fontWeight: FontWeight.w600);
    }
  }

  double _getIconSize(BuildContext context) {
    switch (size) {
      case ButtonSize.small:
        return ResponsiveValues.iconSizeXS(context);
      case ButtonSize.medium:
        return ResponsiveValues.iconSizeS(context);
      case ButtonSize.large:
        return ResponsiveValues.iconSizeM(context);
    }
  }

  double _getIconContainerSize(BuildContext context) =>
      ResponsiveValues.appBarButtonSize(context);
  double _getSpacing(BuildContext context) =>
      ResponsiveValues.spacingXS(context);

  EdgeInsets _getDefaultPadding(BuildContext context) {
    if (variant == ButtonVariant.icon) return EdgeInsets.zero;

    switch (size) {
      case ButtonSize.small:
        return EdgeInsets.symmetric(
          horizontal: ResponsiveValues.spacingM(context),
          vertical: ResponsiveValues.spacingXS(context),
        );
      case ButtonSize.medium:
        return EdgeInsets.symmetric(
          horizontal: ResponsiveValues.spacingL(context),
          vertical: ResponsiveValues.spacingS(context),
        );
      case ButtonSize.large:
        return EdgeInsets.symmetric(
          horizontal: ResponsiveValues.spacingXL(context),
          vertical: ResponsiveValues.spacingM(context),
        );
    }
  }
}

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:familyacademyclient/utils/responsive_values.dart';
import '../../themes/app_themes.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import 'responsive_widgets.dart';

enum EmptyStateType {
  general,
  error,
  noInternet,
  noResults,
  noData,
  success,
  offline,
}

class EmptyState extends StatelessWidget {
  final IconData? icon;
  final Widget? customIcon;
  final String? lottieAsset;
  final String title;
  final String message;
  final String? actionText;
  final VoidCallback? onAction;
  final bool centerContent;
  final EdgeInsetsGeometry padding;
  final bool showAnimation;
  final EmptyStateType type;
  final double? maxWidth;

  const EmptyState({
    super.key,
    this.icon,
    this.customIcon,
    this.lottieAsset,
    required this.title,
    required this.message,
    this.actionText,
    this.onAction,
    this.centerContent = true,
    this.padding = const EdgeInsets.all(AppThemes.spacingL),
    this.showAnimation = true,
    this.type = EmptyStateType.general,
    this.maxWidth,
  }) : assert(icon != null || customIcon != null || lottieAsset != null,
            'Either icon, customIcon, or lottieAsset must be provided');

  Widget _buildGlassContainer(BuildContext context, {required Widget child}) {
    return ClipRRect(
      borderRadius:
          BorderRadius.circular(ResponsiveValues.radiusXLarge(context)),
      child: BackdropFilter(
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
            borderRadius:
                BorderRadius.circular(ResponsiveValues.radiusXLarge(context)),
            border: Border.all(
              color: _getBorderColor(context).withValues(alpha: 0.2),
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildGlassButton(BuildContext context,
      {required VoidCallback onPressed,
      required String label,
      required IconData icon}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _getButtonGradient(type),
        ),
        borderRadius:
            BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
        boxShadow: [
          BoxShadow(
            color: _getIconColor(context).withValues(alpha: 0.3),
            blurRadius: ResponsiveValues.spacingS(context),
            offset: Offset(0, ResponsiveValues.spacingXS(context)),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius:
              BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: ResponsiveValues.spacingM(context),
              horizontal: ResponsiveValues.spacingL(context),
            ),
            child: ResponsiveRow(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    color: Colors.white,
                    size: ResponsiveValues.iconSizeS(context)),
                ResponsiveSizedBox(width: AppSpacing.s),
                ResponsiveText(
                  label,
                  style: AppTextStyles.buttonMedium(context).copyWith(
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Container(
      constraints: BoxConstraints(
        maxWidth: maxWidth ?? 400,
        maxHeight: MediaQuery.of(context).size.height *
            0.8, // Add max height constraint
      ),
      padding: padding,
      child: _buildGlassContainer(
        context,
        child: Padding(
          padding: EdgeInsets.all(ResponsiveValues.spacingXL(context)),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: 0, // Remove minHeight constraint
                    maxWidth: constraints.maxWidth,
                  ),
                  child: ResponsiveColumn(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: centerContent
                        ? CrossAxisAlignment.center
                        : CrossAxisAlignment.start,
                    children: [
                      if (showAnimation) _buildAnimatedIcon(context),
                      ResponsiveSizedBox(height: AppSpacing.l),
                      _buildTitle(context),
                      ResponsiveSizedBox(height: AppSpacing.m),
                      _buildMessage(context),
                      if (actionText != null && onAction != null) ...[
                        ResponsiveSizedBox(height: AppSpacing.xl),
                        _buildActionButton(context),
                      ],
                      ResponsiveSizedBox(height: AppSpacing.s),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    return Padding(
      padding: ResponsiveValues.screenPadding(context),
      child: centerContent ? Center(child: content) : content,
    ).animate().fadeIn(duration: AppThemes.animationDurationMedium);
  }

  Color _getBorderColor(BuildContext context) {
    switch (type) {
      case EmptyStateType.error:
        return AppColors.telegramRed;
      case EmptyStateType.noInternet:
      case EmptyStateType.offline:
        return AppColors.telegramYellow;
      case EmptyStateType.noResults:
      case EmptyStateType.noData:
        return AppColors.telegramBlue;
      case EmptyStateType.success:
        return AppColors.telegramGreen;
      default:
        return AppColors.getTextSecondary(context);
    }
  }

  List<Color> _getButtonGradient(EmptyStateType type) {
    switch (type) {
      case EmptyStateType.error:
        return AppColors.pinkGradient;
      case EmptyStateType.noInternet:
      case EmptyStateType.offline:
        return [AppColors.telegramOrange, AppColors.telegramRed];
      case EmptyStateType.noResults:
      case EmptyStateType.noData:
        return AppColors.blueGradient;
      case EmptyStateType.success:
        return AppColors.greenGradient;
      default:
        return AppColors.blueGradient;
    }
  }

  Widget _buildAnimatedIcon(BuildContext context) {
    final iconSize = ResponsiveValues.iconSizeXXL(context) * 2;

    if (lottieAsset != null) {
      return SizedBox(
        width: iconSize,
        height: iconSize,
        child: Lottie.asset(lottieAsset!,
            width: iconSize,
            height: iconSize,
            fit: BoxFit.contain,
            repeat: true,
            animate: true),
      );
    }

    if (customIcon != null) {
      return SizedBox(width: iconSize, height: iconSize, child: customIcon);
    }

    return Container(
      width: iconSize,
      height: iconSize,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getIconColor(context).withValues(alpha: 0.2),
            _getIconColor(context).withValues(alpha: 0.05),
          ],
        ),
        shape: BoxShape.circle,
        border: Border.all(
          color: _getIconColor(context).withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: ResponsiveIcon(
        icon!,
        size: iconSize * 0.5,
        color: _getIconColor(context),
      ),
    );
  }

  Color _getIconColor(BuildContext context) {
    switch (type) {
      case EmptyStateType.error:
        return AppColors.telegramRed;
      case EmptyStateType.noInternet:
      case EmptyStateType.offline:
        return AppColors.telegramYellow;
      case EmptyStateType.noResults:
      case EmptyStateType.noData:
        return AppColors.telegramBlue;
      case EmptyStateType.success:
        return AppColors.telegramGreen;
      default:
        return AppColors.getTextSecondary(context);
    }
  }

  Widget _buildTitle(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveValues.spacingL(context),
      ),
      child: ResponsiveText(
        title,
        style: AppTextStyles.titleLarge(context).copyWith(
          fontWeight: FontWeight.w600,
        ),
        textAlign: centerContent ? TextAlign.center : TextAlign.start,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildMessage(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveValues.spacingL(context),
      ),
      child: ResponsiveText(
        message,
        style: AppTextStyles.bodyMedium(context).copyWith(
          color: AppColors.getTextSecondary(context),
          height: 1.5,
        ),
        textAlign: centerContent ? TextAlign.center : TextAlign.start,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildActionButton(BuildContext context) {
    return _buildGlassButton(
      context,
      onPressed: onAction!,
      label: actionText!,
      icon: _getActionIcon(),
    );
  }

  IconData _getActionIcon() {
    switch (type) {
      case EmptyStateType.error:
      case EmptyStateType.noInternet:
      case EmptyStateType.offline:
        return Icons.refresh_rounded;
      case EmptyStateType.noResults:
        return Icons.search_off_rounded;
      case EmptyStateType.noData:
        return Icons.cloud_download_rounded;
      case EmptyStateType.success:
        return Icons.check_circle_rounded;
      default:
        return Icons.refresh_rounded;
    }
  }
}

class NoDataState extends StatelessWidget {
  final String dataType;
  final String? customMessage;
  final VoidCallback? onRefresh;
  final String? lottieAsset;

  const NoDataState({
    super.key,
    required this.dataType,
    this.customMessage,
    this.onRefresh,
    this.lottieAsset,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      lottieAsset: lottieAsset ?? 'assets/lottie/no_data.json',
      title: 'No $dataType',
      message: customMessage ??
          '${dataType.capitalize()} will appear here when available.',
      actionText: onRefresh != null ? 'Refresh' : null,
      onAction: onRefresh,
      type: EmptyStateType.noData,
    );
  }
}

class NoInternetState extends StatelessWidget {
  final VoidCallback onRetry;
  final String? message;

  const NoInternetState({super.key, required this.onRetry, this.message});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      lottieAsset: 'assets/lottie/no_internet.json',
      title: 'No Connection',
      message:
          message ?? 'You are offline. Please check your internet connection.',
      actionText: 'Retry',
      onAction: onRetry,
      type: EmptyStateType.noInternet,
    );
  }
}

class OfflineState extends StatelessWidget {
  final String? dataType;
  final VoidCallback? onRetry;
  final String? message;

  const OfflineState({
    super.key,
    this.dataType,
    this.onRetry,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final displayMessage = message ??
        (dataType != null
            ? 'Showing cached $dataType. Connect to update.'
            : 'You are offline. Using cached data.');

    return EmptyState(
      lottieAsset: 'assets/lottie/offline.json',
      title: 'Offline Mode',
      message: displayMessage,
      actionText: onRetry != null ? 'Retry' : null,
      onAction: onRetry,
      type: EmptyStateType.offline,
    );
  }
}

class ErrorState extends StatelessWidget {
  final String title;
  final String message;
  final String actionText;
  final VoidCallback onAction;
  final String? lottieAsset;

  const ErrorState({
    super.key,
    this.title = 'Something Went Wrong',
    required this.message,
    this.actionText = 'Try Again',
    required this.onAction,
    this.lottieAsset,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      lottieAsset: lottieAsset ?? 'assets/lottie/error.json',
      title: title,
      message: message,
      actionText: actionText,
      onAction: onAction,
      type: EmptyStateType.error,
    );
  }
}

class SuccessState extends StatelessWidget {
  final String title;
  final String message;
  final String? actionText;
  final VoidCallback? onAction;
  final String? lottieAsset;

  const SuccessState({
    super.key,
    required this.title,
    required this.message,
    this.actionText,
    this.onAction,
    this.lottieAsset,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      lottieAsset: lottieAsset ?? 'assets/lottie/success.json',
      title: title,
      message: message,
      actionText: actionText,
      onAction: onAction,
      type: EmptyStateType.success,
    );
  }
}

class NoResultsState extends StatelessWidget {
  final String searchQuery;
  final VoidCallback? onClearSearch;

  const NoResultsState({
    super.key,
    required this.searchQuery,
    this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      lottieAsset: 'assets/lottie/no_results.json',
      title: 'No Results',
      message: 'No results found for "$searchQuery". Try different keywords.',
      actionText: onClearSearch != null ? 'Clear Search' : null,
      onAction: onClearSearch,
      type: EmptyStateType.noResults,
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}

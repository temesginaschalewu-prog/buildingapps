import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import '../../themes/app_themes.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';

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
  final double? maxWidth; // New parameter to control width

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

  @override
  Widget build(BuildContext context) {
    final content = Container(
      constraints: BoxConstraints(
        maxWidth: maxWidth ?? double.infinity,
      ),
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.getCard(context),
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
        border: Border.all(
          color: _getBorderColor(context),
          width: 0.5,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: centerContent
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.start,
                  children: [
                    if (showAnimation) _buildAnimatedIcon(context),

                    SizedBox(height: AppThemes.spacingL),

                    _buildTitle(context),

                    SizedBox(height: AppThemes.spacingM),

                    _buildMessage(context, constraints),

                    if (actionText != null && onAction != null) ...[
                      SizedBox(height: AppThemes.spacingXL),
                      _buildActionButton(context),
                    ],

                    // Add extra bottom padding for scroll safety
                    SizedBox(height: AppThemes.spacingS),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    return Padding(
      padding: EdgeInsets.all(AppThemes.spacingL),
      child: centerContent ? Center(child: content) : content,
    ).animate().fadeIn(duration: AppThemes.animationDurationMedium);
  }

  Color _getBorderColor(BuildContext context) {
    switch (type) {
      case EmptyStateType.error:
        return AppColors.telegramRed.withOpacity(0.3);
      case EmptyStateType.noInternet:
      case EmptyStateType.offline:
        return AppColors.telegramYellow.withOpacity(0.3);
      case EmptyStateType.noResults:
      case EmptyStateType.noData:
        return AppColors.telegramBlue.withOpacity(0.3);
      case EmptyStateType.success:
        return AppColors.telegramGreen.withOpacity(0.3);
      default:
        return Theme.of(context).dividerColor;
    }
  }

  Widget _buildAnimatedIcon(BuildContext context) {
    final iconSize = ScreenSize.responsiveValue(
      context: context,
      mobile: 80.0,
      tablet: 100.0,
      desktop: 120.0,
    );

    if (lottieAsset != null) {
      return SizedBox(
        width: iconSize,
        height: iconSize,
        child: Lottie.asset(
          lottieAsset!,
          width: iconSize,
          height: iconSize,
          fit: BoxFit.contain,
          repeat: true,
          animate: true,
        ),
      );
    }

    if (customIcon != null) {
      return SizedBox(
        width: iconSize,
        height: iconSize,
        child: customIcon,
      );
    }

    return Container(
      width: iconSize,
      height: iconSize,
      decoration: BoxDecoration(
        color: _getIconColor(context).withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(
          color: _getIconColor(context).withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Icon(
        icon,
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
        horizontal: AppThemes.spacingL,
      ),
      child: Text(
        title,
        style: AppTextStyles.titleLarge.copyWith(
          color: AppColors.getTextPrimary(context),
          fontWeight: FontWeight.w600,
        ),
        textAlign: centerContent ? TextAlign.center : TextAlign.start,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildMessage(BuildContext context, BoxConstraints constraints) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppThemes.spacingL,
      ),
      child: Text(
        message,
        style: AppTextStyles.bodyMedium.copyWith(
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
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppThemes.spacingL,
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onAction,
          style: ElevatedButton.styleFrom(
            backgroundColor: _getButtonColor(context),
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              vertical: AppThemes.spacingM,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
            ),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getActionIcon(),
                size: 18,
              ),
              SizedBox(width: AppThemes.spacingS),
              Text(
                actionText!,
                style: AppTextStyles.buttonMedium,
              ),
            ],
          ),
        ),
      ),
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

  Color _getButtonColor(BuildContext context) {
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
        return AppColors.telegramBlue;
    }
  }
}

enum EmptyStateType {
  general,
  error,
  noInternet,
  noResults,
  noData,
  success,
  offline,
}

// Specialized empty states
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
      maxWidth: 400,
    );
  }
}

class NoInternetState extends StatelessWidget {
  final VoidCallback onRetry;
  final String? customMessage;

  const NoInternetState({
    super.key,
    required this.onRetry,
    this.customMessage,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      lottieAsset: 'assets/lottie/no_internet.json',
      title: 'No Connection',
      message: customMessage ??
          'You are offline. Please check your internet connection.',
      actionText: 'Retry',
      onAction: onRetry,
      type: EmptyStateType.noInternet,
      maxWidth: 400,
    );
  }
}

class OfflineState extends StatelessWidget {
  final String? customMessage;
  final String? dataType;
  final VoidCallback? onRetry;

  const OfflineState({
    super.key,
    this.customMessage,
    this.dataType,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final message = customMessage ??
        (dataType != null
            ? 'Showing cached $dataType. Connect to update.'
            : 'You are offline. Using cached data.');

    return EmptyState(
      lottieAsset: 'assets/lottie/offline.json',
      title: 'Offline Mode',
      message: message,
      actionText: onRetry != null ? 'Retry' : null,
      onAction: onRetry,
      type: EmptyStateType.offline,
      maxWidth: 400,
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
      maxWidth: 400,
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
      maxWidth: 400,
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
      maxWidth: 400,
    );
  }
}

// Loading/Empty switch with proper constraints
class LoadingEmptySwitch extends StatelessWidget {
  final bool isLoading;
  final bool isEmpty;
  final bool hasError;
  final bool isOffline;
  final Widget loadingWidget;
  final Widget emptyWidget;
  final Widget errorWidget;
  final Widget? offlineWidget;
  final Widget content;
  final String? emptyMessage;
  final String? errorMessage;
  final String? offlineMessage;
  final VoidCallback? onRetry;
  final String? dataType;

  const LoadingEmptySwitch({
    super.key,
    required this.isLoading,
    required this.isEmpty,
    required this.hasError,
    this.isOffline = false,
    required this.loadingWidget,
    required this.emptyWidget,
    required this.errorWidget,
    this.offlineWidget,
    required this.content,
    this.emptyMessage,
    this.errorMessage,
    this.offlineMessage,
    this.onRetry,
    this.dataType,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: loadingWidget,
        ),
      );
    }

    if (hasError) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: errorWidget,
        ),
      );
    }

    if (isOffline) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: offlineWidget ??
              OfflineState(
                dataType: dataType,
                customMessage: offlineMessage,
                onRetry: onRetry,
              ),
        ),
      );
    }

    if (isEmpty) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: emptyWidget,
        ),
      );
    }

    return content;
  }
}

// Cached data widget with proper constraints
class CachedDataWidget extends StatelessWidget {
  final bool hasCachedData;
  final bool isLoading;
  final bool hasError;
  final bool isOffline;
  final Widget cachedContent;
  final Widget loadingWidget;
  final Widget emptyWidget;
  final Widget errorWidget;
  final VoidCallback? onRetry;
  final String dataType;

  const CachedDataWidget({
    super.key,
    required this.hasCachedData,
    required this.isLoading,
    required this.hasError,
    required this.isOffline,
    required this.cachedContent,
    required this.loadingWidget,
    required this.emptyWidget,
    required this.errorWidget,
    this.onRetry,
    required this.dataType,
  });

  @override
  Widget build(BuildContext context) {
    if (hasCachedData) {
      return Stack(
        children: [
          cachedContent,
          if (isLoading || hasError || !isOffline)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.4),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: _buildOverlayContent(context),
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return LoadingEmptySwitch(
      isLoading: isLoading,
      isEmpty: !hasCachedData && !isLoading && !hasError,
      hasError: hasError,
      isOffline: isOffline,
      loadingWidget: loadingWidget,
      emptyWidget: emptyWidget,
      errorWidget: errorWidget,
      content: cachedContent,
      onRetry: onRetry,
      dataType: dataType,
    );
  }

  Widget _buildOverlayContent(BuildContext context) {
    if (isLoading) {
      return Container(
        padding: EdgeInsets.all(AppThemes.spacingL),
        decoration: BoxDecoration(
          color: AppColors.getCard(context),
          borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(AppColors.telegramBlue),
              ),
            ),
            SizedBox(height: AppThemes.spacingM),
            Text(
              'Updating...',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.getTextPrimary(context),
              ),
            ),
          ],
        ),
      );
    }

    if (hasError) {
      return Container(
        padding: EdgeInsets.all(AppThemes.spacingL),
        decoration: BoxDecoration(
          color: AppColors.getCard(context),
          borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: AppColors.telegramRed,
              size: 32,
            ),
            SizedBox(height: AppThemes.spacingM),
            Text(
              'Update failed',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.getTextPrimary(context),
              ),
            ),
            SizedBox(height: AppThemes.spacingM),
            if (onRetry != null)
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.telegramRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppThemes.borderRadiusMedium),
                  ),
                ),
                child: Text('Retry'),
              ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(AppThemes.spacingL),
      decoration: BoxDecoration(
        color: AppColors.getCard(context),
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: AppThemes.spacingM),
        ],
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}

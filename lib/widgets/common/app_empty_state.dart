import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/responsive_values.dart';
import 'app_card.dart';
import 'app_button.dart';

enum EmptyStateType {
  general,
  error,
  noInternet,
  noResults,
  noData,
  success,
  offline,
}

class AppEmptyState extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String message;
  final String? actionText;
  final VoidCallback? onAction;
  final bool centerContent;
  final EdgeInsetsGeometry padding;
  final bool showAnimation;
  final EmptyStateType type;
  final double? maxWidth;

  const AppEmptyState({
    super.key,
    this.icon,
    required this.title,
    required this.message,
    this.actionText,
    this.onAction,
    this.centerContent = true,
    this.padding = const EdgeInsets.all(16),
    this.showAnimation = true,
    this.type = EmptyStateType.general,
    this.maxWidth,
  });

  factory AppEmptyState.noData({
    required String dataType,
    String? customMessage,
    VoidCallback? onRefresh,
  }) {
    return AppEmptyState(
      icon: Icons.inbox_rounded,
      title: 'No $dataType',
      message: customMessage ?? 'No $dataType available.',
      actionText: onRefresh != null ? 'Refresh' : null,
      onAction: onRefresh,
      type: EmptyStateType.noData,
    );
  }

  factory AppEmptyState.offline({
    String? message,
    VoidCallback? onRetry,
    String? dataType,
  }) {
    final displayMessage = message ??
        (dataType != null
            ? 'No cached $dataType available. Connect to internet.'
            : 'You are offline. Connect to internet.');

    return AppEmptyState(
      icon: Icons.wifi_off_rounded,
      title: 'Offline Mode',
      message: displayMessage,
      actionText: onRetry != null ? 'Retry' : null,
      onAction: onRetry,
      type: EmptyStateType.offline,
    );
  }

  factory AppEmptyState.error({
    required String title,
    required String message,
    VoidCallback? onRetry,
  }) {
    return AppEmptyState(
      icon: Icons.error_outline_rounded,
      title: title,
      message: message,
      actionText: onRetry != null ? 'Try Again' : null,
      onAction: onRetry,
      type: EmptyStateType.error,
    );
  }

  factory AppEmptyState.success({
    required String title,
    required String message,
    VoidCallback? onAction,
  }) {
    return AppEmptyState(
      icon: Icons.check_circle_rounded,
      title: title,
      message: message,
      actionText: 'Continue',
      onAction: onAction,
      type: EmptyStateType.success,
    );
  }

  factory AppEmptyState.noResults({
    required String searchQuery,
    VoidCallback? onClearSearch,
  }) {
    return AppEmptyState(
      icon: Icons.search_off_rounded,
      title: 'No Results',
      message: 'No results found for "$searchQuery". Try different keywords.',
      actionText: onClearSearch != null ? 'Clear Search' : null,
      onAction: onClearSearch,
      type: EmptyStateType.noResults,
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Container(
      constraints: BoxConstraints(
        maxWidth: maxWidth ?? 400,
      ),
      padding: padding,
      child: AppCard.glass(
        child: Padding(
          padding: EdgeInsets.all(ResponsiveValues.spacingXL(context)),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: centerContent
                        ? CrossAxisAlignment.center
                        : CrossAxisAlignment.start,
                    children: [
                      if (showAnimation) _buildAnimatedIcon(context),
                      SizedBox(height: ResponsiveValues.spacingL(context)),
                      _buildTitle(context),
                      SizedBox(height: ResponsiveValues.spacingM(context)),
                      _buildMessage(context),
                      if (actionText != null && onAction != null) ...[
                        SizedBox(height: ResponsiveValues.spacingXL(context)),
                        _buildActionButton(context),
                      ],
                      SizedBox(height: ResponsiveValues.spacingS(context)),
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
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildAnimatedIcon(BuildContext context) {
    final iconSize = ResponsiveValues.iconSizeXXL(context) * 2;

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
      child: Icon(
        icon ?? _getIconForType(),
        size: iconSize * 0.5,
        color: _getIconColor(context),
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveValues.spacingL(context),
      ),
      child: Text(
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
      child: Text(
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
    return AppButton.primary(
      label: actionText,
      icon: _getActionIcon(),
      onPressed: onAction,
    );
  }

  IconData _getIconForType() {
    switch (type) {
      case EmptyStateType.error:
        return Icons.error_outline_rounded;
      case EmptyStateType.noInternet:
      case EmptyStateType.offline:
        return Icons.wifi_off_rounded;
      case EmptyStateType.noResults:
        return Icons.search_off_rounded;
      case EmptyStateType.noData:
        return Icons.inbox_rounded;
      case EmptyStateType.success:
        return Icons.check_circle_rounded;
      default:
        return Icons.info_outline_rounded;
    }
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

  IconData _getActionIcon() {
    switch (type) {
      case EmptyStateType.error:
      case EmptyStateType.noInternet:
      case EmptyStateType.offline:
        return Icons.refresh_rounded;
      case EmptyStateType.noResults:
        return Icons.search_off_rounded;
      case EmptyStateType.noData:
        return Icons.refresh_rounded;
      case EmptyStateType.success:
        return Icons.arrow_forward_rounded;
      default:
        return Icons.refresh_rounded;
    }
  }
}

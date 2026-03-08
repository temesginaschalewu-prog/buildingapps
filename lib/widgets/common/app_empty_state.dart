import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/responsive_values.dart';
import 'app_card.dart';
import 'app_button.dart';

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
  final bool isRefreshing;
  final int? pendingCount; // NEW: For queued actions

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
    this.isRefreshing = false,
    this.pendingCount,
  });

  factory AppEmptyState.noData({
    required String dataType,
    String? customMessage,
    VoidCallback? onRefresh,
    bool isRefreshing = false,
    bool isOffline = false,
    int? pendingCount,
  }) {
    final message = isOffline
        ? 'No cached $dataType available. Connect to internet.'
        : (customMessage ?? 'No $dataType available.');

    final title = isOffline ? 'Offline Mode' : 'No $dataType';
    final icon = isOffline ? Icons.wifi_off_rounded : Icons.inbox_rounded;
    final type = isOffline ? EmptyStateType.offline : EmptyStateType.noData;

    return AppEmptyState(
      icon: icon,
      title: title,
      message: message,
      actionText: onRefresh != null
          ? (isRefreshing ? 'Refreshing...' : 'Refresh')
          : null,
      onAction: onRefresh,
      type: type,
      isRefreshing: isRefreshing,
      pendingCount: pendingCount,
    );
  }

  factory AppEmptyState.offline({
    String? message,
    VoidCallback? onRetry,
    String? dataType,
    bool isRefreshing = false,
    int? pendingCount,
  }) {
    final displayMessage = message ??
        (dataType != null
            ? 'No cached $dataType available. Connect to internet.'
            : 'You are offline. Connect to internet.');

    return AppEmptyState(
      icon: Icons.wifi_off_rounded,
      title: 'Offline Mode',
      message: displayMessage,
      actionText:
          onRetry != null ? (isRefreshing ? 'Connecting...' : 'Retry') : null,
      onAction: onRetry,
      type: EmptyStateType.offline,
      isRefreshing: isRefreshing,
      pendingCount: pendingCount,
    );
  }

  factory AppEmptyState.queued({
    required String action,
    int? count,
    VoidCallback? onSync,
    bool isSyncing = false,
  }) {
    final pendingCount = count ?? 1;
    final actionText = pendingCount > 1 ? '$pendingCount actions' : '1 action';

    return AppEmptyState(
      icon: Icons.schedule_rounded,
      title: 'Changes Queued',
      message:
          '$actionText waiting to sync. $action will complete when online.',
      actionText: isSyncing ? 'Syncing...' : 'Sync Now',
      onAction: onSync,
      type: EmptyStateType.queued,
      isRefreshing: isSyncing,
      pendingCount: pendingCount,
    );
  }

  factory AppEmptyState.syncing({
    String? message,
  }) {
    return AppEmptyState(
      icon: Icons.sync_rounded,
      title: 'Syncing...',
      message: message ?? 'Your changes are being synced.',
      type: EmptyStateType.syncing,
      isRefreshing: true,
    );
  }

  factory AppEmptyState.error({
    required String title,
    required String message,
    VoidCallback? onRetry,
    bool isRefreshing = false,
  }) {
    return AppEmptyState(
      icon: Icons.error_outline_rounded,
      title: title,
      message: message,
      actionText:
          onRetry != null ? (isRefreshing ? 'Retrying...' : 'Try Again') : null,
      onAction: onRetry,
      type: EmptyStateType.error,
      isRefreshing: isRefreshing,
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
      constraints: BoxConstraints(maxWidth: maxWidth ?? 400),
      padding: padding,
      child: AppCard.glass(
        isOffline:
            type == EmptyStateType.offline || type == EmptyStateType.queued,
        child: Padding(
          padding: EdgeInsets.all(ResponsiveValues.spacingXL(context)),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: constraints.maxWidth),
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
                      if (pendingCount != null && pendingCount! > 1)
                        Padding(
                          padding: EdgeInsets.only(
                              top: ResponsiveValues.spacingM(context)),
                          child: _buildPendingBadge(context),
                        ),
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
    final iconColor = _getIconColor(context);

    return Container(
      width: iconSize,
      height: iconSize,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            iconColor.withValues(alpha: 0.2),
            iconColor.withValues(alpha: 0.05)
          ],
        ),
        shape: BoxShape.circle,
        border: Border.all(color: iconColor.withValues(alpha: 0.3), width: 2),
      ),
      child: type == EmptyStateType.syncing
          ? const Center(
              child: SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.telegramBlue),
                ),
              ),
            )
          : Icon(
              icon ?? _getIconForType(),
              size: iconSize * 0.5,
              color: iconColor,
            ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.symmetric(horizontal: ResponsiveValues.spacingL(context)),
      child: Text(
        title,
        style: AppTextStyles.titleLarge(context)
            .copyWith(fontWeight: FontWeight.w600),
        textAlign: centerContent ? TextAlign.center : TextAlign.start,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildMessage(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.symmetric(horizontal: ResponsiveValues.spacingL(context)),
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

  Widget _buildPendingBadge(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveValues.spacingM(context),
        vertical: ResponsiveValues.spacingXS(context),
      ),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.1),
        borderRadius:
            BorderRadius.circular(ResponsiveValues.radiusFull(context)),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schedule_rounded,
            size: ResponsiveValues.iconSizeXS(context),
            color: AppColors.info,
          ),
          SizedBox(width: ResponsiveValues.spacingXS(context)),
          Text(
            '$pendingCount pending',
            style: AppTextStyles.labelSmall(context).copyWith(
              color: AppColors.info,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // Find this method and update it:
  Widget _buildActionButton(BuildContext context) {
    if (isRefreshing) {
      return Container(
        width: double.infinity,
        height: ResponsiveValues.buttonHeightMedium(context),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: AppColors.blueGradient),
          borderRadius:
              BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: ResponsiveValues.iconSizeS(context),
                height: ResponsiveValues.iconSizeS(context),
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: ResponsiveValues.spacingS(context)),
              Text(
                actionText ?? 'Loading...',
                style: AppTextStyles.labelLarge(context)
                    .copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    return AppButton.primary(
      label: actionText,
      icon: _getActionIcon(),
      onPressed: onAction,
      requiresOnline: type == EmptyStateType.offline ? false : true,
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
      case EmptyStateType.queued:
        return Icons.schedule_rounded;
      case EmptyStateType.syncing:
        return Icons.sync_rounded;
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
        return AppColors.warning;
      case EmptyStateType.noResults:
      case EmptyStateType.noData:
        return AppColors.telegramBlue;
      case EmptyStateType.success:
        return AppColors.telegramGreen;
      case EmptyStateType.queued:
      case EmptyStateType.syncing:
        return AppColors.info;
      default:
        return AppColors.getTextSecondary(context);
    }
  }

  IconData _getActionIcon() {
    if (isRefreshing) return Icons.hourglass_empty_rounded;

    switch (type) {
      case EmptyStateType.error:
      case EmptyStateType.noInternet:
      case EmptyStateType.offline:
      case EmptyStateType.noData:
        return Icons.refresh_rounded;
      case EmptyStateType.noResults:
        return Icons.search_off_rounded;
      case EmptyStateType.success:
        return Icons.arrow_forward_rounded;
      case EmptyStateType.queued:
      case EmptyStateType.syncing:
        return Icons.sync_rounded;
      default:
        return Icons.refresh_rounded;
    }
  }
}

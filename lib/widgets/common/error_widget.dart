import 'dart:ui';
import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import 'package:familyacademyclient/utils/responsive_values.dart';
import 'package:familyacademyclient/utils/app_enums.dart';
import '../../themes/app_themes.dart';
import 'responsive_widgets.dart';

enum ErrorType {
  general,
  network,
  server,
  access,
  notFound,
  timeout,
  payment,
}

class ErrorWidget extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final IconData? icon;
  final bool fullScreen;
  final ErrorType type;
  final String? lottieAsset;
  final bool showAnimation;

  const ErrorWidget({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
    this.icon,
    this.fullScreen = false,
    this.type = ErrorType.general,
    this.lottieAsset,
    this.showAnimation = true,
  });

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
              color: _getIconColor(context).withValues(alpha: 0.2),
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
                const ResponsiveSizedBox(width: AppSpacing.s),
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
      padding: EdgeInsets.all(ResponsiveValues.spacingXL(context)),
      child: _buildGlassContainer(
        context,
        child: Padding(
          padding: EdgeInsets.all(ResponsiveValues.spacingXXL(context)),
          child: SingleChildScrollView(
            child: ResponsiveColumn(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showAnimation) _buildAnimatedIcon(context),
                const ResponsiveSizedBox(height: AppSpacing.xxl),
                _buildTitle(context),
                const ResponsiveSizedBox(height: AppSpacing.m),
                _buildMessage(context),
                if (onRetry != null) ...[
                  const ResponsiveSizedBox(height: AppSpacing.xxl),
                  _buildActionButtons(context),
                ],
                const ResponsiveSizedBox(height: AppSpacing.l),
              ],
            ),
          ),
        ),
      ),
    );

    final widget = fullScreen
        ? Scaffold(
            backgroundColor: AppColors.getBackground(context),
            body: SafeArea(child: Center(child: content)),
          )
        : Center(child: content);

    return widget
        .animate()
        .fadeIn(duration: AppThemes.animationDurationMedium)
        .slideY(
            begin: 0.1, end: 0, duration: AppThemes.animationDurationMedium);
  }

  List<Color> _getButtonGradient(ErrorType type) {
    switch (type) {
      case ErrorType.network:
        return AppColors.blueGradient;
      case ErrorType.server:
      case ErrorType.payment:
        return AppColors.pinkGradient;
      case ErrorType.access:
      case ErrorType.timeout:
        return [AppColors.telegramOrange, AppColors.telegramRed];
      case ErrorType.notFound:
        return AppColors.blueGradient;
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
        child: Lottie.asset(
          lottieAsset!,
          width: iconSize,
          height: iconSize,
          fit: BoxFit.contain,
          repeat: false,
          animate: true,
        ),
      );
    }

    final typeLottieAsset = _getLottieAssetForType();
    if (typeLottieAsset != null) {
      return SizedBox(
        width: iconSize,
        height: iconSize,
        child: Lottie.asset(
          typeLottieAsset,
          width: iconSize,
          height: iconSize,
          fit: BoxFit.contain,
          repeat: false,
          animate: true,
        ),
      );
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
          color: _getIconColor(context).withValues(alpha: 0.2),
          width: 2.0,
        ),
      ),
      child: ResponsiveIcon(
        icon ?? _getIconForType(),
        size: iconSize * 0.4,
        color: _getIconColor(context),
      ),
    )
        .animate(onPlay: (controller) => controller.repeat())
        .shake(hz: 1, duration: const Duration(seconds: 3));
  }

  String? _getLottieAssetForType() {
    switch (type) {
      case ErrorType.network:
        return 'assets/lottie/no-internet.json';
      case ErrorType.server:
        return 'assets/lottie/server-error.json';
      case ErrorType.access:
        return 'assets/lottie/access-denied.json';
      case ErrorType.notFound:
        return 'assets/lottie/not-found.json';
      case ErrorType.timeout:
        return 'assets/lottie/timeout.json';
      case ErrorType.payment:
        return 'assets/lottie/payment-error.json';
      default:
        return 'assets/lottie/error.json';
    }
  }

  IconData _getIconForType() {
    switch (type) {
      case ErrorType.network:
        return Icons.wifi_off_outlined;
      case ErrorType.server:
        return Icons.cloud_off_outlined;
      case ErrorType.access:
        return Icons.lock_outline;
      case ErrorType.notFound:
        return Icons.search_off_outlined;
      case ErrorType.timeout:
        return Icons.schedule_outlined;
      case ErrorType.payment:
        return Icons.payment_outlined;
      default:
        return Icons.error_outline;
    }
  }

  Color _getIconColor(BuildContext context) {
    switch (type) {
      case ErrorType.network:
        return AppColors.telegramGray;
      case ErrorType.server:
        return AppColors.telegramRed;
      case ErrorType.access:
        return AppColors.telegramYellow;
      case ErrorType.notFound:
        return AppColors.telegramBlue;
      case ErrorType.timeout:
        return AppColors.telegramYellow;
      case ErrorType.payment:
        return AppColors.telegramRed;
      default:
        return AppColors.telegramRed;
    }
  }

  Widget _buildTitle(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveValues.spacingL(context),
        vertical: ResponsiveValues.spacingS(context),
      ),
      decoration: BoxDecoration(
        color: _getIconColor(context).withValues(alpha: 0.1),
        borderRadius:
            BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
      ),
      child: ResponsiveText(
        title,
        style: AppTextStyles.titleLarge(context).copyWith(
          fontWeight: FontWeight.w600,
          fontSize: ResponsiveValues.fontHeadlineSmall(context),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildMessage(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveValues.spacingXL(context),
      ),
      child: ResponsiveText(
        message,
        textAlign: TextAlign.center,
        style: AppTextStyles.bodyMedium(context).copyWith(
          color: AppColors.getTextSecondary(context),
          fontSize: ResponsiveValues.fontBodyLarge(context),
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return ResponsiveColumn(
      children: [
        _buildGlassButton(
          context,
          onPressed: onRetry!,
          label: 'Try Again',
          icon: Icons.refresh_outlined,
        ),
        if (type == ErrorType.network || type == ErrorType.access) ...[
          const ResponsiveSizedBox(height: AppSpacing.l),
          TextButton(
            onPressed: () => _showHelpDialog(context),
            style: TextButton.styleFrom(
              foregroundColor: _getIconColor(context),
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveValues.spacingXL(context),
                vertical: ResponsiveValues.spacingM(context),
              ),
            ),
            child: ResponsiveRow(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.help_outline_outlined,
                    size: ResponsiveValues.iconSizeS(context)),
                const ResponsiveSizedBox(width: AppSpacing.s),
                ResponsiveText(
                  'Need Help?',
                  style: AppTextStyles.bodyMedium(context).copyWith(
                    fontSize: ResponsiveValues.fontBodyLarge(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: _buildGlassContainer(
          context,
          child: Padding(
            padding: ResponsiveValues.dialogPadding(context),
            child: ResponsiveColumn(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(ResponsiveValues.spacingM(context)),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _getIconColor(context).withValues(alpha: 0.2),
                        _getIconColor(context).withValues(alpha: 0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: ResponsiveIcon(
                    _getIconForType(),
                    size: ResponsiveValues.iconSizeXL(context),
                    color: _getIconColor(context),
                  ),
                ),
                const ResponsiveSizedBox(height: AppSpacing.l),
                ResponsiveText(
                  'Help with ${type.name} Error',
                  style: AppTextStyles.titleLarge(context).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const ResponsiveSizedBox(height: AppSpacing.m),
                Container(
                  padding: ResponsiveValues.cardPadding(context),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.getCard(context).withValues(alpha: 0.3),
                        AppColors.getCard(context).withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusMedium(context)),
                  ),
                  child: ResponsiveText(
                    _getHelpMessage(),
                    style: AppTextStyles.bodyMedium(context).copyWith(
                      color: AppColors.getTextSecondary(context),
                      height: 1.5,
                    ),
                  ),
                ),
                const ResponsiveSizedBox(height: AppSpacing.xl),
                ResponsiveRow(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.getTextSecondary(context),
                          padding: EdgeInsets.symmetric(
                            vertical: ResponsiveValues.spacingM(context),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              ResponsiveValues.radiusMedium(context),
                            ),
                          ),
                        ),
                        child: const Text('Close'),
                      ),
                    ),
                    const ResponsiveSizedBox(width: AppSpacing.m),
                    Expanded(
                      child: _buildGlassButton(
                        context,
                        onPressed: () {
                          Navigator.of(context).pop();
                          onRetry?.call();
                        },
                        label: 'Retry',
                        icon: Icons.refresh_rounded,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getHelpMessage() {
    switch (type) {
      case ErrorType.network:
        return '• Check your internet connection\n'
            '• Switch between WiFi and mobile data\n'
            '• Restart your router if needed\n'
            '• Make sure other apps can connect';
      case ErrorType.access:
        return '• Ensure you are logged in\n'
            '• Check your subscription status\n'
            '• Contact support if needed\n'
            '• Try logging out and back in';
      case ErrorType.server:
        return '• This is a temporary server issue\n'
            '• Try again in a few minutes\n'
            '• Our team has been notified\n'
            '• Check status page for updates';
      case ErrorType.timeout:
        return '• Request took too long to complete\n'
            '• Try with better internet connection\n'
            '• Server might be under high load\n'
            '• Check your network speed';
      default:
        return 'An unexpected error occurred. Please try again or contact support if the problem persists.';
    }
  }
}

class NetworkErrorWidget extends StatelessWidget {
  final VoidCallback onRetry;
  final bool fullScreen;
  final bool showOfflineContent;

  const NetworkErrorWidget({
    super.key,
    required this.onRetry,
    this.fullScreen = false,
    this.showOfflineContent = false,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorWidget(
      title: 'No Connection',
      message: showOfflineContent
          ? 'You\'re offline. Some features may not be available. Cached content is still accessible.'
          : 'Unable to connect to the server. Please check your internet connection and try again.',
      onRetry: onRetry,
      type: ErrorType.network,
      fullScreen: fullScreen,
    );
  }
}

class ServerErrorWidget extends StatelessWidget {
  final VoidCallback onRetry;
  final bool fullScreen;

  const ServerErrorWidget({
    super.key,
    required this.onRetry,
    this.fullScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorWidget(
      title: 'Server Error',
      message:
          'We\'re experiencing technical difficulties. Our team has been notified. Please try again in a few moments.',
      onRetry: onRetry,
      type: ErrorType.server,
      fullScreen: fullScreen,
    );
  }
}

class AccessErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onAction;
  final bool fullScreen;

  const AccessErrorWidget({
    super.key,
    required this.message,
    this.onAction,
    this.fullScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorWidget(
      title: 'Access Restricted',
      message: message,
      onRetry: onAction,
      type: ErrorType.access,
      fullScreen: fullScreen,
    );
  }
}

class NotFoundErrorWidget extends StatelessWidget {
  final String resource;
  final VoidCallback onRetry;
  final bool fullScreen;

  const NotFoundErrorWidget({
    super.key,
    required this.resource,
    required this.onRetry,
    this.fullScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorWidget(
      title: 'Not Found',
      message:
          'The requested $resource was not found. It may have been removed or you may not have access to it.',
      onRetry: onRetry,
      type: ErrorType.notFound,
      fullScreen: fullScreen,
    );
  }
}

class TimeoutErrorWidget extends StatelessWidget {
  final VoidCallback onRetry;
  final bool fullScreen;

  const TimeoutErrorWidget({
    super.key,
    required this.onRetry,
    this.fullScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorWidget(
      title: 'Request Timeout',
      message:
          'The request took too long to complete. This could be due to a slow internet connection or server issues.',
      onRetry: onRetry,
      type: ErrorType.timeout,
      fullScreen: fullScreen,
    );
  }
}

class PaymentErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final bool fullScreen;

  const PaymentErrorWidget({
    super.key,
    required this.message,
    required this.onRetry,
    this.fullScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorWidget(
      title: 'Payment Error',
      message: message,
      onRetry: onRetry,
      type: ErrorType.payment,
      fullScreen: fullScreen,
    );
  }
}

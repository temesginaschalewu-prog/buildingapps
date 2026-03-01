import 'dart:ui';
import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import '../../themes/app_themes.dart';

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
      borderRadius: BorderRadius.circular(24),
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
            borderRadius: BorderRadius.circular(24),
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _getIconColor(context).withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: AppTextStyles.buttonMedium.copyWith(
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
      padding: EdgeInsets.all(ScreenSize.responsiveValue(
        context: context,
        mobile: AppThemes.spacingL,
        tablet: AppThemes.spacingXL,
        desktop: AppThemes.spacingXXL,
      )),
      child: _buildGlassContainer(
        context,
        child: Padding(
          padding: EdgeInsets.all(ScreenSize.responsiveValue(
            context: context,
            mobile: AppThemes.spacingXL,
            tablet: AppThemes.spacingXXL,
            desktop: AppThemes.spacingXXXL,
          )),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showAnimation) _buildAnimatedIcon(context),
                const SizedBox(height: AppThemes.spacingXXL),
                _buildTitle(context),
                const SizedBox(height: AppThemes.spacingM),
                _buildMessage(context),
                if (onRetry != null) ...[
                  const SizedBox(height: AppThemes.spacingXXL),
                  _buildActionButtons(context),
                ],
                const SizedBox(height: AppThemes.spacingL),
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
        return const [Color(0xFF2AABEE), Color(0xFF5856D6)];
      case ErrorType.server:
      case ErrorType.payment:
        return const [Color(0xFFFF3B30), Color(0xFFE6204A)];
      case ErrorType.access:
      case ErrorType.timeout:
        return const [Color(0xFFFF9500), Color(0xFFFF2D55)];
      case ErrorType.notFound:
        return const [Color(0xFF2AABEE), Color(0xFF5856D6)];
      default:
        return const [Color(0xFF2AABEE), Color(0xFF5856D6)];
    }
  }

  Widget _buildAnimatedIcon(BuildContext context) {
    final iconSize = ScreenSize.responsiveValue(
      context: context,
      mobile: 100.0,
      tablet: 120.0,
      desktop: 140.0,
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
            color: _getIconColor(context).withValues(alpha: 0.2), width: 2.0),
      ),
      child: Icon(
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
      padding: const EdgeInsets.symmetric(
          horizontal: AppThemes.spacingL, vertical: AppThemes.spacingS),
      decoration: BoxDecoration(
        color: _getIconColor(context).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
      ),
      child: Text(
        title,
        style: AppTextStyles.titleLarge.copyWith(
          color: AppColors.getTextPrimary(context),
          fontWeight: FontWeight.w600,
          fontSize: ScreenSize.responsiveFontSize(
              context: context, mobile: 18, tablet: 20, desktop: 22),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildMessage(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: ScreenSize.responsiveValue(
              context: context,
              mobile: AppThemes.spacingL,
              tablet: AppThemes.spacingXL,
              desktop: AppThemes.spacingXXL)),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.getTextSecondary(context),
          fontSize: ScreenSize.responsiveFontSize(
              context: context, mobile: 14, tablet: 15, desktop: 16),
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        _buildGlassButton(
          context,
          onPressed: onRetry!,
          label: 'Try Again',
          icon: Icons.refresh_outlined,
        ),
        if (type == ErrorType.network || type == ErrorType.access) ...[
          const SizedBox(height: AppThemes.spacingL),
          TextButton(
            onPressed: () => _showHelpDialog(context),
            style: TextButton.styleFrom(
              foregroundColor: _getIconColor(context),
              padding: EdgeInsets.symmetric(
                horizontal: ScreenSize.responsiveValue(
                    context: context,
                    mobile: AppThemes.spacingL,
                    tablet: AppThemes.spacingXL,
                    desktop: AppThemes.spacingXXL),
                vertical: AppThemes.spacingM,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.help_outline_outlined,
                    size: ScreenSize.responsiveValue(
                        context: context, mobile: 16, tablet: 18, desktop: 20)),
                SizedBox(
                    width: ScreenSize.responsiveValue(
                        context: context,
                        mobile: AppThemes.spacingS,
                        tablet: AppThemes.spacingM,
                        desktop: AppThemes.spacingL)),
                Text('Need Help?',
                    style: AppTextStyles.bodyMedium.copyWith(
                        fontSize: ScreenSize.responsiveFontSize(
                            context: context,
                            mobile: 14,
                            tablet: 15,
                            desktop: 16),
                        fontWeight: FontWeight.w500)),
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
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _getIconColor(context).withValues(alpha: 0.2),
                        _getIconColor(context).withValues(alpha: 0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getIconForType(),
                    color: _getIconColor(context),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Help with ${type.name} Error',
                  style: AppTextStyles.titleLarge.copyWith(
                    color: AppColors.getTextPrimary(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.getCard(context).withValues(alpha: 0.3),
                        AppColors.getCard(context).withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getHelpMessage(),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.getTextSecondary(context),
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.getTextSecondary(context),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Close'),
                      ),
                    ),
                    const SizedBox(width: 12),
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

enum ErrorType {
  general,
  network,
  server,
  access,
  notFound,
  timeout,
  payment,
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

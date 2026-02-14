import 'dart:math';

import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:confetti/confetti.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import '../../themes/app_themes.dart';
import '../../utils/helpers.dart';

class ErrorWidget extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final IconData? icon;
  final bool fullScreen;
  final ErrorType type;
  final String? lottieAsset;
  final bool showConfetti;
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
    this.showConfetti = false,
    this.showAnimation = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: EdgeInsets.all(ScreenSize.responsiveValue(
        context: context,
        mobile: AppThemes.spacingL,
        tablet: AppThemes.spacingXL,
        desktop: AppThemes.spacingXXL,
      )),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showAnimation) _buildAnimatedIcon(context),
          SizedBox(height: AppThemes.spacingXXL),
          _buildTitle(context),
          SizedBox(height: AppThemes.spacingM),
          _buildMessage(context),
          if (onRetry != null) ...[
            SizedBox(height: AppThemes.spacingXXL),
            _buildActionButtons(context),
          ],
          if (showConfetti) _buildConfetti(),
        ],
      ),
    );

    final widget = fullScreen
        ? Scaffold(
            backgroundColor: AppColors.getBackground(context),
            body: SafeArea(
              child: content,
            ),
          )
        : Center(
            child: content,
          );

    return widget
        .animate()
        .fadeIn(duration: AppThemes.animationDurationMedium)
        .slideY(
          begin: 0.1,
          end: 0,
          duration: AppThemes.animationDurationMedium,
        );
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
          repeat: true,
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
        color: _getIconColor(context).withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(
          color: _getIconColor(context).withOpacity(0.2),
          width: 2.0,
        ),
      ),
      child: Icon(
        icon ?? _getIconForType(),
        size: iconSize * 0.4,
        color: _getIconColor(context),
      ),
    )
        .animate(
          onPlay: (controller) => controller.repeat(),
        )
        .shake(
          hz: 1,
          duration: const Duration(seconds: 3),
        );
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
    final theme = Theme.of(context);
    switch (type) {
      case ErrorType.network:
        return AppColors.telegramGray;
      case ErrorType.server:
        return theme.colorScheme.error;
      case ErrorType.access:
        return theme.colorScheme.secondary;
      case ErrorType.notFound:
        return theme.colorScheme.primary;
      case ErrorType.timeout:
        return AppColors.telegramYellow;
      case ErrorType.payment:
        return theme.colorScheme.error;
      default:
        return theme.colorScheme.error;
    }
  }

  Widget _buildTitle(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppThemes.spacingL,
        vertical: AppThemes.spacingS,
      ),
      decoration: BoxDecoration(
        color: _getIconColor(context).withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
      ),
      child: AnimatedTextKit(
        animatedTexts: [
          FadeAnimatedText(
            title,
            textStyle: AppTextStyles.titleLarge.copyWith(
              color: AppColors.getTextPrimary(context),
              fontWeight: FontWeight.w600,
              fontSize: ScreenSize.responsiveFontSize(
                context: context,
                mobile: 18,
                tablet: 20,
                desktop: 22,
              ),
            ),
            duration: const Duration(milliseconds: 800),
          ),
        ],
        totalRepeatCount: 1,
        displayFullTextOnTap: true,
        stopPauseOnTap: true,
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
          desktop: AppThemes.spacingXXL,
        ),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.getTextSecondary(context),
          fontSize: ScreenSize.responsiveFontSize(
            context: context,
            mobile: 14,
            tablet: 15,
            desktop: 16,
          ),
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
            boxShadow: [
              BoxShadow(
                color: _getButtonColor(context).withOpacity(0.2),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: _getButtonColor(context),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: ScreenSize.responsiveValue(
                  context: context,
                  mobile: AppThemes.spacingXL,
                  tablet: AppThemes.spacingXXL,
                  desktop: AppThemes.spacingXXXL,
                ),
                vertical: AppThemes.spacingL,
              ),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppThemes.borderRadiusMedium),
              ),
              elevation: 0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.refresh_outlined,
                  size: ScreenSize.responsiveValue(
                    context: context,
                    mobile: 18,
                    tablet: 20,
                    desktop: 22,
                  ),
                ),
                SizedBox(
                    width: ScreenSize.responsiveValue(
                  context: context,
                  mobile: AppThemes.spacingS,
                  tablet: AppThemes.spacingM,
                  desktop: AppThemes.spacingL,
                )),
                Text(
                  'Try Again',
                  style: AppTextStyles.buttonMedium.copyWith(
                    fontSize: ScreenSize.responsiveFontSize(
                      context: context,
                      mobile: 14,
                      tablet: 16,
                      desktop: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (type == ErrorType.network || type == ErrorType.access) ...[
          SizedBox(height: AppThemes.spacingL),
          TextButton(
            onPressed: () => _showHelpDialog(context),
            style: TextButton.styleFrom(
              foregroundColor: _getButtonColor(context),
              padding: EdgeInsets.symmetric(
                horizontal: ScreenSize.responsiveValue(
                  context: context,
                  mobile: AppThemes.spacingL,
                  tablet: AppThemes.spacingXL,
                  desktop: AppThemes.spacingXXL,
                ),
                vertical: AppThemes.spacingM,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.help_outline_outlined,
                  size: ScreenSize.responsiveValue(
                    context: context,
                    mobile: 16,
                    tablet: 18,
                    desktop: 20,
                  ),
                ),
                SizedBox(
                    width: ScreenSize.responsiveValue(
                  context: context,
                  mobile: AppThemes.spacingS,
                  tablet: AppThemes.spacingM,
                  desktop: AppThemes.spacingL,
                )),
                Text(
                  'Need Help?',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontSize: ScreenSize.responsiveFontSize(
                      context: context,
                      mobile: 14,
                      tablet: 15,
                      desktop: 16,
                    ),
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

  Color _getButtonColor(BuildContext context) {
    final theme = Theme.of(context);
    switch (type) {
      case ErrorType.network:
        return AppColors.telegramBlue;
      case ErrorType.server:
        return theme.colorScheme.error;
      case ErrorType.access:
        return theme.colorScheme.secondary;
      case ErrorType.notFound:
        return theme.colorScheme.primary;
      case ErrorType.timeout:
        return AppColors.telegramYellow;
      case ErrorType.payment:
        return theme.colorScheme.error;
      default:
        return theme.colorScheme.primary;
    }
  }

  Widget _buildConfetti() {
    return ConfettiWidget(
      confettiController:
          ConfettiController(duration: const Duration(seconds: 2)),
      blastDirectionality: BlastDirectionality.explosive,
      shouldLoop: false,
      colors: const [
        AppColors.telegramBlue,
        AppColors.telegramGreen,
        AppColors.telegramYellow,
        AppColors.telegramRed,
      ],
      createParticlePath: drawStar,
      numberOfParticles: 20,
      gravity: 0.1,
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getCard(context),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
        ),
        title: Text(
          'Help with ${type.name.capitalize()} Error',
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.getTextPrimary(context),
          ),
        ),
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: AppThemes.spacingS),
          child: Text(
            _getHelpMessage(),
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.getTextSecondary(context),
              height: 1.5,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.getTextSecondary(context),
            ),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onRetry?.call();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.telegramBlue,
            ),
            child: const Text('Retry'),
          ),
        ],
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
          ? 'You\'re offline. Some features may not be available. '
              'Cached content is still accessible.'
          : 'Unable to connect to the server. '
              'Please check your internet connection and try again.',
      onRetry: onRetry,
      type: ErrorType.network,
      fullScreen: fullScreen,
      showAnimation: true,
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
      message: 'We\'re experiencing technical difficulties. '
          'Our team has been notified. Please try again in a few moments.',
      onRetry: onRetry,
      type: ErrorType.server,
      fullScreen: fullScreen,
      showAnimation: true,
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
      showAnimation: true,
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
      message: 'The requested $resource was not found. '
          'It may have been removed or you may not have access to it.',
      onRetry: onRetry,
      type: ErrorType.notFound,
      fullScreen: fullScreen,
      showAnimation: true,
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
      message: 'The request took too long to complete. '
          'This could be due to a slow internet connection or server issues.',
      onRetry: onRetry,
      type: ErrorType.timeout,
      fullScreen: fullScreen,
      showAnimation: true,
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
      showAnimation: true,
    );
  }
}

class OfflineContentWidget extends StatelessWidget {
  final VoidCallback onRetry;
  final String contentDescription;

  const OfflineContentWidget({
    super.key,
    required this.onRetry,
    required this.contentDescription,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(ScreenSize.responsiveValue(
        context: context,
        mobile: AppThemes.spacingL,
        tablet: AppThemes.spacingXL,
        desktop: AppThemes.spacingXXL,
      )),
      decoration: BoxDecoration(
        color: AppColors.telegramYellow.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
        border: Border.all(
          color: AppColors.telegramYellow.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: ScreenSize.responsiveValue(
              context: context,
              mobile: 32,
              tablet: 36,
              desktop: 40,
            ),
            color: AppColors.telegramYellow,
          ),
          SizedBox(height: AppThemes.spacingM),
          Text(
            'Offline Mode',
            style: AppTextStyles.titleSmall.copyWith(
              color: AppColors.getTextPrimary(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: AppThemes.spacingS),
          Text(
            'You\'re viewing cached $contentDescription. '
            'Some features may be limited.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.getTextSecondary(context),
            ),
          ),
          SizedBox(height: AppThemes.spacingL),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.telegramBlue,
                  side: BorderSide(color: AppColors.telegramBlue),
                  padding: EdgeInsets.symmetric(
                    horizontal: ScreenSize.responsiveValue(
                      context: context,
                      mobile: AppThemes.spacingL,
                      tablet: AppThemes.spacingXL,
                      desktop: AppThemes.spacingXXL,
                    ),
                    vertical: AppThemes.spacingS,
                  ),
                ),
                icon: Icon(
                  Icons.refresh_outlined,
                  size: ScreenSize.responsiveValue(
                    context: context,
                    mobile: 16,
                    tablet: 18,
                    desktop: 20,
                  ),
                ),
                label: Text(
                  'Retry Connection',
                  style: AppTextStyles.labelMedium,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideY(
          begin: 0.1,
          end: 0,
          duration: AppThemes.animationDurationMedium,
        );
  }
}

class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(Object error, StackTrace stackTrace)? fallback;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.fallback,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.fallback?.call(_error!, _stackTrace!) ??
          ErrorWidget(
            title: 'Something went wrong',
            message: 'An unexpected error occurred. '
                'Please restart the app or contact support.',
            onRetry: () {
              setState(() {
                _error = null;
                _stackTrace = null;
              });
            },
            fullScreen: true,
          );
    }

    return widget.child;
  }

  @override
  void didCatchError(Object error, StackTrace stackTrace) {
    debugLog('ErrorBoundary', 'Caught error: $error\n$stackTrace');
    setState(() {
      _error = error;
      _stackTrace = stackTrace;
    });
  }
}

Path drawStar(Size size) {
  final path = Path();
  const numberOfPoints = 5;
  final halfWidth = size.width / 2;
  final halfHeight = size.height / 2;
  final externalRadius = halfWidth;
  final internalRadius = halfWidth / 2;

  final degreesPerStep = (2 * 3.141592653589793) / numberOfPoints;
  final halfDegreesPerStep = degreesPerStep / 2;

  path.moveTo(halfWidth, halfHeight - externalRadius);

  for (var i = 1; i < numberOfPoints * 2; i++) {
    final radius = i.isOdd ? externalRadius : internalRadius;
    final angle = i * halfDegreesPerStep;
    final x = halfWidth + radius * sin(angle);
    final y = halfHeight - radius * cos(angle);
    path.lineTo(x, y);
  }

  path.close();
  return path;
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}

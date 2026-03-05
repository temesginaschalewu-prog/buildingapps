import 'dart:async';
import 'package:flutter/material.dart';
import 'package:familyacademyclient/themes/app_colors.dart';

enum SnackbarType {
  success,
  error,
  warning,
  info,
  offline,
}

class SnackbarService {
  static final SnackbarService _instance = SnackbarService._internal();
  factory SnackbarService() => _instance;
  SnackbarService._internal();

  OverlayEntry? _currentEntry;
  Timer? _timer;

  void show({
    required BuildContext context,
    required String message,
    SnackbarType type = SnackbarType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    _currentEntry?.remove();
    _timer?.cancel();

    final colors = _getColors(type);

    _currentEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, -20 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: colors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: colors.first.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    _getIcon(type),
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_currentEntry!);

    _timer = Timer(duration, () {
      _currentEntry?.remove();
      _currentEntry = null;
    });
  }

  void showSuccess(BuildContext context, String message) {
    show(context: context, message: message, type: SnackbarType.success);
  }

  void showError(BuildContext context, String message) {
    show(context: context, message: message, type: SnackbarType.error);
  }

  void showWarning(BuildContext context, String message) {
    show(context: context, message: message, type: SnackbarType.warning);
  }

  void showInfo(BuildContext context, String message) {
    show(context: context, message: message);
  }

  void showOffline(BuildContext context, {String? action}) {
    final message = action != null
        ? 'Cannot $action while offline. Please check your connection.'
        : 'You are offline. Using cached content.';

    show(
      context: context,
      message: message,
      type: SnackbarType.offline,
      duration: const Duration(seconds: 2),
    );
  }

  List<Color> _getColors(SnackbarType type) {
    switch (type) {
      case SnackbarType.success:
        return AppColors.greenGradient;
      case SnackbarType.error:
        return AppColors.pinkGradient;
      case SnackbarType.warning:
        return [AppColors.telegramOrange, AppColors.telegramYellow];
      case SnackbarType.info:
        return AppColors.blueGradient;
      case SnackbarType.offline:
        return [AppColors.telegramYellow, AppColors.telegramOrange];
    }
  }

  IconData _getIcon(SnackbarType type) {
    switch (type) {
      case SnackbarType.success:
        return Icons.check_circle_rounded;
      case SnackbarType.error:
        return Icons.error_outline_rounded;
      case SnackbarType.warning:
        return Icons.warning_rounded;
      case SnackbarType.info:
        return Icons.info_outline_rounded;
      case SnackbarType.offline:
        return Icons.wifi_off_rounded;
    }
  }
}

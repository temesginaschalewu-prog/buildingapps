import 'dart:async';
import 'package:flutter/material.dart';
import '../themes/app_colors.dart';
import '../utils/app_enums.dart';

class SnackbarService {
  static final SnackbarService _instance = SnackbarService._internal();
  factory SnackbarService() => _instance;
  SnackbarService._internal();

  OverlayEntry? _currentEntry;
  Timer? _timer;
  bool _isShowing = false;

  void show({
    required BuildContext context,
    required String message,
    SnackbarType type = SnackbarType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    // Don't try to show if context isn't mounted or if we're already showing
    if (!context.mounted || _isShowing) return;

    // Make sure we have an overlay
    final overlayState = Overlay.of(context, rootOverlay: true);
    if (overlayState == null) {
      debugPrint('SnackbarService: No overlay found, skipping: $message');
      return;
    }

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

    _isShowing = true;
    overlayState.insert(_currentEntry!);

    _timer = Timer(duration, () {
      _currentEntry?.remove();
      _currentEntry = null;
      _isShowing = false;
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
        ? 'Cannot $action while offline. Your changes will sync when online.'
        : 'You are offline. Showing cached content.';

    show(
      context: context,
      message: message,
      type: SnackbarType.offline,
      duration: const Duration(seconds: 2),
    );
  }

  void showQueued(BuildContext context, {String? action}) {
    final message = action != null
        ? '$action saved offline. Will sync when online.'
        : 'Action saved offline. Will sync when online.';

    show(
      context: context,
      message: message,
      type: SnackbarType.queued,
      duration: const Duration(seconds: 2),
    );
  }

  void showSyncComplete(BuildContext context, {int count = 0}) {
    // Don't show sync complete if we don't have a valid context
    if (!context.mounted) return;

    final message = count > 0
        ? 'Sync complete. $count change${count > 1 ? 's' : ''} synced.'
        : 'Sync complete. All changes synced.';

    show(
      context: context,
      message: message,
      type: SnackbarType.syncComplete,
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
        return [AppColors.warning, AppColors.telegramOrange];
      case SnackbarType.queued:
        return [AppColors.info, AppColors.telegramBlue];
      case SnackbarType.syncComplete:
        return AppColors.greenGradient;
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
      case SnackbarType.queued:
        return Icons.schedule_rounded;
      case SnackbarType.syncComplete:
        return Icons.sync_rounded;
    }
  }
}

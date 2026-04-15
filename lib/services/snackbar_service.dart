import 'dart:async';
import 'package:flutter/material.dart';
import '../themes/app_colors.dart';
import '../utils/app_enums.dart';
import '../utils/helpers.dart';

class SnackbarService {
  static final SnackbarService _instance = SnackbarService._internal();
  factory SnackbarService() => _instance;
  SnackbarService._internal();

  OverlayEntry? _currentEntry;
  Timer? _timer;
  bool _isInitialized = false;

  // Queue for messages when overlay not ready
  final List<Map<String, dynamic>> _messageQueue = [];

  // ✅ FIXED: Message deduplication with cleanup
  final Set<String> _recentMessages = {};
  Timer? _messageCleanupTimer;
  static const Duration _messageDedupeDuration = Duration(seconds: 5);

  void show({
    required BuildContext context,
    required String message,
    SnackbarType type = SnackbarType.info,
    Duration duration = const Duration(seconds: 3),
    String? id,
  }) {
    // ✅ FIXED: Deduplicate messages
    final messageId = id ?? '$message${type.index}';
    if (_recentMessages.contains(messageId)) {
      return;
    }
    _recentMessages.add(messageId);

    // ✅ FIXED: Clean up old messages periodically
    _messageCleanupTimer?.cancel();
    _messageCleanupTimer = Timer(_messageDedupeDuration, _recentMessages.clear);

    // Don't try to show if context isn't mounted
    if (!context.mounted) return;

    // Check if we have a valid overlay
    OverlayState? overlayState;
    try {
      overlayState = Overlay.maybeOf(context);
    } catch (_) {
      overlayState = null;
    }

    if (overlayState == null) {
      debugLog('SnackbarService', 'Overlay not ready, queueing message');
      _queueMessage(message, type, messageId);
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

    overlayState.insert(_currentEntry!);

    _timer = Timer(duration, () {
      _currentEntry?.remove();
      _currentEntry = null;
    });
  }

  void _queueMessage(String message, SnackbarType type, String id) {
    _messageQueue.add({'message': message, 'type': type, 'id': id});

    // Try to process queue after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_messageQueue.isNotEmpty && _isInitialized) {
        _processQueue();
      }
    });
  }

  void _processQueue() {
    // This will be called from app.dart after overlay is ready
    // The actual processing happens in initializeWithContext
  }

  // Call this from app.dart after overlay is ready
  void initializeWithContext(BuildContext context) {
    if (_isInitialized) return;
    _isInitialized = true;

    // Process any queued messages
    if (_messageQueue.isNotEmpty) {
      for (final msg in _messageQueue) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (context.mounted) {
            show(
              context: context,
              message: msg['message'],
              type: msg['type'],
              id: msg['id'],
            );
          }
        });
      }
      _messageQueue.clear();
    }
  }

  void showSuccess(BuildContext context, String message, {String? id}) {
    show(
        context: context, message: message, type: SnackbarType.success, id: id);
  }

  void showError(BuildContext context, String message, {String? id}) {
    show(context: context, message: message, type: SnackbarType.error, id: id);
  }

  void showWarning(BuildContext context, String message, {String? id}) {
    show(
        context: context, message: message, type: SnackbarType.warning, id: id);
  }

  void showInfo(BuildContext context, String message, {String? id}) {
    show(context: context, message: message, id: id);
  }

  void showOffline(BuildContext context, {String? action, String? id}) {
    final message = action != null
        ? 'You are offline right now. Connect to the internet to $action.'
        : 'You are offline right now. Connect to the internet to load the latest updates.';

    show(
      context: context,
      message: message,
      type: SnackbarType.offline,
      duration: const Duration(seconds: 2),
      id: id ?? 'offline',
    );
  }

  void showNoInternet(BuildContext context, {String? action, String? id}) {
    final message = action != null
        ? 'No internet connection. Please reconnect to $action.'
        : 'No internet connection. Please reconnect and try again.';

    show(
      context: context,
      message: message,
      id: id ?? 'no_internet',
    );
  }

  void showServerUnavailable(BuildContext context, {String? action, String? id}) {
    final message = action != null
        ? 'We could not reach the server right now. Please try again to $action in a moment.'
        : 'We could not reach the server right now. Please try again in a moment.';

    show(
      context: context,
      message: message,
      type: SnackbarType.warning,
      id: id ?? 'server_unavailable',
    );
  }

  void showQueued(BuildContext context, {String? action, String? id}) {
    final message = action != null
        ? '$action saved offline. Will sync when online.'
        : 'Action saved offline. Will sync when online.';

    show(
      context: context,
      message: message,
      type: SnackbarType.queued,
      duration: const Duration(seconds: 2),
      id: id ?? 'queued',
    );
  }

  void showSyncComplete(BuildContext context, {int count = 0, String? id}) {
    // Don't show sync complete if we don't have a valid context
    if (!context.mounted) return;

    // Check if overlay is available
    OverlayState? overlayState;
    try {
      overlayState = Overlay.maybeOf(context);
    } catch (_) {
      overlayState = null;
    }
    if (overlayState == null) {
      debugLog('SnackbarService', 'Overlay not ready, skipping sync-complete');
      return;
    }

    final message = count > 0
        ? 'Sync complete. $count change${count > 1 ? 's' : ''} synced.'
        : 'Sync complete. All changes synced.';

    show(
      context: context,
      message: message,
      type: SnackbarType.syncComplete,
      duration: const Duration(seconds: 2),
      id: id ?? 'sync_complete',
    );
  }

  List<Color> _getColors(SnackbarType type) {
    switch (type) {
      case SnackbarType.success:
        return AppColors.greenGradient;
      case SnackbarType.error:
        return AppColors.pinkGradient;
      case SnackbarType.warning:
        return [AppColors.telegramOrange, AppColors.telegramPink];
      case SnackbarType.info:
        return AppColors.blueGradient;
      case SnackbarType.offline:
        return [AppColors.telegramIndigo, AppColors.telegramTeal];
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

  void dispose() {
    _timer?.cancel();
    _messageCleanupTimer?.cancel();
    _currentEntry?.remove();
  }
}

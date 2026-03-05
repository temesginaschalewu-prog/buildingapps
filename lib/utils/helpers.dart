import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

void debugLog(String tag, String message) {
  if (const bool.fromEnvironment('PRODUCTION')) {
    return;
  }
  debugPrint(
      '[${DateTime.now().toIso8601String().substring(11, 19)}] [$tag] $message');
}

@Deprecated('Use SnackbarService instead')
void showTopSnackBar(BuildContext context, String message,
    {bool isError = false, int durationSeconds = 3}) {
  if (!context.mounted) return;

  final overlay = Overlay.of(context);
  final overlayEntry = OverlayEntry(
    builder: (context) => Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: AnimatedOpacity(
          opacity: 1.0,
          duration: const Duration(milliseconds: 300),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color:
                  isError ? const Color(0xFFDC3545) : const Color(0xFF28A745),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  isError
                      ? Icons.error_outline_rounded
                      : Icons.check_circle_rounded,
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

  overlay.insert(overlayEntry);
  Future.delayed(Duration(seconds: durationSeconds), overlayEntry.remove);
}

@Deprecated('Use SnackbarService instead')
void showSnackBar(BuildContext context, String message,
    {bool isError = false, int durationSeconds = 2}) {
  showTopSnackBar(context, message,
      isError: isError, durationSeconds: durationSeconds);
}

@Deprecated('Use SnackbarService instead')
void showSimpleSnackBar(BuildContext context, String message,
    {bool isError = false}) {
  showTopSnackBar(context, message, isError: isError);
}

@Deprecated('Use SnackbarService.showOffline() instead')
void showOfflineMessage(BuildContext context) {
  showTopSnackBar(
    context,
    'You are offline. Showing cached content.',
  );
}

@Deprecated('Use SnackbarService.showOffline() instead')
void showOfflineError(BuildContext context, {String? action}) {
  showTopSnackBar(
    context,
    action != null
        ? 'Cannot $action while offline. Please check your connection.'
        : 'You are offline. Please check your internet connection.',
    isError: true,
  );
}

Future<bool> hasInternetConnection() async {
  try {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  } catch (e) {
    return false;
  }
}

Stream<bool> connectivityStream() {
  return Connectivity().onConnectivityChanged.map((result) {
    return result != ConnectivityResult.none;
  });
}

double ensureDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

String formatDate(DateTime date) {
  return DateFormat('dd/MM/yyyy').format(date);
}

String formatDateTime(DateTime date) {
  return DateFormat('dd/MM/yyyy HH:mm').format(date);
}

String formatTime(int seconds) {
  final hours = (seconds / 3600).floor();
  final minutes = ((seconds % 3600) / 60).floor();
  final secs = seconds % 60;

  if (hours > 0) {
    return '${hours}h ${minutes}m ${secs}s';
  } else if (minutes > 0) {
    return '${minutes}m ${secs}s';
  } else {
    return '${secs}s';
  }
}

String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

bool validateEmail(String email) {
  return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
}

bool validatePhone(String phone) {
  return RegExp(r'^\+?[0-9]{10,15}$').hasMatch(phone);
}

String capitalize(String text) {
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1);
}

Future<void> showConfirmDialog(
  BuildContext context,
  String title,
  String message,
  Function() onConfirm,
) async {
  if (!context.mounted) return;

  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onConfirm();
          },
          child: const Text('Confirm'),
        ),
      ],
    ),
  );
}

bool validatePassword(String password) {
  if (password.length < 6) return false;
  if (!password.contains(RegExp('[A-Z]'))) return false;
  if (!password.contains(RegExp('[a-z]'))) return false;
  if (!password.contains(RegExp('[0-9]'))) return false;
  return true;
}

String? validateUsername(String username) {
  if (username.isEmpty) return 'Username is required';
  if (username.length < 3) return 'Username must be at least 3 characters';
  if (username.length > 20) return 'Username must be less than 20 characters';
  if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
    return 'Username can only contain letters, numbers, and underscores';
  }
  return null;
}

String formatSubscriptionDuration(Duration duration) {
  if (duration.inDays >= 30) {
    final months = duration.inDays ~/ 30;
    return '$months month${months > 1 ? 's' : ''}';
  } else if (duration.inDays >= 7) {
    final weeks = duration.inDays ~/ 7;
    return '$weeks week${weeks > 1 ? 's' : ''}';
  } else {
    return '${duration.inDays} day${duration.inDays > 1 ? 's' : ''}';
  }
}

double calculateProgressPercentage(int completed, int total) {
  if (total == 0) return 0.0;
  return (completed / total) * 100;
}

String formatProgressPercentage(double percentage) {
  return '${percentage.toStringAsFixed(1)}%';
}

String generateCacheKey(String base, List<String> parameters) {
  final params = parameters.join('_');
  return '${base}_$params';
}

String formatErrorMessage(dynamic error) {
  if (error is String) {
    if (error.contains('Network') ||
        error.contains('connection') ||
        error.contains('Failed host lookup') ||
        error.contains('SocketException') ||
        error.contains('Connection refused')) {
      return 'Network error. Please check your internet connection.';
    }
    return error;
  }

  if (error is Map<String, dynamic>) {
    if (error.containsKey('offline') && error['offline'] == true) {
      return 'You are offline. Showing cached data.';
    }
    return error['message']?.toString() ?? 'An error occurred';
  }

  if (error is Exception) {
    final message = error.toString();
    if (message.contains('Network') ||
        message.contains('connection') ||
        message.contains('Failed host lookup') ||
        message.contains('SocketException') ||
        message.contains('Connection refused')) {
      return 'Network error. Please check your internet connection.';
    }
    return message;
  }

  return error?.toString() ?? 'An unknown error occurred';
}

bool isNetworkError(dynamic error) {
  final message = formatErrorMessage(error);
  return message.contains('Network error') ||
      message.contains('offline') ||
      message.contains('internet connection');
}

Function debounce(Function func, [int delay = 500]) {
  Timer? timer;
  return () {
    if (timer?.isActive ?? false) {
      timer?.cancel();
    }
    timer = Timer(Duration(milliseconds: delay), () {
      func();
    });
  };
}

Function throttle(Function func, [int delay = 1000]) {
  bool isThrottled = false;
  return () {
    if (!isThrottled) {
      func();
      isThrottled = true;
      Timer(Duration(milliseconds: delay), () {
        isThrottled = false;
      });
    }
  };
}

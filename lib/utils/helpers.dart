import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

void debugLog(String tag, String message) {
  print(
      '[${DateTime.now().toIso8601String().substring(11, 19)}] [$tag] $message');
}

void showSnackBar(BuildContext context, String message,
    {bool isError = false, int durationSeconds = 2}) {
  // Check if context is still mounted/valid
  if (!context.mounted) return;

  try {
    // Hide any current snackbar first
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    final snackBar = SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red : Colors.green,
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: durationSeconds),
      // Remove the action button since you can swipe to dismiss
      // This prevents the "OK" button from causing errors
      action: SnackBarAction(
        label: 'OK',
        textColor: Colors.white,
        onPressed: () {
          // Safe check before using context
          if (context.mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          }
        },
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  } catch (e) {
    debugLog('Helpers', 'Error showing snackbar: $e');
  }
}

// Alternative simpler snackbar without action button
void showSimpleSnackBar(BuildContext context, String message,
    {bool isError = false, int durationSeconds = 2}) {
  if (!context.mounted) return;

  try {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    final snackBar = SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red : Colors.green,
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: durationSeconds),
      // No action button, just swipe to dismiss
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  } catch (e) {
    debugLog('Helpers', 'Error showing simple snackbar: $e');
  }
}

// Rest of the file remains the same...
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
  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => GoRouter.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            GoRouter.of(context).pop();
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

  if (!password.contains(RegExp(r'[A-Z]'))) return false;

  if (!password.contains(RegExp(r'[a-z]'))) return false;

  if (!password.contains(RegExp(r'[0-9]'))) return false;

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
  if (error is String) return error;
  if (error is Map<String, dynamic>) {
    return error['message']?.toString() ?? 'An error occurred';
  }
  return error.toString();
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

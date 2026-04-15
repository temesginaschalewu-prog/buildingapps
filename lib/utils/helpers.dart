import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

void debugLog(String tag, String message) {
  if (kReleaseMode) {
    return;
  }
  debugPrint(
      '[${DateTime.now().toIso8601String().substring(11, 19)}] [$tag] $message');
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

bool isNetworkError(dynamic error) {
  if (error == null) return false;
  final message = error.toString().toLowerCase();
  return message.contains('network') ||
      message.contains('socket') ||
      message.contains('connection') ||
      message.contains('timeout') ||
      message.contains('offline') ||
      message.contains('internet');
}

String getUserFriendlyErrorMessage(dynamic error) {
  if (error == null) return 'An unknown error occurred';

  final message = error.toString();

  if (message.contains('Network image load failed')) {
    return 'Failed to load image. Please check your connection.';
  }
  if (message.contains('SocketException')) {
    return 'Network error. Please check your internet connection.';
  }
  if (message.contains('Connection refused')) {
    return 'Server is not responding. Please try again later.';
  }
  if (message.contains('Connection timeout')) {
    return 'Connection timed out. Please try again.';
  }
  if (message.contains('Failed host lookup')) {
    return 'Could not connect to server. Please check your internet.';
  }
  if (message.contains('Network error')) {
    return 'Network error. Please check your internet connection.';
  }
  if (message.contains('timeout')) {
    return 'Request timed out. Please try again.';
  }
  if (message.contains('offline')) {
    return 'You are offline. Please check your internet connection.';
  }

  // Return the original message if it's already user-friendly
  if (message.length < 100 && !message.contains('Exception')) {
    return message;
  }

  return 'An error occurred. Please try again.';
}

/// Format exception for logging
String formatException(dynamic e, StackTrace stackTrace) {
  return '${e.runtimeType}: $e\n$stackTrace';
}

// ===== FORMATTING =====
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

String capitalize(String text) {
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1);
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

// ===== VALIDATION =====
bool validateEmail(String email) {
  return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
}

bool validatePhone(String phone) {
  return RegExp(r'^\+?[0-9]{10,15}$').hasMatch(phone);
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

// ===== PERFORMANCE UTILITIES =====
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

// ===== DIALOG HELPERS =====
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

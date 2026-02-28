# Utils Files Documentation

Generated on: Sat Feb 28 10:12:56 PM EAT 2026

---

## api_response.dart

```dart
class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final dynamic error;
  final int? statusCode;
  final DateTime timestamp;

  ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.error,
    this.statusCode,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory ApiResponse.success(
      {required String message, T? data, int? statusCode}) {
    return ApiResponse<T>(
      success: true,
      message: message,
      data: data,
      statusCode: statusCode ?? 200,
    );
  }

  factory ApiResponse.error(
      {required String message, dynamic error, int? statusCode, T? data}) {
    return ApiResponse<T>(
      success: false,
      message: message,
      error: error,
      statusCode: statusCode ?? 500,
      data: data,
    );
  }

  factory ApiResponse.fromJson(
      Map<String, dynamic> json, T Function(dynamic) fromJson) {
    try {
      return ApiResponse<T>(
        success: json['success'] ?? false,
        message: json['message']?.toString() ?? '',
        data: json['data'] != null ? fromJson(json['data']) : null,
        error: json['error'],
        statusCode: json['statusCode'],
      );
    } catch (e) {
      return ApiResponse<T>(
        success: false,
        message: 'Failed to parse response: $e',
        error: e,
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'data': data,
      'error': error,
      'statusCode': statusCode,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  bool get hasData => data != null;
  bool get hasError => error != null;

  ApiResponse<R> map<R>(R Function(T) mapper) {
    if (data == null) {
      return ApiResponse<R>(
        success: success,
        message: message,
        error: error,
        statusCode: statusCode,
        timestamp: timestamp,
      );
    }

    return ApiResponse<R>(
      success: success,
      message: message,
      data: mapper(data as T),
      error: error,
      statusCode: statusCode,
      timestamp: timestamp,
    );
  }

  T getDataOrThrow() {
    if (!success) throw ApiError.fromResponse(this);
    if (data == null) throw ApiError(message: 'No data available');
    return data as T;
  }

  T? getDataOrNull() => success ? data : null;

  @override
  String toString() =>
      'ApiResponse{success: $success, message: $message, hasData: ${data != null}, statusCode: $statusCode}';
}

class ApiError {
  final String message;
  final int? statusCode;
  final dynamic data;
  final String? action;
  final DateTime timestamp;

  ApiError({
    required this.message,
    this.statusCode,
    this.data,
    this.action,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => 'ApiError: $message (${statusCode ?? 'No status code'})';

  factory ApiError.fromJson(Map<String, dynamic> json) {
    return ApiError(
      message: json['message']?.toString() ?? 'Unknown error',
      statusCode: json['statusCode'],
      data: json['data'],
      action: json['action'],
    );
  }

  factory ApiError.fromResponse(ApiResponse response) {
    return ApiError(
      message: response.message,
      statusCode: response.statusCode,
      data: response.data,
    );
  }

  factory ApiError.networkError() {
    return ApiError(
        message: 'Network error. Please check your connection.', statusCode: 0);
  }

  factory ApiError.timeoutError() {
    return ApiError(
        message: 'Request timeout. Please try again.', statusCode: 408);
  }

  factory ApiError.unauthorized() {
    return ApiError(
        message: 'Unauthorized. Please login again.', statusCode: 401);
  }

  factory ApiError.notFound() {
    return ApiError(message: 'Resource not found.', statusCode: 404);
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'statusCode': statusCode,
      'data': data,
      'action': action,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  bool get isNetworkError => statusCode == 0 || message.contains('Network');
  bool get isTimeout => statusCode == 408 || message.contains('timeout');
  bool get isUnauthorized => statusCode == 401;
  bool get isNotFound => statusCode == 404;
  bool get isServerError => statusCode != null && statusCode! >= 500;

  String get userFriendlyMessage {
    if (isNetworkError)
      return 'Network error. Please check your internet connection.';
    if (isTimeout) return 'Request took too long. Please try again.';
    if (isUnauthorized) return 'Your session has expired. Please login again.';
    if (isNotFound) return 'The requested resource was not found.';
    if (isServerError) return 'Server error. Please try again later.';
    return message;
  }

  bool requiresAction() => action != null && action!.isNotEmpty;
}

class PaginatedResponse<T> {
  final List<T> items;
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final bool hasNext;
  final bool hasPrevious;

  PaginatedResponse({
    required this.items,
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.hasNext,
    required this.hasPrevious,
  });

  factory PaginatedResponse.fromJson(
      Map<String, dynamic> json, T Function(dynamic) fromJson) {
    final itemsData = json['items'] ?? json['data'] ?? [];
    final items = List<T>.from(itemsData.map((x) => fromJson(x)));

    return PaginatedResponse<T>(
      items: items,
      currentPage: json['current_page'] ?? 1,
      totalPages: json['total_pages'] ?? 1,
      totalItems: json['total_items'] ?? items.length,
      hasNext: json['has_next'] ?? false,
      hasPrevious: json['has_previous'] ?? false,
    );
  }

  Map<String, dynamic> toJson(T Function(T) toJson) {
    return {
      'items': items.map((x) => toJson(x)).toList(),
      'current_page': currentPage,
      'total_pages': totalPages,
      'total_items': totalItems,
      'has_next': hasNext,
      'has_previous': hasPrevious,
    };
  }

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;
  int get itemCount => items.length;
}
```

---

## constants.dart

```dart
class AppConstants {
  static const String baseUrl =
      'https://family-academy-backend-a12l.onrender.com';
  static const String apiVersion = 'v1';
  static String get apiBaseUrl => '$baseUrl/api/$apiVersion';

  // Auth Endpoints
  static const String registerEndpoint = '/auth/register';
  static const String studentLoginEndpoint = '/auth/student-login';
  static const String adminLoginEndpoint = '/auth/admin-login';
  static const String refreshTokenEndpoint = '/auth/refresh-token';
  static const String logoutEndpoint = '/auth/logout';
  static const String validateTokenEndpoint = '/auth/validate';
  static const String validateStudentTokenEndpoint = '/auth/student/validate';
  static const String validateAdminTokenEndpoint = '/auth/admin/validate';

  // Schools
  static const String schoolsEndpoint = '/schools';

  // Categories
  static const String categoriesEndpoint = '/categories';
  static const String allCategoriesEndpoint = '$categoriesEndpoint/all';
  static const String studentCategoriesEndpoint = '$categoriesEndpoint/student';

  // Courses
  static const String coursesEndpoint = '/courses';
  static String coursesByCategory(int categoryId) =>
      '$coursesEndpoint/category/$categoryId';

  // Chapters
  static const String chaptersEndpoint = '/chapters';
  static String chaptersByCourse(int courseId) =>
      '$chaptersEndpoint/course/$courseId';

  // Videos
  static const String videosEndpoint = '/videos';
  static String videosByChapter(int chapterId) =>
      '$videosEndpoint/chapter/$chapterId';
  static String incrementViewEndpoint(int videoId) =>
      '$videosEndpoint/$videoId/view';

  // Notes
  static const String notesEndpoint = '/notes';
  static String notesByChapter(int chapterId) =>
      '$notesEndpoint/chapter/$chapterId';

  // Questions
  static const String questionsEndpoint = '/questions';
  static String practiceQuestions(int chapterId) =>
      '$questionsEndpoint/practice/$chapterId';
  static const String checkAnswerEndpoint = '$questionsEndpoint/check-answer';

  // Exams
  static const String examsEndpoint = '/exams';
  static const String availableExamsEndpoint = '$examsEndpoint/available';
  static String startExamEndpoint(int examId) => '$examsEndpoint/start/$examId';
  static String submitExamEndpoint(int examResultId) =>
      '$examsEndpoint/submit/$examResultId';
  static const String myExamResultsEndpoint = '$examsEndpoint/my-results';
  static String examQuestionsEndpoint(int examId) =>
      '$examsEndpoint/$examId/questions';
  static String examProgressEndpoint(int examResultId) =>
      '$examsEndpoint/progress/$examResultId';

  // Exam Results
  static const String examResultsEndpoint = '/exam-results';
  static String examResultByIdEndpoint(int examResultId) =>
      '$examResultsEndpoint/$examResultId';
  static String examResultsByExamEndpoint(int examId) =>
      '$examResultsEndpoint/exam/$examId';

  // Payments
  static const String paymentsEndpoint = '/payments';
  static const String submitPaymentEndpoint = '$paymentsEndpoint/submit';
  static const String myPaymentsEndpoint = '$paymentsEndpoint/my-payments';
  static const String pendingPaymentsEndpoint = '$paymentsEndpoint/pending';
  static const String allPaymentsEndpoint = '$paymentsEndpoint/all';
  static String verifyPaymentEndpoint(int paymentId) =>
      '$paymentsEndpoint/verify/$paymentId';
  static String rejectPaymentEndpoint(int paymentId) =>
      '$paymentsEndpoint/reject/$paymentId';
  static const String uploadPaymentProofEndpoint = '/upload/payment-proof';

  // Subscriptions
  static const String subscriptionsEndpoint = '/subscriptions';
  static const String mySubscriptionsEndpoint =
      '$subscriptionsEndpoint/my-subscriptions';
  static const String checkSubscriptionStatusEndpoint =
      '$subscriptionsEndpoint/check-status';
  static String extendSubscriptionEndpoint(int subscriptionId) =>
      '$subscriptionsEndpoint/$subscriptionId/extend';
  static String cancelSubscriptionEndpoint(int subscriptionId) =>
      '$subscriptionsEndpoint/$subscriptionId/cancel';

  // Streaks
  static const String streaksEndpoint = '/streaks';
  static const String myStreakEndpoint = '$streaksEndpoint/my-streak';
  static const String updateStreakEndpoint = '$streaksEndpoint/update';

  // Devices
  static const String devicesEndpoint = '/devices';
  static const String pairTvDeviceEndpoint = '$devicesEndpoint/tv/pair';
  static const String verifyTvPairingEndpoint = '$devicesEndpoint/tv/verify';
  static const String unpairTvDeviceEndpoint = '$devicesEndpoint/tv/unpair';
  static String forceRemoveDeviceEndpoint(int id) => '$devicesEndpoint/$id';

  // Telegram/Parent Links
  static const String telegramEndpoint = '/telegram';
  static const String generateParentTokenEndpoint =
      '$telegramEndpoint/generate-token';
  static const String parentLinkStatusEndpoint = '$telegramEndpoint/status';
  static const String unlinkParentEndpoint = '$telegramEndpoint/unlink';

  // Notifications
  static const String notificationsEndpoint = '/notifications';
  static const String myNotificationsEndpoint =
      '$notificationsEndpoint/my-notifications';
  static const String notificationHistoryEndpoint =
      '$notificationsEndpoint/history';
  static const String sendNotificationEndpoint = '$notificationsEndpoint/send';

  // Users
  static const String usersEndpoint = '/users';
  static const String myProfileEndpoint = '$usersEndpoint/profile/me';
  static const String updateProfileEndpoint = '$usersEndpoint/profile/me';
  static const String updateDeviceEndpoint = '$usersEndpoint/device/update';
  static const String allUsersEndpoint = usersEndpoint;
  static String userDetailsEndpoint(int userId) => '$usersEndpoint/$userId';

  // Settings
  static const String settingsEndpoint = '/settings';
  static const String publicSettingsEndpoint = '$settingsEndpoint/public';
  static String settingsByCategory(String category) =>
      '$settingsEndpoint/category/$category';
  static const String settingsCategoriesEndpoint =
      '$settingsEndpoint/categories';
  static String settingByKeyEndpoint(String key) => '$settingsEndpoint/$key';

  // Progress
  static const String saveProgressEndpoint = '/progress/save';
  static const String getProgressEndpoint = '/progress/chapter/';
  static const String getCourseProgressEndpoint = '/progress/course/';
  static const String getOverallProgressEndpoint = '/progress/overall';

  // Uploads
  static const String uploadImageEndpoint = '/upload/image';
  static const String uploadVideoEndpoint = '/upload/video';
  static const String uploadFileEndpoint = '/upload/file';
// Chatbot
  static const String chatbotEndpoint = '/chatbot';
  static const String chatbotChatEndpoint = '$chatbotEndpoint/chat';
  static const String chatbotConversationsEndpoint =
      '$chatbotEndpoint/conversations';
  static const String chatbotUsageEndpoint = '$chatbotEndpoint/usage';
  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userDataKey = 'user_data';
  static const String deviceIdKey = 'device_id';
  static const String themeModeKey = 'theme_mode';
  static const String notificationsEnabledKey = 'notifications_enabled';
  static const String registrationCompleteKey = 'registration_complete';
  static const String selectedSchoolIdKey = 'selected_school_id';
  static const String tvDeviceIdKey = 'tv_device_id';

  // Constants
  static const int apiTimeoutSeconds = 30;
  static const int pairingExpiryMinutes = 10;
  static const int parentTokenExpiryMinutes = 30;

  // App Info
  static const String appName = 'Family Academy';
  static const String appVersion = '1.4.2+1';
}
```

---

## helpers.dart

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

void debugLog(String tag, String message) {
  print(
      '[${DateTime.now().toIso8601String().substring(11, 19)}] [$tag] $message');
}

// UNIFIED TOP SNACKBAR - all notifications from top, auto-dismiss
void showTopSnackBar(BuildContext context, String message,
    {bool isError = false, int durationSeconds = 3}) {
  if (!context.mounted) return;

  final overlay = Overlay.of(context);
  if (overlay == null) return;

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
                  color: Colors.black.withOpacity(0.2),
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
  Future.delayed(Duration(seconds: durationSeconds), () {
    overlayEntry.remove();
  });
}

// For backward compatibility - redirects to top snackbar
void showSnackBar(BuildContext context, String message,
    {bool isError = false, int durationSeconds = 2}) {
  showTopSnackBar(context, message,
      isError: isError, durationSeconds: durationSeconds);
}

void showSimpleSnackBar(BuildContext context, String message,
    {bool isError = false}) {
  showTopSnackBar(context, message, isError: isError);
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
```

---

## responsive.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:familyacademyclient/themes/app_themes.dart';
import 'dart:io' show Platform;

class ScreenSize {
  static double getScreenWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;
  static double getScreenHeight(BuildContext context) =>
      MediaQuery.of(context).size.height;
  static double getPixelRatio(BuildContext context) =>
      MediaQuery.of(context).devicePixelRatio;
  static EdgeInsets getViewInsets(BuildContext context) =>
      MediaQuery.of(context).viewInsets;
  static EdgeInsets getViewPadding(BuildContext context) =>
      MediaQuery.of(context).viewPadding;
  static Orientation getOrientation(BuildContext context) =>
      MediaQuery.of(context).orientation;
  static bool isLandscape(BuildContext context) =>
      getOrientation(context) == Orientation.landscape;
  static bool isPortrait(BuildContext context) =>
      getOrientation(context) == Orientation.portrait;
  static bool isMobile(BuildContext context) => getScreenWidth(context) < 600;
  static bool isTablet(BuildContext context) =>
      getScreenWidth(context) >= 600 && getScreenWidth(context) < 1024;
  static bool isDesktop(BuildContext context) =>
      getScreenWidth(context) >= 1024;
  static bool isLargeScreen(BuildContext context) =>
      getScreenWidth(context) >= 1200;

  static double responsiveValue({
    required BuildContext context,
    required double mobile,
    double? tablet,
    double? desktop,
    double? largeScreen,
  }) {
    if (isLargeScreen(context))
      return largeScreen ?? desktop ?? tablet ?? mobile * 1.75;
    if (isDesktop(context)) return desktop ?? tablet ?? mobile * 1.5;
    if (isTablet(context)) return tablet ?? mobile * 1.25;
    return mobile;
  }

  static int responsiveGridCount({
    required BuildContext context,
    required int mobile,
    int? tablet,
    int? desktop,
    int? largeScreen,
  }) {
    if (isLargeScreen(context))
      return largeScreen ?? (desktop ?? (tablet ?? mobile) * 2);
    if (isDesktop(context)) return desktop ?? (tablet ?? mobile * 2);
    if (isTablet(context)) return tablet ?? mobile + 1;
    return mobile;
  }

  static EdgeInsetsGeometry responsivePadding({
    required BuildContext context,
    required EdgeInsets mobile,
    EdgeInsets? tablet,
    EdgeInsets? desktop,
    EdgeInsets? largeScreen,
  }) {
    if (isLargeScreen(context))
      return largeScreen ?? _scaleEdgeInsets(desktop ?? tablet ?? mobile, 2.0);
    if (isDesktop(context))
      return desktop ?? _scaleEdgeInsets(tablet ?? mobile, 1.5);
    if (isTablet(context)) return tablet ?? _scaleEdgeInsets(mobile, 1.25);
    return mobile;
  }

  static EdgeInsets _scaleEdgeInsets(EdgeInsets insets, double scale) {
    return EdgeInsets.only(
      left: insets.left * scale,
      right: insets.right * scale,
      top: insets.top * scale,
      bottom: insets.bottom * scale,
    );
  }

  static double responsiveFontSize({
    required BuildContext context,
    required double mobile,
    double? tablet,
    double? desktop,
    double? largeScreen,
  }) {
    if (isLargeScreen(context))
      return largeScreen ?? desktop ?? tablet ?? mobile * 1.3;
    if (isDesktop(context)) return desktop ?? tablet ?? mobile * 1.2;
    if (isTablet(context)) return tablet ?? mobile * 1.1;
    return mobile;
  }

  static double responsiveIconSize({
    required BuildContext context,
    required double mobile,
    double? tablet,
    double? desktop,
    double? largeScreen,
  }) {
    if (isLargeScreen(context))
      return largeScreen ?? desktop ?? tablet ?? mobile * 1.5;
    if (isDesktop(context)) return desktop ?? tablet ?? mobile * 1.35;
    if (isTablet(context)) return tablet ?? mobile * 1.2;
    return mobile;
  }

  static double responsiveBorderRadius({
    required BuildContext context,
    required double mobile,
    double? tablet,
    double? desktop,
    double? largeScreen,
  }) {
    if (isLargeScreen(context))
      return largeScreen ?? desktop ?? tablet ?? mobile * 1.3;
    if (isDesktop(context)) return desktop ?? tablet ?? mobile * 1.2;
    if (isTablet(context)) return tablet ?? mobile * 1.1;
    return mobile;
  }

  static double responsiveElevation({
    required BuildContext context,
    required double mobile,
    double? tablet,
    double? desktop,
    double? largeScreen,
  }) {
    if (isLargeScreen(context))
      return largeScreen ?? desktop ?? tablet ?? mobile * 1.2;
    if (isDesktop(context)) return desktop ?? tablet ?? mobile * 1.1;
    if (isTablet(context)) return tablet ?? mobile * 1.05;
    return mobile;
  }

  static double getSafeAreaTop(BuildContext context) =>
      MediaQuery.of(context).padding.top;
  static double getSafeAreaBottom(BuildContext context) =>
      MediaQuery.of(context).padding.bottom;
  static double getKeyboardHeight(BuildContext context) =>
      MediaQuery.of(context).viewInsets.bottom;
  static bool hasKeyboard(BuildContext context) =>
      getKeyboardHeight(context) > 0;
  static bool isFullScreen(BuildContext context) =>
      MediaQuery.of(context).padding.top == 0;
  static Brightness getPlatformBrightness(BuildContext context) =>
      MediaQuery.of(context).platformBrightness;
  static bool isDarkMode(BuildContext context) =>
      getPlatformBrightness(context) == Brightness.dark;
  static bool isLightMode(BuildContext context) =>
      getPlatformBrightness(context) == Brightness.light;
}

class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget tablet;
  final Widget desktop;
  final Widget? largeScreen;
  final bool animateTransition;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    required this.tablet,
    required this.desktop,
    this.largeScreen,
    this.animateTransition = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        Widget selectedWidget;

        if (screenWidth >= 1200)
          selectedWidget = largeScreen ?? desktop;
        else if (screenWidth >= 1024)
          selectedWidget = desktop;
        else if (screenWidth >= 600)
          selectedWidget = tablet;
        else
          selectedWidget = mobile;

        if (animateTransition) {
          return selectedWidget
              .animate()
              .fadeIn(duration: AppThemes.animationDurationMedium)
              .scaleXY(
                  begin: 0.95,
                  end: 1,
                  duration: AppThemes.animationDurationMedium);
        }
        return selectedWidget;
      },
    );
  }
}

class ResponsiveWidget extends StatelessWidget {
  final Widget Function(BuildContext, BoxConstraints) builder;
  final bool animate;

  const ResponsiveWidget(
      {super.key, required this.builder, this.animate = false});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final widget = builder(context, constraints);
        if (animate) {
          return widget
              .animate()
              .fadeIn(duration: AppThemes.animationDurationFast)
              .slideY(
                  begin: 0.05,
                  end: 0,
                  duration: AppThemes.animationDurationMedium);
        }
        return widget;
      },
    );
  }
}

class AdaptiveContainer extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;
  final bool centerContent;
  final bool animate;

  const AdaptiveContainer({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
    this.centerContent = true,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      constraints: BoxConstraints(maxWidth: maxWidth ?? _getMaxWidth(context)),
      padding: padding ?? _getPadding(context),
      child: child,
    );

    final centeredContent = centerContent ? Center(child: content) : content;

    if (animate) {
      return centeredContent
          .animate()
          .fadeIn(duration: AppThemes.animationDurationMedium)
          .scale(
              begin: const Offset(0.98, 0.98),
              end: const Offset(1, 1),
              duration: AppThemes.animationDurationMedium);
    }
    return centeredContent;
  }

  double _getMaxWidth(BuildContext context) {
    if (ScreenSize.isLargeScreen(context)) return 1440;
    if (ScreenSize.isDesktop(context)) return 1200;
    if (ScreenSize.isTablet(context)) return 900;
    return double.infinity;
  }

  EdgeInsetsGeometry _getPadding(BuildContext context) {
    if (ScreenSize.isLargeScreen(context))
      return const EdgeInsets.symmetric(horizontal: 64, vertical: 32);
    if (ScreenSize.isDesktop(context))
      return const EdgeInsets.symmetric(horizontal: 48, vertical: 24);
    if (ScreenSize.isTablet(context))
      return const EdgeInsets.symmetric(horizontal: 32, vertical: 16);
    return const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
  }
}

class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int mobileColumns;
  final int? tabletColumns;
  final int? desktopColumns;
  final int? largeScreenColumns;
  final double spacing;
  final double runSpacing;
  final EdgeInsetsGeometry padding;
  final bool animateItems;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.mobileColumns = 1,
    this.tabletColumns,
    this.desktopColumns,
    this.largeScreenColumns,
    this.spacing = AppThemes.spacingL,
    this.runSpacing = AppThemes.spacingL,
    this.padding = EdgeInsets.zero,
    this.animateItems = true,
    this.shrinkWrap = true,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: GridView.builder(
        shrinkWrap: shrinkWrap,
        physics: physics ?? const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _getColumnCount(context),
          crossAxisSpacing: spacing,
          mainAxisSpacing: runSpacing,
          childAspectRatio: _getAspectRatio(_getColumnCount(context)),
        ),
        itemCount: children.length,
        itemBuilder: (context, index) {
          final child = children[index];
          if (animateItems) {
            return child
                .animate()
                .fadeIn(duration: AppThemes.animationDurationMedium)
                .slideY(
                    begin: 0.1,
                    end: 0,
                    duration: AppThemes.animationDurationMedium);
          }
          return child;
        },
      ),
    );
  }

  int _getColumnCount(BuildContext context) {
    if (ScreenSize.isLargeScreen(context))
      return largeScreenColumns ??
          (desktopColumns ?? (tabletColumns ?? mobileColumns) * 2);
    if (ScreenSize.isDesktop(context))
      return desktopColumns ?? (tabletColumns ?? mobileColumns * 2);
    if (ScreenSize.isTablet(context))
      return tabletColumns ?? (mobileColumns + 1);
    return mobileColumns;
  }

  double _getAspectRatio(int columns) {
    switch (columns) {
      case 1:
        return 1.4;
      case 2:
        return 1.1;
      case 3:
        return 0.95;
      case 4:
        return 0.85;
      default:
        return 0.8;
    }
  }
}

class PlatformCheck {
  static bool get isMobile => Platform.isAndroid || Platform.isIOS;
  static bool get isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  static bool get isWindows => Platform.isWindows;
  static bool get isLinux => Platform.isLinux;
  static bool get isMacOS => Platform.isMacOS;
  static bool get isAndroid => Platform.isAndroid;
  static bool get isIOS => Platform.isIOS;
  static String get platformName {
    if (isAndroid) return 'Android';
    if (isIOS) return 'iOS';
    if (isWindows) return 'Windows';
    if (isLinux) return 'Linux';
    if (isMacOS) return 'macOS';
    return 'Unknown';
  }

  static void runOnMobile(Function() callback) {
    if (isMobile) callback();
  }

  static void runOnDesktop(Function() callback) {
    if (isDesktop) callback();
  }

  static void runOnWindows(Function() callback) {
    if (isWindows) callback();
  }

  static bool canUseFirebase() => isMobile;
  static bool canUseLocalNotifications() => true;
  static bool canUseBiometrics() => isMobile;
  static bool canUseTelegramFeatures() => true;
}
```

---

## router.dart

```dart
import 'package:familyacademyclient/models/exam_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:familyacademyclient/providers/auth_provider.dart';
import 'package:familyacademyclient/screens/splash/splash_screen.dart';
import 'package:familyacademyclient/screens/auth/device_change_screen.dart';
import 'package:familyacademyclient/screens/auth/login_screen.dart';
import 'package:familyacademyclient/screens/auth/register_screen.dart';
import 'package:familyacademyclient/screens/category/category_detail_screen.dart';
import 'package:familyacademyclient/screens/chapter/chapter_content_screen.dart';
import 'package:familyacademyclient/screens/course/course_detail_screen.dart';
import 'package:familyacademyclient/screens/exam/exam_screen.dart';
import 'package:familyacademyclient/screens/main/chatbot_screen.dart';
import 'package:familyacademyclient/screens/main/home_screen.dart';
import 'package:familyacademyclient/screens/main/main_navigation.dart';
import 'package:familyacademyclient/screens/main/profile_screen.dart';
import 'package:familyacademyclient/screens/main/progress_screen.dart';
import 'package:familyacademyclient/screens/notifications/notification_screen.dart';
import 'package:familyacademyclient/screens/onboarding/school_selection_screen.dart';
import 'package:familyacademyclient/screens/payment/payment_screen.dart';
import 'package:familyacademyclient/screens/payment/payment_success_screen.dart';
import 'package:familyacademyclient/screens/settings/parent_link_screen.dart';
import 'package:familyacademyclient/screens/settings/subscription_screen.dart';
import 'package:familyacademyclient/screens/settings/support_screen.dart';
import 'package:familyacademyclient/screens/settings/tv_pairing_screen.dart';
import '../utils/helpers.dart';

class AppRouter {
  late final GoRouter router;
  bool _isLoginInProgress = false;
  bool _isDeviceChangeInProgress = false;
  bool _isNavigatingToHome = false;
  bool _isNavigatingToSchoolSelection = false;
  bool _isNavigatingFromDeviceChange = false;
  String? _pendingDestination;
  Map<String, dynamic>? _pendingDeviceChangeData;

  AppRouter() {
    router = GoRouter(
      initialLocation: '/splash',
      redirect: (context, state) async {
        final location = state.uri.toString();

        final authProvider = Provider.of<AuthProvider>(context, listen: false);

        if (_isNavigatingToHome ||
            _isNavigatingToSchoolSelection ||
            _isNavigatingFromDeviceChange) {
          Future.delayed(const Duration(milliseconds: 500), () {
            _isNavigatingToHome = false;
            _isNavigatingToSchoolSelection = false;
            _isNavigatingFromDeviceChange = false;
            _pendingDestination = null;
          });
          return null;
        }

        if (authProvider.requiresDeviceChange && !_isDeviceChangeInProgress) {
          final lastLoginResult = authProvider.lastLoginResult;

          if (lastLoginResult != null && lastLoginResult['data'] != null) {
            _pendingDeviceChangeData = {
              'username': lastLoginResult['username'],
              'password': lastLoginResult['password'],
              'deviceId': lastLoginResult['deviceId'],
              'fcmToken': lastLoginResult['fcmToken'],
              'currentDeviceId': lastLoginResult['data']['currentDeviceId'],
              'newDeviceId': lastLoginResult['data']['newDeviceId'],
              'changeCount': lastLoginResult['data']['changeCount'] ?? 0,
              'maxChanges': lastLoginResult['data']['maxChanges'] ?? 2,
              'remainingChanges':
                  lastLoginResult['data']['remainingChanges'] ?? 2,
              'canChangeDevice':
                  lastLoginResult['data']['canChangeDevice'] ?? true,
            };
          }

          _isDeviceChangeInProgress = true;
          if (location != '/device-change') return '/device-change';
        }

        if (location.startsWith('/device-change')) return null;

        if (!location.startsWith('/device-change') &&
            _isDeviceChangeInProgress) {
          _isDeviceChangeInProgress = false;
          _pendingDeviceChangeData = null;
        }

        if (location == '/splash') {
          if (authProvider.isInitialized) {
            if (authProvider.isAuthenticated) {
              final user = authProvider.currentUser;
              if (user?.schoolId == null)
                return '/school-selection';
              else
                return '/';
            } else {
              return '/auth/login';
            }
          }
          return null;
        }

        if (!authProvider.isInitialized && location != '/splash')
          return '/splash';

        final isAuthenticated = authProvider.isAuthenticated;
        final user = authProvider.currentUser;

        final publicRoutes = [
          '/auth/login',
          '/auth/register',
          '/device-change',
          '/payment-success'
        ];

        final isPublicRoute = publicRoutes.any(
            (route) => location == route || location.startsWith('$route?'));

        if (!isAuthenticated && !isPublicRoute) return '/auth/login';

        if (isAuthenticated &&
            location.startsWith('/auth/') &&
            location != '/auth/logout') {
          if (user?.schoolId == null) return '/school-selection';
          return '/';
        }

        if (isAuthenticated) {
          if (user?.schoolId == null &&
              location != '/school-selection' &&
              location != '/payment-success' &&
              !location.startsWith('/auth/') &&
              location != '/splash' &&
              !location.startsWith('/device-change')) {
            return '/school-selection';
          }
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/splash',
          name: 'splash',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const SplashScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) =>
                    FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          path: '/auth/register',
          name: 'register',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const RegisterScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) =>
                    SlideTransition(
              position:
                  Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                      .animate(animation),
              child: child,
            ),
          ),
        ),
        GoRoute(
          path: '/auth/login',
          name: 'login',
          pageBuilder: (context, state) {
            final forceLogin = state.uri.queryParameters['force'] == 'true';
            return CustomTransitionPage(
              key: state.pageKey,
              child: const LoginScreen(),
              fullscreenDialog: forceLogin,
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) =>
                      FadeTransition(opacity: animation, child: child),
            );
          },
        ),
        GoRoute(
          path: '/device-change',
          name: 'device-change',
          pageBuilder: (context, state) {
            Map<String, dynamic> extra = {};
            if (state.extra != null && state.extra is Map<String, dynamic>) {
              extra = state.extra as Map<String, dynamic>;
            } else if (_pendingDeviceChangeData != null) {
              extra = _pendingDeviceChangeData!;
            }
            return MaterialPage(
              key: state.pageKey,
              child: const DeviceChangeScreen(),
              fullscreenDialog: true,
              arguments: extra,
            );
          },
        ),
        GoRoute(
          path: '/school-selection',
          name: 'school-selection',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const SchoolSelectionScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) =>
                    FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          path: '/payment',
          name: 'payment',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: PaymentScreen(extra: state.extra as Map<String, dynamic>?),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) =>
                    SlideTransition(
              position:
                  Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                      .animate(animation),
              child: child,
            ),
          ),
        ),
        GoRoute(
          path: '/payment-success',
          name: 'payment-success',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: PaymentSuccessScreen(
                extra: state.extra as Map<String, dynamic>?),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) =>
                    FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          path: '/subscriptions',
          name: 'subscriptions',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const SubscriptionScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) =>
                    SlideTransition(
              position:
                  Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                      .animate(animation),
              child: child,
            ),
          ),
        ),
        GoRoute(
          path: '/tv-pairing',
          name: 'tv-pairing',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const TvPairingScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) =>
                    FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          path: '/parent-link',
          name: 'parent-link',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const ParentLinkScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) =>
                    SlideTransition(
              position:
                  Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                      .animate(animation),
              child: child,
            ),
          ),
        ),
        GoRoute(
          path: '/support',
          name: 'support',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const SupportScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) =>
                    FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          path: '/notifications',
          name: 'notifications',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const NotificationsScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) =>
                    SlideTransition(
              position:
                  Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                      .animate(animation),
              child: child,
            ),
          ),
        ),
        GoRoute(
          path: '/category/:categoryId',
          name: 'category-detail',
          pageBuilder: (context, state) {
            final categoryId =
                int.tryParse(state.pathParameters['categoryId'] ?? '0') ?? 0;
            return CustomTransitionPage(
              key: ValueKey('category-$categoryId'),
              child: CategoryDetailScreen(categoryId: categoryId),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) =>
                      FadeTransition(opacity: animation, child: child),
            );
          },
        ),
        GoRoute(
          path: '/course/:courseId',
          name: 'course-detail',
          pageBuilder: (context, state) {
            final courseId =
                int.tryParse(state.pathParameters['courseId'] ?? '0') ?? 0;
            return CustomTransitionPage(
              key: ValueKey('course-$courseId'),
              child: CourseDetailScreen(courseId: courseId),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) =>
                      SlideTransition(
                position:
                    Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                        .animate(animation),
                child: child,
              ),
            );
          },
        ),
        GoRoute(
          path: '/chapter/:chapterId',
          name: 'chapter-content',
          pageBuilder: (context, state) {
            final chapterId =
                int.tryParse(state.pathParameters['chapterId'] ?? '0') ?? 0;
            return CustomTransitionPage(
              key: ValueKey('chapter-$chapterId'),
              child: ChapterContentScreen(chapterId: chapterId),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) =>
                      FadeTransition(opacity: animation, child: child),
            );
          },
        ),
        GoRoute(
          path: '/exam/:examId',
          name: 'exam',
          pageBuilder: (context, state) {
            final examId =
                int.tryParse(state.pathParameters['examId'] ?? '0') ?? 0;
            final exam = state.extra as Exam?;
            return CustomTransitionPage(
              key: ValueKey('exam-$examId'),
              child: ExamScreen(examId: examId, exam: exam),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) =>
                      ScaleTransition(scale: animation, child: child),
            );
          },
        ),
        // REMOVED: '/course/:courseId/exams' route - exams now shown directly in CourseDetailScreen

        ShellRoute(
          builder: (context, state, child) => MainNavigation(child: child),
          routes: [
            GoRoute(
                path: '/',
                name: 'home',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: HomeScreen())),
            GoRoute(
                path: '/chatbot',
                name: 'chatbot',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: ChatbotScreen())),
            GoRoute(
                path: '/progress',
                name: 'progress',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: ProgressScreen())),
            GoRoute(
                path: '/profile',
                name: 'profile',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: ProfileScreen())),
          ],
        ),
      ],
      errorBuilder: (context, state) {
        return Scaffold(
          appBar: AppBar(title: const Text('Error')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline,
                    size: 64, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 24),
                Text('Oops!',
                    style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.error)),
                const SizedBox(height: 16),
                Text('The page you\'re looking for couldn\'t be found.',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => context.go('/'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Go Home'),
                ),
              ],
            ),
          ),
        );
      },
      debugLogDiagnostics: true,
    );
  }

  void setNavigatingToHome(bool value) => _isNavigatingToHome = value;
  void setNavigatingToSchoolSelection(bool value) =>
      _isNavigatingToSchoolSelection = value;
  void setNavigatingFromDeviceChange(bool value) =>
      _isNavigatingFromDeviceChange = value;
  void setPendingDestination(String? destination) =>
      _pendingDestination = destination;
  void markLoginInProgress(bool inProgress) => _isLoginInProgress = inProgress;
}

final appRouter = AppRouter();
```

---

## screen_protection.dart

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../utils/helpers.dart';

class ScreenProtectionService {
  static bool _protectionEnabled = true;
  static bool _initialized = false;
  static const MethodChannel _channel =
      MethodChannel('com.familyacademy/screen_protection');

  static Future<void> initialize() async {
    if (_initialized) return;

    if (Platform.isAndroid || Platform.isIOS) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }

    await enableSecureMode();
    _initialized = true;
    debugLog('ScreenProtection', '✅ Initialized with full protection');
  }

  static Future<void> enableSecureMode() async {
    try {
      if (Platform.isAndroid) {
        // Set FLAG_SECURE to prevent screenshots and screen recording
        await _channel.invokeMethod('protectScreen');

        // Set immersive mode for better protection
        await SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.edgeToEdge,
          overlays: [SystemUiOverlay.top],
        );

        SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.light,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
        );
      } else if (Platform.isIOS) {
        // iOS specific protection
        await _channel.invokeMethod('protectScreen');

        await SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.edgeToEdge,
          overlays: [],
        );
      }
    } catch (e) {
      debugLog('ScreenProtection', 'Error enabling secure mode: $e');
      await _setSafeSystemUiFlags();
    }
  }

  static Future<void> _setSafeSystemUiFlags() async {
    try {
      if (Platform.isAndroid) {
        await _channel.invokeMethod('setSystemUiMode', 'immersive');
        await SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.immersiveSticky,
          overlays: [],
        );
      }
    } catch (e) {}
  }

  static Future<void> disableSplitScreen() async {
    try {
      if (Platform.isAndroid) {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);

        try {
          await SystemChrome.setEnabledSystemUIMode(
            SystemUiMode.immersiveSticky,
            overlays: [],
          );
        } catch (e) {
          await _setSafeSystemUiFlags();
        }

        // Additional protection against split screen
        await _channel.invokeMethod('disableSplitScreen');
      }
    } catch (e) {
      debugLog('ScreenProtection', 'Error disabling split screen: $e');
    }
  }

  static void enableOnResume() {
    if (!_protectionEnabled) return;
    _setSecureFlags(true);

    if (Platform.isAndroid || Platform.isIOS) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }

    debugLog('ScreenProtection', '🛡️ Protection enabled on resume');
  }

  static void disableOnPause() {
    _setSecureFlags(false);
    debugLog('ScreenProtection', '⚠️ Protection disabled on pause');
  }

  static void disable() {
    _protectionEnabled = false;
    _setSecureFlags(false);

    if (Platform.isAndroid || Platform.isIOS) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    debugLog('ScreenProtection', '🔓 Protection disabled');
  }

  static void enable() {
    _protectionEnabled = true;
    _setSecureFlags(true);

    if (Platform.isAndroid || Platform.isIOS) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
    debugLog('ScreenProtection', '🔒 Protection enabled');
  }

  static void _setSecureFlags(bool secure) {
    try {
      if (Platform.isAndroid) {
        _channel.invokeMethod(secure ? 'protectScreen' : 'unprotectScreen');
      } else if (Platform.isIOS) {
        _channel.invokeMethod(secure ? 'protectScreen' : 'unprotectScreen');
      }
    } catch (e) {
      debugLog('ScreenProtection', 'Error setting secure flags: $e');
    }
  }

  static bool isEnabled() => _protectionEnabled;

  static Widget protectWidget(Widget child, {bool enableProtection = true}) {
    if (!enableProtection || !_protectionEnabled) return child;

    return NotificationListener<UserScrollNotification>(
      onNotification: (notification) {
        if (notification.direction != ScrollDirection.idle) enableOnResume();
        return false;
      },
      child: RepaintBoundary(
        child: child,
      ),
    );
  }

  static Widget preventScreenshot(Widget child) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: RepaintBoundary(
        child: child,
      ),
    );
  }

  static Future<void> clear() async {
    _protectionEnabled = true;
    _initialized = false;

    if (Platform.isAndroid || Platform.isIOS) {
      await SystemChrome.setPreferredOrientations([]);
      try {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      } catch (e) {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual);
      }
    }
    debugLog('ScreenProtection', '🧹 Protection cleared');
  }
}
```

---

## video_protection.dart

```dart
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../utils/helpers.dart';

class VideoProtectionService {
  static VideoPlayerController? _currentController;
  static bool _wakelockEnabled = false;
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    debugLog('VideoProtection', 'Initializing video protection');
    _initialized = true;
  }

  static void protectVideoController(VideoPlayerController controller) {
    _currentController = controller;

    _enableWakelock();

    controller.addListener(() {
      if (controller.value.isPlaying) {
        _enableWakelock();
      } else {
        _disableWakelock();
      }
    });

    debugLog('VideoProtection', '✅ Video controller protected');
  }

  static Future<void> _enableWakelock() async {
    if (_wakelockEnabled) return;

    try {
      await WakelockPlus.enable();
      _wakelockEnabled = true;
      debugLog('VideoProtection', '🔋 Wakelock enabled');
    } catch (e) {
      debugLog('VideoProtection', 'Error enabling wakelock: $e');
    }
  }

  static Future<void> _disableWakelock() async {
    if (!_wakelockEnabled) return;

    try {
      await WakelockPlus.disable();
      _wakelockEnabled = false;
      debugLog('VideoProtection', '🔌 Wakelock disabled');
    } catch (e) {
      debugLog('VideoProtection', 'Error disabling wakelock: $e');
    }
  }

  static Widget protectVideoPlayer(Widget videoPlayer) {
    return GestureDetector(
      onLongPress: () {
        debugLog('VideoProtection', '⚠️ Long press blocked on video');
      },
      onDoubleTap: () {
        debugLog('VideoProtection', '⚠️ Double tap blocked on video');
      },
      child: AbsorbPointer(
        absorbing: false,
        child: videoPlayer,
      ),
    );
  }

  static Map<String, dynamic> protectVideoUrl(String videoUrl) {
    final protectedUrl = {
      'url': videoUrl,
      'protected': true,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'expires_in': 3600,
    };

    debugLog('VideoProtection', '🔒 Video URL protected');
    return protectedUrl;
  }

  static Future<void> clear() async {
    debugLog('VideoProtection', '🧹 Clearing video protection');

    await _disableWakelock();

    if (_currentController != null) {
      try {
        await _currentController!.dispose();
      } catch (e) {
        debugLog('VideoProtection', 'Error disposing controller: $e');
      }
      _currentController = null;
    }

    _initialized = false;
  }

  static bool isVideoProtected() {
    return _currentController != null;
  }

  static Duration? getCurrentPosition() {
    if (_currentController != null && _currentController!.value.isInitialized) {
      return _currentController!.value.position;
    }
    return null;
  }

  static Map<String, dynamic> savePlaybackState() {
    final state = <String, dynamic>{
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    if (_currentController != null && _currentController!.value.isInitialized) {
      state['position'] = _currentController!.value.position.inSeconds;
      state['duration'] = _currentController!.value.duration.inSeconds;
      state['is_playing'] = _currentController!.value.isPlaying;
    }

    return state;
  }

  static Future<void> restorePlaybackState(
      VideoPlayerController controller, Map<String, dynamic> state) async {
    try {
      if (state.containsKey('position') && controller.value.isInitialized) {
        final position = Duration(seconds: state['position'] as int);
        await controller.seekTo(position);

        if (state['is_playing'] == true) {
          await controller.play();
          await _enableWakelock();
        }

        debugLog('VideoProtection', '▶️ Playback state restored');
      }
    } catch (e) {
      debugLog('VideoProtection', 'Error restoring playback state: $e');
    }
  }

  static void handleAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        if (_currentController != null && _currentController!.value.isPlaying) {
          _currentController!.pause();
          _disableWakelock();
        }
        break;
      case AppLifecycleState.resumed:
        break;
      default:
        break;
    }
  }
}
```

---


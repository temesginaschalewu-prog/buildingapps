import 'dart:convert';
import 'package:familyacademyclient/utils/screen_protection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/auth_provider.dart';
import 'utils/router.dart';
import 'services/notification_service.dart';
import 'utils/helpers.dart';

class FamilyAcademyApp extends StatefulWidget {
  final NotificationService notificationService;

  const FamilyAcademyApp({
    super.key,
    required this.notificationService,
  });

  @override
  State<FamilyAcademyApp> createState() => _FamilyAcademyAppState();
}

class _FamilyAcademyAppState extends State<FamilyAcademyApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        ScreenProtectionService.enableOnResume();
        break;
      case AppLifecycleState.paused:
        ScreenProtectionService.disableOnPause();
        break;
      case AppLifecycleState.inactive:
        ScreenProtectionService.disableOnPause();
        break;
      case AppLifecycleState.detached:
        ScreenProtectionService.disable();
        break;
      case AppLifecycleState.hidden:
        ScreenProtectionService.disableOnPause();
        break;
    }
  }

  Future<void> _refreshAllData() async {
    try {
      // Get the current context using a GlobalKey or similar
      // For now, we'll handle this in the notification handler
      debugLog('FamilyAcademyApp', '🔄 App resumed, should refresh data');
    } catch (e) {
      debugLog('FamilyAcademyApp', 'Error refreshing data on resume: $e');
    }
  }

  Future<void> _initializeApp() async {
    try {
      await widget.notificationService.init();
      debugLog('FamilyAcademyApp', '✅ Notification service initialized');

      // Listen to notification stream
      widget.notificationService.notificationStream.listen((data) {
        debugLog(
            'FamilyAcademyApp', '📱 Notification received: ${data['type']}');
        _handleNotificationData(data);
      });

      debugLog('FamilyAcademyApp', '✅ App initialization complete');
    } catch (e) {
      debugLog('FamilyAcademyApp', '❌ App initialization error: $e');
    }
  }

  void _handleNotificationData(Map<String, dynamic> data) {
    final type = data['type'];
    final notificationData = data['data'];

    switch (type) {
      case 'payment_verified':
        debugLog('FamilyAcademyApp', '💰 Payment verified: $notificationData');
        // When payment is verified, we need to refresh subscriptions
        _handlePaymentVerified(notificationData);
        break;
      case 'payment_rejected':
        debugLog('FamilyAcademyApp', '❌ Payment rejected: $notificationData');
        break;
      case 'exam_result':
        debugLog('FamilyAcademyApp', '📝 Exam result: $notificationData');
        break;
      case 'streak_update':
        debugLog('FamilyAcademyApp', '🔥 Streak update: $notificationData');
        break;
      case 'system_announcement':
        debugLog(
            'FamilyAcademyApp', '📢 System announcement: $notificationData');
        break;
    }
  }

  void _handlePaymentVerified(Map<String, dynamic> data) {
    // This is where we handle the refresh when payment is verified
    // We need to access providers to refresh data

    // Show a snackbar or notification to user
    widget.notificationService.showLocalNotification(
      title: 'Payment Verified!',
      body: 'Your payment has been verified. Your access is now active.',
      payload: json.encode({
        'type': 'payment_verified_action',
        'action': 'refresh_subscriptions',
        'category_id': data['category_id'],
        'timestamp': DateTime.now().toIso8601String(),
      }),
    );

    // Note: We can't directly access providers here without context
    // The actual refresh will happen when user opens the category screen
  }

  // Method to test notifications (can be called from anywhere)
  void testNotification() {
    widget.notificationService.showLocalNotification(
      title: 'Test Notification',
      body: 'Welcome to Family Academy! This is a test notification.',
      payload: json.encode({
        'type': 'system_announcement',
        'message': 'Test notification from app',
        'timestamp': DateTime.now().toIso8601String(),
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp.router(
          title: 'Family Academy',
          theme: themeProvider.lightTheme,
          darkTheme: themeProvider.darkTheme,
          themeMode: themeProvider.themeMode,
          routerConfig: AppRouter().router,
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaleFactor: 1.0,
              ),
              child: child ?? const SizedBox(),
            );
          },
        );
      },
    );
  }
}

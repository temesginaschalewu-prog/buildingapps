import 'dart:convert';
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

class _FamilyAcademyAppState extends State<FamilyAcademyApp> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
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
    // This handles notifications from the stream
    final type = data['type'];
    final notificationData = data['data'];

    switch (type) {
      case 'payment_verified':
        debugLog('FamilyAcademyApp', '💰 Payment verified: $notificationData');
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

  @override
  void dispose() {
    widget.notificationService.dispose();
    super.dispose();
  }
}

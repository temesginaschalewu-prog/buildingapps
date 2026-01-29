import 'dart:convert';
import 'package:familyacademyclient/utils/screen_protection.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/auth_provider.dart';
import 'utils/router.dart';
import 'services/notification_service.dart';
import 'services/api_service.dart';
import 'utils/helpers.dart';

class FamilyAcademyApp extends StatefulWidget {
  final ApiService apiService;

  const FamilyAcademyApp({
    super.key,
    required this.apiService,
  });

  @override
  State<FamilyAcademyApp> createState() => _FamilyAcademyAppState();
}

class _FamilyAcademyAppState extends State<FamilyAcademyApp>
    with WidgetsBindingObserver {
  bool _isAppInForeground = true;
  String _currentRoute = '/';
  bool _isRouterReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Wait for router to be ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isRouterReady && context.mounted) {
        try {
          // This will only work after the router is built
          final routeState = GoRouterState.of(context);
          _currentRoute = routeState.uri.toString();
          _isRouterReady = true;
          debugLog('FamilyAcademyApp',
              '✅ Router ready, initial route: $_currentRoute');
        } catch (e) {
          debugLog('FamilyAcademyApp', '⚠️ Router not ready yet: $e');
        }
      }
    });
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
        _isAppInForeground = true;
        ScreenProtectionService.enableOnResume();
        _refreshAllData();
        debugLog('FamilyAcademyApp', '🔄 App resumed - protection enabled');
        break;
      case AppLifecycleState.paused:
        _isAppInForeground = false;
        ScreenProtectionService.disableOnPause();
        debugLog('FamilyAcademyApp', '⏸️ App paused - protection disabled');
        break;
      case AppLifecycleState.inactive:
        _isAppInForeground = false;
        ScreenProtectionService.disableOnPause();
        debugLog('FamilyAcademyApp', '⚡ App inactive - protection disabled');
        break;
      case AppLifecycleState.detached:
        _isAppInForeground = false;
        ScreenProtectionService.disable();
        debugLog('FamilyAcademyApp', '🔌 App detached - protection disabled');
        break;
      case AppLifecycleState.hidden:
        _isAppInForeground = false;
        ScreenProtectionService.disableOnPause();
        debugLog('FamilyAcademyApp', '👁️ App hidden - protection disabled');
        break;
    }
  }

  Future<void> _refreshAllData() async {
    try {
      if (_isAppInForeground) {
        debugLog('FamilyAcademyApp', '🔄 App resumed, refreshing data');
        // Only refresh if app is in foreground
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.isAuthenticated) {
          // Refresh user data in background
          await authProvider.checkAndRequireReLogin();

          if (authProvider.requiresReLogin) {
            debugLog(
                'FamilyAcademyApp', '🔄 Re-login required (3 days passed)');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                authProvider.logoutDueToInactivity();
                GoRouter.of(context).go('/auth/login');
              }
            });
          }
        }
      }
    } catch (e) {
      debugLog('FamilyAcademyApp', 'Error refreshing data on resume: $e');
    }
  }

  Future<void> _initializeApp() async {
    try {
      // Initialize screen protection
      await ScreenProtectionService.initialize();
      await ScreenProtectionService.disableSplitScreen();

      debugLog('FamilyAcademyApp', '✅ Screen protection initialized');

      // Set ApiService to NotificationService singleton
      final notificationService = NotificationService();
      notificationService.setApiService(widget.apiService);

      // Check if re-login is required (3 days check)
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (context.mounted) {
          final authProvider =
              Provider.of<AuthProvider>(context, listen: false);
          await authProvider.checkAndRequireReLogin();

          if (authProvider.requiresReLogin) {
            debugLog(
                'FamilyAcademyApp', '🔄 Re-login required (3 days passed)');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                authProvider.logoutDueToInactivity();
                GoRouter.of(context).go('/auth/login');
              }
            });
          }
        }
      });

      // Listen to notification stream
      notificationService.notificationStream.listen((data) {
        debugLog(
            'FamilyAcademyApp', '📱 Notification received: ${data['type']}');
        _handleNotificationData(data);
      });

      debugLog('FamilyAcademyApp', '✅ App initialization complete');
    } catch (e) {
      debugLog('FamilyAcademyApp', '❌ App initialization error: $e');
    }
  }

  // Monitor route changes using GoRouterState
  void _monitorRouteChanges() {
    if (!_isRouterReady || !context.mounted) return;

    try {
      final routeState = GoRouterState.of(context);
      final currentUri = routeState.uri.toString();

      if (_currentRoute != currentUri) {
        final previousRoute = _currentRoute;
        _currentRoute = currentUri;

        debugLog('FamilyAcademyApp',
            '🔄 Route changed from "$previousRoute" to "$_currentRoute"');

        // Re-enable screen protection on any route change
        if (_isAppInForeground) {
          ScreenProtectionService.enableOnResume();
        }

        // Prevent unauthorized navigation attempts
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            _preventUnauthorizedNavigation(_currentRoute);
          }
        });
      }
    } catch (e) {
      // Router might not be available yet
    }
  }

  // Prevent unauthorized navigation attempts
  void _preventUnauthorizedNavigation(String location) {
    if (!context.mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Define public routes that don't require authentication
    final publicRoutes = [
      '/auth/login',
      '/auth/register',
      '/device-change',
      '/payment-success' // Payment success is public
    ];

    // Check if trying to access protected route without auth
    if (!authProvider.isAuthenticated) {
      bool isProtectedRoute = true;
      for (final route in publicRoutes) {
        if (location == route || location.startsWith('$route?')) {
          isProtectedRoute = false;
          break;
        }
      }

      if (isProtectedRoute && location != '/auth/login') {
        debugLog('FamilyAcademyApp',
            '🚫 Blocked unauthorized navigation to: $location');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            GoRouter.of(context).go('/auth/login');
          }
        });
      }
    } else {
      // User is authenticated, check for school selection
      if (authProvider.user?.schoolId == null &&
          location != '/school-selection' &&
          location != '/payment-success') {
        // Redirect to school selection if no school selected
        debugLog('FamilyAcademyApp', '🏫 Redirecting to school selection');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            GoRouter.of(context).go('/school-selection');
          }
        });
      }

      // Prevent authenticated users from accessing auth routes
      if (location.startsWith('/auth/') && location != '/auth/logout') {
        debugLog('FamilyAcademyApp',
            '🔄 Redirecting authenticated user from auth route');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            GoRouter.of(context).go('/');
          }
        });
      }
    }
  }

  void _handleNotificationData(Map<String, dynamic> data) {
    final type = data['type'];
    final notificationData = data['data'];
    final route = data['route'] ?? '/notifications';

    debugLog('FamilyAcademyApp', '🔄 Handling notification type: $type');

    // Ensure we're in foreground before handling notification
    if (!_isAppInForeground) {
      debugLog(
          'FamilyAcademyApp', '📱 App in background, queuing notification');
      // Queue notification handling for when app resumes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          _processNotificationInForeground(type, notificationData, route);
        }
      });
      return;
    }

    _processNotificationInForeground(type, notificationData, route);
  }

  void _processNotificationInForeground(
      String type, dynamic notificationData, String route) {
    switch (type) {
      case 'payment_verified':
        debugLog('FamilyAcademyApp', '💰 Payment verified: $notificationData');
        _handlePaymentVerified(notificationData);
        break;
      case 'payment_rejected':
        debugLog('FamilyAcademyApp', '❌ Payment rejected: $notificationData');
        _showPaymentRejectedNotification(notificationData);
        break;
      case 'exam_result':
        debugLog('FamilyAcademyApp', '📝 Exam result: $notificationData');
        _showExamResultNotification(notificationData);
        break;
      case 'streak_update':
        debugLog('FamilyAcademyApp', '🔥 Streak update: $notificationData');
        _showStreakUpdateNotification(notificationData);
        break;
      case 'system_announcement':
        debugLog(
            'FamilyAcademyApp', '📢 System announcement: $notificationData');
        _showSystemAnnouncement(notificationData);
        break;
      case 'navigate':
        debugLog('FamilyAcademyApp', '📍 Navigating to: $route');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted && _isRouterReady) {
            // Ensure protection is enabled before navigation
            ScreenProtectionService.enableOnResume();
            GoRouter.of(context).go(route);
          }
        });
        break;
      case 'notification_clicked':
        debugLog('FamilyAcademyApp', '🖱️ Notification clicked');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted && _isRouterReady) {
            // Refresh notifications before navigating
            context.read<NotificationProvider>().loadNotifications().then((_) {
              ScreenProtectionService.enableOnResume();
              GoRouter.of(context).go(route);
            });
          }
        });
        break;
      default:
        debugLog('FamilyAcademyApp', '❓ Unknown notification type: $type');
    }
  }

  void _handlePaymentVerified(Map<String, dynamic> data) {
    final notificationService = NotificationService();
    notificationService.showLocalNotification(
      title: 'Payment Verified!',
      body: 'Your payment has been verified. Your access is now active.',
      payload: json.encode({
        'type': 'payment_verified_action',
        'action': 'refresh_subscriptions',
        'category_id': data['category_id'],
        'timestamp': DateTime.now().toIso8601String(),
      }),
    );

    // Refresh subscription data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        final subscriptionProvider = context.read<NotificationProvider>();
        subscriptionProvider.loadNotifications();
      }
    });
  }

  void _showPaymentRejectedNotification(dynamic data) {
    final notificationService = NotificationService();
    notificationService.showLocalNotification(
      title: 'Payment Rejected',
      body: 'Your payment was rejected. Please contact support.',
      payload: json.encode({
        'type': 'payment_rejected_action',
        'action': 'contact_support',
        'timestamp': DateTime.now().toIso8601String(),
      }),
    );
  }

  void _showExamResultNotification(dynamic data) {
    final notificationService = NotificationService();
    notificationService.showLocalNotification(
      title: 'Exam Results Available',
      body: 'Your exam results are ready to view.',
      payload: json.encode({
        'type': 'exam_result_action',
        'action': 'view_results',
        'exam_id': data['exam_id'],
        'timestamp': DateTime.now().toIso8601String(),
      }),
    );
  }

  void _showStreakUpdateNotification(dynamic data) {
    final notificationService = NotificationService();
    notificationService.showLocalNotification(
      title: 'Streak Update!',
      body: 'You have a ${data['streak_days']} day streak! Keep it up!',
      payload: json.encode({
        'type': 'streak_update_action',
        'action': 'view_progress',
        'timestamp': DateTime.now().toIso8601String(),
      }),
    );
  }

  void _showSystemAnnouncement(dynamic data) {
    final notificationService = NotificationService();
    notificationService.showLocalNotification(
      title: data['title'] ?? 'System Announcement',
      body: data['message'] ?? 'New system announcement',
      payload: json.encode({
        'type': 'system_announcement_action',
        'action': 'view_announcements',
        'timestamp': DateTime.now().toIso8601String(),
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Monitor route changes in build method
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _monitorRouteChanges();
    });

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
            // Add popup protection overlay
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaleFactor: 1.0,
              ),
              child: PopScope(
                // Prevent back button from being used maliciously
                canPop: true,
                onPopInvoked: (didPop) {
                  if (didPop) {
                    // Ensure protection is maintained after pop
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_isAppInForeground) {
                        ScreenProtectionService.enableOnResume();
                      }
                    });
                  }
                },
                child: child ?? const SizedBox(),
              ),
            );
          },
        );
      },
    );
  }
}

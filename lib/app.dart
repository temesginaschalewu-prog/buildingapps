import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:familyacademyclient/providers/payment_provider.dart';
import 'package:familyacademyclient/providers/settings_provider.dart';
import 'package:familyacademyclient/providers/user_provider.dart';
import 'package:familyacademyclient/screens/splash/splash_screen.dart';
import 'package:familyacademyclient/utils/screen_protection.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import 'providers/theme_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/subscription_provider.dart';
import 'providers/category_provider.dart';
import 'utils/router.dart';
import 'services/notification_service.dart';
import 'services/api_service.dart';
import 'utils/helpers.dart';

class FamilyAcademyApp extends StatefulWidget {
  final ApiService apiService;
  final NotificationService notificationService;

  const FamilyAcademyApp({
    super.key,
    required this.apiService,
    required this.notificationService,
  });

  @override
  State<FamilyAcademyApp> createState() => _FamilyAcademyAppState();
}

class _FamilyAcademyAppState extends State<FamilyAcademyApp>
    with WidgetsBindingObserver {
  bool _isAppInForeground = true;
  String _currentRoute = '/';
  bool _isRouterReady = false;
  bool _isInitializing = false;
  final Map<String, DateTime> _lastRouteVisited = {};
  Timer? _sessionCheckTimer;

  StreamSubscription? _deviceDeactivatedSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
    _startSessionChecker();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isRouterReady && context.mounted) {
      try {
        final routeState = GoRouterState.of(context);
        _currentRoute = routeState.uri.toString();
        _isRouterReady = true;
        debugLog('FamilyAcademyApp',
            '✅ Router ready, initial route: $_currentRoute');
      } catch (e) {
        debugLog('FamilyAcademyApp', '⚠️ Router not ready yet: $e');
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionCheckTimer?.cancel();
    _deviceDeactivatedSubscription?.cancel();
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

  void _startSessionChecker() {
    _sessionCheckTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (context.mounted) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.isAuthenticated) {
          authProvider.checkSession();
        }
      }
    });
  }

  Future<void> _initializeApp() async {
    try {
      await ScreenProtectionService.initialize();
      await ScreenProtectionService.disableSplitScreen();

      debugLog('FamilyAcademyApp', '✅ Screen protection initialized');

      widget.notificationService.setApiService(widget.apiService);

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (context.mounted) {
          final authProvider =
              Provider.of<AuthProvider>(context, listen: false);

          _deviceDeactivatedSubscription =
              authProvider.deviceDeactivated.listen((message) {
            if (!mounted) return;

            debugLog('FamilyAcademyApp',
                '🚫 Device deactivated event received: $message');

            _showDeviceDeactivatedDialog(message ??
                'Your device has been deactivated because you logged in on another device.');
          });

          await authProvider.initialize();

          if (authProvider.isAuthenticated) {
            await _initializeAuthenticatedProviders();
          }
        }
      });

      widget.notificationService.notificationStream.listen((data) {
        if (_isAppInForeground) {
          _handleNotificationData(data);
        }
      });

      debugLog('FamilyAcademyApp', '✅ App initialization complete');
    } catch (e) {
      debugLog('FamilyAcademyApp', '❌ App initialization error: $e');
    }
  }

  void _showDeviceDeactivatedDialog(String message) {
    if (!mounted || !context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Device Deactivated'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();

              if (mounted && context.mounted) {
                GoRouter.of(context).go('/auth/login');
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _initializeAuthenticatedProviders() async {
    if (_isInitializing || !context.mounted) return;

    _isInitializing = true;
    debugLog('FamilyAcademyApp', '🔄 Initializing authenticated providers');

    try {
      final subscriptionProvider =
          Provider.of<SubscriptionProvider>(context, listen: false);
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);

      final settingsProvider =
          Provider.of<SettingsProvider>(context, listen: false);
      await settingsProvider.getAllSettings();

      await subscriptionProvider.loadSubscriptions();
      await categoryProvider.loadCategoriesWithSubscriptionCheck();

      _loadBackgroundProviders();

      await widget.notificationService.sendFcmTokenToBackendIfAuthenticated();
    } catch (e) {
      debugLog('FamilyAcademyApp', 'Provider initialization error: $e');
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _loadBackgroundProviders() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final notificationProvider =
          Provider.of<NotificationProvider>(context, listen: false);
      final paymentProvider =
          Provider.of<PaymentProvider>(context, listen: false);
      final settingsProvider =
          Provider.of<SettingsProvider>(context, listen: false);

      await settingsProvider.getAllSettings().catchError(
          (e) => debugLog('FamilyAcademyApp', 'Settings error: $e'));

      await Future.wait([
        userProvider.loadUserProfile().catchError(
            (e) => debugLog('FamilyAcademyApp', 'User profile error: $e')),
        notificationProvider.loadNotifications().catchError(
            (e) => debugLog('FamilyAcademyApp', 'Notifications error: $e')),
        paymentProvider.loadPayments().catchError(
            (e) => debugLog('FamilyAcademyApp', 'Payments error: $e')),
      ], eagerError: true);
    } catch (e) {
      debugLog('FamilyAcademyApp', 'Background providers error: $e');
    }
  }

  Future<void> _refreshAllData() async {
    try {
      if (_isAppInForeground && context.mounted) {
        debugLog('FamilyAcademyApp', '🔄 App resumed, refreshing data');
        final authProvider = Provider.of<AuthProvider>(context, listen: false);

        if (authProvider.isAuthenticated) {
          final subscriptionProvider =
              Provider.of<SubscriptionProvider>(context, listen: false);
          final categoryProvider =
              Provider.of<CategoryProvider>(context, listen: false);

          await subscriptionProvider.loadSubscriptions(forceRefresh: true);
          await categoryProvider.loadCategories(forceRefresh: true);

          debugLog('FamilyAcademyApp', '✅ Data refreshed on app resume');
        }
      }
    } catch (e) {
      debugLog('FamilyAcademyApp', 'Refresh data error: $e');
    }
  }

  void _monitorRouteChanges() {
    if (!_isRouterReady || !context.mounted) return;

    try {
      final routeState = GoRouterState.of(context);
      final currentUri = routeState.uri.toString();

      if (_currentRoute != currentUri) {
        final previousRoute = _currentRoute;
        _currentRoute = currentUri;
        _lastRouteVisited[currentUri] = DateTime.now();

        debugLog('FamilyAcademyApp',
            '🔄 Route changed from "$previousRoute" to "$_currentRoute"');

        if (_isAppInForeground) {
          ScreenProtectionService.enableOnResume();
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            _refreshDataOnRouteChange(previousRoute, currentUri);
          }
        });
      }
    } catch (e) {}
  }

  void _refreshDataOnRouteChange(String previousRoute, String currentRoute) {
    if (!context.mounted ||
        !_shouldRefreshOnNavigation(previousRoute, currentRoute)) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (context.mounted) {
        try {
          final authProvider =
              Provider.of<AuthProvider>(context, listen: false);
          if (authProvider.isAuthenticated) {
            debugLog('FamilyAcademyApp', '🔄 Refreshing data on route change');

            if (currentRoute == '/' || currentRoute.startsWith('/category/')) {
              final subscriptionProvider =
                  Provider.of<SubscriptionProvider>(context, listen: false);
              final categoryProvider =
                  Provider.of<CategoryProvider>(context, listen: false);

              await subscriptionProvider.loadSubscriptions(forceRefresh: true);
              await categoryProvider.loadCategories(forceRefresh: true);
            }
          }
        } catch (e) {
          debugLog('FamilyAcademyApp', 'Route refresh error: $e');
        }
      }
    });
  }

  bool _shouldRefreshOnNavigation(String fromRoute, String toRoute) {
    const refreshableRoutes = [
      '/',
      '/category/',
      '/course/',
      '/progress',
      '/profile'
    ];

    for (final route in refreshableRoutes) {
      if (toRoute.startsWith(route)) {
        final lastVisited = _lastRouteVisited[toRoute];

        return lastVisited == null ||
            DateTime.now().difference(lastVisited).inSeconds > 30;
      }
    }

    return false;
  }

  void _handleNotificationData(Map<String, dynamic> data) {
    final type = data['type'];
    final notificationData = data['data'];
    final route = data['route'] ?? '/notifications';

    switch (type) {
      case 'payment_verified':
        _handlePaymentVerified(notificationData);
        break;
      case 'payment_rejected':
        _showPaymentRejectedNotification(notificationData);
        break;
      case 'exam_result':
        _showExamResultNotification(notificationData);
        break;
      case 'streak_update':
        _showStreakUpdateNotification(notificationData);
        break;
      case 'system_announcement':
        _showSystemAnnouncement(notificationData);
        break;
      case 'navigate':
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted && _isRouterReady) {
            ScreenProtectionService.enableOnResume();
            GoRouter.of(context).go(route);
          }
        });
        break;
      case 'notification_clicked':
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted && _isRouterReady) {
            context.read<NotificationProvider>().loadNotifications().then((_) {
              ScreenProtectionService.enableOnResume();
              GoRouter.of(context).go(route);
            });
          }
        });
        break;
    }
  }

  void _handlePaymentVerified(Map<String, dynamic> data) {
    widget.notificationService.showLocalNotification(
      title: 'Payment Verified!',
      body: 'Your payment has been verified. Your access is now active.',
      payload: json.encode({
        'type': 'payment_verified_action',
        'action': 'refresh_subscriptions',
        'category_id': data['category_id'],
        'timestamp': DateTime.now().toIso8601String(),
        'click_action': '/notifications',
      }),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        final subscriptionProvider =
            Provider.of<SubscriptionProvider>(context, listen: false);
        final categoryProvider =
            Provider.of<CategoryProvider>(context, listen: false);

        subscriptionProvider.refreshAfterPaymentVerification().then((_) {
          categoryProvider.loadCategories(forceRefresh: true);
        });
      }
    });
  }

  void _showPaymentRejectedNotification(dynamic data) {
    widget.notificationService.showLocalNotification(
      title: 'Payment Rejected',
      body: 'Your payment was rejected. Please contact support.',
    );
  }

  void _showExamResultNotification(dynamic data) {
    widget.notificationService.showLocalNotification(
      title: 'Exam Results Available',
      body: 'Your exam results are ready to view.',
    );
  }

  void _showStreakUpdateNotification(dynamic data) {
    widget.notificationService.showLocalNotification(
      title: 'Streak Update!',
      body: 'You have a ${data['streak_days']} day streak! Keep it up!',
    );
  }

  void _showSystemAnnouncement(dynamic data) {
    widget.notificationService.showLocalNotification(
      title: data['title'] ?? 'System Announcement',
      body: data['message'] ?? 'New system announcement',
    );
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _monitorRouteChanges();
    });

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            return MaterialApp.router(
              title: 'Family Academy',
              theme: themeProvider.lightTheme,
              darkTheme: themeProvider.darkTheme,
              themeMode: themeProvider.themeMode,
              routerConfig: appRouter.router,
              debugShowCheckedModeBanner: false,
              builder: (context, child) {
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaleFactor: ScreenSize.isDesktop(context)
                        ? 1.1
                        : ScreenSize.isTablet(context)
                            ? 1.05
                            : 1.0,
                  ),
                  child: PopScope(
                    canPop: true,
                    onPopInvoked: (didPop) {
                      if (didPop && _isAppInForeground) {
                        ScreenProtectionService.enableOnResume();
                      }
                    },
                    child: child ?? const SizedBox(),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

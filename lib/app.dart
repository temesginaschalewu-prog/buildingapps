import 'dart:async';
import 'dart:convert';

import 'package:familyacademyclient/providers/payment_provider.dart';
import 'package:familyacademyclient/providers/settings_provider.dart';
import 'package:familyacademyclient/providers/user_provider.dart';
import 'package:familyacademyclient/services/connectivity_service.dart';
import 'package:familyacademyclient/services/snackbar_service.dart';
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
  StreamSubscription? _connectivitySubscription;
  bool _mounted = true;
  bool _wasOffline = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
    _startSessionChecker();
    _setupConnectivityListener();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isRouterReady && _mounted && context.mounted) {
      try {
        final routeState = GoRouterState.of(context);
        _currentRoute = routeState.uri.toString();
        _isRouterReady = true;
        debugLog('FamilyAcademyApp', 'Router ready: $_currentRoute');
      } catch (e) {
        debugLog('FamilyAcademyApp', 'Router error: $e');
      }
    }
  }

  @override
  void dispose() {
    _mounted = false;
    WidgetsBinding.instance.removeObserver(this);
    _sessionCheckTimer?.cancel();
    _deviceDeactivatedSubscription?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  void _setupConnectivityListener() {
    final connectivityService = Provider.of<ConnectivityService>(
      context,
      listen: false,
    );

    _connectivitySubscription =
        connectivityService.onConnectivityChanged.listen(
      (isOnline) {
        if (!_mounted || !context.mounted) return;

        if (isOnline && _wasOffline) {
          SnackbarService().showSuccess(
            context,
            'Back online! Refreshing content...',
          );
          _refreshAllData();
        } else if (!isOnline && !_wasOffline) {
          SnackbarService().showOffline(context);
        }

        _wasOffline = !isOnline;
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _isAppInForeground = true;
        ScreenProtectionService.enableOnResume();
        _refreshAllData();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _isAppInForeground = false;
        ScreenProtectionService.disableOnPause();
        break;
    }
  }

  void _startSessionChecker() {
    _sessionCheckTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_mounted && context.mounted) {
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

      widget.notificationService.apiService = widget.apiService;

      if (_mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (_mounted && context.mounted) {
            final authProvider =
                Provider.of<AuthProvider>(context, listen: false);
            _deviceDeactivatedSubscription =
                authProvider.deviceDeactivated.listen((message) {
              if (_mounted && context.mounted) {
                _showDeviceDeactivatedDialog(
                    message ?? 'Device has been deactivated.');
              }
            });
            await authProvider.initialize();
            if (authProvider.isAuthenticated && _mounted && context.mounted) {
              await _initializeAuthenticatedProviders();
            }
          }
        });
      }

      widget.notificationService.notificationStream
          .listen(_handleNotificationData);

      debugLog('FamilyAcademyApp', 'App initialization complete');
    } catch (e) {
      debugLog('FamilyAcademyApp', 'Initialization error: $e');
    }
  }

  void _showDeviceDeactivatedDialog(String message) {
    if (!_mounted || !context.mounted) return;
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
              if (_mounted && context.mounted) {
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
    if (_isInitializing || !_mounted || !context.mounted) return;
    _isInitializing = true;
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
      unawaited(_loadBackgroundProviders());
      unawaited(
          widget.notificationService.sendFcmTokenToBackendIfAuthenticated());
    } catch (e) {
      debugLog('FamilyAcademyApp', 'Provider init error: $e');
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _loadBackgroundProviders() async {
    if (!_mounted || !context.mounted) return;

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final notificationProvider =
          Provider.of<NotificationProvider>(context, listen: false);
      final paymentProvider =
          Provider.of<PaymentProvider>(context, listen: false);
      final settingsProvider =
          Provider.of<SettingsProvider>(context, listen: false);

      await settingsProvider.getAllSettings().catchError((e) {
        debugLog('FamilyAcademyApp', 'Settings error: $e');
        return null;
      });

      await Future.wait([
        userProvider.loadUserProfile().catchError((e) {
          debugLog('FamilyAcademyApp', 'User profile error: $e');
          return null;
        }),
        notificationProvider.loadNotifications().catchError((e) {
          debugLog('FamilyAcademyApp', 'Notifications error: $e');
          return null;
        }),
        paymentProvider.loadPayments().catchError((e) {
          debugLog('FamilyAcademyApp', 'Payments error: $e');
          return null;
        }),
      ]);
    } catch (e) {
      debugLog('FamilyAcademyApp', 'Background providers error: $e');
    }
  }

  Future<void> _refreshAllData() async {
    if (!_isAppInForeground || !_mounted || !context.mounted) return;

    final connectivityService = Provider.of<ConnectivityService>(
      context,
      listen: false,
    );
    if (!connectivityService.isOnline) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isAuthenticated) {
      final subscriptionProvider =
          Provider.of<SubscriptionProvider>(context, listen: false);
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);
      unawaited(subscriptionProvider.loadSubscriptions(forceRefresh: true));
      unawaited(categoryProvider.loadCategories(forceRefresh: true));
    }
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
      case 'exam_result':
      case 'streak_update':
      case 'system_announcement':
        unawaited(widget.notificationService.showLocalNotification(
          title: data['title'] ?? 'Notification',
          body: data['message'] ?? '',
        ));
        break;
      case 'navigate':
      case 'notification_clicked':
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleNavigation(route);
        });
        break;
    }
  }

  void _handleNavigation(String route) {
    if (!_mounted || !context.mounted || !_isRouterReady) return;

    ScreenProtectionService.enableOnResume();

    final currentContext = context;
    final notificationProvider = currentContext.read<NotificationProvider>();

    notificationProvider.loadNotifications().then((_) {
      if (!_mounted || !currentContext.mounted) return;

      final currentRoute = GoRouterState.of(currentContext).uri.toString();
      if (currentRoute == route) return;

      if (currentRoute.startsWith('/chatbot') ||
          currentRoute.startsWith('/progress')) {
        GoRouter.of(currentContext).push(route);
      } else {
        GoRouter.of(currentContext).go(route);
      }
    });
  }

  void _handlePaymentVerified(Map<String, dynamic> data) {
    unawaited(widget.notificationService.showLocalNotification(
      title: 'Payment Verified!',
      body: 'Your payment has been verified. Access is now active.',
      payload: json.encode({
        'type': 'payment_verified_action',
        'action': 'refresh_subscriptions',
        'category_id': data['category_id'],
        'click_action': '/notifications',
      }),
    ));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handlePaymentRefresh(data);
    });
  }

  void _handlePaymentRefresh(Map<String, dynamic> data) {
    if (!_mounted || !context.mounted) return;

    final subscriptionProvider =
        Provider.of<SubscriptionProvider>(context, listen: false);
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);

    subscriptionProvider.refreshAfterPaymentVerification().then((_) {
      if (_mounted && context.mounted) {
        categoryProvider.loadCategories(forceRefresh: true);
      }
    });
  }

  void _monitorRouteChanges() {
    if (!_isRouterReady || !_mounted || !context.mounted) return;
    try {
      final routeState = GoRouterState.of(context);
      final currentUri = routeState.uri.toString();
      if (_currentRoute != currentUri) {
        _currentRoute = currentUri;
        _lastRouteVisited[currentUri] = DateTime.now();
        if (_isAppInForeground) ScreenProtectionService.enableOnResume();
      }
    } catch (e) {
      debugLog('FamilyAcademyApp', 'Route monitor error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _monitorRouteChanges());

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) => Consumer<AuthProvider>(
        builder: (context, authProvider, child) => MaterialApp.router(
          title: 'Family Academy',
          theme: themeProvider.lightTheme,
          darkTheme: themeProvider.darkTheme,
          themeMode: themeProvider.themeMode,
          routerConfig: appRouter.router,
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(ScreenSize.isDesktop(context)
                    ? 1.1
                    : ScreenSize.isTablet(context)
                        ? 1.05
                        : 1.0),
              ),
              child: PopScope(
                onPopInvokedWithResult: (didPop, result) {
                  if (didPop && _isAppInForeground) {
                    ScreenProtectionService.enableOnResume();
                  }
                },
                child: child ?? const SizedBox(),
              ),
            );
          },
        ),
      ),
    );
  }
}

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

  FamilyAcademyApp({
    super.key,
    required this.apiService,
    required this.notificationService,
  }) {
    debugLog('FamilyAcademyApp', 'Constructor called');
  }

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
  Timer? _syncTimer;
  StreamSubscription? _deviceDeactivatedSubscription;
  StreamSubscription? _connectivitySubscription;
  bool _mounted = true;
  bool _wasOffline = false;

  @override
  void initState() {
    super.initState();
    debugLog('FamilyAcademyApp', 'initState called');
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
    _startSessionChecker();
    _setupConnectivityListener();
    _startPeriodicSync();
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
    _syncTimer?.cancel();
    _deviceDeactivatedSubscription?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  void _setupConnectivityListener() {
    final BuildContext currentContext = context;
    final bool wasMounted = _mounted;

    final connectivityService = Provider.of<ConnectivityService>(
      currentContext,
      listen: false,
    );

    _connectivitySubscription =
        connectivityService.onConnectivityChanged.listen(
      (isOnline) {
        if (!wasMounted || !currentContext.mounted) return;

        if (isOnline && _wasOffline) {
          SnackbarService().showSuccess(
            currentContext,
            'Back online! Syncing your changes...',
          );
          _syncPendingActions();
          _refreshAllData();
        } else if (!isOnline && !_wasOffline) {
          final pendingCount = connectivityService.pendingActionsCount;
          if (pendingCount > 0) {
            SnackbarService().showInfo(
              currentContext,
              'You are offline. $pendingCount change${pendingCount > 1 ? 's' : ''} queued.',
            );
          } else {
            SnackbarService().showOffline(currentContext);
          }
        }

        _wasOffline = !isOnline;
      },
    );
  }

  void _startPeriodicSync() {
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_mounted && context.mounted) {
        final connectivity = Provider.of<ConnectivityService>(
          context,
          listen: false,
        );
        if (connectivity.isOnline && connectivity.pendingActionsCount > 0) {
          _syncPendingActions();
        }
      }
    });
  }

  Future<void> _syncPendingActions() async {
    if (!_mounted || !context.mounted || !_isRouterReady) return;

    final BuildContext currentContext = context;
    final connectivity = Provider.of<ConnectivityService>(
      currentContext,
      listen: false,
    );

    if (!connectivity.isOnline) return;

    final apiService = Provider.of<ApiService>(currentContext, listen: false);

    await connectivity.processQueueWithApi(apiService, onComplete: () {
      if (_mounted && currentContext.mounted && _isRouterReady) {
        final remaining = connectivity.pendingActionsCount;
        if (remaining == 0) {
          SnackbarService().showSyncComplete(currentContext);
        } else {
          SnackbarService().showInfo(
            currentContext,
            '$remaining change${remaining > 1 ? 's' : ''} remaining to sync',
          );
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Don't try to sync if we're not fully initialized
    if (!_isRouterReady || !_mounted || !context.mounted) {
      // Just handle screen protection without syncing
      switch (state) {
        case AppLifecycleState.resumed:
          _isAppInForeground = true;
          ScreenProtectionService.enableOnResume();
          break;
        case AppLifecycleState.paused:
        case AppLifecycleState.inactive:
        case AppLifecycleState.detached:
        case AppLifecycleState.hidden:
          _isAppInForeground = false;
          ScreenProtectionService.disableOnPause();
          break;
      }
      return;
    }

    // Full handling when ready
    switch (state) {
      case AppLifecycleState.resumed:
        _isAppInForeground = true;
        ScreenProtectionService.enableOnResume();
        _refreshAllData();
        _syncPendingActions();
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
      if (!mounted) return;

      await ScreenProtectionService.disableSplitScreen();
      if (!mounted) return;

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

            // Initialize auth provider
            await authProvider.initialize();
            if (!mounted) return;

            // Only initialize authenticated providers if we're actually authenticated
            if (authProvider.isAuthenticated && _mounted && context.mounted) {
              // Small delay to ensure everything is settled
              await Future.delayed(const Duration(milliseconds: 500));
              if (!mounted) return;

              await _initializeAuthenticatedProviders();
              if (!mounted) return;
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

    final BuildContext currentContext = context;

    try {
      debugLog('FamilyAcademyApp',
          'Starting authenticated providers initialization');

      final subscriptionProvider =
          Provider.of<SubscriptionProvider>(currentContext, listen: false);
      final categoryProvider =
          Provider.of<CategoryProvider>(currentContext, listen: false);
      final settingsProvider =
          Provider.of<SettingsProvider>(currentContext, listen: false);

      // Load settings first (they don't depend on auth)
      await settingsProvider.getAllSettings().catchError((e) {
        debugLog('FamilyAcademyApp', 'Settings error (non-critical): $e');
        return null;
      });
      if (!mounted) return;

      // Load subscriptions
      await subscriptionProvider.loadSubscriptions().catchError((e) {
        debugLog('FamilyAcademyApp', 'Subscriptions error (non-critical): $e');
        return null;
      });
      if (!mounted) return;

      // Load categories
      await categoryProvider
          .loadCategoriesWithSubscriptionCheck()
          .catchError((e) {
        debugLog('FamilyAcademyApp', 'Categories error (non-critical): $e');
        return null;
      });
      if (!mounted) return;

      // Load background providers (don't await - let them run in background)
      unawaited(_loadBackgroundProviders().catchError((e) {
        debugLog('FamilyAcademyApp',
            'Background providers error (non-critical): $e');
      }));

      unawaited(widget.notificationService
          .sendFcmTokenToBackendIfAuthenticated()
          .catchError((e) {
        debugLog('FamilyAcademyApp', 'FCM token error (non-critical): $e');
      }));

      debugLog('FamilyAcademyApp',
          'Authenticated providers initialization completed');
    } catch (e) {
      debugLog('FamilyAcademyApp', 'Provider init error: $e');
      // Don't logout on provider errors - just log them
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _loadBackgroundProviders() async {
    if (!_mounted || !context.mounted) return;

    final BuildContext currentContext = context;

    try {
      final userProvider =
          Provider.of<UserProvider>(currentContext, listen: false);
      final notificationProvider =
          Provider.of<NotificationProvider>(currentContext, listen: false);
      final paymentProvider =
          Provider.of<PaymentProvider>(currentContext, listen: false);
      final settingsProvider =
          Provider.of<SettingsProvider>(currentContext, listen: false);

      // Load all background data with individual error handling
      await Future.wait([
        userProvider.loadUserProfile().catchError((e) {
          debugLog('FamilyAcademyApp', 'User profile error (non-critical): $e');
          return null;
        }),
        notificationProvider.loadNotifications().catchError((e) {
          debugLog(
              'FamilyAcademyApp', 'Notifications error (non-critical): $e');
          return null;
        }),
        paymentProvider.loadPayments().catchError((e) {
          debugLog('FamilyAcademyApp', 'Payments error (non-critical): $e');
          return null;
        }),
      ]).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugLog('FamilyAcademyApp',
              'Background providers timeout - continuing anyway');
          return [];
        },
      );
    } catch (e) {
      debugLog('FamilyAcademyApp', 'Background providers error (ignored): $e');
      // NEVER logout from background providers
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
      unawaited(subscriptionProvider
          .loadSubscriptions(forceRefresh: true)
          .catchError(
              (e) => debugLog('FamilyAcademyApp', 'Refresh error: $e')));
      unawaited(categoryProvider.loadCategories(forceRefresh: true).catchError(
          (e) => debugLog('FamilyAcademyApp', 'Refresh error: $e')));
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

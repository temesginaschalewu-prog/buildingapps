import 'dart:async';
import 'dart:convert';

import 'package:familyacademyclient/services/connectivity_service.dart';
import 'package:familyacademyclient/services/offline_queue_manager.dart'
    as queue;
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
import 'utils/app_enums.dart';
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
  bool _wasOffline = false;
  Timer? _sessionCheckTimer;
  Timer? _syncTimer;
  StreamSubscription? _deviceDeactivatedSubscription;
  StreamSubscription? _connectivitySubscription;
  bool _appInitialized = false;
  bool _overlayReady = false;
  final List<Map<String, dynamic>> _pendingSnackbars = [];
  DateTime? _lastDataRefreshAt;
  static const Duration _minRefreshInterval = Duration(minutes: 2);

  @override
  void initState() {
    super.initState();
    debugLog('FamilyAcademyApp', 'Initializing app');
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _overlayReady = true);
        SnackbarService().initializeWithContext(context);

        for (final snackbar in _pendingSnackbars) {
          SnackbarService().show(
            context: context,
            message: snackbar['message'],
            type: snackbar['type'],
          );
        }
        _pendingSnackbars.clear();

        _initializeApp();
      }
    });

    _startSessionChecker();
    _setupConnectivityListener();
    _startPeriodicSync();
    _setupOfflineQueueListener();
  }

  void _setupOfflineQueueListener() {
    final queueManager =
        Provider.of<queue.OfflineQueueManager>(context, listen: false);

    queueManager.queueStream.listen((items) {
      if (!mounted || !_overlayReady) return;

      final pendingCount = items
          .where((item) => item.status == queue.QueueStatus.pending)
          .length;

      if (pendingCount > 0 && _isAppInForeground) {
        _showSafeSnackbar(
          '📦 $pendingCount item${pendingCount > 1 ? 's' : ''} pending sync',
          SnackbarType.info,
        );
      }
    });
  }

  void _showSafeSnackbar(String message, SnackbarType type) {
    if (!_overlayReady || !mounted) {
      _pendingSnackbars.add({'message': message, 'type': type});
      return;
    }

    try {
      SnackbarService().show(
        context: context,
        message: message,
        type: type,
      );
    } catch (e) {
      _pendingSnackbars.add({'message': message, 'type': type});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionCheckTimer?.cancel();
    _syncTimer?.cancel();
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
        connectivityService.onConnectivityChanged.listen((isOnline) async {
      if (!mounted) return;

      if (isOnline && _wasOffline) {
        _showSafeSnackbar(
          'Back online! Syncing your changes...',
          SnackbarType.success,
        );

        await widget.notificationService.syncPendingFcmToken();
        await widget.notificationService.sendFcmTokenToBackendIfAuthenticated();

        final queueManager =
            Provider.of<queue.OfflineQueueManager>(context, listen: false);
        await queueManager.processQueue();

        await _syncPendingActions();
        await _refreshAllData();
      } else if (!isOnline && !_wasOffline) {
        final queueManager =
            Provider.of<queue.OfflineQueueManager>(context, listen: false);
        final pendingCount = queueManager.pendingCount;

        if (pendingCount > 0) {
          _showSafeSnackbar(
            'You are offline. $pendingCount change${pendingCount > 1 ? 's' : ''} queued.',
            SnackbarType.offline,
          );
        } else {
          _showSafeSnackbar(
            'You are offline. Showing cached content.',
            SnackbarType.offline,
          );
        }
      }

      _wasOffline = !isOnline;
    });
  }

  void _startPeriodicSync() {
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (mounted && _overlayReady) {
        final connectivity = Provider.of<ConnectivityService>(
          context,
          listen: false,
        );
        if (connectivity.isOnline) {
          _syncPendingActions();
        }
      }
    });
  }

  Future<void> _syncPendingActions() async {
    if (!mounted || !_overlayReady) return;

    final connectivity = Provider.of<ConnectivityService>(
      context,
      listen: false,
    );

    if (!connectivity.isOnline) return;

    final queueManager =
        Provider.of<queue.OfflineQueueManager>(context, listen: false);

    await queueManager.processQueue();

    final remaining = queueManager.pendingItems.length;
    if (remaining == 0) {
      _showSafeSnackbar('Sync complete!', SnackbarType.syncComplete);
    } else {
      _showSafeSnackbar(
        '$remaining change${remaining > 1 ? 's' : ''} remaining to sync',
        SnackbarType.info,
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_appInitialized) return;

    switch (state) {
      case AppLifecycleState.resumed:
        _isAppInForeground = true;
        ScreenProtectionService.enableOnResume();
        unawaited(_refreshAllData());
        if (_overlayReady) {
          unawaited(_syncPendingActions());
        }
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
      if (mounted && _appInitialized) {
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

      final subscriptionProvider =
          Provider.of<SubscriptionProvider>(context, listen: false);
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);
      subscriptionProvider.setCategoryProvider(categoryProvider);

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      _deviceDeactivatedSubscription =
          authProvider.deviceDeactivated.listen((message) {
        if (mounted) {
          _showDeviceDeactivatedDialog(
              message ?? 'Device has been deactivated.');
        }
      });
      authProvider.registerOnLoginCallback(() {
        unawaited(widget.notificationService.syncPendingFcmToken());
        unawaited(widget.notificationService.sendFcmTokenToBackendIfAuthenticated());
      });

      await authProvider.initialize();

      widget.notificationService.notificationStream
          .listen(_handleNotificationData);

      if (authProvider.isAuthenticated) {
        await widget.notificationService.syncPendingFcmToken();
        await widget.notificationService.sendFcmTokenToBackendIfAuthenticated();
      }

      setState(() => _appInitialized = true);
      debugLog('FamilyAcademyApp', 'App initialization complete');
    } catch (e) {
      debugLog('FamilyAcademyApp', 'Initialization error: $e');
      setState(() => _appInitialized = true);
    }
  }

  void _showDeviceDeactivatedDialog(String message) {
    if (!mounted) return;
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
              if (mounted) {
                GoRouter.of(context).go('/auth/login');
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshAllData() async {
    if (!_isAppInForeground || !mounted || !_appInitialized) return;

    final connectivityService = Provider.of<ConnectivityService>(
      context,
      listen: false,
    );
    if (!connectivityService.isOnline) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isAuthenticated) {
      await widget.notificationService.syncPendingFcmToken();
      await widget.notificationService.sendFcmTokenToBackendIfAuthenticated();
      final now = DateTime.now();
      if (_lastDataRefreshAt != null &&
          now.difference(_lastDataRefreshAt!) < _minRefreshInterval) {
        return;
      }
      _lastDataRefreshAt = now;

      final subscriptionProvider =
          Provider.of<SubscriptionProvider>(context, listen: false);
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);
      subscriptionProvider.setCategoryProvider(categoryProvider);

      unawaited(subscriptionProvider.loadSubscriptions().catchError(
          (e) => debugLog('FamilyAcademyApp', 'Refresh error: $e')));
      unawaited(categoryProvider.loadCategories().catchError(
          (e) => debugLog('FamilyAcademyApp', 'Refresh error: $e')));
    }
  }

  void _handleNotificationData(Map<String, dynamic> data) {
    final type = data['type'];
    final route = data['route'] ?? '/notifications';

    switch (type) {
      case 'payment_verified':
        _handlePaymentVerified(data['data']);
        break;
      case 'notification_clicked':
      case 'navigate':
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleNavigation(route);
        });
        break;
      default:
        unawaited(widget.notificationService.showLocalNotification(
          title: data['title'] ?? 'Notification',
          body: data['message'] ?? '',
        ));
        break;
    }
  }

  void _handleNavigation(String route) {
    if (!mounted || !_appInitialized) return;

    ScreenProtectionService.enableOnResume();

    final notificationProvider = context.read<NotificationProvider>();
    notificationProvider.loadNotifications().then((_) {
      if (!mounted) return;

      final currentRoute = GoRouterState.of(context).uri.toString();
      if (currentRoute == route) return;

      GoRouter.of(context).push(route);
    });
  }

  void _handlePaymentVerified(Map<String, dynamic>? data) {
    unawaited(widget.notificationService.showLocalNotification(
      title: 'Payment Verified!',
      body: 'Your payment has been verified. Access is now active.',
      payload: json.encode({
        'type': 'payment_verified_action',
        'action': 'refresh_subscriptions',
        'category_id': data?['category_id'],
        'click_action': '/notifications',
      }),
    ));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_appInitialized) return;

      final subscriptionProvider =
          Provider.of<SubscriptionProvider>(context, listen: false);
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);
      subscriptionProvider.setCategoryProvider(categoryProvider);

      subscriptionProvider.refreshAfterPaymentVerification().then((_) {
        if (mounted) {
          categoryProvider.loadCategories(forceRefresh: true);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
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

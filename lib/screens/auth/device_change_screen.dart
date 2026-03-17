// lib/screens/auth/device_change_screen.dart
// COMPLETE PRODUCTION-READY FILE - REPLACE ENTIRE FILE

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../services/user_session.dart';
import '../../services/connectivity_service.dart';
import '../../services/snackbar_service.dart';
import '../../services/device_service.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_dialog.dart';
import '../../widgets/common/app_shimmer.dart';
import '../../providers/auth_provider.dart';
import '../../providers/device_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/category_provider.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/responsive_values.dart';
import '../../utils/helpers.dart';
import '../../utils/api_response.dart';
import '../../utils/router.dart';

/// PRODUCTION-READY DEVICE CHANGE SCREEN
class DeviceChangeScreen extends StatefulWidget {
  const DeviceChangeScreen({super.key});

  @override
  State<DeviceChangeScreen> createState() => _DeviceChangeScreenState();
}

class _DeviceChangeScreenState extends State<DeviceChangeScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _confirmChange = false;
  late Map<String, dynamic> _args = {};
  bool _hasArgs = false;
  String? _newDeviceId;
  String? _error;
  bool _isInitializing = true;
  bool _isOffline = false;
  int _pendingCount = 0;

  late String _username;
  late String _deviceId;
  late String _currentDeviceId;
  late int _maxChanges;
  late bool _canChangeDevice;

  late AnimationController _pulseAnimationController;
  StreamSubscription? _connectivitySubscription;

  @override
  void initState() {
    super.initState();

    _pulseAnimationController =
        AnimationController(vsync: this, duration: 1.seconds)
          ..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _pulseAnimationController.dispose();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    await _checkConnectivity();
    _setupConnectivityListener();
    _checkPendingCount();
    _initializeArgs();
  }

  void _setupConnectivityListener() {
    final connectivityService = context.read<ConnectivityService>();
    _connectivitySubscription =
        connectivityService.onConnectivityChanged.listen((isOnline) {
      if (mounted) {
        setState(() {
          _isOffline = !isOnline;
          _pendingCount = connectivityService.pendingActionsCount;
        });
      }
    });
  }

  Future<void> _checkConnectivity() async {
    final connectivityService = context.read<ConnectivityService>();
    await connectivityService.checkConnectivity();
    if (mounted) {
      setState(() {
        _isOffline = !connectivityService.isOnline;
        _pendingCount = connectivityService.pendingActionsCount;
      });
    }
  }

  Future<void> _checkPendingCount() async {
    final connectivity = ConnectivityService();
    if (mounted) {
      setState(() => _pendingCount = connectivity.pendingActionsCount);
    }
  }

  Future<void> _saveDeviceChangeToCache() async {
    try {
      final deviceService = context.read<DeviceService>();
      final userId = await UserSession().getCurrentUserId();
      if (userId != null && mounted) {
        // ✅ FIXED: changed _mounted to mounted
        deviceService.saveCacheItem(
          'device_change_$userId',
          _args,
          ttl: const Duration(hours: 1),
          isUserSpecific: true,
        );
      }
    } catch (e) {
      debugLog('DeviceChangeScreen', 'Error caching device change: $e');
    }
  }

  Future<void> _loadDeviceChangeFromCache() async {
    try {
      final deviceService = context.read<DeviceService>();
      final userId = await UserSession().getCurrentUserId();
      if (userId != null && mounted) {
        // ✅ FIXED: changed _mounted to mounted
        final cached = await deviceService.getCacheItem<Map<String, dynamic>>(
          'device_change_$userId',
          isUserSpecific: true,
        );
        if (cached != null && cached.isNotEmpty && mounted) {
          // ✅ FIXED: changed _mounted to mounted
          setState(() {
            _args = cached;
            _hasArgs = true;
            _extractArgsFromMap(_args);
          });
        }
      }
    } catch (e) {
      debugLog('DeviceChangeScreen', 'Error loading cached device change: $e');
    }
  }

  void _extractArgsFromMap(Map<String, dynamic> args) {
    // Try multiple possible paths to find the username
    _username = args['username']?.toString() ?? '';

    if (_username.isEmpty && args['data'] != null) {
      final data = args['data'] as Map<String, dynamic>?;
      _username = data?['username']?.toString() ?? '';
    }

    if (_username.isEmpty && args['user'] != null) {
      final user = args['user'] as Map<String, dynamic>?;
      _username = user?['username']?.toString() ?? '';
    }

    // Try to get from auth provider as last resort
    if (_username.isEmpty) {
      try {
        final authProvider = context.read<AuthProvider>();
        final currentUser = authProvider.currentUser;
        if (currentUser != null) {
          _username = currentUser.username;
          debugLog('DeviceChangeScreen',
              'Got username from AuthProvider: $_username');
        }
      } catch (e) {}
    }

    _currentDeviceId = args['currentDeviceId']?.toString() ??
        args['data']?['currentDeviceId']?.toString() ??
        'Unknown';

    _deviceId = args['newDeviceId']?.toString() ??
        args['deviceId']?.toString() ??
        args['data']?['newDeviceId']?.toString() ??
        '';

    _maxChanges =
        args['maxChanges'] as int? ?? args['data']?['maxChanges'] as int? ?? 2;

    _canChangeDevice = args['canChangeDevice'] as bool? ??
        args['data']?['canChangeDevice'] as bool? ??
        true;

    final password = args['password']?.toString() ?? '';

    debugLog('DeviceChangeScreen', 'Extracted username: "$_username"');
    debugLog('DeviceChangeScreen', 'Device ID: $_deviceId');
    debugLog('DeviceChangeScreen', 'Current Device: $_currentDeviceId');

    if (password.isNotEmpty && mounted) {
      _passwordController.text =
          password; // ✅ FIXED: changed _mounted to mounted
    }
  }

  void _initializeArgs() {
    Map<String, dynamic>? routeArgs;

    // Try to get args from GoRouter
    try {
      final goRouter = GoRouter.of(context);
      final state = goRouter.routerDelegate.currentConfiguration;
      if (state.extra != null && state.extra is Map<String, dynamic>) {
        routeArgs = state.extra as Map<String, dynamic>;
        debugLog('DeviceChangeScreen', 'Got args from GoRouter');
      }
    } catch (e) {}

    // Try to get args from ModalRoute
    if (routeArgs == null || routeArgs.isEmpty) {
      try {
        final modalRoute = ModalRoute.of(context);
        if (modalRoute?.settings.arguments != null) {
          final args = modalRoute!.settings.arguments;
          if (args is Map<String, dynamic>) {
            routeArgs = args;
            debugLog('DeviceChangeScreen', 'Got args from ModalRoute');
          }
        }
      } catch (e) {}
    }

    // Try to get args from AuthProvider last login result
    if (routeArgs == null || routeArgs.isEmpty) {
      try {
        final authProvider = context.read<AuthProvider>();
        final lastLoginResult = authProvider.lastLoginResult;
        if (lastLoginResult != null) {
          routeArgs = lastLoginResult;
          debugLog('DeviceChangeScreen',
              'Got args from AuthProvider lastLoginResult');
        }
      } catch (e) {}
    }

    if (routeArgs != null && routeArgs.isNotEmpty && mounted) {
      // ✅ FIXED: changed _mounted to mounted
      _args = routeArgs;
      _hasArgs = true;
      _extractArgsFromMap(_args);

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _saveDeviceChangeToCache();
      });

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _initializeDeviceInfo();
        if (mounted) {
          setState(() =>
              _isInitializing = false); // ✅ FIXED: changed _mounted to mounted
        }
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _loadDeviceChangeFromCache();
        if (_hasArgs && mounted) {
          // ✅ FIXED: changed _mounted to mounted
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await _initializeDeviceInfo();
            if (mounted) {
              setState(() => _isInitializing =
                  false); // ✅ FIXED: changed _mounted to mounted
            }
          });
        } else {
          if (mounted) {
            // ✅ FIXED: changed _mounted to mounted
            debugLog('DeviceChangeScreen', 'No args found anywhere!');

            // Try to get username from auth provider as last resort
            try {
              final authProvider = context.read<AuthProvider>();
              final currentUser = authProvider.currentUser;
              if (currentUser != null && mounted) {
                // ✅ FIXED: changed _mounted to mounted
                debugLog('DeviceChangeScreen',
                    'Using current user as fallback: ${currentUser.username}');
                setState(() {
                  _username = currentUser.username;
                  _hasArgs = true;
                  _isInitializing = false;
                });
                return;
              }
            } catch (e) {}

            if (mounted) {
              // ✅ FIXED: changed _mounted to mounted
              SnackbarService()
                  .showError(context, 'Invalid device change request');
              context.go('/auth/login');
            }
          }
        }
      });
    }
  }

  Future<void> _initializeDeviceInfo() async {
    try {
      final deviceService = context.read<DeviceService>();
      await deviceService.init();
      final deviceId = await deviceService.getDeviceId();
      if (mounted) {
        setState(() =>
            _newDeviceId = deviceId); // ✅ FIXED: changed _mounted to mounted
      }
    } catch (e) {
      debugLog('DeviceChangeScreen', 'Error initializing device: $e');
      if (mounted) {
        // ✅ FIXED: changed _mounted to mounted
        // Use fallback device ID
        setState(() {
          _newDeviceId = 'fallback_${DateTime.now().millisecondsSinceEpoch}';
        });
      }
    }
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required to confirm device change';
    }
    return null;
  }

  Future<void> _approveDeviceChange() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_confirmChange) {
      SnackbarService().showError(context, 'Please confirm the device change');
      return;
    }
    if (!_canChangeDevice) {
      SnackbarService().showError(context,
          'You have reached the maximum device changes ($_maxChanges per month)');
      return;
    }

    final connectivityService = context.read<ConnectivityService>();
    if (!connectivityService.isOnline) {
      SnackbarService().showOffline(context, action: 'change device');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final authProvider = context.read<AuthProvider>();
    final subscriptionProvider = context.read<SubscriptionProvider>();
    final categoryProvider = context.read<CategoryProvider>();
    final deviceProvider = context.read<DeviceProvider>();

    final password = _passwordController.text;

    try {
      // CRITICAL FIX: Ensure username is not empty
      if (_username.isEmpty) {
        // Try to get username from auth provider
        final currentUser = authProvider.currentUser;
        if (currentUser != null) {
          _username = currentUser.username;
          debugLog('DeviceChangeScreen',
              'Got username from currentUser: $_username');
        } else {
          // Try to get from storage
          final userId = await UserSession().getCurrentUserId();
          if (userId != null) {
            debugLog(
                'DeviceChangeScreen', 'Have userId but no username: $userId');
          }

          throw ApiError(message: 'Username not found. Please login again.');
        }
      }

      debugLog('DeviceChangeScreen',
          'Approving device change for username: "$_username"');
      debugLog('DeviceChangeScreen', 'Device ID: ${_newDeviceId ?? _deviceId}');

      // Use AuthProvider instead of direct API call
      final approveResponse = await authProvider.approveDeviceChange(
        username: _username,
        password: password,
        deviceId: _newDeviceId ?? _deviceId,
      );

      if (!approveResponse['success']) {
        throw ApiError(message: approveResponse['message']);
      }

      await Future.delayed(const Duration(seconds: 1));

      final loginResult = await authProvider.login(
        _username,
        password,
        _newDeviceId ?? _deviceId,
        null,
      );

      if (loginResult['success'] == true) {
        await subscriptionProvider.loadSubscriptions(forceRefresh: true);
        await categoryProvider.loadCategories(forceRefresh: true);
        await deviceProvider.initialize();

        final userId = await UserSession().getCurrentUserId();
        if (userId != null && mounted) {
          // ✅ FIXED: changed _mounted to mounted
          await deviceProvider.deviceService
              .removeCacheItem('device_change_$userId', isUserSpecific: true);
        }

        if (mounted) {
          // ✅ FIXED: changed _mounted to mounted
          SnackbarService()
              .showSuccess(context, 'Device change approved successfully!');

          // Navigation with proper delay and flags
          await Future.delayed(const Duration(milliseconds: 300));

          if (!mounted) return; // ✅ FIXED: changed _mounted to mounted

          if (authProvider.currentUser?.schoolId == null) {
            appRouter.setNavigatingToSchoolSelection(true);
            context.go('/school-selection');
          } else {
            appRouter.setNavigatingToHome(true);
            context.go('/');
          }
        }
      } else {
        if (mounted) {
          // ✅ FIXED: changed _mounted to mounted
          setState(() => _error =
              loginResult['message'] ?? 'Login after device change failed');
          SnackbarService().showError(context, _error!);
        }
      }
    } catch (e) {
      String errorMessage;
      if (e is ApiError) {
        if (e.action == 'max_device_changes_reached') {
          errorMessage =
              'Maximum device changes (2 per month) reached. Please contact support.';
        } else if (e.statusCode == 403) {
          errorMessage = 'Access denied. Please check your password.';
        } else {
          errorMessage = e.message;
        }
      } else {
        errorMessage = 'Device change failed. Please try again.';
      }

      if (mounted) {
        // ✅ FIXED: changed _mounted to mounted
        setState(() => _error = errorMessage);
        SnackbarService().showError(context, errorMessage);
      }
    } finally {
      if (mounted) {
        setState(
            () => _isLoading = false); // ✅ FIXED: changed _mounted to mounted
      }
    }
  }

  void _cancelDeviceChange() {
    AppDialog.confirm(
      context: context,
      title: 'Cancel Device Change',
      message:
          'Are you sure you want to cancel? You will not be able to login on this device.',
      confirmText: 'Yes, Cancel',
      cancelText: 'No, Stay',
    ).then((confirmed) {
      if (confirmed == true && mounted) {
        // ✅ FIXED: changed _mounted to mounted
        context.read<AuthProvider>().clearDeviceChangeRequirement();
        context.go('/auth/login');
      }
    });
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: ResponsiveValues.spacingXXXL(context) * 3,
          child: Text(
            '$label:',
            style: AppTextStyles.labelMedium(context)
                .copyWith(color: AppColors.getTextSecondary(context)),
          ),
        ),
        Expanded(
          child: AppCard.glass(
            child: Container(
              padding: EdgeInsets.all(ResponsiveValues.spacingS(context)),
              child: Text(
                value.isNotEmpty
                    ? value.substring(
                            0, value.length > 30 ? 30 : value.length) +
                        (value.length > 30 ? '...' : '')
                    : 'Not available',
                style: AppTextStyles.bodySmall(context).copyWith(
                  fontFamily: Platform.isIOS ? 'Courier' : 'monospace',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWarningBanner() {
    return AppCard.glass(
      child: Padding(
        padding: EdgeInsets.all(ResponsiveValues.spacingXL(context)),
        child: Row(
          children: [
            AnimatedBuilder(
              animation: _pulseAnimationController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1 + _pulseAnimationController.value * 0.1,
                  child: Container(
                    padding: EdgeInsets.all(ResponsiveValues.spacingM(context)),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.telegramYellow.withValues(alpha: 0.2),
                          AppColors.telegramYellow.withValues(alpha: 0.1)
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.warning_rounded,
                      size: ResponsiveValues.iconSizeXL(context),
                      color: AppColors.telegramYellow,
                    ),
                  ),
                );
              },
            ),
            SizedBox(width: ResponsiveValues.spacingXL(context)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'New Device Detected',
                    style: AppTextStyles.headlineSmall(context).copyWith(
                      color: AppColors.telegramYellow,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: ResponsiveValues.spacingS(context)),
                  Text(
                    'You are logging in from a new device. Your old device will be blocked after this change.',
                    style: AppTextStyles.bodyLarge(context)
                        .copyWith(color: AppColors.telegramYellow),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceInfoCard() {
    return AppCard.glass(
      child: Padding(
        padding: EdgeInsets.all(ResponsiveValues.spacingL(context)),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: ResponsiveValues.iconSizeXL(context),
                  height: ResponsiveValues.iconSizeXL(context),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.telegramBlue.withValues(alpha: 0.2),
                        AppColors.telegramPurple.withValues(alpha: 0.1)
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.devices_rounded,
                      size: ResponsiveValues.iconSizeS(context),
                      color: AppColors.telegramBlue),
                ),
                SizedBox(width: ResponsiveValues.spacingM(context)),
                Text(
                  'Device Information',
                  style: AppTextStyles.titleMedium(context)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            SizedBox(height: ResponsiveValues.spacingL(context)),
            _buildInfoRow('Username', _username),
            SizedBox(height: ResponsiveValues.spacingM(context)),
            _buildInfoRow('Current Device', _currentDeviceId),
            SizedBox(height: ResponsiveValues.spacingM(context)),
            _buildInfoRow('New Device', _newDeviceId ?? _deviceId),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmationCard() {
    return AppCard.glass(
      child: Padding(
        padding: ResponsiveValues.cardPadding(context),
        child: Row(
          children: [
            SizedBox(
              width: ResponsiveValues.iconSizeM(context),
              height: ResponsiveValues.iconSizeM(context),
              child: Checkbox(
                value: _confirmChange,
                onChanged: (value) =>
                    mounted // ✅ FIXED: changed _mounted to mounted
                        ? setState(() => _confirmChange = value ?? false)
                        : null,
                activeColor: AppColors.telegramBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                      ResponsiveValues.radiusSmall(context)),
                ),
              ),
            ),
            SizedBox(width: ResponsiveValues.spacingM(context)),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: AppTextStyles.bodyMedium(context),
                  children: const [
                    TextSpan(text: 'I understand that: '),
                    TextSpan(
                        text: 'my old device will be blocked, ',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    TextSpan(text: 'and I can only change devices '),
                    TextSpan(
                        text: '2 times per month.',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: AppButton.outline(
            label: 'Cancel',
            onPressed: _isLoading ? null : _cancelDeviceChange,
            expanded: true,
          ),
        ),
        SizedBox(width: ResponsiveValues.spacingM(context)),
        Expanded(
          child: _canChangeDevice
              ? AppButton.primary(
                  label: _isLoading ? 'Approving...' : 'Approve',
                  onPressed: _isLoading || !_confirmChange || _isOffline
                      ? null
                      : _approveDeviceChange,
                  isLoading: _isLoading,
                  expanded: true,
                )
              : const AppButton.danger(label: 'Cannot Change', expanded: true),
        ),
      ],
    );
  }

  Widget _buildNote() {
    return AppCard.glass(
      child: Padding(
        padding: EdgeInsets.all(ResponsiveValues.spacingM(context)),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded,
                size: ResponsiveValues.iconSizeS(context),
                color: AppColors.getTextSecondary(context)),
            SizedBox(width: ResponsiveValues.spacingM(context)),
            Expanded(
              child: Text(
                'Device changes are limited to 2 per month for security reasons.',
                style: AppTextStyles.bodySmall(context)
                    .copyWith(fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. OFFLINE STATE
    if (_isOffline) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          title:
              Text('Device Change', style: AppTextStyles.appBarTitle(context)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded,
                color: AppColors.getTextPrimary(context)),
            onPressed: () => context.go('/auth/login'),
          ),
        ),
        body: AppEmptyState.offline(
          message: 'You are offline. Please connect to complete device change.',
          onRetry: () {
            setState(() => _isOffline = false);
            _checkConnectivity();
          },
          pendingCount: _pendingCount,
        ),
      );
    }

    // 2. INITIALIZING STATE
    if (_isInitializing) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          title:
              Text('Device Change', style: AppTextStyles.appBarTitle(context)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded,
                color: AppColors.getTextPrimary(context)),
            onPressed: () => context.go('/auth/login'),
          ),
        ),
        body: Center(
          child: AppCard.glass(
            child: Padding(
              padding: ResponsiveValues.dialogPadding(context),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppShimmer(type: ShimmerType.circle),
                  const SizedBox(height: 16),
                  Text(
                    'Initializing device information...',
                    style: AppTextStyles.bodyMedium(context)
                        .copyWith(color: AppColors.getTextSecondary(context)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // 3. NO ARGS STATE
    if (!_hasArgs && _username.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          title:
              Text('Device Change', style: AppTextStyles.appBarTitle(context)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded,
                color: AppColors.getTextPrimary(context)),
            onPressed: () => context.go('/auth/login'),
          ),
        ),
        body: AppEmptyState.error(
          title: 'Invalid Request',
          message: 'No device change data provided.',
          onRetry: () => context.go('/auth/login'),
        ),
      );
    }

    // 4. MAIN CONTENT
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Text('Device Change', style: AppTextStyles.appBarTitle(context)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: ResponsiveValues.screenPadding(context),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildWarningBanner(),
                SizedBox(height: ResponsiveValues.spacingXL(context)),
                _buildDeviceInfoCard(),
                SizedBox(height: ResponsiveValues.spacingL(context)),
                AppCard.glass(
                  child: Padding(
                    padding: ResponsiveValues.cardPadding(context),
                    child: AppTextField.password(
                      controller: _passwordController,
                      label: 'Verify Password',
                      hint: 'Enter your password to confirm device change',
                      validator: _validatePassword,
                      requiresOnline: true,
                    ),
                  ),
                ),
                SizedBox(height: ResponsiveValues.spacingL(context)),
                _buildConfirmationCard(),
                SizedBox(height: ResponsiveValues.spacingXXL(context)),
                _buildActionButtons(),
                SizedBox(height: ResponsiveValues.spacingL(context)),
                _buildNote(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

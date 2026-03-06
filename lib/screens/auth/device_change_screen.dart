import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
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
import '../../themes/app_themes.dart';
import '../../utils/responsive.dart';
import '../../utils/responsive_values.dart';
import '../../utils/helpers.dart';
import '../../utils/api_response.dart';
import '../../utils/router.dart';
import '../../utils/app_enums.dart';
import '../../widgets/common/responsive_widgets.dart';

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
  bool _mounted = true;
  bool _isOffline = false;

  late String _username;
  late String _deviceId;
  late String _currentDeviceId;
  late int _changeCount;
  late int _maxChanges;
  late int _remainingChanges;
  late bool _canChangeDevice;

  late AnimationController _pulseAnimationController;

  @override
  void initState() {
    super.initState();

    _pulseAnimationController =
        AnimationController(vsync: this, duration: 1.seconds)
          ..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_mounted) _checkConnectivity();
      if (_mounted) _initializeArgs();
    });
  }

  @override
  void dispose() {
    _mounted = false;
    _passwordController.dispose();
    _pulseAnimationController.dispose();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    final connectivityService = context.read<ConnectivityService>();
    setState(() => _isOffline = !connectivityService.isOnline);
  }

  Future<void> _saveDeviceChangeToCache() async {
    try {
      final deviceService = context.read<DeviceService>();
      final userId = await UserSession().getCurrentUserId();
      if (userId != null) {
        await deviceService.saveCacheItem(
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
      if (userId != null) {
        final cached = await deviceService.getCacheItem<Map<String, dynamic>>(
          'device_change_$userId',
          isUserSpecific: true,
        );
        if (cached != null && cached.isNotEmpty) {
          setState(() {
            _args = cached;
            _hasArgs = true;
            _username = cached['username']?.toString() ?? '';
            _currentDeviceId =
                cached['currentDeviceId']?.toString() ?? 'Unknown';
            _deviceId = cached['newDeviceId']?.toString() ??
                cached['deviceId']?.toString() ??
                '';
            _changeCount = cached['changeCount'] as int? ?? 0;
            _maxChanges = cached['maxChanges'] as int? ?? 2;
            _remainingChanges = cached['remainingChanges'] as int? ?? 2;
            _canChangeDevice = cached['canChangeDevice'] as bool? ?? true;
          });
        }
      }
    } catch (e) {
      debugLog('DeviceChangeScreen', 'Error loading cached device change: $e');
    }
  }

  void _initializeArgs() {
    Map<String, dynamic>? routeArgs;

    try {
      final goRouter = GoRouter.of(context);
      final state = goRouter.routerDelegate.currentConfiguration;
      if (state.extra != null && state.extra is Map<String, dynamic>) {
        routeArgs = state.extra as Map<String, dynamic>;
      }
    } catch (e) {}

    if (routeArgs == null || routeArgs.isEmpty) {
      try {
        final modalRoute = ModalRoute.of(context);
        if (modalRoute?.settings.arguments != null) {
          final args = modalRoute!.settings.arguments;
          if (args is Map<String, dynamic>) {
            routeArgs = args;
          }
        }
      } catch (e) {}
    }

    if (routeArgs != null && routeArgs.isNotEmpty) {
      _args = routeArgs;
      _hasArgs = true;

      _username = _args['username']?.toString() ?? '';
      _currentDeviceId = _args['currentDeviceId']?.toString() ?? 'Unknown';
      _deviceId = _args['newDeviceId']?.toString() ??
          _args['deviceId']?.toString() ??
          '';
      _changeCount = _args['changeCount'] as int? ?? 0;
      _maxChanges = _args['maxChanges'] as int? ?? 2;
      _remainingChanges = _args['remainingChanges'] as int? ?? 2;
      _canChangeDevice = _args['canChangeDevice'] as bool? ?? true;
      final password = _args['password']?.toString() ?? '';

      if (password.isNotEmpty) _passwordController.text = password;

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _saveDeviceChangeToCache();
      });

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _initializeDeviceInfo();
        if (_mounted) setState(() => _isInitializing = false);
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _loadDeviceChangeFromCache();
        if (_hasArgs) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await _initializeDeviceInfo();
            if (_mounted) setState(() => _isInitializing = false);
          });
        } else {
          if (_mounted) {
            SnackbarService()
                .showError(context, 'Invalid device change request');
            context.go('/auth/login');
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
      if (_mounted) setState(() => _newDeviceId = deviceId);
    } catch (e) {
      debugLog('DeviceChangeScreen', 'Error initializing device: $e');
      if (_mounted) {
        SnackbarService().showError(context, 'Failed to initialize device');
      }
    }
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty)
      return 'Password is required to confirm device change';
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
    final apiService = context.read<ApiService>();

    final password = _passwordController.text;

    try {
      final approveResponse = await apiService.approveDeviceChange(
        username: _username,
        password: password,
        deviceId: _newDeviceId ?? _deviceId,
      );

      if (!approveResponse.success) {
        throw ApiError(message: approveResponse.message);
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
        await categoryProvider.loadCategoriesWithSubscriptionCheck(
            forceRefresh: true);
        await deviceProvider.initialize();

        final userId = await UserSession().getCurrentUserId();
        if (userId != null) {
          await deviceProvider.deviceService
              .removeCacheItem('device_change_$userId', isUserSpecific: true);
        }

        SnackbarService()
            .showSuccess(context, 'Device change approved successfully!');

        if (authProvider.currentUser?.schoolId == null) {
          appRouter.setNavigatingToSchoolSelection(true);
          appRouter.setPendingDestination('/school-selection');
        } else {
          appRouter.setNavigatingToHome(true);
          appRouter.setPendingDestination('/');
        }

        await Future.delayed(const Duration(milliseconds: 100));

        if (!_mounted) return;

        if (authProvider.currentUser?.schoolId == null) {
          context.go('/school-selection');
        } else {
          context.go('/');
        }
      } else {
        if (_mounted) {
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

      if (_mounted) {
        setState(() => _error = errorMessage);
        SnackbarService().showError(context, errorMessage);
      }
    } finally {
      if (_mounted) setState(() => _isLoading = false);
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
      if (confirmed == true && _mounted) {
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
    ).animate().shake(duration: 1.seconds, delay: 500.ms);
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
                onChanged: (value) => _mounted
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
                  onPressed: _isLoading || !_confirmChange
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
        ),
      );
    }

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

    if (!_hasArgs) {
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
    ).animate().fadeIn(duration: AppThemes.animationMedium);
  }
}

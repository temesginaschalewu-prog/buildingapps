// lib/screens/auth/device_change_screen.dart
// PRODUCTION STANDARD - USING BASE SCREEN MIXIN

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../services/user_session.dart';
import '../../services/snackbar_service.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/base_screen_mixin.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/app_dialog.dart';
import '../../widgets/common/app_shimmer.dart';
import '../../providers/auth_provider.dart';
import '../../providers/device_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/category_provider.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/responsive_values.dart' hide EmptyStateType;
import '../../utils/helpers.dart';
import '../../utils/api_response.dart';
import '../../utils/constants.dart';
import '../../utils/router.dart';

class DeviceChangeScreen extends StatefulWidget {
  const DeviceChangeScreen({super.key});

  @override
  State<DeviceChangeScreen> createState() => _DeviceChangeScreenState();
}

class _DeviceChangeScreenState extends State<DeviceChangeScreen>
    with BaseScreenMixin<DeviceChangeScreen>, TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _confirmChange = false;
  late Map<String, dynamic> _args = {};
  bool _hasArgs = false;
  String? _newDeviceId;
  String? _error;
  bool _isInitializing = true;

  late String _username;
  late String _deviceId;
  late String _currentDeviceId;
  late bool _canChangeDevice;

  late AnimationController _pulseAnimationController;
  late AuthProvider _authProvider;
  late DeviceProvider _deviceProvider;
  late SettingsProvider _settingsProvider;
  late SubscriptionProvider _subscriptionProvider;
  late CategoryProvider _categoryProvider;

  @override
  String get screenTitle => 'Approve new device';

  @override
  String? get screenSubtitle => null;

  @override
  bool get isLoading => _isInitializing;

  @override
  bool get hasCachedData => false;

  @override
  dynamic get errorMessage => _error;

  @override
  void initState() {
    super.initState();

    _pulseAnimationController = AnimationController(
      vsync: this,
      duration: 1.seconds,
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isMounted) {
        _initializeArgs();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _authProvider = Provider.of<AuthProvider>(context);
    _deviceProvider = Provider.of<DeviceProvider>(context);
    _settingsProvider = Provider.of<SettingsProvider>(context);
    _subscriptionProvider = Provider.of<SubscriptionProvider>(context);
    _categoryProvider = Provider.of<CategoryProvider>(context);
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _pulseAnimationController.dispose();
    super.dispose();
  }

  @override
  Future<void> onRefresh() async {
    // No refresh needed for this screen
  }

  Future<void> _saveDeviceChangeToCache() async {
    try {
      final userId = await UserSession().getCurrentUserId();
      if (userId != null && isMounted) {
        _deviceProvider.deviceService.saveCacheItem(
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
      final userId = await UserSession().getCurrentUserId();
      if (userId != null && isMounted) {
        final cached = await _deviceProvider.deviceService
            .getCacheItem<Map<String, dynamic>>(
          'device_change_$userId',
          isUserSpecific: true,
        );
        if (cached != null && cached.isNotEmpty && isMounted) {
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
    _username = args['username']?.toString() ?? '';

    if (_username.isEmpty && args['data'] != null) {
      final data = args['data'] as Map<String, dynamic>?;
      _username = data?['username']?.toString() ?? '';
    }

    if (_username.isEmpty && args['user'] != null) {
      final user = args['user'] as Map<String, dynamic>?;
      _username = user?['username']?.toString() ?? '';
    }

    if (_username.isEmpty) {
      try {
        final currentUser = _authProvider.currentUser;
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

    _canChangeDevice = args['canChangeDevice'] as bool? ??
        args['data']?['canChangeDevice'] as bool? ??
        true;

    final password = args['password']?.toString() ?? '';

    debugLog('DeviceChangeScreen', 'Extracted username: "$_username"');
    debugLog('DeviceChangeScreen', 'Device ID: $_deviceId');
    debugLog('DeviceChangeScreen', 'Current Device: $_currentDeviceId');

    if (password.isNotEmpty && isMounted) {
      _passwordController.text = password;
    }
  }

  void _initializeArgs() {
    Map<String, dynamic>? routeArgs;

    try {
      final goRouter = GoRouter.of(context);
      final state = goRouter.routerDelegate.currentConfiguration;
      if (state.extra != null && state.extra is Map<String, dynamic>) {
        routeArgs = state.extra as Map<String, dynamic>;
        debugLog('DeviceChangeScreen', 'Got args from GoRouter');
      }
    } catch (e) {}

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

    if (routeArgs == null || routeArgs.isEmpty) {
      try {
        final lastLoginResult = _authProvider.lastLoginResult;
        if (lastLoginResult != null) {
          routeArgs = lastLoginResult;
          debugLog('DeviceChangeScreen',
              'Got args from AuthProvider lastLoginResult');
        }
      } catch (e) {}
    }

    if (routeArgs != null && routeArgs.isNotEmpty && isMounted) {
      _args = routeArgs;
      _hasArgs = true;
      _extractArgsFromMap(_args);

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _saveDeviceChangeToCache();
      });

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _initializeDeviceInfo();
        if (isMounted) {
          setState(() => _isInitializing = false);
        }
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _loadDeviceChangeFromCache();
        if (_hasArgs && isMounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await _initializeDeviceInfo();
            if (isMounted) {
              setState(() => _isInitializing = false);
            }
          });
        } else {
          if (isMounted) {
            debugLog('DeviceChangeScreen', 'No args found anywhere!');

            try {
              final currentUser = _authProvider.currentUser;
              if (currentUser != null && isMounted) {
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

            if (isMounted) {
              SnackbarService().showError(
                context,
                AppStrings.invalidDeviceChangeRequest,
              );
              context.go('/auth/login');
            }
          }
        }
      });
    }
  }

  Future<void> _initializeDeviceInfo() async {
    try {
      await _deviceProvider.deviceService.init();
      final deviceId = await _deviceProvider.deviceService.getDeviceId();
      if (isMounted) {
        setState(() => _newDeviceId = deviceId);
      }
    } catch (e) {
      debugLog('DeviceChangeScreen', 'Error initializing device: $e');
      if (isMounted) {
        setState(() {
          _newDeviceId = 'fallback_${DateTime.now().millisecondsSinceEpoch}';
        });
      }
    }
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return AppStrings.passwordRequiredForDeviceChange;
    }
    return null;
  }

  Future<void> _approveDeviceChange() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_confirmChange) {
      SnackbarService().showError(
        context,
        AppStrings.confirmDeviceChangePrompt,
      );
      return;
    }
    if (!_canChangeDevice) {
      SnackbarService().showError(
        context,
        _settingsProvider.getDeviceChangeLimitMessage(),
      );
      return;
    }

    if (isOffline) {
      SnackbarService().showOffline(context, action: 'approve device');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final password = _passwordController.text;

    try {
      if (_username.isEmpty) {
        final currentUser = _authProvider.currentUser;
        if (currentUser != null) {
          _username = currentUser.username;
          debugLog('DeviceChangeScreen',
              'Got username from currentUser: $_username');
        } else {
          final userId = await UserSession().getCurrentUserId();
          if (userId != null) {
            debugLog(
                'DeviceChangeScreen', 'Have userId but no username: $userId');
          }
          throw ApiError(message: AppStrings.usernameNotFoundLoginAgain);
        }
      }

      debugLog('DeviceChangeScreen',
          'Approving device change for username: "$_username"');
      debugLog('DeviceChangeScreen', 'Device ID: ${_newDeviceId ?? _deviceId}');

      final approveResponse = await _authProvider.approveDeviceChange(
        username: _username,
        password: password,
        deviceId: _newDeviceId ?? _deviceId,
      );

      if (!approveResponse['success']) {
        throw ApiError(message: approveResponse['message']);
      }

      await Future.delayed(const Duration(seconds: 1));

      final loginResult = await _authProvider.login(
        _username,
        password,
        _newDeviceId ?? _deviceId,
        null,
      );

      if (loginResult['success'] == true) {
        await _subscriptionProvider.loadSubscriptions(forceRefresh: true);
        await _categoryProvider.loadCategories(forceRefresh: true);
        await _deviceProvider.initialize();

        final userId = await UserSession().getCurrentUserId();
        if (userId != null && isMounted) {
          await _deviceProvider.deviceService.removeCacheItem(
            'device_change_$userId',
            isUserSpecific: true,
          );
        }

        if (isMounted) {
          SnackbarService()
              .showSuccess(context, 'Device change approved successfully!');

          await Future.delayed(const Duration(milliseconds: 300));

          if (!isMounted) return;

          if (_authProvider.currentUser?.schoolId == null) {
            appRouter.setNavigatingToSchoolSelection(true);
            context.go('/school-selection');
          } else {
            appRouter.setNavigatingToHome(true);
            context.go('/');
          }
        }
      } else {
        if (isMounted) {
          setState(() => _error =
              loginResult['message'] ?? 'Login after device change failed');
          SnackbarService().showError(context, _error!);
        }
      }
    } catch (e) {
      String errorMessage;
      if (e is ApiError) {
        if (e.action == 'max_device_changes_reached') {
          errorMessage = _settingsProvider.getDeviceChangeLimitMessage();
        } else if (e.statusCode == 403) {
          errorMessage = 'Access denied. Please check your password.';
        } else {
          errorMessage = e.message;
        }
      } else {
        errorMessage = 'Device change failed. Please try again.';
      }

      if (isMounted) {
        setState(() => _error = errorMessage);
        SnackbarService().showError(context, errorMessage);
      }
    } finally {
      if (isMounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _cancelDeviceChange() {
    AppDialog.confirm(
      context: context,
      title: 'Cancel device approval',
      message:
          'Are you sure you want to cancel? You will need to sign in again before using this device.',
      confirmText: 'Yes, cancel',
      cancelText: 'Stay here',
    ).then((confirmed) {
      if (confirmed == true && isMounted) {
        _authProvider.clearDeviceChangeRequirement();
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
            style: AppTextStyles.labelMedium(context).copyWith(
              color: AppColors.getTextSecondary(context),
            ),
          ),
        ),
        Expanded(
          child: Container(
            padding: EdgeInsets.all(ResponsiveValues.spacingS(context)),
            decoration: BoxDecoration(
              color: AppColors.getSurface(context).withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(
                ResponsiveValues.radiusMedium(context),
              ),
            ),
            child: Text(
              value.isNotEmpty
                  ? value.substring(
                          0,
                          value.length > 30 ? 30 : value.length,
                        ) +
                      (value.length > 30 ? '...' : '')
                  : 'Not available',
              style: AppTextStyles.bodySmall(context).copyWith(
                fontFamily: Platform.isIOS ? 'Courier' : 'monospace',
                fontWeight: FontWeight.w600,
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
        padding: ResponsiveValues.cardPadding(context),
        child: Row(
          children: [
            Container(
              width: ResponsiveValues.iconSizeXL(context),
              height: ResponsiveValues.iconSizeXL(context),
              decoration: BoxDecoration(
                color: AppColors.telegramYellow.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.warning_rounded,
                size: ResponsiveValues.iconSizeS(context),
                color: AppColors.telegramYellow,
              ),
            ),
            SizedBox(width: ResponsiveValues.spacingL(context)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'New device detected',
                    style: AppTextStyles.titleMedium(context).copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: ResponsiveValues.spacingXS(context)),
                  Text(
                    'Approve this only if you recognize the device. Your old device will stop accessing this account after the change.',
                    style: AppTextStyles.bodyMedium(context).copyWith(
                      color: AppColors.getTextSecondary(context),
                      height: 1.45,
                    ),
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
                        AppColors.telegramPurple.withValues(alpha: 0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.devices_rounded,
                    size: ResponsiveValues.iconSizeS(context),
                    color: AppColors.telegramBlue,
                  ),
                ),
                SizedBox(width: ResponsiveValues.spacingM(context)),
                Text(
                  'Device Information',
                  style: AppTextStyles.titleMedium(context).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
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
                onChanged: (value) => isMounted
                    ? setState(() => _confirmChange = value ?? false)
                    : null,
                activeColor: AppColors.telegramBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    ResponsiveValues.radiusSmall(context),
                  ),
                ),
              ),
            ),
            SizedBox(width: ResponsiveValues.spacingM(context)),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: AppTextStyles.bodyMedium(context),
                  children: [
                    const TextSpan(text: 'I understand that: '),
                    const TextSpan(
                      text: 'my old device will be blocked, ',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const TextSpan(text: 'and I can only change devices '),
                    TextSpan(
                      text: _settingsProvider.getDeviceChangeLimitSummary(),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
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
                  onPressed: _isLoading || !_confirmChange || isOffline
                      ? null
                      : _approveDeviceChange,
                  isLoading: _isLoading,
                  expanded: true,
                )
              : const AppButton.danger(
                  label: 'Change unavailable',
                  expanded: true,
                ),
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
            Icon(
              Icons.info_outline_rounded,
              size: ResponsiveValues.iconSizeS(context),
              color: AppColors.getTextSecondary(context),
            ),
            SizedBox(width: ResponsiveValues.spacingM(context)),
            Expanded(
              child: Text(
                _settingsProvider.getDeviceChangeLimitMessage(),
                style: AppTextStyles.bodySmall(context).copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget buildContent(BuildContext context) {
    if (isOffline) {
      return Center(
        child: AppEmptyState(
          icon: Icons.wifi_off_rounded,
          title: 'You are offline',
          message: AppStrings.offlineCompleteDeviceChange,
          actionText: 'Try again',
          onAction: _initializeArgs,
          pendingCount: pendingCount,
          type: EmptyStateType.offline,
        ),
      );
    }

    if (_isInitializing) {
      return Center(
        child: AppCard.glass(
          child: Padding(
            padding: ResponsiveValues.dialogPadding(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppShimmer(type: ShimmerType.circle),
                const SizedBox(height: 16),
                Text(
                  AppStrings.initializingDeviceInformation,
                  style: AppTextStyles.bodyMedium(context).copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_hasArgs && _username.isEmpty) {
      return Center(
        child: AppEmptyState(
          icon: Icons.error_outline_rounded,
          title: AppStrings.invalidRequest,
          message: AppStrings.noDeviceChangeDataProvided,
          actionText: 'Go to sign in',
          onAction: () => context.go('/auth/login'),
          type: EmptyStateType.error,
        ),
      );
    }

    return SingleChildScrollView(
      padding: ResponsiveValues.screenPadding(context),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard.glass(
              child: Padding(
                padding: ResponsiveValues.cardPadding(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Approve this device',
                      style: AppTextStyles.headlineSmall(context).copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: ResponsiveValues.spacingXS(context)),
                    Text(
                      'Review the new device request, confirm your password, and approve the change only if this device is yours.',
                      style: AppTextStyles.bodyMedium(context).copyWith(
                        color: AppColors.getTextSecondary(context),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: ResponsiveValues.spacingL(context)),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Text(screenTitle, style: AppTextStyles.appBarTitle(context)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: AppColors.getTextPrimary(context),
          ),
          onPressed: () => context.go('/auth/login'),
        ),
      ),
      body: SafeArea(
        child: buildContent(context),
      ),
    );
  }
}

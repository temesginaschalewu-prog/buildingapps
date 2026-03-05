import 'dart:async';
import 'dart:io';
import 'package:familyacademyclient/themes/app_themes.dart';
import 'package:familyacademyclient/widgets/common/app_shimmer.dart';
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
import '../../providers/auth_provider.dart';
import '../../providers/device_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/category_provider.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/responsive.dart';
import '../../utils/responsive_values.dart';
import '../../utils/helpers.dart';
import '../../utils/api_response.dart';
import '../../utils/router.dart';
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
  DeviceService? _deviceService;
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

    _pulseAnimationController = AnimationController(
      vsync: this,
      duration: 1.seconds,
    )..repeat(reverse: true);

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

      if (password.isNotEmpty) {
        _passwordController.text = password;
      }

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
      _deviceService = context.read<DeviceService>();
      await _deviceService!.init();

      final deviceId = await _deviceService!.getDeviceId();

      if (_mounted) setState(() => _newDeviceId = deviceId);
    } catch (e) {
      debugLog('DeviceChangeScreen', 'Error initializing device: $e');
      if (_mounted) {
        SnackbarService().showError(context, 'Failed to initialize device');
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
      SnackbarService().showError(
        context,
        'You have reached the maximum device changes ($_maxChanges per month)',
      );
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
          await deviceProvider.deviceService.removeCacheItem(
            'device_change_$userId',
            isUserSpecific: true,
          );
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
    return ResponsiveRow(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: ResponsiveValues.spacingXXXL(context) * 3,
          child: ResponsiveText(
            '$label:',
            style: AppTextStyles.labelMedium(context).copyWith(
              color: AppColors.getTextSecondary(context),
            ),
          ),
        ),
        Expanded(
          child: AppCard.glass(
            child: Container(
              padding: EdgeInsets.all(ResponsiveValues.spacingS(context)),
              child: ResponsiveText(
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

  Widget _buildLimitRow({
    required String label,
    required String value,
    required Color color,
  }) {
    return ResponsiveRow(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ResponsiveText(
          label,
          style: AppTextStyles.bodyMedium(context),
        ),
        AppCard.glass(
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveValues.spacingM(context),
              vertical: ResponsiveValues.spacingXS(context),
            ),
            child: ResponsiveText(
              value,
              style: AppTextStyles.labelMedium(context).copyWith(
                color: color,
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
        padding: EdgeInsets.all(ResponsiveValues.spacingXL(context)),
        child: ResponsiveRow(
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
                          AppColors.telegramYellow.withValues(alpha: 0.1),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: ResponsiveIcon(
                      Icons.warning_rounded,
                      size: ResponsiveValues.iconSizeXL(context),
                      color: AppColors.telegramYellow,
                    ),
                  ),
                );
              },
            ),
            const ResponsiveSizedBox(width: AppSpacing.xl),
            Expanded(
              child: ResponsiveColumn(
                children: [
                  ResponsiveText(
                    'New Device Detected',
                    style: AppTextStyles.headlineSmall(context).copyWith(
                      color: AppColors.telegramYellow,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const ResponsiveSizedBox(height: AppSpacing.s),
                  ResponsiveText(
                    'You are logging in from a new device. Your old device will be blocked after this change.',
                    style: AppTextStyles.bodyLarge(context).copyWith(
                      color: AppColors.telegramYellow,
                    ),
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
        child: ResponsiveColumn(
          children: [
            ResponsiveRow(
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
                  child: ResponsiveIcon(
                    Icons.devices_rounded,
                    size: ResponsiveValues.iconSizeS(context),
                    color: AppColors.telegramBlue,
                  ),
                ),
                const ResponsiveSizedBox(width: AppSpacing.m),
                ResponsiveText(
                  'Device Information',
                  style: AppTextStyles.titleMedium(context).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const ResponsiveSizedBox(height: AppSpacing.l),
            _buildInfoRow('Username', _username),
            const ResponsiveSizedBox(height: AppSpacing.m),
            _buildInfoRow('Current Device', _currentDeviceId),
            const ResponsiveSizedBox(height: AppSpacing.m),
            _buildInfoRow('New Device', _newDeviceId ?? _deviceId),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceLimitsCard() {
    final remainingColor = _remainingChanges == 0
        ? AppColors.telegramRed
        : _remainingChanges == 1
            ? AppColors.telegramYellow
            : AppColors.telegramGreen;

    return AppCard.glass(
      child: Padding(
        padding: EdgeInsets.all(ResponsiveValues.spacingL(context)),
        child: ResponsiveColumn(
          children: [
            ResponsiveRow(
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
                  child: ResponsiveIcon(
                    Icons.timer_rounded,
                    size: ResponsiveValues.iconSizeS(context),
                    color: AppColors.telegramBlue,
                  ),
                ),
                const ResponsiveSizedBox(width: AppSpacing.m),
                ResponsiveText(
                  'Device Change Limits',
                  style: AppTextStyles.titleMedium(context).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const ResponsiveSizedBox(height: AppSpacing.l),
            _buildLimitRow(
              label: 'Changes this month',
              value: '$_changeCount/$_maxChanges',
              color: AppColors.telegramBlue,
            ),
            const ResponsiveSizedBox(height: AppSpacing.m),
            _buildLimitRow(
              label: 'Remaining changes',
              value: '$_remainingChanges',
              color: remainingColor,
            ),
            if (!_canChangeDevice)
              Padding(
                padding:
                    EdgeInsets.only(top: ResponsiveValues.spacingL(context)),
                child: Container(
                  padding: EdgeInsets.all(ResponsiveValues.spacingM(context)),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.telegramRed.withValues(alpha: 0.2),
                        AppColors.telegramRed.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusMedium(context)),
                  ),
                  child: ResponsiveRow(
                    children: [
                      ResponsiveIcon(
                        Icons.error_outline_rounded,
                        size: ResponsiveValues.iconSizeS(context),
                        color: AppColors.telegramRed,
                      ),
                      const ResponsiveSizedBox(width: AppSpacing.m),
                      Expanded(
                        child: ResponsiveText(
                          'Maximum changes reached. Contact support.',
                          style: AppTextStyles.bodyMedium(context).copyWith(
                            color: AppColors.telegramRed,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
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

  Widget _buildConfirmationCard() {
    return AppCard.glass(
      child: Padding(
        padding: ResponsiveValues.cardPadding(context),
        child: ResponsiveRow(
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
                    ResponsiveValues.radiusSmall(context),
                  ),
                ),
              ),
            ),
            const ResponsiveSizedBox(width: AppSpacing.m),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: AppTextStyles.bodyMedium(context),
                  children: const [
                    TextSpan(text: 'I understand that: '),
                    TextSpan(
                      text: 'my old device will be blocked, ',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(text: 'and I can only change devices '),
                    TextSpan(
                      text: '2 times per month.',
                      style: TextStyle(fontWeight: FontWeight.w600),
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
    return ResponsiveRow(
      children: [
        Expanded(
          child: AppButton.outline(
            label: 'Cancel',
            onPressed: _isLoading ? null : _cancelDeviceChange,
            expanded: true,
          ),
        ),
        const ResponsiveSizedBox(width: AppSpacing.m),
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
              : const AppButton.danger(
                  label: 'Cannot Change',
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
        child: ResponsiveRow(
          children: [
            ResponsiveIcon(
              Icons.info_outline_rounded,
              size: ResponsiveValues.iconSizeS(context),
              color: AppColors.getTextSecondary(context),
            ),
            const ResponsiveSizedBox(width: AppSpacing.m),
            Expanded(
              child: ResponsiveText(
                'Device changes are limited to 2 per month for security reasons.',
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

  void _showDeviceInfoDialog() {
    AppDialog.info(
      context: context,
      title: 'Device Information',
      message: '',
    ).then((_) {});
  }

  @override
  Widget build(BuildContext context) {
    if (_isOffline) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          title: ResponsiveText(
            'Device Change',
            style: AppTextStyles.appBarTitle(context),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: ResponsiveIcon(
              Icons.arrow_back_rounded,
              color: AppColors.getTextPrimary(context),
            ),
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
          title: ResponsiveText(
            'Device Change',
            style: AppTextStyles.appBarTitle(context),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: ResponsiveIcon(
              Icons.arrow_back_rounded,
              color: AppColors.getTextPrimary(context),
            ),
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
                    style: AppTextStyles.bodyMedium(context).copyWith(
                      color: AppColors.getTextSecondary(context),
                    ),
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
          title: ResponsiveText(
            'Device Change',
            style: AppTextStyles.appBarTitle(context),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: ResponsiveIcon(
              Icons.arrow_back_rounded,
              color: AppColors.getTextPrimary(context),
            ),
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

    return ResponsiveLayout(
      mobile: _buildMobileLayout(),
      tablet: _buildDesktopLayout(),
      desktop: _buildDesktopLayout(),
    ).animate().fadeIn(duration: AppThemes.animationDurationMedium);
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: ResponsiveText(
          'Device Change',
          style: AppTextStyles.appBarTitle(context),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        actions: [
          AppButton.icon(
            icon: Icons.info_outline_rounded,
            onPressed: _showDeviceInfoDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: ResponsiveValues.screenPadding(context),
          child: Form(
            key: _formKey,
            child: ResponsiveColumn(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildWarningBanner(),
                const ResponsiveSizedBox(height: AppSpacing.xl),
                _buildDeviceInfoCard(),
                const ResponsiveSizedBox(height: AppSpacing.l),
                _buildDeviceLimitsCard(),
                const ResponsiveSizedBox(height: AppSpacing.xl),
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
                const ResponsiveSizedBox(height: AppSpacing.l),
                _buildConfirmationCard(),
                const ResponsiveSizedBox(height: AppSpacing.xxl),
                _buildActionButtons(),
                const ResponsiveSizedBox(height: AppSpacing.l),
                _buildNote(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: ResponsiveText(
          'Device Change Required',
          style: AppTextStyles.appBarTitle(context),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        actions: [
          AppButton.icon(
            icon: Icons.info_outline_rounded,
            onPressed: _showDeviceInfoDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: AdaptiveContainer(
          child: Form(
            key: _formKey,
            child: ResponsiveColumn(
              children: [
                const ResponsiveSizedBox(height: AppSpacing.xxl),
                _buildWarningBanner(),
                const ResponsiveSizedBox(height: AppSpacing.xxxl),
                ResponsiveRow(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildDeviceInfoCard()),
                    const ResponsiveSizedBox(width: AppSpacing.xxl),
                    Expanded(child: _buildDeviceLimitsCard()),
                  ],
                ),
                const ResponsiveSizedBox(height: AppSpacing.xxxl),
                AppCard.glass(
                  child: Padding(
                    padding: ResponsiveValues.dialogPadding(context),
                    child: ResponsiveColumn(
                      children: [
                        ResponsiveText(
                          'Verification',
                          style: AppTextStyles.titleLarge(context).copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const ResponsiveSizedBox(height: AppSpacing.xl),
                        AppTextField.password(
                          controller: _passwordController,
                          label: 'Verify Password',
                          hint: 'Enter your password to confirm device change',
                          validator: _validatePassword,
                        ),
                        const ResponsiveSizedBox(height: AppSpacing.xl),
                        _buildConfirmationCard(),
                      ],
                    ),
                  ),
                ),
                const ResponsiveSizedBox(height: AppSpacing.xxxl),
                _buildActionButtons(),
                const ResponsiveSizedBox(height: AppSpacing.xl),
                _buildNote(),
                const ResponsiveSizedBox(height: AppSpacing.xxxl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

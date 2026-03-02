import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:familyacademyclient/services/api_service.dart';
import 'package:familyacademyclient/services/user_session.dart';
import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';
import 'package:familyacademyclient/widgets/common/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import 'package:familyacademyclient/utils/helpers.dart';
import '../../providers/auth_provider.dart';
import '../../providers/device_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/category_provider.dart';
import '../../services/device_service.dart';
import '../../themes/app_themes.dart';
import '../../widgets/auth/password_field.dart';
import '../../utils/api_response.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../utils/router.dart';

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
    final hasConnection = await hasInternetConnection();
    if (!hasConnection) {
      setState(() => _isOffline = true);
      showOfflineMessage(context);
    }
  }

  Widget _buildGlassContainer({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.getCard(context).withValues(alpha: 0.4),
                AppColors.getCard(context).withValues(alpha: 0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.telegramBlue.withValues(alpha: 0.2),
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildGlassButton({
    required String label,
    required VoidCallback onPressed,
    required List<Color> gradient,
    bool isLoading = false,
    bool isEnabled = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: isEnabled ? LinearGradient(colors: gradient) : null,
        color: isEnabled
            ? null
            : AppColors.getTextSecondary(context).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        boxShadow: isEnabled
            ? [
                BoxShadow(
                  color: gradient.first.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? onPressed : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            alignment: Alignment.center,
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white)),
                  )
                : Text(
                    label,
                    style: AppTextStyles.buttonLarge.copyWith(
                      color: isEnabled
                          ? Colors.white
                          : AppColors.getTextSecondary(context),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveDeviceChangeToCache() async {
    try {
      final deviceService = Provider.of<DeviceService>(context, listen: false);
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
      final deviceService = Provider.of<DeviceService>(context, listen: false);
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
        debugLog(
            'DeviceChangeScreen', '✅ Received args from GoRouter: $routeArgs');
      }
    } catch (e) {}

    if (routeArgs == null || routeArgs.isEmpty) {
      try {
        final modalRoute = ModalRoute.of(context);
        if (modalRoute?.settings.arguments != null) {
          final args = modalRoute!.settings.arguments;
          if (args is Map<String, dynamic>) {
            routeArgs = args;
            debugLog('DeviceChangeScreen',
                '✅ Received args from ModalRoute: $routeArgs');
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

      // Save to cache for offline access
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _saveDeviceChangeToCache();
      });

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _initializeDeviceInfo();
        if (_mounted) setState(() => _isInitializing = false);
      });
    } else {
      debugLog('DeviceChangeScreen', '❌ No arguments provided');
      // Try to load from cache
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _loadDeviceChangeFromCache();
        if (_hasArgs) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await _initializeDeviceInfo();
            if (_mounted) setState(() => _isInitializing = false);
          });
        } else {
          if (_mounted) {
            showTopSnackBar(context, 'Invalid device change request',
                isError: true);
            context.go('/auth/login');
          }
        }
      });
    }
  }

  Future<void> _initializeDeviceInfo() async {
    try {
      _deviceService = Provider.of<DeviceService>(context, listen: false);
      await _deviceService!.init();

      final deviceId = await _deviceService!.getDeviceId();

      if (_mounted) setState(() => _newDeviceId = deviceId);

      debugLog('DeviceChangeScreen',
          'Device initialized. New Device ID: ${deviceId.substring(0, 10)}...');
    } catch (e) {
      debugLog('DeviceChangeScreen', 'Error initializing device: $e');
      if (_mounted) {
        showTopSnackBar(context, 'Failed to initialize device', isError: true);
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
      showTopSnackBar(context, 'Please confirm the device change',
          isError: true);
      return;
    }
    if (!_canChangeDevice) {
      showTopSnackBar(context,
          'You have reached the maximum device changes ($_maxChanges per month)',
          isError: true);
      return;
    }

    final hasConnection = await hasInternetConnection();
    if (!hasConnection) {
      showTopSnackBar(
        context,
        'You are offline. Please check your internet connection.',
        isError: true,
      );
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
      debugLog(
          'DeviceChangeScreen', 'Approving device change for user: $_username');

      final approveResponse = await apiService.approveDeviceChange(
        username: _username,
        password: password,
        deviceId: _newDeviceId ?? _deviceId,
      );

      if (!approveResponse.success) {
        throw ApiError(
            message:
                approveResponse.message ?? 'Device change approval failed');
      }

      debugLog('DeviceChangeScreen', '✅ Device change approved by backend');

      await Future.delayed(const Duration(seconds: 1));

      debugLog('DeviceChangeScreen', 'Logging in with new device...');

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

        // Clear cached device change after successful approval
        final userId = await UserSession().getCurrentUserId();
        if (userId != null) {
          await deviceProvider.deviceService.removeCacheItem(
            'device_change_$userId',
            isUserSpecific: true,
          );
        }

        showTopSnackBar(context, 'Device change approved successfully!');

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
          showTopSnackBar(context, _error!, isError: true);
        }
      }
    } catch (e) {
      debugLog('DeviceChangeScreen', 'Device change failed: $e');

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
        showTopSnackBar(context, errorMessage, isError: true);
      }
    } finally {
      if (_mounted) setState(() => _isLoading = false);
    }
  }

  void _cancelDeviceChange() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: _buildGlassContainer(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.telegramYellow.withValues(alpha: 0.2),
                        AppColors.telegramYellow.withValues(alpha: 0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.exit_to_app_rounded,
                      color: AppColors.telegramYellow, size: 32),
                ),
                const SizedBox(height: 16),
                Text('Cancel Device Change',
                    style: AppTextStyles.titleLarge.copyWith(
                        color: AppColors.getTextPrimary(context),
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Text(
                    'Are you sure you want to cancel? You will not be able to login on this device.',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.getTextSecondary(context)),
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.getTextSecondary(context),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('No, Stay'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildGlassButton(
                        label: 'Yes, Cancel',
                        onPressed: () {
                          Navigator.pop(context);
                          context
                              .read<AuthProvider>()
                              .clearDeviceChangeRequirement();
                          if (_mounted) context.go('/auth/login');
                        },
                        gradient: const [Color(0xFFFF3B30), Color(0xFFE6204A)],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
          title: Text('Device Change',
              style: AppTextStyles.appBarTitle
                  .copyWith(color: AppColors.getTextPrimary(context))),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded,
                  color: AppColors.getTextPrimary(context)),
              onPressed: () => context.go('/auth/login')),
        ),
        body: OfflineState(
          dataType: 'device change',
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
          title: Text('Device Change',
              style: AppTextStyles.appBarTitle
                  .copyWith(color: AppColors.getTextPrimary(context))),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded,
                  color: AppColors.getTextPrimary(context)),
              onPressed: () => context.go('/auth/login')),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildGlassContainer(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  child: const LoadingIndicator(
                      size: 48, color: AppColors.telegramBlue),
                ),
              ),
              const SizedBox(height: 16),
              Text('Initializing device information...',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.getTextSecondary(context))),
            ],
          ),
        ),
      );
    }

    if (!_hasArgs) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          title: Text('Device Change',
              style: AppTextStyles.appBarTitle
                  .copyWith(color: AppColors.getTextPrimary(context))),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded,
                  color: AppColors.getTextPrimary(context)),
              onPressed: () => context.go('/auth/login')),
        ),
        body: Center(
          child: EmptyState(
            icon: Icons.error_outline,
            title: 'Invalid Request',
            message: 'No device change data provided.',
            type: EmptyStateType.error,
            actionText: 'Back to Login',
            onAction: () => context.go('/auth/login'),
          ),
        ),
      );
    }

    return ResponsiveLayout(
      mobile: _buildMobileLayout(),
      tablet: _buildDesktopLayout(),
      desktop: _buildDesktopLayout(),
    ).animate().fadeIn(duration: AppThemes.animationDurationMedium);
  }

  // ... rest of the existing UI methods (_buildMobileLayout, _buildDesktopLayout, etc.)
  // They remain the same as in your original file

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Text('Device Change',
            style: AppTextStyles.appBarTitle
                .copyWith(color: AppColors.getTextPrimary(context))),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline_rounded,
                color: AppColors.getTextSecondary(context)),
            onPressed: _showDeviceInfoDialog,
            tooltip: 'Device Information',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildWarningBanner(),
                const SizedBox(height: 24),
                _buildDeviceInfoCard(),
                const SizedBox(height: 16),
                _buildDeviceLimitsCard(),
                const SizedBox(height: 24),
                _buildGlassContainer(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: PasswordField(
                      controller: _passwordController,
                      label: 'Verify Password',
                      hintText: 'Enter your password to confirm device change',
                      validator: _validatePassword,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildConfirmationCard(),
                const SizedBox(height: 32),
                _buildActionButtons(),
                const SizedBox(height: 16),
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
        title: Text('Device Change Required',
            style: AppTextStyles.appBarTitle
                .copyWith(color: AppColors.getTextPrimary(context))),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline_rounded,
                color: AppColors.getTextSecondary(context)),
            onPressed: _showDeviceInfoDialog,
            tooltip: 'Device Information',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: AdaptiveContainer(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                _buildWarningBanner(),
                const SizedBox(height: 48),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildDeviceInfoCard()),
                    const SizedBox(width: 32),
                    Expanded(child: _buildDeviceLimitsCard()),
                  ],
                ),
                const SizedBox(height: 48),
                _buildGlassContainer(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Verification',
                            style: AppTextStyles.titleLarge.copyWith(
                                color: AppColors.getTextPrimary(context),
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 24),
                        PasswordField(
                          controller: _passwordController,
                          label: 'Verify Password',
                          hintText:
                              'Enter your password to confirm device change',
                          validator: _validatePassword,
                        ),
                        const SizedBox(height: 24),
                        _buildConfirmationCard(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                _buildActionButtons(),
                const SizedBox(height: 24),
                _buildNote(),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceInfoCard() {
    return _buildGlassContainer(
      child: Padding(
        padding: EdgeInsets.all(ScreenSize.responsiveValue(
            context: context, mobile: 16, tablet: 20, desktop: 24)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.telegramBlue.withValues(alpha: 0.2),
                        AppColors.telegramPurple.withValues(alpha: 0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.devices_rounded,
                      color: AppColors.telegramBlue, size: 20),
                ),
                const SizedBox(width: 12),
                Text('Device Information',
                    style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.getTextPrimary(context),
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Username', _username),
            const SizedBox(height: 12),
            _buildInfoRow('Current Device', _currentDeviceId),
            const SizedBox(height: 12),
            _buildInfoRow('New Device', _newDeviceId ?? _deviceId),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
            width: 100,
            child: Text('$label:',
                style: AppTextStyles.labelMedium
                    .copyWith(color: AppColors.getTextSecondary(context)))),
        Expanded(
          child: _buildGlassContainer(
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Text(
                value.isNotEmpty
                    ? value.substring(
                            0, value.length > 30 ? 30 : value.length) +
                        (value.length > 30 ? '...' : '')
                    : 'Not available',
                style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.getTextPrimary(context),
                    fontFamily: Platform.isIOS ? 'Courier' : 'monospace',
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceLimitsCard() {
    final remainingColor = _remainingChanges == 0
        ? AppColors.telegramRed
        : _remainingChanges == 1
            ? AppColors.telegramYellow
            : AppColors.telegramGreen;

    return _buildGlassContainer(
      child: Padding(
        padding: EdgeInsets.all(ScreenSize.responsiveValue(
            context: context, mobile: 16, tablet: 20, desktop: 24)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.telegramBlue.withValues(alpha: 0.2),
                        AppColors.telegramPurple.withValues(alpha: 0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.timer_rounded,
                      color: AppColors.telegramBlue, size: 20),
                ),
                const SizedBox(width: 12),
                Text('Device Change Limits',
                    style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.getTextPrimary(context),
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 16),
            _buildLimitRow(
                label: 'Changes this month',
                value: '$_changeCount/$_maxChanges',
                color: AppColors.telegramBlue),
            const SizedBox(height: 12),
            _buildLimitRow(
                label: 'Remaining changes',
                value: '$_remainingChanges',
                color: remainingColor),
            if (!_canChangeDevice)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.telegramRed.withValues(alpha: 0.2),
                        AppColors.telegramRed.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AppColors.telegramRed, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(
                              'Maximum changes reached. Contact support.',
                              style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.telegramRed,
                                  fontWeight: FontWeight.w500))),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLimitRow(
      {required String label, required String value, required Color color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.getTextPrimary(context))),
        _buildGlassContainer(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(value,
                style: AppTextStyles.labelMedium
                    .copyWith(color: color, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmationCard() {
    return _buildGlassContainer(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Checkbox(
              value: _confirmChange,
              onChanged: (value) => _mounted
                  ? setState(() => _confirmChange = value ?? false)
                  : null,
              activeColor: AppColors.telegramBlue,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.getTextPrimary(context)),
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
          child: TextButton(
            onPressed: _isLoading ? null : _cancelDeviceChange,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.getTextSecondary(context),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: Text('Cancel',
                style: AppTextStyles.buttonMedium
                    .copyWith(color: AppColors.getTextSecondary(context))),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _canChangeDevice
              ? _buildGlassButton(
                  label: _isLoading ? 'Approving...' : 'Approve',
                  onPressed: _approveDeviceChange,
                  gradient: const [Color(0xFF2AABEE), Color(0xFF5856D6)],
                  isLoading: _isLoading,
                  isEnabled: !_isLoading && _confirmChange,
                )
              : _buildGlassButton(
                  label: 'Cannot Change',
                  onPressed: () {},
                  gradient: const [Color(0xFFFF3B30), Color(0xFFE6204A)],
                  isEnabled: false,
                ),
        ),
      ],
    );
  }

  Widget _buildNote() {
    return _buildGlassContainer(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded,
                size: 20, color: AppColors.getTextSecondary(context)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Device changes are limited to 2 per month for security reasons.',
                style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.getTextSecondary(context),
                    fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeviceInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: _buildGlassContainer(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.telegramBlue.withValues(alpha: 0.2),
                            AppColors.telegramPurple.withValues(alpha: 0.1),
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.info_rounded,
                          color: AppColors.telegramBlue, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Text('Device Information',
                        style: AppTextStyles.titleLarge.copyWith(
                            color: AppColors.getTextPrimary(context),
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildDialogInfoItem('Username', _username),
                const SizedBox(height: 12),
                _buildDialogInfoItem('Current Device', _currentDeviceId),
                const SizedBox(height: 12),
                _buildDialogInfoItem('New Device', _newDeviceId ?? _deviceId),
                const SizedBox(height: 12),
                _buildDialogInfoItem(
                    'Device Changes', '$_changeCount/$_maxChanges'),
                const SizedBox(height: 12),
                _buildDialogInfoItem('Remaining Changes', '$_remainingChanges'),
                const SizedBox(height: 12),
                _buildDialogInfoItem(
                    'Status', _canChangeDevice ? 'Can Change' : 'Cannot Change',
                    valueColor: _canChangeDevice
                        ? AppColors.telegramGreen
                        : AppColors.telegramRed),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: _buildGlassButton(
                    label: 'Close',
                    onPressed: () => Navigator.pop(context),
                    gradient: const [Color(0xFF2AABEE), Color(0xFF5856D6)],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDialogInfoItem(String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTextStyles.labelMedium
                .copyWith(color: AppColors.getTextSecondary(context))),
        const SizedBox(height: 4),
        _buildGlassContainer(
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Text(
              value.isEmpty ? 'Not available' : value,
              style: AppTextStyles.bodyMedium.copyWith(
                color: valueColor ?? AppColors.getTextPrimary(context),
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
    return _buildGlassContainer(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            AnimatedBuilder(
              animation: _pulseAnimationController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1 + _pulseAnimationController.value * 0.1,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.telegramYellow.withValues(alpha: 0.2),
                          AppColors.telegramYellow.withValues(alpha: 0.1),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.warning_rounded,
                        color: AppColors.telegramYellow, size: 32),
                  ),
                );
              },
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('New Device Detected',
                      style: AppTextStyles.headlineSmall.copyWith(
                          color: AppColors.telegramYellow,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(
                      'You are logging in from a new device. Your old device will be blocked after this change.',
                      style: AppTextStyles.bodyLarge
                          .copyWith(color: AppColors.telegramYellow)),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().shake(duration: 1.seconds, delay: 500.ms);
  }
}

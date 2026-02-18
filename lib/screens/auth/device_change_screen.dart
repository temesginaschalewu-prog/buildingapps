import 'dart:io';
import 'package:familyacademyclient/services/api_service.dart';
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
import '../../widgets/common/error_widget.dart';
import '../../utils/router.dart'; // Add this import

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

  void _initializeArgs() {
    Map<String, dynamic>? routeArgs;

    try {
      final goRouter = GoRouter.of(context);
      final state = goRouter.routerDelegate.currentConfiguration;

      if (state?.extra != null && state!.extra is Map<String, dynamic>) {
        routeArgs = state.extra as Map<String, dynamic>;
        debugLog(
            'DeviceChangeScreen', '✅ Received args from GoRouter: $routeArgs');
      }
    } catch (e) {
      debugLog('DeviceChangeScreen', '⚠️ Error getting GoRouter args: $e');
    }

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
      } catch (e) {
        debugLog('DeviceChangeScreen', '⚠️ Error getting ModalRoute args: $e');
      }
    }

    if (routeArgs != null && routeArgs.isNotEmpty) {
      _args = routeArgs;
      _hasArgs = true;

      debugLog('DeviceChangeScreen', '📦 Processing args: $_args');

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
        await _initializeDeviceInfo();
        if (_mounted) {
          setState(() {
            _isInitializing = false;
          });
        }
      });

      debugLog('DeviceChangeScreen', '✅ Device change data loaded:');
      debugLog('DeviceChangeScreen', '  - Username: $_username');
      debugLog('DeviceChangeScreen', '  - Current Device: $_currentDeviceId');
      debugLog('DeviceChangeScreen', '  - New Device: $_deviceId');
      debugLog(
          'DeviceChangeScreen', '  - Change Count: $_changeCount/$_maxChanges');
      debugLog('DeviceChangeScreen', '  - Can Change: $_canChangeDevice');
    } else {
      debugLog('DeviceChangeScreen', '❌ No arguments provided');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_mounted) {
          showSimpleSnackBar(context, 'Invalid device change request',
              isError: true);
          context.go('/auth/login');
        }
      });
    }
  }

  Future<void> _initializeDeviceInfo() async {
    try {
      _deviceService = Provider.of<DeviceService>(context, listen: false);
      await _deviceService!.init();

      final deviceId = await _deviceService!.getDeviceId();

      if (_mounted) {
        setState(() {
          _newDeviceId = deviceId;
        });
      }

      debugLog('DeviceChangeScreen',
          'Device initialized. New Device ID: ${deviceId.substring(0, 10)}...');
    } catch (e) {
      debugLog('DeviceChangeScreen', 'Error initializing device: $e');
      if (_mounted) {
        showSimpleSnackBar(context, 'Failed to initialize device',
            isError: true);
      }
    }
  }

  Future<void> _approveDeviceChange() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_confirmChange) {
      showSimpleSnackBar(context, 'Please confirm the device change',
          isError: true);
      return;
    }
    if (!_canChangeDevice) {
      showSnackBar(
        context,
        'You have reached the maximum device changes ($_maxChanges per month)',
        isError: true,
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final authProvider = context.read<AuthProvider>();
    final apiService = context.read<ApiService>();
    final subscriptionProvider = context.read<SubscriptionProvider>();
    final categoryProvider = context.read<CategoryProvider>();
    final deviceProvider = context.read<DeviceProvider>();

    final password = _passwordController.text;

    try {
      debugLog(
          'DeviceChangeScreen', 'Approving device change for user: $_username');

      debugLog('DeviceChangeScreen', 'Calling device change approval API...');

      final response = await apiService.approveDeviceChange(
        username: _username,
        password: password,
        deviceId: _newDeviceId ?? _deviceId,
      );

      if (response.success) {
        debugLog('DeviceChangeScreen', '✅ Device change approved via API');

        if (_deviceService != null) {
          await _deviceService!.clearUserCache();
          await _deviceService!.clearAllCache();
          debugLog('DeviceChangeScreen', '🧹 Cleared all cache after approval');
        }

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

          showSimpleSnackBar(context, 'Device change approved successfully!');

          // Set navigation flags BEFORE navigating
          if (authProvider.currentUser?.schoolId == null) {
            appRouter.setNavigatingToSchoolSelection(true);
            appRouter.setPendingDestination('/school-selection');
          } else {
            appRouter.setNavigatingToHome(true);
            appRouter.setPendingDestination('/');
          }

          // Small delay to ensure state updates
          await Future.delayed(const Duration(milliseconds: 100));

          if (!_mounted) return;

          if (authProvider.currentUser?.schoolId == null) {
            context.go('/school-selection');
          } else {
            context.go('/');
          }
        } else {
          if (_mounted) {
            setState(() {
              _error =
                  loginResult['message'] ?? 'Login after device change failed';
            });
            showSimpleSnackBar(context, _error!, isError: true);
          }
        }
      } else {
        if (_mounted) {
          setState(() {
            _error = response.message ?? 'Device change approval failed';
          });
          showSimpleSnackBar(context, _error!, isError: true);
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
        setState(() {
          _error = errorMessage;
        });
        showSimpleSnackBar(context, errorMessage, isError: true);
      }
    } finally {
      if (_mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _cancelDeviceChange() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
        ),
        backgroundColor: AppColors.getCard(context),
        child: Padding(
          padding: EdgeInsets.all(AppThemes.spacingXL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(AppThemes.spacingL),
                decoration: BoxDecoration(
                  color: AppColors.telegramYellow.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.exit_to_app_rounded,
                  color: AppColors.telegramYellow,
                  size: 32,
                ),
              ),
              SizedBox(height: AppThemes.spacingL),
              Text(
                'Cancel Device Change',
                style: AppTextStyles.titleLarge.copyWith(
                  color: AppColors.getTextPrimary(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: AppThemes.spacingM),
              Text(
                'Are you sure you want to cancel? You will not be able to login on this device.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.getTextSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppThemes.spacingXL),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.getTextSecondary(context),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              AppThemes.borderRadiusMedium),
                        ),
                        padding:
                            EdgeInsets.symmetric(vertical: AppThemes.spacingM),
                      ),
                      child:
                          Text('No, Stay', style: AppTextStyles.buttonMedium),
                    ),
                  ),
                  SizedBox(width: AppThemes.spacingM),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);

                        context
                            .read<AuthProvider>()
                            .clearDeviceChangeRequirement();
                        if (_mounted) context.go('/auth/login');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.telegramRed,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              AppThemes.borderRadiusMedium),
                        ),
                        padding:
                            EdgeInsets.symmetric(vertical: AppThemes.spacingM),
                      ),
                      child: Text('Yes, Cancel',
                          style: AppTextStyles.buttonMedium),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeviceInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
        ),
        backgroundColor: AppColors.getCard(context),
        child: Padding(
          padding: EdgeInsets.all(AppThemes.spacingXL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(AppThemes.spacingM),
                    decoration: BoxDecoration(
                      color: AppColors.telegramBlue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.info_rounded,
                      color: AppColors.telegramBlue,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: AppThemes.spacingM),
                  Text(
                    'Device Information',
                    style: AppTextStyles.titleLarge.copyWith(
                      color: AppColors.getTextPrimary(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppThemes.spacingL),
              _buildDialogInfoItem('Username', _username),
              SizedBox(height: AppThemes.spacingM),
              _buildDialogInfoItem('Current Device', _currentDeviceId),
              SizedBox(height: AppThemes.spacingM),
              _buildDialogInfoItem('New Device', _newDeviceId ?? _deviceId),
              SizedBox(height: AppThemes.spacingM),
              _buildDialogInfoItem(
                  'Device Changes', '$_changeCount/$_maxChanges'),
              SizedBox(height: AppThemes.spacingM),
              _buildDialogInfoItem('Remaining Changes', '$_remainingChanges'),
              SizedBox(height: AppThemes.spacingM),
              _buildDialogInfoItem(
                'Status',
                _canChangeDevice ? 'Can Change' : 'Cannot Change',
                valueColor: _canChangeDevice
                    ? AppColors.telegramGreen
                    : AppColors.telegramRed,
              ),
              SizedBox(height: AppThemes.spacingXL),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.telegramBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppThemes.borderRadiusMedium),
                    ),
                    padding: EdgeInsets.symmetric(vertical: AppThemes.spacingM),
                  ),
                  child: Text('Close', style: AppTextStyles.buttonMedium),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogInfoItem(String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.getTextSecondary(context),
          ),
        ),
        SizedBox(height: AppThemes.spacingXS),
        Container(
          padding: EdgeInsets.all(AppThemes.spacingM),
          decoration: BoxDecoration(
            color: AppColors.getSurface(context),
            borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
            border: Border.all(
              color: Theme.of(context).dividerColor,
              width: 0.5,
            ),
          ),
          child: Text(
            value.isEmpty ? 'Not available' : value,
            style: AppTextStyles.bodyMedium.copyWith(
              color: valueColor ?? AppColors.getTextPrimary(context),
              fontFamily: Platform.isIOS ? 'Courier' : 'monospace',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWarningBanner() {
    return Container(
      padding: EdgeInsets.all(AppThemes.spacingXL),
      decoration: BoxDecoration(
        color: AppColors.telegramYellow.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
        border: Border.all(
          color: AppColors.telegramYellow,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimationController,
            builder: (context, child) {
              return Transform.scale(
                scale: 1 + _pulseAnimationController.value * 0.1,
                child: Container(
                  padding: EdgeInsets.all(AppThemes.spacingM),
                  decoration: BoxDecoration(
                    color: AppColors.telegramYellow.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning_rounded,
                    color: AppColors.telegramYellow,
                    size: 32,
                  ),
                ),
              );
            },
          ),
          SizedBox(width: AppThemes.spacingXL),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'New Device Detected',
                  style: AppTextStyles.headlineSmall.copyWith(
                    color: AppColors.telegramYellow,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: AppThemes.spacingS),
                Text(
                  'You are logging in from a new device. Your old device will be blocked after this change.',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.telegramYellow,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().shake(
          duration: 1.seconds,
          delay: 500.ms,
        );
  }

  Widget _buildMobileLayout() {
    if (_isInitializing) {
      return _buildLoadingScreen();
    }

    if (!_hasArgs) {
      return _buildErrorScreen();
    }

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Text(
          'Device Change',
          style: AppTextStyles.appBarTitle.copyWith(
            color: AppColors.getTextPrimary(context),
          ),
        ),
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(
              Icons.info_outline_rounded,
              color: AppColors.getTextSecondary(context),
            ),
            onPressed: _showDeviceInfoDialog,
            tooltip: 'Device Information',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(AppThemes.spacingL),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildWarningBanner(),
                SizedBox(height: AppThemes.spacingXL),
                _buildDeviceInfoCard(),
                SizedBox(height: AppThemes.spacingL),
                _buildDeviceLimitsCard(),
                SizedBox(height: AppThemes.spacingXL),
                PasswordField(
                  controller: _passwordController,
                  label: 'Verify Password',
                  hintText: 'Enter your password to confirm device change',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required to confirm device change';
                    }
                    return null;
                  },
                ),
                SizedBox(height: AppThemes.spacingL),
                _buildConfirmationCard(),
                SizedBox(height: AppThemes.spacingXXL),
                _buildActionButtons(),
                SizedBox(height: AppThemes.spacingL),
                _buildNote(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    if (_isInitializing) {
      return _buildLoadingScreen();
    }

    if (!_hasArgs) {
      return _buildErrorScreen();
    }

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Text(
          'Device Change Required',
          style: AppTextStyles.appBarTitle.copyWith(
            color: AppColors.getTextPrimary(context),
          ),
        ),
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(
              Icons.info_outline_rounded,
              color: AppColors.getTextSecondary(context),
            ),
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
                SizedBox(height: AppThemes.spacingXXL),
                _buildWarningBanner(),
                SizedBox(height: AppThemes.spacingXXXL),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildDeviceInfoCard(),
                    ),
                    SizedBox(width: AppThemes.spacingXXL),
                    Expanded(
                      child: _buildDeviceLimitsCard(),
                    ),
                  ],
                ),
                SizedBox(height: AppThemes.spacingXXXL),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppThemes.borderRadiusLarge),
                  ),
                  color: AppColors.getCard(context),
                  child: Padding(
                    padding: EdgeInsets.all(AppThemes.spacingXXL),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Verification',
                          style: AppTextStyles.titleLarge.copyWith(
                            color: AppColors.getTextPrimary(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: AppThemes.spacingXL),
                        PasswordField(
                          controller: _passwordController,
                          label: 'Verify Password',
                          hintText:
                              'Enter your password to confirm device change',
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Password is required to confirm device change';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: AppThemes.spacingXL),
                        _buildConfirmationCard(),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: AppThemes.spacingXXXL),
                _buildActionButtons(),
                SizedBox(height: AppThemes.spacingXXL),
                _buildNote(),
                SizedBox(height: AppThemes.spacingXXXL),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceInfoCard() {
    return Container(
      padding: EdgeInsets.all(ScreenSize.responsiveValue(
        context: context,
        mobile: AppThemes.spacingL,
        tablet: AppThemes.spacingXL,
        desktop: AppThemes.spacingXXL,
      )),
      decoration: BoxDecoration(
        color: AppColors.getCard(context),
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.telegramBlue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.devices_rounded,
                  color: AppColors.telegramBlue,
                  size: 20,
                ),
              ),
              SizedBox(width: AppThemes.spacingM),
              Text(
                'Device Information',
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.getTextPrimary(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: AppThemes.spacingL),
          _buildInfoRow('Username', _username),
          SizedBox(height: AppThemes.spacingM),
          _buildInfoRow('Current Device', _currentDeviceId),
          SizedBox(height: AppThemes.spacingM),
          _buildInfoRow('New Device', _newDeviceId ?? _deviceId),
          if (_newDeviceId == null)
            Padding(
              padding: EdgeInsets.only(top: AppThemes.spacingM),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_rounded,
                    color: AppColors.telegramRed,
                    size: 16,
                  ),
                  SizedBox(width: AppThemes.spacingS),
                  Expanded(
                    child: Text(
                      'Could not detect new device ID',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.telegramRed,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.getTextSecondary(context),
            ),
          ),
        ),
        Expanded(
          child: Container(
            padding: EdgeInsets.all(AppThemes.spacingS),
            decoration: BoxDecoration(
              color: AppColors.getSurface(context),
              borderRadius: BorderRadius.circular(AppThemes.borderRadiusSmall),
              border: Border.all(
                color: Theme.of(context).dividerColor,
                width: 0.5,
              ),
            ),
            child: Text(
              value.isNotEmpty
                  ? value.substring(0, value.length > 30 ? 30 : value.length) +
                      (value.length > 30 ? '...' : '')
                  : 'Not available',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.getTextPrimary(context),
                fontFamily: Platform.isIOS ? 'Courier' : 'monospace',
                fontWeight: FontWeight.w600,
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

    return Container(
      padding: EdgeInsets.all(ScreenSize.responsiveValue(
        context: context,
        mobile: AppThemes.spacingL,
        tablet: AppThemes.spacingXL,
        desktop: AppThemes.spacingXXL,
      )),
      decoration: BoxDecoration(
        color: AppColors.getCard(context),
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.telegramBlue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.timer_rounded,
                  color: AppColors.telegramBlue,
                  size: 20,
                ),
              ),
              SizedBox(width: AppThemes.spacingM),
              Text(
                'Device Change Limits',
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.getTextPrimary(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: AppThemes.spacingL),
          _buildLimitRow(
            label: 'Changes this month',
            value: '$_changeCount/$_maxChanges',
            color: AppColors.telegramBlue,
          ),
          SizedBox(height: AppThemes.spacingM),
          _buildLimitRow(
            label: 'Remaining changes',
            value: '$_remainingChanges',
            color: remainingColor,
          ),
          if (!_canChangeDevice)
            Padding(
              padding: EdgeInsets.only(top: AppThemes.spacingM),
              child: Container(
                padding: EdgeInsets.all(AppThemes.spacingM),
                decoration: BoxDecoration(
                  color: AppColors.telegramRed.withOpacity(0.1),
                  borderRadius:
                      BorderRadius.circular(AppThemes.borderRadiusMedium),
                  border: Border.all(color: AppColors.telegramRed),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.telegramRed,
                      size: 20,
                    ),
                    SizedBox(width: AppThemes.spacingM),
                    Expanded(
                      child: Text(
                        'Maximum changes reached. Contact support.',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.telegramRed,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_canChangeDevice && _remainingChanges == 1)
            Padding(
              padding: EdgeInsets.only(top: AppThemes.spacingM),
              child: Container(
                padding: EdgeInsets.all(AppThemes.spacingM),
                decoration: BoxDecoration(
                  color: AppColors.telegramYellow.withOpacity(0.1),
                  borderRadius:
                      BorderRadius.circular(AppThemes.borderRadiusMedium),
                  border: Border.all(color: AppColors.telegramYellow),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_rounded,
                      color: AppColors.telegramYellow,
                      size: 20,
                    ),
                    SizedBox(width: AppThemes.spacingM),
                    Expanded(
                      child: Text(
                        'Last change available this month',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.telegramYellow,
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
    );
  }

  Widget _buildLimitRow({
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.getTextPrimary(context),
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppThemes.spacingM,
            vertical: AppThemes.spacingXS,
          ),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppThemes.borderRadiusFull),
            border: Border.all(color: color),
          ),
          child: Text(
            value,
            style: AppTextStyles.labelMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmationCard() {
    return Container(
      padding: EdgeInsets.all(AppThemes.spacingL),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: _confirmChange,
            onChanged: (value) {
              if (_mounted) {
                setState(() => _confirmChange = value ?? false);
              }
            },
            activeColor: AppColors.telegramBlue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppThemes.borderRadiusSmall),
            ),
          ),
          SizedBox(width: AppThemes.spacingM),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.getTextPrimary(context),
                ),
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
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isLoading ? null : _cancelDeviceChange,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.getTextSecondary(context),
              side: BorderSide(
                color: AppColors.getTextSecondary(context).withOpacity(0.5),
              ),
              padding: EdgeInsets.symmetric(vertical: AppThemes.spacingL),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppThemes.borderRadiusMedium),
              ),
            ),
            child: Text(
              'Cancel',
              style: AppTextStyles.buttonMedium.copyWith(
                color: AppColors.getTextSecondary(context),
              ),
            ),
          ),
        ),
        SizedBox(width: AppThemes.spacingM),
        Expanded(
          child: _canChangeDevice
              ? ElevatedButton(
                  onPressed: _isLoading ? null : _approveDeviceChange,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.telegramBlue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: AppThemes.spacingL),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppThemes.borderRadiusMedium),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_rounded, size: 20),
                            SizedBox(width: AppThemes.spacingS),
                            Text(
                              'Approve',
                              style: AppTextStyles.buttonMedium.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                )
              : ElevatedButton(
                  onPressed: null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.telegramRed.withOpacity(0.5),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: AppThemes.spacingL),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppThemes.borderRadiusMedium),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Cannot Change',
                    style: AppTextStyles.buttonMedium.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildNote() {
    return Container(
      padding: EdgeInsets.all(AppThemes.spacingL),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: AppColors.getTextSecondary(context),
          ),
          SizedBox(width: AppThemes.spacingM),
          Expanded(
            child: Text(
              'Device changes are limited to 2 per month for security reasons.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.getTextSecondary(context),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Text(
          'Device Change',
          style: AppTextStyles.appBarTitle.copyWith(
            color: AppColors.getTextPrimary(context),
          ),
        ),
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: AppColors.getTextPrimary(context),
          ),
          onPressed: () => context.go('/auth/login'),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LoadingIndicator(
              type: LoadingType.circular,
              size: 48,
              color: AppColors.telegramBlue,
            ),
            SizedBox(height: AppThemes.spacingL),
            Text(
              'Initializing device information...',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.getTextSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Text(
          'Device Change',
          style: AppTextStyles.appBarTitle.copyWith(
            color: AppColors.getTextPrimary(context),
          ),
        ),
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: AppColors.getTextPrimary(context),
          ),
          onPressed: () => context.go('/auth/login'),
        ),
      ),
      body: Center(
        child: ErrorState(
          title: 'Invalid Request',
          message: 'No device change data provided.',
          actionText: 'Back to Login',
          onAction: () => context.go('/auth/login'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return _buildLoadingScreen();
    }

    if (!_hasArgs) {
      return _buildErrorScreen();
    }

    return ResponsiveLayout(
      mobile: _buildMobileLayout(),
      tablet: _buildDesktopLayout(),
      desktop: _buildDesktopLayout(),
    ).animate().fadeIn(duration: AppThemes.animationDurationMedium);
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/device_service.dart';
import '../../services/notification_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/snackbar_service.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../utils/responsive.dart';
import '../../utils/responsive_values.dart';
import '../../utils/helpers.dart';
import '../../utils/router.dart';
import '../../utils/constants.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../widgets/common/responsive_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _isOffline = false;
  bool _mounted = true;
  bool _isInitializing = false;
  String? _deviceId;
  String? _fcmToken;

  late AnimationController _logoAnimationController;
  late Animation<double> _logoScaleAnimation;

  final NotificationService _notificationService = NotificationService();
  DeviceService? _deviceService;

  @override
  void initState() {
    super.initState();

    _logoAnimationController =
        AnimationController(vsync: this, duration: 600.ms)..forward();
    _logoScaleAnimation = CurvedAnimation(
        parent: _logoAnimationController, curve: Curves.elasticOut);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_mounted) _checkConnectivity();
      if (_mounted) _initializeDeviceAndServices();
    });
  }

  @override
  void dispose() {
    _mounted = false;
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _logoAnimationController.dispose();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    final connectivityService = context.read<ConnectivityService>();
    if (!connectivityService.isOnline) {
      setState(() => _isOffline = true);
    }
  }

  Future<void> _initializeDeviceAndServices() async {
    if (!_mounted || _isInitializing) return;
    _isInitializing = true;
    if (_mounted) setState(() {});

    try {
      _deviceService = context.read<DeviceService>();
      await _deviceService!.init();

      final deviceId = await _deviceService!.getDeviceId();
      await _notificationService.init();

      String? fcmToken;
      if (Platform.isAndroid || Platform.isIOS) {
        fcmToken = await _notificationService.getFCMToken();
      }

      if (_mounted) {
        setState(() {
          _deviceId = deviceId;
          _fcmToken = fcmToken;
          _isInitializing = false;
        });
      }
    } catch (e) {
      if (_mounted) {
        setState(() => _isInitializing = false);
        if (Platform.isAndroid || Platform.isIOS) {
          SnackbarService().showError(context,
              'Service initialization failed. Please restart the app.');
        }
      }
    }
  }

  String? _validateUsername(String? value) {
    if (value == null || value.isEmpty) return AppStrings.usernameRequired;
    if (value.length < 3) return AppStrings.usernameMinLength;
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
      return AppStrings.usernameInvalid;
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return AppStrings.passwordRequired;
    if (value.length < 8) return AppStrings.passwordMinLength;
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty)
      return AppStrings.confirmPasswordRequired;
    if (value != _passwordController.text)
      return AppStrings.passwordsDoNotMatch;
    return null;
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    final connectivityService = context.read<ConnectivityService>();
    if (!connectivityService.isOnline) {
      SnackbarService().showOffline(context, action: 'register');
      setState(() => _isOffline = true);
      return;
    }

    if (_deviceId == null || _deviceId!.isEmpty) {
      SnackbarService()
          .showError(context, 'Device not ready. Please restart the app.');
      return;
    }

    if (_mounted) setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (Platform.isAndroid || Platform.isIOS && _fcmToken == null) {
      try {
        final fcmToken = await _notificationService.getFCMToken();
        if (fcmToken != null) _fcmToken = fcmToken;
      } catch (e) {}
    }

    try {
      final result = await authProvider.register(
          username, password, _deviceId!, _fcmToken);

      if (result['success'] == true && _mounted) {
        SnackbarService().showSuccess(context, 'Registration successful!');
        await Future.delayed(const Duration(milliseconds: 100));

        if (_mounted) {
          if (result['next_step'] == 'select_school') {
            appRouter.setNavigatingToSchoolSelection(true);
            appRouter.setPendingDestination('/school-selection');
            context.go('/school-selection');
          } else {
            appRouter.setNavigatingToHome(true);
            appRouter.setPendingDestination('/');
            context.go('/');
          }
        }
      } else if (_mounted) {
        SnackbarService()
            .showError(context, result['message'] ?? 'Registration failed');
      }
    } catch (e) {
      if (_mounted) {
        SnackbarService().showError(context, formatErrorMessage(e));
      }
    } finally {
      if (_mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildHeader() {
    return Column(
      children: [
        SizedBox(
            height: ScreenSize.isDesktop(context)
                ? ResponsiveValues.spacingXXXL(context)
                : ResponsiveValues.spacingXL(context)),
        ScaleTransition(
          scale: _logoScaleAnimation,
          child: Container(
            width: ResponsiveValues.avatarSizeLarge(context),
            height: ResponsiveValues.avatarSizeLarge(context),
            decoration: BoxDecoration(
              gradient:
                  const LinearGradient(colors: AppColors.telegramGradient),
              borderRadius:
                  BorderRadius.circular(ResponsiveValues.radiusLarge(context)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.telegramBlue.withValues(alpha: 0.3),
                  blurRadius: ResponsiveValues.spacingXL(context),
                  spreadRadius: ResponsiveValues.spacingXS(context),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.school_rounded,
                size: ResponsiveValues.iconSizeXL(context),
                color: Colors.white,
              ),
            ),
          ),
        ),
        SizedBox(height: ResponsiveValues.spacingXL(context)),
        Text(
          AppStrings.createAccount,
          style: AppTextStyles.displaySmall(context)
              .copyWith(fontWeight: FontWeight.w800),
        ),
        SizedBox(height: ResponsiveValues.spacingS(context)),
        Text(
          AppStrings.joinFamilyAcademy,
          style: AppTextStyles.bodyLarge(context)
              .copyWith(color: AppColors.getTextSecondary(context)),
        ),
      ],
    );
  }

  Widget _buildUsernameField() {
    return AppTextField(
      controller: _usernameController,
      label: AppStrings.username,
      hint: 'Choose a username',
      prefixIcon: Icons.person_outline_rounded,
      enabled: !_isLoading,
      validator: _validateUsername,
      onChanged: (_) => setState(() {}),
    )
        .animate()
        .fadeIn(duration: 300.ms, delay: 100.ms)
        .slideX(begin: -0.1, end: 0, duration: 300.ms, delay: 100.ms);
  }

  Widget _buildPasswordField() {
    return AppTextField.password(
      controller: _passwordController,
      label: AppStrings.password,
      hint: 'Create a password',
      enabled: !_isLoading,
      validator: _validatePassword,
    )
        .animate()
        .fadeIn(duration: 300.ms, delay: 200.ms)
        .slideX(begin: -0.1, end: 0, duration: 300.ms, delay: 200.ms);
  }

  Widget _buildConfirmPasswordField() {
    return AppTextField.password(
      controller: _confirmPasswordController,
      label: 'Confirm Password',
      hint: 'Re-enter your password',
      enabled: !_isLoading,
      validator: _validateConfirmPassword,
    )
        .animate()
        .fadeIn(duration: 300.ms, delay: 300.ms)
        .slideX(begin: -0.1, end: 0, duration: 300.ms, delay: 300.ms);
  }

  Widget _buildFormContent() {
    if (_isOffline) {
      return AppEmptyState.offline(
        message: 'You are offline. Please connect to create an account.',
        onRetry: () {
          setState(() => _isOffline = false);
          _checkConnectivity();
        },
      );
    }

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          SizedBox(height: ResponsiveValues.spacingXXXL(context)),
          _buildUsernameField(),
          SizedBox(height: ResponsiveValues.spacingL(context)),
          _buildPasswordField(),
          SizedBox(height: ResponsiveValues.spacingL(context)),
          _buildConfirmPasswordField(),
          SizedBox(height: ResponsiveValues.spacingXXL(context)),
          AppButton.primary(
            label: _deviceId == null
                ? 'Initializing...'
                : (_isLoading
                    ? 'Creating Account...'
                    : AppStrings.createAccount),
            onPressed: _deviceId == null || _isLoading ? null : _register,
            isLoading: _isLoading,
            expanded: true,
          )
              .animate()
              .scale(duration: 300.ms, curve: Curves.easeOut, delay: 400.ms),
          SizedBox(height: ResponsiveValues.spacingXL(context)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                AppStrings.alreadyHaveAccount,
                style: AppTextStyles.bodyMedium(context)
                    .copyWith(color: AppColors.getTextSecondary(context)),
              ),
              SizedBox(width: ResponsiveValues.spacingXS(context)),
              GestureDetector(
                onTap: _isLoading ? null : () => context.go('/auth/login'),
                child: Text(
                  AppStrings.login,
                  style: AppTextStyles.bodyMedium(context).copyWith(
                    color: AppColors.telegramBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ).animate().fadeIn(duration: 300.ms, delay: 500.ms),
          SizedBox(
              height: MediaQuery.of(context).viewInsets.bottom +
                  ResponsiveValues.spacingXL(context)),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: ResponsiveValues.screenPadding(context),
          child: AppCard.glass(child: _buildFormContent()),
        ),
      ),
    );
  }

  Widget _buildTabletLayout() {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: ResponsiveValues.screenPadding(context),
            child: AppCard.glass(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                child: _buildFormContent(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: ResponsiveValues.dialogPadding(context),
                    decoration: const BoxDecoration(
                      gradient:
                          LinearGradient(colors: AppColors.telegramGradient),
                      borderRadius:
                          BorderRadius.horizontal(left: Radius.circular(24)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width:
                              ResponsiveValues.avatarSizeLarge(context) * 1.2,
                          height:
                              ResponsiveValues.avatarSizeLarge(context) * 1.2,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(
                                ResponsiveValues.radiusLarge(context)),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.school_rounded,
                              size: ResponsiveValues.iconSizeXXL(context),
                              color: Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(height: ResponsiveValues.spacingXXXL(context)),
                        Text(
                          'Welcome to\nFamily Academy',
                          style: AppTextStyles.displayLarge(context)
                              .copyWith(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: ResponsiveValues.spacingL(context)),
                        Text(
                          'Join thousands of students learning with our comprehensive educational platform',
                          style: AppTextStyles.bodyLarge(context).copyWith(
                              color: Colors.white.withValues(alpha: 0.9)),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.getCard(context),
                      borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(24)),
                    ),
                    child: SingleChildScrollView(
                      padding: ResponsiveValues.dialogPadding(context),
                      child: AppCard.glass(child: _buildFormContent()),
                    ),
                  ),
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
    return ResponsiveLayout(
      mobile: _buildMobileLayout(),
      tablet: _buildTabletLayout(),
      desktop: _buildDesktopLayout(),
    ).animate().fadeIn(duration: 600.ms);
  }
}

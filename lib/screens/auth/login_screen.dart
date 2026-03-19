// lib/screens/auth/login_screen.dart
// COMPLETE PRODUCTION-READY FILE - FIXED PENDING COUNT

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/auth_provider.dart';
import '../../services/connectivity_service.dart';
import '../../services/snackbar_service.dart';
import '../../services/offline_queue_manager.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/app_brand_logo.dart';
import '../../utils/responsive_values.dart';
import '../../themes/app_themes.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/helpers.dart';
import '../../utils/constants.dart';
import '../../utils/router.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isOffline = false;
  int _pendingCount = 0;

  StreamSubscription? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    debugPrint('🔵 [LoginScreen] initState called');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
  }

  @override
  void dispose() {
    debugPrint('🔵 [LoginScreen] dispose called');
    _usernameController.dispose();
    _passwordController.dispose();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    debugPrint('🔵 [LoginScreen] _initialize started');
    await _checkConnectivity();
    _setupConnectivityListener();
    _loadSavedCredentials();
  }

  void _setupConnectivityListener() {
    final connectivityService = context.read<ConnectivityService>();
    _connectivitySubscription =
        connectivityService.onConnectivityChanged.listen((isOnline) {
      if (mounted) {
        debugPrint('🔵 [LoginScreen] connectivity changed: isOnline=$isOnline');
        setState(() {
          _isOffline = !isOnline;
          final queueManager = context.read<OfflineQueueManager>();
          _pendingCount = queueManager.pendingCount;
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
        final queueManager = context.read<OfflineQueueManager>();
        _pendingCount = queueManager.pendingCount;
      });
    }
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUsername = prefs.getString('last_username');
      if (savedUsername != null && savedUsername.isNotEmpty && mounted) {
        _usernameController.text = savedUsername;
        debugPrint('🔵 [LoginScreen] loaded saved username: $savedUsername');
      }
    } catch (e) {
      debugLog('LoginScreen', 'Error loading saved username: $e');
    }
  }

  Future<void> _saveUsername(String username) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_username', username);
    } catch (e) {
      debugLog('LoginScreen', 'Error saving username: $e');
    }
  }

  String? _validateUsername(String? value) {
    if (value == null || value.isEmpty) return AppStrings.usernameRequired;
    if (value.length < 3) return AppStrings.usernameMinLength;
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return AppStrings.passwordRequired;
    return null;
  }

  Future<void> _handleLogin() async {
    debugPrint('🔵 [LoginScreen] _handleLogin started');

    if (!_formKey.currentState!.validate()) {
      debugPrint('🔵 [LoginScreen] form validation failed');
      return;
    }

    if (!mounted) {
      debugPrint('🔵 [LoginScreen] not mounted');
      return;
    }

    final connectivityService = context.read<ConnectivityService>();
    if (!connectivityService.isOnline) {
      debugPrint('🔵 [LoginScreen] offline - cannot login');
      SnackbarService().showOffline(context, action: 'login');
      if (mounted) setState(() => _isOffline = true);
      return;
    }

    setState(() => _isLoading = true);
    debugPrint('🔵 [LoginScreen] set loading to true');

    try {
      final authProvider = context.read<AuthProvider>();
      final deviceId = await authProvider.deviceService.getDeviceId();
      debugPrint('🔵 [LoginScreen] deviceId: $deviceId');

      await _saveUsername(_usernameController.text.trim());

      final result = await authProvider.login(
        _usernameController.text.trim(),
        _passwordController.text,
        deviceId,
        null,
      );

      debugPrint('🔵 [LoginScreen] login result: $result');

      if (!mounted) {
        debugPrint('🔵 [LoginScreen] not mounted after login');
        return;
      }

      if (result['success'] == true) {
        debugPrint('✅ [LoginScreen] login SUCCESS!');
        final nextStep = result['next_step'] ?? 'home';
        _passwordController.clear();

        SnackbarService().showSuccess(context, AppStrings.success);
        debugPrint('🔵 [LoginScreen] navigating to $nextStep');

        if (nextStep == 'select_school') {
          debugPrint('🔵 [LoginScreen] going to school selection');
          appRouter.setNavigatingToSchoolSelection(true);
          context.go('/school-selection');
        } else {
          debugPrint('🔵 [LoginScreen] going to home');
          appRouter.setNavigatingToHome(true);
          context.go('/');
        }
      } else if (result['requiresDeviceChange'] == true) {
        debugPrint('🔵 [LoginScreen] device change required');
        final deviceChangeData = {
          'username': _usernameController.text.trim(),
          'password': _passwordController.text,
          'deviceId': deviceId,
          'currentDeviceId': result['data']?['currentDeviceId'] ?? 'Unknown',
          'newDeviceId': result['data']?['newDeviceId'] ?? deviceId,
          'maxChanges': result['data']?['maxChanges'] ?? 2,
          'canChangeDevice': result['data']?['canChangeDevice'] ?? true,
          'data': result['data'],
        };

        await context.push('/device-change', extra: deviceChangeData);
      } else {
        debugPrint('❌ [LoginScreen] login failed: ${result['message']}');
        SnackbarService().showError(
          context,
          result['message'] ?? AppStrings.loginFailed,
        );
      }
    } catch (e, stack) {
      debugPrint('❌ [LoginScreen] login error: $e');
      debugPrint('❌ [LoginScreen] stack: $stack');

      if (!mounted) return;

      String errorMessage = AppStrings.loginFailed;
      if (e.toString().contains('timeout')) {
        errorMessage = 'Connection timeout. Please try again.';
      } else if (isNetworkError(e)) {
        errorMessage = 'Network error. Please check your connection.';
      }

      SnackbarService().showError(context, errorMessage);
    } finally {
      if (mounted) {
        debugPrint('🔵 [LoginScreen] setting loading to false');
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🔵 [LoginScreen] building');

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: ResponsiveValues.screenPadding(context),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: AppCard.glass(
                child: Padding(
                  padding: ResponsiveValues.dialogPadding(context),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: AppBrandLogo(
                            size: ResponsiveValues.avatarSizeLarge(context),
                            borderRadius: ResponsiveValues.radiusLarge(context),
                          ),
                        ),
                        SizedBox(height: ResponsiveValues.spacingXL(context)),
                        Text(
                          AppStrings.welcomeBack,
                          style: AppTextStyles.headlineMedium(context)
                              .copyWith(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: ResponsiveValues.spacingS(context)),
                        Text(
                          AppStrings.signInToContinue,
                          style: AppTextStyles.bodyLarge(context).copyWith(
                            color: AppColors.getTextSecondary(context),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_isOffline && _pendingCount > 0)
                          Padding(
                            padding: EdgeInsets.only(
                                top: ResponsiveValues.spacingL(context)),
                            child: Container(
                              padding: ResponsiveValues.cardPadding(context),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.warning.withValues(alpha: 0.2),
                                    AppColors.warning.withValues(alpha: 0.1)
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(
                                    ResponsiveValues.radiusMedium(context)),
                                border: Border.all(
                                    color: AppColors.warning
                                        .withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.schedule_rounded,
                                      color: AppColors.warning,
                                      size:
                                          ResponsiveValues.iconSizeS(context)),
                                  SizedBox(
                                      width:
                                          ResponsiveValues.spacingM(context)),
                                  Expanded(
                                    child: Text(
                                      '$_pendingCount pending action${_pendingCount > 1 ? 's' : ''} will sync when online',
                                      style: AppTextStyles.bodySmall(context)
                                          .copyWith(color: AppColors.warning),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        SizedBox(height: ResponsiveValues.spacingXXL(context)),
                        AppTextField(
                          controller: _usernameController,
                          label: AppStrings.username,
                          hint: AppStrings.enterUsername,
                          prefixIcon: Icons.person_outline_rounded,
                          enabled: !_isLoading,
                          validator: _validateUsername,
                        ),
                        SizedBox(height: ResponsiveValues.spacingL(context)),
                        AppTextField.password(
                          controller: _passwordController,
                          label: AppStrings.password,
                          hint: AppStrings.enterPassword,
                          enabled: !_isLoading,
                          validator: _validatePassword,
                        ),
                        SizedBox(height: ResponsiveValues.spacingXL(context)),
                        AppButton.primary(
                          label: _isOffline
                              ? AppStrings.offlineMode
                              : AppStrings.login,
                          onPressed: _isOffline ? null : _handleLogin,
                          isLoading: _isLoading,
                          expanded: true,
                        ),
                        SizedBox(height: ResponsiveValues.spacingL(context)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              AppStrings.dontHaveAccount,
                              style: AppTextStyles.bodyMedium(context).copyWith(
                                color: AppColors.getTextSecondary(context),
                              ),
                            ),
                            SizedBox(
                                width: ResponsiveValues.spacingXS(context)),
                            GestureDetector(
                              onTap: _isLoading
                                  ? null
                                  : () {
                                      debugPrint(
                                          '🔵 [LoginScreen] navigating to register');
                                      context.push('/auth/register');
                                    },
                              child: Text(
                                AppStrings.register,
                                style:
                                    AppTextStyles.bodyMedium(context).copyWith(
                                  color: AppColors.telegramBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: AppThemes.animationMedium);
  }
}

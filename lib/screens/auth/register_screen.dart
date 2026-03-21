// lib/screens/auth/register_screen.dart
// PRODUCTION STANDARD - USING BASE SCREEN MIXIN

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/device_service.dart';
import '../../services/notification_service.dart';
import '../../services/snackbar_service.dart';
import '../../widgets/common/base_screen_mixin.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/app_brand_logo.dart';
import '../../utils/responsive_values.dart';
import '../../utils/router.dart';
import '../../utils/helpers.dart';
import '../../utils/constants.dart';
import '../../themes/app_themes.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with BaseScreenMixin<RegisterScreen>, TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  String? _deviceId;
  String? _fcmToken;

  final NotificationService _notificationService = NotificationService();

  late AuthProvider _authProvider;
  late DeviceService _deviceService;

  @override
  String get screenTitle => AppStrings.createAccount;

  @override
  String? get screenSubtitle => AppStrings.joinFamilyAcademy;

  @override
  bool get isLoading => _isLoading;

  @override
  bool get hasCachedData => false;

  @override
  dynamic get errorMessage => null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDeviceAndServices();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _authProvider = Provider.of<AuthProvider>(context);
    _deviceService = Provider.of<DeviceService>(context);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Future<void> onRefresh() async {
    // No pull-to-refresh on register screen
  }

  Future<void> _initializeDeviceAndServices() async {
    try {
      await _deviceService.init();
      final deviceId = await _deviceService.getDeviceId();

      String? fcmToken;
      if (Platform.isAndroid || Platform.isIOS) {
        fcmToken = await _notificationService.getFCMToken();
      }

      if (isMounted) {
        setState(() {
          _deviceId = deviceId;
          _fcmToken = fcmToken;
        });
      }
    } catch (e) {
      debugLog('RegisterScreen', 'Device setup error: $e');
      if (isMounted) {
        SnackbarService().showError(context, 'Device setup failed');
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
    if (value == null || value.isEmpty) {
      return AppStrings.confirmPasswordRequired;
    }
    if (value != _passwordController.text) {
      return AppStrings.passwordsDoNotMatch;
    }
    return null;
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!isMounted) return;

    if (isOffline) {
      SnackbarService().showOffline(context, action: 'register');
      return;
    }

    if (_deviceId == null || _deviceId!.isEmpty) {
      SnackbarService().showError(context, 'Device not ready');
      return;
    }

    setState(() => _isLoading = true);

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    try {
      final result = await _authProvider.register(
          username, password, _deviceId!, _fcmToken);

      if (result['success'] == true && isMounted) {
        SnackbarService().showSuccess(context, AppStrings.success);

        await Future.delayed(const Duration(milliseconds: 100));

        if (isMounted) {
          if (result['next_step'] == 'select_school') {
            appRouter.setNavigatingToSchoolSelection(true);
            context.go('/school-selection');
          } else {
            appRouter.setNavigatingToHome(true);
            context.go('/');
          }
        }
      } else if (isMounted) {
        SnackbarService().showError(
            context, result['message'] ?? AppStrings.registrationFailed);
      }
    } catch (e) {
      if (isMounted) {
        String errorMessage = AppStrings.registrationFailed;
        if (e.toString().contains('timeout')) {
          errorMessage = 'Connection timeout. Please try again.';
        } else if (isNetworkError(e)) {
          errorMessage = 'Network error. Please check your connection.';
        }
        SnackbarService().showError(context, errorMessage);
      }
    } finally {
      if (isMounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget buildContent(BuildContext context) {
    return Center(
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
                      AppStrings.createAccount,
                      style: AppTextStyles.headlineMedium(context)
                          .copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: ResponsiveValues.spacingS(context)),
                    Text(
                      AppStrings.joinFamilyAcademy,
                      style: AppTextStyles.bodyLarge(context).copyWith(
                        color: AppColors.getTextSecondary(context),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (isOffline && pendingCount > 0)
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
                                color:
                                    AppColors.warning.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.schedule_rounded,
                                  color: AppColors.warning,
                                  size: ResponsiveValues.iconSizeS(context)),
                              SizedBox(
                                  width: ResponsiveValues.spacingM(context)),
                              Expanded(
                                child: Text(
                                  '$pendingCount pending action${pendingCount > 1 ? 's' : ''} will sync when online',
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
                      hint: AppStrings.chooseUsername,
                      prefixIcon: Icons.person_outline_rounded,
                      enabled: !_isLoading,
                      validator: _validateUsername,
                    ),
                    SizedBox(height: ResponsiveValues.spacingL(context)),
                    AppTextField.password(
                      controller: _passwordController,
                      label: AppStrings.password,
                      hint: AppStrings.createPassword,
                      enabled: !_isLoading,
                      validator: _validatePassword,
                    ),
                    SizedBox(height: ResponsiveValues.spacingL(context)),
                    AppTextField.password(
                      controller: _confirmPasswordController,
                      label: AppStrings.confirmPassword,
                      hint: AppStrings.confirmPassword,
                      enabled: !_isLoading,
                      validator: _validateConfirmPassword,
                    ),
                    SizedBox(height: ResponsiveValues.spacingXL(context)),
                    AppButton.primary(
                      label: _deviceId == null
                          ? AppStrings.loading
                          : (isOffline
                              ? AppStrings.offlineMode
                              : AppStrings.createAccount),
                      onPressed: _deviceId == null || isOffline || _isLoading
                          ? null
                          : _register,
                      isLoading: _isLoading,
                      expanded: true,
                    ),
                    SizedBox(height: ResponsiveValues.spacingL(context)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          AppStrings.alreadyHaveAccount,
                          style: AppTextStyles.bodyMedium(context).copyWith(
                            color: AppColors.getTextSecondary(context),
                          ),
                        ),
                        SizedBox(width: ResponsiveValues.spacingXS(context)),
                        GestureDetector(
                          onTap: _isLoading
                              ? null
                              : () => context.go('/auth/login'),
                          child: Text(
                            AppStrings.login,
                            style: AppTextStyles.bodyMedium(context).copyWith(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return buildScreen(
      content: buildContent(context),
      showAppBar: false,
      showRefreshIndicator: false,
    );
  }
}

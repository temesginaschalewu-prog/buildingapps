import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/auth_provider.dart';
import '../../services/connectivity_service.dart';
import '../../services/notification_service.dart';
import '../../services/snackbar_service.dart';
import '../../widgets/common/base_screen_mixin.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/app_brand_logo.dart';
import '../../utils/platform_helper.dart';
import '../../utils/responsive_values.dart';
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

class _LoginScreenState extends State<LoginScreen>
    with BaseScreenMixin<LoginScreen>, TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final NotificationService _notificationService = NotificationService();

  bool _isLoading = false;

  late AuthProvider _authProvider;

  @override
  String get screenTitle => AppStrings.login;

  @override
  String? get screenSubtitle => 'Sign in to continue learning.';

  @override
  bool get isLoading => _isLoading;

  @override
  bool get hasCachedData => false;

  @override
  bool get blockContentWhenOffline => false;

  @override
  bool get useFullScreenLoadingState => false;

  @override
  dynamic get errorMessage => null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSavedCredentials();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _authProvider = Provider.of<AuthProvider>(context);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Future<void> onRefresh() async {
    // No pull-to-refresh on login screen
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUsername = prefs.getString('last_username');
      if (savedUsername != null && savedUsername.isNotEmpty && isMounted) {
        _usernameController.text = savedUsername;
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
    if (!_formKey.currentState!.validate()) return;
    if (!isMounted) return;

    final connectivityService = context.read<ConnectivityService>();
    await connectivityService.checkConnectivity();

    if (!connectivityService.isOnline) {
      if (connectivityService.hasNetworkConnection) {
        SnackbarService().showServerUnavailable(context, action: 'log in');
      } else {
        SnackbarService().showNoInternet(context, action: 'log in');
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final deviceId = await _authProvider.deviceService.getDeviceId();
      final username = _usernameController.text.trim();
      final fcmToken = (PlatformHelper.isAndroid || PlatformHelper.isIOS)
          ? await _notificationService.getFCMToken()
          : null;

      final result = await _authProvider.login(
        username,
        _passwordController.text,
        deviceId,
        fcmToken,
      );

      if (!isMounted) return;

      if (result['success'] == true) {
        await _saveUsername(username);
        await _notificationService.sendFcmTokenToBackendIfAuthenticated();
        final nextStep = result['next_step'] ?? 'home';
        _passwordController.clear();

        SnackbarService().showSuccess(context, AppStrings.success);

        if (nextStep == 'select_school') {
          appRouter.setNavigatingToSchoolSelection(true);
          context.go('/school-selection');
        } else {
          appRouter.setNavigatingToHome(true);
          context.go('/');
        }
      } else if (result['requiresDeviceChange'] == true) {
        await _saveUsername(username);
        final deviceChangeData = {
          'username': username,
          'password': _passwordController.text,
          'deviceId': deviceId,
          'currentDeviceId': result['data']?['currentDeviceId'] ?? 'Unknown',
          'newDeviceId': result['data']?['newDeviceId'] ?? deviceId,
          'maxChanges': result['data']?['maxChanges'] ?? 2,
          'canChangeDevice': result['data']?['canChangeDevice'] ?? true,
          'data': result['data'],
        };

        context.go('/device-change', extra: deviceChangeData);
      } else {
        SnackbarService()
            .showError(context, result['message'] ?? AppStrings.loginFailed);
      }
    } catch (e) {
      if (!isMounted) return;

      String errorMessage = AppStrings.loginFailed;
      if (e.toString().contains('timeout')) {
        errorMessage = 'Connection timeout. Please try again.';
      } else if (isNetworkError(e)) {
        errorMessage = 'Network error. Please check your connection.';
      }

      SnackbarService().showError(context, errorMessage);
    } finally {
      if (isMounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildIntroCard() {
    return Container(
      margin: EdgeInsets.only(bottom: ResponsiveValues.spacingXL(context)),
      child: Column(
        children: [
          AppBrandLogo(
            size: ResponsiveValues.avatarSizeLarge(context),
            borderRadius: ResponsiveValues.radiusLarge(context),
          ),
          SizedBox(height: ResponsiveValues.spacingL(context)),
          Text(
            'Continue with Family Academy',
            style: AppTextStyles.headlineSmall(context)
                .copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: ResponsiveValues.spacingXS(context)),
          Text(
            'Sign in to access your classes, progress, and saved activity.',
            style: AppTextStyles.bodyMedium(context).copyWith(
              color: AppColors.getTextSecondary(context),
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget buildContent(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: ResponsiveValues.screenPadding(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            children: [
              Padding(
                padding: ResponsiveValues.dialogPadding(context),
                child: Column(
                  children: [
                    _buildIntroCard(),
                    Container(
                      padding: ResponsiveValues.dialogPadding(context),
                      decoration: BoxDecoration(
                        color: AppColors.getSurface(context).withValues(
                          alpha: 0.72,
                        ),
                        borderRadius: BorderRadius.circular(
                          ResponsiveValues.radiusXLarge(context),
                        ),
                        border: Border.all(
                          color: AppColors.getDivider(context)
                              .withValues(alpha: 0.55),
                        ),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
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
                            SizedBox(
                              height: ResponsiveValues.spacingXL(context),
                            ),
                            AppButton.primary(
                              label: AppStrings.login,
                              onPressed: _isLoading ? null : _handleLogin,
                              isLoading: _isLoading,
                              expanded: true,
                            ),
                            SizedBox(height: ResponsiveValues.spacingL(context)),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  AppStrings.dontHaveAccount,
                                  style: AppTextStyles.bodyMedium(
                                    context,
                                  ).copyWith(
                                    color: AppColors.getTextSecondary(context),
                                  ),
                                ),
                                SizedBox(
                                  width: ResponsiveValues.spacingXS(context),
                                ),
                                MouseRegion(
                                  cursor: _isLoading
                                      ? SystemMouseCursors.basic
                                      : SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: _isLoading
                                        ? null
                                        : () => context.push('/auth/register'),
                                    child: Text(
                                      AppStrings.register,
                                      style: AppTextStyles.bodyMedium(
                                        context,
                                      ).copyWith(
                                        color: AppColors.telegramBlue,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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

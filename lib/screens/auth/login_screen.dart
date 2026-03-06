import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../services/connectivity_service.dart';
import '../../services/snackbar_service.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../utils/responsive.dart';
import '../../utils/responsive_values.dart';
import '../../themes/app_themes.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/helpers.dart';
import '../../utils/constants.dart';
import '../../widgets/common/responsive_widgets.dart';

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

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _loadSavedCredentials();
  }

  Future<void> _checkConnectivity() async {
    final connectivityService = context.read<ConnectivityService>();
    if (!connectivityService.isOnline) {
      setState(() => _isOffline = true);
    }
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUsername = prefs.getString('last_username');
      if (savedUsername != null && savedUsername.isNotEmpty) {
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

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
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

    final connectivityService = context.read<ConnectivityService>();
    if (!connectivityService.isOnline) {
      SnackbarService().showOffline(context, action: 'login');
      setState(() => _isOffline = true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final deviceId = await authProvider.deviceService.getDeviceId();

      await _saveUsername(_usernameController.text.trim());

      final result = await authProvider.login(
        _usernameController.text.trim(),
        _passwordController.text,
        deviceId,
        null,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final nextStep = result['next_step'] ?? 'home';
        _passwordController.clear();

        SnackbarService().showSuccess(context, 'Login successful!');

        if (nextStep == 'select_school') {
          context.go('/school-selection');
        } else {
          context.go('/');
        }
      } else if (result['requiresDeviceChange'] == true) {
        await context.push('/device-change', extra: result['data']);
      } else {
        SnackbarService().showError(
          context,
          result['message'] ?? 'Login failed',
        );
      }
    } catch (e) {
      if (!mounted) return;
      SnackbarService().showError(context, formatErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildLogo() {
    return Container(
      width: ResponsiveValues.avatarSizeLarge(context),
      height: ResponsiveValues.avatarSizeLarge(context),
      margin: EdgeInsets.only(bottom: ResponsiveValues.spacingXXL(context)),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: AppColors.telegramGradient),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.telegramBlue.withValues(alpha: 0.3),
            blurRadius: ResponsiveValues.spacingXL(context),
            offset: Offset(0, ResponsiveValues.spacingM(context)),
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
    );
  }

  Widget _buildWelcomeText() {
    return Column(
      children: [
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
      ],
    );
  }

  Widget _buildFormFields() {
    return Column(
      children: [
        AppTextField(
          controller: _usernameController,
          label: AppStrings.username,
          hint: 'Enter your username',
          prefixIcon: Icons.person_outline_rounded,
          enabled: !_isLoading,
          validator: _validateUsername,
        ),
        SizedBox(height: ResponsiveValues.spacingL(context)),
        AppTextField.password(
          controller: _passwordController,
          label: AppStrings.password,
          hint: 'Enter your password',
          enabled: !_isLoading,
          validator: _validatePassword,
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return AppButton.primary(
      label: AppStrings.login,
      onPressed: _isLoading ? null : _handleLogin,
      isLoading: _isLoading,
      expanded: true,
    );
  }

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          AppStrings.dontHaveAccount,
          style: AppTextStyles.bodyMedium(context).copyWith(
            color: AppColors.getTextSecondary(context),
          ),
        ),
        SizedBox(width: ResponsiveValues.spacingXS(context)),
        GestureDetector(
          onTap: _isLoading ? null : () => context.push('/auth/register'),
          child: Text(
            AppStrings.register,
            style: AppTextStyles.bodyMedium(context).copyWith(
              color: AppColors.telegramBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isOffline) {
      return AppEmptyState.offline(
        message:
            'You are offline. Please check your internet connection to login.',
        onRetry: () {
          setState(() => _isOffline = false);
          _checkConnectivity();
        },
      );
    }

    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildLogo(),
          _buildWelcomeText(),
          SizedBox(height: ResponsiveValues.spacingXXL(context)),
          _buildFormFields(),
          SizedBox(height: ResponsiveValues.spacingXL(context)),
          _buildLoginButton(),
          SizedBox(height: ResponsiveValues.spacingL(context)),
          _buildRegisterLink(),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: ResponsiveValues.screenPadding(context),
          child: AppCard.glass(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: _buildContent(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabletLayout() {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: ResponsiveValues.screenPadding(context),
            child: AppCard.glass(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                child: _buildContent(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() => _buildTabletLayout();

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: _buildMobileLayout(),
      tablet: _buildTabletLayout(),
      desktop: _buildDesktopLayout(),
    ).animate().fadeIn(duration: AppThemes.animationMedium);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:familyacademyclient/providers/auth_provider.dart';
import 'package:familyacademyclient/widgets/auth/auth_form_field.dart';
import 'package:familyacademyclient/widgets/auth/password_field.dart';
import 'package:familyacademyclient/utils/helpers.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import 'package:familyacademyclient/utils/responsive_values.dart';
import 'package:familyacademyclient/themes/app_themes.dart';
import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';
import 'package:familyacademyclient/widgets/common/empty_state.dart';
import 'package:familyacademyclient/widgets/common/responsive_widgets.dart';

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
    final hasConnection = await hasInternetConnection();
    if (!hasConnection) {
      setState(() => _isOffline = true);
      showOfflineMessage(context);
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
    if (value == null || value.isEmpty) return 'Username is required';
    if (value.length < 3) return 'Username must be at least 3 characters';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    return null;
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final hasConnection = await hasInternetConnection();
    if (!hasConnection) {
      showTopSnackBar(
        context,
        'You are offline. Please check your internet connection.',
        isError: true,
      );
      setState(() => _isOffline = true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
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

        if (nextStep == 'select_school') {
          context.go('/school-selection');
        } else {
          context.go('/');
        }
      } else if (result['requiresDeviceChange'] == true) {
        await context.push('/device-change', extra: result['data']);
      } else {
        showTopSnackBar(context, result['message'] ?? 'Login failed',
            isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      showTopSnackBar(context, formatErrorMessage(e), isError: true);
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
        gradient: const LinearGradient(
          colors: [Color(0xFF2AABEE), Color(0xFF5856D6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
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
        child: ResponsiveIcon(
          Icons.school_rounded,
          size: ResponsiveValues.iconSizeXL(context),
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildWelcomeText() {
    return ResponsiveColumn(
      children: [
        ResponsiveText(
          'Welcome Back!',
          style: AppTextStyles.headlineMedium(context).copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const ResponsiveSizedBox(height: AppSpacing.s),
        ResponsiveText(
          'Sign in to continue your learning journey',
          style: AppTextStyles.bodyLarge(context).copyWith(
            color: AppColors.getTextSecondary(context),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFormFields() {
    return ResponsiveColumn(
      children: [
        AuthFormField(
          controller: _usernameController,
          label: 'Username',
          hintText: 'Enter your username',
          prefixIcon: Icons.person_outline_rounded,
          validator: _validateUsername,
          enabled: !_isLoading,
        ),
        const ResponsiveSizedBox(height: AppSpacing.l),
        PasswordField(
          controller: _passwordController,
          label: 'Password',
          hintText: 'Enter your password',
          enabled: !_isLoading,
          validator: _validatePassword,
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      height: ResponsiveValues.buttonHeightLarge(context),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.telegramBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              ResponsiveValues.radiusMedium(context),
            ),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? SizedBox(
                width: ResponsiveValues.iconSizeM(context),
                height: ResponsiveValues.iconSizeM(context),
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : ResponsiveText(
                'Login',
                style: AppTextStyles.buttonLarge(context).copyWith(
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildRegisterLink() {
    return ResponsiveRow(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ResponsiveText(
          "Don't have an account? ",
          style: AppTextStyles.bodyMedium(context).copyWith(
            color: AppColors.getTextSecondary(context),
          ),
        ),
        const ResponsiveSizedBox(width: AppSpacing.xs),
        GestureDetector(
          onTap: _isLoading ? null : () => context.push('/auth/register'),
          child: ResponsiveText(
            'Register',
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
      return OfflineState(
        dataType: 'login',
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
      child: ResponsiveColumn(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildLogo(),
          _buildWelcomeText(),
          const ResponsiveSizedBox(height: AppSpacing.xxl),
          _buildFormFields(),
          const ResponsiveSizedBox(height: AppSpacing.xl),
          _buildLoginButton(),
          const ResponsiveSizedBox(height: AppSpacing.l),
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
          child: ResponsiveContainer(
            maxWidth: 400,
            child: _buildContent(),
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
            child: ResponsiveContainer(
              maxWidth: 500,
              child: _buildContent(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: ResponsiveValues.screenPadding(context),
            child: ResponsiveContainer(
              maxWidth: 500,
              child: _buildContent(),
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
    ).animate().fadeIn(duration: AppThemes.animationDurationMedium);
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:familyacademyclient/providers/auth_provider.dart';
import 'package:familyacademyclient/services/user_session.dart';
import 'package:familyacademyclient/widgets/auth/auth_form_field.dart';
import 'package:familyacademyclient/widgets/auth/password_field.dart';
import 'package:familyacademyclient/widgets/common/loading_indicator.dart';
import 'package:familyacademyclient/utils/helpers.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import 'package:familyacademyclient/themes/app_themes.dart';
import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';
import 'package:familyacademyclient/widgets/common/empty_state.dart';

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
  bool _obscurePassword = true;

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
    if (value == null || value.isEmpty) {
      return 'Username is required';
    }
    if (value.length < 3) {
      return 'Username must be at least 3 characters';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
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
        context.push('/device-change', extra: result['data']);
      } else {
        showTopSnackBar(
          context,
          result['message'] ?? 'Login failed',
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      showTopSnackBar(
        context,
        formatErrorMessage(e),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isOffline) {
      return Scaffold(
        body: OfflineState(
          dataType: 'login',
          message:
              'You are offline. Please check your internet connection to login.',
          onRetry: () {
            setState(() => _isOffline = false);
            _checkConnectivity();
          },
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    final contentWidth =
        isMobile ? double.infinity : (isTablet ? 500.0 : 400.0);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(
              ScreenSize.responsiveValue(
                context: context,
                mobile: AppThemes.spacingXL,
                tablet: AppThemes.spacingXXL,
                desktop: AppThemes.spacingXXXL,
              ),
            ),
            child: Container(
              constraints: BoxConstraints(maxWidth: contentWidth),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo/Icon
                    Container(
                      width: 80,
                      height: 80,
                      margin: const EdgeInsets.only(bottom: 32),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2AABEE), Color(0xFF5856D6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:
                                AppColors.telegramBlue.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.school_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),

                    // Welcome Text
                    Text(
                      'Welcome Back!',
                      style: AppTextStyles.headlineMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to continue your learning journey',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.getTextSecondary(context),
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 32),

                    // Username Field
                    AuthFormField(
                      controller: _usernameController,
                      label: 'Username',
                      hintText: 'Enter your username',
                      prefixIcon: Icons.person_outline_rounded,
                      keyboardType: TextInputType.text,
                      validator:
                          _validateUsername, // 🔵 FIX: Using proper method
                      enabled: !_isLoading,
                    ),

                    const SizedBox(height: 16),

                    // Password Field
                    PasswordField(
                      controller: _passwordController,
                      label: 'Password',
                      hintText: 'Enter your password',
                      enabled: !_isLoading,
                      validator:
                          _validatePassword, // 🔵 FIX: Using proper method
                    ),

                    const SizedBox(height: 24),

                    // Login Button
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.telegramBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            : const Text(
                                'Login',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Register Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.getTextSecondary(context),
                          ),
                        ),
                        GestureDetector(
                          onTap: _isLoading
                              ? null
                              : () => context.push('/auth/register'),
                          child: Text(
                            'Register',
                            style: AppTextStyles.bodyMedium.copyWith(
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
}

import 'dart:async';
import 'dart:io';
import 'package:familyacademyclient/themes/app_themes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import 'package:familyacademyclient/utils/helpers.dart';
import 'package:familyacademyclient/providers/auth_provider.dart';
import 'package:familyacademyclient/providers/category_provider.dart';
import 'package:familyacademyclient/providers/subscription_provider.dart';
import 'package:familyacademyclient/services/device_service.dart';
import 'package:familyacademyclient/services/notification_service.dart';
import 'package:familyacademyclient/widgets/auth/auth_form_field.dart';
import 'package:familyacademyclient/widgets/auth/password_field.dart';
import 'package:familyacademyclient/utils/router.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isInitializing = false;
  String? _deviceId;
  String? _fcmToken;
  bool _servicesReady = false;
  bool _mounted = true;
  final NotificationService _notificationService = NotificationService();

  bool _isNavigating = false;

  late AnimationController _fadeInController;
  late AnimationController _slideController;

  @override
  void initState() {
    super.initState();

    _fadeInController = AnimationController(
      vsync: this,
      duration: AppThemes.animationDurationMedium,
    )..forward();

    _slideController = AnimationController(
      vsync: this,
      duration: AppThemes.animationDurationMedium,
    )..forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_mounted) {
        _initializeServices();
      }
    });
  }

  @override
  void dispose() {
    _mounted = false;
    _isNavigating = false;
    _usernameController.dispose();
    _passwordController.dispose();
    _fadeInController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_isLoading || _isNavigating) return;

    if (!_formKey.currentState!.validate()) return;

    if (!_servicesReady || _deviceId == null) {
      showSnackBar(
        context,
        'Please wait for service initialization',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);
    _isNavigating = true;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final subscriptionProvider = Provider.of<SubscriptionProvider>(
      context,
      listen: false,
    );
    final categoryProvider = Provider.of<CategoryProvider>(
      context,
      listen: false,
    );
    final deviceService = Provider.of<DeviceService>(context, listen: false);

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    try {
      debugLog('LoginScreen', '🔐 Attempting login for user: $username');

      await deviceService.clearUserCache();
      await deviceService.clearAllCache();

      final loginResult = await authProvider.login(
        username,
        password,
        _deviceId!,
        _fcmToken,
      );

      if (!_mounted) return;

      if (loginResult['success'] == true) {
        debugLog('LoginScreen', '✅ Login successful');

        await _loadCachedDataInBackground(
          subscriptionProvider,
          categoryProvider,
        );

        if (Platform.isAndroid || Platform.isIOS && _fcmToken != null) {
          _sendFcmTokenInBackground();
        }

        FocusScope.of(context).unfocus();

        await Future.delayed(const Duration(milliseconds: 100));

        if (!_mounted) return;

        final user = authProvider.currentUser;
        if (user != null) {
          debugLog('LoginScreen', '👤 User loaded, navigating...');

          if (user.schoolId == null) {
            debugLog('LoginScreen',
                '🏫 No school selected, going to school selection');
            appRouter.setNavigatingToSchoolSelection(true);
            appRouter.setPendingDestination('/school-selection');

            if (_mounted && context.mounted) {
              context.go('/school-selection');
            }
          } else {
            debugLog('LoginScreen', '🏠 Going to home screen');
            appRouter.setNavigatingToHome(true);
            appRouter.setPendingDestination('/');

            if (_mounted && context.mounted) {
              context.go('/');
            }
          }
        }
      } else if (loginResult['requiresDeviceChange'] == true) {
        debugLog('LoginScreen',
            '⚠️ Device change required, preparing navigation...');

        _isNavigating = true;

        await Future.delayed(const Duration(milliseconds: 100));

        if (_mounted) {
          _navigateToDeviceChange(username, password, loginResult);
        }
      } else {
        showSnackBar(
          context,
          loginResult['message'] ?? 'Login failed',
          isError: true,
        );
        _isNavigating = false;
      }
    } catch (e) {
      debugLog('LoginScreen', '❌ Login error: $e');
      showSimpleSnackBar(context, 'Login failed. Please try again.',
          isError: true);
      _isNavigating = false;
    } finally {
      if (_mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToDeviceChange(
    String username,
    String password,
    Map<String, dynamic> loginResult,
  ) {
    final deviceChangeData = loginResult['data'] as Map<String, dynamic>? ?? {};

    debugLog('LoginScreen',
        '🚗 Navigating to device change with data: $deviceChangeData');
    debugLog('LoginScreen', '📱 Current device ID: $_deviceId');
    debugLog('LoginScreen', '👤 Username: $username');

    final extraData = {
      'username': username,
      'password': password,
      'deviceId': _deviceId,
      'fcmToken': _fcmToken,
      'currentDeviceId': deviceChangeData['currentDeviceId'] ?? 'Unknown',
      'newDeviceId': deviceChangeData['newDeviceId'] ?? _deviceId,
      'changeCount': deviceChangeData['changeCount'] ?? 0,
      'maxChanges': deviceChangeData['maxChanges'] ?? 2,
      'remainingChanges': deviceChangeData['remainingChanges'] ?? 2,
      'canChangeDevice': deviceChangeData['canChangeDevice'] ?? true,
    };

    debugLog('LoginScreen', '📦 Navigation extra: $extraData');

    if (_mounted && context.mounted) {
      try {
        context.go('/device-change', extra: extraData);
        debugLog('LoginScreen', '✅ Navigation to device-change completed');
      } catch (e) {
        debugLog('LoginScreen', '❌ Navigation error: $e');
        Navigator.pushNamed(context, '/device-change', arguments: extraData);
      }
    } else {
      debugLog('LoginScreen', '❌ Cannot navigate - context not mounted');
    }

    _isNavigating = false;
  }

  Future<void> _initializeServices() async {
    if (_isInitializing || !_mounted) return;

    _isInitializing = true;

    try {
      final deviceService = Provider.of<DeviceService>(context, listen: false);
      await deviceService.init();

      final deviceId = await deviceService.getDeviceId();

      if (Platform.isAndroid || Platform.isIOS) {
        await _notificationService.init();
        _fcmToken = await _notificationService.getFCMToken();
      }

      if (_mounted) {
        setState(() {
          _deviceId = deviceId;
          _servicesReady = true;
          _isInitializing = false;
        });
      }

      debugLog(
        'LoginScreen',
        '✅ Services ready. Device ID: ${_deviceId?.substring(0, 10)}...',
      );
    } catch (e) {
      debugLog('LoginScreen', '❌ Service initialization error: $e');
      if (_mounted) {
        setState(() {
          _isInitializing = false;
          _servicesReady = false;
        });
        if (Platform.isAndroid || Platform.isIOS) {
          showSnackBar(
            context,
            'Service initialization failed. Please restart the app.',
            isError: true,
          );
        }
      }
    }
  }

  Future<void> _loadCachedDataInBackground(
    SubscriptionProvider subscriptionProvider,
    CategoryProvider categoryProvider,
  ) async {
    try {
      await subscriptionProvider.loadSubscriptions();
      await categoryProvider.loadCategories();

      unawaited(subscriptionProvider.loadSubscriptions(forceRefresh: true));
      unawaited(categoryProvider.loadCategories(forceRefresh: true));
    } catch (e) {
      debugLog('LoginScreen', 'Error loading cached data: $e');
    }
  }

  void _sendFcmTokenInBackground() {
    unawaited(_notificationService.sendFcmTokenToBackendIfAuthenticated());
  }

  Widget _buildMobileLogin() {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppThemes.spacingL,
              vertical: AppThemes.spacingXL,
            ),
            child: _buildLoginContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildTabletLogin() {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: ScreenSize.responsiveValue(
              context: context,
              mobile: 500,
              tablet: 600,
              desktop: 700,
            ),
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Container(
              padding: EdgeInsets.all(AppThemes.spacingXL),
              decoration: BoxDecoration(
                color: AppColors.getCard(context),
                borderRadius:
                    BorderRadius.circular(AppThemes.borderRadiusLarge),
                border: Border.all(
                  color: Theme.of(context).dividerColor,
                  width: 0.5,
                ),
              ),
              child: _buildLoginContent(showLogo: true),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLogin() {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: ScreenSize.responsiveValue(
              context: context,
              mobile: 500,
              tablet: 800,
              desktop: 1000,
            ),
            maxHeight: 600,
          ),
          decoration: BoxDecoration(
            color: AppColors.getCard(context),
            borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(AppThemes.spacingXXXL),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: AppColors.blueGradient,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(AppThemes.borderRadiusLarge),
                      bottomLeft: Radius.circular(AppThemes.borderRadiusLarge),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(
                            AppThemes.borderRadiusXLarge,
                          ),
                        ),
                        child: Icon(
                          Icons.school_rounded,
                          size: 48,
                          color: Colors.white,
                        ),
                      ).animate().scale(
                            duration: 600.ms,
                            curve: Curves.elasticOut,
                          ),
                      SizedBox(height: AppThemes.spacingXXL),
                      Text(
                        'Family Academy',
                        style: AppTextStyles.displaySmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: AppThemes.spacingL),
                      Text(
                        'Premium Education Platform',
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: AppThemes.spacingXXL),
                      _buildFeatureItem('Access all courses'),
                      SizedBox(height: AppThemes.spacingM),
                      _buildFeatureItem('Track your progress'),
                      SizedBox(height: AppThemes.spacingM),
                      _buildFeatureItem('Take exams online'),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Container(
                    padding: EdgeInsets.all(AppThemes.spacingXXXL),
                    child: _buildLoginContent(showLogo: false),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.check_circle_rounded,
          color: Colors.white,
          size: 20,
        ),
        SizedBox(width: AppThemes.spacingM),
        Text(
          text,
          style: AppTextStyles.bodyMedium.copyWith(
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginContent({bool showLogo = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLogo) ...[
          SizedBox(height: AppThemes.spacingXXL),
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: AppColors.blueGradient),
                borderRadius: BorderRadius.circular(
                  AppThemes.borderRadiusLarge,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.telegramBlue.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                Icons.school_rounded,
                size: 40,
                color: Colors.white,
              ),
            ).animate().scale(
                  duration: 600.ms,
                  curve: Curves.elasticOut,
                ),
          ),
          SizedBox(height: AppThemes.spacingXL),
        ],
        Text(
          'Welcome Back',
          style: AppTextStyles.headlineLarge.copyWith(
            color: AppColors.getTextPrimary(context),
            fontWeight: FontWeight.w700,
          ),
        )
            .animate()
            .fadeIn(
              duration: AppThemes.animationDurationMedium,
              delay: 100.ms,
            )
            .slideX(
              begin: -0.1,
              end: 0,
              duration: AppThemes.animationDurationMedium,
              delay: 100.ms,
            ),
        SizedBox(height: AppThemes.spacingS),
        Text(
          'Sign in to continue learning',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.getTextSecondary(context),
          ),
        )
            .animate()
            .fadeIn(
              duration: AppThemes.animationDurationMedium,
              delay: 200.ms,
            )
            .slideX(
              begin: -0.1,
              end: 0,
              duration: AppThemes.animationDurationMedium,
              delay: 200.ms,
            ),
        SizedBox(height: AppThemes.spacingXXXL),
        if (_isInitializing) _buildInitializationIndicator(),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthFormField(
                controller: _usernameController,
                label: 'Username',
                hintText: 'Enter your username',
                prefixIcon: Icons.person_outline_rounded,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Username is required';
                  }
                  if (value.length < 3) {
                    return 'Username must be at least 3 characters';
                  }
                  return null;
                },
              )
                  .animate()
                  .fadeIn(
                    duration: AppThemes.animationDurationMedium,
                    delay: 300.ms,
                  )
                  .slideX(
                    begin: -0.1,
                    end: 0,
                    duration: AppThemes.animationDurationMedium,
                    delay: 300.ms,
                  ),
              SizedBox(height: AppThemes.spacingXL),
              PasswordField(
                controller: _passwordController,
                label: 'Password',
                hintText: 'Enter your password',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Password is required';
                  }
                  return null;
                },
              )
                  .animate()
                  .fadeIn(
                    duration: AppThemes.animationDurationMedium,
                    delay: 400.ms,
                  )
                  .slideX(
                    begin: -0.1,
                    end: 0,
                    duration: AppThemes.animationDurationMedium,
                    delay: 400.ms,
                  ),
              SizedBox(height: AppThemes.spacingXL),
              ElevatedButton(
                onPressed: (_isLoading || !_servicesReady) ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.telegramBlue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: AppThemes.spacingL),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppThemes.borderRadiusMedium,
                    ),
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
                          Text(
                            'Sign In',
                            style: AppTextStyles.buttonMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: AppThemes.spacingS),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 20,
                          ),
                        ],
                      ),
              ).animate().scale(
                    duration: 300.ms,
                    delay: 500.ms,
                  ),
              SizedBox(height: AppThemes.spacingXXL),
              Center(
                child: TextButton(
                  onPressed: () {
                    context.go('/auth/register');
                  },
                  child: RichText(
                    text: TextSpan(
                      text: 'Don\'t have an account? ',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.getTextSecondary(context),
                      ),
                      children: [
                        TextSpan(
                          text: 'Sign up',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.telegramBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ).animate().fadeIn(
                    duration: AppThemes.animationDurationMedium,
                    delay: 600.ms,
                  ),
            ],
          ),
        ),
        if (!_servicesReady && !_isInitializing) ...[
          SizedBox(height: AppThemes.spacingXL),
          Container(
            padding: EdgeInsets.all(AppThemes.spacingM),
            decoration: BoxDecoration(
              color: AppColors.getStatusBackground('pending', context),
              borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
              border: Border.all(
                color: AppColors.getStatusColor('pending', context),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: AppColors.getStatusColor('pending', context),
                ),
                SizedBox(width: AppThemes.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Initializing...',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.getStatusColor('pending', context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: AppThemes.spacingXS),
                      Text(
                        'Preparing app services. This may take a moment.',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.getTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: AppThemes.animationDurationMedium),
        ],
        SizedBox(height: AppThemes.spacingXXL),
      ],
    );
  }

  Widget _buildInitializationIndicator() {
    return Container(
      margin: EdgeInsets.only(bottom: AppThemes.spacingXL),
      padding: EdgeInsets.all(AppThemes.spacingM),
      decoration: BoxDecoration(
        color: AppColors.telegramBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
        border: Border.all(
          color: AppColors.telegramBlue,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.telegramBlue,
              ),
            ),
          ),
          SizedBox(width: AppThemes.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Preparing app...',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.telegramBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: AppThemes.spacingXS),
                Text(
                  'Setting up services for the best experience',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: AppThemes.animationDurationMedium);
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: _buildMobileLogin(),
      tablet: _buildTabletLogin(),
      desktop: _buildDesktopLogin(),
    ).animate().fadeIn(duration: AppThemes.animationDurationMedium);
  }
}

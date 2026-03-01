import 'dart:async';
import 'dart:io';
import 'dart:ui';
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
        vsync: this, duration: AppThemes.animationDurationMedium)
      ..forward();
    _slideController = AnimationController(
        vsync: this, duration: AppThemes.animationDurationMedium)
      ..forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_mounted) _initializeServices();
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
    } catch (e) {
      if (_mounted) {
        setState(() {
          _isInitializing = false;
          _servicesReady = false;
        });
        if (Platform.isAndroid || Platform.isIOS) {
          showTopSnackBar(
              context, 'Service initialization failed. Please restart the app.',
              isError: true);
        }
      }
    }
  }

  Future<void> _login() async {
    if (_isLoading || _isNavigating) return;
    if (!_formKey.currentState!.validate()) return;
    if (!_servicesReady || _deviceId == null) {
      showTopSnackBar(context, 'Please wait for service initialization',
          isError: true);
      return;
    }

    setState(() => _isLoading = true);
    _isNavigating = true;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final subscriptionProvider =
        Provider.of<SubscriptionProvider>(context, listen: false);
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);
    final deviceService = Provider.of<DeviceService>(context, listen: false);

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    try {
      await deviceService.clearUserCache();
      await deviceService.clearAllCache();

      final loginResult =
          await authProvider.login(username, password, _deviceId!, _fcmToken);

      if (!_mounted) return;

      if (loginResult['success'] == true) {
        await _loadCachedDataInBackground(
            subscriptionProvider, categoryProvider);

        if (Platform.isAndroid || Platform.isIOS && _fcmToken != null) {
          _sendFcmTokenInBackground();
        }

        FocusScope.of(context).unfocus();
        await Future.delayed(const Duration(milliseconds: 100));

        if (!_mounted) return;

        final user = authProvider.currentUser;
        if (user != null) {
          if (user.schoolId == null) {
            appRouter.setNavigatingToSchoolSelection(true);
            appRouter.setPendingDestination('/school-selection');
            if (_mounted && context.mounted) context.go('/school-selection');
          } else {
            appRouter.setNavigatingToHome(true);
            appRouter.setPendingDestination('/');
            if (_mounted && context.mounted) context.go('/');
          }
        }
      } else if (loginResult['requiresDeviceChange'] == true) {
        _isNavigating = true;
        await Future.delayed(const Duration(milliseconds: 100));
        if (_mounted) _navigateToDeviceChange(username, password, loginResult);
      } else {
        showTopSnackBar(context, loginResult['message'] ?? 'Login failed',
            isError: true);
        _isNavigating = false;
      }
    } catch (e) {
      showTopSnackBar(context, 'Login failed. Please try again.',
          isError: true);
      _isNavigating = false;
    } finally {
      if (_mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToDeviceChange(
      String username, String password, Map<String, dynamic> loginResult) {
    final deviceChangeData = loginResult['data'] as Map<String, dynamic>? ?? {};

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

    if (_mounted && context.mounted) {
      try {
        context.go('/device-change', extra: extraData);
      } catch (e) {
        Navigator.pushNamed(context, '/device-change', arguments: extraData);
      }
    }
    _isNavigating = false;
  }

  Future<void> _loadCachedDataInBackground(
      SubscriptionProvider subscriptionProvider,
      CategoryProvider categoryProvider) async {
    try {
      await subscriptionProvider.loadSubscriptions();
      await categoryProvider.loadCategories();
      unawaited(subscriptionProvider.loadSubscriptions(forceRefresh: true));
      unawaited(categoryProvider.loadCategories(forceRefresh: true));
    } catch (e) {}
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
                  context: context, mobile: 500, tablet: 600, desktop: 700)),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: _buildGlassContainer(
              child: Container(
                padding: const EdgeInsets.all(24),
                child: _buildLoginContent(),
              ),
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
                  context: context, mobile: 500, tablet: 800, desktop: 1000),
              maxHeight: 600),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(48),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        colors: AppColors.blueGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(24),
                        bottomLeft: Radius.circular(24)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20)),
                        child: const Icon(Icons.school_rounded,
                            size: 48, color: Colors.white),
                      )
                          .animate()
                          .scale(duration: 600.ms, curve: Curves.elasticOut),
                      const SizedBox(height: 32),
                      const Text('Family Academy',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w800),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      const Text('Premium Education Platform',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 32),
                      _buildFeatureItem('Access all courses'),
                      const SizedBox(height: 12),
                      _buildFeatureItem('Track your progress'),
                      const SizedBox(height: 12),
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
                    padding: const EdgeInsets.all(48),
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
        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
        const SizedBox(width: 12),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 16)),
      ],
    );
  }

  Widget _buildLoginContent({bool showLogo = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLogo) ...[
          const SizedBox(height: 32),
          Align(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: AppColors.blueGradient),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.telegramBlue.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 2)
                ],
              ),
              child: const Icon(Icons.school_rounded,
                  size: 40, color: Colors.white),
            ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
          ),
          const SizedBox(height: 24),
        ],
        Text('Welcome Back',
                style: AppTextStyles.headlineLarge.copyWith(
                    color: AppColors.getTextPrimary(context),
                    fontWeight: FontWeight.w700))
            .animate()
            .fadeIn(duration: 300.ms, delay: 100.ms)
            .slideX(begin: -0.1, end: 0, duration: 300.ms, delay: 100.ms),
        const SizedBox(height: 8),
        Text('Sign in to continue learning',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.getTextSecondary(context)))
            .animate()
            .fadeIn(duration: 300.ms, delay: 200.ms)
            .slideX(begin: -0.1, end: 0, duration: 300.ms, delay: 200.ms),
        const SizedBox(height: 48),
        if (_isInitializing) _buildInitializationIndicator(),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildGlassContainer(
                child: AuthFormField(
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
                ),
              )
                  .animate()
                  .fadeIn(duration: 300.ms, delay: 300.ms)
                  .slideX(begin: -0.1, end: 0, duration: 300.ms, delay: 300.ms),
              const SizedBox(height: 16),
              _buildGlassContainer(
                child: PasswordField(
                  controller: _passwordController,
                  label: 'Password',
                  hintText: 'Enter your password',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    return null;
                  },
                ),
              )
                  .animate()
                  .fadeIn(duration: 300.ms, delay: 400.ms)
                  .slideX(begin: -0.1, end: 0, duration: 300.ms, delay: 400.ms),
              const SizedBox(height: 24),
              _buildGlassButton(
                label: _isLoading ? 'Signing In...' : 'Sign In',
                onPressed: _login,
                gradient: const [Color(0xFF2AABEE), Color(0xFF5856D6)],
                isLoading: _isLoading,
                isEnabled: !_isLoading && _servicesReady,
              ).animate().scale(duration: 300.ms, delay: 500.ms),
              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: () => context.go('/auth/register'),
                  child: RichText(
                    text: TextSpan(
                      text: 'Don\'t have an account? ',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.getTextSecondary(context)),
                      children: [
                        TextSpan(
                            text: 'Sign up',
                            style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.telegramBlue,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ).animate().fadeIn(duration: 300.ms, delay: 600.ms),
            ],
          ),
        ),
        if (!_servicesReady && !_isInitializing) ...[
          const SizedBox(height: 16),
          _buildGlassContainer(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 16,
                      color: AppColors.getStatusColor('pending', context)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Initializing...',
                            style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.getStatusColor(
                                    'pending', context),
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('Preparing app services. This may take a moment.',
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.getTextSecondary(context))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 300.ms),
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildInitializationIndicator() {
    return _buildGlassContainer(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.telegramBlue))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Preparing app...',
                      style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.telegramBlue,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Setting up services for the best experience',
                      style: AppTextStyles.caption.copyWith(
                          color: AppColors.getTextSecondary(context))),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: _buildMobileLogin(),
      tablet: _buildTabletLogin(),
      desktop: _buildDesktopLogin(),
    ).animate().fadeIn(duration: 600.ms);
  }
}

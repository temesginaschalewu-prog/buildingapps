import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:familyacademyclient/providers/auth_provider.dart';
import 'package:familyacademyclient/services/user_session.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import 'package:familyacademyclient/utils/helpers.dart';
import 'package:familyacademyclient/services/device_service.dart';
import 'package:familyacademyclient/services/notification_service.dart';
import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';
import 'package:familyacademyclient/utils/router.dart';
import 'package:familyacademyclient/widgets/common/empty_state.dart';
import 'package:familyacademyclient/widgets/auth/auth_form_field.dart';
import 'package:familyacademyclient/widgets/auth/password_field.dart';

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
    final hasConnection = await hasInternetConnection();
    if (!hasConnection) {
      setState(() => _isOffline = true);
      showOfflineMessage(context);
    }
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

  Future<void> _initializeDeviceAndServices() async {
    if (!_mounted || _isInitializing) return;
    _isInitializing = true;
    if (_mounted) setState(() {});

    try {
      _deviceService = Provider.of<DeviceService>(context, listen: false);
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
          showTopSnackBar(
              context, 'Service initialization failed. Please restart the app.',
              isError: true);
        }
      }
    }
  }

  String? _validateUsername(String? value) {
    if (value == null || value.isEmpty) return 'Username is required';
    if (value.length < 3) return 'Username must be at least 3 characters';
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
      return 'Only letters, numbers and underscore allowed';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  Future<void> _register() async {
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

    if (_deviceId == null || _deviceId!.isEmpty) {
      showTopSnackBar(context, 'Device not ready. Please restart the app.',
          isError: true);
      return;
    }

    if (_mounted) setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
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
        showTopSnackBar(context, 'Registration successful!');
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
        showTopSnackBar(context, result['message'] ?? 'Registration failed',
            isError: true);
      }
    } catch (e) {
      if (_mounted) {
        showTopSnackBar(context, formatErrorMessage(e), isError: true);
      }
    } finally {
      if (_mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildHeader() {
    return Column(
      children: [
        SizedBox(height: ScreenSize.isDesktop(context) ? 40 : 20),
        ScaleTransition(
          scale: _logoScaleAnimation,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: AppColors.blueGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: AppColors.telegramBlue.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 2)
              ],
            ),
            child:
                const Icon(Icons.school_rounded, size: 40, color: Colors.white),
          ),
        ),
        const SizedBox(height: 24),
        Text('Create Account',
            style: AppTextStyles.displaySmall.copyWith(
                color: AppColors.getTextPrimary(context),
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('Join Family Academy',
            style: AppTextStyles.bodyLarge
                .copyWith(color: AppColors.getTextSecondary(context))),
      ],
    );
  }

  Widget _buildUsernameField() {
    return _buildGlassContainer(
      child: TextFormField(
        controller: _usernameController,
        decoration: InputDecoration(
          hintText: 'Username',
          hintStyle: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.getTextSecondary(context)),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          prefixIcon: Icon(Icons.person_outline_rounded,
              color: AppColors.getTextSecondary(context), size: 20),
          suffixIcon: _usernameController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear_rounded,
                      color: AppColors.getTextSecondary(context), size: 20),
                  onPressed: () {
                    _usernameController.clear();
                    setState(() {});
                  },
                )
              : null,
        ),
        style: AppTextStyles.bodyLarge
            .copyWith(color: AppColors.getTextPrimary(context)),
        validator: _validateUsername, // 🔵 FIX: Using proper method
        onChanged: (value) => setState(() {}),
        enabled: !_isLoading,
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms, delay: 100.ms)
        .slideX(begin: -0.1, end: 0, duration: 300.ms, delay: 100.ms);
  }

  Widget _buildPasswordField() {
    bool obscureText = true;

    return StatefulBuilder(
      builder: (context, setState) {
        return _buildGlassContainer(
          child: TextFormField(
            controller: _passwordController,
            obscureText: obscureText,
            decoration: InputDecoration(
              hintText: 'Password',
              hintStyle: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.getTextSecondary(context)),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              prefixIcon: Icon(Icons.lock_outline_rounded,
                  color: AppColors.getTextSecondary(context), size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                    obscureText
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: AppColors.getTextSecondary(context),
                    size: 20),
                onPressed: () => setState(() => obscureText = !obscureText),
              ),
            ),
            style: AppTextStyles.bodyLarge
                .copyWith(color: AppColors.getTextPrimary(context)),
            validator: _validatePassword, // 🔵 FIX: Using proper method
            enabled: !_isLoading,
          ),
        );
      },
    )
        .animate()
        .fadeIn(duration: 300.ms, delay: 200.ms)
        .slideX(begin: -0.1, end: 0, duration: 300.ms, delay: 200.ms);
  }

  Widget _buildConfirmPasswordField() {
    bool obscureText = true;

    return StatefulBuilder(
      builder: (context, setState) {
        return _buildGlassContainer(
          child: TextFormField(
            controller: _confirmPasswordController,
            obscureText: obscureText,
            decoration: InputDecoration(
              hintText: 'Confirm Password',
              hintStyle: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.getTextSecondary(context)),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              prefixIcon: Icon(Icons.lock_outline_rounded,
                  color: AppColors.getTextSecondary(context), size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                    obscureText
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: AppColors.getTextSecondary(context),
                    size: 20),
                onPressed: () => setState(() => obscureText = !obscureText),
              ),
            ),
            style: AppTextStyles.bodyLarge
                .copyWith(color: AppColors.getTextPrimary(context)),
            validator: _validateConfirmPassword, // 🔵 FIX: Using proper method
            enabled: !_isLoading,
          ),
        );
      },
    )
        .animate()
        .fadeIn(duration: 300.ms, delay: 300.ms)
        .slideX(begin: -0.1, end: 0, duration: 300.ms, delay: 300.ms);
  }

  Widget _buildForm() {
    if (_isOffline) {
      return OfflineState(
        dataType: 'registration',
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
          const SizedBox(height: 40),
          _buildUsernameField(),
          const SizedBox(height: 16),
          _buildPasswordField(),
          const SizedBox(height: 16),
          _buildConfirmPasswordField(),
          const SizedBox(height: 32),
          _buildGlassButton(
            label: _deviceId == null
                ? 'Initializing...'
                : (_isLoading ? 'Creating Account...' : 'Create Account'),
            onPressed: _register,
            gradient: const [Color(0xFF2AABEE), Color(0xFF5856D6)],
            isLoading: _isLoading,
            isEnabled: !_isLoading && _deviceId != null,
          )
              .animate()
              .scale(duration: 300.ms, curve: Curves.easeOut, delay: 400.ms),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Already have an account?',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.getTextSecondary(context))),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: _isLoading ? null : () => context.go('/auth/login'),
                child: Text('Sign in',
                    style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.telegramBlue,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ).animate().fadeIn(duration: 300.ms, delay: 500.ms),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 20),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: _buildForm(),
        ),
      ),
    );
  }

  Widget _buildTabletLayout() {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
              child: _buildGlassContainer(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: _buildForm(),
                ),
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
            constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 700),
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
                      borderRadius:
                          BorderRadius.horizontal(left: Radius.circular(24)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20)),
                          child: const Icon(Icons.school_rounded,
                              size: 60, color: Colors.white),
                        ),
                        const SizedBox(height: 40),
                        const Text('Welcome to\nFamily Academy',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w800),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        const Text(
                          'Join thousands of students learning with our comprehensive educational platform',
                          style: TextStyle(color: Colors.white, fontSize: 16),
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
                      padding: const EdgeInsets.all(48),
                      child: _buildForm(),
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

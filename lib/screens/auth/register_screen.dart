import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/responsive.dart';
import '../../themes/app_themes.dart';
import '../../utils/helpers.dart';
import '../../services/device_service.dart';
import '../../services/notification_service.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';

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

    _logoAnimationController = AnimationController(
      vsync: this,
      duration: 600.ms,
    )..forward();

    _logoScaleAnimation = CurvedAnimation(
      parent: _logoAnimationController,
      curve: Curves.elasticOut,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_mounted) {
        _initializeDeviceAndServices();
      }
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

  Future<void> _initializeDeviceAndServices() async {
    if (!_mounted || _isInitializing) return;

    _isInitializing = true;
    if (_mounted) setState(() {});

    try {
      _deviceService = Provider.of<DeviceService>(context, listen: false);
      await _deviceService!.init();

      final deviceId = await _deviceService!.getDeviceId();

      // Initialize notification service
      await _notificationService.init();

      // Only get FCM token on mobile platforms
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

      debugLog('RegisterScreen',
          '✅ Services initialized. Device ID: ${deviceId.substring(0, 10)}..., FCM Token: ${fcmToken != null}');
    } catch (e) {
      debugLog('RegisterScreen', '❌ Error initializing services: $e');
      if (_mounted) {
        setState(() {
          _isInitializing = false;
        });
        // Only show error for mobile platforms
        if (Platform.isAndroid || Platform.isIOS) {
          _showTelegramSnackBar(
            context,
            'Service initialization failed. Please restart the app.',
            isError: true,
          );
        }
      }
    }
  }

  void _showTelegramSnackBar(BuildContext context, String message,
      {bool isError = false}) {
    final overlay = Overlay.of(context);
    if (overlay == null) return;

    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: isError ? AppColors.telegramRed : AppColors.telegramGreen,
              borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  isError
                      ? Icons.error_outline_rounded
                      : Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          )
              .animate()
              .slideY(
                begin: -1,
                end: 0,
                duration: 300.ms,
                curve: Curves.easeOut,
              )
              .fadeIn(duration: 300.ms),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 3), () {
      overlayEntry.remove();
    });
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_deviceId == null || _deviceId!.isEmpty) {
      _showTelegramSnackBar(
          context, 'Device not ready. Please restart the app.',
          isError: true);
      return;
    }

    if (_mounted) {
      setState(() => _isLoading = true);
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    // Only get FCM token on mobile platforms
    if (Platform.isAndroid || Platform.isIOS && _fcmToken == null) {
      try {
        final fcmToken = await _notificationService.getFCMToken();
        if (fcmToken != null) {
          _fcmToken = fcmToken;
        }
      } catch (e) {
        debugLog('RegisterScreen', '⚠️ Failed to get FCM token: $e');
      }
    }

    try {
      debugLog('RegisterScreen',
          '📝 Registering with device ID: ${_deviceId!.substring(0, 15)}... and FCM: ${_fcmToken != null}');

      if (_deviceService != null) {
        await _deviceService!.clearAllCache();
        debugLog('RegisterScreen', '🧹 Cleared all cache before registration');
      }

      final result = await authProvider.register(
          username, password, _deviceId!, _fcmToken);

      if (result['success'] == true && _mounted) {
        debugLog('RegisterScreen',
            '✅ Registration successful, checking next step: ${result['next_step']}');

        if (_deviceService != null) {
          await _deviceService!.clearUserCache();
        }

        // Show success message
        _showTelegramSnackBar(context, 'Registration successful!');

        // ADD DELAY for better UX
        await Future.delayed(const Duration(milliseconds: 800));

        if (_mounted) {
          if (result['next_step'] == 'select_school') {
            debugLog('RegisterScreen', '🏫 Redirecting to school selection');
            context.go('/school-selection');
          } else {
            debugLog('RegisterScreen', '🏠 Redirecting to home');
            context.go('/');
          }
        }
      } else if (_mounted) {
        final errorMessage = result['message'] ?? 'Registration failed';
        debugLog('RegisterScreen', '❌ Registration failed: $errorMessage');
        _showTelegramSnackBar(context, errorMessage, isError: true);
      }
    } catch (e) {
      if (_mounted) {
        debugLog('RegisterScreen', '❌ Registration exception: $e');
        _showTelegramSnackBar(context, 'Registration failed: ${e.toString()}',
            isError: true);
      }
    } finally {
      if (_mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 🎨 Logo Header
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
              gradient: LinearGradient(
                colors: AppColors.blueGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
              boxShadow: [
                BoxShadow(
                  color: AppColors.telegramBlue.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.school_rounded,
              size: 40,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Create Account',
          style: AppTextStyles.displaySmall.copyWith(
            color: AppColors.getTextPrimary(context),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Join Family Academy',
          style: AppTextStyles.bodyLarge.copyWith(
            color: AppColors.getTextSecondary(context),
          ),
        ),
      ],
    );
  }

  // 👤 Username Field
  Widget _buildUsernameField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
      ),
      child: TextFormField(
        controller: _usernameController,
        decoration: InputDecoration(
          hintText: 'Username',
          hintStyle: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.getTextSecondary(context),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          prefixIcon: Icon(
            Icons.person_outline_rounded,
            color: AppColors.getTextSecondary(context),
            size: 20,
          ),
          suffixIcon: _usernameController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear_rounded,
                    color: AppColors.getTextSecondary(context),
                    size: 20,
                  ),
                  onPressed: () {
                    _usernameController.clear();
                    setState(() {});
                  },
                )
              : null,
        ),
        style: AppTextStyles.bodyLarge.copyWith(
          color: AppColors.getTextPrimary(context),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Username is required';
          }
          if (value.length < 3) {
            return 'Username must be at least 3 characters';
          }
          if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
            return 'Only letters, numbers and underscore allowed';
          }
          return null;
        },
        onChanged: (value) => setState(() {}),
      ),
    ).animate().fadeIn(duration: 300.ms, delay: 100.ms).slideX(
          begin: -0.1,
          end: 0,
          duration: 300.ms,
          delay: 100.ms,
        );
  }

  // 🔒 Password Field
  Widget _buildPasswordField() {
    bool _obscureText = true;

    return StatefulBuilder(
      builder: (context, setState) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.getSurface(context),
            borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
          ),
          child: TextFormField(
            controller: _passwordController,
            obscureText: _obscureText,
            decoration: InputDecoration(
              hintText: 'Password',
              hintStyle: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.getTextSecondary(context),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              prefixIcon: Icon(
                Icons.lock_outline_rounded,
                color: AppColors.getTextSecondary(context),
                size: 20,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureText
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: AppColors.getTextSecondary(context),
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _obscureText = !_obscureText;
                  });
                },
              ),
            ),
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.getTextPrimary(context),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Password is required';
              }
              if (value.length < 8) {
                return 'Password must be at least 8 characters';
              }
              return null;
            },
          ),
        );
      },
    ).animate().fadeIn(duration: 300.ms, delay: 200.ms).slideX(
          begin: -0.1,
          end: 0,
          duration: 300.ms,
          delay: 200.ms,
        );
  }

  // 🔐 Confirm Password Field
  Widget _buildConfirmPasswordField() {
    bool _obscureText = true;

    return StatefulBuilder(
      builder: (context, setState) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.getSurface(context),
            borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
          ),
          child: TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureText,
            decoration: InputDecoration(
              hintText: 'Confirm Password',
              hintStyle: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.getTextSecondary(context),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              prefixIcon: Icon(
                Icons.lock_outline_rounded,
                color: AppColors.getTextSecondary(context),
                size: 20,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureText
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: AppColors.getTextSecondary(context),
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _obscureText = !_obscureText;
                  });
                },
              ),
            ),
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.getTextPrimary(context),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm your password';
              }
              if (value != _passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
        );
      },
    ).animate().fadeIn(duration: 300.ms, delay: 300.ms).slideX(
          begin: -0.1,
          end: 0,
          duration: 300.ms,
          delay: 300.ms,
        );
  }

  // 📱 Device Status Indicator
  Widget _buildDeviceStatus() {
    if (_isInitializing) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.telegramBlue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
          border: Border.all(
            color: AppColors.telegramBlue,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(AppColors.telegramBlue),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Initializing device...',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.telegramBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Setting up your device for the best experience',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.telegramBlue.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms);
    }

    if (_deviceId != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.telegramGreen.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
          border: Border.all(
            color: AppColors.telegramGreen,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: AppColors.telegramGreen,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Device Ready',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.telegramGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Your device is connected and ready',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.telegramGreen.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms);
    }

    return const SizedBox.shrink();
  }

  // 🚀 Register Button
  Widget _buildRegisterButton() {
    final isDisabled = _isLoading || _isInitializing || _deviceId == null;

    return Container(
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
        gradient: LinearGradient(
          colors: isDisabled
              ? [
                  AppColors.telegramBlue.withOpacity(0.5),
                  AppColors.telegramBlue.withOpacity(0.5)
                ]
              : AppColors.blueGradient,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDisabled ? null : _register,
          borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
          child: Container(
            alignment: Alignment.center,
            child: _isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _deviceId == null
                            ? 'Initializing...'
                            : 'Create Account',
                        style: AppTextStyles.buttonLarge.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    ).animate().scale(
          duration: 300.ms,
          curve: Curves.easeOut,
          delay: 400.ms,
        );
  }

  // 🔗 Login Link
  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account?',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.getTextSecondary(context),
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => context.go('/auth/login'),
          child: Text(
            'Sign in',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.telegramBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // 📝 Form
  Widget _buildForm() {
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
          const SizedBox(height: 24),
          _buildDeviceStatus(),
          const SizedBox(height: 32),
          _buildRegisterButton(),
          const SizedBox(height: 24),
          _buildLoginLink(),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 20),
        ],
      ),
    );
  }

  // 📱 Mobile Layout
  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: _buildForm(),
        ),
      ),
    );
  }

  // 📱 Tablet Layout
  Widget _buildTabletLayout() {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.getCard(context),
                  borderRadius:
                      BorderRadius.circular(AppThemes.borderRadiusLarge),
                  border: Border.all(
                    color: Theme.of(context).dividerColor,
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: _buildForm(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 💻 Desktop Layout
  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 700),
            child: Row(
              children: [
                // Left Side - Welcome Panel
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(48),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: AppColors.blueGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.horizontal(
                        left: Radius.circular(AppThemes.borderRadiusLarge),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(
                                AppThemes.borderRadiusLarge),
                          ),
                          child: const Icon(
                            Icons.school_rounded,
                            size: 60,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          'Welcome to\nFamily Academy',
                          style: AppTextStyles.displayMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Join thousands of students learning with our comprehensive educational platform',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: Colors.white.withOpacity(0.9),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

                // Right Side - Registration Form
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.getCard(context),
                      borderRadius: BorderRadius.horizontal(
                        right: Radius.circular(AppThemes.borderRadiusLarge),
                      ),
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

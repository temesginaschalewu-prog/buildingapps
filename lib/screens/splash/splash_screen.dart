import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/connectivity_service.dart';
import '../../services/hive_service.dart';
import '../../utils/helpers.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_brand_logo.dart';
import '../../themes/app_themes.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/responsive_values.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoOpacityAnimation;

  late AnimationController _textController;
  late Animation<double> _textOpacityAnimation;
  late Animation<Offset> _textSlideAnimation;

  bool _hasError = false;
  String? _errorMessage;
  static const Duration _initTimeout = Duration(seconds: 10);
  bool _initializationComplete = false;
  Timer? _timeoutTimer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));
    _logoScaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
          parent: _logoController,
          curve: const Interval(0.0, 0.8, curve: Curves.elasticOut)),
    );
    _logoOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _logoController,
          curve: const Interval(0.0, 0.6, curve: Curves.easeInOut)),
    );

    _textController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _textOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeInOut),
    );
    _textSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );

    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _textController.forward();
    });

    // Start initialization immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });

    // Set a timeout timer to prevent infinite waiting
    _timeoutTimer = Timer(_initTimeout, () {
      if (mounted && !_initializationComplete && !_navigated) {
        debugLog(
            'SplashScreen', 'Initialization timeout - proceeding anyway');
        _proceedToNextScreen();
      }
    });
  }

  Future<bool> _waitForServices() async {
    debugLog('SplashScreen', 'Waiting for all services to initialize...');

    final stopwatch = Stopwatch()..start();
    const maxWaitTime = Duration(seconds: 8);

    while (stopwatch.elapsed < maxWaitTime) {
      if (!mounted) return false;

      try {
        final connectivityService = context.read<ConnectivityService>();
        final hiveService = context.read<HiveService>();

        // Check critical services only
        final connectivityReady = connectivityService.isInitialized;
        final hiveReady = hiveService.isInitialized;

        // Auth provider might still be loading - that's fine
        // We just need the critical services

        if (hiveReady && connectivityReady) {
          debugLog('SplashScreen',
              'Critical services ready after ${stopwatch.elapsed.inMilliseconds}ms');

          // Give auth provider a moment to initialize (but don't wait too long)
          await Future.delayed(const Duration(milliseconds: 500));
          return true;
        }
      } catch (e) {
        debugLog('SplashScreen', 'Error checking services: $e');
      }

      await Future.delayed(const Duration(milliseconds: 100));
    }

    debugLog('SplashScreen',
        'Service initialization timeout after ${stopwatch.elapsed.inSeconds}s - proceeding anyway');
    return true;
  }

  Future<void> _initializeApp() async {
    if (!mounted) return;

    try {
      final servicesReady = await _waitForServices();

      if (!mounted) return;

      if (!servicesReady && !_navigated) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Could not initialize. Please restart app.';
        });
        return;
      }

      _initializationComplete = true;
      _timeoutTimer?.cancel();

      // Add a small delay for better UX
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted || _navigated) return;

      _proceedToNextScreen();
    } catch (e) {
      if (mounted && !_navigated) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to start';
        });
      }
    }
  }

  void _proceedToNextScreen() {
    if (_navigated || !mounted) return;

    _navigated = true;
    _timeoutTimer?.cancel();

    try {
      final authProvider = context.read<AuthProvider>();
      final isAuthenticated = authProvider.isAuthenticated;
      final user = authProvider.currentUser;

      debugLog('SplashScreen',
          'Auth check complete - isAuthenticated: $isAuthenticated');

      // Session check is handled by AuthProvider's _autoLogoutTimer
      // If session expired (>3 days), isAuthenticated will be false

      if (isAuthenticated) {
        if (user?.schoolId == null || user?.schoolId == 0) {
          debugLog('SplashScreen', 'Navigating to school selection');
          context.go('/school-selection');
        } else {
          debugLog('SplashScreen', 'Navigating to home');
          context.go('/');
        }
      } else {
        debugLog('SplashScreen', 'Navigating to login');
        context.go('/auth/login');
      }
    } catch (e) {
      debugLog('SplashScreen', 'Error navigating: $e');
      // Fallback to login
      context.go('/auth/login');
    }
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _logoController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: ResponsiveValues.screenPadding(context),
              child: Padding(
                padding: ResponsiveValues.dialogPadding(context),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _logoController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _logoOpacityAnimation.value,
                          child: Transform.scale(
                            scale: _logoScaleAnimation.value,
                            child: AppBrandLogo(
                              size:
                                  ResponsiveValues.splashLogoSize(context) *
                                      0.82,
                              borderRadius:
                                  ResponsiveValues.radiusXLarge(context),
                            ),
                          ),
                        );
                      },
                    ),
                      SizedBox(height: ResponsiveValues.spacingSplash(context)),
                      SlideTransition(
                        position: _textSlideAnimation,
                        child: FadeTransition(
                          opacity: _textOpacityAnimation,
                          child: Column(
                            children: [
                              Text(
                                'Family Academy',
                                style: AppTextStyles.displaySmall(context)
                                    .copyWith(fontWeight: FontWeight.w700),
                              ),
                              SizedBox(
                                  height: ResponsiveValues.spacingL(context)),
                              Text(
                                'Education, progress, and learning sync in one place.',
                                style: AppTextStyles.bodyLarge(context).copyWith(
                                  color: AppColors.getTextSecondary(context),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: ResponsiveValues.spacingXXL(context)),
                      if (_hasError)
                        Column(
                          children: [
                            Text(
                              _errorMessage ?? 'Error',
                              style: AppTextStyles.bodyMedium(context).copyWith(
                                color: AppColors.telegramRed,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: ResponsiveValues.spacingM(context)),
                            AppButton.primary(
                              label: 'Retry',
                              onPressed: () {
                                setState(() {
                                  _hasError = false;
                                  _navigated = false;
                                });
                                _initializeApp();
                              },
                            ),
                          ],
                        )
                      else
                        Column(
                          children: [
                            const SizedBox(
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.telegramBlue,
                                ),
                              ),
                            ),
                            SizedBox(height: ResponsiveValues.spacingL(context)),
                            Text(
                              'Preparing your workspace',
                              style: AppTextStyles.bodyMedium(context).copyWith(
                                color: AppColors.getTextSecondary(context),
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
    ).animate().fadeIn(duration: AppThemes.animationMedium);
  }
}

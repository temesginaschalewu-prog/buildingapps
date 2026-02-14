import 'dart:async';
import 'package:familyacademyclient/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:familyacademyclient/providers/auth_provider.dart';
import 'package:familyacademyclient/themes/app_themes.dart';
import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import '../../utils/helpers.dart';

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

  late AnimationController _checkmarkController;
  late Animation<double> _checkmarkScaleAnimation;
  late Animation<double> _checkmarkOpacityAnimation;

  bool _isInitializing = true;
  bool _authInitialized = false;
  bool _authCompleted = false;
  bool _hasError = false;
  String? _errorMessage;
  String _currentStatus = 'Initializing...';
  Timer? _statusTimer;
  Timer? _navigationTimer;
  Timer? _retryTimer;
  bool _routerReady = false;
  int _retryCount = 0;
  final int _maxRetries = 3;

  @override
  void initState() {
    super.initState();

    // Logo animation controller
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _logoScaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.8, curve: Curves.elasticOut),
      ),
    );

    _logoOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeInOut),
      ),
    );

    // Text animation controller
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _textOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: Curves.easeInOut,
      ),
    );

    _textSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _textController,
        curve: Curves.easeOut,
      ),
    );

    // Checkmark animation controller
    _checkmarkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _checkmarkScaleAnimation = Tween<double>(begin: 0.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _checkmarkController,
        curve: Curves.elasticOut,
      ),
    );

    _checkmarkOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _checkmarkController,
        curve: Curves.easeInOut,
      ),
    );

    // Start animations
    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _textController.forward();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkRouterReady();
      _startStatusUpdates();
    });
  }

  void _checkRouterReady() {
    if (!mounted) return;

    try {
      final router = GoRouter.of(context);
      setState(() {
        _routerReady = true;
      });
      debugLog('SplashScreen', '✅ Router is ready, starting initialization');
      _initializeApp();
    } catch (e) {
      if (_retryCount < _maxRetries && mounted) {
        _retryCount++;
        debugLog(
          'SplashScreen',
          '⚠️ Router not ready (attempt $_retryCount/$_maxRetries), retrying...',
        );

        _retryTimer?.cancel();
        _retryTimer = Timer(const Duration(milliseconds: 300), () {
          if (mounted) {
            _checkRouterReady();
          }
        });
      } else {
        debugLog(
          'SplashScreen',
          '❌ Router not ready after $_maxRetries attempts',
        );
        if (mounted) {
          _initializeAppWithFallback();
        }
      }
    }
  }

  void _initializeAppWithFallback() {
    if (!mounted) return;

    setState(() {
      _routerReady = false;
    });
    _initializeApp();
  }

  void _startStatusUpdates() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      String newStatus = _currentStatus;

      if (!_routerReady) {
        newStatus = 'Checking user status...';
      } else if (_authCompleted) {
        newStatus = 'Ready!';
        timer.cancel();
      }

      if (mounted && newStatus != _currentStatus) {
        setState(() {
          _currentStatus = newStatus;
        });
      }
    });
  }

  Future<void> _initializeApp() async {
    if (!mounted) return;

    try {
      debugLog('SplashScreen', '🚀 Starting app initialization...');

      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (authProvider.isAuthenticated && authProvider.isInitialized) {
        debugLog('SplashScreen', '✅ Already authenticated, skipping splash');
        final user = authProvider.currentUser;
        if (user?.schoolId == null) {
          context.go('/school-selection');
        } else {
          context.go('/');
        }
        return;
      }

      if (mounted) {
        setState(() {
          _currentStatus = 'Initializing authentication...';
        });
      }

      await authProvider.initialize();

      if (mounted) {
        setState(() {
          _authInitialized = true;
          _currentStatus = 'Authentication initialized';
        });
      }

      debugLog(
        'SplashScreen',
        '✅ Auth initialized: ${authProvider.isAuthenticated}',
      );

      if (!mounted) return;

      final isAuthenticated = authProvider.isAuthenticated;
      final user = authProvider.currentUser;

      if (mounted) {
        setState(() {
          _authCompleted = true;
          _currentStatus = 'Authentication complete';
        });

        _checkmarkController.forward();
      }

      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted) return;

      _navigateBasedOnAuthState(isAuthenticated, user);
    } catch (e) {
      debugLog('SplashScreen', '❌ Initialization error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to initialize app. Please restart.';
          _isInitializing = false;
          _currentStatus = 'Error occurred';
        });

        _checkmarkController.forward();

        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          context.go('/auth/login');
        }
      }
    } finally {
      if (mounted && !_hasError) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  void _navigateBasedOnAuthState(bool isAuthenticated, User? user) {
    if (!mounted) return;

    if (isAuthenticated) {
      debugLog(
        'SplashScreen',
        '👤 User: ${user?.username}, School: ${user?.schoolId}',
      );

      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;

        if (user?.schoolId == null) {
          debugLog('SplashScreen', '🏫 No school - going to school selection');
          context.go('/school-selection');
        } else {
          debugLog('SplashScreen', '🏠 Going to home screen');
          context.go('/');
        }
      });
    } else {
      debugLog('SplashScreen', '🔐 Not authenticated - going to login');

      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        context.go('/auth/login');
      });
    }
  }

  void _safeNavigate(String route) {
    if (!mounted) return;

    _navigationTimer?.cancel();
    _navigationTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;

      try {
        context.go(route);
      } catch (e) {
        debugLog('SplashScreen', 'Navigation error: $e');

        _navigationTimer = Timer(const Duration(seconds: 1), () {
          if (mounted) {
            try {
              context.go(route);
            } catch (e2) {
              debugLog('SplashScreen', 'Secondary navigation error: $e2');

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  Navigator.of(
                    context,
                  ).pushReplacementNamed(route == '/' ? '/home' : route);
                }
              });
            }
          }
        });
      }
    });
  }

  // 🎨 Status Indicator
  Widget _buildStatusIndicator() {
    if (_hasError) {
      return Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.telegramRed.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.telegramRed, width: 2),
            ),
            child: Icon(
              Icons.error_outline_rounded,
              size: 32,
              color: AppColors.telegramRed,
            ),
          ).animate().shake(duration: 600.ms),
          SizedBox(height: AppThemes.spacingM),
          Text(
            _errorMessage ?? 'Initialization Error',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.telegramRed,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    if (_authCompleted) {
      return AnimatedBuilder(
        animation: _checkmarkController,
        builder: (context, child) {
          return Opacity(
            opacity: _checkmarkOpacityAnimation.value,
            child: Transform.scale(
              scale: _checkmarkScaleAnimation.value,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.telegramGreen.withOpacity(0.1),
                  border: Border.all(color: AppColors.telegramGreen, width: 2),
                ),
                child: Center(
                  child: Icon(
                    Icons.check_rounded,
                    size: 32,
                    color: AppColors.telegramGreen,
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: AppColors.telegramBlue.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.telegramBlue),
          ),
        ),
      ),
    );
  }

  // 📱 Mobile Splash
  Widget _buildMobileSplash() {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Logo
              AnimatedBuilder(
                animation: _logoController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _logoOpacityAnimation.value,
                    child: Transform.scale(
                      scale: _logoScaleAnimation.value,
                      child: Container(
                        width: ScreenSize.responsiveValue(
                          context: context,
                          mobile: 120,
                          tablet: 140,
                          desktop: 160,
                        ),
                        height: ScreenSize.responsiveValue(
                          context: context,
                          mobile: 120,
                          tablet: 140,
                          desktop: 160,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: AppColors.blueGradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.telegramBlue.withOpacity(0.3),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            Icons.school_rounded,
                            size: ScreenSize.responsiveValue(
                              context: context,
                              mobile: 56,
                              tablet: 64,
                              desktop: 72,
                            ),
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              SizedBox(
                height: ScreenSize.responsiveValue(
                  context: context,
                  mobile: AppThemes.spacingXXL,
                  tablet: AppThemes.spacingXXXL,
                  desktop: AppThemes.spacingXXXL * 1.5,
                ),
              ),

              // Title and Subtitle
              SlideTransition(
                position: _textSlideAnimation,
                child: FadeTransition(
                  opacity: _textOpacityAnimation,
                  child: Column(
                    children: [
                      Text(
                        'Family Academy',
                        style: AppTextStyles.displaySmall.copyWith(
                          color: AppColors.getTextPrimary(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: AppThemes.spacingM),
                      Text(
                        'Empowering Education',
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.getTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(
                height: ScreenSize.responsiveValue(
                  context: context,
                  mobile: AppThemes.spacingXXL,
                  tablet: AppThemes.spacingXXXL,
                  desktop: AppThemes.spacingXXXL * 1.5,
                ),
              ),

              // Status Indicator
              _buildStatusIndicator(),

              SizedBox(height: AppThemes.spacingL),

              // Status Text
              FadeTransition(
                opacity: _textOpacityAnimation,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppThemes.spacingL,
                        vertical: AppThemes.spacingS,
                      ),
                      decoration: BoxDecoration(
                        color: _hasError
                            ? AppColors.telegramRed.withOpacity(0.1)
                            : _authCompleted
                                ? AppColors.telegramGreen.withOpacity(0.1)
                                : AppColors.telegramBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(
                          AppThemes.borderRadiusFull,
                        ),
                        border: Border.all(
                          color: _hasError
                              ? AppColors.telegramRed
                              : _authCompleted
                                  ? AppColors.telegramGreen
                                  : AppColors.telegramBlue,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _currentStatus,
                        style: AppTextStyles.labelMedium.copyWith(
                          color: _hasError
                              ? AppColors.telegramRed
                              : _authCompleted
                                  ? AppColors.telegramGreen
                                  : AppColors.telegramBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(height: AppThemes.spacingS),
                    if (_isInitializing && !_hasError)
                      Text(
                        'Please wait...',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.getTextSecondary(context),
                        ),
                      ),
                    if (!_routerReady && !_hasError)
                      Text(
                        'Preparing navigation...',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.getTextSecondary(context),
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

  // 💻 Desktop Splash (Optional - can be same as mobile for simplicity)
  Widget _buildDesktopSplash() {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: _buildMobileSplash(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _navigationTimer?.cancel();
    _retryTimer?.cancel();

    _logoController.dispose();
    _textController.dispose();
    _checkmarkController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: _buildMobileSplash(),
      tablet: _buildDesktopSplash(),
      desktop: _buildDesktopSplash(),
    ).animate().fadeIn(duration: AppThemes.animationDurationMedium);
  }
}

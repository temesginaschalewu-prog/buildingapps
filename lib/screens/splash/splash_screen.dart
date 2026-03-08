import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/user_session.dart';
import '../../services/connectivity_service.dart';
import '../../services/platform_service.dart';
import '../../utils/helpers.dart';
import '../../widgets/common/app_card.dart';
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

  late AnimationController _checkmarkController;
  late Animation<double> _checkmarkScaleAnimation;
  late Animation<double> _checkmarkOpacityAnimation;

  bool _isInitializing = true;
  bool _authCompleted = false;
  bool _hasError = false;
  bool _isOffline = false;
  int _pendingCount = 0;
  String? _errorMessage;
  String _currentStatus = 'Initializing...';
  Timer? _statusTimer;
  Timer? _navigationTimer;
  bool _routerReady = false;

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

    _checkmarkController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _checkmarkScaleAnimation = Tween<double>(begin: 0.0, end: 1.2).animate(
      CurvedAnimation(parent: _checkmarkController, curve: Curves.elasticOut),
    );
    _checkmarkOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _checkmarkController, curve: Curves.easeInOut),
    );

    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _textController.forward();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkRouterReady();
      _startStatusUpdates();
      _checkConnectivity();
      _checkPendingCount();
    });
  }

  Future<void> _checkPendingCount() async {
    final connectivity = ConnectivityService();
    setState(() => _pendingCount = connectivity.pendingActionsCount);
  }

  Future<void> _checkConnectivity() async {
    final connectivityService = context.read<ConnectivityService>();
    setState(() {
      _isOffline = !connectivityService.isOnline;
      _pendingCount = connectivityService.pendingActionsCount;
    });
  }

  void _checkRouterReady() {
    if (!mounted) return;

    try {
      GoRouter.of(context);
      setState(() => _routerReady = true);
      _initializeApp();
    } catch (e) {
      debugLog('SplashScreen', 'Router not ready, retrying...');
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _checkRouterReady();
      });
    }
  }

  void _startStatusUpdates() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      String newStatus = _currentStatus;

      if (_isOffline) {
        newStatus = 'Offline mode - using cached data';
        if (_pendingCount > 0) {
          newStatus = 'Offline - $_pendingCount pending changes';
        }
      } else if (!_routerReady) {
        newStatus = 'Checking user status...';
      } else if (_authCompleted) {
        newStatus = 'Ready!';
        timer.cancel();
      }

      if (mounted && newStatus != _currentStatus) {
        setState(() => _currentStatus = newStatus);
      }
    });
  }

  Future<void> _initializeApp() async {
    if (!mounted) return;

    debugLog('SplashScreen', 'initializeApp started');

    try {
      final authProvider = context.read<AuthProvider>();
      await UserSession().init();
      if (!mounted) return;

      // Check for existing user session
      if (_isOffline) {
        setState(() => _currentStatus = 'Checking cached user...');

        final user = authProvider.currentUser;
        if (user != null) {
          debugLog('SplashScreen', 'Found cached user: ${user.username}');
          setState(() {
            _authCompleted = true;
            _currentStatus = 'Welcome back! (Offline)';
          });
          await _checkmarkController.forward();
          if (!mounted) return;
          await Future.delayed(const Duration(milliseconds: 800));
          if (!mounted) return;

          if (user.schoolId == null) {
            debugLog('SplashScreen',
                'No school selected, going to school selection');
            if (mounted) context.go('/school-selection');
          } else {
            debugLog('SplashScreen', 'Going to home');
            if (mounted) context.go('/');
          }
          return;
        }
      }

      // Wait for auth provider to fully initialize
      if (mounted) {
        setState(() => _currentStatus = 'Checking authentication...');
      }

      // IMPORTANT: Wait for auth to initialize with timeout
      debugLog('SplashScreen', 'Waiting for auth provider to initialize...');

      // Start initialization if not already started
      if (!authProvider.isInitialized && !authProvider.isInitializing) {
        unawaited(authProvider.initialize());
      }

      // Wait for initialization with longer timeout (10 seconds instead of 3)
      int attempts = 0;
      const int maxAttempts = 100; // 10 seconds (100 * 100ms)
      while (!authProvider.isInitialized && attempts < maxAttempts) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
        if (attempts % 20 == 0) {
          // Log every 2 seconds
          debugLog('SplashScreen',
              'Still waiting for auth... (${attempts * 100}ms)');
        }
      }

      if (!mounted) return;

      if (authProvider.isInitialized) {
        debugLog('SplashScreen',
            'Auth provider initialization completed after ${attempts * 100}ms');
      } else {
        debugLog('SplashScreen',
            'Auth provider initialization TIMEOUT after ${attempts * 100}ms');
      }

      if (mounted) {
        setState(() => _currentStatus = 'Authentication initialized');
      }

      // Now check auth state AFTER initialization is complete
      final isAuthenticated = authProvider.isAuthenticated;
      final user = authProvider.currentUser;

      debugLog('SplashScreen',
          'Auth state after init: isAuthenticated=$isAuthenticated');
      if (user != null) {
        debugLog('SplashScreen',
            'User: ${user.username}, schoolId: ${user.schoolId}');
      }

      if (mounted) {
        setState(() {
          _authCompleted = true;
          _currentStatus = isAuthenticated ? 'Welcome back!' : 'Ready to start';
        });
        await _checkmarkController.forward();
        if (!mounted) return;
      }

      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;

      // Navigate based on auth state
      if (isAuthenticated) {
        if (user?.schoolId == null) {
          debugLog('SplashScreen',
              'Authenticated but no school, going to school selection');
          if (mounted) context.go('/school-selection');
        } else {
          debugLog('SplashScreen', 'Authenticated with school, going to home');
          if (mounted) context.go('/');
        }
      } else {
        debugLog('SplashScreen', 'Not authenticated, going to login');
        if (mounted) context.go('/auth/login');
      }

      debugLog('SplashScreen', 'initializeApp finished');
    } catch (e) {
      debugLog('SplashScreen', 'Error in initializeApp: $e');

      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = _isOffline
              ? 'Offline - using cached data. Some features may be limited.'
              : 'Failed to initialize app. Please restart.';
          _isInitializing = false;
          _currentStatus = 'Error occurred';
        });

        // If offline and we have a cached user, try to use it
        if (_isOffline) {
          final authProvider = context.read<AuthProvider>();
          final user = authProvider.currentUser;
          if (user != null) {
            debugLog('SplashScreen', 'Using cached user despite error');
            await Future.delayed(const Duration(seconds: 1));
            if (!mounted) return;

            if (user.schoolId == null) {
              if (mounted) context.go('/school-selection');
            } else {
              if (mounted) context.go('/');
            }
            return;
          }
        }

        await _checkmarkController.forward();
        if (!mounted) return;
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;

        // Fallback to login
        if (mounted && !_isOffline) {
          debugLog('SplashScreen', 'Falling back to login');
          if (mounted) context.go('/auth/login');
        }
      }
    } finally {
      if (mounted && !_hasError) setState(() => _isInitializing = false);
    }
  }

  Widget _buildStatusIndicator() {
    if (_hasError) {
      return Column(
        children: [
          AppCard.glass(
            child: Container(
              width: ResponsiveValues.iconSizeXXL(context) * 1.5,
              height: ResponsiveValues.iconSizeXXL(context) * 1.5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.telegramRed.withValues(alpha: 0.2),
                    AppColors.telegramRed.withValues(alpha: 0.1)
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded,
                  size: 40, color: AppColors.telegramRed),
            ),
          ).animate().shake(duration: 600.ms),
          SizedBox(height: ResponsiveValues.spacingL(context)),
          Text(
            _errorMessage ?? 'Initialization Error',
            style: AppTextStyles.bodyMedium(context).copyWith(
                color: AppColors.telegramRed, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    if (_isOffline) {
      return Column(
        children: [
          AppCard.glass(
            child: Container(
              width: ResponsiveValues.iconSizeXXL(context) * 1.5,
              height: ResponsiveValues.iconSizeXXL(context) * 1.5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.warning.withValues(alpha: 0.2),
                    AppColors.warning.withValues(alpha: 0.1)
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded,
                  size: 40, color: AppColors.warning),
            ),
          ).animate().shake(duration: 600.ms),
          SizedBox(height: ResponsiveValues.spacingL(context)),
          Text(
            'Offline Mode',
            style: AppTextStyles.bodyMedium(context).copyWith(
                color: AppColors.warning, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
          if (_pendingCount > 0) ...[
            SizedBox(height: ResponsiveValues.spacingS(context)),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveValues.spacingM(context),
                vertical: ResponsiveValues.spacingXS(context),
              ),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius:
                    BorderRadius.circular(ResponsiveValues.radiusFull(context)),
                border:
                    Border.all(color: AppColors.info.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule_rounded,
                      size: ResponsiveValues.iconSizeXS(context),
                      color: AppColors.info),
                  SizedBox(width: ResponsiveValues.spacingXXS(context)),
                  Text(
                    '$_pendingCount pending',
                    style: AppTextStyles.labelSmall(context)
                        .copyWith(color: AppColors.info),
                  ),
                ],
              ),
            ),
          ],
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
              child: AppCard.glass(
                child: Container(
                  width: ResponsiveValues.iconSizeXXL(context) * 1.5,
                  height: ResponsiveValues.iconSizeXXL(context) * 1.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.telegramGreen.withValues(alpha: 0.2),
                        AppColors.telegramGreen.withValues(alpha: 0.1)
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                      child: Icon(Icons.check_rounded,
                          size: 40, color: AppColors.telegramGreen)),
                ),
              ),
            ),
          );
        },
      );
    }

    return AppCard.glass(
      child: Container(
        width: ResponsiveValues.iconSizeXXL(context) * 1.5,
        height: ResponsiveValues.iconSizeXXL(context) * 1.5,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.telegramBlue.withValues(alpha: 0.2),
              AppColors.telegramPurple.withValues(alpha: 0.1)
            ],
          ),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.telegramBlue),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _logoController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _logoOpacityAnimation.value,
                    child: Transform.scale(
                      scale: _logoScaleAnimation.value,
                      child: AppCard.glass(
                        child: Container(
                          width: ResponsiveValues.splashLogoSize(context),
                          height: ResponsiveValues.splashLogoSize(context),
                          padding: ResponsiveValues.dialogPadding(context),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: AppColors.blueGradient),
                            borderRadius: BorderRadius.circular(
                                ResponsiveValues.radiusXLarge(context)),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.telegramBlue
                                    .withValues(alpha: 0.3),
                                blurRadius: ResponsiveValues.spacingXL(context),
                                offset: Offset(
                                    0, ResponsiveValues.spacingM(context)),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.school_rounded,
                            size: ResponsiveValues.splashIconSize(context),
                            color: Colors.white,
                          ),
                        ),
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
                      SizedBox(height: ResponsiveValues.spacingL(context)),
                      Text(
                        _isOffline ? 'Offline Mode' : 'Empowering Education',
                        style: AppTextStyles.bodyLarge(context).copyWith(
                          color: _isOffline
                              ? AppColors.warning
                              : AppColors.getTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: ResponsiveValues.spacingSplash(context)),
              _buildStatusIndicator(),
              SizedBox(height: ResponsiveValues.spacingL(context)),
              FadeTransition(
                opacity: _textOpacityAnimation,
                child: Column(
                  children: [
                    AppCard.glass(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveValues.spacingL(context),
                          vertical: ResponsiveValues.spacingS(context),
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _hasError
                                ? [
                                    AppColors.telegramRed
                                        .withValues(alpha: 0.2),
                                    AppColors.telegramRed.withValues(alpha: 0.1)
                                  ]
                                : (_isOffline
                                    ? [
                                        AppColors.warning
                                            .withValues(alpha: 0.2),
                                        AppColors.warning.withValues(alpha: 0.1)
                                      ]
                                    : (_authCompleted
                                        ? [
                                            AppColors.telegramGreen
                                                .withValues(alpha: 0.2),
                                            AppColors.telegramGreen
                                                .withValues(alpha: 0.1)
                                          ]
                                        : [
                                            AppColors.telegramBlue
                                                .withValues(alpha: 0.2),
                                            AppColors.telegramPurple
                                                .withValues(alpha: 0.1)
                                          ])),
                          ),
                          borderRadius: BorderRadius.circular(
                              ResponsiveValues.radiusFull(context)),
                        ),
                        child: Text(
                          _currentStatus,
                          style: AppTextStyles.labelMedium(context).copyWith(
                            color: _hasError
                                ? AppColors.telegramRed
                                : (_isOffline
                                    ? AppColors.warning
                                    : (_authCompleted
                                        ? AppColors.telegramGreen
                                        : AppColors.telegramBlue)),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: ResponsiveValues.spacingS(context)),
                    if (_isInitializing && !_hasError && !_isOffline)
                      Text(
                        'Please wait...',
                        style: AppTextStyles.caption(context).copyWith(
                            color: AppColors.getTextSecondary(context)),
                      ),
                    if (!_routerReady && !_hasError && !_isOffline)
                      Text(
                        'Preparing navigation...',
                        style: AppTextStyles.caption(context).copyWith(
                            color: AppColors.getTextSecondary(context)),
                      ),
                    if (_isOffline && !_hasError)
                      Text(
                        'Using cached data',
                        style: AppTextStyles.caption(context)
                            .copyWith(color: AppColors.warning),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: AppThemes.animationMedium);
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _navigationTimer?.cancel();
    _logoController.dispose();
    _textController.dispose();
    _checkmarkController.dispose();
    super.dispose();
  }
}

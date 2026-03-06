import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/auth_provider.dart';
import '../../services/user_session.dart';
import '../../services/connectivity_service.dart';
import '../../widgets/common/app_card.dart';
import '../../themes/app_themes.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/responsive.dart';
import '../../utils/responsive_values.dart';
import '../../utils/app_enums.dart';
import '../../widgets/common/responsive_widgets.dart';

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
    });
  }

  Future<void> _checkConnectivity() async {
    final connectivityService = context.read<ConnectivityService>();
    setState(() => _isOffline = !connectivityService.isOnline);
  }

  void _checkRouterReady() {
    if (!mounted) return;

    try {
      GoRouter.of(context);
      setState(() => _routerReady = true);
      _initializeApp();
    } catch (e) {
      if (_retryCount < _maxRetries && mounted) {
        _retryCount++;
        _retryTimer?.cancel();
        _retryTimer = Timer(const Duration(milliseconds: 300), () {
          if (mounted) _checkRouterReady();
        });
      } else {
        if (mounted) _initializeAppWithFallback();
      }
    }
  }

  void _initializeAppWithFallback() {
    if (!mounted) return;
    setState(() => _routerReady = false);
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

      if (_isOffline) {
        newStatus = 'Offline mode - using cached data';
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

    try {
      final authProvider = context.read<AuthProvider>();
      await UserSession().init();

      if (authProvider.isAuthenticated && authProvider.isInitialized) {
        final user = authProvider.currentUser;
        setState(() {
          _authCompleted = true;
          _currentStatus = 'Welcome back!';
        });
        await _checkmarkController.forward();
        await Future.delayed(const Duration(milliseconds: 800));

        if (!mounted) return;
        if (user?.schoolId == null) {
          context.go('/school-selection');
        } else {
          context.go('/');
        }
        return;
      }

      if (mounted)
        setState(() => _currentStatus = 'Initializing authentication...');

      await authProvider.initialize();

      if (mounted)
        setState(() => _currentStatus = 'Authentication initialized');

      if (!mounted) return;

      final isAuthenticated = authProvider.isAuthenticated;
      final user = authProvider.currentUser;

      if (mounted) {
        setState(() {
          _authCompleted = true;
          _currentStatus = isAuthenticated ? 'Welcome back!' : 'Ready to start';
        });
        await _checkmarkController.forward();
      }

      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted) return;

      if (isAuthenticated) {
        if (user?.schoolId == null) {
          context.go('/school-selection');
        } else {
          context.go('/');
        }
      } else {
        context.go('/auth/login');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = _isOffline
              ? 'Offline - using cached data. Some features may be limited.'
              : 'Failed to initialize app. Please restart.';
          _isInitializing = false;
          _currentStatus = 'Error occurred';
        });

        if (_isOffline) {
          final authProvider = context.read<AuthProvider>();
          final user = authProvider.currentUser;
          if (user != null) {
            await Future.delayed(const Duration(seconds: 1));
            if (!mounted) return;
            if (user.schoolId == null) {
              context.go('/school-selection');
            } else {
              context.go('/');
            }
            return;
          }
        }

        await _checkmarkController.forward();
        await Future.delayed(const Duration(seconds: 2));
        if (mounted && !_isOffline) context.go('/auth/login');
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
                    AppColors.telegramYellow.withValues(alpha: 0.2),
                    AppColors.telegramYellow.withValues(alpha: 0.1)
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded,
                  size: 40, color: AppColors.telegramYellow),
            ),
          ).animate().shake(duration: 600.ms),
          SizedBox(height: ResponsiveValues.spacingL(context)),
          Text(
            'Offline Mode',
            style: AppTextStyles.bodyMedium(context).copyWith(
                color: AppColors.telegramYellow, fontWeight: FontWeight.w500),
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
                              ? AppColors.telegramYellow
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
                                        AppColors.telegramYellow
                                            .withValues(alpha: 0.2),
                                        AppColors.telegramYellow
                                            .withValues(alpha: 0.1)
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
                                    ? AppColors.telegramYellow
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
                            .copyWith(color: AppColors.telegramYellow),
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
    _retryTimer?.cancel();
    _logoController.dispose();
    _textController.dispose();
    _checkmarkController.dispose();
    super.dispose();
  }
}

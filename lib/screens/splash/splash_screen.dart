import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/connectivity_service.dart';
import '../../services/hive_service.dart';
import '../../utils/helpers.dart';
import '../../widgets/common/app_brand_logo.dart';
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
  late AnimationController _pulseController;

  bool _hasError = false;
  String? _errorMessage;
  static const Duration _initTimeout = Duration(seconds: 5);
  bool _initializationComplete = false;
  Timer? _timeoutTimer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    // Logo animation - smooth scale up with subtle bounce
    _logoController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _logoScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
          parent: _logoController,
          curve: const Interval(0.0, 0.8, curve: Curves.easeOutBack)),
    );
    _logoOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _logoController,
          curve: const Interval(0.0, 0.6, curve: Curves.easeInOut)),
    );

    // Subtle pulse animation for the logo
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000));
    Tween<double>(begin: 1.0, end: 1.02)
        .animate(
      CurvedAnimation(
          parent: _pulseController,
          curve: const Interval(0.0, 1.0, curve: Curves.easeInOut)),
    )
        .addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _pulseController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _pulseController.forward();
      }
    });

    // Start animations
    _logoController.forward();
    _pulseController.forward();

    // Start initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });

    // Set timeout timer
    _timeoutTimer = Timer(_initTimeout, () {
      if (mounted && !_initializationComplete && !_navigated) {
        debugLog('SplashScreen', 'Initialization timeout - proceeding anyway');
        _proceedToNextScreen();
      }
    });
  }

  Future<void> _initializeApp() async {
    if (!mounted) return;

    try {
      final connectivityService = context.read<ConnectivityService>();
      final hiveService = context.read<HiveService>();
      final authProvider = context.read<AuthProvider>();

      // Wait for critical services
      final stopwatch = Stopwatch()..start();
      const maxWaitTime = Duration(seconds: 4);

      while (stopwatch.elapsed < maxWaitTime) {
        if (!mounted) return;

        final connectivityReady = connectivityService.isInitialized;
        final hiveReady = hiveService.isInitialized;

        if (hiveReady && connectivityReady) {
          debugLog('SplashScreen',
              'Services ready after ${stopwatch.elapsed.inMilliseconds}ms');
          break;
        }

        await Future.delayed(const Duration(milliseconds: 50));
      }

      _initializationComplete = true;
      _timeoutTimer?.cancel();

      // Short delay for visual polish
      await Future.delayed(const Duration(milliseconds: 300));

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
      context.go('/auth/login');
    }
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _logoController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFF),
      body: Stack(
        children: [
          // Background gradient
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? const [
                          Color(0xFF0F172A),
                          Color(0xFF1E293B),
                        ]
                      : const [
                          Color(0xFFF8FAFF),
                          Color(0xFFE2E8F0),
                        ],
                ),
              ),
            ),
          ),

          // Floating orbs for depth
          Positioned(
            top: -60,
            right: -40,
            child: _buildFloatingOrb(
              color: AppColors.telegramBlue
                  .withValues(alpha: isDark ? 0.15 : 0.10),
              size: 180,
              delay: 0.ms,
            ),
          ),
          Positioned(
            bottom: -40,
            left: -30,
            child: _buildFloatingOrb(
              color: AppColors.telegramTeal
                  .withValues(alpha: isDark ? 0.12 : 0.08),
              size: 140,
              delay: 600.ms,
            ),
          ),

          // Main content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo with pulse animation
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseController.value,
                      child: child,
                    );
                  },
                  child: AnimatedBuilder(
                    animation: _logoController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _logoOpacityAnimation.value,
                        child: Transform.scale(
                          scale: _logoScaleAnimation.value,
                          child: _buildLogo(context, isDark),
                        ),
                      );
                    },
                  ),
                ),

                SizedBox(height: ResponsiveValues.spacingXXL(context)),

                // App name
                Text(
                  'Family Academy',
                  style: AppTextStyles.displayLarge(context).copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    shadows: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: ResponsiveValues.spacingS(context)),

                // Tagline
                Text(
                  'Your learning journey starts here',
                  style: AppTextStyles.bodyLarge(context).copyWith(
                    color: AppColors.getTextSecondary(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Loading indicator at bottom
          if (!_hasError)
            Positioned(
              bottom: ResponsiveValues.spacingXL(context),
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.getSurface(context).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color:
                          AppColors.getDivider(context).withValues(alpha: 0.4),
                    ),
                  ),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.telegramBlue,
                    ),
                    backgroundColor:
                        AppColors.telegramBlue.withValues(alpha: 0.15),
                  ),
                ),
              ),
            ),

          // Error state
          if (_hasError)
            Positioned(
              bottom: ResponsiveValues.spacingXL(context),
              left: 0,
              right: 0,
              child: _buildErrorPanel(context),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildFloatingOrb(
      {required Color color, required double size, required Duration delay}) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withValues(alpha: 0.05),
              Colors.transparent,
            ],
          ),
        ),
      ).animate(delay: delay).fadeIn(duration: 800.ms).moveY(
            begin: 20,
            end: 0,
            curve: Curves.easeOut,
          ),
    );
  }

  Widget _buildLogo(BuildContext context, bool isDark) {
    final size = ResponsiveValues.splashLogoSize(context);
    return Container(
      width: size + 40,
      height: size + 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [
                  Color(0xFF1E3A8A),
                  Color(0xFF3B82F6),
                  Color(0xFF2563EB),
                ]
              : const [
                  Color(0xFFEFF6FF),
                  Color(0xFFE0F2FE),
                  Color(0xFFBFDBFE),
                ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.10),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(ResponsiveValues.spacingM(context)),
        child: AppBrandLogo(
          size: size,
          borderRadius: 20,
        ),
      ),
    );
  }

  Widget _buildErrorPanel(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveValues.spacingL(context),
        vertical: ResponsiveValues.spacingM(context),
      ),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.telegramRed.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: AppColors.telegramRed,
                size: 20,
              ),
              SizedBox(width: ResponsiveValues.spacingS(context)),
              Text(
                _errorMessage ?? 'Something went wrong',
                style: AppTextStyles.bodyMedium(context).copyWith(
                  color: AppColors.getTextPrimary(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: ResponsiveValues.spacingS(context)),
          GestureDetector(
            onTap: () {
              setState(() {
                _hasError = false;
                _navigated = false;
              });
              _initializeApp();
            },
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveValues.spacingM(context),
                vertical: ResponsiveValues.spacingS(context),
              ),
              decoration: BoxDecoration(
                color: AppColors.telegramBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Try Again',
                style: AppTextStyles.bodyMedium(context).copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(
          begin: 0.1,
          end: 0,
          duration: 400.ms,
        );
  }
}

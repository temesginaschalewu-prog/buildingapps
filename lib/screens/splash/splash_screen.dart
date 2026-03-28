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
  Timer? _statusTicker;
  String _stageTitle = 'Opening your learning space';
  String _stageMessage = 'Getting your lessons, access, and sync ready.';

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

    _statusTicker = Timer.periodic(const Duration(milliseconds: 220), (_) {
      if (mounted && !_initializationComplete && !_hasError) {
        _refreshStageCopy();
      }
    });

    // Set a timeout timer to prevent infinite waiting
    _timeoutTimer = Timer(_initTimeout, () {
      if (mounted && !_initializationComplete && !_navigated) {
        debugLog('SplashScreen', 'Initialization timeout - proceeding anyway');
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

          // Give auth provider a very short grace period without making splash drag on
          await Future.delayed(const Duration(milliseconds: 120));
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

      // Keep a very short handoff so the transition feels deliberate, not sluggish
      await Future.delayed(const Duration(milliseconds: 120));

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

  void _refreshStageCopy() {
    if (!mounted) return;

    String nextTitle = 'Opening your learning space';
    String nextMessage = 'Getting your lessons, access, and sync ready.';

    try {
      final hiveService = context.read<HiveService>();
      final connectivityService = context.read<ConnectivityService>();
      final authProvider = context.read<AuthProvider>();

      if (!hiveService.isInitialized) {
        nextTitle = 'Building your offline library';
        nextMessage = 'Preparing saved lessons so the app feels instant when you land.';
      } else if (!connectivityService.isInitialized) {
        nextTitle = 'Checking your live connection';
        nextMessage = 'Making sure updates, notifications, and sync are ready.';
      } else if (!authProvider.isInitialized) {
        nextTitle = 'Restoring your session';
        nextMessage = 'Picking up where you left off and checking access safely.';
      }
    } catch (_) {}

    if (nextTitle != _stageTitle || nextMessage != _stageMessage) {
      setState(() {
        _stageTitle = nextTitle;
        _stageMessage = nextMessage;
      });
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
    _statusTicker?.cancel();
    _logoController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProvider = context.watch<AuthProvider>();
    final connectivityService = context.read<ConnectivityService>();
    final hiveService = context.read<HiveService>();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF09111F) : const Color(0xFFF4F8FF),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? const [
                            Color(0xFF07101D),
                            Color(0xFF0D1D34),
                            Color(0xFF112A46),
                          ]
                        : const [
                            Color(0xFFF6F9FF),
                            Color(0xFFEAF1FF),
                            Color(0xFFDDE9FF),
                          ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -80,
              right: -50,
              child: _buildGlowOrb(
                color: AppColors.telegramBlue.withValues(alpha: isDark ? 0.24 : 0.18),
                size: 220,
              ),
            ),
            Positioned(
              bottom: -60,
              left: -30,
              child: _buildGlowOrb(
                color: AppColors.telegramTeal.withValues(alpha: isDark ? 0.18 : 0.14),
                size: 180,
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Padding(
                  padding: ResponsiveValues.screenPadding(context),
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
                              child: _buildHeroMark(context, isDark),
                            ),
                          );
                        },
                      ),
                      SizedBox(height: ResponsiveValues.spacingXL(context)),
                      SlideTransition(
                        position: _textSlideAnimation,
                        child: FadeTransition(
                          opacity: _textOpacityAnimation,
                          child: Column(
                            children: [
                              Text(
                                'Family Academy',
                                style: AppTextStyles.displayMedium(context).copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.8,
                                ),
                              ),
                              SizedBox(height: ResponsiveValues.spacingS(context)),
                              Text(
                                'Learn smoothly, stay synced, and get back into class without the noise.',
                                style: AppTextStyles.bodyLarge(context).copyWith(
                                  color: AppColors.getTextSecondary(context),
                                  height: 1.45,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: ResponsiveValues.spacingXL(context)),
                      if (_hasError)
                        _buildErrorPanel(context)
                      else
                        _buildStatusPanel(
                          context,
                          hiveReady: hiveService.isInitialized,
                          connectivityReady: connectivityService.isInitialized,
                          authReady: authProvider.isInitialized,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: AppThemes.animationMedium);
  }

  Widget _buildGlowOrb({required Color color, required double size}) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withValues(alpha: 0.08),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroMark(BuildContext context, bool isDark) {
    final size = ResponsiveValues.splashLogoSize(context) * 0.88;
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: size + 72,
          height: size + 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppColors.telegramBlue.withValues(alpha: isDark ? 0.26 : 0.18),
                AppColors.telegramTeal.withValues(alpha: isDark ? 0.14 : 0.10),
                Colors.transparent,
              ],
            ),
          ),
        ),
        Container(
          width: size + 24,
          height: size + 24,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(36),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? const [Color(0xFF132742), Color(0xFF0B182B)]
                  : const [Colors.white, Color(0xFFF2F6FF)],
            ),
            border: Border.all(
              color: AppColors.getDivider(context).withValues(alpha: 0.65),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.08),
                blurRadius: 26,
                offset: const Offset(0, 16),
              ),
            ],
          ),
        ),
        AppBrandLogo(
          size: size,
          borderRadius: 28,
        ),
      ],
    );
  }

  Widget _buildStatusPanel(
    BuildContext context, {
    required bool hiveReady,
    required bool connectivityReady,
    required bool authReady,
  }) {
    final readiness = [hiveReady, connectivityReady, authReady];
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 340),
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveValues.spacingL(context),
        vertical: ResponsiveValues.spacingL(context),
      ),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context).withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: AppColors.getDivider(context).withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2.6,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.telegramBlue,
              ),
              backgroundColor: AppColors.telegramBlue.withValues(alpha: 0.15),
            ),
          ),
          SizedBox(height: ResponsiveValues.spacingM(context)),
          Text(
            _stageTitle,
            style: AppTextStyles.titleLarge(context).copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: ResponsiveValues.spacingS(context)),
          Text(
            _stageMessage,
            style: AppTextStyles.bodyMedium(context).copyWith(
              color: AppColors.getTextSecondary(context),
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: ResponsiveValues.spacingM(context)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: readiness
                .map(
                  (ready) => AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: ready ? 26 : 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: ready
                          ? AppColors.telegramGreen
                          : AppColors.getDivider(context),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                )
                .toList(),
          ),
          SizedBox(height: ResponsiveValues.spacingM(context)),
          Text(
            'Warming up quietly in the background.',
            style: AppTextStyles.labelMedium(context).copyWith(
              color: AppColors.getTextSecondary(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ).animate().fadeIn(delay: 260.ms, duration: 500.ms).slideY(
          begin: 0.08,
          end: 0,
          duration: 500.ms,
        );
  }

  Widget _buildErrorPanel(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 360),
      padding: EdgeInsets.all(ResponsiveValues.spacingL(context)),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(
          ResponsiveValues.radiusXLarge(context),
        ),
        border: Border.all(
          color: AppColors.telegramRed.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.telegramRed,
            size: 28,
          ),
          SizedBox(height: ResponsiveValues.spacingM(context)),
          Text(
            _errorMessage ?? 'Could not start the app.',
            style: AppTextStyles.bodyMedium(context).copyWith(
              color: AppColors.getTextPrimary(context),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: ResponsiveValues.spacingL(context)),
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
      ),
    );
  }
}

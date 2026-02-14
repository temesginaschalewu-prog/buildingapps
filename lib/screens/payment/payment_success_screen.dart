import 'dart:async';

import 'package:familyacademyclient/providers/auth_provider.dart';
import 'package:familyacademyclient/services/device_service.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import 'package:familyacademyclient/themes/app_themes.dart';
import 'package:familyacademyclient/widgets/common/loading_indicator.dart';
import 'package:familyacademyclient/widgets/common/empty_state.dart';
import 'package:familyacademyclient/providers/subscription_provider.dart';
import 'package:familyacademyclient/providers/category_provider.dart';
import 'package:familyacademyclient/providers/settings_provider.dart';
import '../../models/category_model.dart';
import '../../utils/helpers.dart';
import '../../themes/app_colors.dart';

class PaymentSuccessScreen extends StatefulWidget {
  final Map<String, dynamic>? extra;

  const PaymentSuccessScreen({super.key, this.extra});

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  Category? _category;
  String _paymentType = 'first_time';
  double _amount = 0.0;
  String _paymentMethod = '';
  bool _animationComplete = false;
  Timer? _redirectTimer;
  int _secondsRemaining = 5;

  late AnimationController _checkAnimationController;
  late AnimationController _pulseAnimationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _checkAnimationController = AnimationController(
      vsync: this,
      duration: 800.ms,
    );

    _pulseAnimationController = AnimationController(
      vsync: this,
      duration: 1.seconds,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
        parent: _pulseAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _loadData();
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    _checkAnimationController.dispose();
    _pulseAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final args = widget.extra;
      if (args != null && args.isNotEmpty) {
        debugLog('PaymentSuccessScreen', '📦 Processing payment success data');

        final categoryId = args['category_id'] as int?;
        _paymentType = args['payment_type'] as String? ?? 'first_time';
        _amount = (args['amount'] as num?)?.toDouble() ?? 0.0;
        _paymentMethod = args['payment_method'] as String? ?? 'unknown';

        if (categoryId != null) {
          final categoryProvider =
              Provider.of<CategoryProvider>(context, listen: false);
          final category = categoryProvider.getCategoryById(categoryId);
          setState(() {
            _category = category;
            _isLoading = false;
          });
        } else {
          _tryToLoadFromCache();
        }
      } else {
        _tryToLoadFromCache();
      }

      // Start checkmark animation
      _checkAnimationController.forward();

      // Start auto-redirect timer
      _startRedirectTimer();

      // Trigger animation completion
      Future.delayed(1.seconds, () {
        if (mounted) {
          setState(() {
            _animationComplete = true;
          });
        }
      });
    } catch (e, stackTrace) {
      debugLog('PaymentSuccessScreen', '❌ Error loading data: $e\n$stackTrace');
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to load payment details: $e';
        _isLoading = false;
      });
    }
  }

  void _startRedirectTimer() {
    _redirectTimer = Timer.periodic(1.seconds, (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        timer.cancel();
        _redirectToHome();
      }
    });
  }

  void _redirectToHome() {
    if (context.mounted) {
      context.go('/');
    }
  }

  Future<void> _tryToLoadFromCache() async {
    try {
      final deviceService = Provider.of<DeviceService>(context, listen: false);
      final cachedPaymentData = await deviceService
          .getCacheItem<Map<String, dynamic>>('last_payment_data');

      if (cachedPaymentData != null) {
        final categoryId = cachedPaymentData['categoryId'];
        final categoryProvider =
            Provider.of<CategoryProvider>(context, listen: false);
        final category = categoryProvider.getCategoryById(categoryId);

        setState(() {
          _category = category;
          _paymentType = cachedPaymentData['paymentType'] ?? 'first_time';
          _amount = (cachedPaymentData['amount'] as num?)?.toDouble() ?? 0.0;
          _paymentMethod = cachedPaymentData['paymentMethod'] ?? 'unknown';
          _isLoading = false;
        });
      } else {
        setState(() {
          _hasError = true;
          _errorMessage = 'No payment information found';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugLog('PaymentSuccessScreen', 'Cache load error: $e');
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to load payment information';
        _isLoading = false;
      });
    }
  }

  Widget _buildErrorScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(AppThemes.spacingXXL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(AppThemes.spacingXL),
                decoration: BoxDecoration(
                  color: AppColors.telegramRed.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 64,
                  color: AppColors.telegramRed,
                ),
              ).animate().shake(duration: 1.seconds),
              SizedBox(height: AppThemes.spacingXL),
              Text(
                'Payment Error',
                style: AppTextStyles.headlineLarge.copyWith(
                  color: AppColors.getTextPrimary(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: AppThemes.spacingL),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.getTextSecondary(context),
                  height: 1.6,
                ),
              ),
              SizedBox(height: AppThemes.spacingXXL),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go('/'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.telegramBlue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      vertical: AppThemes.spacingL,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppThemes.borderRadiusMedium),
                    ),
                  ),
                  child: Text(
                    'Go to Home',
                    style: AppTextStyles.buttonMedium.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              SizedBox(height: AppThemes.spacingM),
              TextButton(
                onPressed: () => context.push('/notifications'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.telegramBlue,
                ),
                child: Text(
                  'Check Notifications',
                  style: AppTextStyles.buttonMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessIcon(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulsing background
        AnimatedBuilder(
          animation: _pulseAnimationController,
          builder: (context, child) {
            return Container(
              width: 140 * _scaleAnimation.value,
              height: 140 * _scaleAnimation.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.telegramGreen.withOpacity(0.3),
                    AppColors.telegramGreen.withOpacity(0.1),
                    Colors.transparent,
                  ],
                  stops: const [0.1, 0.5, 1.0],
                ),
              ),
            );
          },
        ),

        // Checkmark circle
        AnimatedBuilder(
          animation: _checkAnimationController,
          builder: (context, child) {
            return Transform.scale(
              scale:
                  Curves.elasticOut.transform(_checkAnimationController.value),
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.telegramGreen,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.telegramGreen.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: 60,
                  color: Colors.white,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSuccessContent(BuildContext context) {
    final title = _paymentType == 'first_time'
        ? 'Payment Submitted!'
        : 'Renewal Submitted!';

    final message = _category != null
        ? 'Your payment for "${_category!.name}" has been submitted successfully.'
        : 'Your payment has been submitted successfully.';

    return Column(
      children: [
        Text(
          title,
          style: AppTextStyles.displaySmall.copyWith(
            color: AppColors.getTextPrimary(context),
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: AppThemes.spacingM),
        Text(
          message,
          style: AppTextStyles.bodyLarge.copyWith(
            color: AppColors.getTextSecondary(context),
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: AppThemes.spacingM),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppThemes.spacingL,
            vertical: AppThemes.spacingS,
          ),
          decoration: BoxDecoration(
            color: AppColors.statusPending.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppThemes.borderRadiusFull),
            border: Border.all(
              color: AppColors.statusPending,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 16,
                color: AppColors.statusPending,
              ),
              SizedBox(width: 4),
              Text(
                'Pending Verification',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.statusPending,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: AppThemes.spacingXL),
        if (_category != null) _buildPaymentDetails(context),
      ],
    );
  }

  Widget _buildPaymentDetails(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppThemes.spacingL),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          _buildDetailRow(
            icon: Icons.category_rounded,
            label: 'Category',
            value: _category!.name,
          ),
          SizedBox(height: AppThemes.spacingM),
          _buildDetailRow(
            icon: Icons.attach_money_rounded,
            label: 'Amount',
            value: '${_amount.toStringAsFixed(0)} ETB',
          ),
          if (_paymentMethod.isNotEmpty) ...[
            SizedBox(height: AppThemes.spacingM),
            _buildDetailRow(
              icon: Icons.payment_rounded,
              label: 'Method',
              value: _paymentMethod.toUpperCase(),
            ),
          ],
          SizedBox(height: AppThemes.spacingM),
          _buildDetailRow(
            icon: Icons.info_rounded,
            label: 'Status',
            value: 'Pending Verification',
            valueColor: AppColors.statusPending,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.telegramBlue.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 16,
            color: AppColors.telegramBlue,
          ),
        ),
        SizedBox(width: AppThemes.spacingM),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.getTextSecondary(context),
                ),
              ),
              Text(
                value,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: valueColor ?? AppColors.getTextPrimary(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => context.go('/'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.telegramBlue,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                vertical: AppThemes.spacingL,
              ),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppThemes.borderRadiusMedium),
              ),
            ),
            child: Text(
              'Continue to Home',
              style: AppTextStyles.buttonMedium.copyWith(
                color: Colors.white,
              ),
            ),
          ),
        ),
        SizedBox(height: AppThemes.spacingL),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildActionChip(
              icon: Icons.subscriptions_rounded,
              label: 'Subscriptions',
              onTap: () => context.push('/subscriptions'),
            ),
            SizedBox(width: AppThemes.spacingM),
            _buildActionChip(
              icon: Icons.notifications_rounded,
              label: 'Notifications',
              onTap: () => context.push('/notifications'),
            ),
          ],
        ),
        if (_animationComplete) ...[
          SizedBox(height: AppThemes.spacingXL),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppThemes.spacingL,
              vertical: AppThemes.spacingM,
            ),
            decoration: BoxDecoration(
              color: AppColors.getSurface(context),
              borderRadius: BorderRadius.circular(AppThemes.borderRadiusFull),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
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
                Text(
                  'Redirecting in $_secondsRemaining seconds...',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusFull),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppThemes.spacingL,
            vertical: AppThemes.spacingS,
          ),
          decoration: BoxDecoration(
            color: AppColors.getSurface(context),
            borderRadius: BorderRadius.circular(AppThemes.borderRadiusFull),
            border: Border.all(
              color: Theme.of(context).dividerColor,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: AppColors.telegramBlue,
              ),
              SizedBox(width: 4),
              Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.telegramBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(AppThemes.spacingXL),
          child: Column(
            children: [
              SizedBox(height: AppThemes.spacingXXL),
              _buildSuccessIcon(context),
              SizedBox(height: AppThemes.spacingXXL),
              _buildSuccessContent(context),
              SizedBox(height: AppThemes.spacingXXL),
              _buildActionButtons(context),
              SizedBox(height: AppThemes.spacingXXL),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          margin: EdgeInsets.all(AppThemes.spacingXXL),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
              side: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 0.5,
              ),
            ),
            color: AppColors.getCard(context),
            child: Padding(
              padding: EdgeInsets.all(AppThemes.spacingXXXL),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSuccessIcon(context),
                  SizedBox(height: AppThemes.spacingXXL),
                  _buildSuccessContent(context),
                  SizedBox(height: AppThemes.spacingXXL),
                  _buildActionButtons(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        body: Center(
          child: LoadingIndicator(
            message: 'Loading payment details...',
            type: LoadingType.circular,
            color: AppColors.telegramBlue,
          ),
        ),
      );
    }

    if (_hasError) {
      return _buildErrorScreen(context);
    }

    return ResponsiveLayout(
      mobile: _buildMobileLayout(context),
      tablet: _buildDesktopLayout(context),
      desktop: _buildDesktopLayout(context),
      animateTransition: true,
    );
  }
}

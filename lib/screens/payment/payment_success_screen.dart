import 'dart:async';
import 'dart:ui';
import 'package:familyacademyclient/services/device_service.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import 'package:familyacademyclient/utils/responsive_values.dart';
import 'package:familyacademyclient/themes/app_themes.dart';
import 'package:familyacademyclient/providers/category_provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../models/category_model.dart';
import '../../themes/app_colors.dart';
import '../../widgets/common/responsive_widgets.dart';

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
  String _paymentMethodName = '';
  String _categoryName = '';
  String _username = '';
  String _billingCycle = '';
  String _durationText = '';
  String? _accountHolderName;
  bool _animationComplete = false;
  Timer? _redirectTimer;
  int _secondsRemaining = 5;

  late AnimationController _checkAnimationController;
  late AnimationController _pulseAnimationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _checkAnimationController =
        AnimationController(vsync: this, duration: 800.ms);
    _pulseAnimationController =
        AnimationController(vsync: this, duration: 1.seconds)
          ..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
        CurvedAnimation(
            parent: _pulseAnimationController, curve: Curves.easeInOut));

    _loadData();
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    _checkAnimationController.dispose();
    _pulseAnimationController.dispose();
    super.dispose();
  }

  Widget _buildGlassContainer({required Widget child}) {
    return ClipRRect(
      borderRadius:
          BorderRadius.circular(ResponsiveValues.radiusXLarge(context)),
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
            borderRadius:
                BorderRadius.circular(ResponsiveValues.radiusXLarge(context)),
            border: Border.all(
              color: AppColors.telegramBlue.withValues(alpha: 0.2),
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildGradientButton({
    required String label,
    required VoidCallback onPressed,
    required List<Color> gradient,
    IconData? icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius:
            BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withValues(alpha: 0.3),
            blurRadius: ResponsiveValues.spacingS(context),
            offset: Offset(0, ResponsiveValues.spacingXS(context)),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius:
              BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: ResponsiveValues.spacingL(context),
            ),
            alignment: Alignment.center,
            child: ResponsiveRow(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: ResponsiveValues.iconSizeS(context),
                    color: Colors.white,
                  ),
                  const ResponsiveSizedBox(width: AppSpacing.s),
                ],
                ResponsiveText(
                  label,
                  style: AppTextStyles.buttonMedium(context).copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
        borderRadius:
            BorderRadius.circular(ResponsiveValues.radiusFull(context)),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: ResponsiveValues.spacingL(context),
            vertical: ResponsiveValues.spacingS(context),
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.getSurface(context).withValues(alpha: 0.3),
                AppColors.getSurface(context).withValues(alpha: 0.1),
              ],
            ),
            borderRadius:
                BorderRadius.circular(ResponsiveValues.radiusFull(context)),
            border: Border.all(
              color: AppColors.getDivider(context).withValues(alpha: 0.2),
            ),
          ),
          child: ResponsiveRow(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: ResponsiveValues.iconSizeXS(context),
                color: AppColors.telegramBlue,
              ),
              const ResponsiveSizedBox(width: AppSpacing.xs),
              ResponsiveText(
                label,
                style: AppTextStyles.labelSmall(context).copyWith(
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

  Future<void> _loadData() async {
    try {
      final args = widget.extra;
      if (args != null && args.isNotEmpty) {
        _paymentType = args['payment_type'] as String? ?? 'first_time';
        _amount = (args['amount'] as num?)?.toDouble() ?? 0.0;
        _paymentMethod = args['payment_method'] as String? ?? 'unknown';
        _paymentMethodName =
            args['payment_method_name'] as String? ?? _paymentMethod;
        _categoryName = args['category_name'] as String? ?? '';
        _username = args['username'] as String? ?? '';
        _billingCycle = args['billing_cycle'] as String? ?? 'monthly';
        _durationText =
            args['duration_text'] as String? ?? _getAccessDurationText();
        _accountHolderName = args['account_holder_name'] as String?;

        final categoryId = args['category_id'] as int?;
        final category = args['category'];

        if (category is Category) {
          setState(() {
            _category = category;
            _isLoading = false;
          });
        } else if (categoryId != null) {
          final categoryProvider =
              Provider.of<CategoryProvider>(context, listen: false);
          final cat = categoryProvider.getCategoryById(categoryId);
          setState(() {
            _category = cat;
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      } else {
        await _tryToLoadFromCache();
      }

      await _checkAnimationController.forward();
      _startRedirectTimer();
      Future.delayed(1.seconds,
          () => mounted ? setState(() => _animationComplete = true) : null);
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to load payment details: $e';
        _isLoading = false;
      });
    }
  }

  String _getAccessDurationText() {
    if (_billingCycle == 'semester') return '4 months';
    return '1 month';
  }

  void _startRedirectTimer() {
    _redirectTimer = Timer.periodic(1.seconds, (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
        _redirectToHome();
      }
    });
  }

  void _redirectToHome() {
    if (context.mounted) context.go('/');
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
          _paymentMethodName =
              cachedPaymentData['paymentMethodName'] ?? _paymentMethod;
          _categoryName =
              cachedPaymentData['categoryName'] ?? category?.name ?? '';
          _username = cachedPaymentData['username'] ?? '';
          _billingCycle = cachedPaymentData['billingCycle'] ?? 'monthly';
          _durationText =
              cachedPaymentData['durationText'] ?? _getAccessDurationText();
          _accountHolderName =
              cachedPaymentData['accountHolderName'] as String?;
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
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to load payment information';
        _isLoading = false;
      });
    }
  }

  Widget _buildSkeletonLoader() {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: Center(
        child: _buildGlassContainer(
          child: Padding(
            padding: ResponsiveValues.dialogPadding(context),
            child: ResponsiveColumn(
              mainAxisSize: MainAxisSize.min,
              children: [
                Shimmer.fromColors(
                  baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
                  highlightColor: Colors.grey[100]!.withValues(alpha: 0.6),
                  child: Container(
                    width: ResponsiveValues.avatarSizeLarge(context),
                    height: ResponsiveValues.avatarSizeLarge(context),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const ResponsiveSizedBox(height: AppSpacing.xl),
                Shimmer.fromColors(
                  baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
                  highlightColor: Colors.grey[100]!.withValues(alpha: 0.6),
                  child: Container(
                    width: ResponsiveValues.spacingXXXL(context) * 4,
                    height: ResponsiveValues.spacingXL(context),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusSmall(context),
                      ),
                    ),
                  ),
                ),
                const ResponsiveSizedBox(height: AppSpacing.l),
                Shimmer.fromColors(
                  baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
                  highlightColor: Colors.grey[100]!.withValues(alpha: 0.6),
                  child: Container(
                    width: ResponsiveValues.spacingXXXL(context) * 5,
                    height: ResponsiveValues.spacingL(context),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusSmall(context),
                      ),
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

  Widget _buildErrorScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: SafeArea(
        child: Padding(
          padding: ResponsiveValues.dialogPadding(context),
          child: ResponsiveColumn(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: ResponsiveValues.dialogPadding(context),
                decoration: BoxDecoration(
                  color: AppColors.telegramRed.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline_rounded,
                    size: 64, color: AppColors.telegramRed),
              ).animate().shake(duration: 1.seconds),
              const ResponsiveSizedBox(height: AppSpacing.xl),
              ResponsiveText(
                'Payment Error',
                style: AppTextStyles.headlineLarge(context).copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const ResponsiveSizedBox(height: AppSpacing.l),
              ResponsiveText(
                _errorMessage,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyLarge(context).copyWith(
                  color: AppColors.getTextSecondary(context),
                  height: 1.6,
                ),
              ),
              const ResponsiveSizedBox(height: AppSpacing.xxl),
              SizedBox(
                width: double.infinity,
                child: _buildGradientButton(
                  label: 'Go to Home',
                  onPressed: () => context.go('/'),
                  gradient: AppColors.blueGradient,
                ),
              ),
              const ResponsiveSizedBox(height: AppSpacing.m),
              TextButton(
                onPressed: () => context.push('/notifications'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.telegramBlue,
                ),
                child: const Text('Check Notifications'),
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
        AnimatedBuilder(
          animation: _pulseAnimationController,
          builder: (context, child) {
            return Container(
              width: ResponsiveValues.avatarSizeLarge(context) *
                  1.5 *
                  _scaleAnimation.value,
              height: ResponsiveValues.avatarSizeLarge(context) *
                  1.5 *
                  _scaleAnimation.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.telegramGreen.withValues(alpha: 0.3),
                  AppColors.telegramGreen.withValues(alpha: 0.1),
                  Colors.transparent,
                ], stops: const [
                  0.1,
                  0.5,
                  1.0
                ]),
              ),
            );
          },
        ),
        AnimatedBuilder(
          animation: _checkAnimationController,
          builder: (context, child) {
            return Transform.scale(
              scale:
                  Curves.elasticOut.transform(_checkAnimationController.value),
              child: Container(
                width: ResponsiveValues.avatarSizeLarge(context),
                height: ResponsiveValues.avatarSizeLarge(context),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.telegramGreen,
                      AppColors.telegramGreen.withValues(alpha: 0.8),
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.telegramGreen.withValues(alpha: 0.3),
                      blurRadius: ResponsiveValues.spacingXL(context),
                      spreadRadius: ResponsiveValues.spacingS(context),
                    ),
                  ],
                ),
                child: const Icon(Icons.check_rounded,
                    size: 60, color: Colors.white),
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
    final message = _categoryName.isNotEmpty
        ? 'Your payment for "$_categoryName" has been submitted successfully.'
        : 'Your payment has been submitted successfully.';

    return ResponsiveColumn(
      children: [
        ResponsiveText(
          title,
          style: AppTextStyles.displaySmall(context).copyWith(
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const ResponsiveSizedBox(height: AppSpacing.m),
        ResponsiveText(
          message,
          style: AppTextStyles.bodyLarge(context).copyWith(
            color: AppColors.getTextSecondary(context),
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const ResponsiveSizedBox(height: AppSpacing.m),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: ResponsiveValues.spacingL(context),
            vertical: ResponsiveValues.spacingS(context),
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.statusPending.withValues(alpha: 0.2),
                AppColors.statusPending.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(
              ResponsiveValues.radiusFull(context),
            ),
            border: Border.all(
              color: AppColors.statusPending.withValues(alpha: 0.3),
            ),
          ),
          child: ResponsiveRow(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.schedule_rounded,
                  size: 16, color: AppColors.statusPending),
              const ResponsiveSizedBox(width: AppSpacing.xs),
              ResponsiveText(
                'Pending Verification',
                style: AppTextStyles.labelSmall(context).copyWith(
                  color: AppColors.statusPending,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const ResponsiveSizedBox(height: AppSpacing.xl),
        _buildPaymentDetails(),
      ],
    );
  }

  Widget _buildPaymentDetails() {
    return _buildGlassContainer(
      child: Padding(
        padding: ResponsiveValues.cardPadding(context),
        child: ResponsiveColumn(
          children: [
            _buildDetailRow(
              icon: Icons.category_rounded,
              label: 'Category',
              value: _categoryName.isNotEmpty
                  ? _categoryName
                  : (_category?.name ?? 'N/A'),
            ),
            const ResponsiveSizedBox(height: AppSpacing.m),
            _buildDetailRow(
              icon: Icons.attach_money_rounded,
              label: 'Amount',
              value: '${_amount.toStringAsFixed(0)} ETB',
            ),
            if (_paymentMethodName.isNotEmpty) ...[
              const ResponsiveSizedBox(height: AppSpacing.m),
              _buildDetailRow(
                icon: Icons.payment_rounded,
                label: 'Method',
                value: _paymentMethodName,
              ),
            ],
            if (_accountHolderName != null &&
                _accountHolderName!.isNotEmpty) ...[
              const ResponsiveSizedBox(height: AppSpacing.m),
              _buildDetailRow(
                icon: Icons.person_rounded,
                label: 'Account Holder',
                value: _accountHolderName!,
              ),
            ],
            if (_username.isNotEmpty) ...[
              const ResponsiveSizedBox(height: AppSpacing.m),
              _buildDetailRow(
                icon: Icons.person_rounded,
                label: 'Username',
                value: _username,
              ),
            ],
            const ResponsiveSizedBox(height: AppSpacing.m),
            _buildDetailRow(
              icon: Icons.calendar_today_rounded,
              label: 'Billing Cycle',
              value: _billingCycle == 'semester'
                  ? 'Semester (4 months)'
                  : 'Monthly (1 month)',
            ),
            const ResponsiveSizedBox(height: AppSpacing.m),
            _buildDetailRow(
              icon: Icons.timer_rounded,
              label: 'Access Duration',
              value: _durationText,
            ),
            const ResponsiveSizedBox(height: AppSpacing.m),
            _buildDetailRow(
              icon: Icons.info_rounded,
              label: 'Status',
              value: 'Pending Verification',
              valueColor: AppColors.statusPending,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return ResponsiveRow(
      children: [
        Container(
          width: ResponsiveValues.iconSizeL(context),
          height: ResponsiveValues.iconSizeL(context),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.telegramBlue.withValues(alpha: 0.2),
                AppColors.telegramPurple.withValues(alpha: 0.1),
              ],
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: ResponsiveValues.iconSizeXS(context),
            color: AppColors.telegramBlue,
          ),
        ),
        const ResponsiveSizedBox(width: AppSpacing.m),
        Expanded(
          child: ResponsiveRow(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ResponsiveText(
                label,
                style: AppTextStyles.bodyMedium(context).copyWith(
                  color: AppColors.getTextSecondary(context),
                ),
              ),
              ResponsiveText(
                value,
                style: AppTextStyles.bodyMedium(context).copyWith(
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
    return ResponsiveColumn(
      children: [
        SizedBox(
          width: double.infinity,
          child: _buildGradientButton(
            label: 'Continue to Home',
            onPressed: () => context.go('/'),
            gradient: AppColors.blueGradient,
          ),
        ),
        const ResponsiveSizedBox(height: AppSpacing.l),
        ResponsiveRow(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildActionChip(
              icon: Icons.subscriptions_rounded,
              label: 'Subscriptions',
              onTap: () => context.push('/subscriptions'),
            ),
            const ResponsiveSizedBox(width: AppSpacing.m),
            _buildActionChip(
              icon: Icons.notifications_rounded,
              label: 'Notifications',
              onTap: () => context.push('/notifications'),
            ),
          ],
        ),
        if (_animationComplete) ...[
          const ResponsiveSizedBox(height: AppSpacing.xl),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveValues.spacingL(context),
              vertical: ResponsiveValues.spacingM(context),
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.getSurface(context).withValues(alpha: 0.3),
                  AppColors.getSurface(context).withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(
                ResponsiveValues.radiusFull(context),
              ),
            ),
            child: ResponsiveRow(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: ResponsiveValues.iconSizeS(context),
                  height: ResponsiveValues.iconSizeS(context),
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.telegramBlue),
                  ),
                ),
                const ResponsiveSizedBox(width: AppSpacing.m),
                ResponsiveText(
                  'Redirecting in $_secondsRemaining seconds...',
                  style: AppTextStyles.bodySmall(context).copyWith(
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

  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: ResponsiveValues.screenPadding(context),
          child: ResponsiveColumn(
            children: [
              const ResponsiveSizedBox(height: AppSpacing.xxl),
              _buildSuccessIcon(context),
              const ResponsiveSizedBox(height: AppSpacing.xxl),
              _buildSuccessContent(context),
              const ResponsiveSizedBox(height: AppSpacing.xxl),
              _buildActionButtons(context),
              const ResponsiveSizedBox(height: AppSpacing.xxl),
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
        child: ResponsiveContainer(
          maxWidth: 500,
          margin: ResponsiveValues.dialogPadding(context),
          child: _buildGlassContainer(
            child: Padding(
              padding: ResponsiveValues.dialogPadding(context),
              child: ResponsiveColumn(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSuccessIcon(context),
                  const ResponsiveSizedBox(height: AppSpacing.xxl),
                  _buildSuccessContent(context),
                  const ResponsiveSizedBox(height: AppSpacing.xxl),
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
      return _buildSkeletonLoader();
    }

    if (_hasError) return _buildErrorScreen(context);

    return ResponsiveLayout(
      mobile: _buildMobileLayout(context),
      tablet: _buildDesktopLayout(context),
      desktop: _buildDesktopLayout(context),
    );
  }
}

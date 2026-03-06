import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/category_model.dart';
import '../../services/device_service.dart';
import '../../providers/category_provider.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_shimmer.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/responsive.dart';
import '../../utils/responsive_values.dart';
import '../../utils/app_enums.dart';
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
          final categoryProvider = context.read<CategoryProvider>();
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
    return _billingCycle == 'semester' ? '4 months' : '1 month';
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
      final deviceService = context.read<DeviceService>();
      final cachedPaymentData = await deviceService
          .getCacheItem<Map<String, dynamic>>('last_payment_data');

      if (cachedPaymentData != null) {
        final categoryId = cachedPaymentData['categoryId'];
        final categoryProvider = context.read<CategoryProvider>();
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
        child: AppCard.glass(
          child: Padding(
            padding: ResponsiveValues.dialogPadding(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppShimmer(type: ShimmerType.circle),
                SizedBox(height: ResponsiveValues.spacingXL(context)),
                const AppShimmer(type: ShimmerType.textLine, customWidth: 200),
                SizedBox(height: ResponsiveValues.spacingL(context)),
                const AppShimmer(type: ShimmerType.textLine, customWidth: 250),
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
          child: AppEmptyState.error(
            title: 'Payment Error',
            message: _errorMessage,
            onRetry: () => context.go('/'),
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
                gradient: RadialGradient(
                  colors: [
                    AppColors.telegramGreen.withValues(alpha: 0.3),
                    AppColors.telegramGreen.withValues(alpha: 0.1),
                    Colors.transparent
                  ],
                  stops: const [0.1, 0.5, 1.0],
                ),
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
                      AppColors.telegramGreen.withValues(alpha: 0.8)
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

    return Column(
      children: [
        Text(
          title,
          style: AppTextStyles.displaySmall(context)
              .copyWith(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: ResponsiveValues.spacingM(context)),
        Text(
          message,
          style: AppTextStyles.bodyLarge(context).copyWith(
              color: AppColors.getTextSecondary(context), height: 1.5),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: ResponsiveValues.spacingM(context)),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: ResponsiveValues.spacingL(context),
            vertical: ResponsiveValues.spacingS(context),
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.pending.withValues(alpha: 0.2),
                AppColors.pending.withValues(alpha: 0.1)
              ],
            ),
            borderRadius:
                BorderRadius.circular(ResponsiveValues.radiusFull(context)),
            border: Border.all(color: AppColors.pending.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.schedule_rounded,
                  size: 16, color: AppColors.pending),
              SizedBox(width: ResponsiveValues.spacingXS(context)),
              Text(
                'Pending Verification',
                style: AppTextStyles.labelSmall(context).copyWith(
                    color: AppColors.pending, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        SizedBox(height: ResponsiveValues.spacingXL(context)),
        _buildPaymentDetails(),
      ],
    );
  }

  Widget _buildPaymentDetails() {
    return AppCard.glass(
      child: Padding(
        padding: ResponsiveValues.cardPadding(context),
        child: Column(
          children: [
            _buildDetailRow(
              icon: Icons.category_rounded,
              label: 'Category',
              value: _categoryName.isNotEmpty
                  ? _categoryName
                  : (_category?.name ?? 'N/A'),
            ),
            SizedBox(height: ResponsiveValues.spacingM(context)),
            _buildDetailRow(
              icon: Icons.attach_money_rounded,
              label: 'Amount',
              value: '${_amount.toStringAsFixed(0)} ETB',
            ),
            if (_paymentMethodName.isNotEmpty) ...[
              SizedBox(height: ResponsiveValues.spacingM(context)),
              _buildDetailRow(
                icon: Icons.payment_rounded,
                label: 'Method',
                value: _paymentMethodName,
              ),
            ],
            if (_accountHolderName != null &&
                _accountHolderName!.isNotEmpty) ...[
              SizedBox(height: ResponsiveValues.spacingM(context)),
              _buildDetailRow(
                icon: Icons.person_rounded,
                label: 'Account Holder',
                value: _accountHolderName!,
              ),
            ],
            if (_username.isNotEmpty) ...[
              SizedBox(height: ResponsiveValues.spacingM(context)),
              _buildDetailRow(
                icon: Icons.person_rounded,
                label: 'Username',
                value: _username,
              ),
            ],
            SizedBox(height: ResponsiveValues.spacingM(context)),
            _buildDetailRow(
              icon: Icons.calendar_today_rounded,
              label: 'Billing Cycle',
              value: _billingCycle == 'semester'
                  ? 'Semester (4 months)'
                  : 'Monthly (1 month)',
            ),
            SizedBox(height: ResponsiveValues.spacingM(context)),
            _buildDetailRow(
              icon: Icons.timer_rounded,
              label: 'Access Duration',
              value: _durationText,
            ),
            SizedBox(height: ResponsiveValues.spacingM(context)),
            _buildDetailRow(
              icon: Icons.info_rounded,
              label: 'Status',
              value: 'Pending Verification',
              valueColor: AppColors.pending,
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
    return Row(
      children: [
        Container(
          width: ResponsiveValues.iconSizeL(context),
          height: ResponsiveValues.iconSizeL(context),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.telegramBlue.withValues(alpha: 0.2),
                AppColors.telegramPurple.withValues(alpha: 0.1)
              ],
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(icon,
              size: ResponsiveValues.iconSizeXS(context),
              color: AppColors.telegramBlue),
        ),
        SizedBox(width: ResponsiveValues.spacingM(context)),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: AppTextStyles.bodyMedium(context)
                      .copyWith(color: AppColors.getTextSecondary(context))),
              Text(
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
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: AppButton.primary(
            label: 'Continue to Home',
            onPressed: () => context.go('/'),
            expanded: true,
          ),
        ),
        SizedBox(height: ResponsiveValues.spacingL(context)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppButton.glass(
              label: 'Subscriptions',
              icon: Icons.subscriptions_rounded,
              onPressed: () => context.push('/subscriptions'),
            ),
            SizedBox(width: ResponsiveValues.spacingM(context)),
            AppButton.glass(
              label: 'Notifications',
              icon: Icons.notifications_rounded,
              onPressed: () => context.push('/notifications'),
            ),
          ],
        ),
        if (_animationComplete) ...[
          SizedBox(height: ResponsiveValues.spacingXL(context)),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveValues.spacingL(context),
              vertical: ResponsiveValues.spacingM(context),
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.getSurface(context).withValues(alpha: 0.3),
                  AppColors.getSurface(context).withValues(alpha: 0.1)
                ],
              ),
              borderRadius:
                  BorderRadius.circular(ResponsiveValues.radiusFull(context)),
            ),
            child: Row(
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
                SizedBox(width: ResponsiveValues.spacingM(context)),
                Text(
                  'Redirecting in $_secondsRemaining seconds...',
                  style: AppTextStyles.bodySmall(context)
                      .copyWith(color: AppColors.getTextSecondary(context)),
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
          child: Column(
            children: [
              SizedBox(height: ResponsiveValues.spacingXXL(context)),
              _buildSuccessIcon(context),
              SizedBox(height: ResponsiveValues.spacingXXL(context)),
              _buildSuccessContent(context),
              SizedBox(height: ResponsiveValues.spacingXXL(context)),
              _buildActionButtons(context),
              SizedBox(height: ResponsiveValues.spacingXXL(context)),
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
          margin: ResponsiveValues.dialogPadding(context),
          child: AppCard.glass(
            child: Padding(
              padding: ResponsiveValues.dialogPadding(context),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSuccessIcon(context),
                  SizedBox(height: ResponsiveValues.spacingXXL(context)),
                  _buildSuccessContent(context),
                  SizedBox(height: ResponsiveValues.spacingXXL(context)),
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
    if (_isLoading) return _buildSkeletonLoader();
    if (_hasError) return _buildErrorScreen(context);

    return ResponsiveLayout(
      mobile: _buildMobileLayout(context),
      tablet: _buildDesktopLayout(context),
      desktop: _buildDesktopLayout(context),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/category_model.dart';
import '../../services/device_service.dart';
import '../../providers/category_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/payment_provider.dart';
import '../../widgets/common/base_screen_mixin.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_button.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/responsive_values.dart';
import '../../utils/constants.dart';
import '../../utils/router.dart';

class PaymentSuccessScreen extends StatefulWidget {
  final Map<String, dynamic>? extra;

  const PaymentSuccessScreen({super.key, this.extra});

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen>
    with BaseScreenMixin<PaymentSuccessScreen>, TickerProviderStateMixin {
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
  bool _isQueued = false;
  int _secondsRemaining = 5;

  late AnimationController _checkAnimationController;
  Timer? _redirectTimer;

  @override
  String get screenTitle => AppStrings.payment;

  @override
  String? get screenSubtitle => null;

  @override
  bool get isLoading => _isLoading;

  @override
  bool get hasCachedData => false;

  @override
  dynamic get errorMessage => _hasError ? _errorMessage : null;

  @override
  ShimmerType get shimmerType => ShimmerType.paymentCard;

  @override
  int get shimmerItemCount => 1;

  @override
  void initState() {
    super.initState();

    _checkAnimationController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 800),
        );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    _checkAnimationController.dispose();
    super.dispose();
  }

  @override
  Future<void> onRefresh() async {}

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
        _isQueued = args['queued'] == true;

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

      Future.delayed(const Duration(seconds: 1), () {
        if (isMounted) setState(() => _animationComplete = true);
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = '${AppStrings.failedToLoadPaymentDetails}: $e';
        _isLoading = false;
      });
    }
  }

  String _getAccessDurationText() {
    return context
        .read<SettingsProvider>()
        .getBillingCycleDurationText(_billingCycle);
  }

  void _startRedirectTimer() {
    _redirectTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
        _redirectToHome();
      }
    });
  }

  void _redirectToHome() {
    if (!isMounted) return;
    _redirectTimer?.cancel();
    unawaited(_syncCriticalStateAndGoHome());
  }

  Future<void> _syncCriticalStateAndGoHome() async {
    if (!isMounted) return;

    final subscriptionProvider = context.read<SubscriptionProvider>();
    final paymentProvider = context.read<PaymentProvider>();
    final categoryProvider = context.read<CategoryProvider>();

    try {
      await subscriptionProvider.forceRefreshFromServer();
      await paymentProvider.loadPayments(forceRefresh: true);
      await categoryProvider.loadCategories(forceRefresh: true);
    } catch (_) {
      // We still navigate home even if refresh fails; home will retry.
    }

    if (isMounted) {
      appRouter.setNavigatingToHome(true);
      context.go('/?from=payment-success');
    }
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
          _isQueued = cachedPaymentData['queued'] == true;
          _isLoading = false;
        });
      } else {
        setState(() {
          _hasError = true;
          _errorMessage = AppStrings.noPaymentInformationFound;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = AppStrings.failedToLoadPaymentInformation;
        _isLoading = false;
      });
    }
  }

  Widget _buildSuccessIcon() {
    final accentColor = _isQueued ? AppColors.info : AppColors.telegramGreen;

    return AnimatedBuilder(
      animation: _checkAnimationController,
      builder: (context, child) {
        return Transform.scale(
          scale: Curves.elasticOut.transform(_checkAnimationController.value),
          child: Container(
            width: ResponsiveValues.successStateOuterSize(context),
            height: ResponsiveValues.successStateOuterSize(context),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.getSurface(context).withValues(alpha: 0.72),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.12),
                  blurRadius: ResponsiveValues.spacingXL(context),
                  spreadRadius: ResponsiveValues.spacingXS(context),
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: ResponsiveValues.avatarSizeLarge(context),
                height: ResponsiveValues.avatarSizeLarge(context),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withValues(alpha: 0.12),
                ),
                child: Icon(
                  _isQueued ? Icons.schedule_rounded : Icons.check_rounded,
                  size: 54,
                  color: accentColor,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSuccessContent() {
    final title = _isQueued
        ? AppStrings.paymentQueued
        : (_paymentType == 'first_time'
            ? AppStrings.paymentSubmitted
            : AppStrings.renewalSubmitted);
    final message = _isQueued
        ? '${AppStrings.yourPaymentFor} "$_categoryName" ${AppStrings.hasBeenSavedOffline}'
        : (_categoryName.isNotEmpty
            ? '${AppStrings.yourPaymentFor} "$_categoryName" ${AppStrings.hasBeenSubmitted}'
            : AppStrings.yourPaymentHasBeenSubmitted);

    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: ResponsiveValues.spacingM(context),
            vertical: ResponsiveValues.spacingS(context),
          ),
          decoration: BoxDecoration(
            color: (_isQueued ? AppColors.info : AppColors.telegramGreen)
                .withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(
              ResponsiveValues.radiusFull(context),
            ),
          ),
          child: Text(
            _isQueued
                ? context.read<SettingsProvider>().getPaymentSuccessSavedBadge()
                : context.read<SettingsProvider>().getPaymentSuccessReviewBadge(),
            style: AppTextStyles.labelMedium(context).copyWith(
              color: _isQueued ? AppColors.info : AppColors.telegramGreen,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(height: ResponsiveValues.spacingL(context)),
        Text(
          title,
          style: AppTextStyles.headlineSmall(context).copyWith(
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: ResponsiveValues.spacingM(context)),
        Text(
          message,
          style: AppTextStyles.bodyLarge(context).copyWith(
            color: AppColors.getTextSecondary(context),
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: ResponsiveValues.spacingS(context)),
        Text(
          _isQueued
              ? context.read<SettingsProvider>().getPaymentSuccessQueuedSummary()
              : context
                  .read<SettingsProvider>()
                  .getPaymentSuccessSubmittedSummary(),
          style: AppTextStyles.bodyMedium(context).copyWith(
            color: AppColors.getTextSecondary(context),
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: ResponsiveValues.spacingL(context)),
        Text(
          _isQueued
              ? context.read<SettingsProvider>().getPaymentSuccessQueuedDetail()
              : context
                  .read<SettingsProvider>()
                  .getPaymentSuccessSubmittedDetail(),
          style: AppTextStyles.bodyMedium(context).copyWith(
            color: AppColors.getTextSecondary(context),
            height: 1.45,
          ),
          textAlign: TextAlign.center,
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
              label: AppStrings.category,
              value: _categoryName.isNotEmpty
                  ? _categoryName
                  : (_category?.name ?? AppStrings.notAvailable),
            ),
            SizedBox(height: ResponsiveValues.spacingM(context)),
            _buildDetailRow(
              icon: Icons.payments_rounded,
              label: AppStrings.amount,
              value:
                  '${_amount.toStringAsFixed(0)} ${AppStrings.currencyLabel}',
            ),
            if (_paymentMethodName.isNotEmpty) ...[
              SizedBox(height: ResponsiveValues.spacingM(context)),
              _buildDetailRow(
                icon: Icons.payment_rounded,
                label: AppStrings.method,
                value: _paymentMethodName,
              ),
            ],
            if (_accountHolderName != null &&
                _accountHolderName!.isNotEmpty) ...[
              SizedBox(height: ResponsiveValues.spacingM(context)),
              _buildDetailRow(
                icon: Icons.person_rounded,
                label: AppStrings.accountHolder,
                value: _accountHolderName!,
              ),
            ],
            if (_username.isNotEmpty) ...[
              SizedBox(height: ResponsiveValues.spacingM(context)),
              _buildDetailRow(
                icon: Icons.person_rounded,
                label: AppStrings.username,
                value: _username,
              ),
            ],
            SizedBox(height: ResponsiveValues.spacingM(context)),
            _buildDetailRow(
              icon: Icons.calendar_today_rounded,
              label: AppStrings.billingCycle,
              value: _billingCycle == 'semester'
                  ? AppStrings.semesterBilling
                  : AppStrings.monthlyBilling,
            ),
            SizedBox(height: ResponsiveValues.spacingM(context)),
            _buildDetailRow(
              icon: Icons.timer_rounded,
              label: AppStrings.accessDuration,
              value: _durationText,
            ),
            SizedBox(height: ResponsiveValues.spacingM(context)),
            _buildDetailRow(
              icon: Icons.info_rounded,
              label: AppStrings.status,
              value: _isQueued
                  ? AppStrings.queuedForSync
                  : AppStrings.pendingVerification,
              valueColor: _isQueued ? AppColors.info : AppColors.pending,
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: ResponsiveValues.iconSizeL(context),
          height: ResponsiveValues.iconSizeL(context),
          decoration: BoxDecoration(
            color: AppColors.telegramBlue.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: ResponsiveValues.iconSizeXS(context),
            color: AppColors.telegramBlue,
          ),
        ),
        SizedBox(width: ResponsiveValues.spacingM(context)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.labelMedium(context).copyWith(
                  color: AppColors.getTextSecondary(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: ResponsiveValues.spacingXXS(context)),
              Text(
                value,
                style: AppTextStyles.bodyMedium(context).copyWith(
                  color: valueColor ?? AppColors.getTextPrimary(context),
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: AppButton.primary(
            label: AppStrings.continueToHome,
            onPressed: _redirectToHome,
            expanded: true,
          ),
        ),
        SizedBox(height: ResponsiveValues.spacingL(context)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppButton.glass(
              label: AppStrings.notifications,
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
                  AppColors.getSurface(context).withValues(alpha: 0.1),
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
                  '${AppStrings.redirectingIn} $_secondsRemaining ${AppStrings.seconds}...',
                  style: AppTextStyles.bodySmall(context).copyWith(
                    color: AppColors.getTextSecondary(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget buildContent(BuildContext context) {
    if (isLoading) {
      return Center(
        child: buildLoadingShimmer(),
      );
    }

    if (_hasError) {
      return Center(
        child: buildErrorWidget(_errorMessage, onRetry: () => context.go('/')),
      );
    }

    return SingleChildScrollView(
      padding: ResponsiveValues.screenPadding(context),
      child: Column(
        children: [
          _buildSuccessIcon(),
          SizedBox(height: ResponsiveValues.spacingXXL(context)),
          _buildSuccessContent(),
          SizedBox(height: ResponsiveValues.spacingXXL(context)),
          _buildActionButtons(),
          SizedBox(height: ResponsiveValues.spacingXXL(context)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return buildScreen(
      content: buildContent(context),
      showAppBar: false,
      showRefreshIndicator: false,
    );
  }
}

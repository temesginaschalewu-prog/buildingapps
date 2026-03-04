import 'dart:io';
import 'dart:ui';
import 'package:familyacademyclient/services/device_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:familyacademyclient/services/user_session.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import 'package:familyacademyclient/utils/responsive_values.dart';
import 'package:familyacademyclient/themes/app_themes.dart';
import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';
import 'package:shimmer/shimmer.dart';
import '../../models/category_model.dart';
import '../../providers/payment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/category_provider.dart';
import '../../utils/helpers.dart';
import '../../widgets/common/responsive_widgets.dart';
import '../../widgets/common/app_bar.dart';

class PaymentScreen extends StatefulWidget {
  final Map<String, dynamic>? extra;
  const PaymentScreen({super.key, this.extra});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _accountHolderNameController = TextEditingController();
  final _picker = ImagePicker();

  late AnimationController _animationController;

  PaymentMethod? _selectedPaymentMethod;
  File? _proofImageFile;
  bool _confirmAccuracy = false;
  bool _isLoading = false;
  bool _hasError = false;
  bool _isLoadingMethods = true;
  String _errorMessage = '';
  Category? _category;
  String _username = '';
  double _amount = 0.0;
  String _billingCycle = 'monthly';
  String _paymentType = 'first_time';
  int _monthsToAdd = 1;

  bool _initialized = false;
  bool _settingsLoadAttempted = false;
  List<PaymentMethod> _cachedMethods = [];
  bool _isOffline = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: AppThemes.animationDurationMedium,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getCurrentUserId();
      _checkConnectivity();
      _initializeData();
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _accountHolderNameController.dispose();
    _animationController.dispose();
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
    required VoidCallback? onPressed,
    required List<Color> gradient,
    IconData? icon,
    bool isLoading = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: onPressed != null ? LinearGradient(colors: gradient) : null,
        color: onPressed == null
            ? AppColors.telegramGray.withValues(alpha: 0.2)
            : null,
        borderRadius:
            BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
        boxShadow: onPressed != null
            ? [
                BoxShadow(
                  color: gradient.first.withValues(alpha: 0.3),
                  blurRadius: ResponsiveValues.spacingS(context),
                  offset: Offset(0, ResponsiveValues.spacingXS(context)),
                ),
              ]
            : null,
      ),
      child: Material(
        color: onPressed != null ? Colors.transparent : Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius:
              BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: ResponsiveValues.spacingL(context),
            ),
            alignment: Alignment.center,
            child: isLoading
                ? SizedBox(
                    width: ResponsiveValues.iconSizeM(context),
                    height: ResponsiveValues.iconSizeM(context),
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : ResponsiveRow(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(
                          icon,
                          size: ResponsiveValues.iconSizeS(context),
                          color: onPressed != null
                              ? Colors.white
                              : AppColors.getTextSecondary(context),
                        ),
                        ResponsiveSizedBox(width: AppSpacing.s),
                      ],
                      ResponsiveText(
                        label,
                        style: AppTextStyles.buttonMedium(context).copyWith(
                          color: onPressed != null
                              ? Colors.white
                              : AppColors.getTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _getCurrentUserId() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _currentUserId = authProvider.currentUser?.id.toString();
  }

  Future<void> _checkConnectivity() async {
    final hasConnection = await hasInternetConnection();
    if (!hasConnection) {
      setState(() => _isOffline = true);
      showOfflineMessage(context);
    }
  }

  Future<void> _loadCachedPaymentMethods() async {
    try {
      final deviceService = Provider.of<DeviceService>(context, listen: false);
      final cachedMethods = await deviceService.getCacheItem<List<dynamic>>(
        'payment_methods_$_currentUserId',
        isUserSpecific: true,
      );

      if (cachedMethods != null && mounted) {
        setState(() {
          _cachedMethods = cachedMethods
              .map((m) => PaymentMethod(
                    method: m['method'],
                    name: m['name'],
                    accountInfo: m['accountInfo'],
                    instructions: m['instructions'],
                    iconData: Icons.payment,
                  ))
              .toList();
          _isLoadingMethods = false;
        });
      }
    } catch (e) {
      debugLog('PaymentScreen', 'Error loading cached methods: $e');
    }
  }

  void _initializeData() {
    if (_initialized) return;

    try {
      final args = widget.extra;
      if (args == null) {
        if (_isOffline) {
          _loadCachedPaymentMethods();
        }
        setState(() {
          _hasError = true;
          _errorMessage = 'No payment data provided';
        });
        return;
      }

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);

      Category? category;
      final dynamic categoryData = args['category'];

      if (categoryData is Category) {
        category = categoryData;
      } else if (categoryData is Map<String, dynamic>) {
        if (categoryData['price'] != null) {
          category = Category(
            id: categoryData['id'] ?? 0,
            name: categoryData['name'] ?? 'Unknown',
            status: 'active',
            price: double.parse(categoryData['price'].toString()),
            billingCycle: categoryData['billing_cycle'] ?? 'monthly',
            description: categoryData['description'],
          );
        } else {
          category = categoryProvider.getCategoryById(categoryData['id']);
        }
      }

      if (category == null) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Category not found';
        });
        return;
      }

      _monthsToAdd = category.billingCycle == 'semester' ? 4 : 1;

      setState(() {
        _username = authProvider.currentUser?.username ?? '';
        _amount = category?.price ?? 0.0;
        _billingCycle = category!.billingCycle;
        _category = category;
        _paymentType = args['paymentType'] ?? 'first_time';
        _hasError = false;
        _isLoadingMethods = true;
        _initialized = true;
      });

      _loadPaymentMethods();
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to initialize: $e';
      });
    }
  }

  Future<void> _loadPaymentMethods() async {
    if (_settingsLoadAttempted) return;
    _settingsLoadAttempted = true;

    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);

    if (settingsProvider.allSettings.isEmpty && !_isOffline) {
      await settingsProvider.getAllSettings();
    }

    _cachedMethods = settingsProvider.getPaymentMethods();

    if (_cachedMethods.isNotEmpty && _currentUserId != null && !_isOffline) {
      try {
        final deviceService =
            Provider.of<DeviceService>(context, listen: false);
        await deviceService.saveCacheItem(
          'payment_methods_$_currentUserId',
          _cachedMethods
              .map((m) => {
                    'method': m.method,
                    'name': m.name,
                    'accountInfo': m.accountInfo,
                    'instructions': m.instructions,
                  })
              .toList(),
          ttl: const Duration(days: 7),
          isUserSpecific: true,
        );
      } catch (e) {}
    }

    if (mounted) setState(() => _isLoadingMethods = false);
  }

  Future<void> _pickImage() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );
      if (image != null) {
        final file = File(image.path);
        final sizeInMB = await file.length() / (1024 * 1024);

        if (sizeInMB > 5) {
          showTopSnackBar(context, 'Image must be less than 5MB',
              isError: true);
          return;
        }

        setState(() => _proofImageFile = file);
      }
    } catch (e) {
      showTopSnackBar(context, 'Failed to pick image: $e', isError: true);
    }
  }

  String _getBillingCycleDescription() {
    if (_billingCycle == 'semester') {
      return 'Semester (4 months)';
    }
    return 'Monthly (1 month)';
  }

  String _getAccessDurationText() {
    if (_billingCycle == 'semester') {
      return 'You will get access for 4 months';
    }
    return 'You will get access for 1 month';
  }

  String? _validateAccountHolderName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Account holder name is required';
    }
    if (value.trim().length < 3) {
      return 'Account holder name must be at least 3 characters';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  Widget _buildPaymentMethodDropdown(List<PaymentMethod> methods) {
    final uniqueMethods = <PaymentMethod>[];
    final seenKeys = <String>{};

    for (final method in methods) {
      final key = '${method.method}-${method.name}';
      if (!seenKeys.contains(key)) {
        seenKeys.add(key);
        uniqueMethods.add(method);
      }
    }

    return ResponsiveColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResponsiveText(
          'Payment Method',
          style: AppTextStyles.labelMedium(context),
        ),
        ResponsiveSizedBox(height: AppSpacing.s),
        _buildGlassContainer(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButtonFormField<PaymentMethod>(
              value: _selectedPaymentMethod,
              hint: Padding(
                padding: ResponsiveValues.listItemPadding(context),
                child: ResponsiveText(
                  'Select a payment method',
                  style: AppTextStyles.bodyMedium(context).copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
              ),
              isExpanded: true,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              icon: Icon(Icons.arrow_drop_down_rounded,
                  color: AppColors.getTextSecondary(context)),
              items: uniqueMethods.map((method) {
                return DropdownMenuItem<PaymentMethod>(
                  value: method,
                  child: ResponsiveRow(
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
                          borderRadius: BorderRadius.circular(
                            ResponsiveValues.radiusSmall(context),
                          ),
                        ),
                        child: Icon(method.iconData,
                            size: ResponsiveValues.iconSizeXS(context),
                            color: AppColors.telegramBlue),
                      ),
                      ResponsiveSizedBox(width: AppSpacing.m),
                      Expanded(
                        child: RichText(
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            style: DefaultTextStyle.of(context).style,
                            children: [
                              TextSpan(
                                text: '${method.name}\n',
                                style: AppTextStyles.bodyMedium(context),
                              ),
                              TextSpan(
                                text: method.accountInfo.split('\n').first,
                                style: AppTextStyles.caption(context).copyWith(
                                  color: AppColors.getTextSecondary(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: !_isOffline
                  ? (PaymentMethod? newValue) =>
                      setState(() => _selectedPaymentMethod = newValue)
                  : null,
            ),
          ),
        ),
        if (_isOffline)
          Padding(
            padding: EdgeInsets.only(
              top: ResponsiveValues.spacingS(context),
            ),
            child: ResponsiveText(
              'Payment methods require internet connection',
              style: AppTextStyles.caption(context).copyWith(
                color: AppColors.telegramYellow,
              ),
            ),
          ),
        if (_selectedPaymentMethod != null) ...[
          ResponsiveSizedBox(height: AppSpacing.l),
          _buildGlassContainer(
            child: Padding(
              padding: ResponsiveValues.cardPadding(context),
              child: ResponsiveColumn(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ResponsiveRow(
                    children: [
                      const Icon(Icons.info_rounded,
                          size: 16, color: AppColors.telegramBlue),
                      ResponsiveSizedBox(width: AppSpacing.s),
                      ResponsiveText(
                        'Account Details',
                        style: AppTextStyles.labelMedium(context).copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  ResponsiveSizedBox(height: AppSpacing.m),
                  Container(
                    padding: ResponsiveValues.cardPadding(context),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.getCard(context).withValues(alpha: 0.3),
                          AppColors.getCard(context).withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusSmall(context),
                      ),
                    ),
                    child: ResponsiveRow(
                      children: [
                        Expanded(
                          child: ResponsiveText(
                            _selectedPaymentMethod!.accountInfo,
                            style: AppTextStyles.bodyMedium(context),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(
                                text: _selectedPaymentMethod!.accountInfo));
                            showTopSnackBar(context, 'Copied to clipboard');
                          },
                          child: Container(
                            padding: EdgeInsets.all(
                                ResponsiveValues.spacingXXS(context)),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.telegramBlue.withValues(alpha: 0.2),
                                  AppColors.telegramBlue.withValues(alpha: 0.1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(
                                ResponsiveValues.radiusSmall(context),
                              ),
                            ),
                            child: const Icon(Icons.copy_rounded,
                                size: 16, color: AppColors.telegramBlue),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ResponsiveSizedBox(height: AppSpacing.m),
                  ResponsiveText(
                    'Instructions',
                    style: AppTextStyles.labelSmall(context).copyWith(
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                  ResponsiveSizedBox(height: AppSpacing.xs),
                  ResponsiveText(
                    _selectedPaymentMethod!.instructions,
                    style: AppTextStyles.bodySmall(context).copyWith(
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSkeletonLoader() {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: _buildAppBar(context),
      body: SingleChildScrollView(
        child: Padding(
          padding: ResponsiveValues.screenPadding(context),
          child: ResponsiveColumn(
            children: [
              _buildGlassContainer(
                child: Padding(
                  padding: ResponsiveValues.cardPadding(context),
                  child: ResponsiveColumn(
                    children: List.generate(
                      5,
                      (index) => Padding(
                        padding: EdgeInsets.only(
                          bottom: ResponsiveValues.spacingM(context),
                        ),
                        child: ResponsiveRow(
                          children: [
                            Shimmer.fromColors(
                              baseColor:
                                  Colors.grey[300]!.withValues(alpha: 0.3),
                              highlightColor:
                                  Colors.grey[100]!.withValues(alpha: 0.6),
                              child: Container(
                                width: ResponsiveValues.iconSizeL(context),
                                height: ResponsiveValues.iconSizeL(context),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            ResponsiveSizedBox(width: AppSpacing.m),
                            Expanded(
                              child: Shimmer.fromColors(
                                baseColor:
                                    Colors.grey[300]!.withValues(alpha: 0.3),
                                highlightColor:
                                    Colors.grey[100]!.withValues(alpha: 0.6),
                                child: Container(
                                  height: ResponsiveValues.spacingL(context),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(
                                      ResponsiveValues.radiusSmall(context),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              ResponsiveSizedBox(height: AppSpacing.xl),
              _buildGlassContainer(
                child: Padding(
                  padding: ResponsiveValues.cardPadding(context),
                  child: ResponsiveColumn(
                    children: List.generate(
                      4,
                      (index) => Padding(
                        padding: EdgeInsets.only(
                          bottom: ResponsiveValues.spacingL(context),
                        ),
                        child: Shimmer.fromColors(
                          baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
                          highlightColor:
                              Colors.grey[100]!.withValues(alpha: 0.6),
                          child: Container(
                            height:
                                ResponsiveValues.buttonHeightMedium(context),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(
                                ResponsiveValues.radiusMedium(context),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitPayment() async {
    if (_category == null) {
      showTopSnackBar(context, 'Category information missing', isError: true);
      return;
    }

    if (_amount <= 0) {
      showTopSnackBar(context, 'Invalid payment amount', isError: true);
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    if (_selectedPaymentMethod == null) {
      showTopSnackBar(context, 'Please select a payment method', isError: true);
      return;
    }

    if (_proofImageFile == null) {
      showTopSnackBar(context, 'Please upload payment proof', isError: true);
      return;
    }

    if (!_confirmAccuracy) {
      showTopSnackBar(context, 'Please confirm accuracy', isError: true);
      return;
    }

    final hasConnection = await hasInternetConnection();
    if (!hasConnection) {
      showTopSnackBar(
        context,
        'You are offline. Please check your internet connection.',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    final paymentProvider =
        Provider.of<PaymentProvider>(context, listen: false);
    final subscriptionProvider =
        Provider.of<SubscriptionProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final paymentMethod = _selectedPaymentMethod!.method;

      String? proofImageUrl;
      try {
        final apiService = paymentProvider.apiService;
        final uploadResponse =
            await apiService.uploadPaymentProof(_proofImageFile!);
        if (uploadResponse.success && uploadResponse.data != null) {
          proofImageUrl = uploadResponse.data;
        } else {
          showTopSnackBar(context, 'Failed to upload payment proof',
              isError: true);
          setState(() => _isLoading = false);
          return;
        }
      } catch (uploadError) {
        showTopSnackBar(context, 'Failed to upload image', isError: true);
        setState(() => _isLoading = false);
        return;
      }

      final accountHolderName = _accountHolderNameController.text.trim();

      final result = await paymentProvider.submitPayment(
        categoryId: _category!.id,
        paymentType: _paymentType,
        paymentMethod: paymentMethod,
        amount: _amount,
        accountHolderName:
            accountHolderName.isNotEmpty ? accountHolderName : null,
        proofImagePath: proofImageUrl,
      );

      if (result['success'] == true) {
        await subscriptionProvider.refreshAfterPaymentVerification();
        await authProvider.checkSession();

        if (mounted) {
          showTopSnackBar(context, 'Payment submitted successfully!');
          context.push('/payment-success', extra: {
            'category': _category,
            'category_id': _category!.id,
            'category_name': _category!.name,
            'payment_type': _paymentType,
            'payment_method': paymentMethod,
            'payment_method_name': _selectedPaymentMethod!.name,
            'amount': _amount,
            'billing_cycle': _billingCycle,
            'months': _monthsToAdd,
            'duration_text': _getAccessDurationText(),
            'username': _username,
            'account_holder_name':
                accountHolderName.isNotEmpty ? accountHolderName : null,
            'timestamp': DateTime.now().toIso8601String(),
          });
        }
      } else {
        final message = result['message'] ?? 'Payment failed';
        final action = result['action'];

        if (action == 'device_change_required') {
          if (mounted) {
            context.push('/device-change', extra: {
              'message': message,
              'action': action,
              'data': result['data']
            });
          }
        } else {
          if (mounted) showTopSnackBar(context, message, isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        showTopSnackBar(context, 'Payment failed: ${e.toString()}',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getPaymentTypeText() {
    switch (_paymentType) {
      case 'first_time':
        return 'First Time Payment';
      case 'repayment':
        return 'Renewal Payment';
      default:
        return 'Payment';
    }
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: ResponsiveIcon(
          Icons.arrow_back_rounded,
          color: AppColors.getTextPrimary(context),
        ),
        onPressed: () => GoRouter.of(context).pop(),
      ),
      title: ResponsiveText(
        'Payment',
        style: AppTextStyles.appBarTitle(context),
      ),
      centerTitle: false,
    );
  }

  Widget _buildPaymentSummary() {
    return _buildGlassContainer(
      child: Padding(
        padding: ResponsiveValues.cardPadding(context),
        child: ResponsiveColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ResponsiveRow(
              children: [
                Container(
                  width: ResponsiveValues.iconSizeXL(context) * 1.5,
                  height: ResponsiveValues.iconSizeXL(context) * 1.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.telegramBlue.withValues(alpha: 0.2),
                        AppColors.telegramPurple.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(
                      ResponsiveValues.radiusMedium(context),
                    ),
                  ),
                  child: const Icon(Icons.payment_rounded,
                      color: AppColors.telegramBlue, size: 24),
                ),
                ResponsiveSizedBox(width: AppSpacing.l),
                Expanded(
                  child: ResponsiveColumn(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ResponsiveText(
                        _category?.name ?? 'Payment',
                        style: AppTextStyles.titleMedium(context),
                      ),
                      ResponsiveSizedBox(height: AppSpacing.xs),
                      ResponsiveText(
                        _getPaymentTypeText(),
                        style: AppTextStyles.bodySmall(context).copyWith(
                          color: AppColors.getTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                ResponsiveColumn(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ResponsiveText(
                      _amount.toStringAsFixed(0),
                      style: AppTextStyles.displaySmall(context).copyWith(
                        color: AppColors.telegramBlue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    ResponsiveText(
                      'ETB',
                      style: AppTextStyles.labelMedium(context).copyWith(
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            ResponsiveSizedBox(height: AppSpacing.l),
            Divider(
              color: AppColors.getDivider(context).withValues(alpha: 0.2),
              height: 1,
            ),
            ResponsiveSizedBox(height: AppSpacing.l),
            _buildSummaryRow(
              icon: Icons.category_rounded,
              label: 'Category',
              value: _category?.name ?? 'N/A',
            ),
            ResponsiveSizedBox(height: AppSpacing.s),
            _buildSummaryRow(
              icon: Icons.calendar_today_rounded,
              label: 'Billing Cycle',
              value: _getBillingCycleDescription(),
            ),
            ResponsiveSizedBox(height: AppSpacing.s),
            _buildSummaryRow(
              icon: Icons.timer_rounded,
              label: 'Access Duration',
              value: _getAccessDurationText(),
            ),
            ResponsiveSizedBox(height: AppSpacing.s),
            _buildSummaryRow(
              icon: Icons.person_rounded,
              label: 'Username',
              value: _username,
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: AppThemes.animationDurationMedium, delay: 100.ms)
        .slideY(
            begin: 0.1, end: 0, duration: AppThemes.animationDurationMedium);
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required String label,
    required String value,
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
        ResponsiveSizedBox(width: AppSpacing.m),
        Expanded(
          child: ResponsiveRow(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ResponsiveText(
                label,
                style: AppTextStyles.bodySmall(context).copyWith(
                  color: AppColors.getTextSecondary(context),
                ),
              ),
              ResponsiveText(
                value,
                style: AppTextStyles.bodyMedium(context).copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentForm(List<PaymentMethod> methods) {
    return _buildGlassContainer(
      child: Padding(
        padding: ResponsiveValues.cardPadding(context),
        child: Form(
          key: _formKey,
          child: ResponsiveColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ResponsiveText(
                'Payment Details',
                style: AppTextStyles.titleMedium(context),
              ),
              ResponsiveSizedBox(height: AppSpacing.l),
              _buildPaymentMethodDropdown(methods),
              ResponsiveSizedBox(height: AppSpacing.l),
              ResponsiveText(
                'Account Holder Name',
                style: AppTextStyles.labelMedium(context),
              ),
              ResponsiveSizedBox(height: AppSpacing.s),
              TextFormField(
                controller: _accountHolderNameController,
                decoration: InputDecoration(
                  hintText: 'Enter the account holder name',
                  hintStyle: AppTextStyles.bodyMedium(context).copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                  filled: true,
                  fillColor:
                      AppColors.getSurface(context).withValues(alpha: 0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      ResponsiveValues.radiusMedium(context),
                    ),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: Icon(Icons.person_outline_rounded,
                      color: AppColors.getTextSecondary(context),
                      size: ResponsiveValues.iconSizeS(context)),
                  contentPadding: ResponsiveValues.listItemPadding(context),
                ),
                style: AppTextStyles.bodyMedium(context),
                validator: _validateAccountHolderName,
                enabled: !_isOffline,
              ),
              ResponsiveSizedBox(height: AppSpacing.l),
              ResponsiveText(
                'Password',
                style: AppTextStyles.labelMedium(context),
              ),
              ResponsiveSizedBox(height: AppSpacing.s),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  hintText: 'Enter your password',
                  hintStyle: AppTextStyles.bodyMedium(context).copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                  filled: true,
                  fillColor:
                      AppColors.getSurface(context).withValues(alpha: 0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      ResponsiveValues.radiusMedium(context),
                    ),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: Icon(Icons.lock_rounded,
                      color: AppColors.getTextSecondary(context),
                      size: ResponsiveValues.iconSizeS(context)),
                  contentPadding: ResponsiveValues.listItemPadding(context),
                ),
                obscureText: true,
                style: AppTextStyles.bodyMedium(context),
                validator: _validatePassword,
                enabled: !_isOffline,
              ),
              ResponsiveSizedBox(height: AppSpacing.l),
              ResponsiveText(
                'Payment Proof',
                style: AppTextStyles.labelMedium(context),
              ),
              ResponsiveSizedBox(height: AppSpacing.s),
              _buildProofUploadSection(),
              ResponsiveSizedBox(height: AppSpacing.l),
              ResponsiveRow(
                children: [
                  SizedBox(
                    width: ResponsiveValues.iconSizeM(context),
                    height: ResponsiveValues.iconSizeM(context),
                    child: Checkbox(
                      value: _confirmAccuracy,
                      onChanged: _isOffline
                          ? null
                          : (value) =>
                              setState(() => _confirmAccuracy = value ?? false),
                      activeColor: AppColors.telegramBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          ResponsiveValues.radiusSmall(context),
                        ),
                      ),
                    ),
                  ),
                  ResponsiveSizedBox(width: AppSpacing.m),
                  Expanded(
                    child: ResponsiveText(
                      'I confirm that all payment information is accurate and valid',
                      style: AppTextStyles.bodyMedium(context).copyWith(
                        color: _isOffline
                            ? AppColors.getTextSecondary(context)
                                .withValues(alpha: 0.5)
                            : AppColors.getTextPrimary(context),
                      ),
                    ),
                  ),
                ],
              ),
              if (_isOffline)
                Padding(
                  padding: EdgeInsets.only(
                    top: ResponsiveValues.spacingL(context),
                    bottom: ResponsiveValues.spacingL(context),
                  ),
                  child: Container(
                    padding: ResponsiveValues.cardPadding(context),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.telegramYellow.withValues(alpha: 0.2),
                          AppColors.telegramYellow.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusMedium(context),
                      ),
                    ),
                    child: ResponsiveRow(
                      children: [
                        const Icon(Icons.wifi_off_rounded,
                            color: AppColors.telegramYellow, size: 20),
                        ResponsiveSizedBox(width: AppSpacing.m),
                        Expanded(
                          child: ResponsiveText(
                            'You are offline. Please connect to submit payment.',
                            style: AppTextStyles.bodySmall(context).copyWith(
                              color: AppColors.telegramYellow,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ResponsiveSizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: _buildGradientButton(
                  label: _isOffline ? 'Offline' : 'Submit Payment',
                  onPressed: _isLoading || _isOffline ? null : _submitPayment,
                  gradient: AppColors.blueGradient,
                  icon:
                      _isOffline ? Icons.wifi_off_rounded : Icons.send_rounded,
                  isLoading: _isLoading,
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: AppThemes.animationDurationMedium, delay: 200.ms)
        .slideY(
            begin: 0.1, end: 0, duration: AppThemes.animationDurationMedium);
  }

  Widget _buildProofUploadSection() {
    return GestureDetector(
      onTap: _isOffline ? null : _pickImage,
      child: AnimatedContainer(
        duration: AppThemes.animationDurationFast,
        height: 200,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.getSurface(context).withValues(alpha: 0.3),
              AppColors.getSurface(context).withValues(alpha: 0.1),
            ],
          ),
          borderRadius:
              BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
          border: Border.all(
            color: _proofImageFile == null
                ? (_isOffline
                    ? AppColors.telegramGray.withValues(alpha: 0.2)
                    : AppColors.getTextSecondary(context)
                        .withValues(alpha: 0.2))
                : AppColors.telegramBlue,
            width: _proofImageFile == null ? 1.0 : 2.0,
          ),
        ),
        child: _proofImageFile != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(
                    ResponsiveValues.radiusMedium(context)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(
                      _proofImageFile!,
                      fit: BoxFit.contain,
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.5),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: ResponsiveValues.spacingM(context),
                      right: ResponsiveValues.spacingM(context),
                      child: GestureDetector(
                        onTap: () => setState(() => _proofImageFile = null),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: ResponsiveValues.spacingM(context),
                            vertical: ResponsiveValues.spacingXS(context),
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.telegramRed,
                                AppColors.telegramRed.withValues(alpha: 0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(
                              ResponsiveValues.radiusFull(context),
                            ),
                          ),
                          child: ResponsiveRow(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.delete_rounded,
                                  size: 16, color: Colors.white),
                              ResponsiveSizedBox(width: AppSpacing.xs),
                              ResponsiveText(
                                'Remove',
                                style: AppTextStyles.caption(context).copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: ResponsiveValues.spacingM(context),
                      left: ResponsiveValues.spacingM(context),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveValues.spacingM(context),
                          vertical: ResponsiveValues.spacingXS(context),
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.telegramGreen,
                              AppColors.telegramGreen.withValues(alpha: 0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(
                            ResponsiveValues.radiusFull(context),
                          ),
                        ),
                        child: ResponsiveRow(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                size: 14, color: Colors.white),
                            ResponsiveSizedBox(width: AppSpacing.xs),
                            ResponsiveText(
                              'Uploaded',
                              style: AppTextStyles.caption(context).copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : ResponsiveColumn(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ResponsiveIcon(
                    _isOffline
                        ? Icons.wifi_off_rounded
                        : Icons.cloud_upload_rounded,
                    size: ResponsiveValues.iconSizeXXL(context),
                    color: _isOffline
                        ? AppColors.telegramGray
                        : AppColors.getTextSecondary(context),
                  ),
                  ResponsiveSizedBox(height: AppSpacing.m),
                  ResponsiveText(
                    _isOffline
                        ? 'Offline - cannot upload'
                        : 'Tap to upload payment proof',
                    style: AppTextStyles.bodyMedium(context).copyWith(
                      color: _isOffline
                          ? AppColors.telegramGray
                          : AppColors.getTextPrimary(context),
                    ),
                  ),
                  ResponsiveSizedBox(height: AppSpacing.xs),
                  ResponsiveText(
                    _isOffline ? 'Connect to internet' : 'JPG or PNG • Max 5MB',
                    style: AppTextStyles.caption(context).copyWith(
                      color: _isOffline
                          ? AppColors.telegramGray
                          : AppColors.getTextSecondary(context),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildPaymentInstructions() {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final instructions = settingsProvider.getPaymentInstructions();

    return _buildGlassContainer(
      child: Padding(
        padding: ResponsiveValues.cardPadding(context),
        child: ResponsiveColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ResponsiveRow(
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
                    borderRadius: BorderRadius.circular(
                      ResponsiveValues.radiusMedium(context),
                    ),
                  ),
                  child: const Icon(Icons.info_rounded,
                      color: AppColors.telegramBlue, size: 20),
                ),
                ResponsiveSizedBox(width: AppSpacing.m),
                ResponsiveText(
                  'Instructions',
                  style: AppTextStyles.titleSmall(context),
                ),
              ],
            ),
            ResponsiveSizedBox(height: AppSpacing.l),
            Divider(
              color: AppColors.getDivider(context).withValues(alpha: 0.2),
              height: 1,
            ),
            ResponsiveSizedBox(height: AppSpacing.l),
            ResponsiveText(
              instructions,
              style: AppTextStyles.bodyMedium(context).copyWith(
                color: AppColors.getTextSecondary(context),
                height: 1.6,
              ),
            ),
            ResponsiveSizedBox(height: AppSpacing.l),
            Divider(
              color: AppColors.getDivider(context).withValues(alpha: 0.2),
              height: 1,
            ),
            ResponsiveSizedBox(height: AppSpacing.l),
            ResponsiveText(
              'Important Notes:',
              style: AppTextStyles.labelMedium(context).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            ResponsiveSizedBox(height: AppSpacing.s),
            _buildNoteItem(
              'Make sure the account holder name matches the bank/mobile account',
            ),
            _buildNoteItem('Payments are processed within 24 hours'),
            _buildNoteItem('Keep your payment proof screenshot'),
            _buildNoteItem('Contact support if payment is not verified'),
            _buildNoteItem('You will be notified when payment is verified'),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: AppThemes.animationDurationMedium, delay: 300.ms)
        .slideY(
            begin: 0.1, end: 0, duration: AppThemes.animationDurationMedium);
  }

  Widget _buildNoteItem(String text) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: ResponsiveValues.spacingS(context),
      ),
      child: ResponsiveRow(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.circle_rounded,
              size: 6, color: AppColors.telegramBlue),
          ResponsiveSizedBox(width: AppSpacing.s),
          Expanded(
            child: ResponsiveText(
              text,
              style: AppTextStyles.bodySmall(context).copyWith(
                color: AppColors.getTextSecondary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: _buildAppBar(context),
      body: Center(
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
              ),
              ResponsiveSizedBox(height: AppSpacing.xxl),
              ResponsiveText(
                'Payment Error',
                style: AppTextStyles.headlineMedium(context).copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              ResponsiveSizedBox(height: AppSpacing.l),
              ResponsiveText(
                _errorMessage,
                style: AppTextStyles.bodyLarge(context).copyWith(
                  color: AppColors.getTextSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),
              ResponsiveSizedBox(height: AppSpacing.xxl),
              SizedBox(
                width: ResponsiveValues.spacingXXXL(context) * 5,
                child: _buildGradientButton(
                  label: 'Go Back',
                  onPressed: () => GoRouter.of(context).pop(),
                  gradient: AppColors.blueGradient,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoMethodsState() {
    return Center(
      child: Padding(
        padding: ResponsiveValues.dialogPadding(context),
        child: ResponsiveColumn(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: ResponsiveValues.dialogPadding(context),
              decoration: BoxDecoration(
                color: AppColors.telegramYellow.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.payment_outlined,
                  size: 64, color: AppColors.telegramYellow),
            ),
            ResponsiveSizedBox(height: AppSpacing.xxl),
            ResponsiveText(
              'No Payment Methods',
              style: AppTextStyles.headlineSmall(context).copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            ResponsiveSizedBox(height: AppSpacing.l),
            ResponsiveText(
              'Payment methods are not available.\nPlease try again or contact support.',
              style: AppTextStyles.bodyLarge(context).copyWith(
                color: AppColors.getTextSecondary(context),
              ),
              textAlign: TextAlign.center,
            ),
            ResponsiveSizedBox(height: AppSpacing.xxl),
            ResponsiveRow(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildGradientButton(
                  label: 'Retry',
                  onPressed: () {
                    setState(() {
                      _settingsLoadAttempted = false;
                      _isLoadingMethods = true;
                    });
                    _loadPaymentMethods();
                  },
                  gradient: AppColors.blueGradient,
                ),
                ResponsiveSizedBox(width: AppSpacing.l),
                OutlinedButton(
                  onPressed: () => GoRouter.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.getTextPrimary(context),
                    side: BorderSide(
                      color: AppColors.getTextSecondary(context),
                    ),
                    padding: ResponsiveValues.buttonPadding(context),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusMedium(context),
                      ),
                    ),
                  ),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineNoMethodsState() {
    return Center(
      child: Padding(
        padding: ResponsiveValues.dialogPadding(context),
        child: ResponsiveColumn(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: ResponsiveValues.dialogPadding(context),
              decoration: BoxDecoration(
                color: AppColors.telegramYellow.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded,
                  size: 64, color: AppColors.telegramYellow),
            ),
            ResponsiveSizedBox(height: AppSpacing.xxl),
            ResponsiveText(
              'No Payment Methods Available',
              style: AppTextStyles.headlineSmall(context).copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            ResponsiveSizedBox(height: AppSpacing.l),
            ResponsiveText(
              'You are offline and no cached payment methods are available.\nPlease connect to the internet and try again.',
              style: AppTextStyles.bodyLarge(context).copyWith(
                color: AppColors.getTextSecondary(context),
              ),
              textAlign: TextAlign.center,
            ),
            ResponsiveSizedBox(height: AppSpacing.xxl),
            OutlinedButton(
              onPressed: () => GoRouter.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.getTextPrimary(context),
                side: BorderSide(
                  color: AppColors.getTextSecondary(context),
                ),
                padding: ResponsiveValues.buttonPadding(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    ResponsiveValues.radiusMedium(context),
                  ),
                ),
              ),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, List<PaymentMethod> methods) {
    if (_hasError) return _buildErrorState();
    if (_isLoadingMethods) return _buildSkeletonLoader();
    if (methods.isEmpty && _isOffline) return _buildOfflineNoMethodsState();
    if (methods.isEmpty) return _buildNoMethodsState();

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: _buildAppBar(context),
      body: SingleChildScrollView(
        child: Padding(
          padding: ResponsiveValues.screenPadding(context),
          child: ResponsiveColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPaymentSummary(),
              ResponsiveSizedBox(height: AppSpacing.xl),
              _buildPaymentForm(methods),
              ResponsiveSizedBox(height: AppSpacing.xl),
              _buildPaymentInstructions(),
              ResponsiveSizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(
      BuildContext context, List<PaymentMethod> methods) {
    if (_hasError) return _buildErrorState();
    if (_isLoadingMethods) return Center(child: _buildSkeletonLoader());
    if (methods.isEmpty && _isOffline)
      return Center(child: _buildOfflineNoMethodsState());
    if (methods.isEmpty) return Center(child: _buildNoMethodsState());

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: _buildAppBar(context),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: SingleChildScrollView(
            child: Padding(
              padding: ResponsiveValues.dialogPadding(context),
              child: ResponsiveColumn(
                children: [
                  _buildPaymentSummary(),
                  ResponsiveSizedBox(height: AppSpacing.xxxl),
                  ResponsiveRow(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildPaymentForm(methods),
                      ),
                      ResponsiveSizedBox(width: AppSpacing.xxxl),
                      Expanded(
                        child: _buildPaymentInstructions(),
                      ),
                    ],
                  ),
                  ResponsiveSizedBox(height: AppSpacing.xxxl),
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
    final methods = _cachedMethods;

    if (_isLoadingMethods) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: _buildAppBar(context),
        body: _buildSkeletonLoader(),
      );
    }

    if (_hasError) return _buildErrorState();

    if (_category == null) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: _buildAppBar(context),
        body: Center(
          child: ResponsiveColumn(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: ResponsiveValues.iconSizeXL(context),
                height: ResponsiveValues.iconSizeXL(context),
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.telegramBlue),
                ),
              ),
              ResponsiveSizedBox(height: AppSpacing.l),
              ResponsiveText(
                'Loading payment details...',
                style: AppTextStyles.bodyMedium(context).copyWith(
                  color: AppColors.getTextSecondary(context),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ResponsiveLayout(
      mobile: _buildMobileLayout(context, methods),
      tablet: _buildDesktopLayout(context, methods),
      desktop: _buildDesktopLayout(context, methods),
    ).animate().fadeIn(duration: AppThemes.animationDurationMedium);
  }
}

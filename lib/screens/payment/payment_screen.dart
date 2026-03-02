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
  final bool _showMethodDetails = false;
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
        // Try to load from cache if offline
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

    // Cache payment methods for offline use
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

  Widget _buildGlassContainer({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
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
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.telegramBlue.withValues(alpha: 0.2),
            ),
          ),
          child: child,
        ),
      ),
    );
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Payment Method',
            style: AppTextStyles.labelMedium
                .copyWith(color: AppColors.getTextPrimary(context))),
        const SizedBox(height: 8),
        _buildGlassContainer(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButtonFormField<PaymentMethod>(
              value: _selectedPaymentMethod,
              hint: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('Select a payment method',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.getTextSecondary(context))),
              ),
              isExpanded: true,
              decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
              icon: Icon(Icons.arrow_drop_down_rounded,
                  color: AppColors.getTextSecondary(context)),
              items: uniqueMethods.map((method) {
                return DropdownMenuItem<PaymentMethod>(
                  value: method,
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.telegramBlue.withValues(alpha: 0.2),
                              AppColors.telegramPurple.withValues(alpha: 0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(
                              AppThemes.borderRadiusSmall),
                        ),
                        child: Icon(method.iconData,
                            size: 16, color: AppColors.telegramBlue),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: RichText(
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            style: DefaultTextStyle.of(context).style,
                            children: [
                              TextSpan(
                                  text: '${method.name}\n',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                      color:
                                          AppColors.getTextPrimary(context))),
                              TextSpan(
                                  text: method.accountInfo.split('\n').first,
                                  style: AppTextStyles.caption.copyWith(
                                      color:
                                          AppColors.getTextSecondary(context))),
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
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Payment methods require internet connection',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.telegramYellow,
              ),
            ),
          ),
        if (_selectedPaymentMethod != null) ...[
          const SizedBox(height: 16),
          _buildGlassContainer(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_rounded,
                          size: 16, color: AppColors.telegramBlue),
                      const SizedBox(width: 8),
                      Text('Account Details',
                          style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.getTextPrimary(context),
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.getCard(context).withValues(alpha: 0.3),
                          AppColors.getCard(context).withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius:
                          BorderRadius.circular(AppThemes.borderRadiusSmall),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                            child: Text(_selectedPaymentMethod!.accountInfo,
                                style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.getTextPrimary(context)))),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(
                                text: _selectedPaymentMethod!.accountInfo));
                            showTopSnackBar(context, 'Copied to clipboard');
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.telegramBlue
                                        .withValues(alpha: 0.2),
                                    AppColors.telegramBlue
                                        .withValues(alpha: 0.1),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(
                                    AppThemes.borderRadiusSmall)),
                            child: const Icon(Icons.copy_rounded,
                                size: 16, color: AppColors.telegramBlue),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Instructions',
                      style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.getTextSecondary(context))),
                  const SizedBox(height: 4),
                  Text(_selectedPaymentMethod!.instructions,
                      style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.getTextPrimary(context),
                          height: 1.5)),
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
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Payment Summary Skeleton
              _buildGlassContainer(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: List.generate(
                        5,
                        (index) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Shimmer.fromColors(
                                    baseColor: Colors.grey[300]!
                                        .withValues(alpha: 0.3),
                                    highlightColor: Colors.grey[100]!
                                        .withValues(alpha: 0.6),
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Shimmer.fromColors(
                                          baseColor: Colors.grey[300]!
                                              .withValues(alpha: 0.3),
                                          highlightColor: Colors.grey[100]!
                                              .withValues(alpha: 0.6),
                                          child: Container(
                                            height: 16,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Payment Form Skeleton
              _buildGlassContainer(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: List.generate(
                        4,
                        (index) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Shimmer.fromColors(
                                baseColor:
                                    Colors.grey[300]!.withValues(alpha: 0.3),
                                highlightColor:
                                    Colors.grey[100]!.withValues(alpha: 0.6),
                                child: Container(
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            )),
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

  Widget _buildMobileLayout(BuildContext context, List<PaymentMethod> methods) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: _buildAppBar(context),
      body: _hasError
          ? _buildErrorState()
          : _isLoadingMethods
              ? _buildSkeletonLoader()
              : methods.isEmpty && _isOffline
                  ? _buildOfflineNoMethodsState()
                  : methods.isEmpty
                      ? _buildNoMethodsState()
                      : SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildPaymentSummary(),
                                const SizedBox(height: 24),
                                _buildPaymentForm(methods),
                                const SizedBox(height: 24),
                                _buildPaymentInstructions(),
                                const SizedBox(height: 32),
                              ],
                            ),
                          ),
                        ),
    );
  }

  Widget _buildDesktopLayout(
      BuildContext context, List<PaymentMethod> methods) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: _buildAppBar(context),
      body: _hasError
          ? Center(child: _buildErrorState())
          : _isLoadingMethods
              ? Center(child: _buildSkeletonLoader())
              : methods.isEmpty && _isOffline
                  ? Center(child: _buildOfflineNoMethodsState())
                  : methods.isEmpty
                      ? Center(child: _buildNoMethodsState())
                      : SingleChildScrollView(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1200),
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  children: [
                                    _buildPaymentSummary(),
                                    const SizedBox(height: 48),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                            flex: 2,
                                            child: _buildPaymentForm(methods)),
                                        const SizedBox(width: 48),
                                        Expanded(
                                            child: _buildPaymentInstructions()),
                                      ],
                                    ),
                                    const SizedBox(height: 48),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.telegramBlue))),
            const SizedBox(height: 16),
            Text('Loading payment methods...',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.getTextSecondary(context))),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                setState(() {
                  _settingsLoadAttempted = false;
                  _isLoadingMethods = true;
                });
                _loadPaymentMethods();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoMethodsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                  color: AppColors.telegramYellow.withValues(alpha: 0.1),
                  shape: BoxShape.circle),
              child: const Icon(Icons.payment_outlined,
                  size: 64, color: AppColors.telegramYellow),
            ),
            const SizedBox(height: 32),
            Text('No Payment Methods',
                style: AppTextStyles.headlineSmall.copyWith(
                    color: AppColors.getTextPrimary(context),
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Text(
                'Payment methods are not available.\nPlease try again or contact support.',
                style: AppTextStyles.bodyLarge
                    .copyWith(color: AppColors.getTextSecondary(context)),
                textAlign: TextAlign.center),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _settingsLoadAttempted = false;
                      _isLoadingMethods = true;
                    });
                    _loadPaymentMethods();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.telegramBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                            AppThemes.borderRadiusMedium)),
                  ),
                  child: Text('Retry',
                      style: AppTextStyles.buttonMedium
                          .copyWith(color: Colors.white)),
                ),
                const SizedBox(width: 16),
                OutlinedButton(
                  onPressed: () => GoRouter.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.getTextPrimary(context),
                    side:
                        BorderSide(color: AppColors.getTextSecondary(context)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                            AppThemes.borderRadiusMedium)),
                  ),
                  child:
                      const Text('Go Back', style: AppTextStyles.buttonMedium),
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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                  color: AppColors.telegramYellow.withValues(alpha: 0.1),
                  shape: BoxShape.circle),
              child: const Icon(Icons.wifi_off_rounded,
                  size: 64, color: AppColors.telegramYellow),
            ),
            const SizedBox(height: 32),
            Text('No Payment Methods Available',
                style: AppTextStyles.headlineSmall.copyWith(
                    color: AppColors.getTextPrimary(context),
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Text(
                'You are offline and no cached payment methods are available.\nPlease connect to the internet and try again.',
                style: AppTextStyles.bodyLarge
                    .copyWith(color: AppColors.getTextSecondary(context)),
                textAlign: TextAlign.center),
            const SizedBox(height: 32),
            OutlinedButton(
              onPressed: () => GoRouter.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.getTextPrimary(context),
                side: BorderSide(color: AppColors.getTextSecondary(context)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppThemes.borderRadiusMedium)),
              ),
              child: const Text('Go Back', style: AppTextStyles.buttonMedium),
            ),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              color: AppColors.getTextPrimary(context)),
          onPressed: () => GoRouter.of(context).pop()),
      title: Text('Payment',
          style: AppTextStyles.appBarTitle
              .copyWith(color: AppColors.getTextPrimary(context))),
      centerTitle: false,
    );
  }

  Widget _buildPaymentSummary() {
    return _buildGlassContainer(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.telegramBlue.withValues(alpha: 0.2),
                        AppColors.telegramPurple.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius:
                        BorderRadius.circular(AppThemes.borderRadiusMedium),
                  ),
                  child: const Icon(Icons.payment_rounded,
                      color: AppColors.telegramBlue, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_category?.name ?? 'Payment',
                          style: AppTextStyles.titleMedium.copyWith(
                              color: AppColors.getTextPrimary(context))),
                      const SizedBox(height: 4),
                      Text(_getPaymentTypeText(),
                          style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.getTextSecondary(context))),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_amount.toStringAsFixed(0),
                        style: AppTextStyles.displaySmall.copyWith(
                            color: AppColors.telegramBlue,
                            fontWeight: FontWeight.w700)),
                    Text('ETB',
                        style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.getTextSecondary(context))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                height: 1),
            const SizedBox(height: 16),
            _buildSummaryRow(
                icon: Icons.category_rounded,
                label: 'Category',
                value: _category?.name ?? 'N/A'),
            const SizedBox(height: 8),
            _buildSummaryRow(
                icon: Icons.calendar_today_rounded,
                label: 'Billing Cycle',
                value: _getBillingCycleDescription()),
            const SizedBox(height: 8),
            _buildSummaryRow(
                icon: Icons.timer_rounded,
                label: 'Access Duration',
                value: _getAccessDurationText()),
            const SizedBox(height: 8),
            _buildSummaryRow(
                icon: Icons.person_rounded,
                label: 'Username',
                value: _username),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: AppThemes.animationDurationMedium, delay: 100.ms)
        .slideY(
            begin: 0.1, end: 0, duration: AppThemes.animationDurationMedium);
  }

  Widget _buildSummaryRow(
      {required IconData icon, required String label, required String value}) {
    return Row(
      children: [
        Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.telegramBlue.withValues(alpha: 0.2),
                    AppColors.telegramPurple.withValues(alpha: 0.1),
                  ],
                ),
                shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: AppColors.telegramBlue)),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.getTextSecondary(context))),
              Text(value,
                  style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.getTextPrimary(context),
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentForm(List<PaymentMethod> methods) {
    return _buildGlassContainer(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Payment Details',
                  style: AppTextStyles.titleMedium
                      .copyWith(color: AppColors.getTextPrimary(context))),
              const SizedBox(height: 16),
              _buildPaymentMethodDropdown(methods),
              const SizedBox(height: 16),
              Text('Account Holder Name',
                  style: AppTextStyles.labelMedium
                      .copyWith(color: AppColors.getTextPrimary(context))),
              const SizedBox(height: 8),
              TextFormField(
                controller: _accountHolderNameController,
                decoration: InputDecoration(
                  hintText: 'Enter the account holder name',
                  hintStyle: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.getTextSecondary(context)),
                  filled: true,
                  fillColor:
                      AppColors.getSurface(context).withValues(alpha: 0.3),
                  border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppThemes.borderRadiusMedium),
                      borderSide: BorderSide.none),
                  prefixIcon: Icon(Icons.person_outline_rounded,
                      color: AppColors.getTextSecondary(context), size: 20),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.getTextPrimary(context)),
                validator: _validateAccountHolderName,
                enabled: !_isOffline,
              ),
              const SizedBox(height: 16),
              Text('Password',
                  style: AppTextStyles.labelMedium
                      .copyWith(color: AppColors.getTextPrimary(context))),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  hintText: 'Enter your password',
                  hintStyle: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.getTextSecondary(context)),
                  filled: true,
                  fillColor:
                      AppColors.getSurface(context).withValues(alpha: 0.3),
                  border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppThemes.borderRadiusMedium),
                      borderSide: BorderSide.none),
                  prefixIcon: Icon(Icons.lock_rounded,
                      color: AppColors.getTextSecondary(context), size: 20),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                obscureText: true,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.getTextPrimary(context)),
                validator: _validatePassword,
                enabled: !_isOffline,
              ),
              const SizedBox(height: 16),
              Text('Payment Proof',
                  style: AppTextStyles.labelMedium
                      .copyWith(color: AppColors.getTextPrimary(context))),
              const SizedBox(height: 8),
              _buildProofUploadSection(),
              const SizedBox(height: 16),
              Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: _confirmAccuracy,
                      onChanged: _isOffline
                          ? null
                          : (value) =>
                              setState(() => _confirmAccuracy = value ?? false),
                      activeColor: AppColors.telegramBlue,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              AppThemes.borderRadiusSmall)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                        'I confirm that all payment information is accurate and valid',
                        style: AppTextStyles.bodyMedium.copyWith(
                            color: _isOffline
                                ? AppColors.getTextSecondary(context)
                                    .withValues(alpha: 0.5)
                                : AppColors.getTextPrimary(context))),
                  ),
                ],
              ),
              if (_isOffline)
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.telegramYellow.withValues(alpha: 0.2),
                          AppColors.telegramYellow.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.wifi_off_rounded,
                            color: AppColors.telegramYellow, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'You are offline. Please connect to submit payment.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.telegramYellow,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading || _isOffline ? null : _submitPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isOffline
                        ? AppColors.telegramGray.withValues(alpha: 0.3)
                        : AppColors.telegramBlue,
                    foregroundColor: _isOffline
                        ? AppColors.getTextSecondary(context)
                        : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                            AppThemes.borderRadiusMedium)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white)))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.send_rounded,
                                size: 20,
                                color: _isOffline
                                    ? AppColors.getTextSecondary(context)
                                    : Colors.white),
                            const SizedBox(width: 8),
                            Text(_isOffline ? 'Offline' : 'Submit Payment',
                                style: AppTextStyles.buttonMedium.copyWith(
                                    color: _isOffline
                                        ? AppColors.getTextSecondary(context)
                                        : Colors.white)),
                          ],
                        ),
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
        height: 150,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.getSurface(context).withValues(alpha: 0.3),
              AppColors.getSurface(context).withValues(alpha: 0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
          border: Border.all(
              color: _proofImageFile == null
                  ? (_isOffline
                      ? AppColors.telegramGray.withValues(alpha: 0.2)
                      : AppColors.getTextSecondary(context)
                          .withValues(alpha: 0.2))
                  : AppColors.telegramBlue,
              width: _proofImageFile == null ? 1.0 : 2.0),
        ),
        child: _proofImageFile != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                      borderRadius:
                          BorderRadius.circular(AppThemes.borderRadiusMedium),
                      child: Image.file(_proofImageFile!, fit: BoxFit.cover)),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7)
                          ])),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: () => setState(() => _proofImageFile = null),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.telegramRed,
                                AppColors.telegramRed.withValues(alpha: 0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(
                                AppThemes.borderRadiusFull)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.delete_rounded,
                                size: 16, color: Colors.white),
                            const SizedBox(width: 4),
                            Text('Remove',
                                style: AppTextStyles.caption.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.telegramGreen,
                              AppColors.telegramGreen.withValues(alpha: 0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(
                              AppThemes.borderRadiusFull)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          Text('Uploaded',
                              style: AppTextStyles.caption.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isOffline
                        ? Icons.wifi_off_rounded
                        : Icons.cloud_upload_rounded,
                    size: 40,
                    color: _isOffline
                        ? AppColors.telegramGray
                        : AppColors.getTextSecondary(context),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isOffline
                        ? 'Offline - cannot upload'
                        : 'Tap to upload payment proof',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: _isOffline
                          ? AppColors.telegramGray
                          : AppColors.getTextPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isOffline ? 'Connect to internet' : 'JPG or PNG • Max 5MB',
                    style: AppTextStyles.caption.copyWith(
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.telegramBlue.withValues(alpha: 0.2),
                        AppColors.telegramPurple.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius:
                        BorderRadius.circular(AppThemes.borderRadiusMedium),
                  ),
                  child: const Icon(Icons.info_rounded,
                      color: AppColors.telegramBlue, size: 20),
                ),
                const SizedBox(width: 12),
                Text('Instructions',
                    style: AppTextStyles.titleSmall
                        .copyWith(color: AppColors.getTextPrimary(context))),
              ],
            ),
            const SizedBox(height: 16),
            Divider(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                height: 1),
            const SizedBox(height: 16),
            Text(instructions,
                style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.getTextSecondary(context), height: 1.6)),
            const SizedBox(height: 16),
            Divider(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                height: 1),
            const SizedBox(height: 16),
            Text('Important Notes:',
                style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.getTextPrimary(context),
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _buildNoteItem(
                'Make sure the account holder name matches the bank/mobile account'),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.circle_rounded,
              size: 6, color: AppColors.telegramBlue),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.getTextSecondary(context)))),
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
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                    color: AppColors.telegramRed.withValues(alpha: 0.1),
                    shape: BoxShape.circle),
                child: const Icon(Icons.error_outline_rounded,
                    size: 64, color: AppColors.telegramRed),
              ),
              const SizedBox(height: 32),
              Text('Payment Error',
                  style: AppTextStyles.headlineMedium.copyWith(
                      color: AppColors.getTextPrimary(context),
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Text(_errorMessage,
                  style: AppTextStyles.bodyLarge
                      .copyWith(color: AppColors.getTextSecondary(context)),
                  textAlign: TextAlign.center),
              const SizedBox(height: 32),
              SizedBox(
                width: 200,
                child: ElevatedButton(
                  onPressed: () => GoRouter.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.telegramBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                            AppThemes.borderRadiusMedium)),
                  ),
                  child: Text('Go Back',
                      style: AppTextStyles.buttonMedium
                          .copyWith(color: Colors.white)),
                ),
              ),
            ],
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
          body: _buildSkeletonLoader());
    }

    if (_hasError) return _buildErrorState();

    if (_category == null) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: _buildAppBar(context),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.telegramBlue))),
              const SizedBox(height: 16),
              Text('Loading payment details...',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.getTextSecondary(context))),
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

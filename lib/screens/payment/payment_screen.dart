import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import 'package:familyacademyclient/themes/app_themes.dart';
import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';
import 'package:familyacademyclient/widgets/common/loading_indicator.dart';
import 'package:familyacademyclient/widgets/common/error_widget.dart';
import 'package:familyacademyclient/widgets/common/empty_state.dart';
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
  bool _showMethodDetails = false;
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

  // Track initialization
  bool _initialized = false;
  bool _settingsLoadAttempted = false;
  List<PaymentMethod> _cachedMethods = [];

  // Offline support
  bool _isOffline = false;
  List<Map<String, dynamic>> _offlinePayments = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: AppThemes.animationDurationMedium,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
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

  void _initializeData() {
    if (_initialized) return;

    try {
      final args = widget.extra;
      if (args == null) {
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
      dynamic categoryData = args['category'];

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

      debugLog('PaymentScreen',
          'Category: ${category.name}, Amount: $_amount, Type: $_paymentType');

      // Load settings to get payment methods
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

    // Ensure settings are loaded
    if (settingsProvider.allSettings.isEmpty) {
      debugLog('PaymentScreen', '📥 Loading settings from API...');
      await settingsProvider.getAllSettings();
    }

    // Get payment methods and cache them
    _cachedMethods = settingsProvider.getPaymentMethods();

    debugLog(
        'PaymentScreen', '✅ Loaded ${_cachedMethods.length} payment methods');

    if (mounted) {
      setState(() {
        _isLoadingMethods = false;
      });
    }
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
          _showErrorSnackBar('Image must be less than 5MB');
          return;
        }

        setState(() => _proofImageFile = file);
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick image: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.telegramRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
          ),
          margin: EdgeInsets.all(AppThemes.spacingL),
        ),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.telegramGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
          ),
          margin: EdgeInsets.all(AppThemes.spacingL),
        ),
      );
    }
  }

  Widget _buildPaymentMethodDropdown(List<PaymentMethod> methods) {
    // Remove duplicates
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
        Text(
          'Payment Method',
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.getTextPrimary(context),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: _selectedPaymentMethod == null
                  ? Theme.of(context).dividerColor
                  : AppColors.telegramBlue,
            ),
            borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
          ),
          child: DropdownButtonFormField<PaymentMethod>(
            value: _selectedPaymentMethod,
            hint: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Select a payment method',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.getTextSecondary(context),
                ),
              ),
            ),
            isExpanded: true,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
            ),
            icon: Icon(
              Icons.arrow_drop_down_rounded,
              color: AppColors.getTextSecondary(context),
            ),
            items: uniqueMethods.map((method) {
              return DropdownMenuItem<PaymentMethod>(
                value: method,
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.telegramBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(
                          AppThemes.borderRadiusSmall,
                        ),
                      ),
                      child: Icon(
                        method.iconData,
                        size: 16,
                        color: AppColors.telegramBlue,
                      ),
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
                                color: AppColors.getTextPrimary(context),
                              ),
                            ),
                            TextSpan(
                              text: method.accountInfo.split('\n').first,
                              style: AppTextStyles.caption.copyWith(
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
            onChanged: (PaymentMethod? newValue) {
              setState(() {
                _selectedPaymentMethod = newValue;
              });
            },
          ),
        ),

        // Show method details when selected
        if (_selectedPaymentMethod != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.getSurface(context),
              borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
              border: Border.all(
                color: AppColors.telegramBlue.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_rounded,
                      size: 16,
                      color: AppColors.telegramBlue,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Account Details',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.getTextPrimary(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.getCard(context),
                    borderRadius: BorderRadius.circular(
                      AppThemes.borderRadiusSmall,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedPaymentMethod!.accountInfo,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.getTextPrimary(context),
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(
                              text: _selectedPaymentMethod!.accountInfo));
                          _showSuccessSnackBar('Copied to clipboard');
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.telegramBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(
                              AppThemes.borderRadiusSmall,
                            ),
                          ),
                          child: Icon(
                            Icons.copy_rounded,
                            size: 16,
                            color: AppColors.telegramBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Instructions',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedPaymentMethod!.instructions,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.getTextPrimary(context),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _submitPayment() async {
    // Validate all required fields first
    if (_category == null) {
      _showErrorSnackBar('Category information missing');
      return;
    }

    if (_amount <= 0) {
      _showErrorSnackBar('Invalid payment amount');
      return;
    }

    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check payment method selection
    if (_selectedPaymentMethod == null) {
      _showErrorSnackBar('Please select a payment method');
      return;
    }

    // Store in local variable to avoid null check issues
    final selectedPaymentMethod = _selectedPaymentMethod!;

    // Check proof image
    if (_proofImageFile == null) {
      _showErrorSnackBar('Please upload payment proof');
      return;
    }

    // Check confirmation
    if (!_confirmAccuracy) {
      _showErrorSnackBar('Please confirm accuracy');
      return;
    }

    setState(() => _isLoading = true);

    final paymentProvider =
        Provider.of<PaymentProvider>(context, listen: false);
    final subscriptionProvider =
        Provider.of<SubscriptionProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      debugLog('PaymentScreen', 'Submitting payment...');

      // Use the validated payment method
      final paymentMethod = selectedPaymentMethod.method;

      // Upload the image first to get a URL
      String? proofImageUrl;
      try {
        debugLog('PaymentScreen', 'Uploading payment proof image...');
        final apiService = paymentProvider.apiService;
        final uploadResponse =
            await apiService.uploadPaymentProof(_proofImageFile!);

        if (uploadResponse.success && uploadResponse.data != null) {
          proofImageUrl = uploadResponse.data!;
          debugLog(
              'PaymentScreen', '✅ Image uploaded successfully: $proofImageUrl');
        } else {
          _showErrorSnackBar('Failed to upload payment proof');
          setState(() => _isLoading = false);
          return;
        }
      } catch (uploadError) {
        debugLog('PaymentScreen', '❌ Image upload failed: $uploadError');
        _showErrorSnackBar('Failed to upload image: $uploadError');
        setState(() => _isLoading = false);
        return;
      }

      // Get account holder name from controller
      final accountHolderName = _accountHolderNameController.text.trim();

      // Now submit payment with the image URL and account holder name
      final result = await paymentProvider.submitPayment(
        categoryId: _category!.id,
        paymentType: _paymentType,
        paymentMethod: paymentMethod,
        amount: _amount,
        accountHolderName:
            accountHolderName.isNotEmpty ? accountHolderName : null,
        proofImagePath: proofImageUrl,
      );

      debugLog('PaymentScreen', 'Payment submission result: $result');

      if (result['success'] == true) {
        await subscriptionProvider.refreshAfterPaymentVerification();
        await authProvider.checkSession();

        if (mounted) {
          _showSuccessSnackBar('Payment submitted successfully!');

          // Pass ALL payment data to success screen
          context.push('/payment-success', extra: {
            'category': _category,
            'category_id': _category!.id,
            'category_name': _category!.name,
            'payment_type': _paymentType,
            'payment_method': paymentMethod,
            'payment_method_name': selectedPaymentMethod.name,
            'amount': _amount,
            'billing_cycle': _billingCycle,
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
              'data': result['data'],
            });
          }
        } else {
          if (mounted) {
            _showErrorSnackBar(message);
          }
        }
      }
    } catch (e, stackTrace) {
      debugLog('PaymentScreen', 'Payment error: $e\n$stackTrace');
      if (mounted) {
        _showErrorSnackBar('Payment failed: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
              ? _buildLoadingState()
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
              ? _buildLoadingState()
              : methods.isEmpty
                  ? _buildNoMethodsState()
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: _buildPaymentForm(methods),
                                    ),
                                    const SizedBox(width: 48),
                                    Expanded(
                                      flex: 1,
                                      child: _buildPaymentInstructions(),
                                    ),
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
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.telegramBlue,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading payment methods...',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.getTextSecondary(context),
              ),
            ),
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
                color: AppColors.telegramYellow.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.payment_outlined,
                size: 64,
                color: AppColors.telegramYellow,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'No Payment Methods',
              style: AppTextStyles.headlineSmall.copyWith(
                color: AppColors.getTextPrimary(context),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Payment methods are not available.\nPlease try again or contact support.',
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.getTextSecondary(context),
              ),
              textAlign: TextAlign.center,
            ),
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
                      horizontal: 24,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppThemes.borderRadiusMedium),
                    ),
                  ),
                  child: Text(
                    'Retry',
                    style: AppTextStyles.buttonMedium.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton(
                  onPressed: () => GoRouter.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.getTextPrimary(context),
                    side: BorderSide(
                      color: AppColors.getTextSecondary(context),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppThemes.borderRadiusMedium),
                    ),
                  ),
                  child: Text(
                    'Go Back',
                    style: AppTextStyles.buttonMedium,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.getBackground(context),
      elevation: 0,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_rounded,
          color: AppColors.getTextPrimary(context),
        ),
        onPressed: () => GoRouter.of(context).pop(),
      ),
      title: Text(
        'Payment',
        style: AppTextStyles.appBarTitle.copyWith(
          color: AppColors.getTextPrimary(context),
        ),
      ),
      centerTitle: false,
    );
  }

  Widget _buildPaymentSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getCard(context),
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.telegramBlue.withOpacity(0.1),
                  borderRadius:
                      BorderRadius.circular(AppThemes.borderRadiusMedium),
                ),
                child: Icon(
                  Icons.payment_rounded,
                  color: AppColors.telegramBlue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _category?.name ?? 'Payment',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.getTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getPaymentTypeText(),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${_amount.toStringAsFixed(0)}',
                    style: AppTextStyles.displaySmall.copyWith(
                      color: AppColors.telegramBlue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'ETB',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Theme.of(context).dividerColor, height: 1),
          const SizedBox(height: 16),
          _buildSummaryRow(
            icon: Icons.category_rounded,
            label: 'Category',
            value: _category?.name ?? 'N/A',
          ),
          const SizedBox(height: 8),
          _buildSummaryRow(
            icon: Icons.calendar_today_rounded,
            label: 'Billing Cycle',
            value: _billingCycle.toUpperCase(),
          ),
          const SizedBox(height: 8),
          _buildSummaryRow(
            icon: Icons.person_rounded,
            label: 'Username',
            value: _username,
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(
          duration: AppThemes.animationDurationMedium,
          delay: 100.ms,
        )
        .slideY(
          begin: 0.1,
          end: 0,
          duration: AppThemes.animationDurationMedium,
        );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required String label,
    required String value,
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
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.getTextSecondary(context),
                ),
              ),
              Text(
                value,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.getTextPrimary(context),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getCard(context),
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: 0.5,
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Details',
              style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: 16),

            // Payment Method Dropdown
            _buildPaymentMethodDropdown(methods),
            const SizedBox(height: 16),

            // Account Holder Name Field
            Text(
              'Account Holder Name',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _accountHolderNameController,
              decoration: InputDecoration(
                hintText: 'Enter the account holder name',
                hintStyle: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.getTextSecondary(context),
                ),
                filled: true,
                fillColor: AppColors.getSurface(context),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppThemes.borderRadiusMedium),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.getTextSecondary(context),
                  size: 20,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.getTextPrimary(context),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Account holder name is required';
                }
                if (value.trim().length < 3) {
                  return 'Account holder name must be at least 3 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Password
            Text(
              'Password',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                hintText: 'Enter your password',
                hintStyle: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.getTextSecondary(context),
                ),
                filled: true,
                fillColor: AppColors.getSurface(context),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppThemes.borderRadiusMedium),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(
                  Icons.lock_rounded,
                  color: AppColors.getTextSecondary(context),
                  size: 20,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              obscureText: true,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.getTextPrimary(context),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Password is required';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Payment Proof
            Text(
              'Payment Proof',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: 8),
            _buildProofUploadSection(),
            const SizedBox(height: 16),

            // Confirmation
            Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _confirmAccuracy,
                    onChanged: (value) =>
                        setState(() => _confirmAccuracy = value ?? false),
                    activeColor: AppColors.telegramBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppThemes.borderRadiusSmall),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'I confirm that all payment information is accurate and valid',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.getTextPrimary(context),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.telegramBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppThemes.borderRadiusMedium),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.send_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Submit Payment',
                            style: AppTextStyles.buttonMedium.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(
          duration: AppThemes.animationDurationMedium,
          delay: 200.ms,
        )
        .slideY(
          begin: 0.1,
          end: 0,
          duration: AppThemes.animationDurationMedium,
        );
  }

  Widget _buildProofUploadSection() {
    return GestureDetector(
      onTap: _pickImage,
      child: AnimatedContainer(
        duration: AppThemes.animationDurationFast,
        height: 150,
        decoration: BoxDecoration(
          color: AppColors.getSurface(context),
          borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
          border: Border.all(
            color: _proofImageFile == null
                ? Theme.of(context).dividerColor
                : AppColors.telegramBlue,
            width: _proofImageFile == null ? 1.0 : 2.0,
          ),
        ),
        child: _proofImageFile != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius:
                        BorderRadius.circular(AppThemes.borderRadiusMedium),
                    child: Image.file(
                      _proofImageFile!,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: () => setState(() => _proofImageFile = null),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.telegramRed,
                          borderRadius:
                              BorderRadius.circular(AppThemes.borderRadiusFull),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.delete_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Remove',
                              style: AppTextStyles.caption.copyWith(
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
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.telegramGreen,
                        borderRadius:
                            BorderRadius.circular(AppThemes.borderRadiusFull),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Uploaded',
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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
                    Icons.cloud_upload_rounded,
                    size: 40,
                    color: AppColors.getTextSecondary(context),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tap to upload payment proof',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.getTextPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'JPG or PNG • Max 5MB',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.getTextSecondary(context),
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getCard(context),
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.telegramBlue.withOpacity(0.1),
                  borderRadius:
                      BorderRadius.circular(AppThemes.borderRadiusMedium),
                ),
                child: Icon(
                  Icons.info_rounded,
                  color: AppColors.telegramBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Instructions',
                style: AppTextStyles.titleSmall.copyWith(
                  color: AppColors.getTextPrimary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Theme.of(context).dividerColor, height: 1),
          const SizedBox(height: 16),
          Text(
            instructions,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.getTextSecondary(context),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: Theme.of(context).dividerColor, height: 1),
          const SizedBox(height: 16),
          Text(
            'Important Notes:',
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.getTextPrimary(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _buildNoteItem(
              'Make sure the account holder name matches the bank/mobile account'),
          _buildNoteItem('Payments are processed within 24 hours'),
          _buildNoteItem('Keep your payment proof screenshot'),
          _buildNoteItem('Contact support if payment is not verified'),
          _buildNoteItem('You will be notified when payment is verified'),
        ],
      ),
    )
        .animate()
        .fadeIn(
          duration: AppThemes.animationDurationMedium,
          delay: 300.ms,
        )
        .slideY(
          begin: 0.1,
          end: 0,
          duration: AppThemes.animationDurationMedium,
        );
  }

  Widget _buildNoteItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.circle_rounded,
            size: 6,
            color: AppColors.telegramBlue,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodySmall.copyWith(
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
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.telegramRed.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 64,
                  color: AppColors.telegramRed,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Payment Error',
                style: AppTextStyles.headlineMedium.copyWith(
                  color: AppColors.getTextPrimary(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.getTextSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 200,
                child: ElevatedButton(
                  onPressed: () => GoRouter.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.telegramBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppThemes.borderRadiusMedium),
                    ),
                  ),
                  child: Text(
                    'Go Back',
                    style: AppTextStyles.buttonMedium.copyWith(
                      color: Colors.white,
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

  @override
  Widget build(BuildContext context) {
    // Use cached methods to avoid multiple calls
    final methods = _cachedMethods;

    // Show loading state until initialization is complete
    if (_isLoadingMethods) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: _buildAppBar(context),
        body: _buildLoadingState(),
      );
    }

    if (_hasError) {
      return _buildErrorState();
    }

    if (_category == null) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: _buildAppBar(context),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.telegramBlue,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading payment details...',
                style: AppTextStyles.bodyMedium.copyWith(
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
    ).animate().fadeIn(
          duration: AppThemes.animationDurationMedium,
        );
  }
}

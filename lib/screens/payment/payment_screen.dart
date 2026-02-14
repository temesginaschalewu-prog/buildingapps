import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
  final _picker = ImagePicker();

  late AnimationController _animationController;

  PaymentMethod? _selectedPaymentMethod;
  File? _proofImageFile;
  bool _confirmAccuracy = false;
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  Category? _category;
  String _username = '';
  double _amount = 0.0;
  String _billingCycle = 'monthly';
  String _paymentType = 'first_time';

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
    _animationController.dispose();
    super.dispose();
  }

  void _initializeData() {
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
      });

      debugLog('PaymentScreen',
          'Category: ${category.name}, Amount: $_amount, Type: $_paymentType');
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to initialize: $e';
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

      // Now submit payment with the image URL
      final result = await paymentProvider.submitPayment(
        categoryId: _category!.id,
        paymentType: _paymentType,
        paymentMethod: paymentMethod,
        amount: _amount,
        proofImagePath: proofImageUrl,
      );

      debugLog('PaymentScreen', 'Payment submission result: $result');

      if (result['success'] == true) {
        await subscriptionProvider.refreshAfterPaymentVerification();
        await authProvider.checkSession();

        if (mounted) {
          _showSuccessSnackBar('Payment submitted successfully!');

          context.push('/payment-success', extra: {
            'category': _category,
            'paymentType': _paymentType,
            'paymentMethod': paymentMethod,
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
          : SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(AppThemes.spacingL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPaymentSummary(),
                    SizedBox(height: AppThemes.spacingXL),
                    _buildPaymentForm(methods),
                    SizedBox(height: AppThemes.spacingXL),
                    _buildPaymentInstructions(),
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
          : SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Padding(
                    padding: EdgeInsets.all(AppThemes.spacingXL),
                    child: Column(
                      children: [
                        _buildPaymentSummary(),
                        SizedBox(height: AppThemes.spacingXXL),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: _buildPaymentForm(methods),
                            ),
                            SizedBox(width: AppThemes.spacingXXL),
                            Expanded(
                              flex: 1,
                              child: _buildPaymentInstructions(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
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
      padding: EdgeInsets.all(ScreenSize.responsiveValue(
        context: context,
        mobile: AppThemes.spacingL,
        tablet: AppThemes.spacingXL,
        desktop: AppThemes.spacingXXL,
      )),
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
              SizedBox(width: AppThemes.spacingL),
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
                    SizedBox(height: 4),
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
          SizedBox(height: AppThemes.spacingL),
          Divider(color: Theme.of(context).dividerColor, height: 1),
          SizedBox(height: AppThemes.spacingL),
          _buildSummaryRow(
            icon: Icons.category_rounded,
            label: 'Category',
            value: _category?.name ?? 'N/A',
          ),
          SizedBox(height: AppThemes.spacingS),
          _buildSummaryRow(
            icon: Icons.calendar_today_rounded,
            label: 'Billing Cycle',
            value: _billingCycle.toUpperCase(),
          ),
          SizedBox(height: AppThemes.spacingS),
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
        SizedBox(width: AppThemes.spacingM),
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
    final uniqueMethods = <PaymentMethod>[];
    final seenKeys = <String>{};

    for (final method in methods) {
      final key = '${method.method}-${method.name}-${method.accountInfo}';
      if (!seenKeys.contains(key)) {
        seenKeys.add(key);
        uniqueMethods.add(method);
      }
    }

    return Container(
      padding: EdgeInsets.all(ScreenSize.responsiveValue(
        context: context,
        mobile: AppThemes.spacingL,
        tablet: AppThemes.spacingXL,
        desktop: AppThemes.spacingXXL,
      )),
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
            SizedBox(height: AppThemes.spacingL),

            // Payment Method
            Text(
              'Payment Method',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.getTextPrimary(context),
              ),
            ),
            SizedBox(height: AppThemes.spacingS),
            _buildPaymentMethodGrid(uniqueMethods),
            SizedBox(height: AppThemes.spacingL),

            // Password
            Text(
              'Password',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.getTextPrimary(context),
              ),
            ),
            SizedBox(height: AppThemes.spacingS),
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
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppThemes.spacingL,
                  vertical: AppThemes.spacingM,
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
            SizedBox(height: AppThemes.spacingL),

            // Payment Proof
            Text(
              'Payment Proof',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.getTextPrimary(context),
              ),
            ),
            SizedBox(height: AppThemes.spacingS),
            _buildProofUploadSection(),
            SizedBox(height: AppThemes.spacingL),

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
                SizedBox(width: AppThemes.spacingM),
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
            SizedBox(height: AppThemes.spacingXL),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitPayment,
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
                          SizedBox(width: AppThemes.spacingS),
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

  Widget _buildPaymentMethodGrid(List<PaymentMethod> methods) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: ScreenSize.responsiveGridCount(
          context: context,
          mobile: 2,
          tablet: 3,
          desktop: 4,
        ),
        crossAxisSpacing: AppThemes.spacingM,
        mainAxisSpacing: AppThemes.spacingM,
        childAspectRatio: 2.2,
      ),
      itemCount: methods.length,
      itemBuilder: (context, index) {
        final method = methods[index];
        final isSelected = _selectedPaymentMethod == method;

        return GestureDetector(
          onTap: () => setState(() => _selectedPaymentMethod = method),
          child: AnimatedContainer(
            duration: AppThemes.animationDurationFast,
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.telegramBlue.withOpacity(0.1)
                  : AppColors.getSurface(context),
              borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
              border: Border.all(
                color: isSelected
                    ? AppColors.telegramBlue
                    : Theme.of(context).dividerColor,
                width: isSelected ? 2.0 : 1.0,
              ),
            ),
            padding: EdgeInsets.all(AppThemes.spacingM),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.telegramBlue
                        : AppColors.getTextSecondary(context).withOpacity(0.1),
                    borderRadius:
                        BorderRadius.circular(AppThemes.borderRadiusMedium),
                  ),
                  child: Icon(
                    method.iconData,
                    size: 20,
                    color: isSelected
                        ? Colors.white
                        : AppColors.getTextSecondary(context),
                  ),
                ),
                SizedBox(height: AppThemes.spacingS),
                Text(
                  method.name,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: isSelected
                        ? AppColors.telegramBlue
                        : AppColors.getTextPrimary(context),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 2),
                Text(
                  method.accountInfo.split('\n').first,
                  style: AppTextStyles.caption.copyWith(
                    color: isSelected
                        ? AppColors.telegramBlue.withOpacity(0.8)
                        : AppColors.getTextSecondary(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ).animate().fadeIn(
                duration: AppThemes.animationDurationFast,
                delay: (index * 50).ms,
              ),
        );
      },
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
                    bottom: AppThemes.spacingM,
                    right: AppThemes.spacingM,
                    child: GestureDetector(
                      onTap: () => setState(() => _proofImageFile = null),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppThemes.spacingM,
                          vertical: AppThemes.spacingS,
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
                            SizedBox(width: 4),
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
                    top: AppThemes.spacingM,
                    left: AppThemes.spacingM,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppThemes.spacingM,
                        vertical: AppThemes.spacingXS,
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
                          SizedBox(width: 4),
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
                  SizedBox(height: AppThemes.spacingM),
                  Text(
                    'Tap to upload payment proof',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.getTextPrimary(context),
                    ),
                  ),
                  SizedBox(height: AppThemes.spacingXS),
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
      padding: EdgeInsets.all(ScreenSize.responsiveValue(
        context: context,
        mobile: AppThemes.spacingL,
        tablet: AppThemes.spacingXL,
        desktop: AppThemes.spacingXXL,
      )),
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
              SizedBox(width: AppThemes.spacingM),
              Text(
                'Instructions',
                style: AppTextStyles.titleSmall.copyWith(
                  color: AppColors.getTextPrimary(context),
                ),
              ),
            ],
          ),
          SizedBox(height: AppThemes.spacingL),
          Divider(color: Theme.of(context).dividerColor, height: 1),
          SizedBox(height: AppThemes.spacingL),
          Text(
            instructions,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.getTextSecondary(context),
              height: 1.6,
            ),
          ),
          SizedBox(height: AppThemes.spacingL),
          Divider(color: Theme.of(context).dividerColor, height: 1),
          SizedBox(height: AppThemes.spacingL),
          Text(
            'Important Notes:',
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.getTextPrimary(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: AppThemes.spacingS),
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
      padding: EdgeInsets.only(bottom: AppThemes.spacingS),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.circle_rounded,
            size: 6,
            color: AppColors.telegramBlue,
          ),
          SizedBox(width: 8),
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
          padding: EdgeInsets.all(AppThemes.spacingXL),
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
              ),
              SizedBox(height: AppThemes.spacingXL),
              Text(
                'Payment Error',
                style: AppTextStyles.headlineMedium.copyWith(
                  color: AppColors.getTextPrimary(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: AppThemes.spacingL),
              Text(
                _errorMessage,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.getTextSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppThemes.spacingXXL),
              SizedBox(
                width: 200,
                child: ElevatedButton(
                  onPressed: () => GoRouter.of(context).pop(),
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
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final paymentMethods = settingsProvider.getPaymentMethods();

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
              SizedBox(height: AppThemes.spacingL),
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

    if (paymentMethods.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: _buildAppBar(context),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(AppThemes.spacingXL),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(AppThemes.spacingXL),
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
                SizedBox(height: AppThemes.spacingXL),
                Text(
                  'No Payment Methods',
                  style: AppTextStyles.headlineSmall.copyWith(
                    color: AppColors.getTextPrimary(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: AppThemes.spacingL),
                Text(
                  'Payment methods are not currently available.\nPlease check back later or contact support.',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: AppThemes.spacingXXL),
                SizedBox(
                  width: 200,
                  child: ElevatedButton(
                    onPressed: () => GoRouter.of(context).pop(),
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

    return ResponsiveLayout(
      mobile: _buildMobileLayout(context, paymentMethods),
      tablet: _buildDesktopLayout(context, paymentMethods),
      desktop: _buildDesktopLayout(context, paymentMethods),
    ).animate().fadeIn(
          duration: AppThemes.animationDurationMedium,
        );
  }
}

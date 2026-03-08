import 'dart:async' show StreamSubscription;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import '../../models/category_model.dart';
import '../../providers/payment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/category_provider.dart';
import '../../services/device_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/snackbar_service.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/app_shimmer.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../utils/responsive.dart';
import '../../utils/responsive_values.dart';
import '../../themes/app_themes.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
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
  int _pendingCount = 0;
  String? _currentUserId;
  StreamSubscription? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _animationController =
        AnimationController(vsync: this, duration: AppThemes.animationMedium);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getCurrentUserId();
      _checkConnectivity();
      _checkPendingCount();
      _initializeData();
      _animationController.forward();
    });

    _setupConnectivityListener();
  }

  void _setupConnectivityListener() {
    final connectivityService = context.read<ConnectivityService>();
    _connectivitySubscription =
        connectivityService.onConnectivityChanged.listen((isOnline) {
      if (mounted) {
        setState(() {
          _isOffline = !isOnline;
          _pendingCount = connectivityService.pendingActionsCount;
        });
      }
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _accountHolderNameController.dispose();
    _animationController.dispose();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _getCurrentUserId() async {
    final authProvider = context.read<AuthProvider>();
    _currentUserId = authProvider.currentUser?.id.toString();
  }

  Future<void> _checkConnectivity() async {
    final connectivityService = context.read<ConnectivityService>();
    setState(() {
      _isOffline = !connectivityService.isOnline;
      _pendingCount = connectivityService.pendingActionsCount;
    });
  }

  Future<void> _checkPendingCount() async {
    final connectivity = ConnectivityService();
    setState(() => _pendingCount = connectivity.pendingActionsCount);
  }

  Future<void> _loadCachedPaymentMethods() async {
    try {
      final deviceService = context.read<DeviceService>();
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

      final authProvider = context.read<AuthProvider>();
      final categoryProvider = context.read<CategoryProvider>();

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
          final categoryId = categoryData['id'];
          if (categoryId != null) {
            category = categoryProvider.getCategoryById(categoryId);
          }
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

    final settingsProvider = context.read<SettingsProvider>();

    if (settingsProvider.allSettings.isEmpty && !_isOffline) {
      await settingsProvider.getAllSettings();
    }

    _cachedMethods = settingsProvider.getPaymentMethods();

    if (_cachedMethods.isNotEmpty && _currentUserId != null && !_isOffline) {
      try {
        final deviceService = context.read<DeviceService>();
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
      } catch (e) {
        debugLog('PaymentScreen', 'Error caching payment methods: $e');
      }
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
          SnackbarService().showError(context, 'Image must be less than 5MB');
          return;
        }

        setState(() => _proofImageFile = file);
      }
    } catch (e) {
      debugLog('PaymentScreen', 'Error picking image: $e');
      SnackbarService().showError(context, 'Failed to pick image: $e');
    }
  }

  String _getBillingCycleDescription() {
    return _billingCycle == 'semester'
        ? 'Semester (4 months)'
        : 'Monthly (1 month)';
  }

  String _getAccessDurationText() {
    return _billingCycle == 'semester'
        ? 'You will get access for 4 months'
        : 'You will get access for 1 month';
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
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Password must be at least 6 characters';
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Payment Method', style: AppTextStyles.labelMedium(context)),
        SizedBox(height: ResponsiveValues.spacingS(context)),
        AppCard.glass(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButtonFormField<PaymentMethod>(
              initialValue: _selectedPaymentMethod,
              hint: Padding(
                padding: ResponsiveValues.listItemPadding(context),
                child: Text(
                  'Select a payment method',
                  style: AppTextStyles.bodyMedium(context)
                      .copyWith(color: AppColors.getTextSecondary(context)),
                ),
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
                        width: ResponsiveValues.iconSizeL(context),
                        height: ResponsiveValues.iconSizeL(context),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.telegramBlue.withValues(alpha: 0.2),
                              AppColors.telegramPurple.withValues(alpha: 0.1)
                            ],
                          ),
                          borderRadius: BorderRadius.circular(
                              ResponsiveValues.radiusSmall(context)),
                        ),
                        child: Icon(method.iconData,
                            size: ResponsiveValues.iconSizeXS(context),
                            color: AppColors.telegramBlue),
                      ),
                      SizedBox(width: ResponsiveValues.spacingM(context)),
                      Expanded(
                        child: RichText(
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            style: DefaultTextStyle.of(context).style,
                            children: [
                              TextSpan(
                                  text: '${method.name}\n',
                                  style: AppTextStyles.bodyMedium(context)),
                              TextSpan(
                                text: method.accountInfo.split('\n').first,
                                style: AppTextStyles.caption(context).copyWith(
                                    color: AppColors.getTextSecondary(context)),
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
            padding: EdgeInsets.only(top: ResponsiveValues.spacingS(context)),
            child: Text(
              'Payment methods require internet connection',
              style: AppTextStyles.caption(context)
                  .copyWith(color: AppColors.warning),
            ),
          ),
        if (_selectedPaymentMethod != null) ...[
          SizedBox(height: ResponsiveValues.spacingL(context)),
          AppCard.glass(
            child: Padding(
              padding: ResponsiveValues.cardPadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_rounded,
                          size: 16, color: AppColors.telegramBlue),
                      SizedBox(width: ResponsiveValues.spacingS(context)),
                      Text(
                        'Account Details',
                        style: AppTextStyles.labelMedium(context)
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  SizedBox(height: ResponsiveValues.spacingM(context)),
                  Container(
                    padding: ResponsiveValues.cardPadding(context),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.getCard(context).withValues(alpha: 0.3),
                          AppColors.getCard(context).withValues(alpha: 0.1)
                        ],
                      ),
                      borderRadius: BorderRadius.circular(
                          ResponsiveValues.radiusSmall(context)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _selectedPaymentMethod!.accountInfo,
                            style: AppTextStyles.bodyMedium(context),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(
                                text: _selectedPaymentMethod!.accountInfo));
                            SnackbarService()
                                .showSuccess(context, 'Copied to clipboard');
                          },
                          child: Container(
                            padding: EdgeInsets.all(
                                ResponsiveValues.spacingXXS(context)),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.telegramBlue.withValues(alpha: 0.2),
                                  AppColors.telegramBlue.withValues(alpha: 0.1)
                                ],
                              ),
                              borderRadius: BorderRadius.circular(
                                  ResponsiveValues.radiusSmall(context)),
                            ),
                            child: const Icon(Icons.copy_rounded,
                                size: 16, color: AppColors.telegramBlue),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: ResponsiveValues.spacingM(context)),
                  Text(
                    'Instructions',
                    style: AppTextStyles.labelSmall(context)
                        .copyWith(color: AppColors.getTextSecondary(context)),
                  ),
                  SizedBox(height: ResponsiveValues.spacingXS(context)),
                  Text(
                    _selectedPaymentMethod!.instructions,
                    style:
                        AppTextStyles.bodySmall(context).copyWith(height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProofUploadSection() {
    return GestureDetector(
      onTap: _isOffline ? null : _pickImage,
      child: AnimatedContainer(
        duration: AppThemes.animationFast,
        height: 200,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.getSurface(context).withValues(alpha: 0.3),
              AppColors.getSurface(context).withValues(alpha: 0.1)
            ],
          ),
          borderRadius:
              BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
          border: Border.all(
            color: _proofImageFile == null
                ? (_isOffline
                    ? AppColors.warning.withValues(alpha: 0.2)
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
                    Image.file(_proofImageFile!, fit: BoxFit.contain),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.5)
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
                                AppColors.telegramRed.withValues(alpha: 0.8)
                              ],
                            ),
                            borderRadius: BorderRadius.circular(
                                ResponsiveValues.radiusFull(context)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.delete_rounded,
                                  size: 16, color: Colors.white),
                              SizedBox(
                                  width: ResponsiveValues.spacingXS(context)),
                              Text(
                                'Remove',
                                style: AppTextStyles.caption(context).copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600),
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
                              AppColors.telegramGreen.withValues(alpha: 0.8)
                            ],
                          ),
                          borderRadius: BorderRadius.circular(
                              ResponsiveValues.radiusFull(context)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                size: 14, color: Colors.white),
                            SizedBox(
                                width: ResponsiveValues.spacingXS(context)),
                            Text(
                              'Uploaded',
                              style: AppTextStyles.caption(context).copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isOffline
                        ? Icons.wifi_off_rounded
                        : Icons.cloud_upload_rounded,
                    size: ResponsiveValues.iconSizeXXL(context),
                    color: _isOffline
                        ? AppColors.warning
                        : AppColors.getTextSecondary(context),
                  ),
                  SizedBox(height: ResponsiveValues.spacingM(context)),
                  Text(
                    _isOffline
                        ? 'Offline - will queue when online'
                        : 'Tap to upload payment proof',
                    style: AppTextStyles.bodyMedium(context).copyWith(
                      color: _isOffline
                          ? AppColors.warning
                          : AppColors.getTextPrimary(context),
                    ),
                  ),
                  SizedBox(height: ResponsiveValues.spacingXS(context)),
                  Text(
                    _isOffline ? 'Connect to internet' : 'JPG or PNG • Max 5MB',
                    style: AppTextStyles.caption(context).copyWith(
                      color: _isOffline
                          ? AppColors.warning
                          : AppColors.getTextSecondary(context),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildNoteItem(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: ResponsiveValues.spacingS(context)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.circle_rounded,
              size: 6, color: AppColors.telegramBlue),
          SizedBox(width: ResponsiveValues.spacingS(context)),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodySmall(context)
                  .copyWith(color: AppColors.getTextSecondary(context)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSummary() {
    if (_category == null) return const SizedBox.shrink();

    return AppCard.glass(
      child: Padding(
        padding: ResponsiveValues.cardPadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: ResponsiveValues.iconSizeXL(context) * 1.5,
                  height: ResponsiveValues.iconSizeXL(context) * 1.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.telegramBlue.withValues(alpha: 0.2),
                        AppColors.telegramPurple.withValues(alpha: 0.1)
                      ],
                    ),
                    borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusMedium(context)),
                  ),
                  child: const Icon(Icons.payment_rounded,
                      color: AppColors.telegramBlue, size: 24),
                ),
                SizedBox(width: ResponsiveValues.spacingL(context)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_category?.name ?? 'Payment',
                          style: AppTextStyles.titleMedium(context)),
                      SizedBox(height: ResponsiveValues.spacingXS(context)),
                      Text(
                        _paymentType == 'first_time'
                            ? 'First Time Payment'
                            : 'Renewal Payment',
                        style: AppTextStyles.bodySmall(context).copyWith(
                            color: AppColors.getTextSecondary(context)),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _amount.toStringAsFixed(0),
                      style: AppTextStyles.displaySmall(context).copyWith(
                          color: AppColors.telegramBlue,
                          fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'ETB',
                      style: AppTextStyles.labelMedium(context)
                          .copyWith(color: AppColors.getTextSecondary(context)),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: ResponsiveValues.spacingL(context)),
            Divider(
                color: AppColors.getDivider(context).withValues(alpha: 0.2),
                height: 1),
            SizedBox(height: ResponsiveValues.spacingL(context)),
            _buildSummaryRow(
                icon: Icons.category_rounded,
                label: 'Category',
                value: _category?.name ?? 'N/A'),
            SizedBox(height: ResponsiveValues.spacingS(context)),
            _buildSummaryRow(
                icon: Icons.calendar_today_rounded,
                label: 'Billing Cycle',
                value: _getBillingCycleDescription()),
            SizedBox(height: ResponsiveValues.spacingS(context)),
            _buildSummaryRow(
                icon: Icons.timer_rounded,
                label: 'Access Duration',
                value: _getAccessDurationText()),
            SizedBox(height: ResponsiveValues.spacingS(context)),
            _buildSummaryRow(
                icon: Icons.person_rounded,
                label: 'Username',
                value: _username),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: AppThemes.animationMedium, delay: 100.ms)
        .slideY(begin: 0.1, end: 0, duration: AppThemes.animationMedium);
  }

  Widget _buildSummaryRow(
      {required IconData icon, required String label, required String value}) {
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
                  style: AppTextStyles.bodySmall(context)
                      .copyWith(color: AppColors.getTextSecondary(context))),
              Text(value,
                  style: AppTextStyles.bodyMedium(context)
                      .copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentForm(List<PaymentMethod> methods) {
    if (_category == null) return const SizedBox.shrink();

    return AppCard.glass(
      child: Padding(
        padding: ResponsiveValues.cardPadding(context),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Payment Details',
                  style: AppTextStyles.titleMedium(context)),
              SizedBox(height: ResponsiveValues.spacingL(context)),
              _buildPaymentMethodDropdown(methods),
              SizedBox(height: ResponsiveValues.spacingL(context)),
              AppTextField(
                controller: _accountHolderNameController,
                label: 'Account Holder Name',
                hint: 'Enter the account holder name',
                prefixIcon: Icons.person_outline_rounded,
                enabled: !_isOffline,
                validator: _validateAccountHolderName,
                requiresOnline: true,
              ),
              SizedBox(height: ResponsiveValues.spacingL(context)),
              AppTextField.password(
                controller: _passwordController,
                label: 'Password',
                hint: 'Enter your password',
                enabled: !_isOffline,
                validator: _validatePassword,
                requiresOnline: true,
              ),
              SizedBox(height: ResponsiveValues.spacingL(context)),
              Text('Payment Proof', style: AppTextStyles.labelMedium(context)),
              SizedBox(height: ResponsiveValues.spacingS(context)),
              _buildProofUploadSection(),
              SizedBox(height: ResponsiveValues.spacingL(context)),
              Row(
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
                            ResponsiveValues.radiusSmall(context)),
                      ),
                    ),
                  ),
                  SizedBox(width: ResponsiveValues.spacingM(context)),
                  Expanded(
                    child: Text(
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
                      bottom: ResponsiveValues.spacingL(context)),
                  child: Container(
                    padding: ResponsiveValues.cardPadding(context),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.warning.withValues(alpha: 0.2),
                          AppColors.warning.withValues(alpha: 0.1)
                        ],
                      ),
                      borderRadius: BorderRadius.circular(
                          ResponsiveValues.radiusMedium(context)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.wifi_off_rounded,
                            color: AppColors.warning, size: 20),
                        SizedBox(width: ResponsiveValues.spacingM(context)),
                        Expanded(
                          child: Text(
                            'You are offline. Payment will be queued.',
                            style: AppTextStyles.bodySmall(context)
                                .copyWith(color: AppColors.warning),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              SizedBox(height: ResponsiveValues.spacingXL(context)),
              SizedBox(
                width: double.infinity,
                child: AppButton.primary(
                  label: _isOffline ? 'Queue Payment' : 'Submit Payment',
                  onPressed: _isLoading ? null : _submitPayment,
                  icon:
                      _isOffline ? Icons.schedule_rounded : Icons.send_rounded,
                  isLoading: _isLoading,
                  expanded: true,
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: AppThemes.animationMedium, delay: 200.ms)
        .slideY(begin: 0.1, end: 0, duration: AppThemes.animationMedium);
  }

  Future<void> _submitPayment() async {
    if (_category == null) {
      SnackbarService().showError(context, 'Category information missing');
      return;
    }

    if (_amount <= 0) {
      SnackbarService().showError(context, 'Invalid payment amount');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    if (_selectedPaymentMethod == null) {
      SnackbarService().showError(context, 'Please select a payment method');
      return;
    }

    if (_proofImageFile == null) {
      SnackbarService().showError(context, 'Please upload payment proof');
      return;
    }

    if (!_confirmAccuracy) {
      SnackbarService().showError(context, 'Please confirm accuracy');
      return;
    }

    final connectivityService = context.read<ConnectivityService>();
    final isOnline = connectivityService.isOnline;

    setState(() => _isLoading = true);

    final paymentProvider = context.read<PaymentProvider>();
    final subscriptionProvider = context.read<SubscriptionProvider>();
    final authProvider = context.read<AuthProvider>();

    try {
      final paymentMethod = _selectedPaymentMethod!.method;

      String? proofImageUrl;

      if (isOnline) {
        try {
          final apiService = paymentProvider.apiService;
          final uploadResponse =
              await apiService.uploadPaymentProof(_proofImageFile!);
          if (uploadResponse.success && uploadResponse.data != null) {
            proofImageUrl = uploadResponse.data;
          } else {
            SnackbarService()
                .showError(context, 'Failed to upload payment proof');
            setState(() => _isLoading = false);
            return;
          }
        } catch (uploadError) {
          debugLog('PaymentScreen', 'Upload error: $uploadError');
          SnackbarService().showError(context, 'Failed to upload image');
          setState(() => _isLoading = false);
          return;
        }
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
        if (result['queued'] == true) {
          // Payment queued offline
          SnackbarService().showQueued(context, action: 'Payment');
          if (mounted) {
            await context.push('/payment-success', extra: {
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
              'queued': true,
            });
          }
        } else {
          // Payment submitted online
          await subscriptionProvider.refreshAfterPaymentVerification();
          await authProvider.checkSession();

          if (mounted) {
            SnackbarService()
                .showSuccess(context, 'Payment submitted successfully!');
            await context.push('/payment-success', extra: {
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
        }
      } else {
        final message = result['message'] ?? 'Payment failed';
        final action = result['action'];

        if (action == 'device_change_required') {
          if (mounted) {
            await context.push('/device-change', extra: {
              'message': message,
              'action': action,
              'data': result['data']
            });
          }
        } else {
          if (mounted) SnackbarService().showError(context, message);
        }
      }
    } catch (e) {
      debugLog('PaymentScreen', 'Payment error: $e');
      if (mounted) {
        SnackbarService().showError(context, 'Payment failed: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildPaymentInstructions() {
    final settingsProvider = context.read<SettingsProvider>();
    final instructions = settingsProvider.getPaymentInstructions();

    return AppCard.glass(
      child: Padding(
        padding: ResponsiveValues.cardPadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                    borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusMedium(context)),
                  ),
                  child: const Icon(Icons.info_rounded,
                      color: AppColors.telegramBlue, size: 20),
                ),
                SizedBox(width: ResponsiveValues.spacingM(context)),
                Text('Instructions', style: AppTextStyles.titleSmall(context)),
              ],
            ),
            SizedBox(height: ResponsiveValues.spacingL(context)),
            Divider(
                color: AppColors.getDivider(context).withValues(alpha: 0.2),
                height: 1),
            SizedBox(height: ResponsiveValues.spacingL(context)),
            Text(
              instructions,
              style: AppTextStyles.bodyMedium(context).copyWith(
                  color: AppColors.getTextSecondary(context), height: 1.6),
            ),
            SizedBox(height: ResponsiveValues.spacingL(context)),
            Divider(
                color: AppColors.getDivider(context).withValues(alpha: 0.2),
                height: 1),
            SizedBox(height: ResponsiveValues.spacingL(context)),
            Text('Important Notes:',
                style: AppTextStyles.labelMedium(context)
                    .copyWith(fontWeight: FontWeight.w600)),
            SizedBox(height: ResponsiveValues.spacingS(context)),
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
        .fadeIn(duration: AppThemes.animationMedium, delay: 300.ms)
        .slideY(begin: 0.1, end: 0, duration: AppThemes.animationMedium);
  }

  Widget _buildSkeletonLoader() {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: _buildAppBar(context),
      body: SingleChildScrollView(
        child: Padding(
          padding: ResponsiveValues.screenPadding(context),
          child: Column(
            children: [
              AppCard.glass(
                child: Padding(
                  padding: ResponsiveValues.cardPadding(context),
                  child: Column(
                    children: List.generate(
                      5,
                      (index) => Padding(
                        padding: EdgeInsets.only(
                            bottom: ResponsiveValues.spacingM(context)),
                        child: Row(
                          children: [
                            const AppShimmer(
                                type: ShimmerType.circle,
                                customWidth: 24,
                                customHeight: 24),
                            SizedBox(width: ResponsiveValues.spacingM(context)),
                            const Expanded(
                                child: AppShimmer(
                                    type: ShimmerType.textLine,
                                    customHeight: 16)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: ResponsiveValues.spacingXL(context)),
              AppCard.glass(
                child: Padding(
                  padding: ResponsiveValues.cardPadding(context),
                  child: Column(
                    children: List.generate(
                      4,
                      (index) => Padding(
                        padding: EdgeInsets.only(
                            bottom: ResponsiveValues.spacingL(context)),
                        child: const AppShimmer(
                            type: ShimmerType.rectangle, customHeight: 48),
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

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: AppButton.icon(
          icon: Icons.arrow_back_rounded,
          onPressed: () => GoRouter.of(context).pop()),
      title: Text('Payment', style: AppTextStyles.appBarTitle(context)),
      centerTitle: false,
    );
  }

  Widget _buildErrorState() {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: _buildAppBar(context),
      body: Center(
        child: Padding(
          padding: ResponsiveValues.dialogPadding(context),
          child: AppEmptyState.error(
            title: 'Payment Error',
            message: _errorMessage,
            onRetry: () => GoRouter.of(context).pop(),
          ),
        ),
      ),
    );
  }

  Widget _buildNoMethodsState() {
    return Center(
      child: Padding(
        padding: ResponsiveValues.dialogPadding(context),
        child: AppEmptyState.noData(
          dataType: 'payment methods',
          customMessage:
              'Payment methods are not available.\nPlease try again or contact support.',
          onRefresh: () {
            setState(() {
              _settingsLoadAttempted = false;
              _isLoadingMethods = true;
            });
            _loadPaymentMethods();
          },
          isOffline: _isOffline,
          pendingCount: _pendingCount,
        ),
      ),
    );
  }

  Widget _buildOfflineNoMethodsState() {
    return Center(
      child: Padding(
        padding: ResponsiveValues.dialogPadding(context),
        child: AppEmptyState.offline(
          message:
              'No cached payment methods are available.\nPlease connect to the internet and try again.',
          onRetry: () => GoRouter.of(context).pop(),
          pendingCount: _pendingCount,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_pendingCount > 0)
                Container(
                  margin: EdgeInsets.only(
                      bottom: ResponsiveValues.spacingL(context)),
                  padding: ResponsiveValues.cardPadding(context),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.info.withValues(alpha: 0.2),
                        AppColors.info.withValues(alpha: 0.1)
                      ],
                    ),
                    borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusMedium(context)),
                    border: Border.all(
                        color: AppColors.info.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule_rounded,
                          color: AppColors.info, size: 20),
                      SizedBox(width: ResponsiveValues.spacingM(context)),
                      Expanded(
                        child: Text(
                          '$_pendingCount pending payment${_pendingCount > 1 ? 's' : ''} waiting to sync',
                          style: AppTextStyles.bodySmall(context)
                              .copyWith(color: AppColors.info),
                        ),
                      ),
                    ],
                  ),
                ),
              _buildPaymentSummary(),
              SizedBox(height: ResponsiveValues.spacingXL(context)),
              _buildPaymentForm(methods),
              SizedBox(height: ResponsiveValues.spacingXL(context)),
              _buildPaymentInstructions(),
              SizedBox(height: ResponsiveValues.spacingXXL(context)),
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
    if (methods.isEmpty && _isOffline) {
      return Center(child: _buildOfflineNoMethodsState());
    }
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
              child: Column(
                children: [
                  if (_pendingCount > 0)
                    Container(
                      margin: EdgeInsets.only(
                          bottom: ResponsiveValues.spacingL(context)),
                      padding: ResponsiveValues.cardPadding(context),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.info.withValues(alpha: 0.2),
                            AppColors.info.withValues(alpha: 0.1)
                          ],
                        ),
                        borderRadius: BorderRadius.circular(
                            ResponsiveValues.radiusMedium(context)),
                        border: Border.all(
                            color: AppColors.info.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.schedule_rounded,
                              color: AppColors.info, size: 20),
                          SizedBox(width: ResponsiveValues.spacingM(context)),
                          Text(
                            '$_pendingCount pending payment${_pendingCount > 1 ? 's' : ''}',
                            style: AppTextStyles.bodySmall(context)
                                .copyWith(color: AppColors.info),
                          ),
                        ],
                      ),
                    ),
                  _buildPaymentSummary(),
                  SizedBox(height: ResponsiveValues.spacingXXXL(context)),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: _buildPaymentForm(methods)),
                      SizedBox(width: ResponsiveValues.spacingXXXL(context)),
                      Expanded(child: _buildPaymentInstructions()),
                    ],
                  ),
                  SizedBox(height: ResponsiveValues.spacingXXXL(context)),
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: ResponsiveValues.iconSizeXL(context),
                height: ResponsiveValues.iconSizeXL(context),
                child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.telegramBlue)),
              ),
              SizedBox(height: ResponsiveValues.spacingL(context)),
              Text(
                'Loading payment details...',
                style: AppTextStyles.bodyMedium(context)
                    .copyWith(color: AppColors.getTextSecondary(context)),
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
    ).animate().fadeIn(duration: AppThemes.animationMedium);
  }
}

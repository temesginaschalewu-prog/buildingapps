// lib/screens/payment/payment_screen.dart
// COMPLETE PRODUCTION-READY FILE - REPLACE ENTIRE FILE

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/category_model.dart';
import '../../providers/payment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/category_provider.dart';
import '../../services/device_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/snackbar_service.dart';
import '../../services/offline_queue_manager.dart';
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
import '../../utils/constants.dart';

/// PRODUCTION-READY PAYMENT SCREEN with 3-Tier Caching
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
      _initialize();
      _animationController.forward();
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

  Future<void> _initialize() async {
    await _getCurrentUserId();
    await _checkConnectivity();
    _setupConnectivityListener();
    _checkPendingCount();
    _initializeData();
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

  Future<void> _getCurrentUserId() async {
    final authProvider = context.read<AuthProvider>();
    _currentUserId = authProvider.currentUser?.id.toString();
  }

  Future<void> _checkConnectivity() async {
    final connectivityService = context.read<ConnectivityService>();
    await connectivityService.checkConnectivity();
    if (mounted) {
      setState(() {
        _isOffline = !connectivityService.isOnline;
        _pendingCount = connectivityService.pendingActionsCount;
      });
    }
  }

  Future<void> _checkPendingCount() async {
    final connectivityService = context.read<ConnectivityService>();
    if (mounted) {
      setState(() => _pendingCount = connectivityService.pendingActionsCount);
    }
  }

  // TIER 2: Load cached payment methods
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

  // TIER 1 & 2: Initialize from cache/args
  void _initializeData() {
    if (_initialized) return;

    try {
      final args = widget.extra;
      if (args == null) {
        if (_isOffline) {
          _loadCachedPaymentMethods(); // TIER 2
        }
        setState(() {
          _hasError = true;
          _errorMessage = AppStrings.noPaymentDataProvided;
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
            name: categoryData['name'] ?? AppStrings.unknown,
            status: 'active',
            price: double.parse(categoryData['price'].toString()),
            billingCycle: categoryData['billing_cycle'] ?? 'monthly',
            description: categoryData['description'],
          );
        } else {
          final categoryId = categoryData['id'];
          if (categoryId != null) {
            category = categoryProvider.getCategoryById(categoryId); // TIER 1
          }
        }
      }

      if (category == null) {
        setState(() {
          _hasError = true;
          _errorMessage = AppStrings.categoryNotFound;
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

      _loadPaymentMethods(); // TIER 3 if online, TIER 2 if cached
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = '${AppStrings.failedToInitialize}: $e';
      });
    }
  }

  // TIER 3: Load payment methods from API
  Future<void> _loadPaymentMethods() async {
    if (_settingsLoadAttempted) return;
    _settingsLoadAttempted = true;

    final settingsProvider = context.read<SettingsProvider>();

    if (settingsProvider.allSettings.isEmpty && !_isOffline) {
      await settingsProvider.getAllSettings(); // TIER 3
    }

    _cachedMethods = settingsProvider.getPaymentMethods(); // TIER 1

    if (_cachedMethods.isNotEmpty && _currentUserId != null && !_isOffline) {
      try {
        final deviceService = context.read<DeviceService>();
        deviceService.saveCacheItem(
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
        ); // Save to TIER 2
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
          SnackbarService().showError(context, AppStrings.imageTooLarge5MB);
          return;
        }

        setState(() => _proofImageFile = file);
      }
    } catch (e) {
      debugLog('PaymentScreen', 'Error picking image: $e');
      SnackbarService()
          .showError(context, '${AppStrings.failedToPickImage}: $e');
    }
  }

  String _getBillingCycleDescription() {
    return _billingCycle == 'semester'
        ? AppStrings.semesterBilling
        : AppStrings.monthlyBilling;
  }

  String _getAccessDurationText() {
    return _billingCycle == 'semester'
        ? AppStrings.accessFourMonths
        : AppStrings.accessOneMonth;
  }

  String? _validateAccountHolderName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppStrings.accountHolderNameRequired;
    }
    if (value.trim().length < 3) {
      return AppStrings.accountHolderNameMinLength;
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return AppStrings.passwordRequired;
    if (value.length < 6) return AppStrings.passwordMinLength;
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
        Text(AppStrings.paymentMethod,
            style: AppTextStyles.labelMedium(context)),
        SizedBox(height: ResponsiveValues.spacingS(context)),
        AppCard.glass(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButtonFormField<PaymentMethod>(
              value: _selectedPaymentMethod,
              hint: Padding(
                padding: ResponsiveValues.listItemPadding(context),
                child: Text(
                  AppStrings.selectPaymentMethod,
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
                        AppStrings.accountDetails,
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
                            SnackbarService().showSuccess(
                                context, AppStrings.copiedToClipboard);
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
                    AppStrings.instructions,
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
                                AppStrings.remove,
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
                              AppStrings.uploaded,
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
                        ? AppStrings.offlineWillQueue
                        : AppStrings.tapToUploadProof,
                    style: AppTextStyles.bodyMedium(context).copyWith(
                      color: _isOffline
                          ? AppColors.warning
                          : AppColors.getTextPrimary(context),
                    ),
                  ),
                  SizedBox(height: ResponsiveValues.spacingXS(context)),
                  Text(
                    _isOffline
                        ? AppStrings.connectToInternet
                        : AppStrings.imageRequirements,
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
                      Text(_category?.name ?? AppStrings.payment,
                          style: AppTextStyles.titleMedium(context)),
                      SizedBox(height: ResponsiveValues.spacingXS(context)),
                      Text(
                        _paymentType == 'first_time'
                            ? AppStrings.firstTimePayment
                            : AppStrings.renewalPayment,
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
                      AppStrings.etb,
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
                label: AppStrings.category,
                value: _category?.name ?? AppStrings.notAvailable),
            SizedBox(height: ResponsiveValues.spacingS(context)),
            _buildSummaryRow(
                icon: Icons.calendar_today_rounded,
                label: AppStrings.billingCycle,
                value: _getBillingCycleDescription()),
            SizedBox(height: ResponsiveValues.spacingS(context)),
            _buildSummaryRow(
                icon: Icons.timer_rounded,
                label: AppStrings.accessDuration,
                value: _getAccessDurationText()),
            SizedBox(height: ResponsiveValues.spacingS(context)),
            _buildSummaryRow(
                icon: Icons.person_rounded,
                label: AppStrings.username,
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
              Text(AppStrings.paymentDetails,
                  style: AppTextStyles.titleMedium(context)),
              SizedBox(height: ResponsiveValues.spacingL(context)),
              _buildPaymentMethodDropdown(methods),
              SizedBox(height: ResponsiveValues.spacingL(context)),
              AppTextField(
                controller: _accountHolderNameController,
                label: AppStrings.accountHolderName,
                hint: AppStrings.enterAccountHolderName,
                prefixIcon: Icons.person_outline_rounded,
                enabled: !_isOffline,
                validator: _validateAccountHolderName,
                requiresOnline: true,
              ),
              SizedBox(height: ResponsiveValues.spacingL(context)),
              AppTextField.password(
                controller: _passwordController,
                label: AppStrings.password,
                hint: AppStrings.enterPassword,
                enabled: !_isOffline,
                validator: _validatePassword,
                requiresOnline: true,
              ),
              SizedBox(height: ResponsiveValues.spacingL(context)),
              Text(AppStrings.paymentProof,
                  style: AppTextStyles.labelMedium(context)),
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
                      AppStrings.confirmAccuracy,
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
              SizedBox(height: ResponsiveValues.spacingXL(context)),
              SizedBox(
                width: double.infinity,
                child: AppButton.primary(
                  label: _isOffline
                      ? AppStrings.queuePayment
                      : AppStrings.submitPayment,
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

  // TIER 2 & 3: Submit payment with offline queue
  Future<void> _submitPayment() async {
    if (_category == null) {
      SnackbarService().showError(context, AppStrings.categoryInfoMissing);
      return;
    }

    if (_amount <= 0) {
      SnackbarService().showError(context, AppStrings.invalidPaymentAmount);
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    if (_selectedPaymentMethod == null) {
      SnackbarService().showError(context, AppStrings.selectPaymentMethod);
      return;
    }

    if (_proofImageFile == null) {
      SnackbarService().showError(context, AppStrings.uploadPaymentProof);
      return;
    }

    if (!_confirmAccuracy) {
      SnackbarService().showError(context, AppStrings.confirmAccuracy);
      return;
    }

    final connectivityService = context.read<ConnectivityService>();
    final isOnline = connectivityService.isOnline;

    setState(() => _isLoading = true);

    final paymentProvider = context.read<PaymentProvider>();
    final subscriptionProvider = context.read<SubscriptionProvider>();
    final authProvider = context.read<AuthProvider>();
    final queueManager = context.read<OfflineQueueManager>();

    try {
      final paymentMethod = _selectedPaymentMethod!.method;

      String? proofImageUrl;

      if (isOnline) {
        try {
          final uploadResponse =
              await paymentProvider.uploadPaymentProof(_proofImageFile!);
          if (uploadResponse.success && uploadResponse.data != null) {
            proofImageUrl = uploadResponse.data;
          } else {
            SnackbarService()
                .showError(context, AppStrings.failedToUploadProof);
            setState(() => _isLoading = false);
            return;
          }
        } catch (uploadError) {
          debugLog('PaymentScreen', 'Upload error: $uploadError');
          SnackbarService().showError(context, AppStrings.failedToUploadImage);
          setState(() => _isLoading = false);
          return;
        }
      }

      final accountHolderName = _accountHolderNameController.text.trim();

      if (!isOnline) {
        // TIER 2: Queue offline
        queueManager.addItem(
          type: AppConstants.queueActionSubmitPayment,
          data: {
            'categoryId': _category!.id,
            'paymentType': _paymentType,
            'paymentMethod': paymentMethod,
            'amount': _amount,
            'accountHolderName':
                accountHolderName.isNotEmpty ? accountHolderName : null,
            'proofImagePath': null,
            'userId': _currentUserId,
          },
        );

        // Also save to cache for success screen
        final deviceService = context.read<DeviceService>();
        deviceService.saveCacheItem(
          'last_payment_data',
          {
            'categoryId': _category!.id,
            'paymentType': _paymentType,
            'paymentMethod': paymentMethod,
            'paymentMethodName': _selectedPaymentMethod!.name,
            'categoryName': _category!.name,
            'amount': _amount,
            'billingCycle': _billingCycle,
            'durationText': _getAccessDurationText(),
            'username': _username,
            'accountHolderName':
                accountHolderName.isNotEmpty ? accountHolderName : null,
            'queued': true,
          },
          ttl: const Duration(days: 1),
        );

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
        // TIER 3: Submit online
        final result = await paymentProvider.submitPayment(
          categoryId: _category!.id,
          paymentType: _paymentType,
          paymentMethod: paymentMethod,
          amount: _amount,
          accountHolderName:
              accountHolderName.isNotEmpty ? accountHolderName : null,
          proofImagePath: proofImageUrl,
        );

        if (result.success && result.data != null) {
          await subscriptionProvider.refreshAfterPaymentVerification();
          await authProvider.checkSession();

          if (mounted) {
            SnackbarService().showSuccess(context, AppStrings.paymentSubmitted);
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
        } else {
          final message = result.message;
          final action = result.data?['action'];

          if (action == 'device_change_required') {
            if (mounted) {
              await context.push('/device-change', extra: {
                'message': message,
                'action': action,
                'data': result.data
              });
            }
          } else {
            if (mounted) SnackbarService().showError(context, message);
          }
        }
      }
    } catch (e) {
      debugLog('PaymentScreen', 'Payment error: $e');
      if (mounted) {
        SnackbarService()
            .showError(context, '${AppStrings.paymentFailed}: ${e.toString()}');
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
                Text(AppStrings.instructions,
                    style: AppTextStyles.titleSmall(context)),
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
            Text(AppStrings.importantNotes,
                style: AppTextStyles.labelMedium(context)
                    .copyWith(fontWeight: FontWeight.w600)),
            SizedBox(height: ResponsiveValues.spacingS(context)),
            _buildNoteItem(AppStrings.noteAccountHolderMatch),
            _buildNoteItem(AppStrings.noteProcessingTime),
            _buildNoteItem(AppStrings.noteKeepProof),
            _buildNoteItem(AppStrings.noteContactSupport),
            _buildNoteItem(AppStrings.noteNotification),
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
      title:
          Text(AppStrings.payment, style: AppTextStyles.appBarTitle(context)),
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
            title: AppStrings.paymentError,
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
          dataType: AppStrings.paymentMethods,
          customMessage: AppStrings.paymentMethodsNotAvailable,
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

  Widget _buildMobileLayout(BuildContext context, List<PaymentMethod> methods) {
    if (_hasError) return _buildErrorState();
    if (_isLoadingMethods) return _buildSkeletonLoader();
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
              // Pending count banner (if offline with pending actions)
              if (_isOffline && _pendingCount > 0)
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
                      Icon(Icons.schedule_rounded,
                          color: AppColors.info,
                          size: ResponsiveValues.iconSizeS(context)),
                      SizedBox(width: ResponsiveValues.spacingM(context)),
                      Expanded(
                        child: Text(
                          '$_pendingCount pending action${_pendingCount > 1 ? 's' : ''}',
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
                  // Pending count banner (if offline with pending actions)
                  if (_isOffline && _pendingCount > 0)
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
                          Icon(Icons.schedule_rounded,
                              color: AppColors.info,
                              size: ResponsiveValues.iconSizeS(context)),
                          SizedBox(width: ResponsiveValues.spacingM(context)),
                          Expanded(
                            child: Text(
                              '$_pendingCount pending action${_pendingCount > 1 ? 's' : ''}',
                              style: AppTextStyles.bodySmall(context)
                                  .copyWith(color: AppColors.info),
                            ),
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

    // 1. LOADING STATE
    if (_isLoadingMethods) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: _buildAppBar(context),
        body: _buildSkeletonLoader(),
      );
    }

    // 2. ERROR STATE
    if (_hasError) return _buildErrorState();

    // 3. NO CATEGORY STATE
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
                AppStrings.loadingPaymentDetails,
                style: AppTextStyles.bodyMedium(context)
                    .copyWith(color: AppColors.getTextSecondary(context)),
              ),
            ],
          ),
        ),
      );
    }

    // 4. MAIN CONTENT
    return ResponsiveLayout(
      mobile: _buildMobileLayout(context, methods),
      tablet: _buildDesktopLayout(context, methods),
      desktop: _buildDesktopLayout(context, methods),
    ).animate().fadeIn(duration: AppThemes.animationMedium);
  }
}

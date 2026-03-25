import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../models/category_model.dart';
import '../../providers/payment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/category_provider.dart';
import '../../services/device_service.dart';
import '../../services/snackbar_service.dart';
import '../../services/offline_queue_manager.dart';
import '../../services/user_session.dart';
import '../../widgets/common/base_screen_mixin.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';
import '../../utils/responsive_values.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/helpers.dart';
import '../../utils/constants.dart';

class PaymentScreen extends StatefulWidget {
  final Map<String, dynamic>? extra;
  const PaymentScreen({super.key, this.extra});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with BaseScreenMixin<PaymentScreen>, TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _accountHolderNameController = TextEditingController();
  final _picker = ImagePicker();

  PaymentMethod? _selectedPaymentMethod;
  File? _proofImageFile;
  bool _confirmAccuracy = false;
  bool _hasError = false;
  bool _isLoadingMethods = true;
  bool _isSubmittingPayment = false;
  String _errorMessage = '';
  String _submitStatusMessage = '';
  Category? _category;
  String _username = '';
  double _amount = 0.0;
  String _billingCycle = 'monthly';
  String _paymentType = 'first_time';
  int _monthsToAdd = 1;

  bool _initialized = false;
  bool _queuedFallbackTriggered = false;
  bool _settingsLoadAttempted = false;
  List<PaymentMethod> _cachedMethods = [];
  String? _currentUserId;

  late AuthProvider _authProvider;
  late PaymentProvider _paymentProvider;
  late SettingsProvider _settingsProvider;
  late SubscriptionProvider _subscriptionProvider;
  late CategoryProvider _categoryProvider;
  late DeviceService _deviceService;
  late OfflineQueueManager _queueManager;

  @override
  String get screenTitle => AppStrings.payment;

  @override
  String? get screenSubtitle =>
      _category?.name ?? AppStrings.completeYourPayment;

  @override
  bool get isLoading => _isLoadingMethods && _cachedMethods.isEmpty;

  @override
  bool get hasCachedData => _cachedMethods.isNotEmpty;

  @override
  dynamic get errorMessage => _hasError ? _errorMessage : null;

  @override
  ShimmerType get shimmerType => ShimmerType.paymentCard;

  @override
  int get shimmerItemCount => 5;

  @override
  Widget? get appBarLeading => IconButton(
        icon: Icon(Icons.arrow_back_rounded,
            color: AppColors.getTextPrimary(context)),
        onPressed: () => context.pop(),
      );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _authProvider = Provider.of<AuthProvider>(context);
    _paymentProvider = Provider.of<PaymentProvider>(context);
    _settingsProvider = Provider.of<SettingsProvider>(context);
    _subscriptionProvider = Provider.of<SubscriptionProvider>(context);
    _categoryProvider = Provider.of<CategoryProvider>(context);
    _deviceService = Provider.of<DeviceService>(context);
    _queueManager = Provider.of<OfflineQueueManager>(context);

    _getCurrentUserId();
    _initializeData();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _accountHolderNameController.dispose();
    super.dispose();
  }

  @override
  Future<void> onRefresh() async {
    await _loadPaymentMethods(forceRefresh: true);
  }

  Future<void> _getCurrentUserId() async {
    _currentUserId = _authProvider.currentUser?.id.toString();
  }

  Future<void> _loadCachedPaymentMethods() async {
    try {
      final cachedMethods = await _deviceService.getCacheItem<List<dynamic>>(
        'payment_methods_$_currentUserId',
        isUserSpecific: true,
      );

      if (cachedMethods != null && isMounted) {
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

  String _resolvePaymentType({
    Category? category,
    int? categoryId,
    String? requestedType,
  }) {
    final resolvedCategoryId = category?.id ?? categoryId;
    final hasExpiredSubscription = resolvedCategoryId != null &&
        _subscriptionProvider.expiredSubscriptions
            .any((sub) => sub.categoryId == resolvedCategoryId);

    if (hasExpiredSubscription) {
      return 'repayment';
    }

    return requestedType ?? 'first_time';
  }

  void _initializeData() {
    if (_initialized) return;

    try {
      final args = widget.extra;
      if (args == null) {
        if (isOffline) {
          _loadCachedPaymentMethods();
        }
        setState(() {
          _hasError = true;
          _errorMessage = AppStrings.noPaymentDataProvided;
        });
        return;
      }

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
            category = _categoryProvider.getCategoryById(categoryId);
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

      _monthsToAdd = _settingsProvider.getBillingCycleMonths(
        category.billingCycle,
      );

      setState(() {
        _username = _authProvider.currentUser?.username ?? '';
        _amount = category?.price ?? 0.0;
        _billingCycle = category!.billingCycle;
        _category = category;
        _paymentType = _resolvePaymentType(
          category: category,
          categoryId: args['categoryId'] as int?,
          requestedType: args['paymentType']?.toString(),
        );
        _hasError = false;
        _cachedMethods = _settingsProvider.getPaymentMethods();
        _isLoadingMethods = _cachedMethods.isEmpty;
        _initialized = true;
      });

      if (_cachedMethods.isEmpty) {
        unawaited(_loadCachedPaymentMethods());
      }

      _loadPaymentMethods();
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = '${AppStrings.failedToInitialize}: $e';
      });
    }
  }

  Future<void> _loadPaymentMethods({bool forceRefresh = false}) async {
    if (_settingsLoadAttempted && !forceRefresh) return;
    _settingsLoadAttempted = true;

    if (_settingsProvider.allSettings.isEmpty && _cachedMethods.isEmpty) {
      await _loadCachedPaymentMethods();
    }

    if (_settingsProvider.allSettings.isEmpty && !isOffline) {
      await _settingsProvider.getAllSettings();
    }

    final freshMethods = _settingsProvider.getPaymentMethods();
    if (freshMethods.isNotEmpty) {
      _cachedMethods = freshMethods;
    }

    if (_cachedMethods.isNotEmpty && _currentUserId != null && !isOffline) {
      try {
        _deviceService.saveCacheItem(
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

    if (isMounted) setState(() => _isLoadingMethods = false);
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
    return _settingsProvider.getBillingCycleDescription(_billingCycle);
  }

  String _getAccessDurationText() {
    return _settingsProvider.getBillingCycleDurationText(_billingCycle);
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
        Text(
          AppStrings.paymentMethod,
          style: AppTextStyles.labelMedium(context),
        ),
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
                        width: ResponsiveValues.iconSizeL(context),
                        height: ResponsiveValues.iconSizeL(context),
                        decoration: BoxDecoration(
                          color: AppColors.telegramBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            ResponsiveValues.radiusSmall(context),
                          ),
                        ),
                        child: Icon(
                          method.iconData,
                          size: ResponsiveValues.iconSizeXS(context),
                          color: AppColors.telegramBlue,
                        ),
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
              onChanged: !isOffline
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
                        style: AppTextStyles.labelMedium(context).copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: ResponsiveValues.spacingM(context)),
                  Container(
                    padding: ResponsiveValues.cardPadding(context),
                    decoration: BoxDecoration(
                      color:
                          AppColors.getSurface(context).withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusSmall(context),
                      ),
                      border: Border.all(
                        color: AppColors.getDivider(context)
                            .withValues(alpha: 0.16),
                      ),
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
                              text: _selectedPaymentMethod!.accountInfo,
                            ));
                            SnackbarService().showSuccess(
                              context,
                              AppStrings.copiedToClipboard,
                            );
                          },
                          child: Container(
                            padding: EdgeInsets.all(
                                ResponsiveValues.spacingXXS(context)),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.telegramBlue.withValues(alpha: 0.1),
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
                  SizedBox(height: ResponsiveValues.spacingM(context)),
                  Text(
                    AppStrings.instructions,
                    style: AppTextStyles.labelSmall(context).copyWith(
                      color: AppColors.getTextSecondary(context),
                    ),
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
      onTap: isOffline ? null : _pickImage,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
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
                ? (isOffline
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
                            color:
                                AppColors.telegramRed.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(
                              ResponsiveValues.radiusFull(context),
                            ),
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
                          color:
                              AppColors.telegramGreen.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(
                            ResponsiveValues.radiusFull(context),
                          ),
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
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isOffline
                        ? Icons.wifi_off_rounded
                        : Icons.cloud_upload_rounded,
                    size: ResponsiveValues.iconSizeXXL(context),
                    color: isOffline
                        ? AppColors.warning
                        : AppColors.getTextSecondary(context),
                  ),
                  SizedBox(height: ResponsiveValues.spacingM(context)),
                  Text(
                    isOffline
                        ? AppStrings.offlineWillQueue
                        : AppStrings.tapToUploadProof,
                    style: AppTextStyles.bodyMedium(context).copyWith(
                      color: isOffline
                          ? AppColors.warning
                          : AppColors.getTextPrimary(context),
                    ),
                  ),
                  SizedBox(height: ResponsiveValues.spacingXS(context)),
                  Text(
                    isOffline
                        ? AppStrings.connectToInternet
                        : AppStrings.imageRequirements,
                    style: AppTextStyles.caption(context).copyWith(
                      color: isOffline
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
              style: AppTextStyles.bodySmall(context).copyWith(
                color: AppColors.getTextSecondary(context),
              ),
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
                  width: ResponsiveValues.featureCardIconContainerSize(context),
                  height:
                      ResponsiveValues.featureCardIconContainerSize(context),
                  decoration: BoxDecoration(
                    color: AppColors.telegramBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(
                      ResponsiveValues.radiusMedium(context),
                    ),
                  ),
                  child: const Icon(Icons.payment_rounded,
                      color: AppColors.telegramBlue, size: 24),
                ),
                SizedBox(width: ResponsiveValues.spacingL(context)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _category?.name ?? AppStrings.payment,
                        style: AppTextStyles.titleMedium(context),
                      ),
                      SizedBox(height: ResponsiveValues.spacingXS(context)),
                      Text(
                        _paymentType == 'first_time'
                            ? AppStrings.firstTimePayment
                            : AppStrings.renewalPayment,
                        style: AppTextStyles.bodySmall(context).copyWith(
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
                      _amount.toStringAsFixed(0),
                      style: AppTextStyles.headlineSmall(context).copyWith(
                        color: AppColors.telegramBlue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      AppStrings.currencyLabel,
                      style: AppTextStyles.labelMedium(context).copyWith(
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: ResponsiveValues.spacingL(context)),
            Divider(
              color: AppColors.getDivider(context).withValues(alpha: 0.2),
              height: 1,
            ),
            SizedBox(height: ResponsiveValues.spacingL(context)),
            _buildSummaryRow(
              icon: Icons.category_rounded,
              label: AppStrings.category,
              value: _category?.name ?? AppStrings.notAvailable,
            ),
            SizedBox(height: ResponsiveValues.spacingS(context)),
            _buildSummaryRow(
              icon: Icons.calendar_today_rounded,
              label: AppStrings.billingCycle,
              value: _getBillingCycleDescription(),
            ),
            SizedBox(height: ResponsiveValues.spacingS(context)),
            _buildSummaryRow(
              icon: Icons.timer_rounded,
              label: AppStrings.accessDuration,
              value: _getAccessDurationText(),
            ),
            SizedBox(height: ResponsiveValues.spacingS(context)),
            _buildSummaryRow(
              icon: Icons.person_rounded,
              label: AppStrings.username,
              value: _username,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required String label,
    required String value,
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
              Text(
                AppStrings.paymentDetails,
                style: AppTextStyles.titleMedium(context),
              ),
              SizedBox(height: ResponsiveValues.spacingL(context)),
              _buildPaymentMethodDropdown(methods),
              SizedBox(height: ResponsiveValues.spacingL(context)),
              AppTextField(
                controller: _accountHolderNameController,
                label: AppStrings.accountHolderName,
                hint: AppStrings.enterAccountHolderName,
                prefixIcon: Icons.person_outline_rounded,
                enabled: !isOffline,
                validator: _validateAccountHolderName,
                requiresOnline: true,
              ),
              SizedBox(height: ResponsiveValues.spacingL(context)),
              AppTextField.password(
                controller: _passwordController,
                label: AppStrings.password,
                hint: AppStrings.enterPassword,
                enabled: !isOffline,
                validator: _validatePassword,
                requiresOnline: true,
              ),
              SizedBox(height: ResponsiveValues.spacingL(context)),
              Text(
                AppStrings.paymentProof,
                style: AppTextStyles.labelMedium(context),
              ),
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
                      onChanged: isOffline
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
                  SizedBox(width: ResponsiveValues.spacingM(context)),
                  Expanded(
                    child: Text(
                      AppStrings.confirmAccuracy,
                      style: AppTextStyles.bodyMedium(context).copyWith(
                        color: isOffline
                            ? AppColors.getTextSecondary(context)
                                .withValues(alpha: 0.5)
                            : AppColors.getTextPrimary(context),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: ResponsiveValues.spacingXL(context)),
              if (_isSubmittingPayment) ...[
                Container(
                  width: double.infinity,
                  padding: ResponsiveValues.cardPadding(context),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(
                      ResponsiveValues.radiusMedium(context),
                    ),
                    border: Border.all(
                      color: AppColors.info.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: ResponsiveValues.iconSizeM(context),
                        height: ResponsiveValues.iconSizeM(context),
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(AppColors.info),
                        ),
                      ),
                      SizedBox(width: ResponsiveValues.spacingM(context)),
                      Expanded(
                        child: Text(
                          _submitStatusMessage.isNotEmpty
                              ? _submitStatusMessage
                              : 'Processing your payment. Please wait...',
                          style: AppTextStyles.bodyMedium(context).copyWith(
                            color: AppColors.info,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: ResponsiveValues.spacingL(context)),
              ],
              SizedBox(
                width: double.infinity,
                child: AppButton.primary(
                  label: _isSubmittingPayment
                      ? 'Processing Payment...'
                      : (isOffline
                          ? AppStrings.queuePayment
                          : AppStrings.submitPayment),
                  onPressed: _isSubmittingPayment ? null : _submitPayment,
                  icon: isOffline ? Icons.schedule_rounded : Icons.send_rounded,
                  isLoading: _isSubmittingPayment,
                  expanded: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitPayment() async {
    if (_isSubmittingPayment) return;

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

    setState(() {
      _isSubmittingPayment = true;
      _queuedFallbackTriggered = false;
      _submitStatusMessage = isOffline
          ? 'Saving your payment for sync'
          : 'Uploading your payment proof';
    });

    try {
      final paymentMethod = _selectedPaymentMethod!.method;
      String? proofImageUrl;

      // ✅ Always try to upload first if online
      if (!isOffline) {
        try {
          if (isMounted) {
            setState(() {
              _submitStatusMessage = 'Uploading your payment proof';
            });
          }

          // ✅ Add timeout to upload
          final uploadResponse = await _paymentProvider
              .uploadPaymentProof(_proofImageFile!)
              .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              debugLog('PaymentScreen', 'Upload timeout - queuing payment');
              throw TimeoutException('Upload timed out');
            },
          );

          if (uploadResponse.success && uploadResponse.data != null) {
            proofImageUrl = uploadResponse.data;
            debugLog('PaymentScreen', '✅ Upload successful: $proofImageUrl');
          } else {
            debugLog(
                'PaymentScreen', '❌ Upload failed: ${uploadResponse.message}');
            throw Exception(uploadResponse.message);
          }
        } catch (uploadError) {
          debugLog('PaymentScreen', 'Upload error: $uploadError');

          // ✅ On upload timeout or failure, FALL BACK TO OFFLINE QUEUE
          SnackbarService().showInfo(
            context,
            'This is taking a little longer than expected. Your payment will be saved and synced automatically.',
          );

          // Save to offline queue
          await _queuePaymentOffline(
            categoryId: _category!.id,
            paymentType: _paymentType,
            paymentMethod: paymentMethod,
            amount: _amount,
            accountHolderName: _accountHolderNameController.text.trim(),
            proofImagePath: _proofImageFile!.path,
          );

          if (isMounted) {
            _queuedFallbackTriggered = true;
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
              'account_holder_name': _accountHolderNameController.text.trim(),
              'timestamp': DateTime.now().toIso8601String(),
              'queued': true,
            });
          }
          return;
        }
      }

      final accountHolderName = _accountHolderNameController.text.trim();

      if (isOffline) {
        await _queuePaymentOffline(
          categoryId: _category!.id,
          paymentType: _paymentType,
          paymentMethod: paymentMethod,
          amount: _amount,
          accountHolderName:
              accountHolderName.isNotEmpty ? accountHolderName : null,
          proofImagePath: _proofImageFile!.path,
        );

        if (isMounted) {
          _queuedFallbackTriggered = true;
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
        return;
      }

      // ✅ Online submission with proof URL
      if (isMounted) {
        setState(() {
          _submitStatusMessage = 'Submitting your payment';
        });
      }

      final result = await _paymentProvider
          .submitPayment(
        categoryId: _category!.id,
        paymentType: _paymentType,
        paymentMethod: paymentMethod,
        amount: _amount,
        accountHolderName:
            accountHolderName.isNotEmpty ? accountHolderName : null,
        proofImagePath: proofImageUrl,
      )
          .timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          debugLog('PaymentScreen', 'Payment submission timeout - queuing');
          throw TimeoutException('Payment submission timed out');
        },
      );

      if (result.success && result.data != null) {
        await _subscriptionProvider.refreshAfterPaymentVerification();
        await _authProvider.checkSession();

        if (isMounted) {
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
          if (isMounted) {
            await context.push('/device-change', extra: {
              'message': message,
              'action': action,
              'data': result.data,
            });
          }
        } else if (message.toLowerCase().contains('pending')) {
          SnackbarService().showInfo(
            context,
            'You already have a pending payment for this category.',
          );
          if (isMounted) {
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
          SnackbarService().showError(context, message);
        }
      }
    } catch (e) {
      debugLog('PaymentScreen', 'Payment error: $e');

      final errorText = e.toString().toLowerCase();
      final shouldQueueAsOfflineFallback = !isOffline &&
          !_queuedFallbackTriggered &&
          (errorText.contains('timeout') ||
              errorText.contains('socket') ||
              errorText.contains('connection') ||
              errorText.contains('network'));

      if (shouldQueueAsOfflineFallback) {
        SnackbarService().showInfo(
          context,
          'Network issue detected. Saving payment for later sync...',
        );

        await _queuePaymentOffline(
          categoryId: _category!.id,
          paymentType: _paymentType,
          paymentMethod: _selectedPaymentMethod!.method,
          amount: _amount,
          accountHolderName: _accountHolderNameController.text.trim(),
          proofImagePath: _proofImageFile!.path,
        );

        if (isMounted) {
          await context.push('/payment-success', extra: {
            'category': _category,
            'category_id': _category!.id,
            'category_name': _category!.name,
            'payment_type': _paymentType,
            'payment_method': _selectedPaymentMethod!.method,
            'payment_method_name': _selectedPaymentMethod!.name,
            'amount': _amount,
            'billing_cycle': _billingCycle,
            'months': _monthsToAdd,
            'duration_text': _getAccessDurationText(),
            'username': _username,
            'account_holder_name': _accountHolderNameController.text.trim(),
            'timestamp': DateTime.now().toIso8601String(),
            'queued': true,
          });
        }
        return;
      }

      if (isMounted) {
        SnackbarService().showError(
          context,
          'We could not finish your payment just now. Please try again in a moment.',
        );
      }
    } finally {
      if (isMounted) {
        setState(() {
          _isSubmittingPayment = false;
          _submitStatusMessage = '';
        });
      }
    }
  }

  Future<void> _queuePaymentOffline({
    required int categoryId,
    required String paymentType,
    required String paymentMethod,
    required double amount,
    String? accountHolderName,
    String? proofImagePath,
  }) async {
    try {
      final userId = await UserSession().getCurrentUserId();
      if (userId == null) return;

      // Save the image file locally for later upload
      String? savedImagePath;
      if (proofImagePath != null) {
        final imageFile = File(proofImagePath);
        if (await imageFile.exists()) {
          final appDocDir = await getApplicationDocumentsDirectory();
          final paymentDir = Directory('${appDocDir.path}/pending_payments');
          if (!await paymentDir.exists()) {
            await paymentDir.create(recursive: true);
          }
          final fileName =
              'payment_${DateTime.now().millisecondsSinceEpoch}.jpg';
          savedImagePath = '${paymentDir.path}/$fileName';
          await imageFile.copy(savedImagePath);
          debugLog('PaymentScreen', '📁 Saved image locally: $savedImagePath');
        }
      }

      _queueManager.addItem(
        type: AppConstants.queueActionSubmitPayment,
        data: {
          'categoryId': categoryId,
          'paymentType': paymentType,
          'paymentMethod': paymentMethod,
          'amount': amount,
          'accountHolderName': accountHolderName,
          'proofImagePath': savedImagePath,
          'userId': userId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      // Cache payment data for success screen
      _deviceService.saveCacheItem(
        'last_payment_data',
        {
          'categoryId': categoryId,
          'paymentType': paymentType,
          'paymentMethod': paymentMethod,
          'paymentMethodName': _selectedPaymentMethod?.name,
          'categoryName': _category?.name,
          'amount': amount,
          'billingCycle': _billingCycle,
          'durationText': _getAccessDurationText(),
          'username': _username,
          'accountHolderName': accountHolderName,
          'queued': true,
        },
        ttl: const Duration(days: 1),
      );

      debugLog('PaymentScreen', '📝 Queued payment for offline sync');
    } catch (e) {
      debugLog('PaymentScreen', 'Error queueing payment: $e');
    }
  }

  Widget _buildPaymentInstructions() {
    final instructions = _settingsProvider.getPaymentInstructions();

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
                SizedBox(width: ResponsiveValues.spacingM(context)),
                Text(
                  AppStrings.instructions,
                  style: AppTextStyles.titleSmall(context),
                ),
              ],
            ),
            SizedBox(height: ResponsiveValues.spacingL(context)),
            Divider(
              color: AppColors.getDivider(context).withValues(alpha: 0.2),
              height: 1,
            ),
            SizedBox(height: ResponsiveValues.spacingL(context)),
            Text(
              instructions,
              style: AppTextStyles.bodyMedium(context).copyWith(
                color: AppColors.getTextSecondary(context),
                height: 1.6,
              ),
            ),
            SizedBox(height: ResponsiveValues.spacingL(context)),
            Divider(
              color: AppColors.getDivider(context).withValues(alpha: 0.2),
              height: 1,
            ),
            SizedBox(height: ResponsiveValues.spacingL(context)),
            Text(
              AppStrings.importantNotes,
              style: AppTextStyles.labelMedium(context).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: ResponsiveValues.spacingS(context)),
            ..._settingsProvider.getPaymentImportantNotes().map(_buildNoteItem),
          ],
        ),
      ),
    );
  }

  @override
  Widget buildContent(BuildContext context) {
    if (_hasError) {
      return Center(
        child: buildErrorWidget(_errorMessage, onRetry: () => context.pop()),
      );
    }

    if (isLoading && !hasCachedData) {
      return buildLoadingShimmer();
    }

    if (_cachedMethods.isEmpty) {
      return Center(
        child: buildEmptyWidget(
          dataType: AppStrings.paymentMethods,
          customMessage:
              _settingsProvider.getPaymentMethodsUnavailableMessage(),
          isOffline: isOffline,
        ),
      );
    }

    if (_category == null) {
      return Center(
        child: Column(
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
            SizedBox(height: ResponsiveValues.spacingL(context)),
            Text(
              AppStrings.loadingPaymentDetails,
              style: AppTextStyles.bodyMedium(context).copyWith(
                color: AppColors.getTextSecondary(context),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: ResponsiveValues.screenPadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPaymentSummary(),
            SizedBox(height: ResponsiveValues.spacingXL(context)),
            _buildPaymentForm(_cachedMethods),
            SizedBox(height: ResponsiveValues.spacingXL(context)),
            _buildPaymentInstructions(),
            SizedBox(height: ResponsiveValues.spacingXXL(context)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return buildScreen(
      content: buildContent(context),
    );
  }
}

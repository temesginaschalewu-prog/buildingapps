import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../models/setting_model.dart';
import '../utils/helpers.dart';
import '../utils/constants.dart';

class SettingsProvider with ChangeNotifier {
  final ApiService apiService;
  final DeviceService deviceService;

  List<Setting> _allSettings = [];
  Map<String, Setting> _settingsMap = {};
  Map<String, List<Setting>> _settingsByCategory = {};
  bool _isLoading = false;
  String? _error;

  // Track last load time per category
  final Map<String, DateTime> _lastCategoryLoadTime = {};
  static const Duration _categoryLoadMinInterval = Duration(minutes: 5);

  // Prevent duplicate loads
  final Map<String, Completer<bool>> _ongoingLoads = {};

  StreamController<List<Setting>> _settingsUpdateController =
      StreamController<List<Setting>>.broadcast();

  SettingsProvider({required this.apiService, required this.deviceService});

  List<Setting> get allSettings => List.unmodifiable(_allSettings);
  Map<String, List<Setting>> get settingsByCategory =>
      Map.unmodifiable(_settingsByCategory);
  bool get isLoading => _isLoading;
  String? get error => _error;
  Stream<List<Setting>> get settingsUpdates => _settingsUpdateController.stream;

  List<Setting> getSettingsByCategory(String category) {
    return List.unmodifiable(_settingsByCategory[category] ?? []);
  }

  Setting? getSettingByKey(String key) {
    return _settingsMap[key];
  }

  String? getSettingValue(String key) {
    return _settingsMap[key]?.settingValue;
  }

  String? getSettingDisplayName(String key) {
    return _settingsMap[key]?.displayName;
  }

  bool _shouldLoadCategory(String category, {bool forceRefresh = false}) {
    if (forceRefresh) return true;

    final lastLoad = _lastCategoryLoadTime[category];
    if (lastLoad == null) return true;

    final minutesSinceLastLoad = DateTime.now().difference(lastLoad).inMinutes;
    return minutesSinceLastLoad >= 5; // Only load every 5 minutes minimum
  }

  List<PaymentMethod> getPaymentMethods() {
    final methods = <PaymentMethod>[];

    debugLog('SettingsProvider', '🔄 Scanning for payment methods...');
    debugLog('SettingsProvider', 'Settings map size: ${_settingsMap.length}');
    debugLog(
        'SettingsProvider', 'Total settings loaded: ${_allSettings.length}');

    // If settings are empty, try to load them
    if (_allSettings.isEmpty) {
      debugLog('SettingsProvider',
          '⚠️ No settings loaded yet, attempting to load...');
      getAllSettings(); // Load async
      // Return empty for now, UI should retry or show loading
      return methods;
    }

    debugLog(
        'SettingsProvider', 'Available setting keys: ${_settingsMap.keys}');

    // Check if payment_methods_enabled exists
    final enabledValue = getSettingValue('payment_methods_enabled');
    debugLog('SettingsProvider',
        'Payment methods enabled setting value: "$enabledValue"');

    // Default to true if setting doesn't exist
    bool methodsEnabled;
    if (enabledValue == null) {
      debugLog('SettingsProvider',
          '⚠️ payment_methods_enabled not found, defaulting to true');
      methodsEnabled = true;
    } else {
      // Handle both string "true"/"false" and boolean true/false
      if (enabledValue is bool) {
        methodsEnabled = enabledValue as bool;
      } else {
        methodsEnabled = enabledValue.toString().toLowerCase() == 'true';
      }
    }

    if (!methodsEnabled) {
      debugLog(
          'SettingsProvider', '⚠️ Payment methods are disabled in settings');
      return methods;
    }

    debugLog('SettingsProvider', '✅ Payment methods are enabled, scanning...');

    final methodKeys = <String>{};

    // Scan for payment method configurations
    for (final setting in _allSettings) {
      final key = setting.settingKey;
      if (key.startsWith('payment_method_') && key.endsWith('_name')) {
        final methodKey = key.substring(
            'payment_method_'.length, key.length - '_name'.length);
        methodKeys.add(methodKey);
        debugLog('SettingsProvider',
            'Found payment method key: $methodKey from $key');
      }
    }

    debugLog('SettingsProvider',
        'Found ${methodKeys.length} payment method keys: $methodKeys');

    // If no methods found in settings, use defaults
    if (methodKeys.isEmpty) {
      debugLog('SettingsProvider',
          '⚠️ No payment methods found in settings, using defaults');
      methods.addAll(_getDefaultPaymentMethods());
    } else {
      // Process each payment method
      for (final methodKey in methodKeys) {
        final nameKey = 'payment_method_${methodKey}_name';
        final numberKey = 'payment_method_${methodKey}_number';
        final instructionsKey = 'payment_method_${methodKey}_instructions';

        final methodName = getSettingValue(nameKey);
        final methodNumber = getSettingValue(numberKey);
        final methodInstructions = getSettingValue(instructionsKey);

        debugLog('SettingsProvider',
            'Method $methodKey: name="$methodName", number="$methodNumber", instructions="$methodInstructions"');

        if (methodName != null &&
            methodName.isNotEmpty &&
            methodNumber != null &&
            methodNumber.isNotEmpty) {
          methods.add(PaymentMethod(
            method: methodKey,
            name: methodName,
            accountInfo: methodNumber,
            instructions:
                methodInstructions ?? 'Make payment to the provided account',
            iconData: _getPaymentMethodIcon(methodKey, methodName),
          ));
          debugLog('SettingsProvider', '✅ Added payment method: $methodName');
        } else {
          debugLog('SettingsProvider',
              '⚠️ Skipping $methodKey: Missing name or number');
        }
      }
    }

    // Add legacy payment methods if they exist
    _addLegacyPaymentMethods(methods);

    debugLog(
        'SettingsProvider', 'Total payment methods found: ${methods.length}');

    // Sort by name for consistent display
    methods.sort((a, b) => a.name.compareTo(b.name));

    return methods;
  }

  List<PaymentMethod> _getDefaultPaymentMethods() {
    return [
      PaymentMethod(
        method: 'telebirr',
        name: 'Telebirr',
        accountInfo: '+251911223344',
        instructions: 'Send payment via Telebirr to the number above',
        iconData: Icons.phone_android,
      ),
      PaymentMethod(
        method: 'cbe',
        name: 'CBE Bank',
        accountInfo: '100034567890',
        instructions: 'Make transfer to CBE account above',
        iconData: Icons.account_balance,
      ),
      PaymentMethod(
        method: 'bank',
        name: 'Bank Transfer',
        accountInfo: 'Commercial Bank of Ethiopia\nAccount: 200034567890',
        instructions: 'Make transfer to the bank account above',
        iconData: Icons.account_balance_wallet,
      ),
    ];
  }

  void _addLegacyPaymentMethods(List<PaymentMethod> methods) {
    // Check for old-style payment settings and add them
    final oldTelebirrNumber = getSettingValue('payment_telebirr_number');
    if (oldTelebirrNumber != null &&
        oldTelebirrNumber.isNotEmpty &&
        !methods.any((m) =>
            m.method == 'telebirr' ||
            m.name.toLowerCase().contains('telebirr'))) {
      final oldTelebirrName =
          getSettingValue('payment_telebirr_name') ?? 'Telebirr';
      methods.add(PaymentMethod(
        method: 'telebirr',
        name: oldTelebirrName,
        accountInfo: oldTelebirrNumber,
        instructions: 'Send payment via Telebirr to the number above',
        iconData: Icons.phone_android,
      ));
      debugLog('SettingsProvider', '✅ Added legacy telebirr payment method');
    }

    final oldBankName = getSettingValue('payment_bank_name');
    final oldBankNumber = getSettingValue('payment_account_number');
    if (oldBankName != null &&
        oldBankName.isNotEmpty &&
        oldBankNumber != null &&
        oldBankNumber.isNotEmpty &&
        !methods.any((m) =>
            m.method == 'bank' || m.name.toLowerCase().contains('bank'))) {
      methods.add(PaymentMethod(
        method: 'bank',
        name: oldBankName,
        accountInfo: oldBankNumber,
        instructions: getSettingValue('payment_instructions') ??
            'Make transfer to the bank account above',
        iconData: Icons.account_balance,
      ));
      debugLog('SettingsProvider', '✅ Added legacy bank payment method');
    }
  }

  IconData _getPaymentMethodIcon(String methodKey, String displayName) {
    final method = methodKey.toLowerCase();
    final name = displayName.toLowerCase();

    if (method.contains('cbe') ||
        name.contains('cbe') ||
        name.contains('commercial')) {
      return Icons.account_balance;
    }
    if (method.contains('awash') || name.contains('awash')) {
      return Icons.account_balance;
    }
    if (method.contains('dashen') || name.contains('dashen')) {
      return Icons.account_balance;
    }
    if (method.contains('telebirr') ||
        name.contains('telebirr') ||
        method.contains('birr') ||
        name.contains('birr') ||
        method.contains('phone') ||
        name.contains('phone') ||
        method.contains('mobile')) {
      return Icons.phone_android;
    }
    if (method.contains('bank') ||
        name.contains('bank') ||
        method.contains('transfer') ||
        name.contains('transfer')) {
      return Icons.account_balance;
    }
    if (method.contains('card') ||
        name.contains('card') ||
        method.contains('credit') ||
        name.contains('credit') ||
        method.contains('debit')) {
      return Icons.credit_card;
    }
    if (method.contains('cash') ||
        name.contains('cash') ||
        method.contains('money') ||
        name.contains('money')) {
      return Icons.money;
    }
    if (method.contains('crypto') ||
        name.contains('crypto') ||
        method.contains('bitcoin') ||
        name.contains('bitcoin') ||
        method.contains('ethereum')) {
      return Icons.currency_bitcoin;
    }
    if (method.contains('paypal') || name.contains('paypal')) {
      return Icons.payments;
    }

    return Icons.payment;
  }

  String getPaymentInstructions() {
    return getSettingValue(AppConstants.paymentInstructionsKey) ??
        'Please follow these steps to complete your payment:\n'
            '1. Select a payment method\n'
            '2. Make the payment using the provided account details\n'
            '3. Upload proof of payment\n'
            '4. Wait for admin verification (usually within 24 hours)\n'
            '5. Your access will be activated once verified';
  }

  bool isPaymentMethodConfigured(String methodKey) {
    final name = getSettingValue(
        '${AppConstants.paymentMethodPrefix}${methodKey}${AppConstants.paymentMethodNameSuffix}');
    final number = getSettingValue(
        '${AppConstants.paymentMethodPrefix}${methodKey}${AppConstants.paymentMethodNumberSuffix}');
    return name != null && number != null;
  }

  List<String> getConfiguredPaymentMethods() {
    final methods = <String>[];
    for (final setting in _allSettings) {
      final key = setting.settingKey;
      if (key.startsWith(AppConstants.paymentMethodPrefix) &&
          key.endsWith(AppConstants.paymentMethodNameSuffix)) {
        final methodName = key.substring(
            AppConstants.paymentMethodPrefix.length,
            key.length - AppConstants.paymentMethodNameSuffix.length);
        if (isPaymentMethodConfigured(methodName)) {
          methods.add(methodName);
        }
      }
    }
    return methods;
  }

  // UPDATED: Contact Information Methods with better logging and fallbacks
  String getSupportPhone() {
    final value = getSettingValue(AppConstants.contactSupportPhoneKey);
    debugLog('SettingsProvider', '📞 Support phone from settings: "$value"');
    return value ?? '+251 911 223 344';
  }

  String getSupportEmail() {
    final value = getSettingValue(AppConstants.contactSupportEmailKey);
    debugLog('SettingsProvider', '📧 Support email from settings: "$value"');
    return value ?? 'support@familyacademy.com';
  }

  String getOfficeAddress() {
    final value = getSettingValue(AppConstants.contactOfficeAddressKey);
    debugLog('SettingsProvider', '📍 Office address from settings: "$value"');
    return value ?? 'Addis Ababa, Ethiopia';
  }

  String getOfficeHours() {
    final value = getSettingValue(AppConstants.contactOfficeHoursKey);
    debugLog('SettingsProvider', '🕒 Office hours from settings: "$value"');
    return value ?? 'Monday - Friday: 9:00 AM - 5:00 PM';
  }

  String getWhatsAppNumber() {
    final value = getSettingValue(AppConstants.contactWhatsAppNumberKey);
    debugLog('SettingsProvider', '📱 WhatsApp from settings: "$value"');
    return value ?? '';
  }

  String getTelegramUsername() {
    final value = getSettingValue(AppConstants.contactTelegramUsernameKey);
    debugLog('SettingsProvider', '✈️ Telegram from settings: "$value"');
    return value ?? '';
  }

  // UPDATED: getContactInfoList with better logging
  List<ContactInfo> getContactInfoList() {
    final contacts = <ContactInfo>[];

    // Phone
    contacts.add(ContactInfo(
      type: ContactType.phone,
      title: 'Phone',
      value: getSupportPhone(),
      icon: Icons.phone,
    ));

    // Email
    contacts.add(ContactInfo(
      type: ContactType.email,
      title: 'Email',
      value: getSupportEmail(),
      icon: Icons.email,
    ));

    // WhatsApp (if you have it)
    final whatsapp = getWhatsAppNumber();
    if (whatsapp.isNotEmpty) {
      contacts.add(ContactInfo(
        type: ContactType.whatsapp,
        title: 'WhatsApp',
        value: whatsapp,
        icon: Icons.message,
      ));
    }

    // Telegram (if you have it)
    final telegram = getTelegramUsername();
    if (telegram.isNotEmpty) {
      contacts.add(ContactInfo(
        type: ContactType.telegram,
        title: 'Telegram',
        value: telegram,
        icon: Icons.telegram,
      ));
    }

    // Address
    contacts.add(ContactInfo(
      type: ContactType.address,
      title: 'Address',
      value: getOfficeAddress(),
      icon: Icons.location_on,
    ));

    // Hours
    contacts.add(ContactInfo(
      type: ContactType.hours,
      title: 'Office Hours',
      value: getOfficeHours(),
      icon: Icons.access_time,
    ));

    debugLog('SettingsProvider',
        '📞 Contact info list built: ${contacts.length} items');
    for (final info in contacts) {
      debugLog('SettingsProvider', '   - ${info.title}: "${info.value}"');
    }

    return contacts;
  }

  String getSystemVersion() {
    return getSettingValue(AppConstants.systemVersionKey) ?? '1.0.0';
  }

  String getAdminEmail() {
    return getSettingValue(AppConstants.adminEmailKey) ??
        'admin@familyacademy.com';
  }

  // UPDATED: getAllSettings with better error handling and logging
  Future<void> getAllSettings() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('SettingsProvider', '🔄 Loading all settings from backend...');

      // First check cache
      final cachedSettings =
          await deviceService.getCacheItem<List<Setting>>('all_settings');
      if (cachedSettings != null && cachedSettings.isNotEmpty) {
        _allSettings = cachedSettings;
        _rebuildMaps();
        _isLoading = false;
        _settingsUpdateController.add(_allSettings);
        debugLog('SettingsProvider',
            '✅ Loaded ${_allSettings.length} settings from cache');

        // Log what we loaded from cache
        final categories = _settingsByCategory.keys.toList();
        debugLog('SettingsProvider', '📊 Categories in cache: $categories');

        _notifySafely();

        // Still try to refresh from backend in background
        _refreshSettingsInBackground();
        return;
      }

      // Fetch from backend using the new /settings/all endpoint
      final response = await apiService.getAllSettings();

      if (response.success &&
          response.data != null &&
          response.data!.isNotEmpty) {
        _allSettings = response.data!;
        debugLog('SettingsProvider',
            '✅ Successfully loaded ${_allSettings.length} settings from backend');

        // Log categories found
        final categories = _allSettings.map((s) => s.category).toSet().toList();
        debugLog('SettingsProvider', '📊 Categories found: $categories');

        // Specifically check for contact settings
        final contactSettings =
            _allSettings.where((s) => s.category == 'contact').toList();
        debugLog('SettingsProvider',
            '📞 Contact settings found: ${contactSettings.length}');

        // Save to cache
        await deviceService.saveCacheItem('all_settings', _allSettings,
            ttl: const Duration(minutes: 30));
      } else {
        // No settings from backend, use defaults
        debugLog('SettingsProvider',
            '⚠️ No settings loaded from backend, using defaults');
        _allSettings = _getDefaultSettings();
      }

      _rebuildMaps();
      _settingsUpdateController.add(_allSettings);
    } catch (e, stackTrace) {
      _error = e.toString();
      debugLog('SettingsProvider', '❌ getAllSettings error: $e\n$stackTrace');

      // On error, use defaults
      _allSettings = _getDefaultSettings();
      _rebuildMaps();
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> _refreshSettingsInBackground() async {
    try {
      debugLog('SettingsProvider', '🔄 Background refresh of settings...');

      final response = await apiService.getAllSettings();

      if (response.success &&
          response.data != null &&
          response.data!.isNotEmpty) {
        _allSettings = response.data!;
        _rebuildMaps();
        _settingsUpdateController.add(_allSettings);

        await deviceService.saveCacheItem('all_settings', _allSettings,
            ttl: const Duration(minutes: 30));

        debugLog('SettingsProvider',
            '✅ Background refresh: Updated ${_allSettings.length} settings');
      }
    } catch (e) {
      // Ignore background refresh errors
      debugLog('SettingsProvider', '⚠️ Background refresh failed: $e');
    }
  }

  // UPDATED: loadContactSettings with better logic
  Future<void> loadContactSettings({bool? forceRefresh}) async {
    final shouldForce = forceRefresh ?? false;

    debugLog('SettingsProvider',
        '📞 Loading contact settings (force: $shouldForce)');

    // Check if we already have contact settings loaded from all settings
    if (!shouldForce &&
        _settingsByCategory.containsKey('contact') &&
        _settingsByCategory['contact']!.isNotEmpty) {
      debugLog('SettingsProvider',
          '✅ Using cached contact settings: ${_settingsByCategory['contact']!.length} items');
      return;
    }

    // Load all settings first (this will try /settings/all, then fallback to categories)
    if (_allSettings.isEmpty || shouldForce) {
      debugLog(
          'SettingsProvider', '📋 Loading all settings to get contact info');
      await getAllSettings();
    }

    // If contact settings still not found, log it
    if (!_settingsByCategory.containsKey('contact') ||
        _settingsByCategory['contact']!.isEmpty) {
      debugLog('SettingsProvider',
          '⚠️ No contact settings found in backend, will use fallback values');
    } else {
      debugLog('SettingsProvider',
          '✅ Contact settings loaded: ${_settingsByCategory['contact']!.length} items');
      // Log the actual values
      for (final setting in _settingsByCategory['contact']!) {
        debugLog('SettingsProvider',
            '   - ${setting.settingKey}: ${setting.settingValue}');
      }
    }
  }

  List<Setting> _getDefaultSettings() {
    // Combine payment and contact defaults
    final defaultSettings = <Setting>[];

    // Payment defaults
    defaultSettings.addAll(_getDefaultPaymentSettings());

    // Contact defaults
    defaultSettings.addAll([
      Setting(
        id: 100,
        settingKey: 'contact_support_phone',
        settingValue: '+251911223355',
        displayName: 'Support Phone',
        category: 'contact',
        dataType: 'string',
        isPublic: true,
        displayOrder: 1,
        description: 'Support phone number',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Setting(
        id: 101,
        settingKey: 'contact_support_email',
        settingValue: 'support@familyacademy.com',
        displayName: 'Support Email',
        category: 'contact',
        dataType: 'string',
        isPublic: true,
        displayOrder: 2,
        description: 'Support email address',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Setting(
        id: 102,
        settingKey: 'contact_office_address',
        settingValue: 'Addis Ababa, Ethiopia',
        displayName: 'Office Address',
        category: 'contact',
        dataType: 'string',
        isPublic: true,
        displayOrder: 3,
        description: 'Office physical address',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Setting(
        id: 103,
        settingKey: 'contact_office_hours',
        settingValue: 'Monday - Friday: 9:00 AM - 5:00 PM',
        displayName: 'Office Hours',
        category: 'contact',
        dataType: 'string',
        isPublic: true,
        displayOrder: 4,
        description: 'Office working hours',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Setting(
        id: 104,
        settingKey: 'contact_whatsapp_number',
        settingValue: '+251911223355',
        displayName: 'WhatsApp Number',
        category: 'contact',
        dataType: 'string',
        isPublic: true,
        displayOrder: 5,
        description: 'WhatsApp contact number',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Setting(
        id: 105,
        settingKey: 'contact_telegram_username',
        settingValue: '@familyacademy_support',
        displayName: 'Telegram Username',
        category: 'contact',
        dataType: 'string',
        isPublic: true,
        displayOrder: 6,
        description: 'Telegram username for support',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ]);

    return defaultSettings;
  }

  List<Setting> _getDefaultPaymentSettings() {
    return [
      Setting(
        id: 1,
        settingKey: 'payment_methods_enabled',
        settingValue: 'true',
        displayName: 'Payment Methods Enabled',
        category: 'payment',
        dataType: 'boolean',
        isPublic: true,
        displayOrder: 0,
        description: 'Enable/disable payment methods',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Setting(
        id: 2,
        settingKey: 'payment_method_telebirr_name',
        settingValue: 'Telebirr',
        displayName: 'Telebirr Name',
        category: 'payment',
        dataType: 'string',
        isPublic: true,
        displayOrder: 1,
        description: 'Telebirr payment method display name',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Setting(
        id: 3,
        settingKey: 'payment_method_telebirr_number',
        settingValue: '+251911223344',
        displayName: 'Telebirr Number',
        category: 'payment',
        dataType: 'string',
        isPublic: true,
        displayOrder: 2,
        description: 'Telebirr account number',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Setting(
        id: 4,
        settingKey: 'payment_method_telebirr_instructions',
        settingValue: 'Send payment via Telebirr to the number above',
        displayName: 'Telebirr Instructions',
        category: 'payment',
        dataType: 'string',
        isPublic: true,
        displayOrder: 3,
        description: 'Telebirr payment instructions',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Setting(
        id: 5,
        settingKey: 'payment_method_cbe_name',
        settingValue: 'CBE Bank',
        displayName: 'CBE Bank Name',
        category: 'payment',
        dataType: 'string',
        isPublic: true,
        displayOrder: 4,
        description: 'CBE Bank payment method display name',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Setting(
        id: 6,
        settingKey: 'payment_method_cbe_number',
        settingValue: '100034567890',
        displayName: 'CBE Account Number',
        category: 'payment',
        dataType: 'string',
        isPublic: true,
        displayOrder: 5,
        description: 'CBE Bank account number',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Setting(
        id: 7,
        settingKey: 'payment_method_cbe_instructions',
        settingValue: 'Make transfer to CBE account above',
        displayName: 'CBE Instructions',
        category: 'payment',
        dataType: 'string',
        isPublic: true,
        displayOrder: 6,
        description: 'CBE Bank payment instructions',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Setting(
        id: 8,
        settingKey: 'payment_method_bank_name',
        settingValue: 'Commercial Bank of Ethiopia',
        displayName: 'Bank Name',
        category: 'payment',
        dataType: 'string',
        isPublic: true,
        displayOrder: 7,
        description: 'Bank payment method display name',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Setting(
        id: 9,
        settingKey: 'payment_method_bank_number',
        settingValue: '200034567890',
        displayName: 'Bank Account Number',
        category: 'payment',
        dataType: 'string',
        isPublic: true,
        displayOrder: 8,
        description: 'Bank account number',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Setting(
        id: 10,
        settingKey: 'payment_method_bank_instructions',
        settingValue: 'Make transfer to the bank account above',
        displayName: 'Bank Instructions',
        category: 'payment',
        dataType: 'string',
        isPublic: true,
        displayOrder: 9,
        description: 'Bank payment instructions',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Setting(
        id: 11,
        settingKey: 'payment_instructions',
        settingValue:
            '1. Send payment to the account/telebirr number above\n2. Take screenshot of confirmation\n3. Upload screenshot in the payment section\n4. Wait for admin verification',
        displayName: 'Payment Instructions',
        category: 'payment',
        dataType: 'string',
        isPublic: true,
        displayOrder: 10,
        description: 'Instructions for making payments',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];
  }

  Future<void> loadSettingsByCategory(String category) async {
    if (_isLoading) return;

    // Check if we should load this category
    if (!_shouldLoadCategory(category)) {
      debugLog('SettingsProvider', '⏰ Using cached $category settings');
      return;
    }

    // Check if a load is already in progress
    if (_ongoingLoads.containsKey(category)) {
      debugLog('SettingsProvider', '⏳ $category load already in progress');
      await _ongoingLoads[category]!.future;
      return;
    }

    final completer = Completer<bool>();
    _ongoingLoads[category] = completer;

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('SettingsProvider', 'Loading settings for category: $category');

      final cacheKey = 'settings_category_$category';
      final cachedSettings =
          await deviceService.getCacheItem<List<Setting>>(cacheKey);
      if (cachedSettings != null) {
        _settingsByCategory[category] = cachedSettings;

        for (final setting in cachedSettings) {
          _settingsMap[setting.settingKey] = setting;
        }

        _isLoading = false;
        _lastCategoryLoadTime[category] = DateTime.now();
        completer.complete(true);
        debugLog('SettingsProvider',
            '✅ Loaded ${cachedSettings.length} $category settings from cache');
        return;
      }

      final response = await apiService.getSettingsByCategory(category);
      final categorySettings = response.data ?? [];

      _settingsByCategory[category] = categorySettings;

      for (final setting in categorySettings) {
        _settingsMap[setting.settingKey] = setting;
      }

      await deviceService.saveCacheItem(cacheKey, categorySettings,
          ttl: Duration(minutes: 30));

      _lastCategoryLoadTime[category] = DateTime.now();
      completer.complete(true);

      debugLog('SettingsProvider',
          '✅ Loaded ${categorySettings.length} $category settings');
    } catch (e) {
      _error = e.toString();
      debugLog('SettingsProvider', 'loadSettingsByCategory error: $e');
      completer.complete(false);
      rethrow;
    } finally {
      _isLoading = false;
      _ongoingLoads.remove(category);
      _notifySafely();
    }
  }

  Future<void> loadPaymentSettings() async {
    await loadSettingsByCategory('payment');
  }

  Future<void> loadSystemSettings() async {
    await loadSettingsByCategory('system');
  }

  void _rebuildMaps() {
    _settingsMap.clear();
    _settingsByCategory.clear();

    for (final setting in _allSettings) {
      _settingsMap[setting.settingKey] = setting;

      if (!_settingsByCategory.containsKey(setting.category)) {
        _settingsByCategory[setting.category] = [];
      }
      _settingsByCategory[setting.category]!.add(setting);
    }

    debugLog('SettingsProvider',
        '✅ Rebuilt maps: ${_settingsMap.length} settings, ${_settingsByCategory.length} categories');
  }

  Future<void> clearUserData() async {
    debugLog('SettingsProvider', 'Clearing settings data');

    await deviceService.clearCacheByPrefix('settings');
    await deviceService.clearCacheByPrefix('all_settings');

    _allSettings.clear();
    _settingsMap.clear();
    _settingsByCategory.clear();
    _lastCategoryLoadTime.clear();
    _ongoingLoads.clear();

    _settingsUpdateController.close();
    _settingsUpdateController = StreamController<List<Setting>>.broadcast();

    _settingsUpdateController.add(_allSettings);

    _notifySafely();
  }

  void clearError() {
    _error = null;
    _notifySafely();
  }

  void _notifySafely() {
    if (hasListeners) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (hasListeners) {
          notifyListeners();
        }
      });
    }
  }

  @override
  void dispose() {
    _settingsUpdateController.close();
    super.dispose();
  }
}

class PaymentMethod {
  final String method;
  final String name;
  final String accountInfo;
  final String instructions;
  final IconData iconData;

  PaymentMethod({
    required this.method,
    required this.name,
    required this.accountInfo,
    required this.instructions,
    required this.iconData,
  });

  @override
  String toString() => 'PaymentMethod($name: $accountInfo)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PaymentMethod &&
        other.method == method &&
        other.name == name &&
        other.accountInfo == accountInfo;
  }

  @override
  int get hashCode => method.hashCode ^ name.hashCode ^ accountInfo.hashCode;
}

class ContactInfo {
  final ContactType type;
  final String title;
  final String value;
  final IconData icon;

  ContactInfo({
    required this.type,
    required this.title,
    required this.value,
    required this.icon,
  });

  bool get isPhone => type == ContactType.phone;
  bool get isEmail => type == ContactType.email;
  bool get isWhatsApp => type == ContactType.whatsapp;
  bool get isTelegram => type == ContactType.telegram;
  bool get isAddress => type == ContactType.address;
  bool get isHours => type == ContactType.hours;
}

enum ContactType {
  phone,
  email,
  whatsapp,
  telegram,
  address,
  hours,
}

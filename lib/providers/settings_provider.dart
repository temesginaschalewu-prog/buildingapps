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

  final Map<String, DateTime> _lastCategoryLoadTime = {};
  static const Duration _categoryLoadMinInterval = Duration(minutes: 5);

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
    return minutesSinceLastLoad >= 5;
  }

  List<ContactInfo> getContactInfoList() {
    final contacts = <ContactInfo>[];
    final contactSettings = _settingsByCategory['contact'] ?? [];

    debugLog('SettingsProvider',
        '📞 Building contact list from ${contactSettings.length} contact settings');

    for (final setting in contactSettings) {
      if (setting.settingValue == null || setting.settingValue!.isEmpty) {
        debugLog('SettingsProvider',
            '   ⚠️ Skipping ${setting.settingKey} - empty value');
        continue;
      }

      final key = setting.settingKey.toLowerCase();
      final value = setting.settingValue!;
      final displayName = setting.displayName;

      ContactType type;
      IconData icon;

      if (key.contains('phone') || key.contains('tel')) {
        type = ContactType.phone;
        icon = Icons.phone;
        debugLog('SettingsProvider', '   📞 Phone: $displayName = $value');
      } else if (key.contains('email')) {
        type = ContactType.email;
        icon = Icons.email;
        debugLog('SettingsProvider', '   📧 Email: $displayName = $value');
      } else if (key.contains('whatsapp') || key.contains('wa')) {
        type = ContactType.whatsapp;
        icon = Icons.message;
        debugLog('SettingsProvider', '   💬 WhatsApp: $displayName = $value');
      } else if (key.contains('telegram') || key.contains('tg')) {
        type = ContactType.telegram;
        icon = Icons.telegram;
        debugLog('SettingsProvider', '   ✈️ Telegram: $displayName = $value');
      } else if (key.contains('address') || key.contains('location')) {
        type = ContactType.address;
        icon = Icons.location_on;
        debugLog('SettingsProvider', '   📍 Address: $displayName = $value');
      } else if (key.contains('hours') || key.contains('time')) {
        type = ContactType.hours;
        icon = Icons.access_time;
        debugLog('SettingsProvider', '   🕒 Hours: $displayName = $value');
      } else if (key.contains('website') ||
          key.contains('url') ||
          key.contains('web')) {
        type = ContactType.website;
        icon = Icons.language;
        debugLog('SettingsProvider', '   🌐 Website: $displayName = $value');
      } else if (key.contains('facebook') || key.contains('fb')) {
        type = ContactType.social;
        icon = Icons.facebook;
        debugLog('SettingsProvider', '   📘 Facebook: $displayName = $value');
      } else if (key.contains('twitter') || key.contains('x.com')) {
        type = ContactType.social;
        icon = Icons.alternate_email;
        debugLog('SettingsProvider', '   🐦 Twitter: $displayName = $value');
      } else if (key.contains('instagram') || key.contains('ig')) {
        type = ContactType.social;
        icon = Icons.photo_camera;
        debugLog('SettingsProvider', '   📷 Instagram: $displayName = $value');
      } else if (key.contains('linkedin')) {
        type = ContactType.social;
        icon = Icons.business;
        debugLog('SettingsProvider', '   💼 LinkedIn: $displayName = $value');
      } else if (key.contains('youtube')) {
        type = ContactType.social;
        icon = Icons.play_circle;
        debugLog('SettingsProvider', '   ▶️ YouTube: $displayName = $value');
      } else {
        type = ContactType.other;
        icon = Icons.contact_page;
        debugLog('SettingsProvider', '   📄 Other: $displayName = $value');
      }

      contacts.add(ContactInfo(
        type: type,
        title: displayName,
        value: value,
        icon: icon,
        settingKey: setting.settingKey,
      ));
    }

    contacts.sort((a, b) {
      const typeOrder = {
        ContactType.phone: 1,
        ContactType.email: 2,
        ContactType.whatsapp: 3,
        ContactType.telegram: 4,
        ContactType.address: 5,
        ContactType.hours: 6,
        ContactType.website: 7,
        ContactType.social: 8,
        ContactType.other: 9,
      };

      final orderCompare = typeOrder[a.type]!.compareTo(typeOrder[b.type]!);
      if (orderCompare != 0) return orderCompare;
      return a.title.compareTo(b.title);
    });

    debugLog(
        'SettingsProvider', '📞 Total contact items built: ${contacts.length}');
    return contacts;
  }

  String getSupportPhone() {
    final contacts = getContactInfoList();
    final phoneContact = contacts.firstWhere(
      (c) => c.type == ContactType.phone,
      orElse: () => ContactInfo(
        type: ContactType.phone,
        title: 'Phone',
        value: '+251 911 223 344',
        icon: Icons.phone,
        settingKey: 'fallback_phone',
      ),
    );
    return phoneContact.value;
  }

  String getSupportEmail() {
    final contacts = getContactInfoList();
    final emailContact = contacts.firstWhere(
      (c) => c.type == ContactType.email,
      orElse: () => ContactInfo(
        type: ContactType.email,
        title: 'Email',
        value: 'support@familyacademy.com',
        icon: Icons.email,
        settingKey: 'fallback_email',
      ),
    );
    return emailContact.value;
  }

  String getOfficeAddress() {
    final contacts = getContactInfoList();
    final addressContact = contacts.firstWhere(
      (c) => c.type == ContactType.address,
      orElse: () => ContactInfo(
        type: ContactType.address,
        title: 'Address',
        value: 'Addis Ababa, Ethiopia',
        icon: Icons.location_on,
        settingKey: 'fallback_address',
      ),
    );
    return addressContact.value;
  }

  String getOfficeHours() {
    final contacts = getContactInfoList();
    final hoursContact = contacts.firstWhere(
      (c) => c.type == ContactType.hours,
      orElse: () => ContactInfo(
        type: ContactType.hours,
        title: 'Office Hours',
        value:
            'Monday - Friday: 9:00 AM - 5:00 PM\nSaturday: 9:00 AM - 1:00 PM',
        icon: Icons.access_time,
        settingKey: 'fallback_hours',
      ),
    );
    return hoursContact.value;
  }

  String getWhatsAppNumber() {
    final contacts = getContactInfoList();
    final whatsappContact = contacts.firstWhere(
      (c) => c.type == ContactType.whatsapp,
      orElse: () => ContactInfo(
        type: ContactType.whatsapp,
        title: 'WhatsApp',
        value: '',
        icon: Icons.message,
        settingKey: '',
      ),
    );
    return whatsappContact.value;
  }

  String getTelegramUsername() {
    final contacts = getContactInfoList();
    final telegramContact = contacts.firstWhere(
      (c) => c.type == ContactType.telegram,
      orElse: () => ContactInfo(
        type: ContactType.telegram,
        title: 'Telegram',
        value: '',
        icon: Icons.telegram,
        settingKey: '',
      ),
    );
    return telegramContact.value;
  }

  // UPDATED: getPaymentMethods() to properly return account holder names
  List<PaymentMethod> getPaymentMethods() {
    final methods = <PaymentMethod>[];

    debugLog('SettingsProvider', '🔄 Scanning for payment methods...');
    debugLog('SettingsProvider', 'Settings map size: ${_settingsMap.length}');
    debugLog(
        'SettingsProvider', 'Total settings loaded: ${_allSettings.length}');

    if (_allSettings.isEmpty) {
      debugLog('SettingsProvider',
          '⚠️ No settings loaded yet, attempting to load...');
      getAllSettings();
      return methods;
    }

    debugLog(
        'SettingsProvider', 'Available setting keys: ${_settingsMap.keys}');

    final enabledValue = getSettingValue('payment_methods_enabled');
    debugLog('SettingsProvider',
        'Payment methods enabled setting value: "$enabledValue"');

    bool methodsEnabled;
    if (enabledValue == null) {
      debugLog('SettingsProvider',
          '⚠️ payment_methods_enabled not found, defaulting to true');
      methodsEnabled = true;
    } else {
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

    // Find all payment method keys by looking for entries ending with '_name'
    for (final setting in _allSettings) {
      final key = setting.settingKey;
      if (key.startsWith('payment_method_') && key.endsWith('_name')) {
        // Extract the method key (e.g., 'telebirr' from 'payment_method_telebirr_name')
        final methodKey = key.substring(
            'payment_method_'.length, key.length - '_name'.length);
        methodKeys.add(methodKey);
        debugLog('SettingsProvider',
            'Found payment method key: $methodKey from $key');
      }
    }

    debugLog('SettingsProvider',
        'Found ${methodKeys.length} payment method keys: $methodKeys');

    if (methodKeys.isEmpty) {
      debugLog('SettingsProvider',
          '⚠️ No payment methods found in settings, using defaults');
      methods.addAll(_getDefaultPaymentMethods());
    } else {
      for (final methodKey in methodKeys) {
        // Look for name, number, and instructions using the correct pattern
        final nameKey = 'payment_method_${methodKey}_name';
        final numberKey = 'payment_method_${methodKey}_number';
        final instructionsKey = 'payment_method_${methodKey}_instructions';

        final methodName = getSettingValue(nameKey);
        final methodNumber = getSettingValue(numberKey);
        final methodInstructions = getSettingValue(instructionsKey);

        debugLog('SettingsProvider',
            'Method $methodKey: name="$methodName", number="$methodNumber", instructions="$methodInstructions"');

        // IMPORTANT: The methodName is the account holder name (e.g., "Kalaab Alemu", "John Mwangi", "Abebe Kebede")
        // The methodNumber is the account number or mobile number
        if (methodName != null &&
            methodName.isNotEmpty &&
            methodNumber != null &&
            methodNumber.isNotEmpty) {
          methods.add(PaymentMethod(
            method: methodKey,
            name: methodName, // This is the ACCOUNT HOLDER NAME from settings
            accountInfo: methodNumber, // This is the account number
            instructions:
                methodInstructions ?? 'Make payment to the provided account',
            iconData: _getPaymentMethodIcon(methodKey, methodName),
          ));
          debugLog('SettingsProvider',
              '✅ Added payment method: $methodKey with account holder: "$methodName"');
        } else {
          debugLog('SettingsProvider',
              '⚠️ Skipping $methodKey: Missing name or number');
        }
      }
    }

    // Add legacy payment methods as fallback
    _addLegacyPaymentMethods(methods);

    debugLog(
        'SettingsProvider', 'Total payment methods found: ${methods.length}');

    // Sort methods by name for consistent display
    methods.sort((a, b) => a.name.compareTo(b.name));

    return methods;
  }

  List<PaymentMethod> _getDefaultPaymentMethods() {
    return [
      PaymentMethod(
        method: 'telebirr',
        name: 'Kalaab Alemu', // Account holder name
        accountInfo: '+251911111111', // Account number
        instructions: 'Send payment via Telebirr to the number above',
        iconData: Icons.phone_android,
      ),
      PaymentMethod(
        method: 'cbe',
        name: 'Family Academy Business', // Account holder name
        accountInfo: '100011111111111', // Account number
        instructions: 'Make transfer to CBE account above',
        iconData: Icons.account_balance,
      ),
      PaymentMethod(
        method: 'bank',
        name: 'Family Academy PLC', // Account holder name
        accountInfo: '200000000000', // Account number
        instructions: 'Make transfer to the bank account above',
        iconData: Icons.account_balance_wallet,
      ),
    ];
  }

  void _addLegacyPaymentMethods(List<PaymentMethod> methods) {
    // Check for legacy telebirr settings (without the payment_method_ prefix)
    final oldTelebirrNumber = getSettingValue('payment_telebirr_number');
    final oldTelebirrName = getSettingValue('payment_telebirr_name');

    if (oldTelebirrNumber != null &&
        oldTelebirrNumber.isNotEmpty &&
        oldTelebirrName != null &&
        oldTelebirrName.isNotEmpty &&
        !methods.any((m) =>
            m.method == 'telebirr' ||
            m.name.toLowerCase().contains('telebirr'))) {
      methods.add(PaymentMethod(
        method: 'telebirr',
        name: oldTelebirrName, // Account holder name
        accountInfo: oldTelebirrNumber, // Account number
        instructions: 'Send payment via Telebirr to the number above',
        iconData: Icons.phone_android,
      ));
      debugLog('SettingsProvider', '✅ Added legacy telebirr payment method');
    }

    // Check for legacy bank settings
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
        name: oldBankName, // Account holder name
        accountInfo: oldBankNumber, // Account number
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
    if (method.contains('abyssinia') || name.contains('abyssinia')) {
      return Icons.account_balance;
    }
    if (method.contains('nib') || name.contains('nib')) {
      return Icons.account_balance;
    }
    if (method.contains('zemen') || name.contains('zemen')) {
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
    if (method.contains('mpesa') || name.contains('mpesa')) {
      return Icons.phone_android;
    }
    if (method.contains('hellocash') || name.contains('hellocash')) {
      return Icons.phone_android;
    }
    if (method.contains('amole') || name.contains('amole')) {
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
    if (method.contains('paypal') || name.contains('paypal')) {
      return Icons.payments;
    }
    if (method.contains('bitcoin') ||
        name.contains('bitcoin') ||
        method.contains('crypto') ||
        name.contains('crypto')) {
      return Icons.currency_bitcoin;
    }
    if (method.contains('western') || name.contains('western')) {
      return Icons.send;
    }

    return Icons.payment;
  }

  String getPaymentInstructions() {
    return getSettingValue('payment_instructions') ??
        'Please follow these steps to complete your payment:\n'
            '1. Select a payment method\n'
            '2. Make the payment using the provided account details\n'
            '3. Make sure the account holder name matches your payment\n'
            '4. Upload proof of payment\n'
            '5. Wait for admin verification (usually within 24 hours)\n'
            '6. Your access will be activated once verified';
  }

  bool isPaymentMethodConfigured(String methodKey) {
    final name = getSettingValue('payment_method_${methodKey}_name');
    final number = getSettingValue('payment_method_${methodKey}_number');
    return name != null &&
        name.isNotEmpty &&
        number != null &&
        number.isNotEmpty;
  }

  List<String> getConfiguredPaymentMethods() {
    final methods = <String>[];
    for (final setting in _allSettings) {
      final key = setting.settingKey;
      if (key.startsWith('payment_method_') && key.endsWith('_name')) {
        final methodName = key.substring(
            'payment_method_'.length, key.length - '_name'.length);
        if (isPaymentMethodConfigured(methodName)) {
          methods.add(methodName);
        }
      }
    }
    return methods;
  }

  String getSystemVersion() {
    return getSettingValue('system_version') ?? '1.0.0';
  }

  String getAdminEmail() {
    return getSettingValue('admin_email') ?? 'admin@familyacademy.com';
  }

  Future<void> getAllSettings() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('SettingsProvider', '🔄 Loading all settings from backend...');

      final cachedSettings =
          await deviceService.getCacheItem<List<Setting>>('all_settings');
      if (cachedSettings != null && cachedSettings.isNotEmpty) {
        _allSettings = cachedSettings;
        _rebuildMaps();
        _isLoading = false;
        _settingsUpdateController.add(_allSettings);
        debugLog('SettingsProvider',
            '✅ Loaded ${_allSettings.length} settings from cache');

        final categories = _settingsByCategory.keys.toList();
        debugLog('SettingsProvider', '📊 Categories in cache: $categories');

        _notifySafely();
        _refreshSettingsInBackground();
        return;
      }

      final response = await apiService.getAllSettings();

      if (response.success &&
          response.data != null &&
          response.data!.isNotEmpty) {
        _allSettings = response.data!;
        debugLog('SettingsProvider',
            '✅ Successfully loaded ${_allSettings.length} settings from backend');

        final categories = _allSettings.map((s) => s.category).toSet().toList();
        debugLog('SettingsProvider', '📊 Categories found: $categories');

        final paymentSettings =
            _allSettings.where((s) => s.category == 'payment').toList();
        debugLog('SettingsProvider',
            '💰 Payment settings found: ${paymentSettings.length}');

        // Log a few payment settings as examples
        for (final setting in paymentSettings.take(5)) {
          debugLog('SettingsProvider',
              '   - ${setting.settingKey}: "${setting.settingValue}"');
        }

        await deviceService.saveCacheItem('all_settings', _allSettings,
            ttl: const Duration(minutes: 30));
      } else {
        debugLog('SettingsProvider',
            '⚠️ No settings loaded from backend, using defaults');
        _allSettings = _getDefaultSettings();
      }

      _rebuildMaps();
      _settingsUpdateController.add(_allSettings);
    } catch (e, stackTrace) {
      _error = e.toString();
      debugLog('SettingsProvider', '❌ getAllSettings error: $e\n$stackTrace');
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
      debugLog('SettingsProvider', '⚠️ Background refresh failed: $e');
    }
  }

  Future<void> loadContactSettings({bool? forceRefresh}) async {
    final shouldForce = forceRefresh ?? false;

    debugLog('SettingsProvider',
        '📞 Loading contact settings (force: $shouldForce)');

    if (!shouldForce &&
        _settingsByCategory.containsKey('contact') &&
        _settingsByCategory['contact']!.isNotEmpty) {
      debugLog('SettingsProvider',
          '✅ Using cached contact settings: ${_settingsByCategory['contact']!.length} items');
      return;
    }

    if (_allSettings.isEmpty || shouldForce) {
      debugLog(
          'SettingsProvider', '📋 Loading all settings to get contact info');
      await getAllSettings();
    }

    if (!_settingsByCategory.containsKey('contact') ||
        _settingsByCategory['contact']!.isEmpty) {
      debugLog('SettingsProvider',
          '⚠️ No contact settings found in backend, will use fallback values');
      _addFallbackContactSettings();
    } else {
      debugLog('SettingsProvider',
          '✅ Contact settings loaded: ${_settingsByCategory['contact']!.length} items');

      for (final setting in _settingsByCategory['contact']!) {
        debugLog('SettingsProvider',
            '   - ${setting.settingKey}: "${setting.settingValue}"');
      }
    }
  }

  void _addFallbackContactSettings() {
    final fallbackContacts = [
      Setting(
        id: 1001,
        settingKey: 'contact_support_phone',
        settingValue: '+251 911 223 344',
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
        id: 1002,
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
        id: 1003,
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
        id: 1004,
        settingKey: 'contact_office_hours',
        settingValue:
            'Monday - Friday: 9:00 AM - 5:00 PM\nSaturday: 9:00 AM - 1:00 PM',
        displayName: 'Office Hours',
        category: 'contact',
        dataType: 'string',
        isPublic: true,
        displayOrder: 4,
        description: 'Office working hours',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    for (final setting in fallbackContacts) {
      if (!_settingsMap.containsKey(setting.settingKey)) {
        _allSettings.add(setting);
      }
    }

    _rebuildMaps();
  }

  Future<void> loadSettingsByCategory(String category) async {
    if (_isLoading) return;

    if (!_shouldLoadCategory(category)) {
      debugLog('SettingsProvider', '⏰ Using cached $category settings');
      return;
    }

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

  List<Setting> _getDefaultSettings() {
    final defaultSettings = <Setting>[];

    defaultSettings.addAll(_getDefaultPaymentSettings());

    defaultSettings.addAll([
      Setting(
        id: 100,
        settingKey: 'contact_support_phone',
        settingValue: '+25191111111111',
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
        settingValue: '+2519111111111',
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
        settingValue: 'Kalaab Alemu',
        displayName: 'Telebirr Name',
        category: 'payment',
        dataType: 'string',
        isPublic: true,
        displayOrder: 1,
        description: 'Telebirr account holder name',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Setting(
        id: 3,
        settingKey: 'payment_method_telebirr_number',
        settingValue: '+25191111111111',
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
        settingValue: 'Family Academy Business',
        displayName: 'CBE Bank Name',
        category: 'payment',
        dataType: 'string',
        isPublic: true,
        displayOrder: 4,
        description: 'CBE Bank account holder name',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Setting(
        id: 6,
        settingKey: 'payment_method_cbe_number',
        settingValue: '1000000000000',
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
        settingValue: 'Family Academy PLC',
        displayName: 'Bank Name',
        category: 'payment',
        dataType: 'string',
        isPublic: true,
        displayOrder: 7,
        description: 'Bank account holder name',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Setting(
        id: 9,
        settingKey: 'payment_method_bank_number',
        settingValue: '20002222222',
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
  final String name; // This is the ACCOUNT HOLDER NAME
  final String accountInfo; // This is the account number/mobile number
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
  final String settingKey;

  ContactInfo({
    required this.type,
    required this.title,
    required this.value,
    required this.icon,
    this.settingKey = '',
  });

  bool get isPhone => type == ContactType.phone;
  bool get isEmail => type == ContactType.email;
  bool get isWhatsApp => type == ContactType.whatsapp;
  bool get isTelegram => type == ContactType.telegram;
  bool get isAddress => type == ContactType.address;
  bool get isHours => type == ContactType.hours;
  bool get isWebsite => type == ContactType.website;
  bool get isSocial => type == ContactType.social;
  bool get isOther => type == ContactType.other;
}

enum ContactType {
  phone,
  email,
  whatsapp,
  telegram,
  address,
  hours,
  website,
  social,
  other,
}

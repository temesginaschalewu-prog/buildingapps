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

  // 🔥 FIXED: Get ALL contact settings from the contact category
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

      // 🔥 FIX: Detect contact type based on value format, NOT just key name
      ContactType type;
      IconData icon;

      // First try to detect by value format
      if (_isPhoneNumber(value)) {
        type = ContactType.phone;
        icon = Icons.phone;
        debugLog('SettingsProvider',
            '   📞 Detected as phone: $displayName = $value');
      } else if (_isEmail(value)) {
        type = ContactType.email;
        icon = Icons.email;
        debugLog('SettingsProvider',
            '   📧 Detected as email: $displayName = $value');
      } else if (_isUrl(value)) {
        if (value.contains('wa.me') || value.contains('whatsapp')) {
          type = ContactType.whatsapp;
          icon = Icons.message;
          debugLog('SettingsProvider',
              '   💬 Detected as WhatsApp: $displayName = $value');
        } else if (value.contains('t.me') || value.contains('telegram')) {
          type = ContactType.telegram;
          icon = Icons.telegram;
          debugLog('SettingsProvider',
              '   ✈️ Detected as Telegram: $displayName = $value');
        } else {
          type = ContactType.website;
          icon = Icons.language;
          debugLog('SettingsProvider',
              '   🌐 Detected as website: $displayName = $value');
        }
      }
      // If value format doesn't give type, use key name as fallback
      else if (key.contains('phone') ||
          key.contains('tel') ||
          key.contains('mobile')) {
        type = ContactType.phone;
        icon = Icons.phone;
        debugLog(
            'SettingsProvider', '   📞 Phone (by key): $displayName = $value');
      } else if (key.contains('email')) {
        type = ContactType.email;
        icon = Icons.email;
        debugLog(
            'SettingsProvider', '   📧 Email (by key): $displayName = $value');
      } else if (key.contains('whatsapp') || key.contains('wa')) {
        type = ContactType.whatsapp;
        icon = Icons.message;
        debugLog('SettingsProvider',
            '   💬 WhatsApp (by key): $displayName = $value');
      } else if (key.contains('telegram') ||
          key.contains('tg') ||
          key.contains('bot')) {
        type = ContactType.telegram;
        icon = Icons.telegram;
        debugLog('SettingsProvider',
            '   ✈️ Telegram (by key): $displayName = $value');
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
        // 🔥 FIX: If we can't determine type, treat as generic "other" but still show it
        type = ContactType.other;
        icon = Icons.contact_page;
        debugLog(
            'SettingsProvider', '   📄 Other contact: $displayName = $value');
      }

      contacts.add(ContactInfo(
        type: type,
        title: displayName,
        value: value,
        icon: icon,
        settingKey: setting.settingKey,
      ));
    }

    // Sort by type priority then title
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

  // Helper to detect phone numbers
  bool _isPhoneNumber(String value) {
    // Remove common formatting characters
    final clean = value.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
    // Check if it's mostly digits with reasonable length
    if (RegExp(r'^\d{8,15}$').hasMatch(clean)) return true;
    // Check for common phone patterns
    if (RegExp(r'^\+?\d{1,4}[\s\-]?\d{1,4}[\s\-]?\d{1,4}[\s\-]?\d{1,4}$')
        .hasMatch(value)) return true;
    return false;
  }

  // Helper to detect emails
  bool _isEmail(String value) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
  }

  // Helper to detect URLs
  bool _isUrl(String value) {
    return value.startsWith('http://') ||
        value.startsWith('https://') ||
        value.startsWith('www.') ||
        value.contains('.com') ||
        value.contains('.org') ||
        value.contains('.net') ||
        value.contains('.io') ||
        value.contains('t.me') ||
        value.contains('wa.me');
  }

  // 🔥 FIX: Get ALL payment methods - show everything admin adds
  List<PaymentMethod> getPaymentMethods() {
    final methods = <PaymentMethod>[];

    debugLog('SettingsProvider', '🔄 Scanning for payment methods...');

    if (_allSettings.isEmpty) {
      debugLog('SettingsProvider', '⚠️ No settings loaded yet');
      return methods;
    }

    // Check if payment methods are enabled
    final enabledValue = getSettingValue('payment_methods_enabled');
    bool methodsEnabled =
        enabledValue == null || enabledValue.toString().toLowerCase() == 'true';

    if (!methodsEnabled) {
      debugLog(
          'SettingsProvider', '⚠️ Payment methods are disabled in settings');
      return methods;
    }

    // 🔥 FIX: Find ALL payment methods by looking for entries ending with '_name'
    final methodKeys = <String>{};

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

    debugLog(
        'SettingsProvider', 'Found ${methodKeys.length} payment method keys');

    for (final methodKey in methodKeys) {
      final nameKey = 'payment_method_${methodKey}_name';
      final numberKey = 'payment_method_${methodKey}_number';
      final instructionsKey = 'payment_method_${methodKey}_instructions';

      final methodName = getSettingValue(nameKey);
      final methodNumber = getSettingValue(numberKey);
      final methodInstructions = getSettingValue(instructionsKey);

      debugLog('SettingsProvider',
          'Method $methodKey: name="$methodName", number="$methodNumber"');

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
          iconData: _getPaymentMethodIcon(methodKey, methodName, methodNumber),
        ));
        debugLog('SettingsProvider', '✅ Added payment method: $methodKey');
      } else {
        debugLog('SettingsProvider',
            '⚠️ Skipping $methodKey: Missing name or number');
      }
    }

    debugLog(
        'SettingsProvider', 'Total payment methods found: ${methods.length}');
    methods.sort((a, b) => a.name.compareTo(b.name));
    return methods;
  }

  IconData _getPaymentMethodIcon(String methodKey, String name, String number) {
    final method = methodKey.toLowerCase();
    final nameLower = name.toLowerCase();
    final numberLower = number.toLowerCase();

    if (method.contains('telebirr') ||
        nameLower.contains('telebirr') ||
        numberLower.contains('telebirr') ||
        method.contains('birr')) {
      return Icons.phone_android;
    }
    if (method.contains('mpesa') ||
        nameLower.contains('mpesa') ||
        method.contains('m-pesa')) {
      return Icons.phone_android;
    }
    if (method.contains('hellocash') || nameLower.contains('hellocash')) {
      return Icons.phone_android;
    }
    if (method.contains('amole') || nameLower.contains('amole')) {
      return Icons.phone_android;
    }
    if (method.contains('cbe') ||
        nameLower.contains('cbe') ||
        nameLower.contains('commercial')) {
      return Icons.account_balance;
    }
    if (method.contains('awash') || nameLower.contains('awash')) {
      return Icons.account_balance;
    }
    if (method.contains('dashen') || nameLower.contains('dashen')) {
      return Icons.account_balance;
    }
    if (method.contains('abyssinia') || nameLower.contains('abyssinia')) {
      return Icons.account_balance;
    }
    if (method.contains('nib') || nameLower.contains('nib')) {
      return Icons.account_balance;
    }
    if (method.contains('zemen') || nameLower.contains('zemen')) {
      return Icons.account_balance;
    }
    if (method.contains('bank') || nameLower.contains('bank')) {
      return Icons.account_balance;
    }
    if (method.contains('paypal') || nameLower.contains('paypal')) {
      return Icons.payments;
    }
    if (method.contains('bitcoin') ||
        nameLower.contains('bitcoin') ||
        nameLower.contains('crypto')) {
      return Icons.currency_bitcoin;
    }
    if (method.contains('western') || nameLower.contains('western')) {
      return Icons.send;
    }
    if (method.contains('card') ||
        nameLower.contains('card') ||
        nameLower.contains('credit') ||
        nameLower.contains('debit')) {
      return Icons.credit_card;
    }
    if (method.contains('cash') || nameLower.contains('cash')) {
      return Icons.money;
    }

    return Icons.payment;
  }

  // 🔥 FIX: Get Telegram bot URL from ANY contact setting
  String? getTelegramBotUrl() {
    final contactSettings = _settingsByCategory['contact'] ?? [];

    for (final setting in contactSettings) {
      final value = setting.settingValue;
      if (value != null && value.isNotEmpty) {
        if (value.contains('t.me') ||
            value.contains('telegram') ||
            setting.settingKey.toLowerCase().contains('bot') ||
            setting.settingKey.toLowerCase().contains('telegram') ||
            setting.displayName.toLowerCase().contains('telegram') ||
            setting.displayName.toLowerCase().contains('bot')) {
          debugLog('SettingsProvider',
              'Found Telegram bot: ${setting.settingKey} = $value');
          return value;
        }
      }
    }

    // Fallback to hardcoded if nothing found
    return 'https://t.me/FamilyAcademy_notify_Bot';
  }

  String getSupportPhone() {
    final contactSettings = getContactInfoList();
    for (final contact in contactSettings) {
      if (contact.type == ContactType.phone) {
        return contact.value;
      }
    }
    return '+251 911 223 344'; // Fallback
  }

  String getSupportEmail() {
    final contactSettings = getContactInfoList();
    for (final contact in contactSettings) {
      if (contact.type == ContactType.email) {
        return contact.value;
      }
    }
    return 'support@familyacademy.com'; // Fallback
  }

  String getOfficeAddress() {
    final contactSettings = getContactInfoList();
    for (final contact in contactSettings) {
      if (contact.type == ContactType.address) {
        return contact.value;
      }
    }
    return 'Addis Ababa, Ethiopia'; // Fallback
  }

  String getOfficeHours() {
    final contactSettings = getContactInfoList();
    for (final contact in contactSettings) {
      if (contact.type == ContactType.hours) {
        return contact.value;
      }
    }
    return 'Monday - Friday: 9:00 AM - 5:00 PM'; // Fallback
  }

  String getWhatsAppNumber() {
    final contactSettings = getContactInfoList();
    for (final contact in contactSettings) {
      if (contact.type == ContactType.whatsapp) {
        return contact.value;
      }
    }
    return ''; // No fallback
  }

  String getWebsite() {
    final contactSettings = getContactInfoList();
    for (final contact in contactSettings) {
      if (contact.type == ContactType.website) {
        return contact.value;
      }
    }
    return ''; // No fallback
  }

  String getPaymentInstructions() {
    return getSettingValue('payment_instructions') ??
        'Please follow these steps to complete your payment:\n'
            '1. Select a payment method\n'
            '2. Make the payment using the provided account details\n'
            '3. Upload proof of payment\n'
            '4. Wait for admin verification (usually within 24 hours)\n'
            '5. Your access will be activated once verified';
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

        final contactSettings =
            _allSettings.where((s) => s.category == 'contact').toList();
        debugLog('SettingsProvider',
            '📞 Contact settings found: ${contactSettings.length}');

        for (final setting in contactSettings) {
          debugLog('SettingsProvider',
              '   - ${setting.settingKey}: "${setting.settingValue}" (${setting.displayName})');
        }

        await deviceService.saveCacheItem('all_settings', _allSettings,
            ttl: const Duration(minutes: 30));
      } else {
        debugLog('SettingsProvider',
            '⚠️ No settings loaded from backend, using defaults');
      }

      _rebuildMaps();
      _settingsUpdateController.add(_allSettings);
    } catch (e, stackTrace) {
      _error = e.toString();
      debugLog('SettingsProvider', '❌ getAllSettings error: $e\n$stackTrace');
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
      debugLog('SettingsProvider', '⚠️ No contact settings found in backend');
    } else {
      debugLog('SettingsProvider',
          '✅ Contact settings loaded: ${_settingsByCategory['contact']!.length} items');

      for (final setting in _settingsByCategory['contact']!) {
        debugLog('SettingsProvider',
            '   - ${setting.settingKey}: "${setting.settingValue}" (${setting.displayName})');
      }
    }
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

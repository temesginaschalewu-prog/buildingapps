import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../models/setting_model.dart';

class SettingsProvider with ChangeNotifier {
  final ApiService apiService;
  final DeviceService deviceService;

  List<Setting> _allSettings = [];
  final Map<String, Setting> _settingsMap = {};
  final Map<String, List<Setting>> _settingsByCategory = {};
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

  // Get ALL contact settings
  List<ContactInfo> getContactInfoList() {
    final contacts = <ContactInfo>[];
    final contactSettings = _settingsByCategory['contact'] ?? [];

    for (final setting in contactSettings) {
      if (setting.settingValue == null || setting.settingValue!.isEmpty) {
        continue;
      }

      final key = setting.settingKey.toLowerCase();
      final value = setting.settingValue!;
      final displayName = setting.displayName;

      ContactType type;
      IconData icon;

      if (_isPhoneNumber(value)) {
        type = ContactType.phone;
        icon = Icons.phone;
      } else if (_isEmail(value)) {
        type = ContactType.email;
        icon = Icons.email;
      } else if (_isUrl(value)) {
        if (value.contains('wa.me') || value.contains('whatsapp')) {
          type = ContactType.whatsapp;
          icon = Icons.message;
        } else if (value.contains('t.me') || value.contains('telegram')) {
          type = ContactType.telegram;
          icon = Icons.telegram;
        } else {
          type = ContactType.website;
          icon = Icons.language;
        }
      } else if (key.contains('phone') ||
          key.contains('tel') ||
          key.contains('mobile')) {
        type = ContactType.phone;
        icon = Icons.phone;
      } else if (key.contains('email')) {
        type = ContactType.email;
        icon = Icons.email;
      } else if (key.contains('whatsapp') || key.contains('wa')) {
        type = ContactType.whatsapp;
        icon = Icons.message;
      } else if (key.contains('telegram') ||
          key.contains('tg') ||
          key.contains('bot')) {
        type = ContactType.telegram;
        icon = Icons.telegram;
      } else if (key.contains('address') || key.contains('location')) {
        type = ContactType.address;
        icon = Icons.location_on;
      } else if (key.contains('hours') || key.contains('time')) {
        type = ContactType.hours;
        icon = Icons.access_time;
      } else if (key.contains('website') ||
          key.contains('url') ||
          key.contains('web')) {
        type = ContactType.website;
        icon = Icons.language;
      } else if (key.contains('facebook') || key.contains('fb')) {
        type = ContactType.social;
        icon = Icons.facebook;
      } else if (key.contains('twitter') || key.contains('x.com')) {
        type = ContactType.social;
        icon = Icons.alternate_email;
      } else if (key.contains('instagram') || key.contains('ig')) {
        type = ContactType.social;
        icon = Icons.photo_camera;
      } else if (key.contains('linkedin')) {
        type = ContactType.social;
        icon = Icons.business;
      } else if (key.contains('youtube')) {
        type = ContactType.social;
        icon = Icons.play_circle;
      } else {
        type = ContactType.other;
        icon = Icons.contact_page;
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

    return contacts;
  }

  bool _isPhoneNumber(String value) {
    final clean = value.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
    if (RegExp(r'^\d{8,15}$').hasMatch(clean)) return true;
    if (RegExp(r'^\+?\d{1,4}[\s\-]?\d{1,4}[\s\-]?\d{1,4}[\s\-]?\d{1,4}$')
        .hasMatch(value)) {
      return true;
    }
    return false;
  }

  bool _isEmail(String value) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
  }

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

  // Get ALL payment methods
  List<PaymentMethod> getPaymentMethods() {
    final methods = <PaymentMethod>[];

    if (_allSettings.isEmpty) return methods;

    final enabledValue = getSettingValue('payment_methods_enabled');
    final bool methodsEnabled =
        enabledValue == null || enabledValue.toString().toLowerCase() == 'true';
    if (!methodsEnabled) return methods;

    final methodKeys = <String>{};
    for (final setting in _allSettings) {
      final key = setting.settingKey;
      if (key.startsWith('payment_method_') && key.endsWith('_name')) {
        final methodKey = key.substring(
            'payment_method_'.length, key.length - '_name'.length);
        methodKeys.add(methodKey);
      }
    }

    for (final methodKey in methodKeys) {
      final nameKey = 'payment_method_${methodKey}_name';
      final numberKey = 'payment_method_${methodKey}_number';
      final instructionsKey = 'payment_method_${methodKey}_instructions';

      final methodName = getSettingValue(nameKey);
      final methodNumber = getSettingValue(numberKey);
      final methodInstructions = getSettingValue(instructionsKey);

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
      }
    }

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
          return value;
        }
      }
    }
    return 'https://t.me/FamilyAcademy_notify_Bot';
  }

  String getSupportPhone() {
    final contactSettings = getContactInfoList();
    for (final contact in contactSettings) {
      if (contact.type == ContactType.phone) return contact.value;
    }
    return '+251 911 223 344';
  }

  String getSupportEmail() {
    final contactSettings = getContactInfoList();
    for (final contact in contactSettings) {
      if (contact.type == ContactType.email) return contact.value;
    }
    return 'support@familyacademy.com';
  }

  String getOfficeAddress() {
    final contactSettings = getContactInfoList();
    for (final contact in contactSettings) {
      if (contact.type == ContactType.address) return contact.value;
    }
    return 'Addis Ababa, Ethiopia';
  }

  String getOfficeHours() {
    final contactSettings = getContactInfoList();
    for (final contact in contactSettings) {
      if (contact.type == ContactType.hours) return contact.value;
    }
    return 'Monday - Friday: 9:00 AM - 5:00 PM';
  }

  String getWhatsAppNumber() {
    final contactSettings = getContactInfoList();
    for (final contact in contactSettings) {
      if (contact.type == ContactType.whatsapp) return contact.value;
    }
    return '';
  }

  String getWebsite() {
    final contactSettings = getContactInfoList();
    for (final contact in contactSettings) {
      if (contact.type == ContactType.website) return contact.value;
    }
    return '';
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
        if (isPaymentMethodConfigured(methodName)) methods.add(methodName);
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
      final cachedSettings =
          await deviceService.getCacheItem<List<Setting>>('all_settings');
      if (cachedSettings != null && cachedSettings.isNotEmpty) {
        _allSettings = cachedSettings;
        _rebuildMaps();
        _isLoading = false;
        _settingsUpdateController.add(_allSettings);
        _notifySafely();
        _refreshSettingsInBackground();
        return;
      }

      final response = await apiService.getAllSettings();

      if (response.success &&
          response.data != null &&
          response.data!.isNotEmpty) {
        _allSettings = response.data!;
        await deviceService.saveCacheItem('all_settings', _allSettings,
            ttl: const Duration(minutes: 30));
      }

      _rebuildMaps();
      _settingsUpdateController.add(_allSettings);
    } catch (e) {
      _error = e.toString();
      _rebuildMaps();
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> _refreshSettingsInBackground() async {
    try {
      final response = await apiService.getAllSettings();
      if (response.success &&
          response.data != null &&
          response.data!.isNotEmpty) {
        _allSettings = response.data!;
        _rebuildMaps();
        _settingsUpdateController.add(_allSettings);
        await deviceService.saveCacheItem('all_settings', _allSettings,
            ttl: const Duration(minutes: 30));
      }
    } catch (e) {}
  }

  Future<void> loadContactSettings({bool? forceRefresh}) async {
    final shouldForce = forceRefresh ?? false;

    if (!shouldForce &&
        _settingsByCategory.containsKey('contact') &&
        _settingsByCategory['contact']!.isNotEmpty) {
      return;
    }

    if (_allSettings.isEmpty || shouldForce) await getAllSettings();
  }

  Future<void> loadSettingsByCategory(String category) async {
    if (_isLoading) return;
    if (!_shouldLoadCategory(category)) return;
    if (_ongoingLoads.containsKey(category)) {
      await _ongoingLoads[category]!.future;
      return;
    }

    final completer = Completer<bool>();
    _ongoingLoads[category] = completer;

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
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
        return;
      }

      final response = await apiService.getSettingsByCategory(category);
      final categorySettings = response.data ?? [];

      _settingsByCategory[category] = categorySettings;
      for (final setting in categorySettings) {
        _settingsMap[setting.settingKey] = setting;
      }

      await deviceService.saveCacheItem(cacheKey, categorySettings,
          ttl: const Duration(minutes: 30));
      _lastCategoryLoadTime[category] = DateTime.now();
      completer.complete(true);
    } catch (e) {
      _error = e.toString();
      completer.complete(false);
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
  }

  Future<void> clearUserData() async {
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
        if (hasListeners) notifyListeners();
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

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/setting_model.dart';
import '../utils/helpers.dart';

class SettingsProvider with ChangeNotifier {
  final ApiService apiService;

  List<Setting> _allSettings = [];
  Map<String, Setting> _settingsMap = {};
  Map<String, List<Setting>> _settingsByCategory = {};
  bool _isLoading = false;
  String? _error;

  SettingsProvider({required this.apiService});

  List<Setting> get allSettings => List.unmodifiable(_allSettings);
  Map<String, List<Setting>> get settingsByCategory =>
      Map.unmodifiable(_settingsByCategory);
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Setting> getSettingsByCategory(String category) {
    return List.unmodifiable(_settingsByCategory[category] ?? []);
  }

  List<Setting> get contactSettings => getSettingsByCategory('contact');

  List<Setting> get paymentSettings => getSettingsByCategory('payment');

  Setting? getSettingByKey(String key) {
    return _settingsMap[key];
  }

  String? getSettingValue(String key) {
    return _settingsMap[key]?.settingValue;
  }

  String? getSettingDisplayName(String key) {
    return _settingsMap[key]?.displayName;
  }

  String? getPaymentBankName() => getSettingValue('payment_bank_name');
  String? getPaymentAccountNumber() =>
      getSettingValue('payment_account_number');
  String? getPaymentTelebirrNumber() =>
      getSettingValue('payment_telebirr_number');
  String? getPaymentInstructions() => getSettingValue('payment_instructions');

  String? getContactSupportPhone() => getSettingValue('contact_support_phone');
  String? getContactSupportEmail() => getSettingValue('contact_support_email');
  String? getContactOfficeAddress() =>
      getSettingValue('contact_office_address');
  String? getContactOfficeHours() => getSettingValue('contact_office_hours');

  Future<void> getAllSettings() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('SettingsProvider', 'Loading all settings');
      final response = await apiService.getAllSettings();
      _allSettings = response.data ?? [];

      _rebuildMaps();

      debugLog('SettingsProvider', 'Loaded ${_allSettings.length} settings');
    } catch (e) {
      _error = e.toString();
      debugLog('SettingsProvider', 'getAllSettings error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> loadSettingsByCategory(String category) async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('SettingsProvider', 'Loading settings for category: $category');
      final response = await apiService.getSettingsByCategory(category);
      final categorySettings = response.data ?? [];

      _settingsByCategory[category] = categorySettings;

      for (final setting in categorySettings) {
        _settingsMap[setting.settingKey] = setting;
      }

      debugLog('SettingsProvider',
          'Loaded ${categorySettings.length} $category settings');
    } catch (e) {
      _error = e.toString();
      debugLog('SettingsProvider', 'loadSettingsByCategory error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> loadPaymentSettings() async {
    await loadSettingsByCategory('payment');
  }

  Future<void> loadContactSettings() async {
    await loadSettingsByCategory('contact');
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

  void clearError() {
    _error = null;
    _notifySafely();
  }

  void clearSettings() {
    _allSettings.clear();
    _settingsMap.clear();
    _settingsByCategory.clear();
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
}

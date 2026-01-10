import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/setting_model.dart';
import '../utils/helpers.dart';

class SettingsProvider with ChangeNotifier {
  final ApiService apiService;

  List<Setting> _contactSettings = [];
  List<Setting> _paymentSettings = [];
  bool _isLoading = false;
  String? _error;

  SettingsProvider({required this.apiService});

  List<Setting> get contactSettings => List.unmodifiable(_contactSettings);
  List<Setting> get paymentSettings => List.unmodifiable(_paymentSettings);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadContactSettings() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('SettingsProvider', 'Loading contact settings');
      final response = await apiService.getSettingsByCategory('contact');
      _contactSettings = response.data ?? [];
      debugLog('SettingsProvider',
          'Loaded ${_contactSettings.length} contact settings');
    } catch (e) {
      _error = e.toString();
      debugLog('SettingsProvider', 'loadContactSettings error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> loadPaymentSettings() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('SettingsProvider', 'Loading payment settings');
      final response = await apiService.getSettingsByCategory('payment');
      _paymentSettings = response.data ?? [];
      debugLog('SettingsProvider',
          'Loaded ${_paymentSettings.length} payment settings');
    } catch (e) {
      _error = e.toString();
      debugLog('SettingsProvider', 'loadPaymentSettings error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  String? getContactSetting(String key) {
    try {
      final setting = _contactSettings.firstWhere((s) => s.settingKey == key);
      return setting.settingValue;
    } catch (e) {
      return null;
    }
  }

  String? getPaymentSetting(String key) {
    try {
      final setting = _paymentSettings.firstWhere((s) => s.settingKey == key);
      return setting.settingValue;
    } catch (e) {
      return null;
    }
  }

  String? getSetting(String key) {
    try {
      final setting = _contactSettings.firstWhere((s) => s.settingKey == key);
      return setting.settingValue;
    } catch (e) {
      try {
        final setting = _paymentSettings.firstWhere((s) => s.settingKey == key);
        return setting.settingValue;
      } catch (e) {
        return null;
      }
    }
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
}

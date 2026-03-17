// lib/providers/settings_provider.dart
// COMPLETE PRODUCTION-READY FINAL VERSION - INSTANT CACHE + BACKGROUND REFRESH

import 'dart:async';
import 'package:familyacademyclient/services/offline_queue_manager.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../services/user_session.dart';
import '../services/connectivity_service.dart';
import '../services/hive_service.dart';
import '../models/setting_model.dart';
import '../utils/api_response.dart';
import '../utils/constants.dart';
import '../utils/app_enums.dart';
import 'base_provider.dart';

/// PRODUCTION-READY Settings Provider with Full Offline Support
class SettingsProvider extends ChangeNotifier
    with
        BaseProvider<SettingsProvider>,
        OfflineAwareProvider<SettingsProvider>,
        BackgroundRefreshMixin<SettingsProvider> {
  @override
  final ConnectivityService connectivityService;

  final ApiService apiService;
  final DeviceService deviceService;
  final HiveService hiveService;

  List<Setting> _allSettings = [];
  final Map<String, Setting> _settingsMap = {};
  final Map<String, List<Setting>> _settingsByCategory = {};

  final Map<String, DateTime> _lastCategoryLoadTime = {};
  final Map<String, Completer<bool>> _ongoingLoads = {};

  // Flag to prevent double initialization
  bool _hasInitialized = false;
  bool _isLoadingContactSettings = false;

  @override
  Duration get refreshInterval => const Duration(minutes: 30);

  Box? _settingsBox;

  int _apiCallCount = 0;

  StreamController<List<Setting>> _settingsUpdateController =
      StreamController<List<Setting>>.broadcast();

  SettingsProvider({
    required this.apiService,
    required this.deviceService,
    required this.connectivityService,
    required this.hiveService,
  }) {
    log('SettingsProvider constructor called');
    initializeOfflineAware(
      connectivity: connectivityService,
      queue: OfflineQueueManager(),
    );
    _init();
  }

  Future<void> _init() async {
    log('_init() START');
    await _openHiveBoxes();
    await _loadCachedSettings();

    if (_allSettings.isNotEmpty) {
      startBackgroundRefresh();
      _hasInitialized = true;
    }

    log('_init() END');
  }

  Future<void> _openHiveBoxes() async {
    try {
      if (!Hive.isBoxOpen(AppConstants.hiveSettingsBox)) {
        _settingsBox =
            await Hive.openBox<dynamic>(AppConstants.hiveSettingsBox);
      } else {
        _settingsBox = Hive.box<dynamic>(AppConstants.hiveSettingsBox);
      }
      log('✅ Hive box opened');
    } catch (e) {
      log('⚠️ Error opening Hive box: $e');
    }
  }

  Future<void> _loadCachedSettings() async {
    try {
      if (_settingsBox != null) {
        final cachedSettings = _settingsBox!.get('all_settings');
        if (cachedSettings != null && cachedSettings is List) {
          final List<Setting> settings = [];
          for (final item in cachedSettings) {
            if (item is Setting) {
              settings.add(item);
            } else if (item is Map<String, dynamic>) {
              settings.add(Setting.fromJson(item));
            }
          }

          if (settings.isNotEmpty) {
            _allSettings = settings;
            _rebuildMaps();
            setLoaded();
            log('✅ Loaded ${_allSettings.length} settings from Hive');
          }
        }
      }
    } catch (e) {
      log('Error loading cached settings: $e');
    }
  }

  Future<void> _saveToHive() async {
    try {
      if (_settingsBox != null) {
        await _settingsBox!.put('all_settings', _allSettings);
        log('💾 Saved ${_allSettings.length} settings to Hive');
      }
    } catch (e) {
      log('Error saving to Hive: $e');
    }
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
    log('Rebuilt maps: ${_settingsMap.length} keys, ${_settingsByCategory.length} categories');
  }

  bool _shouldLoadCategory(String category, {bool forceRefresh = false}) {
    if (forceRefresh) return true;
    final lastLoad = _lastCategoryLoadTime[category];
    if (lastLoad == null) return true;
    final minutesSinceLastLoad = DateTime.now().difference(lastLoad).inMinutes;
    return minutesSinceLastLoad >= 5;
  }

  bool _isPhoneNumber(String value) {
    final clean = value.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
    if (RegExp(r'^\d{8,15}$').hasMatch(clean)) return true;
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
    if (method.contains('bank') || nameLower.contains('bank')) {
      return Icons.account_balance;
    }
    if (method.contains('paypal') || nameLower.contains('paypal')) {
      return Icons.payments;
    }
    if (method.contains('card') ||
        nameLower.contains('card') ||
        nameLower.contains('credit') ||
        nameLower.contains('debit')) {
      return Icons.credit_card;
    }
    return Icons.payment;
  }

  // ===== GETTERS =====
  List<Setting> get allSettings => List.unmodifiable(_allSettings);
  Map<String, List<Setting>> get settingsByCategory =>
      Map.unmodifiable(_settingsByCategory);

  Stream<List<Setting>> get settingsUpdates => _settingsUpdateController.stream;

  List<Setting> getSettingsByCategory(String category) {
    return _settingsByCategory[category] ?? [];
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

  // ===== LOAD ALL SETTINGS - INSTANT CACHE + BACKGROUND REFRESH =====
  Future<void> getAllSettings({
    bool forceRefresh = false,
    bool isManualRefresh = false,
  }) async {
    _apiCallCount++;
    final callId = _apiCallCount;

    log('getAllSettings() CALL #$callId');

    // If we already have data and not forcing refresh, return cached immediately
    if (_hasInitialized && _allSettings.isNotEmpty && !forceRefresh) {
      log('✅ Returning cached settings INSTANTLY');
      setLoaded();
      _settingsUpdateController.add(_allSettings);

      // If online and not manual refresh, do background refresh silently
      if (!isOffline && !isManualRefresh) {
        unawaited(_refreshInBackground());
      }
      return;
    }

    if (isManualRefresh && isOffline) {
      throw Exception('Network error. Please check your internet connection.');
    }

    if (isLoading && !forceRefresh) {
      log('⏳ Already loading, waiting...');
      int attempts = 0;
      while (isLoading && attempts < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }
      if (_allSettings.isNotEmpty) {
        log('✅ Got settings from existing load');
        setLoaded();
        _settingsUpdateController.add(_allSettings);
        return;
      }
    }

    setLoading();

    try {
      // STEP 1: Try Hive first (fast)
      if (!forceRefresh && _allSettings.isEmpty) {
        log('STEP 1: Checking Hive cache');
        if (_settingsBox != null) {
          final cachedSettings = _settingsBox!.get('all_settings');
          if (cachedSettings != null && cachedSettings is List) {
            final List<Setting> settings = [];
            for (final item in cachedSettings) {
              if (item is Setting) {
                settings.add(item);
              } else if (item is Map<String, dynamic>) {
                settings.add(Setting.fromJson(item));
              }
            }
            if (settings.isNotEmpty) {
              _allSettings = settings;
              _rebuildMaps();
              _hasInitialized = true;
              setLoaded();
              _settingsUpdateController.add(_allSettings);
              log('✅ Using cached settings from Hive');

              // Background refresh if online
              if (!isOffline && !isManualRefresh) {
                unawaited(_refreshInBackground());
              }
              return;
            }
          }
        }
      }

      // STEP 2: Try DeviceService
      if (!forceRefresh && _allSettings.isEmpty) {
        log('STEP 2: Checking DeviceService cache');
        final cachedSettings = await deviceService.getCacheItem<List<dynamic>>(
          AppConstants.allSettingsKey,
        );
        if (cachedSettings != null && cachedSettings.isNotEmpty) {
          final List<Setting> settings = [];
          for (final json in cachedSettings) {
            if (json is Map<String, dynamic>) {
              settings.add(Setting.fromJson(json));
            }
          }

          if (settings.isNotEmpty) {
            _allSettings = settings;
            _rebuildMaps();
            _hasInitialized = true;
            setLoaded();
            _settingsUpdateController.add(_allSettings);
            log('✅ Using cached settings from DeviceService');

            await _saveToHive();

            if (!isOffline && !isManualRefresh) {
              unawaited(_refreshInBackground());
            }
            return;
          }
        }
      }

      // STEP 3: Check offline status
      if (isOffline) {
        log('STEP 3: Offline mode');
        if (_allSettings.isNotEmpty) {
          setLoaded();
          _settingsUpdateController.add(_allSettings);
          log('✅ Showing cached settings offline');
          return;
        }

        setError('You are offline. No cached settings available.');
        setLoaded();
        _settingsUpdateController.add(_allSettings);

        if (isManualRefresh) {
          throw Exception(
              'Network error. Please check your internet connection.');
        }
        return;
      }

      // STEP 4: Fetch from API (only if online and we need fresh data)
      log('STEP 4: Fetching from API');
      final response = await apiService.getAllSettings().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          log('⏱️ API timeout in getAllSettings - using cached if available');
          if (_allSettings.isNotEmpty) {
            return ApiResponse<List<Setting>>(
              success: true,
              message: 'Using cached settings (server timeout)',
              data: _allSettings,
            );
          }
          return ApiResponse<List<Setting>>(
            success: false,
            message: 'Request timed out. Please try again.',
            data: [],
          );
        },
      );

      if (response.success &&
          response.data != null &&
          response.data!.isNotEmpty) {
        _allSettings = response.data!;
        log('✅ Received ${_allSettings.length} settings from API');

        await _saveToHive();

        deviceService.saveCacheItem(
          AppConstants.allSettingsKey,
          _allSettings.map((s) => s.toJson()).toList(),
          ttl: AppConstants.cacheTTLSettings,
        );

        _rebuildMaps();
        _hasInitialized = true;
        _settingsUpdateController.add(_allSettings);
        setLoaded();
        log('✅ Success! Settings loaded');
      } else {
        log('⚠️ No settings from API, using empty list');
        _allSettings = [];
        _rebuildMaps();
        _hasInitialized = true;
        setLoaded();
        _settingsUpdateController.add(_allSettings);

        if (isManualRefresh) {
          throw Exception(response.message);
        }
      }
    } catch (e) {
      setError(e.toString());
      setLoaded();
      log('❌ Error loading settings: $e');

      if (_allSettings.isEmpty) {
        await _recoverFromCache();
      }

      _settingsUpdateController.add(_allSettings);

      if (isManualRefresh) {
        rethrow;
      }
    } finally {
      safeNotify();
    }
  }

  Future<void> _refreshInBackground() async {
    if (isOffline) return;

    try {
      final response = await apiService.getAllSettings().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          log('⏱️ Background refresh timeout');
          return ApiResponse<List<Setting>>(
            success: false,
            message: 'Timeout',
          );
        },
      );

      if (response.success &&
          response.data != null &&
          response.data!.isNotEmpty) {
        _allSettings = response.data!;
        _rebuildMaps();

        await _saveToHive();

        deviceService.saveCacheItem(
          AppConstants.allSettingsKey,
          _allSettings.map((s) => s.toJson()).toList(),
          ttl: AppConstants.cacheTTLSettings,
        );

        _settingsUpdateController.add(_allSettings);
        safeNotify();
        log('🔄 Background refresh complete');
      }
    } catch (e) {
      log('Background refresh error: $e');
    }
  }

  Future<void> _recoverFromCache() async {
    log('Attempting cache recovery');

    if (_settingsBox != null) {
      try {
        final cachedSettings = _settingsBox!.get('all_settings');
        if (cachedSettings != null && cachedSettings is List) {
          final List<Setting> settings = [];
          for (final item in cachedSettings) {
            if (item is Setting) {
              settings.add(item);
            } else if (item is Map<String, dynamic>) {
              settings.add(Setting.fromJson(item));
            }
          }
          if (settings.isNotEmpty) {
            _allSettings = settings;
            _rebuildMaps();
            log('✅ Recovered ${settings.length} settings from Hive after error');
            return;
          }
        }
      } catch (e) {
        log('Error recovering from Hive: $e');
      }
    }

    try {
      final cachedSettings = await deviceService.getCacheItem<List<dynamic>>(
        AppConstants.allSettingsKey,
      );
      if (cachedSettings != null && cachedSettings.isNotEmpty) {
        final List<Setting> settings = [];
        for (final json in cachedSettings) {
          if (json is Map<String, dynamic>) {
            settings.add(Setting.fromJson(json));
          }
        }

        if (settings.isNotEmpty) {
          _allSettings = settings;
          _rebuildMaps();
          log('✅ Recovered ${settings.length} settings from DeviceService after error');
        }
      }
    } catch (e) {
      log('Error recovering from DeviceService: $e');
    }
  }

  // ===== LOAD CONTACT SETTINGS - FIXED WITH BACKGROUND REFRESH =====
  Future<void> loadContactSettings({bool? forceRefresh}) async {
    log('loadContactSettings()');

    // Prevent double loading
    if (_isLoadingContactSettings) {
      log('Already loading contact settings, skipping');
      return;
    }

    final shouldForce = forceRefresh ?? false;

    // If we already have contact settings and not forcing refresh, return cached data
    if (!shouldForce &&
        _settingsByCategory.containsKey('contact') &&
        _settingsByCategory['contact']!.isNotEmpty) {
      log('Contact settings already loaded, returning cached');
      return;
    }

    // If we have no settings at all, load them first (without force)
    if (_allSettings.isEmpty) {
      _isLoadingContactSettings = true;
      await getAllSettings();
      _isLoadingContactSettings = false;
      return;
    }

    // If we're forcing refresh, do it in background (no spinner)
    if (shouldForce && !isOffline) {
      _isLoadingContactSettings = true;
      unawaited(_refreshContactSettingsInBackground());
      // Don't set loading to false immediately - let background task run
      Future.delayed(const Duration(milliseconds: 100), () {
        _isLoadingContactSettings = false;
      });
    }
  }

  Future<void> _refreshContactSettingsInBackground() async {
    log('Refreshing contact settings in background');
    try {
      final response =
          await apiService.getSettingsByCategory('contact').timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          log('⏱️ Background refresh timeout for contact settings');
          return ApiResponse<List<Setting>>(
            success: false,
            message: 'Timeout',
          );
        },
      );

      if (response.success && response.data != null) {
        final settings = response.data!;
        _settingsByCategory['contact'] = settings;
        for (final setting in settings) {
          _settingsMap[setting.settingKey] = setting;
        }

        // Update Hive cache
        if (_settingsBox != null) {
          await _settingsBox!.put('category_contact', settings);
        }

        // Also update device service cache
        deviceService.saveCacheItem(
          'settings_category_contact',
          settings.map((s) => s.toJson()).toList(),
          ttl: const Duration(minutes: 30),
        );

        safeNotify();
        log('✅ Contact settings refreshed in background');
      }
    } catch (e) {
      log('Background refresh error for contact settings: $e');
    }
  }

  // ===== LOAD SETTINGS BY CATEGORY =====
  Future<void> loadSettingsByCategory(String category) async {
    log('loadSettingsByCategory($category)');

    if (isLoading) return;
    if (!_shouldLoadCategory(category)) {
      log('Category $category already loaded recently');
      return;
    }

    if (_ongoingLoads.containsKey(category)) {
      log('Waiting for existing load of category $category');
      await _ongoingLoads[category]!.future;
      return;
    }

    final completer = Completer<bool>();
    _ongoingLoads[category] = completer;

    setLoading();

    try {
      final cacheKey = AppConstants.settingsCategoryKey(category);

      // STEP 1: Try memory cache first
      if (_settingsByCategory.containsKey(category) &&
          _settingsByCategory[category]!.isNotEmpty) {
        log('Using memory cache for category $category');
        setLoaded();
        completer.complete(true);
        return;
      }

      // STEP 2: Try Hive for category
      if (_settingsBox != null) {
        final categoryKey = 'category_$category';
        final cachedCategory = _settingsBox!.get(categoryKey);
        if (cachedCategory != null && cachedCategory is List) {
          final List<Setting> settings = [];
          for (final item in cachedCategory) {
            if (item is Setting) {
              settings.add(item);
            } else if (item is Map<String, dynamic>) {
              settings.add(Setting.fromJson(item));
            }
          }
          if (settings.isNotEmpty) {
            _settingsByCategory[category] = settings;
            for (final setting in settings) {
              _settingsMap[setting.settingKey] = setting;
            }
            setLoaded();
            _lastCategoryLoadTime[category] = DateTime.now();
            completer.complete(true);
            log('✅ Loaded category $category from Hive');
            return;
          }
        }
      }

      // STEP 3: Try DeviceService
      final cachedSettings =
          await deviceService.getCacheItem<List<Setting>>(cacheKey);
      if (cachedSettings != null) {
        log('Found category $category in DeviceService');
        _settingsByCategory[category] = cachedSettings;
        for (final setting in cachedSettings) {
          _settingsMap[setting.settingKey] = setting;
        }
        setLoaded();
        _lastCategoryLoadTime[category] = DateTime.now();

        if (_settingsBox != null) {
          final categoryKey = 'category_$category';
          await _settingsBox!.put(categoryKey, cachedSettings);
        }

        completer.complete(true);
        log('✅ Loaded category $category from DeviceService');
        return;
      }

      // STEP 4: If offline and no cache - error
      if (isOffline) {
        log('Offline with no cache for category $category');
        setLoaded();
        completer.complete(false);
        return;
      }

      // STEP 5: Only reach here if online
      log('Fetching category $category from API');
      final response = await apiService.getSettingsByCategory(category).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          log('⏱️ API timeout for category $category');
          return ApiResponse<List<Setting>>(
            success: false,
            message: 'Request timed out',
            data: [],
          );
        },
      );

      final categorySettings = response.data ?? [];

      if (categorySettings.isNotEmpty) {
        _settingsByCategory[category] = categorySettings;
        for (final setting in categorySettings) {
          _settingsMap[setting.settingKey] = setting;
        }

        deviceService.saveCacheItem(
          cacheKey,
          categorySettings,
          ttl: const Duration(minutes: 30),
        );

        if (_settingsBox != null) {
          final categoryKey = 'category_$category';
          await _settingsBox!.put(categoryKey, categorySettings);
        }

        _lastCategoryLoadTime[category] = DateTime.now();
        log('✅ Loaded category $category from API');
      }

      completer.complete(true);
    } catch (e) {
      setError(e.toString());
      log('Error loading category $category: $e');
      completer.complete(false);
    } finally {
      setLoaded();
      _ongoingLoads.remove(category);
      safeNotify();
    }
  }

  // ===== LOAD SPECIFIC SETTINGS =====
  Future<void> loadPaymentSettings() async {
    await loadSettingsByCategory('payment');
  }

  Future<void> loadSystemSettings() async {
    await loadSettingsByCategory('system');
  }

  // ===== CONTACT INFO METHODS =====
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

    log('getContactInfoList: ${contacts.length} contacts');
    return contacts;
  }

  // ===== PAYMENT METHODS =====
  List<PaymentMethod> getPaymentMethods() {
    final methods = <PaymentMethod>[];

    if (_allSettings.isEmpty) return methods;

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

    log('getPaymentMethods: ${methods.length} methods');
    return methods;
  }

  // ===== PAYMENT INSTRUCTIONS =====
  String getPaymentInstructions() {
    return getSettingValue('payment_instructions') ??
        'Please follow these steps to complete your payment:\n'
            '1. Select a payment method\n'
            '2. Make the payment using the provided account details\n'
            '3. Upload proof of payment\n'
            '4. Wait for admin verification (usually within 24 hours)\n'
            '5. Your access will be activated once verified';
  }

  // ===== SUPPORT CONTACT METHODS =====
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

  // ===== OFFICE HOURS =====
  String getOfficeHours() {
    final contactSettings = getContactInfoList();
    for (final contact in contactSettings) {
      if (contact.type == ContactType.hours) return contact.value;
    }
    return 'Monday - Friday: 9:00 AM - 5:00 PM';
  }

  // ===== TELEGRAM BOT URL =====
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

  @override
  Future<void> onBackgroundRefresh() async {
    log('Background refresh triggered');
    if (!isOffline && _allSettings.isNotEmpty) {
      await _refreshInBackground();
    }
  }

  @override
  Future<void> onOnlineRefresh() async {
    log('Online - refreshing settings');
    await getAllSettings(isManualRefresh: true);
  }

  Future<void> clearUserData() async {
    final session = UserSession();
    if (!session.shouldClearCacheOnLogout()) return;

    await deviceService.clearCacheByPrefix('settings');
    await deviceService.clearCacheByPrefix('all_settings');
    stopBackgroundRefresh();

    _allSettings.clear();
    _settingsMap.clear();
    _settingsByCategory.clear();
    _lastCategoryLoadTime.clear();
    _ongoingLoads.clear();
    _hasInitialized = false;

    await _settingsUpdateController.close();
    _settingsUpdateController = StreamController<List<Setting>>.broadcast();
    _settingsUpdateController.add(_allSettings);
    safeNotify();

    log('🧹 Cleared settings data');
  }

  @override
  void dispose() {
    stopBackgroundRefresh();
    _settingsUpdateController.close();
    _settingsBox?.close();
    disposeSubscriptions();
    super.dispose();
  }
}

// ===== PAYMENT METHOD CLASS =====
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

// ===== CONTACT INFO CLASS =====
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

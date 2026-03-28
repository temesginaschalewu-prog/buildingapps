// lib/providers/settings_provider.dart
// PRODUCTION-READY FINAL VERSION - FIXED LOG SPAM

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
import '../utils/parsers.dart';
import '../utils/api_response.dart';
import '../utils/constants.dart';
import '../utils/app_enums.dart';
import '../utils/helpers.dart';
import 'base_provider.dart';

/// PRODUCTION-READY Settings Provider
class SettingsProvider extends ChangeNotifier
    with
        BaseProvider<SettingsProvider>,
        OfflineAwareProvider<SettingsProvider>,
        BackgroundRefreshMixin<SettingsProvider> {
  final ConnectivityService _connectivityService;

  @override
  ConnectivityService get connectivityService => _connectivityService;

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

  // ✅ FIXED: Proper stream declaration
  late StreamController<List<Setting>> _settingsUpdateController;

  // ✅ FIXED: Rate limiting
  DateTime? _lastBackgroundRefresh;
  static const Duration _minBackgroundInterval = Duration(minutes: 2);

  // ✅ FIXED: Cache for contact info to prevent log spam
  List<ContactInfo> _cachedContacts = [];
  DateTime? _lastContactsFetch;
  static const Duration _contactsCacheDuration = Duration(seconds: 5);

  SettingsProvider({
    required this.apiService,
    required this.deviceService,
    required ConnectivityService connectivityService,
    required this.hiveService,
  })  : _connectivityService = connectivityService,
        _settingsUpdateController = StreamController<List<Setting>>.broadcast() {
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

    // Clear contact cache when settings change
    _cachedContacts.clear();
    _lastContactsFetch = null;

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

  String _normalizeTelegramUrl(String rawValue) {
    final value = rawValue.trim();
    if (value.isEmpty) return value;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('t.me/')) {
      return 'https://$value';
    }
    if (value.startsWith('@')) {
      return 'https://t.me/${value.substring(1)}';
    }
    if (!value.contains('/') &&
        !value.contains(' ') &&
        !value.contains('.com')) {
      return 'https://t.me/$value';
    }
    return value;
  }

  String _formatMonthsLabel(int months) {
    return months == 1 ? '1 month' : '$months months';
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

  int getBillingCycleMonths(String billingCycle) {
    final normalizedCycle = billingCycle.trim().toLowerCase();
    final candidates = [
      'billing_cycle_${normalizedCycle}_months',
      'subscription_${normalizedCycle}_months',
      '${normalizedCycle}_duration_months',
    ];

    for (final key in candidates) {
      final value = getSettingValue(key);
      if (value != null && value.isNotEmpty) {
        final parsed = int.tryParse(value.trim());
        if (parsed != null && parsed > 0) {
          return parsed;
        }
      }
    }

    return normalizedCycle == 'semester' ? 4 : 1;
  }

  String getBillingCycleDurationText(String billingCycle) {
    return _formatMonthsLabel(getBillingCycleMonths(billingCycle));
  }

  String getBillingCyclePlanLabel(String billingCycle) {
    final normalizedCycle = billingCycle.trim().toLowerCase();
    final configuredLabel = getSettingValue('billing_cycle_${normalizedCycle}_label');
    if (configuredLabel != null && configuredLabel.trim().isNotEmpty) {
      return configuredLabel.trim();
    }

    final durationText = getBillingCycleDurationText(normalizedCycle);
    if (normalizedCycle == 'monthly') {
      return 'Monthly plan';
    }
    if (normalizedCycle == 'semester') {
      return 'Semester plan ($durationText)';
    }
    return '${Parsers.toTitleCase(normalizedCycle)} plan ($durationText)';
  }

  String getBillingCycleDescription(String billingCycle) {
    final normalizedCycle = billingCycle.trim().toLowerCase();
    final configuredDescription =
        getSettingValue('billing_cycle_${normalizedCycle}_description');
    if (configuredDescription != null &&
        configuredDescription.trim().isNotEmpty) {
      return configuredDescription.trim();
    }

    return '${Parsers.toTitleCase(normalizedCycle)} (${getBillingCycleDurationText(normalizedCycle)})';
  }

  // ===== LOAD ALL SETTINGS =====
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
      throw Exception(getUserFriendlyErrorMessage(
          'Network error. Please check your internet connection.'));
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

        setError(getUserFriendlyErrorMessage(
            'You are offline. No cached settings available.'));
        setLoaded();
        _settingsUpdateController.add(_allSettings);

        if (isManualRefresh) {
          throw Exception(getUserFriendlyErrorMessage(
              'Network error. Please check your internet connection.'));
        }
        return;
      }

      // STEP 4: Fetch from API
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
      setError(getUserFriendlyErrorMessage(e));
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

  // ✅ FIXED: Rate limited background refresh
  Future<void> _refreshInBackground() async {
    if (isOffline) return;

    // Rate limiting
    if (_lastBackgroundRefresh != null &&
        DateTime.now().difference(_lastBackgroundRefresh!) <
            _minBackgroundInterval) {
      log('⏱️ Background refresh rate limited');
      return;
    }
    _lastBackgroundRefresh = DateTime.now();

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

  // ===== LOAD CONTACT SETTINGS =====
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
      try {
        await getAllSettings(forceRefresh: shouldForce);
      } finally {
        _isLoadingContactSettings = false;
      }

      if (_settingsByCategory.containsKey('contact') &&
          _settingsByCategory['contact']!.isNotEmpty) {
        return;
      }
    }

    if (isOffline) {
      log('Offline, skipping contact settings API fetch');
      return;
    }

    if (shouldForce) {
      _isLoadingContactSettings = true;
      unawaited(_refreshContactSettingsInBackground());
      Future.delayed(const Duration(milliseconds: 100), () {
        _isLoadingContactSettings = false;
      });
      return;
    }

    _isLoadingContactSettings = true;
    try {
      await loadSettingsByCategory('contact');
    } finally {
      _isLoadingContactSettings = false;
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

        // Clear contact cache
        _cachedContacts.clear();
        _lastContactsFetch = null;

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
      setError(getUserFriendlyErrorMessage(e));
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

  // ===== CONTACT INFO METHODS - FIXED WITH CACHING =====
  List<ContactInfo> getContactInfoList() {
    // ✅ FIXED: Return cached version if still fresh
    if (_cachedContacts.isNotEmpty &&
        _lastContactsFetch != null &&
        DateTime.now().difference(_lastContactsFetch!) <
            _contactsCacheDuration) {
      return _cachedContacts;
    }

    log('Building contact info list (cache miss)');

    final contacts = <ContactInfo>[];
    final seenKeys = <String>{};
    final contactSettings = <Setting>[
      ...(_settingsByCategory['contact'] ?? const <Setting>[]),
      ...(_settingsByCategory['telegram'] ?? const <Setting>[]),
    ];

    for (final setting in contactSettings) {
      if (setting.settingValue == null || setting.settingValue!.isEmpty) {
        continue;
      }
      if (seenKeys.contains(setting.settingKey)) {
        continue;
      }
      seenKeys.add(setting.settingKey);

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

    // ✅ FIXED: Cache the results
    _cachedContacts = contacts;
    _lastContactsFetch = DateTime.now();

    log('getContactInfoList: ${contacts.length} contacts');
    return contacts;
  }

  ContactInfo? getContactInfoByType(ContactType type) {
    for (final contact in getContactInfoList()) {
      if (contact.type == type) {
        return contact;
      }
    }
    return null;
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
    final verificationMessage = getPaymentVerificationMessage();
    return getSettingValue('payment_instructions') ??
        'Please follow these steps to complete your payment:\n'
            '1. Select a payment method\n'
            '2. Make the payment using the provided account details\n'
            '3. Upload proof of payment\n'
            '4. Wait for admin verification. $verificationMessage\n'
            '5. Your access will be activated once verified';
  }

  String getPaymentVerificationWindowText() {
    final rawValue = getSettingValue('payment_verification_business_days');
    final trimmed = rawValue?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return '$trimmed working days';
    }
    return '1-3 working days';
  }

  String getPaymentVerificationMessage() {
    final configured = getSettingValue('payment_verification_message');
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }

    return 'Payments are usually verified within ${getPaymentVerificationWindowText()}';
  }

  String getPendingPaymentStatusMessage() {
    return 'Please wait for admin verification (${getPaymentVerificationWindowText()})';
  }

  String getPaymentMethodsUnavailableMessage() {
    final configured = getSettingValue('payment_methods_unavailable_message');
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }
    return 'Payment options are not ready yet. Please refresh or contact support if this continues.';
  }

  List<String> getPaymentImportantNotes() {
    final accountHolderMatch =
        getSettingValue('payment_note_account_holder_match')?.trim();
    final keepProof = getSettingValue('payment_note_keep_proof')?.trim();
    final contactSupport =
        getSettingValue('payment_note_contact_support')?.trim();
    final notification = getSettingValue('payment_note_notification')?.trim();

    final notes = <String>[];

    if (accountHolderMatch != null && accountHolderMatch.isNotEmpty) {
      notes.add(accountHolderMatch);
    } else {
      notes.add(
        'Make sure the account holder name matches the bank or mobile money account you used.',
      );
    }

    notes.add(getPaymentVerificationMessage());

    if (keepProof != null && keepProof.isNotEmpty) {
      notes.add(keepProof);
    } else {
      notes.add('Keep your payment proof until your payment is verified.');
    }

    if (contactSupport != null && contactSupport.isNotEmpty) {
      notes.add(contactSupport);
    } else {
      notes.add(
        'Contact support if your payment is still not verified after the expected review window.',
      );
    }

    if (notification != null && notification.isNotEmpty) {
      notes.add(notification);
    } else {
      notes.add('You will receive a notification once your payment is verified.');
    }

    return notes;
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

  int getSupportResponseHours() {
    final rawValue = getSettingValue('support_response_hours');
    final parsed = rawValue != null ? int.tryParse(rawValue.trim()) : null;
    if (parsed != null && parsed > 0) {
      return parsed;
    }
    return 24;
  }

  String getSupportResponseBadgeLabel() {
    final hours = getSupportResponseHours();
    return '${hours}H';
  }

  String getSupportResponseMessage() {
    final configured = getSettingValue('support_response_message');
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }

    final hours = getSupportResponseHours();
    return 'We typically respond within $hours hours during business days';
  }

  String getSupportScreenTitle() {
    final configured = getSettingValue('support_screen_title');
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }
    return 'Support';
  }

  String getSupportScreenSubtitle() {
    final configured = getSettingValue('support_screen_subtitle');
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }
    return 'Get help when you need it';
  }

  String getSupportQuickActionTitle() {
    final configured = getSettingValue('support_quick_action_title');
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }
    return 'Message support';
  }

  String getSupportQuickActionDescription() {
    final configured = getSettingValue('support_quick_action_description');
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }
    return 'Open the main support contact';
  }

  String getSupportHoursLabel() {
    final configured = getSettingValue('support_hours_label');
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }
    return 'Support hours';
  }

  String getSupportResponseTitle() {
    final configured = getSettingValue('support_response_title');
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }
    return 'Quick response';
  }

  String getSupportStillNeedHelpTitle() {
    final configured = getSettingValue('support_still_need_help_title');
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }
    return 'Contact us directly';
  }

  String getSupportStillNeedHelpMessage() {
    final configured = getSettingValue('support_still_need_help_message');
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }
    return 'If your question is not answered here, reach out through the contact options above and we will guide you.';
  }

  String getSupportNoContactTitle() {
    final configured = getSettingValue('support_no_contact_title');
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }
    return 'No contact information yet';
  }

  String getSupportNoContactMessage() {
    final configured = getSettingValue('support_no_contact_message');
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }
    return 'Your administrator has not configured a direct support contact yet.';
  }

  String getRefundPolicyMessage() {
    final configured = getSettingValue('refund_policy_message');
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }
    return 'Payments are non-refundable once verified. Please contact support if you have any issues.';
  }

  List<Map<String, String>> getSupportFaqItems() {
    final paymentMethodsAnswer =
        getSettingValue('support_faq_payment_methods_answer')?.trim();
    final passwordAnswer =
        getSettingValue('support_faq_password_answer')?.trim();
    final offlineAccessAnswer =
        getSettingValue('support_faq_offline_access_answer')?.trim();

    final contactChannels = <String>[];
    if (getContactInfoByType(ContactType.phone) != null) {
      contactChannels.add('phone');
    }
    if (getContactInfoByType(ContactType.email) != null) {
      contactChannels.add('email');
    }
    if (getContactInfoByType(ContactType.telegram) != null) {
      contactChannels.add('Telegram');
    }
    if (getContactInfoByType(ContactType.whatsapp) != null) {
      contactChannels.add('WhatsApp');
    }

    final readableChannels = contactChannels.isEmpty
        ? 'the Contact tab'
        : '${contactChannels.join(', ')} and the Contact tab';

    return [
      {
        'question': 'How do I reset my password?',
        'answer': passwordAnswer != null && passwordAnswer.isNotEmpty
            ? passwordAnswer
            : 'Go to Profile -> Settings -> Change Password. You will need your current password to set a new one.',
      },
      {
        'question': 'What payment methods are accepted?',
        'answer': paymentMethodsAnswer != null && paymentMethodsAnswer.isNotEmpty
            ? paymentMethodsAnswer
            : 'We accept the payment methods currently enabled by the administrator. Check the Payment screen for the latest options.',
      },
      {
        'question': 'How long does payment verification take?',
        'answer':
            '${getPaymentVerificationMessage()}. You will receive a notification once your payment is verified.',
      },
      {
        'question': 'Can I access content offline?',
        'answer': offlineAccessAnswer != null && offlineAccessAnswer.isNotEmpty
            ? offlineAccessAnswer
            : 'Yes. Videos and notes can be downloaded for offline access. Your progress will sync when you are back online.',
      },
      {
        'question': 'How do I contact support?',
        'answer':
            'You can reach us through $readableChannels. ${getSupportResponseMessage()}.',
      },
      {
        'question': 'What is the refund policy?',
        'answer': getRefundPolicyMessage(),
      },
    ];
  }

  int getParentLinkTokenExpiryMinutes() {
    final rawValue = getSettingValue('parent_link_token_expiry_minutes');
    final parsed = rawValue != null ? int.tryParse(rawValue.trim()) : null;
    if (parsed != null && parsed > 0) {
      return parsed;
    }
    return 30;
  }

  String getParentLinkTokenWindowText() {
    final minutes = getParentLinkTokenExpiryMinutes();
    if (minutes % 60 == 0) {
      final hours = minutes ~/ 60;
      return hours == 1 ? '1 hour' : '$hours hours';
    }
    return minutes == 1 ? '1 minute' : '$minutes minutes';
  }

  int getDevicePairingExpiryMinutes() {
    final rawValue = getSettingValue('device_pairing_expiry_minutes');
    final parsed = rawValue != null ? int.tryParse(rawValue.trim()) : null;
    if (parsed != null && parsed > 0) {
      return parsed;
    }
    return 10;
  }

  String getDevicePairingWindowText() {
    final minutes = getDevicePairingExpiryMinutes();
    if (minutes % 60 == 0) {
      final hours = minutes ~/ 60;
      return hours == 1 ? '1 hour' : '$hours hours';
    }
    return minutes == 1 ? '1 minute' : '$minutes minutes';
  }

  int getDeviceChangeMaxApprovals() {
    final rawValue = getSettingValue('device_change_max_approvals');
    final parsed = rawValue != null ? int.tryParse(rawValue.trim()) : null;
    if (parsed != null && parsed > 0) {
      return parsed;
    }
    return 2;
  }

  int getDeviceChangeWindowDays() {
    final rawValue = getSettingValue('device_change_window_days');
    final parsed = rawValue != null ? int.tryParse(rawValue.trim()) : null;
    if (parsed != null && parsed > 0) {
      return parsed;
    }
    return 30;
  }

  String getDeviceChangeLimitMessage() {
    final configured = getSettingValue('device_change_limit_message');
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }
    return 'For security, device changes are limited to ${getDeviceChangeMaxApprovals()} every ${getDeviceChangeWindowDays()} days.';
  }

  String getDeviceChangeLimitSummary() {
    final approvals = getDeviceChangeMaxApprovals();
    final days = getDeviceChangeWindowDays();
    final changeLabel = approvals == 1 ? 'change' : 'changes';
    final dayLabel = days == 1 ? 'day' : 'days';
    return '$approvals $changeLabel every $days $dayLabel';
  }

  String getChapterComingSoonMessage() {
    final configured = getSettingValue('chapter_coming_soon_message');
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }
    return 'This chapter will be available soon. Stay tuned for updates.';
  }

  bool isChatbotEnabled() {
    final rawValue = getSettingValue('chatbot_enabled')?.trim().toLowerCase();
    if (rawValue == null || rawValue.isEmpty) return true;
    return rawValue == '1' ||
        rawValue == 'true' ||
        rawValue == 'yes' ||
        rawValue == 'on';
  }

  String getChatbotScreenTitle() {
    final configured = getSettingValue('chatbot_screen_title');
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }
    return 'Learning assistant';
  }

  String getChatbotWelcomeMessage() {
    final configured = getSettingValue('chatbot_welcome_message');
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }
    return 'Ask me about your lessons, revision ideas, or study help anytime.';
  }

  String getChatbotOfflineMessage() {
    final configured = getSettingValue('chatbot_offline_message');
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }
    return 'You are offline right now. Your message will wait and send when you reconnect.';
  }

  String getChatbotDisabledMessage() {
    final configured = getSettingValue('chatbot_disabled_message');
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }
    return 'The learning assistant is not available right now. Please check again later.';
  }

  String getChatbotLimitReachedMessage() {
    final configured = getSettingValue('chatbot_limit_reached_message');
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }
    return 'Daily limit reached';
  }

  String getChatbotEmptyStateMessage(int remainingMessages, int dailyLimit) {
    final welcome = getChatbotWelcomeMessage();
    if (dailyLimit <= 0) return welcome;
    return '$welcome You have $remainingMessages/$dailyLimit messages left today.';
  }

  String getChatbotEmptyConversationsTitle() {
    final configured = getSettingValue('chatbot_empty_conversations_title');
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }
    return 'No conversations yet';
  }

  String getChatbotEmptyConversationsMessage() {
    final configured = getSettingValue('chatbot_empty_conversations_message');
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }
    return 'Start a new chat whenever you want help studying.';
  }

  String getChatbotConversationsTitle() {
    final configured = getSettingValue('chatbot_conversations_title');
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }
    return 'Conversations';
  }

  String getChatbotConversationsSubtitle() {
    final configured = getSettingValue('chatbot_conversations_subtitle');
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }
    return 'Pick up where you left off or start a new study chat.';
  }

  String getParentLinkTitle() {
    final configured = getSettingValue('parent_link_title');
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }
    return 'Bring a parent into the journey';
  }

  String getParentLinkLoadingTitle() {
    final configured = getSettingValue('parent_link_loading_title');
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }
    return 'Preparing your parent connection';
  }

  String getParentLinkLoadingMessage() {
    final configured = getSettingValue('parent_link_loading_message');
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }
    return 'We are checking your link details and Telegram status so everything opens in one complete view.';
  }

  String getParentLinkScreenSubtitle() {
    final configured = getSettingValue('parent_link_screen_subtitle');
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }
    return 'Connect with parents';
  }

  String getParentLinkDescription() {
    final configured = getSettingValue('parent_link_description');
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }
    return 'Generate a secure code and connect your parent to a polished Telegram progress assistant.';
  }

  String getParentLinkTokenMessage() {
    final configured = getSettingValue('parent_link_token_message');
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }
    return 'Ask your parent to use this code within {window}.';
  }

  String getParentLinkTokenMessageWithWindow() {
    return getParentLinkTokenMessage().replaceAll(
      '{window}',
      getParentLinkTokenWindowText(),
    );
  }

  String getParentLinkActiveWindowMessage() {
    final configured = getSettingValue('parent_link_active_window_message');
    if (configured != null && configured.trim().isNotEmpty) {
      return configured
          .trim()
          .replaceAll('{window}', getParentLinkTokenWindowText());
    }
    return 'New parent link codes stay active for ${getParentLinkTokenWindowText()}.';
  }

  String getParentLinkBenefitsTitle() {
    final configured = getSettingValue('parent_link_benefits_title');
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }
    return 'What parents receive';
  }

  String getParentLinkBenefitsSummary() {
    final configured = getSettingValue('parent_link_benefits_summary');
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }
    return 'Parents receive a richer student snapshot, including study time, chapter completion, questions, exams, and active subscriptions.';
  }

  String getParentLinkBenefitsUpdates() {
    final configured = getSettingValue('parent_link_benefits_updates');
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }
    return 'Important child changes such as profile updates and learning milestones can also be sent to the linked parent.';
  }

  String getParentLinkConnectedTitle() {
    final configured = getSettingValue('parent_link_connected_title');
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }
    return 'Parent connected';
  }

  String getParentLinkConnectedMessage() {
    final configured = getSettingValue('parent_link_connected_message');
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }
    return 'Your parent can now receive your learning snapshot, study milestones, exam performance, and access updates.';
  }

  String getParentLinkLiveBadge() {
    final configured = getSettingValue('parent_link_live_badge');
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }
    return 'Live';
  }

  String getParentLinkBotTitle() {
    final configured = getSettingValue('parent_link_bot_title');
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }
    return 'Parent Telegram assistant';
  }

  String getParentLinkBotFallbackMessage() {
    final configured = getSettingValue('parent_link_bot_fallback_message');
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }
    return 'Ask your administrator to configure the parent Telegram bot.';
  }

  String getParentLinkBotDescription() {
    final configured = getSettingValue('parent_link_bot_description');
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }
    return 'Once linked, parents can open the bot anytime to view a polished child snapshot, recent activity, exams, and payment access updates.';
  }

  // ===== TELEGRAM BOT URL =====
  String? getTelegramBotUrl() {
    const preferredKeys = [
      'parent_telegram_bot_url',
      'telegram_bot_url',
      'support_telegram_bot_url',
      'support_telegram_url',
      'telegram_url',
      'telegram_bot_username',
      'support_telegram_username',
    ];

    for (final key in preferredKeys) {
      final value = getSettingValue(key);
      if (value != null && value.trim().isNotEmpty) {
        return _normalizeTelegramUrl(value);
      }
    }

    final candidateCategories = ['parent_link', 'telegram', 'contact'];
    for (final category in candidateCategories) {
      final categorySettings = _settingsByCategory[category] ?? const <Setting>[];
      for (final setting in categorySettings) {
        final value = setting.settingValue;
        if (value == null || value.trim().isEmpty) {
          continue;
        }

        final key = setting.settingKey.toLowerCase();
        final display = setting.displayName.toLowerCase();
        final looksLikeTelegramValue = value.contains('t.me') ||
            value.startsWith('@') ||
            value.toLowerCase().contains('telegram');
        final looksLikeTelegramKey = key.contains('telegram') ||
            key.contains('bot') ||
            display.contains('telegram') ||
            display.contains('bot');

        if (looksLikeTelegramValue || looksLikeTelegramKey) {
          return _normalizeTelegramUrl(value);
        }
      }
    }

    return null;
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

  // ✅ FIXED: Clear user data with proper stream recreation
  Future<void> clearUserData() async {
    final session = UserSession();
    if (!session.shouldClearCacheOnLogout()) return;

    await deviceService.clearCacheByPrefix('settings');
    await deviceService.clearCacheByPrefix('all_settings');
    stopBackgroundRefresh();
    _lastBackgroundRefresh = null;
    _cachedContacts.clear();
    _lastContactsFetch = null;

    _allSettings.clear();
    _settingsMap.clear();
    _settingsByCategory.clear();
    _lastCategoryLoadTime.clear();
    _ongoingLoads.clear();
    _hasInitialized = false;

    // FIX: Properly recreate stream controller
    await _settingsUpdateController.close();
    _settingsUpdateController = StreamController<List<Setting>>.broadcast();
    _settingsUpdateController.add(_allSettings);

    safeNotify();
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

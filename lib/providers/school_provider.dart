// lib/providers/school_provider.dart
// PRODUCTION-READY FINAL VERSION

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:familyacademyclient/services/api_service.dart';
import 'package:familyacademyclient/services/device_service.dart';
import 'package:familyacademyclient/services/user_session.dart';
import 'package:familyacademyclient/services/connectivity_service.dart';
import 'package:familyacademyclient/services/hive_service.dart';
import 'package:familyacademyclient/services/offline_queue_manager.dart';
import 'package:familyacademyclient/models/school_model.dart';
import 'package:familyacademyclient/utils/constants.dart';
import '../utils/api_response.dart';
import '../utils/helpers.dart';
import 'base_provider.dart';

class SchoolProvider extends ChangeNotifier
    with
        BaseProvider<SchoolProvider>,
        OfflineAwareProvider<SchoolProvider>,
        BackgroundRefreshMixin<SchoolProvider> {
  @override
  final ConnectivityService connectivityService;

  final ApiService apiService;
  final DeviceService deviceService;
  final HiveService hiveService;

  List<School> _schools = [];
  int? _selectedSchoolId;

  // Cache for school names by ID
  final Map<int, String> _schoolNameCache = {};
  bool _loadError = false;
  bool _hasLoaded = false;
  DateTime? _lastFetchTime;

  static const Duration _schoolsCacheTTL = AppConstants.cacheTTLSchools;
  static const Duration _minFetchInterval = Duration(minutes: 30);
  @override
  Duration get refreshInterval => const Duration(minutes: 30);

  Box? _schoolsBox;
  Box? _selectedBox;

  int _apiCallCount = 0;

  // ✅ FIXED: Proper stream declarations
  late StreamController<List<School>> _schoolsUpdateController;
  late StreamController<int?> _selectedSchoolController;

  // ✅ FIXED: Rate limiting
  DateTime? _lastBackgroundRefresh;
  static const Duration _minBackgroundInterval = Duration(minutes: 2);

  SchoolProvider({
    required this.apiService,
    required this.deviceService,
    required this.connectivityService,
    required this.hiveService,
  })  : _schoolsUpdateController = StreamController<List<School>>.broadcast(),
        _selectedSchoolController = StreamController<int?>.broadcast() {
    log('SchoolProvider constructor called');
    initializeOfflineAware(
      connectivity: connectivityService,
      queue: OfflineQueueManager(),
    );
    _init();
  }

  Future<void> _init() async {
    log('_init() START');
    await _openHiveBoxes();
    await _loadCachedData();

    if (_schools.isNotEmpty) {
      startBackgroundRefresh();
    }

    log('_init() END');
  }

  Future<void> _openHiveBoxes() async {
    try {
      if (!Hive.isBoxOpen(AppConstants.hiveSchoolsBox)) {
        _schoolsBox = await Hive.openBox(AppConstants.hiveSchoolsBox);
      } else {
        _schoolsBox = Hive.box(AppConstants.hiveSchoolsBox);
      }

      if (!Hive.isBoxOpen('selected_school_box')) {
        _selectedBox = await Hive.openBox('selected_school_box');
      } else {
        _selectedBox = Hive.box('selected_school_box');
      }

      log('✅ Hive boxes opened');
    } catch (e) {
      log('⚠️ Error opening Hive boxes: $e');
    }
  }

  Future<void> _loadCachedData() async {
    log('_loadCachedData() START');

    try {
      // Load schools from Hive
      if (_schoolsBox != null) {
        final cachedSchools = _schoolsBox!.get('schools_list');
        if (cachedSchools != null) {
          log('Found cached schools, type: ${cachedSchools.runtimeType}');

          final List<School> convertedSchools = [];
          if (cachedSchools is List) {
            for (final item in cachedSchools) {
              if (item is School) {
                convertedSchools.add(item);
              } else if (item is Map<String, dynamic>) {
                convertedSchools.add(School.fromJson(item));
              } else if (item is Map) {
                try {
                  final Map<String, dynamic> typedMap = {};
                  item.forEach((key, value) {
                    typedMap[key.toString()] = value;
                  });
                  convertedSchools.add(School.fromJson(typedMap));
                } catch (e) {
                  log('Error converting school: $e');
                }
              }
            }
          }

          if (convertedSchools.isNotEmpty) {
            _schools = convertedSchools;
            _hasLoaded = true;
            _buildNameCache();
            _schoolsUpdateController.add(_schools);
            log('✅ Loaded ${_schools.length} schools from Hive');
          }
        }
      }

      // Load selected school from Hive
      if (_selectedBox != null) {
        final selectedId = _selectedBox!.get('selected_school');
        if (selectedId != null && selectedId is int) {
          _selectedSchoolId = selectedId;
          _selectedSchoolController.add(selectedId);
          log('✅ Loaded selected school $selectedId from Hive');
        }
      }
    } catch (e) {
      log('Error loading cached data: $e');
    }
  }

  void _buildNameCache() {
    _schoolNameCache.clear();
    for (final school in _schools) {
      _schoolNameCache[school.id] = school.name;
    }
    log('✅ Built school name cache with ${_schoolNameCache.length} entries');
  }

  Future<void> _saveSchoolsToHive() async {
    log('_saveSchoolsToHive() START');

    try {
      if (_schoolsBox != null) {
        await _schoolsBox!.put('schools_list', _schools);
        log('💾 Saved ${_schools.length} schools to Hive');
      }
    } catch (e) {
      log('Error saving schools to Hive: $e');
    }
  }

  Future<void> _saveSelectedToHive(int? schoolId) async {
    log('_saveSelectedToHive() for school $schoolId');

    try {
      if (_selectedBox != null) {
        if (schoolId != null) {
          await _selectedBox!.put('selected_school', schoolId);
        } else {
          await _selectedBox!.delete('selected_school');
        }
        log('💾 Saved selected school $schoolId to Hive');
      }
    } catch (e) {
      log('Error saving selected school to Hive: $e');
    }
  }

  // ===== GETTERS =====
  List<School> get schools => List.unmodifiable(_schools);
  int? get selectedSchoolId => _selectedSchoolId;
  bool get loadError => _loadError;
  bool get hasLoaded => _hasLoaded;

  Stream<List<School>> get schoolsUpdates => _schoolsUpdateController.stream;
  Stream<int?> get selectedSchoolUpdates => _selectedSchoolController.stream;

  School? getSchoolById(int id) {
    try {
      return _schools.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }

  // FAST cached school name lookup
  String? getSchoolNameById(int id) {
    // Check cache first
    if (_schoolNameCache.containsKey(id)) {
      return _schoolNameCache[id];
    }

    // Fall back to full school list
    final school = getSchoolById(id);
    if (school != null) {
      // Cache it for next time
      _schoolNameCache[id] = school.name;
      return school.name;
    }
    return null;
  }

  // ===== LOAD SCHOOLS =====
  Future<void> loadSchools({
    bool forceRefresh = false,
    bool isManualRefresh = false,
  }) async {
    _apiCallCount++;
    final callId = _apiCallCount;

    log('loadSchools() CALL #$callId');

    if (isManualRefresh && isOffline) {
      if (_schools.isNotEmpty) {
        clearError();
        _loadError = false;
        setLoaded();
        _schoolsUpdateController.add(_schools);
        return;
      }
      throw Exception(getUserFriendlyErrorMessage(
          'Network error. Please check your internet connection.'));
    }

    // Return cached data if already loaded and not too old
    if (_hasLoaded && !forceRefresh && !isManualRefresh) {
      if (_lastFetchTime != null) {
        final age = DateTime.now().difference(_lastFetchTime!);
        if (age < _minFetchInterval) {
          log('✅ Returning cached schools (age: ${age.inMinutes} minutes)');
          return;
        }
      } else {
        log('✅ Already have schools, returning cached');
        return;
      }
    }

    if (isLoading && !forceRefresh) {
      log('⏳ Already loading, skipping');
      return;
    }

    setLoading();

    try {
      // STEP 1: Try Hive first
      if (!forceRefresh && _schools.isEmpty) {
        log('STEP 1: Checking Hive cache');
        if (_schoolsBox != null) {
          final cachedSchools = _schoolsBox!.get('schools_list');
          if (cachedSchools != null) {
            log('Found cached schools in Hive, type: ${cachedSchools.runtimeType}');

            final List<School> convertedSchools = [];
            if (cachedSchools is List) {
              for (final item in cachedSchools) {
                if (item is School) {
                  convertedSchools.add(item);
                } else if (item is Map<String, dynamic>) {
                  convertedSchools.add(School.fromJson(item));
                } else if (item is Map) {
                  try {
                    final Map<String, dynamic> typedMap = {};
                    item.forEach((key, value) {
                      typedMap[key.toString()] = value;
                    });
                    convertedSchools.add(School.fromJson(typedMap));
                  } catch (e) {}
                }
              }
            }

            if (convertedSchools.isNotEmpty) {
              _schools = convertedSchools;
              _hasLoaded = true;
              _loadError = false;
              _lastFetchTime = DateTime.now();
              _buildNameCache();
              setLoaded();
              _schoolsUpdateController.add(_schools);
              log('✅ Using cached schools from Hive');

              if (!isOffline && !isManualRefresh) {
                unawaited(_refreshInBackground());
              }
              return;
            }
          }
        }
      }

      // STEP 2: Try DeviceService
      if (!forceRefresh && _schools.isEmpty) {
        log('STEP 2: Checking DeviceService cache');
        final cachedSchools = await deviceService.getCacheItem<List<dynamic>>(
          AppConstants.schoolsListKey,
        );

        if (cachedSchools != null) {
          log('Found ${cachedSchools.length} schools in DeviceService');

          final List<School> convertedSchools = [];
          for (final json in cachedSchools) {
            if (json is School) {
              convertedSchools.add(json);
            } else if (json is Map<String, dynamic>) {
              convertedSchools.add(School.fromJson(json));
            } else if (json is Map) {
              try {
                final Map<String, dynamic> typedMap = {};
                json.forEach((key, value) {
                  typedMap[key.toString()] = value;
                });
                convertedSchools.add(School.fromJson(typedMap));
              } catch (e) {}
            }
          }

          if (convertedSchools.isNotEmpty) {
            _schools = convertedSchools;
            _hasLoaded = true;
            _loadError = false;
            _lastFetchTime = DateTime.now();
            _buildNameCache();
            setLoaded();
            _schoolsUpdateController.add(_schools);
            log('✅ Using cached schools from DeviceService');

            await _saveSchoolsToHive();

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
        if (_schools.isNotEmpty) {
          _hasLoaded = true;
          _loadError = false;
          setLoaded();
          _schoolsUpdateController.add(_schools);
          log('✅ Showing cached schools offline');
          return;
        }

        setError(getUserFriendlyErrorMessage(
            'You are offline. No cached schools available.'));
        _loadError = true;
        setLoaded();
        _schoolsUpdateController.add(_schools);

        if (isManualRefresh) {
          throw Exception(getUserFriendlyErrorMessage(
              'Network error. Please check your internet connection.'));
        }
        return;
      }

      // STEP 4: Fetch from API
      log('STEP 4: Fetching from API');
      final response = await apiService.getSchools();

      if (response.success && response.data != null) {
        // Defensive: always map to School
        _schools = (response.data as List)
            .map((json) {
              if (json is School) return json;
              if (json is Map<String, dynamic>) return School.fromJson(json);
              if (json is Map) {
                return School.fromJson(Map<String, dynamic>.from(json));
              }
              return null;
            })
            .whereType<School>()
            .toList();

        log('✅ Received ${_schools.length} schools from API');
        _hasLoaded = true;
        _loadError = false;
        _lastFetchTime = DateTime.now();
        _buildNameCache();

        await _saveSchoolsToHive();

        deviceService.saveCacheItem(
          AppConstants.schoolsListKey,
          _schools.map((s) => s.toJson()).toList(),
          ttl: _schoolsCacheTTL,
        );

        await _loadSelectedSchool();

        setLoaded();
        _schoolsUpdateController.add(_schools);
        log('✅ Success! Schools loaded');
      } else {
        if (_schools.isNotEmpty) {
          clearError();
          _loadError = false;
          setLoaded();
          _schoolsUpdateController.add(_schools);
          log('⚠️ API refresh failed, keeping cached schools');
          return;
        }

        setError(getUserFriendlyErrorMessage(response.message));
        _loadError = true;
        setLoaded();
        log('❌ API error: ${response.message}');

        if (_schools.isEmpty) {
          await _recoverFromCache();
        }

        _schoolsUpdateController.add(_schools);

        if (isManualRefresh) {
          throw Exception(response.message);
        }
      }
    } catch (e) {
      if (_schools.isNotEmpty) {
        clearError();
        _loadError = false;
        setLoaded();
      } else {
        setError(getUserFriendlyErrorMessage(e));
        _loadError = true;
        setLoaded();
      }
      log('❌ Error loading schools: $e');

      if (_schools.isEmpty) {
        await _recoverFromCache();
      }

      _schoolsUpdateController.add(_schools);

      if (isManualRefresh && _schools.isEmpty) {
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

    // Don't refresh if we just did
    if (_lastFetchTime != null) {
      final age = DateTime.now().difference(_lastFetchTime!);
      if (age < _minFetchInterval) {
        log('Skipping background refresh - last fetch was ${age.inMinutes} minutes ago');
        return;
      }
    }

    try {
      final response = await apiService.getSchools();

      if (response.success && response.data != null) {
        _schools = response.data ?? [];
        _lastFetchTime = DateTime.now();
        _buildNameCache();
        log('Background refresh got ${_schools.length} schools');

        await _saveSchoolsToHive();

        deviceService.saveCacheItem(
          AppConstants.schoolsListKey,
          _schools.map((s) => s.toJson()).toList(),
          ttl: _schoolsCacheTTL,
        );

        _schoolsUpdateController.add(_schools);
        safeNotify();
        log('🔄 Background refresh complete');
      }
    } catch (e) {
      log('Background refresh error: $e');
    }
  }

  Future<void> _recoverFromCache() async {
    log('_recoverFromCache()');

    if (_schoolsBox != null) {
      try {
        final cachedSchools = _schoolsBox!.get('schools_list');
        if (cachedSchools != null) {
          log('Found schools in Hive for recovery, type: ${cachedSchools.runtimeType}');

          final List<School> convertedSchools = [];
          if (cachedSchools is List) {
            for (final item in cachedSchools) {
              if (item is School) {
                convertedSchools.add(item);
              } else if (item is Map<String, dynamic>) {
                convertedSchools.add(School.fromJson(item));
              } else if (item is Map) {
                try {
                  final Map<String, dynamic> typedMap = {};
                  item.forEach((key, value) {
                    typedMap[key.toString()] = value;
                  });
                  convertedSchools.add(School.fromJson(typedMap));
                } catch (e) {}
              }
            }
          }

          if (convertedSchools.isNotEmpty) {
            _schools = convertedSchools;
            _hasLoaded = true;
            _loadError = false;
            _buildNameCache();
            _schoolsUpdateController.add(_schools);
            log('✅ Recovered ${convertedSchools.length} schools from Hive after error');
            return;
          }
        }
      } catch (e) {
        log('Error recovering from Hive: $e');
      }
    }

    try {
      final cachedSchools = await deviceService.getCacheItem<List<dynamic>>(
        AppConstants.schoolsListKey,
      );
      if (cachedSchools != null) {
        log('Found ${cachedSchools.length} schools in DeviceService for recovery');

        final List<School> convertedSchools = [];
        for (final json in cachedSchools) {
          if (json is School) {
            convertedSchools.add(json);
          } else if (json is Map<String, dynamic>) {
            convertedSchools.add(School.fromJson(json));
          } else if (json is Map) {
            try {
              final Map<String, dynamic> typedMap = {};
              json.forEach((key, value) {
                typedMap[key.toString()] = value;
              });
              convertedSchools.add(School.fromJson(typedMap));
            } catch (e) {}
          }
        }

        if (convertedSchools.isNotEmpty) {
          _schools = convertedSchools;
          _hasLoaded = true;
          _loadError = false;
          _buildNameCache();
          _schoolsUpdateController.add(_schools);
          log('✅ Recovered ${convertedSchools.length} schools from DeviceService after error');
        }
      }
    } catch (e) {
      log('Error recovering from DeviceService: $e');
    }
  }

  Future<ApiResponse<void>> selectSchool(int schoolId) async {
    log('selectSchool($schoolId)');

    final response = await apiService.selectSchool(schoolId);

    if (response.success) {
      _selectedSchoolId = schoolId;

      await _saveSelectedToHive(schoolId);

      deviceService.saveCacheItem(
        AppConstants.selectedSchoolKey,
        schoolId,
        ttl: const Duration(days: 365),
        isUserSpecific: true,
      );

      _selectedSchoolController.add(schoolId);
      safeNotify();
      log('✅ Selected school $schoolId');
    } else {
      log('Failed to select school: ${response.message}');
    }

    return response;
  }

  Future<void> clearSelectedSchool() async {
    log('clearSelectedSchool()');

    _selectedSchoolId = null;

    await _saveSelectedToHive(null);
    await deviceService.removeCacheItem(
      AppConstants.selectedSchoolKey,
      isUserSpecific: true,
    );

    _selectedSchoolController.add(null);
    safeNotify();
    log('🧹 Cleared selected school');
  }

  Future<void> _loadSelectedSchool() async {
    log('_loadSelectedSchool()');

    try {
      if (_selectedBox != null) {
        final selectedId = _selectedBox!.get('selected_school');
        if (selectedId != null && selectedId is int) {
          _selectedSchoolId = selectedId;
          _selectedSchoolController.add(selectedId);
          log('✅ Loaded selected school from Hive');
          return;
        }
      }

      final selectedSchool = await deviceService.getCacheItem<int>(
        AppConstants.selectedSchoolKey,
      );
      if (selectedSchool != null) {
        _selectedSchoolId = selectedSchool;
        _selectedSchoolController.add(selectedSchool);

        await _saveSelectedToHive(selectedSchool);
        log('✅ Loaded selected school from DeviceService');
      }
    } catch (e) {
      log('Error loading selected school: $e');
    }
  }

  @override
  Future<void> onBackgroundRefresh() async {
    log('Background refresh triggered');
    if (!isOffline && _schools.isNotEmpty) {
      await _refreshInBackground();
    }
  }

  @override
  Future<void> onOnlineRefresh() async {
    log('Online - refreshing schools');
    await loadSchools(forceRefresh: true);
  }

  // ✅ FIXED: Clear user data with proper stream recreation
  Future<void> clearUserData() async {
    final session = UserSession();
    if (!session.shouldClearCacheOnLogout()) return;

    await deviceService.clearCacheByPrefix('schools');
    await deviceService.removeCacheItem(
      AppConstants.selectedSchoolKey,
      isUserSpecific: true,
    );
    stopBackgroundRefresh();
    _lastBackgroundRefresh = null;

    await _saveSelectedToHive(null);

    _schools = [];
    _selectedSchoolId = null;
    _schoolNameCache.clear();
    _hasLoaded = false;
    _lastFetchTime = null;

    // FIX: Properly recreate stream controllers
    await _schoolsUpdateController.close();
    await _selectedSchoolController.close();
    _schoolsUpdateController = StreamController<List<School>>.broadcast();
    _selectedSchoolController = StreamController<int?>.broadcast();

    _schoolsUpdateController.add(_schools);
    _selectedSchoolController.add(null);

    safeNotify();
  }

  void retryLoadSchools() {
    clearError();
    loadSchools(forceRefresh: true);
  }

  @override
  void clearError() {
    super.clearError();
    _loadError = false;
  }

  @override
  void dispose() {
    stopBackgroundRefresh();
    _schoolsUpdateController.close();
    _selectedSchoolController.close();
    _schoolsBox?.close();
    _selectedBox?.close();
    disposeSubscriptions();
    super.dispose();
  }
}

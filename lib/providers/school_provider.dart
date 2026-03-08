import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:familyacademyclient/services/api_service.dart';
import 'package:familyacademyclient/services/device_service.dart';
import 'package:familyacademyclient/services/user_session.dart';
import 'package:familyacademyclient/services/connectivity_service.dart';
import 'package:familyacademyclient/models/school_model.dart';
import 'package:familyacademyclient/utils/constants.dart';
import 'package:familyacademyclient/utils/helpers.dart';

class SchoolProvider with ChangeNotifier {
  final ApiService apiService;
  final DeviceService deviceService;
  final ConnectivityService connectivityService;

  List<School> _schools = [];
  int? _selectedSchoolId;
  bool _isLoading = false;
  String? _error;
  bool _hasError = false;
  bool _isOffline = false;

  StreamController<List<School>> _schoolsUpdateController =
      StreamController<List<School>>.broadcast();
  StreamController<int?> _selectedSchoolController =
      StreamController<int?>.broadcast();

  static const Duration _schoolsCacheTTL = AppConstants.cacheTTLSchools;

  SchoolProvider({
    required this.apiService,
    required this.deviceService,
    required this.connectivityService,
  }) {
    _setupConnectivityListener();
  }

  void _setupConnectivityListener() {
    connectivityService.onConnectivityChanged.listen((isOnline) {
      if (_isOffline != !isOnline) {
        _isOffline = !isOnline;
        notifyListeners();
      }
    });
  }

  List<School> get schools => List.unmodifiable(_schools);
  int? get selectedSchoolId => _selectedSchoolId;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _hasError;
  bool get isOffline => _isOffline;

  Stream<List<School>> get schoolsUpdates => _schoolsUpdateController.stream;
  Stream<int?> get selectedSchoolUpdates => _selectedSchoolController.stream;

  School? getSchoolById(int id) {
    try {
      return _schools.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }

  String? getSchoolNameById(int id) {
    final school = getSchoolById(id);
    return school?.name;
  }

  Future<void> loadSchools(
      {bool forceRefresh = false, bool isManualRefresh = false}) async {
    if (_isLoading && !forceRefresh) return;

    // STEP 1: ALWAYS try cache first (even when offline)
    if (!forceRefresh) {
      try {
        final cachedSchools = await deviceService
            .getCacheItem<List<School>>(AppConstants.schoolsListKey);
        if (cachedSchools != null) {
          _schools = cachedSchools;
          _hasError = false;
          _schoolsUpdateController.add(_schools);
          _notifySafely();

          // STEP 2: If online, refresh in background
          if (!_isOffline) {
            unawaited(_refreshInBackground());
          }
          return;
        }
      } catch (e) {
        debugLog('SchoolProvider', 'Cache read error: $e');
      }
    }

    // STEP 3: If no cache, try API (only if online)
    if (_isOffline) {
      _error = 'You are offline. No cached schools available.';
      _isLoading = false;
      _notifySafely();

      if (isManualRefresh) {
        throw Exception(
            'Network error. Please check your internet connection.');
      }
      return;
    }

    _isLoading = true;
    _error = null;
    _hasError = false;
    _notifySafely();

    try {
      debugLog('SchoolProvider', 'Loading schools');

      final response = await apiService.getSchools();

      if (response.success && response.data != null) {
        _schools = response.data ?? [];

        // Save to cache for next time
        await deviceService.saveCacheItem(AppConstants.schoolsListKey, _schools,
            ttl: _schoolsCacheTTL);
        await _loadSelectedSchool();

        debugLog('SchoolProvider', 'Loaded schools: ${_schools.length}');
        _hasError = false;
        _schoolsUpdateController.add(_schools);
      } else {
        _error = response.message;
        _hasError = true;
        debugLog('SchoolProvider', 'API error: $_error');

        if (isManualRefresh) {
          throw Exception(response.message);
        }
      }
    } catch (e) {
      _error = e.toString();
      _hasError = true;
      debugLog('SchoolProvider', 'loadSchools error: $e');

      if (isManualRefresh) {
        rethrow;
      }
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> _refreshInBackground() async {
    if (_isOffline) return;

    try {
      debugLog('SchoolProvider', '🔄 Background refresh of schools');

      final response = await apiService.getSchools();

      if (response.success && response.data != null) {
        _schools = response.data ?? [];

        await deviceService.saveCacheItem(AppConstants.schoolsListKey, _schools,
            ttl: _schoolsCacheTTL);

        _schoolsUpdateController.add(_schools);
        _notifySafely();

        debugLog('SchoolProvider', '✅ Background refresh completed');
      }
    } catch (e) {
      debugLog('SchoolProvider', '⚠️ Background refresh error: $e');
    }
  }

  Future<void> selectSchool(int schoolId) async {
    _selectedSchoolId = schoolId;

    await deviceService.saveCacheItem(AppConstants.selectedSchoolKey, schoolId,
        ttl: const Duration(days: 365));
    _selectedSchoolController.add(schoolId);
    _notifySafely();
  }

  Future<void> clearSelectedSchool() async {
    _selectedSchoolId = null;
    await deviceService.removeCacheItem(AppConstants.selectedSchoolKey);
    _selectedSchoolController.add(null);
    _notifySafely();
  }

  Future<void> _loadSelectedSchool() async {
    try {
      final selectedSchool =
          await deviceService.getCacheItem<int>(AppConstants.selectedSchoolKey);
      if (selectedSchool != null) {
        _selectedSchoolId = selectedSchool;
        _selectedSchoolController.add(selectedSchool);
      }
    } catch (e) {
      debugLog('SchoolProvider', 'Error loading selected school: $e');
    }
  }

  void clearError() {
    _error = null;
    _hasError = false;
    _notifySafely();
  }

  void retryLoadSchools() {
    clearError();
    loadSchools(forceRefresh: true);
  }

  Future<void> clearUserData() async {
    debugLog('SchoolProvider', 'Clearing school data');

    final session = UserSession();
    final isDifferentUser = !await session.isSameUser();
    final isLoggingOut = await _isLoggingOut();

    if (!isDifferentUser || !isLoggingOut) {
      debugLog('SchoolProvider', '✅ Same user - preserving school cache');
      return;
    }

    await deviceService.clearCacheByPrefix('schools');
    await deviceService.removeCacheItem(AppConstants.selectedSchoolKey);

    _schools = [];
    _selectedSchoolId = null;

    await _schoolsUpdateController.close();
    await _selectedSchoolController.close();
    _schoolsUpdateController = StreamController<List<School>>.broadcast();
    _selectedSchoolController = StreamController<int?>.broadcast();

    _schoolsUpdateController.add(_schools);
    _selectedSchoolController.add(null);
    _notifySafely();
  }

  Future<bool> _isLoggingOut() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.isLoggingOutKey) ?? false;
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
    _schoolsUpdateController.close();
    _selectedSchoolController.close();
    super.dispose();
  }
}

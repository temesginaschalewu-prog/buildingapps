import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:familyacademyclient/services/api_service.dart';
import 'package:familyacademyclient/services/device_service.dart';
import 'package:familyacademyclient/services/user_session.dart';
import 'package:familyacademyclient/models/school_model.dart';
import 'package:familyacademyclient/utils/constants.dart';
import 'package:familyacademyclient/utils/helpers.dart';

class SchoolProvider with ChangeNotifier {
  final ApiService apiService;
  final DeviceService deviceService;

  List<School> _schools = [];
  int? _selectedSchoolId;
  bool _isLoading = false;
  String? _error;
  bool _hasError = false;

  StreamController<List<School>> _schoolsUpdateController =
      StreamController<List<School>>.broadcast();
  StreamController<int?> _selectedSchoolController =
      StreamController<int?>.broadcast();

  static const Duration _schoolsCacheTTL = Duration(hours: 24);

  SchoolProvider({required this.apiService, required this.deviceService});

  List<School> get schools => List.unmodifiable(_schools);
  int? get selectedSchoolId => _selectedSchoolId;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _hasError;

  Stream<List<School>> get schoolsUpdates => _schoolsUpdateController.stream;
  Stream<int?> get selectedSchoolUpdates => _selectedSchoolController.stream;

  Future<void> loadSchools({bool forceRefresh = false}) async {
    if (_isLoading && !forceRefresh) return;

    if (!forceRefresh) {
      try {
        final cachedSchools = await deviceService
            .getCacheItem<List<School>>(AppConstants.schoolsListKey);
        if (cachedSchools != null) {
          _schools = cachedSchools;
          _hasError = false;
          _schoolsUpdateController.add(_schools);
          _notifySafely();
          return;
        }
      } catch (e) {
        debugLog('SchoolProvider', 'Cache read error: $e');
      }
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
      }
    } catch (e) {
      _error = e.toString();
      _hasError = true;
      debugLog('SchoolProvider', 'loadSchools error: $e');
    } finally {
      _isLoading = false;
      _notifySafely();
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

  School? getSchoolById(int id) {
    try {
      return _schools.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }

  /// 🔵 FIX: Clear user data ONLY for different user logout
  Future<void> clearUserData() async {
    debugLog('SchoolProvider', 'Clearing school data');

    // Only clear if this is a different user logout
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

  void clearError() {
    _error = null;
    _hasError = false;
    _notifySafely();
  }

  void retryLoadSchools() {
    clearError();
    loadSchools(forceRefresh: true);
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

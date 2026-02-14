import 'dart:async';
import 'package:flutter/material.dart';
import 'package:familyacademyclient/services/api_service.dart';
import 'package:familyacademyclient/services/device_service.dart';
import 'package:familyacademyclient/models/school_model.dart';
import 'package:familyacademyclient/utils/helpers.dart';

class SchoolProvider with ChangeNotifier {
  final ApiService apiService;
  final DeviceService deviceService;

  List<School> _schools = [];
  int? _selectedSchoolId;
  bool _isLoading = false;
  String? _error;
  bool _hasError = false;
  DateTime? _lastLoadTime;

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
      final cachedSchools =
          await deviceService.getCacheItem<List<School>>('schools_list');
      if (cachedSchools != null) {
        _schools = cachedSchools;
        _lastLoadTime = DateTime.now();
        _hasError = false;

        _schoolsUpdateController.add(_schools);

        _notifySafely();
        return;
      }
    }

    _isLoading = true;
    _error = null;
    _hasError = false;
    _notifySafely();

    try {
      debugLog('SchoolProvider', 'Loading schools');
      final response = await apiService.getSchools();
      _schools = response.data ?? [];
      _lastLoadTime = DateTime.now();

      await deviceService.saveCacheItem('schools_list', _schools,
          ttl: _schoolsCacheTTL);

      await _loadSelectedSchool();

      debugLog('SchoolProvider', 'Loaded schools: ${_schools.length}');
      _hasError = false;

      _schoolsUpdateController.add(_schools);
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

    await deviceService.saveCacheItem('selected_school', schoolId,
        ttl: Duration(days: 365));

    _selectedSchoolController.add(schoolId);

    _notifySafely();
  }

  Future<void> clearSelectedSchool() async {
    _selectedSchoolId = null;

    await deviceService.removeCacheItem('selected_school');

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

  Future<void> clearUserData() async {
    debugLog('SchoolProvider', 'Clearing school data');

    await deviceService.clearCacheByPrefix('schools');
    await deviceService.removeCacheItem('selected_school');

    _schools = [];
    _selectedSchoolId = null;
    _lastLoadTime = null;

    _schoolsUpdateController.close();
    _selectedSchoolController.close();

    _schoolsUpdateController = StreamController<List<School>>.broadcast();
    _selectedSchoolController = StreamController<int?>.broadcast();

    _schoolsUpdateController.add(_schools);
    _selectedSchoolController.add(null);

    _notifySafely();
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
    final selectedSchool =
        await deviceService.getCacheItem<int>('selected_school');
    if (selectedSchool != null) {
      _selectedSchoolId = selectedSchool;
      _selectedSchoolController.add(selectedSchool);
    }
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
    _schoolsUpdateController.close();
    _selectedSchoolController.close();
    super.dispose();
  }
}

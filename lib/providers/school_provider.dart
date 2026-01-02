import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/school_model.dart';
import '../utils/helpers.dart';

class SchoolProvider with ChangeNotifier {
  final ApiService apiService;

  List<School> _schools = [];
  int? _selectedSchoolId;
  bool _isLoading = false;
  String? _error;
  bool _hasError = false;

  SchoolProvider({required this.apiService});

  List<School> get schools => _schools;
  int? get selectedSchoolId => _selectedSchoolId;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _hasError;

  Future<void> loadSchools() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    _hasError = false;
    notifyListeners();

    try {
      debugLog('SchoolProvider', 'Loading schools');
      final response = await apiService.getSchools();
      _schools = response.data ?? [];
      debugLog('SchoolProvider', 'Loaded schools: ${_schools.length}');
      _hasError = false;
    } catch (e) {
      _error = e.toString();
      _hasError = true;
      debugLog('SchoolProvider', 'loadSchools error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectSchool(int schoolId) async {
    _selectedSchoolId = schoolId;
    notifyListeners();
  }

  School? getSchoolById(int id) {
    try {
      return _schools.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }

  void clearSchools() {
    _schools = [];
    _selectedSchoolId = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    _hasError = false;
    notifyListeners();
  }

  void retryLoadSchools() {
    clearError();
    loadSchools();
  }
}

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/category_model.dart';
import '../utils/helpers.dart';

class CategoryProvider with ChangeNotifier {
  final ApiService apiService;

  List<Category> _categories = [];
  List<Category> _activeCategories = [];
  List<Category> _comingSoonCategories = [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _error;

  CategoryProvider({required this.apiService});

  List<Category> get categories => List.unmodifiable(_categories);
  List<Category> get activeCategories => List.unmodifiable(_activeCategories);
  List<Category> get comingSoonCategories =>
      List.unmodifiable(_comingSoonCategories);
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get error => _error;

  Future<void> loadCategories({bool forceRefresh = false}) async {
    if (_isLoading && !forceRefresh) return;
    // If we already have data and not forcing refresh, just return
    if (_hasLoaded && !forceRefresh && !_isLoading) return;

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('CategoryProvider', 'Loading categories');
      final response = await apiService.getCategories();

      if (response.success && response.data != null) {
        _categories = response.data ?? [];

        // Filter categories
        _activeCategories = _categories.where((c) => c.isActive).toList();
        _comingSoonCategories =
            _categories.where((c) => c.isComingSoon).toList();

        _hasLoaded = true;
        debugLog('CategoryProvider', 'Loaded ${_categories.length} categories');
      } else {
        _error = response.message;
        debugLog('CategoryProvider',
            'Failed to load categories: ${response.message}');
      }
    } catch (e) {
      _error = e.toString();
      debugLog('CategoryProvider', 'loadCategories error: $e');
      // Don't rethrow - keep existing data
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Category? getCategoryById(int id) {
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
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

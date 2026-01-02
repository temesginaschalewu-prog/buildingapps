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
  String? _error;

  CategoryProvider({required this.apiService});

  List<Category> get categories => List.unmodifiable(_categories);
  List<Category> get activeCategories => List.unmodifiable(_activeCategories);
  List<Category> get comingSoonCategories =>
      List.unmodifiable(_comingSoonCategories);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadCategories() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('CategoryProvider', 'Loading categories');
      final response = await apiService.getCategories();
      _categories = response.data ?? [];

      // Filter categories
      _activeCategories = _categories.where((c) => c.isActive).toList();
      _comingSoonCategories = _categories.where((c) => c.isComingSoon).toList();
    } catch (e) {
      _error = e.toString();
      debugLog('CategoryProvider', 'loadCategories error: $e');
      rethrow;
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

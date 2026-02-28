# Provider Files Documentation

Generated on: Sat Feb 28 10:13:02 PM EAT 2026

## Table of Contents

- [auth_provider.dart](#auth_providerdart)
- [category_provider.dart](#category_providerdart)
- [chapter_provider.dart](#chapter_providerdart)
- [chatbot_provider.dart](#chatbot_providerdart)
- [course_provider.dart](#course_providerdart)
- [device_provider.dart](#device_providerdart)
- [exam_provider.dart](#exam_providerdart)
- [exam_question_provider.dart](#exam_question_providerdart)
- [note_provider.dart](#note_providerdart)
- [notification_provider.dart](#notification_providerdart)
- [parent_link_provider.dart](#parent_link_providerdart)
- [payment_provider.dart](#payment_providerdart)
- [progress_provider.dart](#progress_providerdart)
- [question_provider.dart](#question_providerdart)
- [school_provider.dart](#school_providerdart)
- [settings_provider.dart](#settings_providerdart)
- [streak_provider.dart](#streak_providerdart)
- [subscription_provider.dart](#subscription_providerdart)
- [theme_provider.dart](#theme_providerdart)
- [user_provider.dart](#user_providerdart)
- [video_provider.dart](#video_providerdart)

---

## auth_provider.dart

**File Path:** `lib/providers/auth_provider.dart`

```dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/device_service.dart';
import '../models/user_model.dart';
import '../utils/helpers.dart';
import '../utils/constants.dart';
import '../utils/api_response.dart';

class AuthProvider with ChangeNotifier {
  final ApiService apiService;
  final StorageService storageService;
  final DeviceService deviceService;

  User? _currentUser;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  bool _isInitializing = false;
  bool _isInitialized = false;
  bool _requiresDeviceChange = false;
  String? _error;
  Map<String, dynamic>? _lastLoginResult;

  Timer? _autoLogoutTimer;
  static const Duration _sessionDuration = Duration(days: 3);

  Timer? _tokenRefreshTimer;
  static const Duration _tokenRefreshInterval = Duration(minutes: 30);

  StreamController<bool> _authStateController =
      StreamController<bool>.broadcast();
  StreamController<User?> _userController = StreamController<User?>.broadcast();
  StreamController<bool> _deviceChangeController =
      StreamController<bool>.broadcast();
  StreamController<String?> _deviceDeactivatedController =
      StreamController<String?>.broadcast();

  List<VoidCallback> _onLogoutCallbacks = [];
  List<VoidCallback> _onLoginCallbacks = [];
  StreamSubscription? _deviceDeactivationSubscription;

  AuthProvider(
      {required this.apiService,
      required this.storageService,
      required this.deviceService}) {
    _listenToDeviceDeactivation();
  }

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing;
  bool get isInitialized => _isInitialized;
  bool get requiresDeviceChange => _requiresDeviceChange;
  String? get error => _error;
  Map<String, dynamic>? get lastLoginResult => _lastLoginResult;
  bool get isReadyForNavigation =>
      _isInitialized &&
      (!_isAuthenticated || (_isAuthenticated && _currentUser != null));

  Stream<bool> get authStateChanges => _authStateController.stream;
  Stream<User?> get userChanges => _userController.stream;
  Stream<bool> get deviceChangeRequired => _deviceChangeController.stream;
  Stream<String?> get deviceDeactivated => _deviceDeactivatedController.stream;

  void registerOnLogoutCallback(VoidCallback callback) =>
      _onLogoutCallbacks.add(callback);
  void registerOnLoginCallback(VoidCallback callback) =>
      _onLoginCallbacks.add(callback);

  void _listenToDeviceDeactivation() {
    _deviceDeactivationSubscription =
        apiService.deviceDeactivationStream.listen(
      (event) => _handleDeviceDeactivation(
          event['message'] ?? 'Device has been deactivated'),
      onError: (error) => null,
    );
  }

  Future<void> _handleDeviceDeactivation(String message) async {
    _stopTimers();
    _executeLogoutCallbacks();
    await deviceService.clearUserCache();
    await deviceService.clearCurrentUserId();
    await storageService.clearAllUserData();

    _currentUser = null;
    _isAuthenticated = false;
    _requiresDeviceChange = false;
    _error = message;
    _lastLoginResult = null;

    _deviceDeactivatedController.add(message);
    _authStateController.add(false);
    _userController.add(null);
    _deviceChangeController.add(false);
    notifyListeners();
  }

  void _stopTimers() {
    _autoLogoutTimer?.cancel();
    _tokenRefreshTimer?.cancel();
  }

  Future<void> initialize() async {
    if (_isInitializing || _isInitialized) return;

    _isInitializing = true;
    _error = null;
    notifyListeners();

    try {
      await storageService.init();
      await deviceService.init();

      final token = await storageService.getToken();
      if (token == null || token.isEmpty) {
        _completeInitialization();
        return;
      }

      if (_isOldFormatToken(token)) {
        await logout(manual: false);
        _completeInitialization();
        return;
      }

      final sessionValid =
          await storageService.isSessionValid(_sessionDuration);
      if (!sessionValid) {
        await logout(manual: false);
        _completeInitialization();
        return;
      }

      final user = await storageService.getUser();
      if (user != null) {
        _currentUser = user;
        _isAuthenticated = true;
        await deviceService.setCurrentUserId(user.id.toString());
        _startAutoLogoutTimer();
        _startTokenRefreshTimer();

        _authStateController.add(true);
        _userController.add(user);
        _executeLoginCallbacks();

        final isTokenExpiring = await _isTokenExpiringSoon(token);
        if (isTokenExpiring) unawaited(_validateTokenInBackground());
      } else {
        await logout(manual: false);
      }
    } catch (e) {
      _error = e.toString();
      await logout(manual: false);
      _authStateController.add(false);
      _userController.add(null);
    } finally {
      await Future.delayed(const Duration(milliseconds: 500));
      _completeInitialization();
    }
  }

  bool _isOldFormatToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final jsonPayload = json.decode(decoded);
      return !jsonPayload.containsKey('iss') && !jsonPayload.containsKey('aud');
    } catch (e) {
      return false;
    }
  }

  Future<bool> _isTokenExpiringSoon(String token) async {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final jsonPayload = json.decode(decoded);
      final exp = jsonPayload['exp'];
      if (exp == null) return false;
      final expiryTime = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      final hoursUntilExpiry = expiryTime.difference(DateTime.now()).inHours;
      return hoursUntilExpiry < 24;
    } catch (e) {
      return false;
    }
  }

  void _completeInitialization() {
    _isInitializing = false;
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _validateTokenInBackground() async {
    try {
      final isValid = await validateToken();
      if (!isValid) await logout(manual: false);
    } catch (e) {}
  }

  Future<Map<String, dynamic>> login(String username, String password,
      String deviceId, String? fcmToken) async {
    if (_isLoading)
      return {
        'success': false,
        'message': 'Already processing',
        'requiresDeviceChange': false
      };

    _isLoading = true;
    _error = null;
    _requiresDeviceChange = false;
    notifyListeners();

    try {
      final deviceId = await deviceService.getDeviceId();
      final response =
          await apiService.studentLogin(username, password, deviceId, fcmToken);

      if (response.success && response.data != null) {
        final userData = response.data!['user'];
        final user = User.fromJson(userData);

        await deviceService.clearUserCache();
        await deviceService.clearAllCache();

        await storageService.saveUser(user);
        await storageService.saveToken(response.data!['token']);
        if (response.data!['deviceToken'] != null) {
          await storageService.saveRefreshToken(response.data!['deviceToken']);
        }
        await storageService.saveSessionStart();

        _currentUser = user;
        _isAuthenticated = true;
        _requiresDeviceChange = false;
        _lastLoginResult = null;
        _isInitialized = true;
        _isInitializing = false;

        await deviceService.setCurrentUserId(user.id.toString());

        _startAutoLogoutTimer();
        _startTokenRefreshTimer();
        _executeLoginCallbacks();

        _authStateController.add(true);
        _userController.add(user);
        _deviceChangeController.add(false);

        return {
          'success': true,
          'message': 'Login successful',
          'user': user,
          'requiresDeviceChange': false,
          'next_step': user.schoolId == null ? 'select_school' : 'home',
        };
      } else {
        _error = response.message;
        return {
          'success': false,
          'message': response.message,
          'requiresDeviceChange': false
        };
      }
    } on ApiError catch (e) {
      _error = e.message;
      _requiresDeviceChange = e.action == 'device_change_required';

      if (_requiresDeviceChange) {
        _deviceChangeController.add(true);
        final deviceId = await deviceService.getDeviceId();
        _lastLoginResult = {
          'success': false,
          'message': e.message,
          'requiresDeviceChange': true,
          'action': e.action,
          'data': e.data,
          'username': username,
          'password': password,
          'deviceId': deviceId,
          'fcmToken': fcmToken,
        };
        return _lastLoginResult!;
      }
      return {
        'success': false,
        'message': e.message,
        'requiresDeviceChange': false,
        'action': e.action,
        'data': e.data
      };
    } catch (e) {
      _error = e.toString();
      return {
        'success': false,
        'message': 'Login failed',
        'requiresDeviceChange': false
      };
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> register(String username, String password,
      String deviceId, String? fcmToken) async {
    if (_isLoading) return {'success': false, 'message': 'Already processing'};

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final deviceId = await deviceService.getDeviceId();
      final response =
          await apiService.register(username, password, deviceId, fcmToken);

      if (response.success && response.data != null) {
        Map<String, dynamic> responseData = response.data!;
        Map<String, dynamic> userData;
        String token;

        if (responseData.containsKey('user') &&
            responseData.containsKey('token')) {
          userData = responseData['user'] as Map<String, dynamic>;
          token = responseData['token'] as String;
        } else if (responseData.containsKey('id') &&
            responseData.containsKey('username')) {
          userData = responseData;
          token = responseData['token']?.toString() ?? '';
        } else {
          throw ApiError(message: 'Invalid response format');
        }

        final user = User.fromJson(userData);
        await deviceService.clearUserCache();
        await deviceService.clearAllCache();
        await storageService.saveUser(user);
        await storageService.saveToken(token);
        await storageService.saveSessionStart();
        await storageService.markRegistrationComplete();

        _currentUser = user;
        _isAuthenticated = true;
        _requiresDeviceChange = false;
        _lastLoginResult = null;
        _isInitialized = true;
        _isInitializing = false;
        await deviceService.setCurrentUserId(user.id.toString());

        _startAutoLogoutTimer();
        _startTokenRefreshTimer();
        _executeLoginCallbacks();

        _authStateController.add(true);
        _userController.add(user);
        _deviceChangeController.add(false);

        return {
          'success': true,
          'message': 'Registration successful',
          'user': user,
          'next_step': user.schoolId == null ? 'select_school' : 'home',
        };
      } else {
        _error = response.message;
        return {'success': false, 'message': response.message};
      }
    } on ApiError catch (e) {
      _error = e.message;
      return {'success': false, 'message': e.message};
    } catch (e) {
      _error = e.toString();
      return {'success': false, 'message': 'Registration failed'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout({bool manual = true}) async {
    _stopTimers();
    _executeLogoutCallbacks();

    await deviceService.clearUserCache();
    await deviceService.clearCurrentUserId();
    await storageService.clearAllUserData();

    _currentUser = null;
    _isAuthenticated = false;
    _requiresDeviceChange = false;
    _error = null;
    _lastLoginResult = null;

    if (!manual) {
      _isInitialized = false;
      _isInitializing = false;
    }

    _authStateController.add(false);
    _userController.add(null);
    _deviceChangeController.add(false);
    notifyListeners();
  }

  void _executeLogoutCallbacks() {
    for (final callback in _onLogoutCallbacks) {
      try {
        callback();
      } catch (e) {}
    }
  }

  void _executeLoginCallbacks() {
    for (final callback in _onLoginCallbacks) {
      try {
        callback();
      } catch (e) {}
    }
  }

  void _startAutoLogoutTimer() {
    _autoLogoutTimer?.cancel();
    _autoLogoutTimer =
        Timer(_sessionDuration, () async => await logout(manual: false));
  }

  void _startTokenRefreshTimer() {
    _tokenRefreshTimer?.cancel();
    _tokenRefreshTimer = Timer.periodic(
        _tokenRefreshInterval, (timer) async => await refreshToken());
  }

  Future<void> refreshToken() async {
    try {
      final refreshToken = await storageService.getRefreshToken();
      if (refreshToken == null) return;

      final response = await apiService.dio.post(
        '/auth/refresh-token',
        data: {'refreshToken': refreshToken},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final newToken = response.data['data']['token'];
        await storageService.saveToken(newToken);
        _startAutoLogoutTimer();
      }
    } catch (e) {}
  }

  Future<bool> validateToken() async {
    try {
      final response = await apiService.validateStudentToken();
      return response.success;
    } catch (e) {
      return false;
    }
  }

  Future<User?> loadUser() async {
    try {
      final user = await storageService.getUser();
      if (user != null) {
        _currentUser = user;
        _isAuthenticated = true;
        await deviceService.setCurrentUserId(user.id.toString());
        return user;
      }
    } catch (e) {}
    return null;
  }

  Future<void> updateUser(User user) async {
    _currentUser = user;
    await storageService.saveUser(user);
    _userController.add(user);
    notifyListeners();
  }

  Future<void> updateDeviceChangeStatus(bool requiresChange) async {
    _requiresDeviceChange = requiresChange;
    _deviceChangeController.add(requiresChange);
    notifyListeners();
  }

  Future<void> clearDeviceChangeRequirement() async {
    _requiresDeviceChange = false;
    _lastLoginResult = null;
    _deviceChangeController.add(false);
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> checkSession() async {
    try {
      final sessionValid =
          await storageService.isSessionValid(_sessionDuration);
      if (!sessionValid) await logout(manual: false);
    } catch (e) {}
  }

  @override
  void dispose() {
    _stopTimers();
    _authStateController.close();
    _userController.close();
    _deviceChangeController.close();
    _deviceDeactivatedController.close();
    _deviceDeactivationSubscription?.cancel();
    _onLogoutCallbacks.clear();
    _onLoginCallbacks.clear();
    super.dispose();
  }
}
```

---

## category_provider.dart

**File Path:** `lib/providers/category_provider.dart`

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../models/category_model.dart';
import '../utils/helpers.dart';

class CategoryProvider with ChangeNotifier {
  final ApiService apiService;
  final DeviceService deviceService;

  List<Category> _categories = [];
  List<Category> _activeCategories = [];
  List<Category> _comingSoonCategories = [];
  Map<int, bool> _categorySubscriptionStatus = {};
  Map<int, bool> _categoryStatusLoaded = {};
  Map<int, DateTime> _lastSubscriptionCheck = {};

  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _error;

  Timer? _backgroundRefreshTimer;
  static const Duration _backgroundRefreshInterval = Duration(minutes: 5);
  static const Duration _cacheDuration =
      Duration(hours: 1); // Reduced to 1 hour

  final StreamController<List<Category>> _categoriesUpdateController =
      StreamController<List<Category>>.broadcast();
  final StreamController<Map<int, bool>> _subscriptionStatusController =
      StreamController<Map<int, bool>>.broadcast();

  final Map<int, Completer<bool>> _waitForCheckCompleters = {};
  bool _isSyncingSubscription = false;

  CategoryProvider({required this.apiService, required this.deviceService}) {
    _initBackgroundRefresh();
  }

  void _initBackgroundRefresh() {
    _backgroundRefreshTimer = Timer.periodic(_backgroundRefreshInterval, (_) {
      if (_hasLoaded && !_isLoading) {
        unawaited(_refreshInBackground());
      }
    });
  }

  Future<void> _refreshInBackground() async {
    debugLog('CategoryProvider', '🔄 Background refresh started');

    try {
      final response = await apiService.getCategories();

      if (response.success && response.data != null) {
        List<Category> loadedCategories = [];

        if (response.data is List<Category>) {
          loadedCategories = response.data!;
        } else if (response.data is List) {
          loadedCategories = (response.data as List)
              .map((item) => item is Category ? item : Category.fromJson(item))
              .toList();
        }

        bool hasChanges = _hasCategoryChanges(loadedCategories);

        if (hasChanges) {
          debugLog('CategoryProvider', '📦 Changes detected, updating cache');
          _categories = loadedCategories;
          _updateCategoryLists();

          // Log image URLs for debugging
          for (var cat in _categories) {
            if (cat.imageUrl != null) {
              debugLog('CategoryProvider',
                  '📸 ${cat.name} has image: ${cat.imageUrl}');
            }
          }

          await deviceService.saveCacheItem(
              'categories',
              {
                'categories': _categories.map((c) => c.toJson()).toList(),
                'timestamp': DateTime.now().toIso8601String(),
              },
              ttl: _cacheDuration,
              isUserSpecific: true);

          _categoriesUpdateController.add(_categories);
          _notifySafely();
        }
      }
    } catch (e) {
      debugLog('CategoryProvider', '⚠️ Background refresh failed: $e');
    }
  }

  bool _hasCategoryChanges(List<Category> newCategories) {
    if (_categories.length != newCategories.length) return true;

    for (int i = 0; i < newCategories.length; i++) {
      if (_categories[i].id != newCategories[i].id ||
          _categories[i].name != newCategories[i].name ||
          _categories[i].status != newCategories[i].status ||
          _categories[i].imageUrl != newCategories[i].imageUrl) {
        // Check image URL changes
        return true;
      }
    }

    return false;
  }

  List<Category> get categories => List.unmodifiable(_categories);
  List<Category> get activeCategories => List.unmodifiable(_activeCategories);
  List<Category> get comingSoonCategories =>
      List.unmodifiable(_comingSoonCategories);
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get error => _error;
  bool get isSyncingSubscription => _isSyncingSubscription;

  Stream<List<Category>> get categoriesUpdates =>
      _categoriesUpdateController.stream;
  Stream<Map<int, bool>> get subscriptionStatusUpdates =>
      _subscriptionStatusController.stream;

  bool getCategorySubscriptionStatus(int categoryId) {
    return _categorySubscriptionStatus[categoryId] ?? false;
  }

  bool isCategoryStatusLoaded(int categoryId) {
    return _categoryStatusLoaded[categoryId] ?? false;
  }

  bool shouldCheckSubscription(int categoryId) {
    final lastCheck = _lastSubscriptionCheck[categoryId];
    if (lastCheck == null) return true;
    return DateTime.now().difference(lastCheck).inMinutes > 15;
  }

  Future<void> loadCategories({bool forceRefresh = false}) async {
    if (_isLoading && !forceRefresh) return;

    if (_hasLoaded && !forceRefresh && _categories.isNotEmpty) {
      debugLog('CategoryProvider', '📦 Using cached categories');
      return;
    }

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('CategoryProvider', '📥 Loading categories');

      if (!forceRefresh) {
        final cachedData =
            await deviceService.getCacheItem<Map<String, dynamic>>('categories',
                isUserSpecific: true);

        if (cachedData != null && cachedData['categories'] is List) {
          final categoriesList = cachedData['categories'] as List;
          _categories = categoriesList.map<Category>((item) {
            try {
              if (item is Category) return item;
              if (item is Map<String, dynamic>) return Category.fromJson(item);
              return Category(
                id: 0,
                name: 'Unknown',
                status: 'active',
                billingCycle: 'monthly',
              );
            } catch (e) {
              debugLog('CategoryProvider', 'Error parsing cached category: $e');
              return Category(
                id: 0,
                name: 'Unknown',
                status: 'active',
                billingCycle: 'monthly',
              );
            }
          }).toList();

          _updateCategoryLists();
          _hasLoaded = true;
          _isLoading = false;

          // Log cached image URLs
          for (var cat in _categories) {
            if (cat.imageUrl != null) {
              debugLog('CategoryProvider',
                  '📸 [CACHED] ${cat.name} image: ${cat.imageUrl}');
            }
          }

          _categoriesUpdateController.add(_categories);
          _notifySafely();

          debugLog('CategoryProvider',
              '✅ Loaded ${_categories.length} categories from cache');

          unawaited(_refreshInBackground());
          return;
        }
      }

      final response = await apiService.getCategories();

      if (response.success && response.data != null) {
        List<Category> loadedCategories = [];

        if (response.data is List<Category>) {
          loadedCategories = response.data ?? [];
        } else if (response.data is List) {
          loadedCategories = (response.data as List).map<Category>((item) {
            if (item is Category) return item;
            if (item is Map<String, dynamic>) return Category.fromJson(item);
            return Category(
              id: 0,
              name: 'Unknown',
              status: 'active',
              billingCycle: 'monthly',
            );
          }).toList();
        }

        _categories = loadedCategories;
        _updateCategoryLists();

        // Log image URLs from API
        for (var cat in _categories) {
          if (cat.imageUrl != null) {
            debugLog('CategoryProvider',
                '📸 [API] ${cat.name} image: ${cat.imageUrl}');
          } else {
            debugLog('CategoryProvider', '📸 [API] ${cat.name} has NO image');
          }
        }

        await deviceService.saveCacheItem(
            'categories',
            {
              'categories': _categories.map((c) => c.toJson()).toList(),
              'timestamp': DateTime.now().toIso8601String(),
            },
            ttl: _cacheDuration,
            isUserSpecific: true);

        _hasLoaded = true;
        _categoriesUpdateController.add(_categories);

        debugLog(
            'CategoryProvider', '✅ Loaded ${_categories.length} categories');
      } else {
        _error = response.message;
        debugLog('CategoryProvider',
            '❌ Failed to load categories: ${response.message}');
      }
    } catch (e) {
      _error = e.toString();
      debugLog('CategoryProvider', '❌ loadCategories error: $e');
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  void _updateCategoryLists() {
    _activeCategories = _categories.where((c) => c.isActive).toList();
    _comingSoonCategories = _categories.where((c) => c.isComingSoon).toList();
  }

  Future<void> loadCategoriesWithSubscriptionCheck(
      {bool forceRefresh = false}) async {
    await loadCategories(forceRefresh: forceRefresh);

    if (_activeCategories.isNotEmpty) {
      debugLog('CategoryProvider',
          '🔍 Will check subscription status for ${_activeCategories.length} active categories');

      for (final category in _activeCategories) {
        if (shouldCheckSubscription(category.id)) {
          unawaited(_refreshCategorySubscription(category.id));
        }
      }
    }
  }

  Future<void> _refreshCategorySubscription(int categoryId) async {}

  Future<void> syncSubscriptionStatus(Map<int, bool> subscriptionStatus) async {
    if (_isSyncingSubscription) return;

    _isSyncingSubscription = true;

    try {
      debugLog('CategoryProvider',
          '🔄 Syncing subscription status for ${subscriptionStatus.length} categories');

      final now = DateTime.now();
      subscriptionStatus.forEach((categoryId, hasSubscription) {
        _categorySubscriptionStatus[categoryId] = hasSubscription;
        _categoryStatusLoaded[categoryId] = true;
        _lastSubscriptionCheck[categoryId] = now;

        if (_waitForCheckCompleters.containsKey(categoryId)) {
          _waitForCheckCompleters[categoryId]!.complete(hasSubscription);
          _waitForCheckCompleters.remove(categoryId);
        }
      });

      _subscriptionStatusController.add(subscriptionStatus);
      _notifySafely();

      debugLog('CategoryProvider',
          '✅ Subscription status synced for ${subscriptionStatus.length} categories');
    } finally {
      _isSyncingSubscription = false;
    }
  }

  Future<void> batchUpdateSubscriptionStatus(Map<int, bool> statusMap) async {
    if (statusMap.isEmpty) {
      debugLog('CategoryProvider', '⚠️ Received empty status map');
      return;
    }

    debugLog('CategoryProvider',
        '📥 Received batch update for ${statusMap.length} categories');

    final now = DateTime.now();

    statusMap.forEach((categoryId, hasSubscription) {
      _categorySubscriptionStatus[categoryId] = hasSubscription;
      _categoryStatusLoaded[categoryId] = true;
      _lastSubscriptionCheck[categoryId] = now;

      if (_waitForCheckCompleters.containsKey(categoryId)) {
        _waitForCheckCompleters[categoryId]!.complete(hasSubscription);
        _waitForCheckCompleters.remove(categoryId);
      }
    });

    _subscriptionStatusController.add(Map.from(statusMap));
    _notifySafely();

    debugLog('CategoryProvider',
        '✅ Batch updated ${statusMap.length} category subscription statuses');
  }

  Future<void> updateCategorySubscriptionStatus(
      int categoryId, bool hasSubscription) async {
    _categorySubscriptionStatus[categoryId] = hasSubscription;
    _categoryStatusLoaded[categoryId] = true;
    _lastSubscriptionCheck[categoryId] = DateTime.now();

    if (_waitForCheckCompleters.containsKey(categoryId)) {
      _waitForCheckCompleters[categoryId]!.complete(hasSubscription);
      _waitForCheckCompleters.remove(categoryId);
    }

    _subscriptionStatusController.add({categoryId: hasSubscription});
    _notifySafely();

    debugLog('CategoryProvider',
        'Updated category $categoryId subscription status: $hasSubscription');
  }

  Category? getCategoryById(int id) {
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<bool> waitForSubscriptionCheck(int categoryId,
      {Duration timeout = const Duration(seconds: 10)}) async {
    if (_categoryStatusLoaded[categoryId] == true) {
      return _categorySubscriptionStatus[categoryId] ?? false;
    }

    if (!_waitForCheckCompleters.containsKey(categoryId)) {
      _waitForCheckCompleters[categoryId] = Completer<bool>();
    }

    Future.delayed(timeout, () {
      if (!_waitForCheckCompleters[categoryId]!.isCompleted) {
        _waitForCheckCompleters[categoryId]!.complete(false);
        debugLog('CategoryProvider',
            '⏰ Subscription check timeout for category $categoryId');
      }
    });

    return await _waitForCheckCompleters[categoryId]!.future;
  }

  Future<bool> verifyCategoryAccess(int categoryId,
      {bool forceCheck = false}) async {
    if (!forceCheck &&
        _categoryStatusLoaded[categoryId] == true &&
        !shouldCheckSubscription(categoryId)) {
      return _categorySubscriptionStatus[categoryId] ?? false;
    }

    _categoryStatusLoaded[categoryId] = false;
    _notifySafely();

    return await waitForSubscriptionCheck(categoryId);
  }

  void clearError() {
    _error = null;
    _notifySafely();
  }

  Future<void> clearUserData() async {
    debugLog('CategoryProvider', '🧹 Clearing category data');

    await deviceService.clearCacheByPrefix('categories');

    _categories.clear();
    _activeCategories.clear();
    _comingSoonCategories.clear();
    _categorySubscriptionStatus.clear();
    _categoryStatusLoaded.clear();
    _lastSubscriptionCheck.clear();
    _hasLoaded = false;
    _isSyncingSubscription = false;
    _waitForCheckCompleters.clear();

    _categoriesUpdateController.add([]);
    _subscriptionStatusController.add({});
    _notifySafely();
  }

  @override
  void dispose() {
    _backgroundRefreshTimer?.cancel();
    _categoriesUpdateController.close();
    _subscriptionStatusController.close();
    _waitForCheckCompleters.clear();
    super.dispose();
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
```

---

## chapter_provider.dart

**File Path:** `lib/providers/chapter_provider.dart`

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../models/chapter_model.dart';
import '../utils/helpers.dart';

class ChapterProvider with ChangeNotifier {
  final ApiService apiService;
  final DeviceService deviceService;

  List<Chapter> _chapters = [];
  Map<int, List<Chapter>> _chaptersByCourse = {};
  Map<int, bool> _hasLoadedForCourse = {};
  Map<int, bool> _isLoadingForCourse = {};
  Map<int, DateTime> _lastLoadedTime = {};
  bool _isLoading = false;
  String? _error;

  StreamController<Map<int, List<Chapter>>> _chaptersUpdateController =
      StreamController<Map<int, List<Chapter>>>.broadcast();

  static const Duration cacheDuration = Duration(minutes: 15);

  ChapterProvider({required this.apiService, required this.deviceService});

  List<Chapter> get chapters => _chapters;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Stream<Map<int, List<Chapter>>> get chaptersUpdates =>
      _chaptersUpdateController.stream;

  bool hasLoadedForCourse(int courseId) =>
      _hasLoadedForCourse[courseId] ?? false;
  bool isLoadingForCourse(int courseId) =>
      _isLoadingForCourse[courseId] ?? false;

  List<Chapter> getChaptersByCourse(int courseId) {
    return _chaptersByCourse[courseId] ?? [];
  }

  List<Chapter> getFreeChaptersByCourse(int courseId) {
    final chapters = _chaptersByCourse[courseId] ?? [];
    return chapters.where((c) => c.isFree).toList();
  }

  List<Chapter> getLockedChaptersByCourse(int courseId) {
    final chapters = _chaptersByCourse[courseId] ?? [];
    return chapters.where((c) => c.isLocked).toList();
  }

  Future<void> loadChaptersByCourse(int courseId,
      {bool forceRefresh = false}) async {
    if (_isLoadingForCourse[courseId] == true) {
      return;
    }

    final lastLoaded = _lastLoadedTime[courseId];
    final hasCache = _hasLoadedForCourse[courseId] == true;
    final isCacheValid = lastLoaded != null &&
        DateTime.now().difference(lastLoaded) < cacheDuration;

    if (hasCache && !forceRefresh && isCacheValid) {
      debugLog(
          'ChapterProvider', '✅ Using cached chapters for course: $courseId');
      return;
    }

    if (!forceRefresh) {
      final cachedChapters = await deviceService
          .getCacheItem<List<Chapter>>('chapters_course_$courseId');
      if (cachedChapters != null) {
        _chaptersByCourse[courseId] = cachedChapters;
        _hasLoadedForCourse[courseId] = true;
        _lastLoadedTime[courseId] = DateTime.now();

        _addToGlobalList(cachedChapters);

        _chaptersUpdateController.add({courseId: cachedChapters});

        debugLog('ChapterProvider',
            '✅ Loaded ${cachedChapters.length} chapters from cache for course $courseId');
        return;
      }
    }

    _isLoadingForCourse[courseId] = true;
    _error = null;

    try {
      debugLog('ChapterProvider', '📚 Loading chapters for course: $courseId');
      final response = await apiService.getChaptersByCourse(courseId);

      final responseData = response.data ?? {};
      final chaptersData =
          responseData['chapters'] ?? responseData['data'] ?? [];

      if (chaptersData is List) {
        final loadedChapters =
            List<Chapter>.from(chaptersData.map((x) => Chapter.fromJson(x)));

        _chaptersByCourse[courseId] = loadedChapters;
        _hasLoadedForCourse[courseId] = true;
        _lastLoadedTime[courseId] = DateTime.now();

        await deviceService.saveCacheItem(
            'chapters_course_$courseId', loadedChapters,
            ttl: cacheDuration);

        _addToGlobalList(loadedChapters);

        debugLog('ChapterProvider',
            '✅ Loaded ${loadedChapters.length} chapters for course $courseId');

        _chaptersUpdateController.add({courseId: loadedChapters});
      } else {
        _chaptersByCourse[courseId] = [];
        _hasLoadedForCourse[courseId] = true;
        _lastLoadedTime[courseId] = DateTime.now();

        await deviceService.saveCacheItem('chapters_course_$courseId', [],
            ttl: cacheDuration);

        _chaptersUpdateController.add({courseId: []});
      }
    } catch (e) {
      _error = e.toString();
      debugLog('ChapterProvider', '❌ loadChaptersByCourse error: $e');

      if (!_hasLoadedForCourse[courseId]!) {
        _chaptersByCourse[courseId] = [];
        _hasLoadedForCourse[courseId] = true;
        _lastLoadedTime[courseId] = DateTime.now();
      }

      _chaptersUpdateController.add({courseId: []});
    } finally {
      _isLoadingForCourse[courseId] = false;
      _isLoading = false;
      _notifySafely();
    }
  }

  void _addToGlobalList(List<Chapter> newChapters) {
    for (final chapter in newChapters) {
      if (!_chapters.any((c) => c.id == chapter.id)) {
        _chapters.add(chapter);
      }
    }
  }

  Chapter? getChapterById(int id) {
    try {
      return _chapters.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> clearChaptersForCourse(int courseId) async {
    _hasLoadedForCourse.remove(courseId);
    _lastLoadedTime.remove(courseId);

    final courseChapters = _chaptersByCourse[courseId] ?? [];
    _chapters.removeWhere(
        (chapter) => courseChapters.any((c) => c.id == chapter.id));
    _chaptersByCourse.remove(courseId);

    await deviceService.removeCacheItem('chapters_course_$courseId');

    _chaptersUpdateController.add({courseId: []});

    _notifySafely();
  }

  Future<void> clearUserData() async {
    debugLog('ChapterProvider', 'Clearing chapter data');

    await deviceService.clearCacheByPrefix('chapters_course_');

    _chapters.clear();
    _chaptersByCourse.clear();
    _hasLoadedForCourse.clear();
    _lastLoadedTime.clear();
    _isLoadingForCourse.clear();

    _chaptersUpdateController.close();
    _chaptersUpdateController =
        StreamController<Map<int, List<Chapter>>>.broadcast();

    _chaptersUpdateController.add({});

    _notifySafely();
  }

  Future<void> clearAllChapters() async {
    await deviceService.clearCacheByPrefix('chapters_course_');

    _chapters.clear();
    _chaptersByCourse.clear();
    _hasLoadedForCourse.clear();
    _lastLoadedTime.clear();
    _isLoadingForCourse.clear();

    _chaptersUpdateController.add({});

    _notifySafely();
  }

  Future<void> clearError() async {
    _error = null;
    _notifySafely();
  }

  @override
  void dispose() {
    _chaptersUpdateController.close();
    super.dispose();
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
```

---

## chatbot_provider.dart

**File Path:** `lib/providers/chatbot_provider.dart`

```dart
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/chatbot_model.dart';
import '../utils/helpers.dart';
import '../utils/api_response.dart';

class ChatbotProvider extends ChangeNotifier {
  final ApiService apiService;

  List<ChatbotMessage> _messages = [];
  List<ChatbotConversation> _conversations = [];
  ChatbotConversation? _currentConversation;

  bool _isLoading = false;
  bool _isLoadingMessages = false;
  bool _isLoadingConversations = false;
  String? _error;

  int _remainingMessages = 30;
  int _dailyLimit = 30;
  int _totalMessages = 0;
  int _totalConversations = 0;

  int _currentPage = 1;
  bool _hasMoreConversations = true;
  bool _isLoadingMore = false;

  ChatbotProvider({required this.apiService}) {
    loadConversations();
    loadUsageStats();
  }

  List<ChatbotMessage> get messages => List.unmodifiable(_messages);
  List<ChatbotConversation> get conversations =>
      List.unmodifiable(_conversations);
  ChatbotConversation? get currentConversation => _currentConversation;

  bool get isLoading => _isLoading;
  bool get isLoadingMessages => _isLoadingMessages;
  bool get isLoadingConversations => _isLoadingConversations;
  String? get error => _error;

  int get remainingMessages => _remainingMessages;
  int get dailyLimit => _dailyLimit;
  bool get hasMessagesLeft => _remainingMessages > 0;
  int get totalMessages => _totalMessages;
  int get totalConversations => _totalConversations;

  bool get hasMoreConversations => _hasMoreConversations;

  Future<void> loadUsageStats() async {
    try {
      final response = await apiService.dio.get('/chatbot/usage');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final stats = ChatbotUsageStats.fromJson(response.data['data']);
        _remainingMessages = stats.remaining;
        _dailyLimit = stats.limit;
        _totalMessages = stats.totalMessages;
        _totalConversations = stats.totalConversations;
        debugLog('ChatbotProvider',
            '📊 Usage stats loaded: $_remainingMessages/$_dailyLimit');
        notifyListeners();
      }
    } catch (e) {
      debugLog('ChatbotProvider', 'Error loading usage stats: $e');
    }
  }

  Future<void> loadConversations({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMoreConversations = true;
      _conversations.clear();
    }

    if (_isLoadingConversations || !_hasMoreConversations) return;

    _isLoadingConversations = true;
    _isLoadingMore = _currentPage > 1;
    notifyListeners();

    try {
      final response = await apiService.dio.get(
        '/chatbot/conversations',
        queryParameters: {'page': _currentPage, 'limit': 20},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'];
        final newConversations =
            data.map((json) => ChatbotConversation.fromJson(json)).toList();

        if (refresh) {
          _conversations = newConversations;
        } else {
          _conversations.addAll(newConversations);
        }

        final pagination = response.data['pagination'] ?? {};
        final totalPages = pagination['pages'] ?? 1;
        _hasMoreConversations = _currentPage < totalPages;

        if (_hasMoreConversations) {
          _currentPage++;
        }

        debugLog('ChatbotProvider',
            '📋 Loaded ${newConversations.length} conversations');
      }
    } catch (e) {
      _error = 'Failed to load conversations';
      debugLog('ChatbotProvider', 'Error loading conversations: $e');
    } finally {
      _isLoadingConversations = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> loadMessages(int conversationId) async {
    _isLoadingMessages = true;
    _error = null;
    notifyListeners();

    try {
      final response = await apiService.dio.get(
        '/chatbot/conversations/$conversationId/messages',
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'];
        _messages = data.map((json) => ChatbotMessage.fromJson(json)).toList();

        _currentConversation = _conversations.firstWhere(
          (c) => c.id == conversationId,
          orElse: () => ChatbotConversation(
            id: conversationId,
            title: 'Conversation',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            messageCount: _messages.length,
          ),
        );

        debugLog('ChatbotProvider', '💬 Loaded ${_messages.length} messages');

        WidgetsBinding.instance.addPostFrameCallback((_) {
          notifyListeners();
        });
      }
    } catch (e) {
      _error = 'Failed to load messages';
      debugLog('ChatbotProvider', 'Error loading messages: $e');
    } finally {
      _isLoadingMessages = false;
      notifyListeners();
    }
  }

  List<T> _takeLast<T>(Iterable<T> items, int n) {
    final list = items.toList();
    if (list.isEmpty) return [];
    if (list.length <= n) return list;
    return list.sublist(list.length - n);
  }

  Future<Map<String, dynamic>> sendMessage(
    String message, {
    int? conversationId,
  }) async {
    if (message.trim().isEmpty) {
      return {'success': false, 'error': 'Message cannot be empty'};
    }

    if (!hasMessagesLeft) {
      return {
        'success': false,
        'error': 'Daily message limit reached. Please try again tomorrow.',
      };
    }

    _isLoading = true;
    _error = null;

    final tempUserMessage = ChatbotMessage(
      id: DateTime.now().millisecondsSinceEpoch,
      role: 'user',
      content: message,
      timestamp: DateTime.now(),
    );
    _messages.add(tempUserMessage);
    notifyListeners();

    try {
      final List<String> history = [];
      if (_messages.length > 1) {
        for (int i = 0; i < _messages.length - 1; i++) {
          if (_messages[i].id < 1000000) {
            history.add(_messages[i].content);
          }
        }

        if (history.length > 10) {
          history.removeRange(0, history.length - 10);
        }
      }

      final response = await apiService.dio.post(
        '/chatbot/chat',
        data: {
          'message': message,
          'conversation_id': conversationId,
          'history': history,
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];

        final aiMessage = ChatbotMessage(
          id: DateTime.now().millisecondsSinceEpoch + 1,
          role: 'assistant',
          content: data['reply'],
          timestamp: DateTime.now(),
        );
        _messages.add(aiMessage);

        if (data['remaining'] != null) {
          _remainingMessages = data['remaining'];
          debugLog(
              'ChatbotProvider', '📊 Updated remaining: $_remainingMessages');
        }

        loadUsageStats();

        if (conversationId == null && data['conversation_id'] != null) {
          await loadConversations(refresh: true);
        }

        notifyListeners();

        return {
          'success': true,
          'reply': data['reply'],
          'conversationId': data['conversation_id'],
          'suggestedQuestions': data['suggested_questions'] ?? [],
        };
      } else {
        throw Exception(response.data['message'] ?? 'Failed to send message');
      }
    } catch (e) {
      _messages.remove(tempUserMessage);

      _error = 'Failed to send message: $e';
      debugLog('ChatbotProvider', 'Error sending message: $e');

      return {'success': false, 'error': _error};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> renameConversation(int conversationId, String title) async {
    try {
      final response = await apiService.dio.put(
        '/chatbot/conversations/$conversationId',
        data: {'title': title},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final index = _conversations.indexWhere((c) => c.id == conversationId);
        if (index != -1) {
          _conversations[index] = ChatbotConversation(
            id: _conversations[index].id,
            title: title,
            createdAt: _conversations[index].createdAt,
            updatedAt: DateTime.now(),
            lastMessage: _conversations[index].lastMessage,
            lastMessageRole: _conversations[index].lastMessageRole,
            messageCount: _conversations[index].messageCount,
          );
        }

        if (_currentConversation?.id == conversationId) {
          _currentConversation = ChatbotConversation(
            id: _currentConversation!.id,
            title: title,
            createdAt: _currentConversation!.createdAt,
            updatedAt: DateTime.now(),
            lastMessage: _currentConversation!.lastMessage,
            lastMessageRole: _currentConversation!.lastMessageRole,
            messageCount: _currentConversation!.messageCount,
          );
        }

        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugLog('ChatbotProvider', 'Error renaming conversation: $e');
      return false;
    }
  }

  Future<bool> deleteConversation(int conversationId) async {
    try {
      final response = await apiService.dio.delete(
        '/chatbot/conversations/$conversationId',
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        _conversations.removeWhere((c) => c.id == conversationId);

        if (_currentConversation?.id == conversationId) {
          _currentConversation = null;
          _messages.clear();
        }

        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugLog('ChatbotProvider', 'Error deleting conversation: $e');
      return false;
    }
  }

  void clearCurrentConversation() {
    _messages.clear();
    _currentConversation = null;
    notifyListeners();
  }

  Future<void> loadMoreConversations() async {
    if (!_hasMoreConversations || _isLoadingMore) return;
    await loadConversations();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    super.dispose();
  }
}
```

---

## course_provider.dart

**File Path:** `lib/providers/course_provider.dart`

```dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../models/course_model.dart';
import '../utils/helpers.dart';

class CourseProvider with ChangeNotifier {
  final ApiService apiService;
  final DeviceService deviceService;

  List<Course> _courses = [];
  Map<int, List<Course>> _coursesByCategory = {};
  Map<int, bool> _hasLoadedCategory = {};
  Map<int, bool> _isLoadingCategory = {};
  Map<int, DateTime> _lastLoadedTime = {};
  bool _isLoading = false;
  String? _error;

  static const Duration _cacheDuration = Duration(minutes: 10);

  CourseProvider({required this.apiService, required this.deviceService});

  List<Course> get courses => List.unmodifiable(_courses);
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Course> getCoursesByCategory(int categoryId) {
    return _coursesByCategory[categoryId] ?? [];
  }

  bool hasLoadedCategory(int categoryId) {
    return _hasLoadedCategory[categoryId] ?? false;
  }

  bool isLoadingCategory(int categoryId) {
    return _isLoadingCategory[categoryId] ?? false;
  }

  Future<void> loadCoursesByCategory(int categoryId,
      {bool forceRefresh = false, bool? hasAccess}) async {
    if (_isLoadingCategory[categoryId] == true && !forceRefresh) {
      return;
    }

    if (!forceRefresh && _hasLoadedCategory[categoryId] == true) {
      final lastLoaded = _lastLoadedTime[categoryId];
      if (lastLoaded != null &&
          DateTime.now().difference(lastLoaded) < _cacheDuration) {
        debugLog('CourseProvider',
            '✅ Using cached courses for category: $categoryId');
        return;
      }
    }

    _isLoadingCategory[categoryId] = true;
    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('CourseProvider', 'Loading courses for category: $categoryId');

      if (!forceRefresh) {
        final cachedCourses = await deviceService
            .getCacheItem<List<Course>>('courses_$categoryId');
        if (cachedCourses != null) {
          _coursesByCategory[categoryId] = cachedCourses;
          _hasLoadedCategory[categoryId] = true;
          _lastLoadedTime[categoryId] = DateTime.now();
          _updateMainCoursesList(cachedCourses);
          debugLog('CourseProvider',
              '✅ Loaded ${cachedCourses.length} courses from cache for category $categoryId');
          return;
        }
      }

      final response = await apiService.getCoursesByCategory(categoryId);

      final responseData = response.data ?? {};
      final categoryData = responseData['category'] ?? {};
      final coursesData = responseData['courses'] ?? [];

      bool categoryHasAccess =
          hasAccess ?? (categoryData['has_access'] ?? false);

      if (coursesData is List) {
        List<Course> parsedCourses = [];

        for (var courseData in coursesData) {
          try {
            if (courseData is Map<String, dynamic>) {
              final course = Course.fromJson(courseData);

              parsedCourses.add(Course(
                id: course.id,
                name: course.name,
                categoryId: course.categoryId,
                description: course.description,
                chapterCount: course.chapterCount,
                access: categoryHasAccess ? 'full' : 'limited',
                message: categoryHasAccess
                    ? 'Full access to all content'
                    : 'Limited access to free chapters only',
                hasPendingPayment: false,
                requiresPayment: !categoryHasAccess,
              ));
            }
          } catch (e) {
            debugLog('CourseProvider',
                'Error parsing course: $e, data: $courseData');
          }
        }

        await deviceService.saveCacheItem('courses_$categoryId', parsedCourses,
            ttl: _cacheDuration);

        _coursesByCategory[categoryId] = parsedCourses;
        _hasLoadedCategory[categoryId] = true;
        _lastLoadedTime[categoryId] = DateTime.now();

        _updateMainCoursesList(parsedCourses);

        debugLog('CourseProvider',
            '✅ Parsed ${parsedCourses.length} courses for category $categoryId, access: $categoryHasAccess');

        if (parsedCourses.isEmpty) {
          debugLog(
              'CourseProvider', '⚠️ No courses found for category $categoryId');
        }
      } else {
        debugLog('CourseProvider',
            'Courses data is not a list: ${coursesData.runtimeType}');
        _coursesByCategory[categoryId] = [];
        _hasLoadedCategory[categoryId] = true;
        _lastLoadedTime[categoryId] = DateTime.now();
      }
    } catch (e) {
      _error = e.toString();
      debugLog('CourseProvider', 'loadCoursesByCategory error: $e');

      if (!(_hasLoadedCategory[categoryId] ?? false)) {
        _coursesByCategory[categoryId] = [];
        _hasLoadedCategory[categoryId] = true;
        _lastLoadedTime[categoryId] = DateTime.now();
      }
    } finally {
      _isLoadingCategory[categoryId] = false;
      _isLoading = false;
      _notifySafely();
    }
  }

  void _updateMainCoursesList(List<Course> newCourses) {
    final currentIds = _courses.map((c) => c.id).toSet();
    for (final course in newCourses) {
      if (!currentIds.contains(course.id)) {
        _courses.add(course);
      }
    }
  }

  Future<void> refreshCoursesWithAccessCheck(
      int categoryId, bool hasAccess) async {
    try {
      debugLog('CourseProvider',
          'Refreshing courses for category $categoryId with access: $hasAccess');

      await deviceService.removeCacheItem('courses_$categoryId');

      _coursesByCategory.remove(categoryId);
      _hasLoadedCategory.remove(categoryId);
      _isLoadingCategory.remove(categoryId);
      _lastLoadedTime.remove(categoryId);

      await loadCoursesByCategory(categoryId,
          forceRefresh: true, hasAccess: hasAccess);

      debugLog('CourseProvider', '✅ Courses refreshed with access: $hasAccess');
    } catch (e) {
      debugLog('CourseProvider', 'refreshCoursesWithAccessCheck error: $e');
    }
  }

  Course? getCourseById(int id) {
    try {
      return _courses.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> clearUserData() async {
    debugLog('CourseProvider', 'Clearing course data');

    for (final categoryId in _coursesByCategory.keys) {
      await deviceService.removeCacheItem('courses_$categoryId');
    }

    _courses.clear();
    _coursesByCategory.clear();
    _hasLoadedCategory.clear();
    _isLoadingCategory.clear();
    _lastLoadedTime.clear();

    _notifySafely();
  }

  void clearCoursesForCategory(int categoryId) async {
    await deviceService.removeCacheItem('courses_$categoryId');

    final categoryCourses = _coursesByCategory[categoryId] ?? [];
    _courses
        .removeWhere((course) => categoryCourses.any((c) => c.id == course.id));

    _coursesByCategory.remove(categoryId);
    _hasLoadedCategory.remove(categoryId);
    _isLoadingCategory.remove(categoryId);
    _lastLoadedTime.remove(categoryId);

    _notifySafely();
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
```

---

## device_provider.dart

**File Path:** `lib/providers/device_provider.dart`

```dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class DeviceProvider with ChangeNotifier {
  final ApiService apiService;
  final DeviceService deviceService;

  String? _deviceId;
  String? _tvDeviceId;
  String? _pairingCode;
  DateTime? _pairingExpiresAt;
  bool _isPairing = false;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;

  DeviceProvider(
      {required this.apiService, required DeviceService deviceService})
      : deviceService = DeviceService() {
    _initializeAsync();
  }

  String? get deviceId => _deviceId;
  String? get tvDeviceId => _tvDeviceId;
  String? get pairingCode => _pairingCode;
  DateTime? get pairingExpiresAt => _pairingExpiresAt;
  bool get isPairing => _isPairing;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  bool get hasTvDevice => _tvDeviceId != null && _tvDeviceId!.isNotEmpty;
  bool get isPairingExpired => _pairingExpiresAt == null
      ? true
      : DateTime.now().isAfter(_pairingExpiresAt!);

  Future<void> _initializeAsync() async {
    try {
      await deviceService.init();
      _deviceId = await deviceService.getDeviceId();
      _tvDeviceId = await deviceService.getTvDeviceId();
      await _loadPairingCode();
      _isInitialized = true;
    } catch (e) {
      _error = e.toString();
    }
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _initializeAsync();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadPairingCode() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('pairing_code');
    final expiresAt = prefs.getInt('pairing_expires_at');

    if (code != null && expiresAt != null) {
      _pairingCode = code;
      _pairingExpiresAt = DateTime.fromMillisecondsSinceEpoch(expiresAt);
      _isPairing = true;
    }
  }

  Future<void> _savePairingCode(String code, int expiresInSeconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pairing_code', code);
    await prefs.setInt(
      'pairing_expires_at',
      DateTime.now()
          .add(Duration(seconds: expiresInSeconds))
          .millisecondsSinceEpoch,
    );

    _pairingCode = code;
    _pairingExpiresAt = DateTime.now().add(Duration(seconds: expiresInSeconds));
    _isPairing = true;
    notifyListeners();
  }

  Future<void> pairTvDevice(String tvDeviceId) async {
    if (!_isInitialized) await initialize();

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await apiService.pairTvDevice(tvDeviceId);
      final data = response.data!;

      final code = data['pairing_code'];
      final expiresIn = data['expires_in'] ?? 600;

      await _savePairingCode(code, expiresIn);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> verifyTvPairing(String code) async {
    if (!_isInitialized) await initialize();

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await apiService.verifyTvPairing(code);
      final data = response.data!;

      await deviceService.saveTvDeviceId(data['tv_device_id']);
      _tvDeviceId = data['tv_device_id'];

      await _clearPairingState();
      await apiService.updateDevice('tv', data['tv_device_id']);

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> unpairTvDevice() async {
    if (!_isInitialized) await initialize();

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await apiService.unpairTvDevice();
      await deviceService.clearTvDeviceId();
      _tvDeviceId = null;
      await apiService.updateDevice('tv', '');
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _clearPairingState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pairing_code');
    await prefs.remove('pairing_expires_at');

    _pairingCode = null;
    _pairingExpiresAt = null;
    _isPairing = false;
    notifyListeners();
  }

  Future<void> cancelPairing() async {
    await _clearPairingState();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<Map<String, dynamic>> getDeviceInfo() async {
    if (!_isInitialized) await initialize();
    try {
      return await deviceService.getDeviceInfo();
    } catch (e) {
      return {};
    }
  }

  Future<void> clearUserData() async {
    _tvDeviceId = null;
    _pairingCode = null;
    _pairingExpiresAt = null;
    _isPairing = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pairing_code');
    await prefs.remove('pairing_expires_at');
    await deviceService.clearTvDeviceId();

    notifyListeners();
  }
}
```

---

## exam_provider.dart

**File Path:** `lib/providers/exam_provider.dart`

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../models/exam_model.dart';
import '../models/exam_result_model.dart';
import '../models/payment_model.dart';
import '../utils/helpers.dart';

class ExamProvider with ChangeNotifier {
  final ApiService apiService;
  final DeviceService deviceService;

  List<Exam> _availableExams = [];
  List<ExamResult> _myExamResults = [];
  Map<int, List<Exam>> _examsByCourse = {};
  Map<int, DateTime> _lastLoadedTime = {};
  Map<int, bool> _isLoadingCourse = {};
  bool _isLoading = false;
  String? _error;
  Timer? _cacheCleanupTimer;

  // NEW: Track pending payments per category
  Map<int, bool> _pendingPaymentsByCategory = {};

  StreamController<List<Exam>> _examsUpdateController =
      StreamController<List<Exam>>.broadcast();
  StreamController<List<ExamResult>> _resultsUpdateController =
      StreamController<List<ExamResult>>.broadcast();

  static const Duration _cacheDuration = Duration(hours: 1);
  static const Duration _cacheCleanupInterval = Duration(minutes: 30);

  ExamProvider({required this.apiService, required this.deviceService}) {
    _cacheCleanupTimer = Timer.periodic(_cacheCleanupInterval, (_) {
      _cleanupExpiredCache();
    });
  }

  List<Exam> get availableExams => List.unmodifiable(_availableExams);
  List<ExamResult> get myExamResults => List.unmodifiable(_myExamResults);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Stream<List<Exam>> get examsUpdates => _examsUpdateController.stream;
  Stream<List<ExamResult>> get resultsUpdates =>
      _resultsUpdateController.stream;

  List<Exam> getExamsByCourse(int courseId) {
    return List.unmodifiable(_examsByCourse[courseId] ?? []);
  }

  bool isLoadingCourse(int courseId) => _isLoadingCourse[courseId] ?? false;

  // NEW: Update pending payments status for exams
  Future<void> updatePendingPayments(Map<int, bool> pendingStatus) async {
    debugLog(
        'ExamProvider', '🔄 Updating pending payments status: $pendingStatus');

    _pendingPaymentsByCategory.addAll(pendingStatus);

    // Update all exams with new pending payment status
    bool hasChanges = false;

    for (int i = 0; i < _availableExams.length; i++) {
      final exam = _availableExams[i];
      final hasPending = _pendingPaymentsByCategory[exam.categoryId] ?? false;

      if (exam.hasPendingPayment != hasPending) {
        _availableExams[i] = Exam(
          id: exam.id,
          title: exam.title,
          examType: exam.examType,
          startDate: exam.startDate,
          endDate: exam.endDate,
          duration: exam.duration,
          userTimeLimit: exam.userTimeLimit,
          passingScore: exam.passingScore,
          maxAttempts: exam.maxAttempts,
          autoSubmit: exam.autoSubmit,
          showResultsImmediately: exam.showResultsImmediately,
          courseName: exam.courseName,
          courseId: exam.courseId,
          categoryId: exam.categoryId,
          categoryName: exam.categoryName,
          categoryStatus: exam.categoryStatus,
          attemptsTaken: exam.attemptsTaken,
          lastAttemptStatus: exam.lastAttemptStatus,
          questionCount: exam.questionCount,
          status: exam.status,
          message: exam.message,
          canTakeExam: exam.canTakeExam,
          requiresPayment: exam.requiresPayment,
          hasAccess: exam.hasAccess,
          actualDuration: exam.actualDuration,
          timingType: exam.timingType,
          hasPendingPayment: hasPending,
        );
        hasChanges = true;
      }
    }

    // Update course-specific exams
    for (final courseId in _examsByCourse.keys) {
      final courseExams = _examsByCourse[courseId]!;
      for (int i = 0; i < courseExams.length; i++) {
        final exam = courseExams[i];
        final hasPending = _pendingPaymentsByCategory[exam.categoryId] ?? false;

        if (exam.hasPendingPayment != hasPending) {
          courseExams[i] = Exam(
            id: exam.id,
            title: exam.title,
            examType: exam.examType,
            startDate: exam.startDate,
            endDate: exam.endDate,
            duration: exam.duration,
            userTimeLimit: exam.userTimeLimit,
            passingScore: exam.passingScore,
            maxAttempts: exam.maxAttempts,
            autoSubmit: exam.autoSubmit,
            showResultsImmediately: exam.showResultsImmediately,
            courseName: exam.courseName,
            courseId: exam.courseId,
            categoryId: exam.categoryId,
            categoryName: exam.categoryName,
            categoryStatus: exam.categoryStatus,
            attemptsTaken: exam.attemptsTaken,
            lastAttemptStatus: exam.lastAttemptStatus,
            questionCount: exam.questionCount,
            status: exam.status,
            message: exam.message,
            canTakeExam: exam.canTakeExam,
            requiresPayment: exam.requiresPayment,
            hasAccess: exam.hasAccess,
            actualDuration: exam.actualDuration,
            timingType: exam.timingType,
            hasPendingPayment: hasPending,
          );
          hasChanges = true;
        }
      }
    }

    if (hasChanges) {
      _examsUpdateController.add(_availableExams);
      _notifySafely();
      debugLog('ExamProvider', '✅ Updated exams with pending payment status');
    }
  }

  Future<void> loadAvailableExams(
      {int? courseId, bool forceRefresh = false}) async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('ExamProvider', 'Loading available exams for course: $courseId');

      if (courseId == null) {
        final cachedExams =
            await deviceService.getCacheItem<List<Exam>>('available_exams');
        if (cachedExams != null && !forceRefresh) {
          _availableExams = cachedExams;
          // Apply pending payment status to cached exams
          _applyPendingPaymentStatus();
          _isLoading = false;
          _examsUpdateController.add(_availableExams);
          debugLog('ExamProvider',
              '✅ Loaded ${_availableExams.length} exams from cache');
          return;
        }
      } else {
        final cachedExams = await deviceService
            .getCacheItem<List<Exam>>('exams_course_$courseId');
        if (cachedExams != null && !forceRefresh) {
          _examsByCourse[courseId] = cachedExams;
          _updateGlobalExams(cachedExams);
          _lastLoadedTime[courseId] = DateTime.now();
          _applyPendingPaymentStatus();
          _isLoading = false;
          _examsUpdateController.add(_availableExams);
          debugLog('ExamProvider',
              '✅ Loaded ${cachedExams.length} exams for course $courseId from cache');
          return;
        }
      }

      final response = await apiService.getAvailableExams(courseId: courseId);

      if (response.success && response.data != null) {
        final exams = response.data!;

        if (courseId == null) {
          _availableExams = exams;
          _applyPendingPaymentStatus();
          await deviceService.saveCacheItem('available_exams', exams,
              ttl: _cacheDuration);
        } else {
          _examsByCourse[courseId] = exams;
          _updateGlobalExams(exams);
          _lastLoadedTime[courseId] = DateTime.now();
          _applyPendingPaymentStatus();
          await deviceService.saveCacheItem('exams_course_$courseId', exams,
              ttl: _cacheDuration);
        }

        debugLog('ExamProvider', 'Loaded ${exams.length} exams');
        _examsUpdateController.add(exams);
      } else {
        debugLog('ExamProvider', 'No exams data received: ${response.message}');
        _availableExams = [];
        _error = response.message;
      }
    } catch (e, stackTrace) {
      _error = 'Failed to load exams: ${e.toString()}';
      debugLog('ExamProvider', 'loadAvailableExams error: $e');
      _availableExams = [];
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  // NEW: Apply pending payment status to all exams
  void _applyPendingPaymentStatus() {
    for (int i = 0; i < _availableExams.length; i++) {
      final exam = _availableExams[i];
      final hasPending = _pendingPaymentsByCategory[exam.categoryId] ?? false;

      if (hasPending) {
        _availableExams[i] = Exam(
          id: exam.id,
          title: exam.title,
          examType: exam.examType,
          startDate: exam.startDate,
          endDate: exam.endDate,
          duration: exam.duration,
          userTimeLimit: exam.userTimeLimit,
          passingScore: exam.passingScore,
          maxAttempts: exam.maxAttempts,
          autoSubmit: exam.autoSubmit,
          showResultsImmediately: exam.showResultsImmediately,
          courseName: exam.courseName,
          courseId: exam.courseId,
          categoryId: exam.categoryId,
          categoryName: exam.categoryName,
          categoryStatus: exam.categoryStatus,
          attemptsTaken: exam.attemptsTaken,
          lastAttemptStatus: exam.lastAttemptStatus,
          questionCount: exam.questionCount,
          status: exam.status,
          message: exam.message,
          canTakeExam: exam.canTakeExam,
          requiresPayment: exam.requiresPayment,
          hasAccess: exam.hasAccess,
          actualDuration: exam.actualDuration,
          timingType: exam.timingType,
          hasPendingPayment: true,
        );
      }
    }

    for (final courseId in _examsByCourse.keys) {
      final courseExams = _examsByCourse[courseId]!;
      for (int i = 0; i < courseExams.length; i++) {
        final exam = courseExams[i];
        final hasPending = _pendingPaymentsByCategory[exam.categoryId] ?? false;

        if (hasPending) {
          courseExams[i] = Exam(
            id: exam.id,
            title: exam.title,
            examType: exam.examType,
            startDate: exam.startDate,
            endDate: exam.endDate,
            duration: exam.duration,
            userTimeLimit: exam.userTimeLimit,
            passingScore: exam.passingScore,
            maxAttempts: exam.maxAttempts,
            autoSubmit: exam.autoSubmit,
            showResultsImmediately: exam.showResultsImmediately,
            courseName: exam.courseName,
            courseId: exam.courseId,
            categoryId: exam.categoryId,
            categoryName: exam.categoryName,
            categoryStatus: exam.categoryStatus,
            attemptsTaken: exam.attemptsTaken,
            lastAttemptStatus: exam.lastAttemptStatus,
            questionCount: exam.questionCount,
            status: exam.status,
            message: exam.message,
            canTakeExam: exam.canTakeExam,
            requiresPayment: exam.requiresPayment,
            hasAccess: exam.hasAccess,
            actualDuration: exam.actualDuration,
            timingType: exam.timingType,
            hasPendingPayment: true,
          );
        }
      }
    }
  }

  void _updateGlobalExams(List<Exam> exams) {
    for (final exam in exams) {
      final index = _availableExams.indexWhere((e) => e.id == exam.id);
      if (index == -1) {
        _availableExams.add(exam);
      } else {
        _availableExams[index] = exam;
      }
    }
  }

  Future<void> loadMyExamResults({bool forceRefresh = false}) async {
    if (_isLoading && !forceRefresh) {
      debugLog('ExamProvider', 'Already loading, skipping');
      return;
    }

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('ExamProvider', 'Loading my exam results');

      if (!forceRefresh) {
        final cachedResults = await deviceService
            .getCacheItem<List<ExamResult>>('my_exam_results');
        if (cachedResults != null && cachedResults.isNotEmpty) {
          _myExamResults = cachedResults;
          _isLoading = false;
          _resultsUpdateController.add(_myExamResults);
          notifyListeners();
          debugLog('ExamProvider',
              '✅ Loaded ${_myExamResults.length} exam results from cache');
          return;
        }
      }

      final response = await apiService.getMyExamResults();

      if (response.success) {
        if (response.data is List) {
          _myExamResults = response.data as List<ExamResult>;
          debugLog('ExamProvider',
              '✅ Parsed ${_myExamResults.length} exam results from List');
        } else if (response.data is Map &&
            (response.data as Map).containsKey('data')) {
          final dataList = (response.data as Map)['data'];
          if (dataList is List) {
            _myExamResults =
                dataList.map((item) => ExamResult.fromJson(item)).toList();
            debugLog('ExamProvider',
                '✅ Parsed ${_myExamResults.length} exam results from data field');
          }
        } else {
          _myExamResults = [];
        }

        await deviceService.saveCacheItem('my_exam_results', _myExamResults,
            ttl: _cacheDuration);

        _resultsUpdateController.add(_myExamResults);
        notifyListeners();

        debugLog('ExamProvider',
            '✅ Final exam results count: ${_myExamResults.length}');
      } else {
        _error = response.message;
        _myExamResults = [];
      }
    } catch (e, stackTrace) {
      _error = 'Failed to load exam results: ${e.toString()}';
      debugLog('ExamProvider', '❌ loadMyExamResults error: $e');
      _myExamResults = [];
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> loadExamsByCourse(int courseId,
      {bool forceRefresh = false}) async {
    if (_isLoadingCourse[courseId] == true && !forceRefresh) return;

    if (!forceRefresh) {
      final cachedExams = await deviceService
          .getCacheItem<List<Exam>>('exams_course_$courseId');
      if (cachedExams != null) {
        _examsByCourse[courseId] = cachedExams;
        _updateGlobalExams(cachedExams);
        _lastLoadedTime[courseId] = DateTime.now();
        _applyPendingPaymentStatus();
        _examsUpdateController.add(_availableExams);
        debugLog('ExamProvider',
            '✅ Loaded ${cachedExams.length} exams for course $courseId from cache');
        return;
      }
    }

    _isLoadingCourse[courseId] = true;
    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('ExamProvider', 'Loading exams for course: $courseId');
      final response = await apiService.getAvailableExams(courseId: courseId);

      if (response.success) {
        final exams = response.data ?? [];
        _examsByCourse[courseId] = exams;
        _updateGlobalExams(exams);
        _lastLoadedTime[courseId] = DateTime.now();
        _applyPendingPaymentStatus();

        await deviceService.saveCacheItem('exams_course_$courseId', exams,
            ttl: _cacheDuration);

        _examsUpdateController.add(_availableExams);
      } else {
        _error = response.message;
        _examsByCourse[courseId] = [];
      }
    } catch (e) {
      _error = 'Failed to load exams for course: ${e.toString()}';
      debugLog('ExamProvider', 'loadExamsByCourse error: $e');
      _examsByCourse[courseId] = [];
    } finally {
      _isLoadingCourse[courseId] = false;
      _isLoading = false;
      _notifySafely();
    }
  }

  Exam? getExamById(int id) {
    try {
      return _availableExams.firstWhere((exam) => exam.id == id);
    } catch (e) {
      return null;
    }
  }

  ExamResult? getExamResultById(int id) {
    try {
      return _myExamResults.firstWhere((result) => result.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> _cleanupExpiredCache() async {
    debugLog('ExamProvider', '🔄 Cleaning up expired exam cache');
    final now = DateTime.now();

    final expiredCourses = <int>[];
    for (final entry in _lastLoadedTime.entries) {
      if (now.difference(entry.value) > _cacheDuration) {
        expiredCourses.add(entry.key);
      }
    }

    for (final courseId in expiredCourses) {
      await deviceService.removeCacheItem('exams_course_$courseId');
      _examsByCourse.remove(courseId);
      _lastLoadedTime.remove(courseId);
      _isLoadingCourse.remove(courseId);
    }

    if (expiredCourses.isNotEmpty) {
      _examsUpdateController.add(_availableExams);
      debugLog('ExamProvider',
          '🧹 Cleared cache for ${expiredCourses.length} expired courses');
    }
  }

  Future<void> clearUserData() async {
    debugLog('ExamProvider', 'Clearing exam data');

    await deviceService.removeCacheItem('available_exams');
    await deviceService.removeCacheItem('my_exam_results');

    final courseIds = _examsByCourse.keys.toList();
    for (final courseId in courseIds) {
      await deviceService.removeCacheItem('exams_course_$courseId');
    }

    _availableExams = [];
    _examsByCourse = {};
    _myExamResults = [];
    _lastLoadedTime = {};
    _isLoadingCourse = {};
    _pendingPaymentsByCategory.clear();

    _examsUpdateController.close();
    _resultsUpdateController.close();

    _examsUpdateController = StreamController<List<Exam>>.broadcast();
    _resultsUpdateController = StreamController<List<ExamResult>>.broadcast();

    _examsUpdateController.add(_availableExams);
    _resultsUpdateController.add(_myExamResults);

    _notifySafely();
  }

  void clearExamsForCourse(int courseId) async {
    await deviceService.removeCacheItem('exams_course_$courseId');

    final courseExams = _examsByCourse[courseId] ?? [];
    _availableExams
        .removeWhere((exam) => courseExams.any((e) => e.id == exam.id));

    _examsByCourse.remove(courseId);
    _lastLoadedTime.remove(courseId);
    _isLoadingCourse.remove(courseId);

    _examsUpdateController.add(_availableExams);

    _notifySafely();
  }

  void clearError() {
    _error = null;
    _notifySafely();
  }

  @override
  void dispose() {
    _cacheCleanupTimer?.cancel();
    _examsUpdateController.close();
    _resultsUpdateController.close();
    super.dispose();
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
```

---

## exam_question_provider.dart

**File Path:** `lib/providers/exam_question_provider.dart`

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:familyacademyclient/providers/exam_provider.dart';
import 'package:familyacademyclient/providers/subscription_provider.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../models/exam_question_model.dart';
import '../utils/helpers.dart';
import '../utils/api_response.dart';
import '../utils/constants.dart';

class ExamQuestionProvider with ChangeNotifier {
  final ApiService apiService;
  final DeviceService deviceService;
  BuildContext? _context;

  List<ExamQuestion> _examQuestions = [];
  Map<int, List<ExamQuestion>> _questionsByExam = {};
  Map<int, DateTime> _lastLoadedTime = {};
  Map<int, bool> _isLoadingExam = {};
  Map<int, bool> _examAccessChecked = {};
  Map<int, bool> _examHasAccess = {};
  bool _isLoading = false;
  String? _error;
  Timer? _cacheCleanupTimer;

  StreamController<Map<int, List<ExamQuestion>>> _questionsUpdateController =
      StreamController<Map<int, List<ExamQuestion>>>.broadcast();
  StreamController<Map<int, bool>> _examAccessController =
      StreamController<Map<int, bool>>.broadcast();

  static const Duration _cacheDuration = Duration(minutes: 30);
  static const Duration _cacheCleanupInterval = Duration(minutes: 15);
  static const Duration _accessCheckTTL = Duration(minutes: 5);

  ExamQuestionProvider({
    required this.apiService,
    required this.deviceService,
  }) {
    _cacheCleanupTimer = Timer.periodic(_cacheCleanupInterval, (_) {
      _cleanupExpiredCache();
    });
  }

  void setContext(BuildContext context) {
    if (_context == null) {
      _context = context;
      debugLog('ExamQuestionProvider', '✅ Context set');
    }
  }

  List<ExamQuestion> get examQuestions => List.unmodifiable(_examQuestions);
  bool get isLoading => _isLoading;
  String? get error => _error;
  Stream<Map<int, List<ExamQuestion>>> get questionsUpdates =>
      _questionsUpdateController.stream;
  Stream<Map<int, bool>> get examAccessUpdates => _examAccessController.stream;

  bool hasExamAccess(int examId) => _examHasAccess[examId] ?? false;
  bool isExamAccessChecked(int examId) => _examAccessChecked[examId] ?? false;
  bool isLoadingExam(int examId) => _isLoadingExam[examId] ?? false;

  List<ExamQuestion> getQuestionsByExam(int examId) {
    return List.unmodifiable(_questionsByExam[examId] ?? []);
  }

  Future<bool> checkExamAccess(int examId, {bool forceCheck = false}) async {
    final lastChecked = _examAccessChecked[examId];
    if (lastChecked == true && !forceCheck) {
      final hasAccess = _examHasAccess[examId] ?? false;
      debugLog('ExamQuestionProvider',
          'Using cached access for exam $examId: $hasAccess');
      return hasAccess;
    }

    _examAccessChecked[examId] = true;
    _notifySafely();

    try {
      debugLog('ExamQuestionProvider', 'Checking access for exam: $examId');

      BuildContext? checkContext = _context;

      if (checkContext == null || !checkContext.mounted) {
        debugLog('ExamQuestionProvider',
            'Context not available, assuming access for now');
        _examHasAccess[examId] = true;
        _examAccessController.add({examId: true});
        return true;
      }

      final examProvider =
          Provider.of<ExamProvider>(checkContext, listen: false);
      final exam = examProvider.getExamById(examId);

      if (exam == null) {
        debugLog('ExamQuestionProvider', 'Exam not found: $examId');
        _examHasAccess[examId] = false;
        _examAccessController.add({examId: false});
        return false;
      }

      final subscriptionProvider =
          Provider.of<SubscriptionProvider>(checkContext, listen: false);

      debugLog('ExamQuestionProvider',
          'Checking subscription for category: ${exam.categoryId}');

      final hasAccess = await subscriptionProvider
          .checkHasActiveSubscriptionForCategory(exam.categoryId);

      _examHasAccess[examId] = hasAccess;
      _examAccessController.add({examId: hasAccess});

      debugLog('ExamQuestionProvider',
          'Exam $examId access check result: $hasAccess');

      return hasAccess;
    } on ApiError catch (e) {
      debugLog('ExamQuestionProvider',
          'Access check error for exam $examId: ${e.message}');
      _examHasAccess[examId] = false;
      _examAccessController.add({examId: false});
      return false;
    } catch (e) {
      debugLog('ExamQuestionProvider',
          'Unexpected access check error for exam $examId: $e');
      _examHasAccess[examId] = false;
      _examAccessController.add({examId: false});
      return false;
    } finally {
      _notifySafely();
    }
  }

  Future<void> loadExamQuestions(int examId,
      {bool forceRefresh = false, bool checkAccess = true}) async {
    if (_isLoadingExam[examId] == true && !forceRefresh) return;

    if (checkAccess) {
      final hasAccess = await checkExamAccess(examId, forceCheck: forceRefresh);
      if (!hasAccess) {
        debugLog('ExamQuestionProvider',
            'No access to exam $examId, skipping question load');
        return;
      }
    }

    if (!forceRefresh) {
      final cachedQuestions = await _getCachedExamQuestions(examId);
      if (cachedQuestions != null && cachedQuestions.isNotEmpty) {
        _questionsByExam[examId] = cachedQuestions;
        _updateGlobalQuestions(cachedQuestions);
        _lastLoadedTime[examId] = DateTime.now();
        _questionsUpdateController.add({examId: cachedQuestions});
        debugLog('ExamQuestionProvider',
            '✅ Loaded ${cachedQuestions.length} questions from cache for exam $examId');
        return;
      }
    }

    _isLoadingExam[examId] = true;
    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('ExamQuestionProvider', 'Loading questions for exam: $examId');
      final response = await apiService.getExamQuestions(examId);

      debugLog(
          'ExamQuestionProvider', 'API Response success: ${response.success}');
      debugLog('ExamQuestionProvider',
          'API Response data type: ${response.data.runtimeType}');

      List<ExamQuestion> questions = [];

      // ✅ CRITICAL FIX: Directly use the response.data if it's already a List
      if (response.data is List) {
        final items = response.data as List;
        debugLog('ExamQuestionProvider',
            'Response is direct List with ${items.length} items');

        // The items should already be ExamQuestion objects from ApiService
        questions = items.whereType<ExamQuestion>().toList();
        debugLog('ExamQuestionProvider',
            '✅ Directly got ${questions.length} ExamQuestion objects');
      }
      // If it's a Map, try to extract the data
      else if (response.data is Map<String, dynamic>) {
        final dataMap = response.data as Map<String, dynamic>;
        debugLog('ExamQuestionProvider',
            'Response is Map with keys: ${dataMap.keys}');

        if (dataMap.containsKey('data') && dataMap['data'] is List) {
          final items = dataMap['data'] as List;
          debugLog('ExamQuestionProvider',
              'Found data list with ${items.length} items');

          for (var item in items) {
            if (item is Map<String, dynamic>) {
              try {
                final examQuestion = ExamQuestion(
                  id: item['id'] ?? 0,
                  examId: examId,
                  questionId: item['id'] ?? item['exam_question_id'] ?? 0,
                  displayOrder: item['display_order'] ?? 0,
                  marks: item['marks'] ?? 1,
                  questionText: item['question_text']?.toString() ?? '',
                  optionA: item['option_a']?.toString(),
                  optionB: item['option_b']?.toString(),
                  optionC: item['option_c']?.toString(),
                  optionD: item['option_d']?.toString(),
                  optionE: item['option_e']?.toString(),
                  optionF: item['option_f']?.toString(),
                  difficulty: (item['difficulty']?.toString() ?? 'medium')
                      .toLowerCase(),
                  hasAnswer: item['correct_option'] != null &&
                      (item['correct_option']?.toString() ?? '').isNotEmpty,
                );
                questions.add(examQuestion);
                debugLog('ExamQuestionProvider',
                    'Added question ${questions.length} from data field');
              } catch (e) {
                debugLog(
                    'ExamQuestionProvider', 'Error parsing question item: $e');
              }
            }
          }
        }
      }

      debugLog('ExamQuestionProvider',
          '✅ Successfully processed ${questions.length} questions for exam $examId');

      // Save to cache if we have questions
      if (questions.isNotEmpty) {
        await _cacheExamQuestions(examId, questions);
      } else {
        debugLog('ExamQuestionProvider',
            '⚠️ No questions parsed from response for exam $examId');

        // Try to use cached questions as fallback
        final cachedQuestions = await _getCachedExamQuestions(examId);
        if (cachedQuestions != null && cachedQuestions.isNotEmpty) {
          questions = cachedQuestions;
          debugLog(
              'ExamQuestionProvider', '✅ Using cached questions as fallback');
        }
      }

      // ALWAYS update the state
      _questionsByExam[examId] = questions;
      _updateGlobalQuestions(questions);
      _lastLoadedTime[examId] = DateTime.now();
      _questionsUpdateController.add({examId: questions});

      debugLog('ExamQuestionProvider',
          '📊 Final questions for exam $examId: ${questions.length} items');
    } on ApiError catch (e) {
      _error = e.message;
      debugLog(
          'ExamQuestionProvider', '❌ loadExamQuestions error: ${e.message}');

      final cachedQuestions = await _getCachedExamQuestions(examId);
      if (cachedQuestions != null && cachedQuestions.isNotEmpty) {
        _questionsByExam[examId] = cachedQuestions;
        _updateGlobalQuestions(cachedQuestions);
        debugLog(
            'ExamQuestionProvider', '✅ Fallback to cached questions on error');
        _questionsUpdateController.add({examId: cachedQuestions});
      } else {
        _questionsByExam[examId] = [];
        _questionsUpdateController.add({examId: []});
      }
    } catch (e, stackTrace) {
      _error = e.toString();
      debugLog('ExamQuestionProvider', '❌ Unexpected error: $e');
      debugLog('ExamQuestionProvider', 'Stack trace: $stackTrace');

      final cachedQuestions = await _getCachedExamQuestions(examId);
      if (cachedQuestions != null && cachedQuestions.isNotEmpty) {
        _questionsByExam[examId] = cachedQuestions;
        _updateGlobalQuestions(cachedQuestions);
        debugLog('ExamQuestionProvider',
            '✅ Fallback to cached questions on unexpected error');
        _questionsUpdateController.add({examId: cachedQuestions});
      } else {
        _questionsByExam[examId] = [];
        _questionsUpdateController.add({examId: []});
      }
    } finally {
      _isLoadingExam[examId] = false;
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<List<ExamQuestion>?> _getCachedExamQuestions(int examId) async {
    try {
      final cached = await deviceService
          .getCacheItem<List<Map<String, dynamic>>>('exam_questions_$examId',
              isUserSpecific: true);
      if (cached != null) {
        return cached.map((item) => ExamQuestion.fromJson(item)).toList();
      }
    } catch (e) {
      debugLog('ExamQuestionProvider', 'Error reading cached questions: $e');
    }
    return null;
  }

  Future<void> _cacheExamQuestions(
      int examId, List<ExamQuestion> questions) async {
    try {
      final questionsJson = questions.map((q) => q.toJson()).toList();
      await deviceService.saveCacheItem(
        'exam_questions_$examId',
        questionsJson,
        ttl: _cacheDuration,
        isUserSpecific: true,
      );
    } catch (e) {
      debugLog('ExamQuestionProvider', 'Error caching questions: $e');
    }
  }

  void _updateGlobalQuestions(List<ExamQuestion> questions) {
    for (final question in questions) {
      final index = _examQuestions.indexWhere((q) => q.id == question.id);
      if (index == -1) {
        _examQuestions.add(question);
      } else {
        _examQuestions[index] = question;
      }
    }
  }

  Future<void> clearExamAccessCache(int examId) async {
    _examAccessChecked.remove(examId);
    _examHasAccess.remove(examId);
    await deviceService.removeCacheItem('exam_access_$examId',
        isUserSpecific: true);
    _notifySafely();
  }

  Future<void> refreshAllExamAccess() async {
    debugLog('ExamQuestionProvider', 'Refreshing all exam access');
    _examAccessChecked.clear();
    _examHasAccess.clear();

    await deviceService.clearCacheByPrefix('exam_access_');

    _examAccessController.add({});
    _notifySafely();
  }

  Future<Map<String, dynamic>> saveExamProgress(
    int examResultId,
    List<Map<String, dynamic>> answers,
  ) async {
    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('ExamQuestionProvider',
          'Saving progress for exam result: $examResultId');
      final response = await apiService.saveExamProgress(examResultId, answers);
      return response.data ?? {};
    } catch (e) {
      _error = e.toString();
      debugLog('ExamQuestionProvider', 'saveExamProgress error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  ExamQuestion? getQuestionById(int id) {
    try {
      return _examQuestions.firstWhere((q) => q.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> _cleanupExpiredCache() async {
    debugLog(
        'ExamQuestionProvider', '🔄 Cleaning up expired exam question cache');
    final now = DateTime.now();
    final expiredExams = <int>[];

    for (final entry in _lastLoadedTime.entries) {
      if (now.difference(entry.value) > _cacheDuration) {
        expiredExams.add(entry.key);
      }
    }

    for (final examId in expiredExams) {
      await deviceService.removeCacheItem('exam_questions_$examId',
          isUserSpecific: true);
      _questionsByExam.remove(examId);
      _lastLoadedTime.remove(examId);
      _isLoadingExam.remove(examId);
      _examAccessChecked.remove(examId);
      _examHasAccess.remove(examId);
    }

    if (expiredExams.isNotEmpty) {
      _questionsUpdateController.add({});
      _examAccessController.add({});
      debugLog('ExamQuestionProvider',
          '🧹 Cleared cache for ${expiredExams.length} expired exams');
    }
  }

  Future<void> clearUserData() async {
    debugLog('ExamQuestionProvider', 'Clearing exam question data');

    final keys = _questionsByExam.keys.toList();
    for (final examId in keys) {
      await deviceService.removeCacheItem('exam_questions_$examId',
          isUserSpecific: true);
      await deviceService.removeCacheItem('exam_access_$examId',
          isUserSpecific: true);
    }

    _examQuestions.clear();
    _questionsByExam.clear();
    _lastLoadedTime.clear();
    _isLoadingExam.clear();
    _examAccessChecked.clear();
    _examHasAccess.clear();

    _questionsUpdateController.close();
    _examAccessController.close();

    _questionsUpdateController =
        StreamController<Map<int, List<ExamQuestion>>>.broadcast();
    _examAccessController = StreamController<Map<int, bool>>.broadcast();

    _questionsUpdateController.add({});
    _examAccessController.add({});

    _notifySafely();
  }

  void clearExamQuestionsForExam(int examId) async {
    await deviceService.removeCacheItem('exam_questions_$examId',
        isUserSpecific: true);
    await deviceService.removeCacheItem('exam_access_$examId',
        isUserSpecific: true);

    final examQuestions = _questionsByExam[examId] ?? [];
    _examQuestions.removeWhere(
        (question) => examQuestions.any((q) => q.id == question.id));

    _questionsByExam.remove(examId);
    _lastLoadedTime.remove(examId);
    _isLoadingExam.remove(examId);
    _examAccessChecked.remove(examId);
    _examHasAccess.remove(examId);

    _questionsUpdateController.add({examId: []});
    _examAccessController.add({examId: false});

    _notifySafely();
  }

  void clearError() {
    _error = null;
    _notifySafely();
  }

  @override
  void dispose() {
    _cacheCleanupTimer?.cancel();
    _questionsUpdateController.close();
    _examAccessController.close();
    super.dispose();
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

  int min(int a, int b) => a < b ? a : b;
}
```

---

## note_provider.dart

**File Path:** `lib/providers/note_provider.dart`

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../models/note_model.dart';
import '../utils/helpers.dart';

class NoteProvider with ChangeNotifier {
  final ApiService apiService;
  final DeviceService deviceService;

  List<Note> _notes = [];
  Map<int, List<Note>> _notesByChapter = {};
  Map<int, bool> _hasLoadedForChapter = {};
  Map<int, bool> _isLoadingForChapter = {};
  Map<int, DateTime> _lastLoadedTime = {};
  Map<int, bool> _noteViewedStatus = {};
  bool _isLoading = false;
  String? _error;

  StreamController<Map<String, dynamic>> _noteUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();

  static const Duration cacheDuration = Duration(minutes: 15);
  static const Duration viewedCacheDuration = Duration(days: 30);

  NoteProvider({required this.apiService, required this.deviceService});

  List<Note> get notes => _notes;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Stream<Map<String, dynamic>> get noteUpdates => _noteUpdateController.stream;

  bool hasLoadedForChapter(int chapterId) =>
      _hasLoadedForChapter[chapterId] ?? false;
  bool isLoadingForChapter(int chapterId) =>
      _isLoadingForChapter[chapterId] ?? false;

  List<Note> getNotesByChapter(int chapterId) {
    return _notesByChapter[chapterId] ?? [];
  }

  Future<void> loadNotesByChapter(int chapterId,
      {bool forceRefresh = false}) async {
    if (_isLoadingForChapter[chapterId] == true) {
      return;
    }

    final lastLoaded = _lastLoadedTime[chapterId];
    final hasCache = _hasLoadedForChapter[chapterId] == true;
    final isCacheValid = lastLoaded != null &&
        DateTime.now().difference(lastLoaded) < cacheDuration;

    if (hasCache && !forceRefresh && isCacheValid) {
      debugLog('NoteProvider', '✅ Using cached notes for chapter: $chapterId');
      return;
    }

    _isLoadingForChapter[chapterId] = true;
    _error = null;
    notifyListeners();

    try {
      debugLog('NoteProvider', '📝 Loading notes for chapter: $chapterId');
      final response = await apiService.getNotesByChapter(chapterId);

      final responseData = response.data ?? {};
      final notesData = responseData['notes'] ?? [];

      if (notesData is List) {
        final noteList = <Note>[];
        for (var noteJson in notesData) {
          try {
            noteList.add(Note.fromJson(noteJson));
          } catch (e) {
            debugLog('NoteProvider', 'Error parsing note: $e, data: $noteJson');
          }
        }

        _notesByChapter[chapterId] = noteList;
        _hasLoadedForChapter[chapterId] = true;
        _lastLoadedTime[chapterId] = DateTime.now();

        for (final note in noteList) {
          if (!_notes.any((n) => n.id == note.id)) {
            _notes.add(note);
          }
        }

        await deviceService.saveCacheItem(
          'notes_chapter_$chapterId',
          noteList.map((n) => n.toJson()).toList(),
          ttl: cacheDuration,
        );

        await _loadViewedStatus(chapterId);

        debugLog('NoteProvider',
            '✅ Loaded ${noteList.length} notes for chapter $chapterId');

        _noteUpdateController.add({
          'type': 'notes_loaded',
          'chapter_id': chapterId,
          'count': noteList.length
        });
      } else {
        _notesByChapter[chapterId] = [];
        _hasLoadedForChapter[chapterId] = true;
        _lastLoadedTime[chapterId] = DateTime.now();
      }
    } catch (e) {
      _error = e.toString();
      debugLog('NoteProvider', '❌ loadNotesByChapter error: $e');

      try {
        final cachedNotes = await deviceService
            .getCacheItem<List<dynamic>>('notes_chapter_$chapterId');
        if (cachedNotes != null) {
          final noteList = <Note>[];
          for (var noteJson in cachedNotes) {
            try {
              noteList.add(Note.fromJson(noteJson));
            } catch (e) {}
          }
          _notesByChapter[chapterId] = noteList;
          _hasLoadedForChapter[chapterId] = true;
          _lastLoadedTime[chapterId] = DateTime.now();

          await _loadViewedStatus(chapterId);
        }
      } catch (cacheError) {
        debugLog('NoteProvider', 'Cache load error: $cacheError');
      }

      if (!_hasLoadedForChapter[chapterId]!) {
        _notesByChapter[chapterId] = [];
      }
    } finally {
      _isLoadingForChapter[chapterId] = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadViewedStatus(int chapterId) async {
    final notes = _notesByChapter[chapterId] ?? [];
    for (final note in notes) {
      final viewed =
          await deviceService.getCacheItem<bool>('note_viewed_${note.id}');
      _noteViewedStatus[note.id] = viewed ?? false;
    }
  }

  Note? getNoteById(int id) {
    try {
      return _notes.firstWhere((n) => n.id == id);
    } catch (e) {
      return null;
    }
  }

  bool isNoteViewed(int noteId) {
    return _noteViewedStatus[noteId] ?? false;
  }

  Future<void> markNoteAsViewed(int noteId) async {
    _noteViewedStatus[noteId] = true;

    await deviceService.saveCacheItem(
      'note_viewed_$noteId',
      true,
      ttl: viewedCacheDuration,
    );

    _noteUpdateController.add({'type': 'note_viewed', 'note_id': noteId});

    notifyListeners();
  }

  Future<void> markNotesAsViewedForChapter(int chapterId) async {
    final notes = _notesByChapter[chapterId] ?? [];
    for (final note in notes) {
      await markNoteAsViewed(note.id);
    }
  }

  int getViewedNotesCountForChapter(int chapterId) {
    final notes = _notesByChapter[chapterId] ?? [];
    return notes.where((note) => isNoteViewed(note.id)).length;
  }

  Future<void> clearNotesForChapter(int chapterId) async {
    _hasLoadedForChapter.remove(chapterId);
    _lastLoadedTime.remove(chapterId);

    final chapterNotes = _notesByChapter[chapterId] ?? [];
    _notes.removeWhere((note) => chapterNotes.any((n) => n.id == note.id));
    _notesByChapter.remove(chapterId);

    await deviceService.removeCacheItem('notes_chapter_$chapterId');

    for (final note in chapterNotes) {
      await deviceService.removeCacheItem('note_viewed_${note.id}');
      _noteViewedStatus.remove(note.id);
    }

    _noteUpdateController
        .add({'type': 'notes_cleared', 'chapter_id': chapterId});

    notifyListeners();
  }

  Future<void> clearUserData() async {
    debugLog('NoteProvider', 'Clearing note data');

    _notes.clear();
    _notesByChapter.clear();
    _hasLoadedForChapter.clear();
    _lastLoadedTime.clear();
    _isLoadingForChapter.clear();
    _noteViewedStatus.clear();

    await deviceService.clearCacheByPrefix('notes_');
    await deviceService.clearCacheByPrefix('note_viewed_');

    _noteUpdateController.close();
    _noteUpdateController = StreamController<Map<String, dynamic>>.broadcast();

    _noteUpdateController.add({'type': 'all_notes_cleared'});

    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _noteUpdateController.close();
    super.dispose();
  }
}
```

---

## notification_provider.dart

**File Path:** `lib/providers/notification_provider.dart`

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../models/notification_model.dart' as AppNotification;
import '../utils/helpers.dart';

class NotificationProvider with ChangeNotifier {
  final ApiService apiService;
  final DeviceService deviceService;

  List<AppNotification.Notification> _notifications = [];
  bool _isLoading = false;
  String? _error;
  int _unreadCount = 0;
  bool _hasLoaded = false;
  DateTime? _lastLoadTime;
  Timer? _refreshTimer;

  static const Duration _cacheDuration = Duration(minutes: 15);
  static const Duration _refreshInterval = Duration(minutes: 5);

  NotificationProvider(
      {required this.apiService, required this.deviceService}) {
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (_hasLoaded && !_isLoading) loadNotifications();
    });
  }

  List<AppNotification.Notification> get notifications =>
      List.unmodifiable(_notifications);
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get unreadCount => _unreadCount;

  List<AppNotification.Notification> get unreadNotifications {
    return _notifications.where((n) => !n.isRead && n.isDelivered).toList();
  }

  List<AppNotification.Notification> get readNotifications {
    return _notifications.where((n) => n.isRead && n.isDelivered).toList();
  }

  Future<void> loadNotifications({bool forceRefresh = false}) async {
    if (_isLoading && !forceRefresh) return;

    if (!forceRefresh && _hasLoaded) {
      final now = DateTime.now();
      if (_lastLoadTime != null &&
          now.difference(_lastLoadTime!) < _cacheDuration) return;
    }

    if (!forceRefresh && !_hasLoaded) {
      final cachedNotifications = await deviceService
          .getCacheItem<List<AppNotification.Notification>>('notifications',
              isUserSpecific: true);
      if (cachedNotifications != null) {
        _notifications = cachedNotifications;
        _unreadCount =
            _notifications.where((n) => !n.isRead && n.isDelivered).length;
        _hasLoaded = true;
        _notifySafely();
        _refreshFromApi();
        return;
      }
    }

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      final response = await apiService.getMyNotifications();

      if (response.success && response.data != null) {
        _notifications = response.data ?? [];
        _unreadCount =
            _notifications.where((n) => !n.isRead && n.isDelivered).length;
        _hasLoaded = true;
        _lastLoadTime = DateTime.now();

        await deviceService.saveCacheItem('notifications', _notifications,
            ttl: _cacheDuration, isUserSpecific: true);
      } else {
        _error = response.message ?? 'Failed to load notifications';
      }
    } catch (e) {
      _error = e.toString();
      if (!_hasLoaded) _error = 'No internet connection';
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> _refreshFromApi() async {
    try {
      final response = await apiService.getMyNotifications();

      if (response.success && response.data != null) {
        final newNotifications = response.data ?? [];
        final Map<int, AppNotification.Notification> notificationMap = {};
        for (final notif in _notifications)
          notificationMap[notif.logId] = notif;
        for (final notif in newNotifications)
          notificationMap[notif.logId] = notif;

        _notifications = notificationMap.values.toList()
          ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
        _unreadCount =
            _notifications.where((n) => !n.isRead && n.isDelivered).length;
        _lastLoadTime = DateTime.now();

        await deviceService.saveCacheItem('notifications', _notifications,
            ttl: _cacheDuration, isUserSpecific: true);
        if (hasListeners) _notifySafely();
      }
    } catch (e) {}
  }

  Future<void> refreshUnreadCount() async {
    try {
      final response = await apiService.getUnreadCount();
      if (response.success && response.data != null) {
        _unreadCount = response.data!['unread_count'] ?? 0;
        notifyListeners();
      }
    } catch (e) {
      debugLog('NotificationProvider', 'Refresh unread count error: $e');
    }
  }

  Future<void> markAsRead(int logId) async {
    try {
      final index = _notifications.indexWhere((n) => n.logId == logId);
      if (index != -1) {
        _notifications[index] = AppNotification.Notification(
          logId: _notifications[index].logId,
          notificationId: _notifications[index].notificationId,
          title: _notifications[index].title,
          message: _notifications[index].message,
          deliveryStatus: _notifications[index].deliveryStatus,
          isRead: true,
          receivedAt: _notifications[index].receivedAt,
          sentAt: _notifications[index].sentAt,
          readAt: DateTime.now(),
          deliveredAt: _notifications[index].deliveredAt,
          sentBy: _notifications[index].sentBy,
        );

        _unreadCount = unreadNotifications.length;
        await deviceService.saveCacheItem('notifications', _notifications,
            ttl: _cacheDuration, isUserSpecific: true);
        _notifySafely();

        try {
          await apiService.markNotificationAsRead(logId);
        } catch (e) {}
      }
    } catch (e) {}
  }

  Future<void> markAllAsRead() async {
    try {
      _notifications = _notifications.map((notification) {
        return AppNotification.Notification(
          logId: notification.logId,
          notificationId: notification.notificationId,
          title: notification.title,
          message: notification.message,
          deliveryStatus: notification.deliveryStatus,
          isRead: true,
          receivedAt: notification.receivedAt,
          sentAt: notification.sentAt,
          readAt: DateTime.now(),
          deliveredAt: notification.deliveredAt,
          sentBy: notification.sentBy,
        );
      }).toList();

      _unreadCount = 0;
      await deviceService.saveCacheItem('notifications', _notifications,
          ttl: _cacheDuration, isUserSpecific: true);
      _notifySafely();

      try {
        await apiService.markAllNotificationsAsRead();
      } catch (e) {}
    } catch (e) {}
  }

  Future<void> deleteNotification(int logId) async {
    try {
      // Remove from local list immediately for UI responsiveness
      _notifications.removeWhere((n) => n.logId == logId);
      _unreadCount = unreadNotifications.length;

      // Save to cache
      await deviceService.saveCacheItem('notifications', _notifications,
          ttl: _cacheDuration, isUserSpecific: true);
      _notifySafely();

      // Call API to delete from backend
      try {
        await apiService.deleteNotification(logId);
        debugLog('NotificationProvider',
            '✅ Deleted notification $logId from backend');
      } catch (e) {
        debugLog('NotificationProvider',
            '⚠️ Backend delete failed, but removed locally: $e');
        // If backend delete fails, we should refresh to sync
        Future.delayed(const Duration(seconds: 2),
            () => loadNotifications(forceRefresh: true));
      }
    } catch (e) {
      debugLog('NotificationProvider', '❌ Delete notification error: $e');
    }
  }

  void addNotification(AppNotification.Notification notification) {
    _notifications.insert(0, notification);
    if (!notification.isRead && notification.isDelivered) _unreadCount++;
    deviceService.saveCacheItem('notifications', _notifications,
        ttl: _cacheDuration, isUserSpecific: true);
    _notifySafely();
  }

  Future<void> clearUserData() async {
    await deviceService.clearCacheByPrefix('notifications');
    _notifications.clear();
    _unreadCount = 0;
    _hasLoaded = false;
    _lastLoadTime = null;
    _notifySafely();
  }

  void clearNotifications() {
    _notifications.clear();
    _unreadCount = 0;
    _notifySafely();
  }

  void clearError() {
    _error = null;
    _notifySafely();
  }

  AppNotification.Notification? getNotificationByLogId(int logId) {
    try {
      return _notifications.firstWhere((n) => n.logId == logId);
    } catch (e) {
      return null;
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _notifySafely() {
    if (hasListeners) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (hasListeners) notifyListeners();
      });
    }
  }
}
```

---

## parent_link_provider.dart

**File Path:** `lib/providers/parent_link_provider.dart`

```dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:familyacademyclient/services/api_service.dart';
import 'package:familyacademyclient/services/device_service.dart';
import 'package:familyacademyclient/models/parent_link_model.dart';
import 'package:familyacademyclient/utils/helpers.dart';
import 'package:familyacademyclient/utils/api_response.dart';

class ParentLinkProvider with ChangeNotifier {
  final ApiService apiService;
  final DeviceService deviceService;

  String? _parentToken;
  DateTime? _tokenExpiresAt;
  bool _isLinked = false;
  bool _hasLoaded = false;
  String? _parentTelegramUsername;
  int? _parentTelegramId;
  DateTime? _linkedAt;
  bool _isLoading = false;
  String? _error;
  Timer? _countdownTimer;
  String? _parentName;
  ParentLink? _parentLinkData;
  Duration? _serverTimeOffset;

  StreamController<ParentLink?> _parentLinkUpdateController =
      StreamController<ParentLink?>.broadcast();
  StreamController<bool> _linkStatusUpdateController =
      StreamController<bool>.broadcast();

  ParentLinkProvider({required this.apiService, required this.deviceService});

  String? get parentToken => _parentToken;
  DateTime? get tokenExpiresAt => _tokenExpiresAt;
  bool get isLinked => _isLinked;
  bool get hasLoaded => _hasLoaded;
  String? get parentTelegramUsername => _parentTelegramUsername;
  int? get parentTelegramId => _parentTelegramId;
  DateTime? get linkedAt => _linkedAt;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get parentName => _parentName;
  ParentLink? get parentLinkData => _parentLinkData;

  Stream<ParentLink?> get parentLinkUpdates =>
      _parentLinkUpdateController.stream;
  Stream<bool> get linkStatusUpdates => _linkStatusUpdateController.stream;

  DateTime get _currentServerTime {
    if (_serverTimeOffset != null) {
      return DateTime.now().add(_serverTimeOffset!);
    }
    return DateTime.now();
  }

  Duration get remainingTime {
    if (_tokenExpiresAt == null) return Duration.zero;
    final now = _currentServerTime;
    if (now.isAfter(_tokenExpiresAt!)) return Duration.zero;
    return _tokenExpiresAt!.difference(now);
  }

  String get remainingTimeFormatted {
    final duration = remainingTime;
    if (duration.inMinutes <= 0) return 'Expired';

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  bool get isTokenExpired {
    if (_tokenExpiresAt == null) return true;
    return _currentServerTime.isAfter(_tokenExpiresAt!);
  }

  // 🔥 FIX: Method to clear cache
  Future<void> clearCache() async {
    debugLog('ParentLinkProvider', '🧹 Clearing cache');
    await deviceService.removeCacheItem('parent_link_status');
    await deviceService.removeCacheItem('parent_token');
  }

  Future<void> _syncServerTime() async {
    try {
      final cachedTime = await deviceService
          .getCacheItem<Map<String, dynamic>>('server_time_info');
      if (cachedTime != null) {
        final offset = Duration(milliseconds: cachedTime['offset'] ?? 0);
        final cachedAt = DateTime.parse(cachedTime['cached_at']);

        if (DateTime.now().difference(cachedAt).inHours < 1) {
          _serverTimeOffset = offset;
          debugLog('ParentLinkProvider',
              'Using cached server time offset: ${offset.inMinutes} minutes');
          return;
        }
      }

      try {
        final startTime = DateTime.now();
        final response = await apiService.dio.get('/health');
        final endTime = DateTime.now();

        if (response.statusCode == 200) {
          final serverTime = DateTime.now();
          final roundTripTime = endTime.difference(startTime);
          final estimatedServerTime = serverTime.add(roundTripTime ~/ 2);
          _serverTimeOffset = estimatedServerTime.difference(DateTime.now());

          await deviceService.saveCacheItem(
              'server_time_info',
              {
                'offset': _serverTimeOffset!.inMilliseconds,
                'cached_at': DateTime.now().toIso8601String(),
              },
              ttl: Duration(hours: 1));

          debugLog('ParentLinkProvider',
              'Server time synced. Offset: ${_serverTimeOffset!.inMinutes} minutes');
        }
      } catch (e) {
        debugLog('ParentLinkProvider', 'Server time sync failed: $e');
        _serverTimeOffset = null;
      }
    } catch (e) {
      debugLog('ParentLinkProvider', 'Server time sync error: $e');
      _serverTimeOffset = null;
    }
  }

  void _startCountdownTimer() {
    _stopCountdownTimer();

    if (_tokenExpiresAt != null && !isTokenExpired) {
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (isTokenExpired) {
          _stopCountdownTimer();
          _parentToken = null;
          _tokenExpiresAt = null;
          _notifySafely();
        } else {
          _notifySafely();
        }
      });
    }
  }

  void _stopCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  Future<void> generateParentToken() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      // 🔥 FIX: Clear cache before generating
      await deviceService.removeCacheItem('parent_token');
      await deviceService.removeCacheItem('parent_link_status');

      debugLog('ParentLinkProvider', '🧹 Cleared cache, generating new token');

      await _syncServerTime();

      debugLog('ParentLinkProvider', 'Generating parent token');
      final response = await apiService.generateParentToken();

      if (!response.success || response.data == null) {
        throw Exception(response.message ?? 'Failed to generate token');
      }

      final data = response.data!;

      _parentToken = data['token'];
      _tokenExpiresAt = DateTime.parse(data['expires_at']).toLocal();
      _isLinked = false;
      _parentTelegramUsername = null;
      _parentTelegramId = null;
      _linkedAt = null;
      _parentName = null;
      _parentLinkData = null;

      // Save new token to cache
      await deviceService.saveCacheItem(
          'parent_token',
          {
            'token': _parentToken,
            'expires_at': _tokenExpiresAt!.toIso8601String(),
          },
          ttl: Duration(minutes: 30));

      debugLog('ParentLinkProvider',
          '✅ Generated new token: ${_parentToken}, expiresAt: ${_tokenExpiresAt?.toIso8601String()}');

      _startCountdownTimer();

      _hasLoaded = true;
      _linkStatusUpdateController.add(false);
      _notifySafely();
    } on ApiError catch (e) {
      _error = e.userFriendlyMessage;
      debugLog(
          'ParentLinkProvider', 'generateParentToken API error: ${e.message}');
    } catch (e) {
      _error = e.toString();
      debugLog('ParentLinkProvider', 'generateParentToken error: $e');
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> getParentLinkStatus({bool forceRefresh = false}) async {
    if (_isLoading && !forceRefresh) return;

    _isLoading = true;
    if (forceRefresh) {
      _error = null;
    }
    _notifySafely();

    try {
      // 🔥 FIX: Force remove cache if refresh requested
      if (forceRefresh) {
        await deviceService.removeCacheItem('parent_link_status');
      }

      debugLog('ParentLinkProvider',
          'Fetching parent link status (forceRefresh: $forceRefresh)');
      final response = await apiService.getParentLinkStatus();

      if (response.success && response.data != null) {
        _parentLinkData = response.data;

        // 🔥 FIX: Always refresh from server, don't cache if forceRefresh
        if (!forceRefresh) {
          await deviceService.saveCacheItem(
              'parent_link_status', _parentLinkData!,
              ttl: const Duration(minutes: 5));
        }

        _updateFromParentLink(_parentLinkData!);

        debugLog(
            'ParentLinkProvider', 'Parent link status: isLinked=${_isLinked}');
      } else {
        // If API returns no data, clear everything
        _parentLinkData = null;
        _isLinked = false;
        _parentTelegramUsername = null;
        _parentTelegramId = null;
        _linkedAt = null;
        _parentName = null;
        _parentToken = null;
        _tokenExpiresAt = null;
      }

      _hasLoaded = true;

      _parentLinkUpdateController.add(_parentLinkData);
      _linkStatusUpdateController.add(_isLinked);
    } on ApiError catch (e) {
      _error = e.userFriendlyMessage;
      debugLog(
          'ParentLinkProvider', 'getParentLinkStatus API error: ${e.message}');
      _hasLoaded = true;
    } catch (e) {
      _error = e.toString();
      debugLog('ParentLinkProvider', 'getParentLinkStatus error: $e');
      _hasLoaded = true;
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  void _updateFromParentLink(ParentLink parentLink) {
    _stopCountdownTimer();

    _isLinked = parentLink.isLinked;
    _parentTelegramUsername = parentLink.parentTelegramUsername;
    _parentTelegramId = parentLink.parentTelegramId;
    _linkedAt = parentLink.linkedAt;
    _parentName = parentLink.parentName;

    if (!_isLinked) {
      _parentToken = parentLink.token;
      _tokenExpiresAt = parentLink.tokenExpiresAt;

      if (_parentToken != null && _tokenExpiresAt != null) {
        _startCountdownTimer();
      }
    } else {
      _parentToken = null;
      _tokenExpiresAt = null;
    }
  }

  Future<void> refreshParentLinkStatus() async {
    await deviceService.removeCacheItem('parent_link_status');
    await getParentLinkStatus(forceRefresh: true);
  }

  Future<void> unlinkParent() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('ParentLinkProvider', 'Unlinking parent');
      final response = await apiService.unlinkParent();

      if (response.success) {
        // 🔥 FIX: Clear cache immediately
        await deviceService.removeCacheItem('parent_link_status');
        await deviceService.removeCacheItem('parent_token');

        _stopCountdownTimer();
        _isLinked = false;
        _parentTelegramUsername = null;
        _parentTelegramId = null;
        _linkedAt = null;
        _parentToken = null;
        _tokenExpiresAt = null;
        _parentName = null;
        _parentLinkData = null;
        _hasLoaded = true;

        _parentLinkUpdateController.add(null);
        _linkStatusUpdateController.add(false);

        debugLog('ParentLinkProvider', 'Parent unlinked');
      }
    } on ApiError catch (e) {
      _error = e.userFriendlyMessage;
      debugLog('ParentLinkProvider', 'unlinkParent API error: ${e.message}');
      rethrow;
    } catch (e) {
      _error = e.toString();
      debugLog('ParentLinkProvider', 'unlinkParent error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  void updateLinkStatus({
    required bool isLinked,
    String? parentTelegramUsername,
    int? parentTelegramId,
    String? parentName,
    DateTime? linkedAt,
  }) {
    _stopCountdownTimer();
    _isLinked = isLinked;
    _parentTelegramUsername = parentTelegramUsername;
    _parentTelegramId = parentTelegramId;
    _parentName = parentName;
    _linkedAt = linkedAt ?? DateTime.now();

    if (isLinked) {
      _parentToken = null;
      _tokenExpiresAt = null;
    }

    _hasLoaded = true;

    _parentLinkUpdateController.add(_parentLinkData);
    _linkStatusUpdateController.add(_isLinked);

    _notifySafely();
  }

  void clearError() {
    _error = null;
    _notifySafely();
  }

  Future<void> clearUserData() async {
    debugLog('ParentLinkProvider', 'Clearing parent link data');

    await deviceService.removeCacheItem('parent_link_status');
    await deviceService.removeCacheItem('parent_token');
    await deviceService.removeCacheItem('server_time_info');

    _stopCountdownTimer();

    _parentLinkData = null;
    _hasLoaded = false;
    _isLinked = false;
    _parentTelegramUsername = null;
    _parentTelegramId = null;
    _linkedAt = null;
    _parentToken = null;
    _tokenExpiresAt = null;
    _parentName = null;
    _serverTimeOffset = null;

    _parentLinkUpdateController.add(null);
    _linkStatusUpdateController.add(false);

    _notifySafely();
  }

  @override
  void dispose() {
    _stopCountdownTimer();
    _parentLinkUpdateController.close();
    _linkStatusUpdateController.close();
    super.dispose();
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
```

---

## payment_provider.dart

**File Path:** `lib/providers/payment_provider.dart`

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../models/payment_model.dart';
import '../models/setting_model.dart';
import '../utils/helpers.dart';
import '../utils/constants.dart';

class PaymentProvider with ChangeNotifier {
  final ApiService apiService;
  final DeviceService deviceService;

  List<Payment> _payments = [];
  bool _isLoading = false;
  String? _error;

  Timer? _refreshTimer;
  StreamController<List<Payment>> _paymentsUpdateController =
      StreamController<List<Payment>>.broadcast();

  static const Duration _cacheDuration = Duration(minutes: 10);
  static const Duration _refreshInterval = Duration(minutes: 5);

  PaymentProvider({required this.apiService, required this.deviceService}) {
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      _refreshDataInBackground();
    });
  }

  List<Payment> get payments => List.unmodifiable(_payments);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Stream<List<Payment>> get paymentsUpdates => _paymentsUpdateController.stream;

  List<Payment> getPendingPayments() {
    return _payments.where((p) => p.isPending).toList();
  }

  List<Payment> getVerifiedPayments() {
    return _payments.where((p) => p.isVerified).toList();
  }

  List<Payment> getRejectedPayments() {
    return _payments.where((p) => p.isRejected).toList();
  }

  Future<void> _refreshDataInBackground() async {
    if (_isLoading) return;

    try {
      debugLog('PaymentProvider', '🔄 Background refresh of payment data');
      await _loadPaymentsFromCacheOrApi(forceRefresh: true);
    } catch (e) {
      debugLog('PaymentProvider', 'Background refresh error: $e');
    }
  }

  Future<void> loadPayments({bool forceRefresh = false}) async {
    if (_isLoading && !forceRefresh) return;

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('PaymentProvider', 'Loading payments');
      await _loadPaymentsFromCacheOrApi(forceRefresh: forceRefresh);
    } catch (e) {
      _error = e.toString();
      debugLog('PaymentProvider', 'loadPayments error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> _loadPaymentsFromCacheOrApi({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cachedPayments =
          await deviceService.getCacheItem<List<Payment>>('payments');
      if (cachedPayments != null) {
        _payments = cachedPayments;
        _paymentsUpdateController.add(_payments);
        debugLog('PaymentProvider',
            'Loaded ${_payments.length} payments from cache');
        return;
      }
    }

    final response = await apiService.getMyPayments();
    _payments = response.data ?? [];

    await deviceService.saveCacheItem('payments', _payments,
        ttl: _cacheDuration);
    _paymentsUpdateController.add(_payments);

    debugLog('PaymentProvider', 'Loaded payments: ${_payments.length}');
  }

  Future<Map<String, dynamic>> submitPayment({
    required int categoryId,
    required String paymentType,
    required String paymentMethod,
    required double amount,
    String? accountHolderName,
    String? proofImagePath,
  }) async {
    if (_isLoading) return {'success': false, 'message': 'Already processing'};

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('PaymentProvider',
          'Submitting payment category:$categoryId amount:$amount method:$paymentMethod accountHolder:$accountHolderName proof:$proofImagePath');

      final apiResponse = await apiService.submitPayment(
        categoryId: categoryId,
        paymentType: paymentType,
        paymentMethod: paymentMethod,
        amount: amount,
        accountHolderName: accountHolderName,
        proofImagePath: proofImagePath,
      );

      debugLog(
          'PaymentProvider', 'Submit payment response: ${apiResponse.data}');
      debugLog(
          'PaymentProvider', 'Submit payment success: ${apiResponse.success}');
      debugLog(
          'PaymentProvider', 'Submit payment message: ${apiResponse.message}');

      if (apiResponse.success) {
        await deviceService.removeCacheItem('payments');
        await _loadPaymentsFromCacheOrApi(forceRefresh: true);
      }

      return {
        'success': apiResponse.success,
        'message': apiResponse.message,
        'data': apiResponse.data,
      };
    } catch (e, stackTrace) {
      _error = e.toString();
      debugLog('PaymentProvider', 'submitPayment error: $e\n$stackTrace');

      return {
        'success': false,
        'message': e.toString(),
        'error': e.toString(),
      };
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> clearUserData() async {
    debugLog('PaymentProvider', 'Clearing payment data');

    await deviceService.clearCacheByPrefix('payment');

    _payments = [];

    _paymentsUpdateController.close();
    _paymentsUpdateController = StreamController<List<Payment>>.broadcast();

    _paymentsUpdateController.add(_payments);

    _notifySafely();
  }

  void clearError() {
    _error = null;
    _notifySafely();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _paymentsUpdateController.close();
    super.dispose();
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
```

---

## progress_provider.dart

**File Path:** `lib/providers/progress_provider.dart`

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:familyacademyclient/models/progress_model.dart';
import 'package:familyacademyclient/services/api_service.dart';
import 'package:familyacademyclient/services/device_service.dart';
import 'package:familyacademyclient/providers/streak_provider.dart';
import 'package:familyacademyclient/utils/helpers.dart';
import '../utils/api_response.dart';

class ProgressProvider with ChangeNotifier {
  final ApiService apiService;
  final DeviceService deviceService;
  final StreakProvider streakProvider;

  List<UserProgress> _userProgress = [];
  Map<int, UserProgress> _progressByChapter = {};
  Map<String, dynamic> _overallStats = {};
  List<Map<String, dynamic>> _achievements = [];
  List<Map<String, dynamic>> _recentActivity = [];
  List<DateTime> _streakHistory = [];

  bool _isLoading = false;
  bool _isLoadingOverall = false;
  bool _hasLoadedOverall = false;
  bool _hasLoadedProgress = false;
  String? _error;

  final Set<int> _pendingSaves = {};
  final Map<int, Timer> _saveDebounceTimers = {};

  StreamController<List<UserProgress>> _progressUpdateController =
      StreamController<List<UserProgress>>.broadcast();
  StreamController<Map<int, UserProgress>> _chapterProgressController =
      StreamController<Map<int, UserProgress>>.broadcast();
  StreamController<Map<String, dynamic>> _overallStatsController =
      StreamController<Map<String, dynamic>>.broadcast();

  static const Duration _cacheDuration = Duration(minutes: 30);
  static const Duration _syncInterval = Duration(seconds: 60);
  static const Duration _saveDebounceDuration = Duration(seconds: 5);

  ProgressProvider({
    required this.apiService,
    required this.deviceService,
    required this.streakProvider,
  }) {
    _init();
  }

  Future<void> _init() async {
    await _loadCachedProgress();
  }

  List<UserProgress> get userProgress => List.unmodifiable(_userProgress);
  Map<String, dynamic> get overallStats => Map.unmodifiable(_overallStats);
  List<Map<String, dynamic>> get achievements =>
      List.unmodifiable(_achievements);
  List<Map<String, dynamic>> get recentActivity =>
      List.unmodifiable(_recentActivity);
  List<DateTime> get streakHistory => List.unmodifiable(_streakHistory);
  bool get isLoading => _isLoading;
  bool get isLoadingOverall => _isLoadingOverall;
  bool get hasLoadedOverall => _hasLoadedOverall;
  bool get hasLoadedProgress => _hasLoadedProgress;
  String? get error => _error;

  Stream<List<UserProgress>> get progressUpdates =>
      _progressUpdateController.stream;
  Stream<Map<int, UserProgress>> get chapterProgressUpdates =>
      _chapterProgressController.stream;
  Stream<Map<String, dynamic>> get overallStatsUpdates =>
      _overallStatsController.stream;

  UserProgress? getProgressForChapter(int chapterId) {
    return _progressByChapter[chapterId];
  }

  double getOverallProgress() {
    if (_userProgress.isEmpty) return 0;
    final totalProgress = _userProgress.fold(
      0.0,
      (sum, progress) => sum + progress.completionPercentage,
    );
    return totalProgress / _userProgress.length;
  }

  int getCompletedChaptersCount() {
    return _userProgress.where((p) => p.completed).length;
  }

  int getTotalChaptersAttempted() {
    return _userProgress.length;
  }

  double getOverallAccuracy() {
    final attemptedQuestions = _userProgress.fold(
      0,
      (sum, progress) => sum + progress.questionsAttempted,
    );

    final correctQuestions = _userProgress.fold(
      0,
      (sum, progress) => sum + progress.questionsCorrect,
    );

    if (attemptedQuestions == 0) return 0;
    return (correctQuestions / attemptedQuestions) * 100;
  }

  Future<void> _loadCachedProgress() async {
    try {
      final cachedProgress = await deviceService
          .getCacheItem<Map<String, dynamic>>('all_user_progress',
              isUserSpecific: true);

      if (cachedProgress != null) {
        final progressList = cachedProgress['progress'] as List? ?? [];
        _userProgress = progressList
            .map((json) => UserProgress.fromJson(json as Map<String, dynamic>))
            .toList();
        _progressByChapter = {for (var p in _userProgress) p.chapterId: p};
        _hasLoadedProgress = true;

        _progressUpdateController.add(_userProgress);
        _chapterProgressController.add(_progressByChapter);

        debugLog('ProgressProvider',
            '✅ Loaded ${_userProgress.length} progress items from cache');
      }

      final cachedStats = await deviceService
          .getCacheItem<Map<String, dynamic>>('overall_stats',
              isUserSpecific: true);
      if (cachedStats != null) {
        _overallStats = cachedStats;
        _hasLoadedOverall = true;

        if (_overallStats['achievements'] != null &&
            _overallStats['achievements'] is List) {
          _achievements = List<Map<String, dynamic>>.from(
              _overallStats['achievements'] as List);
        }

        if (_overallStats['recent_activity'] != null &&
            _overallStats['recent_activity'] is List) {
          _recentActivity = List<Map<String, dynamic>>.from(
              _overallStats['recent_activity'] as List);
        }

        if (_overallStats['streak_history'] != null &&
            _overallStats['streak_history'] is List) {
          _streakHistory = (_overallStats['streak_history'] as List)
              .map((date) => DateTime.parse(date).toLocal())
              .toList();
        }

        _overallStatsController.add(_overallStats);
        notifyListeners();

        debugLog('ProgressProvider', '✅ Loaded overall stats from cache');
      }

      _loadAllProgressFromApi();
    } catch (e) {
      debugLog('ProgressProvider', 'Error loading cached progress: $e');
    }
  }

  Future<void> _loadAllProgressFromApi() async {
    try {
      debugLog(
          'ProgressProvider', 'Loading all progress from API in background');

      final response = await apiService.getOverallProgress();

      if (response.success && response.data != null) {
        _overallStats = response.data!;

        if (_overallStats['achievements'] != null &&
            _overallStats['achievements'] is List) {
          _achievements = List<Map<String, dynamic>>.from(
              _overallStats['achievements'] as List);
          debugLog('ProgressProvider',
              '✅ Loaded ${_achievements.length} achievements');
        }

        if (_overallStats['recent_activity'] != null &&
            _overallStats['recent_activity'] is List) {
          _recentActivity = List<Map<String, dynamic>>.from(
              _overallStats['recent_activity'] as List);
          debugLog('ProgressProvider',
              '✅ Loaded ${_recentActivity.length} recent activities');
        }

        if (_overallStats['streak_history'] != null &&
            _overallStats['streak_history'] is List) {
          _streakHistory = (_overallStats['streak_history'] as List)
              .map((date) => DateTime.parse(date).toLocal())
              .toList();
          debugLog('ProgressProvider',
              '✅ Loaded ${_streakHistory.length} streak history entries');
        }

        await deviceService.saveCacheItem('overall_stats', _overallStats,
            ttl: _cacheDuration, isUserSpecific: true);

        _hasLoadedOverall = true;
        _overallStatsController.add(_overallStats);
        notifyListeners();
      }
    } catch (e) {
      debugLog('ProgressProvider', 'Error loading all progress: $e');
    }
  }

  Future<void> loadUserProgressForCourse(int courseId,
      {bool forceRefresh = false}) async {
    if (_isLoading) return;

    if (!forceRefresh && _hasLoadedProgress && _userProgress.isNotEmpty) {
      debugLog(
          'ProgressProvider', '📦 Using cached progress for course: $courseId');
      _progressUpdateController.add(_userProgress);
      _chapterProgressController.add(_progressByChapter);
      return;
    }

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('ProgressProvider', 'Loading progress for course: $courseId');

      final cacheKey = 'progress_course_$courseId';
      final cachedProgress = await deviceService
          .getCacheItem<List<dynamic>>(cacheKey, isUserSpecific: true);

      if (cachedProgress != null && !forceRefresh) {
        _userProgress = cachedProgress
            .map((json) => UserProgress.fromJson(json as Map<String, dynamic>))
            .toList();
        _progressByChapter = {for (var p in _userProgress) p.chapterId: p};
        _hasLoadedProgress = true;

        _progressUpdateController.add(_userProgress);
        _chapterProgressController.add(_progressByChapter);

        debugLog('ProgressProvider',
            '✅ Loaded ${_userProgress.length} progress entries from cache');

        _refreshCourseProgressInBackground(courseId);
        return;
      }

      final response = await apiService.getUserProgressForCourse(courseId);
      if (response.success && response.data != null) {
        _userProgress = response.data!;
        _progressByChapter = {for (var p in _userProgress) p.chapterId: p};
        _hasLoadedProgress = true;

        await deviceService.saveCacheItem(
            cacheKey, _userProgress.map((p) => p.toJson()).toList(),
            ttl: _cacheDuration, isUserSpecific: true);

        _progressUpdateController.add(_userProgress);
        _chapterProgressController.add(_progressByChapter);

        debugLog('ProgressProvider',
            '✅ Loaded ${_userProgress.length} progress entries from API');
      }
    } on ApiError catch (e) {
      _error = e.userFriendlyMessage;
      debugLog('ProgressProvider', 'ApiError loading progress: ${e.message}');
    } catch (e) {
      _error = 'Failed to load progress: ${e.toString()}';
      debugLog('ProgressProvider', 'Error loading progress: $e');
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> _refreshCourseProgressInBackground(int courseId) async {
    try {
      final response = await apiService.getUserProgressForCourse(courseId);
      if (response.success && response.data != null) {
        _userProgress = response.data!;
        _progressByChapter = {for (var p in _userProgress) p.chapterId: p};

        final cacheKey = 'progress_course_$courseId';
        await deviceService.saveCacheItem(
            cacheKey, _userProgress.map((p) => p.toJson()).toList(),
            ttl: _cacheDuration, isUserSpecific: true);

        _progressUpdateController.add(_userProgress);
        _chapterProgressController.add(_progressByChapter);

        debugLog('ProgressProvider',
            '✅ Background refresh complete for course: $courseId');
      }
    } catch (e) {
      debugLog('ProgressProvider', 'Background refresh error: $e');
    }
  }

  Future<void> loadOverallProgress({bool forceRefresh = false}) async {
    if (_isLoadingOverall) return;

    if (!forceRefresh && _hasLoadedOverall && _overallStats.isNotEmpty) {
      debugLog('ProgressProvider', '📦 Using cached overall stats');
      _overallStatsController.add(_overallStats);
      notifyListeners();

      _refreshOverallProgressInBackground();
      return;
    }

    _isLoadingOverall = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('ProgressProvider', 'Loading overall progress');

      final cachedStats = await deviceService
          .getCacheItem<Map<String, dynamic>>('overall_stats',
              isUserSpecific: true);
      if (cachedStats != null && !forceRefresh) {
        _overallStats = cachedStats;
        _hasLoadedOverall = true;

        if (_overallStats['achievements'] != null &&
            _overallStats['achievements'] is List) {
          _achievements = List<Map<String, dynamic>>.from(
              _overallStats['achievements'] as List);
        }

        if (_overallStats['recent_activity'] != null &&
            _overallStats['recent_activity'] is List) {
          _recentActivity = List<Map<String, dynamic>>.from(
              _overallStats['recent_activity'] as List);
        }

        if (_overallStats['streak_history'] != null &&
            _overallStats['streak_history'] is List) {
          _streakHistory = (_overallStats['streak_history'] as List)
              .map((date) => DateTime.parse(date).toLocal())
              .toList();
        }

        _overallStatsController.add(_overallStats);
        debugLog('ProgressProvider', '✅ Loaded overall stats from cache');

        _refreshOverallProgressInBackground();
        return;
      }

      final response = await apiService.getOverallProgress();

      if (response.success && response.data != null) {
        _overallStats = response.data!;
        _hasLoadedOverall = true;

        if (_overallStats['achievements'] != null &&
            _overallStats['achievements'] is List) {
          _achievements = List<Map<String, dynamic>>.from(
              _overallStats['achievements'] as List);
        }

        if (_overallStats['recent_activity'] != null &&
            _overallStats['recent_activity'] is List) {
          _recentActivity = List<Map<String, dynamic>>.from(
              _overallStats['recent_activity'] as List);
        }

        if (_overallStats['streak_history'] != null &&
            _overallStats['streak_history'] is List) {
          _streakHistory = (_overallStats['streak_history'] as List)
              .map((date) => DateTime.parse(date).toLocal())
              .toList();
        }

        await deviceService.saveCacheItem('overall_stats', _overallStats,
            ttl: _cacheDuration, isUserSpecific: true);
        _overallStatsController.add(_overallStats);
        notifyListeners();

        debugLog('ProgressProvider', '✅ Loaded overall progress stats');
      } else {
        _setEmptyProgressData();
      }
    } on ApiError catch (e) {
      debugLog('ProgressProvider', 'ApiError loading overall progress: $e');
      _setEmptyProgressData();
    } catch (e) {
      _error = 'Failed to load overall progress: ${e.toString()}';
      debugLog('ProgressProvider', 'Error loading overall progress: $e');
      _setEmptyProgressData();
    } finally {
      _isLoadingOverall = false;
      _notifySafely();
    }
  }

  Future<void> _refreshOverallProgressInBackground() async {
    try {
      final response = await apiService.getOverallProgress();
      if (response.success && response.data != null) {
        _overallStats = response.data!;

        if (_overallStats['achievements'] != null &&
            _overallStats['achievements'] is List) {
          _achievements = List<Map<String, dynamic>>.from(
              _overallStats['achievements'] as List);
        }

        if (_overallStats['recent_activity'] != null &&
            _overallStats['recent_activity'] is List) {
          _recentActivity = List<Map<String, dynamic>>.from(
              _overallStats['recent_activity'] as List);
        }

        if (_overallStats['streak_history'] != null &&
            _overallStats['streak_history'] is List) {
          _streakHistory = (_overallStats['streak_history'] as List)
              .map((date) => DateTime.parse(date).toLocal())
              .toList();
        }

        await deviceService.saveCacheItem('overall_stats', _overallStats,
            ttl: _cacheDuration, isUserSpecific: true);

        _overallStatsController.add(_overallStats);
        notifyListeners();

        debugLog('ProgressProvider',
            '✅ Background refresh complete for overall stats');
      }
    } catch (e) {
      debugLog('ProgressProvider', 'Background refresh error: $e');
    }
  }

  void _setEmptyProgressData() {
    _overallStats = {
      'stats': {
        'chapters_completed': 0,
        'total_chapters_attempted': 0,
        'accuracy_percentage': 0.0,
        'study_time_hours': 0.0,
        'total_questions_attempted': 0,
        'total_questions_correct': 0,
      },
      'recent_activity': [],
      'streak_history': [],
      'achievements': [],
    };
    _achievements = [];
    _recentActivity = [];
    _streakHistory = [];
    _hasLoadedOverall = true;
    _overallStatsController.add(_overallStats);
    debugLog('ProgressProvider', 'Set empty progress data');
  }

  Future<void> saveChapterProgress({
    required int chapterId,
    int? videoProgress,
    bool? notesViewed,
    int? questionsAttempted,
    int? questionsCorrect,
  }) async {
    try {
      debugLog('ProgressProvider', 'Saving progress for chapter: $chapterId');

      _saveDebounceTimers[chapterId]?.cancel();

      final completer = Completer<void>();

      _saveDebounceTimers[chapterId] = Timer(_saveDebounceDuration, () async {
        _pendingSaves.add(chapterId);

        try {
          final existingProgress = _progressByChapter[chapterId];
          final now = DateTime.now();

          UserProgress newProgress;

          if (existingProgress != null) {
            newProgress = UserProgress(
              chapterId: chapterId,
              completed:
                  existingProgress.completed || (videoProgress ?? 0) >= 90,
              videoProgress: videoProgress ?? existingProgress.videoProgress,
              notesViewed: notesViewed ?? existingProgress.notesViewed,
              questionsAttempted:
                  questionsAttempted ?? existingProgress.questionsAttempted,
              questionsCorrect:
                  questionsCorrect ?? existingProgress.questionsCorrect,
              lastAccessed: now,
            );
          } else {
            newProgress = UserProgress(
              chapterId: chapterId,
              completed: (videoProgress ?? 0) >= 90,
              videoProgress: videoProgress ?? 0,
              notesViewed: notesViewed ?? false,
              questionsAttempted: questionsAttempted ?? 0,
              questionsCorrect: questionsCorrect ?? 0,
              lastAccessed: now,
            );
          }

          _progressByChapter[chapterId] = newProgress;
          _userProgress = _progressByChapter.values.toList();

          await _saveToLocalCache(chapterId, newProgress);

          _progressUpdateController.add(_userProgress);
          _chapterProgressController.add(_progressByChapter);
          _notifySafely();

          try {
            await apiService.saveUserProgress(
              chapterId: chapterId,
              videoProgress: newProgress.videoProgress,
              notesViewed: newProgress.notesViewed,
              questionsAttempted: newProgress.questionsAttempted,
              questionsCorrect: newProgress.questionsCorrect,
            );

            if (videoProgress != null ||
                notesViewed == true ||
                questionsAttempted != null) {
              await streakProvider.updateStreak();
            }

            await loadOverallProgress(forceRefresh: true);

            debugLog('ProgressProvider',
                '✅ Progress saved to API for chapter: $chapterId');

            completer.complete();
          } catch (apiError) {
            debugLog('ProgressProvider',
                '⚠️ API save failed, will retry later: $apiError');
            await _markAsPendingSync(chapterId, newProgress);
            completer.complete();
          }
        } catch (e) {
          debugLog('ProgressProvider', 'Error in debounced save: $e');
          completer.completeError(e);
        } finally {
          _pendingSaves.remove(chapterId);
          _saveDebounceTimers.remove(chapterId);
        }
      });

      return completer.future;
    } catch (e) {
      debugLog('ProgressProvider', 'Error saving progress: $e');
      rethrow;
    }
  }

  Future<void> _saveToLocalCache(int chapterId, UserProgress progress) async {
    try {
      final cacheKey = 'progress_chapter_$chapterId';
      await deviceService.saveCacheItem(cacheKey, progress.toJson(),
          ttl: _cacheDuration, isUserSpecific: true);

      final allProgressKey = 'all_user_progress';
      final allProgressData = {
        'progress': _userProgress.map((p) => p.toJson()).toList(),
        'last_updated': DateTime.now().toIso8601String(),
      };
      await deviceService.saveCacheItem(allProgressKey, allProgressData,
          ttl: _cacheDuration, isUserSpecific: true);
    } catch (e) {
      debugLog('ProgressProvider', 'Error saving to cache: $e');
    }
  }

  Future<void> _markAsPendingSync(int chapterId, UserProgress progress) async {
    try {
      final pendingKey = 'pending_progress';
      final existing = await deviceService
              .getCacheItem<List<dynamic>>(pendingKey, isUserSpecific: true) ??
          [];

      final updated = [
        ...existing,
        {
          'chapter_id': chapterId,
          'progress': progress.toJson(),
          'timestamp': DateTime.now().toIso8601String(),
        }
      ];

      await deviceService.saveCacheItem(pendingKey, updated,
          ttl: const Duration(days: 7), isUserSpecific: true);
    } catch (e) {
      debugLog('ProgressProvider', 'Error marking pending sync: $e');
    }
  }

  Future<void> _syncPendingProgress() async {
    try {
      final pendingKey = 'pending_progress';
      final pendingItems = await deviceService
          .getCacheItem<List<dynamic>>(pendingKey, isUserSpecific: true);

      if (pendingItems == null || pendingItems.isEmpty) return;

      debugLog('ProgressProvider',
          '🔄 Syncing ${pendingItems.length} pending progress items');

      final List<dynamic> failedItems = [];

      for (final item in pendingItems) {
        try {
          final chapterId = item['chapter_id'] as int;
          final progressData = item['progress'] as Map<String, dynamic>;

          await apiService.saveUserProgress(
            chapterId: chapterId,
            videoProgress: progressData['video_progress'] as int?,
            notesViewed: progressData['notes_viewed'] as bool?,
            questionsAttempted: progressData['questions_attempted'] as int?,
            questionsCorrect: progressData['questions_correct'] as int?,
          );

          debugLog(
              'ProgressProvider', '✅ Synced progress for chapter: $chapterId');
        } catch (e) {
          debugLog('ProgressProvider', '❌ Failed to sync item: $e');
          failedItems.add(item);
        }
      }

      if (failedItems.isEmpty) {
        await deviceService.removeCacheItem(pendingKey, isUserSpecific: true);
      } else {
        await deviceService.saveCacheItem(pendingKey, failedItems,
            ttl: const Duration(days: 7), isUserSpecific: true);
      }
    } catch (e) {
      debugLog('ProgressProvider', 'Error syncing pending progress: $e');
    }
  }

  Future<void> markChapterAsCompleted(int chapterId) async {
    await saveChapterProgress(
      chapterId: chapterId,
      videoProgress: 100,
      notesViewed: true,
      questionsAttempted: 1,
      questionsCorrect: 1,
    );
  }

  Future<void> forceSyncPending() async {
    await _syncPendingProgress();
  }

  Future<void> clearUserData() async {
    debugLog('ProgressProvider', 'Clearing progress data');

    for (final timer in _saveDebounceTimers.values) {
      timer.cancel();
    }
    _saveDebounceTimers.clear();
    _pendingSaves.clear();

    await deviceService.clearCacheByPrefix('progress_');
    await deviceService.clearCacheByPrefix('pending_');

    _userProgress = [];
    _progressByChapter = {};
    _overallStats = {};
    _achievements = [];
    _recentActivity = [];
    _streakHistory = [];
    _hasLoadedOverall = false;
    _hasLoadedProgress = false;

    _progressUpdateController.close();
    _chapterProgressController.close();
    _overallStatsController.close();

    _progressUpdateController =
        StreamController<List<UserProgress>>.broadcast();
    _chapterProgressController =
        StreamController<Map<int, UserProgress>>.broadcast();
    _overallStatsController =
        StreamController<Map<String, dynamic>>.broadcast();

    _progressUpdateController.add(_userProgress);
    _chapterProgressController.add(_progressByChapter);
    _overallStatsController.add(_overallStats);

    _notifySafely();
  }

  void clearError() {
    _error = null;
    _notifySafely();
  }

  @override
  void dispose() {
    for (final timer in _saveDebounceTimers.values) {
      timer.cancel();
    }
    _progressUpdateController.close();
    _chapterProgressController.close();
    _overallStatsController.close();
    super.dispose();
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
```

---

## question_provider.dart

**File Path:** `lib/providers/question_provider.dart`

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../models/question_model.dart';
import '../utils/helpers.dart';

class QuestionProvider with ChangeNotifier {
  final ApiService apiService;
  final DeviceService deviceService;

  List<Question> _questions = [];
  Map<int, List<Question>> _questionsByChapter = {};
  Map<int, bool> _hasLoadedForChapter = {};
  Map<int, bool> _isLoadingForChapter = {};
  Map<int, DateTime> _lastLoadedTime = {};
  Map<int, Map<int, bool>> _answerResults = {};
  Map<int, Map<int, String>> _selectedAnswers = {};
  bool _isLoading = false;
  String? _error;

  StreamController<Map<String, dynamic>> _questionUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();
  StreamController<Map<String, dynamic>> _answerUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();

  static const Duration cacheDuration = Duration(minutes: 20);
  static const Duration answerCacheDuration = Duration(days: 7);

  QuestionProvider({required this.apiService, required this.deviceService});

  List<Question> get questions => _questions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Stream<Map<String, dynamic>> get questionUpdates =>
      _questionUpdateController.stream;
  Stream<Map<String, dynamic>> get answerUpdates =>
      _answerUpdateController.stream;

  bool hasLoadedForChapter(int chapterId) =>
      _hasLoadedForChapter[chapterId] ?? false;
  bool isLoadingForChapter(int chapterId) =>
      _isLoadingForChapter[chapterId] ?? false;

  List<Question> getQuestionsByChapter(int chapterId) {
    return _questionsByChapter[chapterId] ?? [];
  }

  Future<void> loadPracticeQuestions(int chapterId,
      {bool forceRefresh = false}) async {
    if (_isLoadingForChapter[chapterId] == true) {
      return;
    }

    final lastLoaded = _lastLoadedTime[chapterId];
    final hasCache = _hasLoadedForChapter[chapterId] == true;
    final isCacheValid = lastLoaded != null &&
        DateTime.now().difference(lastLoaded) < cacheDuration;

    if (hasCache && !forceRefresh && isCacheValid) {
      debugLog('QuestionProvider',
          '✅ Using cached questions for chapter: $chapterId');
      return;
    }

    _isLoadingForChapter[chapterId] = true;
    _error = null;
    notifyListeners();

    try {
      debugLog('QuestionProvider',
          '❓ Loading practice questions for chapter: $chapterId');
      final response = await apiService.getPracticeQuestions(chapterId);

      final responseData = response.data ?? {};
      final questionsData = responseData['questions'] ?? [];

      if (questionsData is List) {
        final questionList = <Question>[];
        for (var questionJson in questionsData) {
          try {
            questionList.add(Question.fromJson(questionJson));
          } catch (e) {
            debugLog('QuestionProvider',
                'Error parsing question: $e, data: $questionJson');
          }
        }

        _questionsByChapter[chapterId] = questionList;
        _hasLoadedForChapter[chapterId] = true;
        _lastLoadedTime[chapterId] = DateTime.now();

        for (final question in questionList) {
          if (!_questions.any((q) => q.id == question.id)) {
            _questions.add(question);
          }
        }

        await deviceService.saveCacheItem(
          'questions_chapter_$chapterId',
          questionList.map((q) => q.toJson()).toList(),
          ttl: cacheDuration,
        );

        await _loadAnswerResults(chapterId);

        debugLog('QuestionProvider',
            '✅ Loaded ${questionList.length} questions for chapter $chapterId');

        _questionUpdateController.add({
          'type': 'questions_loaded',
          'chapter_id': chapterId,
          'count': questionList.length
        });
      } else {
        _questionsByChapter[chapterId] = [];
        _hasLoadedForChapter[chapterId] = true;
        _lastLoadedTime[chapterId] = DateTime.now();
      }
    } catch (e) {
      _error = e.toString();
      debugLog('QuestionProvider', '❌ loadPracticeQuestions error: $e');

      try {
        final cachedQuestions = await deviceService
            .getCacheItem<List<dynamic>>('questions_chapter_$chapterId');
        if (cachedQuestions != null) {
          final questionList = <Question>[];
          for (var questionJson in cachedQuestions) {
            try {
              questionList.add(Question.fromJson(questionJson));
            } catch (e) {}
          }
          _questionsByChapter[chapterId] = questionList;
          _hasLoadedForChapter[chapterId] = true;
          _lastLoadedTime[chapterId] = DateTime.now();

          await _loadAnswerResults(chapterId);
        }
      } catch (cacheError) {
        debugLog('QuestionProvider', 'Cache load error: $cacheError');
      }

      if (!_hasLoadedForChapter[chapterId]!) {
        _questionsByChapter[chapterId] = [];
      }
    } finally {
      _isLoadingForChapter[chapterId] = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadAnswerResults(int chapterId) async {
    final questions = _questionsByChapter[chapterId] ?? [];

    if (!_answerResults.containsKey(chapterId)) {
      _answerResults[chapterId] = {};
    }
    if (!_selectedAnswers.containsKey(chapterId)) {
      _selectedAnswers[chapterId] = {};
    }

    for (final question in questions) {
      final result = await deviceService
          .getCacheItem<bool>('answer_result_${question.id}');
      if (result != null) {
        _answerResults[chapterId]![question.id] = result;
      }

      final selected = await deviceService
          .getCacheItem<String>('selected_answer_${question.id}');
      if (selected != null) {
        _selectedAnswers[chapterId]![question.id] = selected;
      }
    }
  }

  Future<Map<String, dynamic>> checkAnswer(
    int questionId,
    String selectedOption,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugLog('QuestionProvider',
          '✅ Checking answer for question:$questionId option:$selectedOption');
      final response = await apiService.checkAnswer(questionId, selectedOption);

      final index = _questions.indexWhere((q) => q.id == questionId);
      if (index != -1) {
        final question = _questions[index];
        final isCorrect = response.data?['is_correct'] == true;

        _questions[index] = Question(
          id: question.id,
          chapterId: question.chapterId,
          questionText: question.questionText,
          optionA: question.optionA,
          optionB: question.optionB,
          optionC: question.optionC,
          optionD: question.optionD,
          optionE: question.optionE,
          optionF: question.optionF,
          correctOption: question.correctOption,
          explanation: response.data?['explanation'] ?? question.explanation,
          difficulty: question.difficulty,
          hasAnswer: true,
        );

        int? chapterId;
        for (final entry in _questionsByChapter.entries) {
          if (entry.value.any((q) => q.id == questionId)) {
            chapterId = entry.key;
            break;
          }
        }

        if (chapterId != null) {
          if (!_answerResults.containsKey(chapterId)) {
            _answerResults[chapterId] = {};
          }
          if (!_selectedAnswers.containsKey(chapterId)) {
            _selectedAnswers[chapterId] = {};
          }

          _answerResults[chapterId]![questionId] = isCorrect;
          _selectedAnswers[chapterId]![questionId] = selectedOption;

          await deviceService.saveCacheItem(
            'answer_result_$questionId',
            isCorrect,
            ttl: answerCacheDuration,
          );
          await deviceService.saveCacheItem(
            'selected_answer_$questionId',
            selectedOption,
            ttl: answerCacheDuration,
          );

          _answerUpdateController.add({
            'type': 'answer_checked',
            'question_id': questionId,
            'chapter_id': chapterId,
            'is_correct': isCorrect,
            'selected_option': selectedOption,
            'correct_option': question.correctOption,
            'explanation': response.data?['explanation']
          });
        }

        notifyListeners();
      }

      return response.data ?? {};
    } catch (e) {
      _error = e.toString();
      debugLog('QuestionProvider', '❌ checkAnswer error: $e');
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Question? getQuestionById(int id) {
    try {
      return _questions.firstWhere((q) => q.id == id);
    } catch (e) {
      return null;
    }
  }

  bool? getAnswerResult(int chapterId, int questionId) {
    return _answerResults[chapterId]?[questionId];
  }

  String? getSelectedAnswer(int chapterId, int questionId) {
    return _selectedAnswers[chapterId]?[questionId];
  }

  int getCorrectAnswersCount(int chapterId) {
    final results = _answerResults[chapterId];
    if (results == null) return 0;

    return results.values.where((isCorrect) => isCorrect == true).length;
  }

  int getAttemptedQuestionsCount(int chapterId) {
    final results = _answerResults[chapterId];
    return results?.length ?? 0;
  }

  double getAccuracyPercentage(int chapterId) {
    final attempted = getAttemptedQuestionsCount(chapterId);
    final correct = getCorrectAnswersCount(chapterId);

    if (attempted == 0) return 0.0;
    return (correct / attempted) * 100;
  }

  Future<void> clearQuestionsForChapter(int chapterId) async {
    _hasLoadedForChapter.remove(chapterId);
    _lastLoadedTime.remove(chapterId);

    final chapterQuestions = _questionsByChapter[chapterId] ?? [];
    _questions.removeWhere(
        (question) => chapterQuestions.any((q) => q.id == question.id));
    _questionsByChapter.remove(chapterId);

    _answerResults.remove(chapterId);
    _selectedAnswers.remove(chapterId);

    await deviceService.removeCacheItem('questions_chapter_$chapterId');

    for (final question in chapterQuestions) {
      await deviceService.removeCacheItem('answer_result_${question.id}');
      await deviceService.removeCacheItem('selected_answer_${question.id}');
    }

    _questionUpdateController
        .add({'type': 'questions_cleared', 'chapter_id': chapterId});

    notifyListeners();
  }

  Future<void> clearUserData() async {
    debugLog('QuestionProvider', 'Clearing question data');

    _questions.clear();
    _questionsByChapter.clear();
    _hasLoadedForChapter.clear();
    _lastLoadedTime.clear();
    _isLoadingForChapter.clear();
    _answerResults.clear();
    _selectedAnswers.clear();

    await deviceService.clearCacheByPrefix('questions_');
    await deviceService.clearCacheByPrefix('answer_result_');
    await deviceService.clearCacheByPrefix('selected_answer_');

    _questionUpdateController.close();
    _answerUpdateController.close();

    _questionUpdateController =
        StreamController<Map<String, dynamic>>.broadcast();
    _answerUpdateController =
        StreamController<Map<String, dynamic>>.broadcast();

    _questionUpdateController.add({'type': 'all_questions_cleared'});
    _answerUpdateController.add({'type': 'all_answers_cleared'});

    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _questionUpdateController.close();
    _answerUpdateController.close();
    super.dispose();
  }
}
```

---

## school_provider.dart

**File Path:** `lib/providers/school_provider.dart`

```dart
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
      try {
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
        _lastLoadTime = DateTime.now();

        await deviceService.saveCacheItem('schools_list', _schools,
            ttl: _schoolsCacheTTL);
        await _loadSelectedSchool();

        debugLog('SchoolProvider', 'Loaded schools: ${_schools.length}');
        _hasError = false;
        _schoolsUpdateController.add(_schools);
      } else {
        _error = response.message ?? 'Failed to load schools';
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
    try {
      final selectedSchool =
          await deviceService.getCacheItem<int>('selected_school');
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
```

---

## settings_provider.dart

**File Path:** `lib/providers/settings_provider.dart`

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../models/setting_model.dart';
import '../utils/helpers.dart';
import '../utils/constants.dart';

class SettingsProvider with ChangeNotifier {
  final ApiService apiService;
  final DeviceService deviceService;

  List<Setting> _allSettings = [];
  Map<String, Setting> _settingsMap = {};
  Map<String, List<Setting>> _settingsByCategory = {};
  bool _isLoading = false;
  String? _error;

  final Map<String, DateTime> _lastCategoryLoadTime = {};
  static const Duration _categoryLoadMinInterval = Duration(minutes: 5);
  final Map<String, Completer<bool>> _ongoingLoads = {};
  StreamController<List<Setting>> _settingsUpdateController =
      StreamController<List<Setting>>.broadcast();

  SettingsProvider({required this.apiService, required this.deviceService});

  List<Setting> get allSettings => List.unmodifiable(_allSettings);
  Map<String, List<Setting>> get settingsByCategory =>
      Map.unmodifiable(_settingsByCategory);
  bool get isLoading => _isLoading;
  String? get error => _error;
  Stream<List<Setting>> get settingsUpdates => _settingsUpdateController.stream;

  List<Setting> getSettingsByCategory(String category) {
    return List.unmodifiable(_settingsByCategory[category] ?? []);
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

  bool _shouldLoadCategory(String category, {bool forceRefresh = false}) {
    if (forceRefresh) return true;
    final lastLoad = _lastCategoryLoadTime[category];
    if (lastLoad == null) return true;
    final minutesSinceLastLoad = DateTime.now().difference(lastLoad).inMinutes;
    return minutesSinceLastLoad >= 5;
  }

  // Get ALL contact settings
  List<ContactInfo> getContactInfoList() {
    final contacts = <ContactInfo>[];
    final contactSettings = _settingsByCategory['contact'] ?? [];

    for (final setting in contactSettings) {
      if (setting.settingValue == null || setting.settingValue!.isEmpty)
        continue;

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

    return contacts;
  }

  bool _isPhoneNumber(String value) {
    final clean = value.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
    if (RegExp(r'^\d{8,15}$').hasMatch(clean)) return true;
    if (RegExp(r'^\+?\d{1,4}[\s\-]?\d{1,4}[\s\-]?\d{1,4}[\s\-]?\d{1,4}$')
        .hasMatch(value)) return true;
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

  // Get ALL payment methods
  List<PaymentMethod> getPaymentMethods() {
    final methods = <PaymentMethod>[];

    if (_allSettings.isEmpty) return methods;

    final enabledValue = getSettingValue('payment_methods_enabled');
    bool methodsEnabled =
        enabledValue == null || enabledValue.toString().toLowerCase() == 'true';
    if (!methodsEnabled) return methods;

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

    methods.sort((a, b) => a.name.compareTo(b.name));
    return methods;
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
    if (method.contains('hellocash') || nameLower.contains('hellocash')) {
      return Icons.phone_android;
    }
    if (method.contains('amole') || nameLower.contains('amole')) {
      return Icons.phone_android;
    }
    if (method.contains('cbe') ||
        nameLower.contains('cbe') ||
        nameLower.contains('commercial')) {
      return Icons.account_balance;
    }
    if (method.contains('awash') || nameLower.contains('awash')) {
      return Icons.account_balance;
    }
    if (method.contains('dashen') || nameLower.contains('dashen')) {
      return Icons.account_balance;
    }
    if (method.contains('abyssinia') || nameLower.contains('abyssinia')) {
      return Icons.account_balance;
    }
    if (method.contains('nib') || nameLower.contains('nib')) {
      return Icons.account_balance;
    }
    if (method.contains('zemen') || nameLower.contains('zemen')) {
      return Icons.account_balance;
    }
    if (method.contains('bank') || nameLower.contains('bank')) {
      return Icons.account_balance;
    }
    if (method.contains('paypal') || nameLower.contains('paypal')) {
      return Icons.payments;
    }
    if (method.contains('bitcoin') ||
        nameLower.contains('bitcoin') ||
        nameLower.contains('crypto')) {
      return Icons.currency_bitcoin;
    }
    if (method.contains('western') || nameLower.contains('western')) {
      return Icons.send;
    }
    if (method.contains('card') ||
        nameLower.contains('card') ||
        nameLower.contains('credit') ||
        nameLower.contains('debit')) {
      return Icons.credit_card;
    }
    if (method.contains('cash') || nameLower.contains('cash')) {
      return Icons.money;
    }
    return Icons.payment;
  }

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

  String getOfficeAddress() {
    final contactSettings = getContactInfoList();
    for (final contact in contactSettings) {
      if (contact.type == ContactType.address) return contact.value;
    }
    return 'Addis Ababa, Ethiopia';
  }

  String getOfficeHours() {
    final contactSettings = getContactInfoList();
    for (final contact in contactSettings) {
      if (contact.type == ContactType.hours) return contact.value;
    }
    return 'Monday - Friday: 9:00 AM - 5:00 PM';
  }

  String getWhatsAppNumber() {
    final contactSettings = getContactInfoList();
    for (final contact in contactSettings) {
      if (contact.type == ContactType.whatsapp) return contact.value;
    }
    return '';
  }

  String getWebsite() {
    final contactSettings = getContactInfoList();
    for (final contact in contactSettings) {
      if (contact.type == ContactType.website) return contact.value;
    }
    return '';
  }

  String getPaymentInstructions() {
    return getSettingValue('payment_instructions') ??
        'Please follow these steps to complete your payment:\n'
            '1. Select a payment method\n'
            '2. Make the payment using the provided account details\n'
            '3. Upload proof of payment\n'
            '4. Wait for admin verification (usually within 24 hours)\n'
            '5. Your access will be activated once verified';
  }

  bool isPaymentMethodConfigured(String methodKey) {
    final name = getSettingValue('payment_method_${methodKey}_name');
    final number = getSettingValue('payment_method_${methodKey}_number');
    return name != null &&
        name.isNotEmpty &&
        number != null &&
        number.isNotEmpty;
  }

  List<String> getConfiguredPaymentMethods() {
    final methods = <String>[];
    for (final setting in _allSettings) {
      final key = setting.settingKey;
      if (key.startsWith('payment_method_') && key.endsWith('_name')) {
        final methodName = key.substring(
            'payment_method_'.length, key.length - '_name'.length);
        if (isPaymentMethodConfigured(methodName)) methods.add(methodName);
      }
    }
    return methods;
  }

  String getSystemVersion() {
    return getSettingValue('system_version') ?? '1.0.0';
  }

  String getAdminEmail() {
    return getSettingValue('admin_email') ?? 'admin@familyacademy.com';
  }

  Future<void> getAllSettings() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      final cachedSettings =
          await deviceService.getCacheItem<List<Setting>>('all_settings');
      if (cachedSettings != null && cachedSettings.isNotEmpty) {
        _allSettings = cachedSettings;
        _rebuildMaps();
        _isLoading = false;
        _settingsUpdateController.add(_allSettings);
        _notifySafely();
        _refreshSettingsInBackground();
        return;
      }

      final response = await apiService.getAllSettings();

      if (response.success &&
          response.data != null &&
          response.data!.isNotEmpty) {
        _allSettings = response.data!;
        await deviceService.saveCacheItem('all_settings', _allSettings,
            ttl: const Duration(minutes: 30));
      }

      _rebuildMaps();
      _settingsUpdateController.add(_allSettings);
    } catch (e) {
      _error = e.toString();
      _rebuildMaps();
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> _refreshSettingsInBackground() async {
    try {
      final response = await apiService.getAllSettings();
      if (response.success &&
          response.data != null &&
          response.data!.isNotEmpty) {
        _allSettings = response.data!;
        _rebuildMaps();
        _settingsUpdateController.add(_allSettings);
        await deviceService.saveCacheItem('all_settings', _allSettings,
            ttl: const Duration(minutes: 30));
      }
    } catch (e) {}
  }

  Future<void> loadContactSettings({bool? forceRefresh}) async {
    final shouldForce = forceRefresh ?? false;

    if (!shouldForce &&
        _settingsByCategory.containsKey('contact') &&
        _settingsByCategory['contact']!.isNotEmpty) return;

    if (_allSettings.isEmpty || shouldForce) await getAllSettings();
  }

  Future<void> loadSettingsByCategory(String category) async {
    if (_isLoading) return;
    if (!_shouldLoadCategory(category)) return;
    if (_ongoingLoads.containsKey(category)) {
      await _ongoingLoads[category]!.future;
      return;
    }

    final completer = Completer<bool>();
    _ongoingLoads[category] = completer;

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      final cacheKey = 'settings_category_$category';
      final cachedSettings =
          await deviceService.getCacheItem<List<Setting>>(cacheKey);
      if (cachedSettings != null) {
        _settingsByCategory[category] = cachedSettings;
        for (final setting in cachedSettings)
          _settingsMap[setting.settingKey] = setting;
        _isLoading = false;
        _lastCategoryLoadTime[category] = DateTime.now();
        completer.complete(true);
        return;
      }

      final response = await apiService.getSettingsByCategory(category);
      final categorySettings = response.data ?? [];

      _settingsByCategory[category] = categorySettings;
      for (final setting in categorySettings)
        _settingsMap[setting.settingKey] = setting;

      await deviceService.saveCacheItem(cacheKey, categorySettings,
          ttl: Duration(minutes: 30));
      _lastCategoryLoadTime[category] = DateTime.now();
      completer.complete(true);
    } catch (e) {
      _error = e.toString();
      completer.complete(false);
    } finally {
      _isLoading = false;
      _ongoingLoads.remove(category);
      _notifySafely();
    }
  }

  Future<void> loadPaymentSettings() async {
    await loadSettingsByCategory('payment');
  }

  Future<void> loadSystemSettings() async {
    await loadSettingsByCategory('system');
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
  }

  Future<void> clearUserData() async {
    await deviceService.clearCacheByPrefix('settings');
    await deviceService.clearCacheByPrefix('all_settings');

    _allSettings.clear();
    _settingsMap.clear();
    _settingsByCategory.clear();
    _lastCategoryLoadTime.clear();
    _ongoingLoads.clear();

    _settingsUpdateController.close();
    _settingsUpdateController = StreamController<List<Setting>>.broadcast();
    _settingsUpdateController.add(_allSettings);
    _notifySafely();
  }

  void clearError() {
    _error = null;
    _notifySafely();
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
    _settingsUpdateController.close();
    super.dispose();
  }
}

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

enum ContactType {
  phone,
  email,
  whatsapp,
  telegram,
  address,
  hours,
  website,
  social,
  other,
}
```

---

## streak_provider.dart

**File Path:** `lib/providers/streak_provider.dart`

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../models/streak_model.dart';
import '../utils/helpers.dart';

class StreakProvider with ChangeNotifier {
  final ApiService apiService;
  final DeviceService deviceService;

  Streak? _streak;
  bool _isLoading = false;
  String? _error;
  List<DateTime> _streakHistory = [];
  Timer? _refreshTimer;
  String? _currentUserId;

  static const Duration _refreshInterval = Duration(minutes: 5);
  static const Duration _cacheDuration = Duration(hours: 1);

  StreakProvider({required this.apiService, required this.deviceService}) {
    _init();
  }

  Future<void> _init() async {
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (!_isLoading) loadStreak(forceRefresh: true);
    });
    await _getCurrentUserId();
    await loadStreak(forceRefresh: false);
  }

  Future<void> _getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('current_user_id');
  }

  Streak? get streak => _streak;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<DateTime> get streakHistory => _streakHistory;

  int get currentStreak => _streak?.currentStreak ?? 0;

  String get streakLevel {
    final count = currentStreak;
    if (count >= 365) return 'Legendary 🔥🔥🔥';
    if (count >= 100) return 'Elite 🏆';
    if (count >= 50) return 'Master ⭐';
    if (count >= 30) return 'Dedicated 📚';
    if (count >= 14) return 'Committed 💪';
    if (count >= 7) return 'Consistent 🚀';
    if (count >= 3) return 'Growing 🌱';
    return 'New ✨';
  }

  Color get streakColor {
    final count = currentStreak;
    if (count >= 100) return const Color(0xFFFFD700);
    if (count >= 50) return const Color(0xFFC0C0C0);
    if (count >= 30) return const Color(0xFFCD7F32);
    if (count >= 14) return const Color(0xFF34C759);
    if (count >= 7) return const Color(0xFF2AABEE);
    return const Color(0xFFFF9500);
  }

  IconData get streakIcon {
    final count = currentStreak;
    if (count >= 100) return Icons.emoji_events;
    if (count >= 50) return Icons.military_tech;
    if (count >= 30) return Icons.workspace_premium;
    if (count >= 14) return Icons.star;
    if (count >= 7) return Icons.local_fire_department;
    return Icons.bolt;
  }

  Future<void> loadStreak({bool forceRefresh = false}) async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      if (!forceRefresh && _currentUserId != null) {
        final cachedStreak =
            await deviceService.getCacheItem<Map<String, dynamic>>(
          'streak_$_currentUserId',
          isUserSpecific: true,
        );
        if (cachedStreak != null) {
          _streak = Streak.fromJson(cachedStreak);
          _streakHistory = _streak?.history ?? [];
          _isLoading = false;
          _notifySafely();
          return;
        }
      }

      final response = await apiService.getMyStreak();
      if (response.success && response.data != null) {
        _streak = Streak.fromJson(response.data!);
        _streakHistory = _streak?.history ?? [];

        if (_currentUserId != null) {
          await deviceService.saveCacheItem(
            'streak_$_currentUserId',
            response.data!,
            ttl: _cacheDuration,
            isUserSpecific: true,
          );
        }
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> updateStreak() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      await apiService.updateStreak();
      await loadStreak(forceRefresh: true);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  bool get hasStreakToday {
    final today = DateTime.now();
    return _streakHistory.any(
      (date) =>
          date.year == today.year &&
          date.month == today.month &&
          date.day == today.day,
    );
  }

  bool hasStreakOnDate(DateTime date) {
    return _streakHistory.any(
      (streakDate) =>
          streakDate.year == date.year &&
          streakDate.month == date.month &&
          streakDate.day == date.day,
    );
  }

  int getWeeklyStreak() {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    return _streakHistory.where((date) => date.isAfter(weekAgo)).length;
  }

  List<bool> getLast7DaysStreak() {
    final days = List<bool>.filled(7, false);
    final now = DateTime.now();

    for (final date in _streakHistory) {
      final diff = now.difference(date).inDays;
      if (diff < 7) days[6 - diff] = true;
    }
    return days;
  }

  String getMotivationalMessage() {
    final count = currentStreak;
    if (count >= 365) return "ONE YEAR! You're a true legend! 🏆";
    if (count >= 100) return "100 days! You're in the elite club! 👑";
    if (count >= 50) return "50 days of dedication! You're a master! ⭐";
    if (count >= 30) return "30 days! You've built an incredible habit! 📚";
    if (count >= 14) return "Two weeks strong! Keep going! 💪";
    if (count >= 7) return "One week! Consistency is your superpower! 🚀";
    if (count >= 3) return "3 days in a row! You're building momentum! 🌱";
    if (count == 2) return "Two days! Come back tomorrow! 🔥";
    if (count == 1) return "Great start! Make it two tomorrow! ✨";
    return "Start your streak today! 📅";
  }

  Future<void> clearUserData() async {
    if (_currentUserId != null) {
      await deviceService.removeCacheItem('streak_$_currentUserId',
          isUserSpecific: true);
    }
    _streak = null;
    _streakHistory = [];
    _notifySafely();
  }

  void clearError() {
    _error = null;
    _notifySafely();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _notifySafely() {
    if (hasListeners) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (hasListeners) notifyListeners();
      });
    }
  }
}
```

---

## subscription_provider.dart

**File Path:** `lib/providers/subscription_provider.dart`

```dart
import 'dart:async';
import 'package:familyacademyclient/providers/category_provider.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../models/subscription_model.dart';
import '../utils/helpers.dart';

class SubscriptionProvider with ChangeNotifier {
  final ApiService apiService;
  final DeviceService deviceService;

  Map<int, Subscription> _subscriptionsByCategory = {};
  List<Subscription> _allSubscriptions = [];
  Map<int, bool> _categoryAccessCache = {};
  Map<int, bool> _categoryCheckComplete = {};
  Map<int, DateTime> _lastCheckTime = {};

  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _error;

  Timer? _backgroundRefreshTimer;
  // CHANGED: Increased from 30 seconds to 5 minutes
  static const Duration _backgroundRefreshInterval = Duration(minutes: 5);
  static const Duration _cacheDuration = Duration(minutes: 30);

  // NEW: Track last background refresh time to prevent multiple refreshes
  DateTime? _lastBackgroundRefreshTime;

  final StreamController<Map<int, bool>> _subscriptionUpdateController =
      StreamController<Map<int, bool>>.broadcast();
  final StreamController<List<Subscription>> _subscriptionsUpdateController =
      StreamController<List<Subscription>>.broadcast();
  final StreamController<int> _subscriptionStatusChangedController =
      StreamController<int>.broadcast();

  final Map<int, Completer<bool>> _categoryCheckCompleters = {};
  static const Duration _categoryCheckTimeout = Duration(seconds: 10);

  CategoryProvider? _categoryProvider;

  SubscriptionProvider({
    required this.apiService,
    required this.deviceService,
  }) {
    _initBackgroundRefresh();
  }

  void setCategoryProvider(CategoryProvider categoryProvider) {
    _categoryProvider = categoryProvider;
    debugLog('SubscriptionProvider', '✅ CategoryProvider reference set');
  }

  List<Subscription> get allSubscriptions =>
      List.unmodifiable(_allSubscriptions);
  Map<int, Subscription> get subscriptionsByCategory =>
      Map.unmodifiable(_subscriptionsByCategory);
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get error => _error;

  List<Subscription> get activeSubscriptions {
    return _allSubscriptions.where((sub) => sub.isActive).toList();
  }

  List<Subscription> get expiredSubscriptions {
    return _allSubscriptions.where((sub) => sub.isExpired).toList();
  }

  List<Subscription> get expiringSoonSubscriptions {
    return _allSubscriptions.where((sub) => sub.isExpiringSoon).toList();
  }

  Stream<Map<int, bool>> get subscriptionUpdates =>
      _subscriptionUpdateController.stream;
  Stream<List<Subscription>> get subscriptionsUpdates =>
      _subscriptionsUpdateController.stream;
  Stream<int> get subscriptionStatusChanged =>
      _subscriptionStatusChangedController.stream;

  void _initBackgroundRefresh() {
    _backgroundRefreshTimer = Timer.periodic(_backgroundRefreshInterval, (_) {
      if (_hasLoaded && !_isLoading) {
        _performBackgroundRefresh();
      }
    });
  }

  // NEW: Separate method for background refresh with time tracking
  Future<void> _performBackgroundRefresh() async {
    // Check if we've refreshed recently
    if (_lastBackgroundRefreshTime != null) {
      final minutesSinceLastRefresh =
          DateTime.now().difference(_lastBackgroundRefreshTime!).inMinutes;

      // Don't refresh if less than 2 minutes have passed
      if (minutesSinceLastRefresh < 2) {
        debugLog('SubscriptionProvider',
            '⏰ Skipping background refresh - only $minutesSinceLastRefresh minutes since last refresh');
        return;
      }
    }

    _lastBackgroundRefreshTime = DateTime.now();
    await _refreshInBackground();
  }

  Future<void> _refreshInBackground() async {
    debugLog('SubscriptionProvider', '🔄 Background refresh started');

    try {
      final response = await apiService.getMySubscriptions();

      if (response.success && response.data != null) {
        final newSubscriptions = response.data!;

        bool hasChanges = _hasSubscriptionChanges(newSubscriptions);

        if (hasChanges) {
          debugLog(
              'SubscriptionProvider', '📦 Changes detected, updating cache');
          _allSubscriptions = newSubscriptions;
          await deviceService.saveCacheItem('subscriptions', _allSubscriptions,
              ttl: _cacheDuration, isUserSpecific: true);

          _rebuildCacheFromSubscriptions();
          _notifyChanges();
        } else {
          debugLog('SubscriptionProvider', '✅ No changes detected');
        }
      } else {
        debugLog(
            'SubscriptionProvider', '⚠️ Background refresh returned no data');
      }
    } catch (e) {
      // Check if it's a 429 rate limit error
      if (e.toString().contains('429') ||
          e.toString().contains('Too many requests')) {
        debugLog('SubscriptionProvider',
            '⚠️ Rate limited in background, will retry later');
      } else {
        debugLog('SubscriptionProvider', '⚠️ Background refresh failed: $e');
      }
    }
  }

  bool _hasSubscriptionChanges(List<Subscription> newSubscriptions) {
    if (_allSubscriptions.length != newSubscriptions.length) return true;

    for (int i = 0; i < newSubscriptions.length; i++) {
      if (!_allSubscriptions.any((s) =>
          s.id == newSubscriptions[i].id &&
          s.isActive == newSubscriptions[i].isActive)) {
        return true;
      }
    }

    return false;
  }

  Future<void> loadSubscriptions({bool forceRefresh = false}) async {
    if (_isLoading && !forceRefresh) return;

    if (_hasLoaded && !forceRefresh && _allSubscriptions.isNotEmpty) {
      debugLog('SubscriptionProvider', '📦 Using cached subscriptions');
      return;
    }

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('SubscriptionProvider', '📥 Loading subscriptions...');

      if (!forceRefresh) {
        final cachedSubscriptions = await deviceService
            .getCacheItem<List<Subscription>>('subscriptions',
                isUserSpecific: true);

        if (cachedSubscriptions != null && cachedSubscriptions.isNotEmpty) {
          _allSubscriptions = cachedSubscriptions;
          _rebuildCacheFromSubscriptions();
          _hasLoaded = true;
          _isLoading = false;
          _notifySafely();
          _subscriptionsUpdateController.add(_allSubscriptions);

          if (_categoryProvider != null) {
            final statusMap = <int, bool>{};
            for (final sub in _allSubscriptions) {
              statusMap[sub.categoryId] = sub.isActive;
            }
            unawaited(
                _categoryProvider!.batchUpdateSubscriptionStatus(statusMap));
          }

          debugLog('SubscriptionProvider',
              '✅ Loaded ${_allSubscriptions.length} subscriptions from cache');

          // Don't auto-refresh after cache load - let the timer handle it
          // unawaited(_refreshInBackground());
          return;
        }
      }

      final response = await apiService.getMySubscriptions();

      if (response.success && response.data != null) {
        _allSubscriptions = response.data!;

        await deviceService.saveCacheItem('subscriptions', _allSubscriptions,
            ttl: _cacheDuration, isUserSpecific: true);

        _rebuildCacheFromSubscriptions();
        _hasLoaded = true;

        debugLog('SubscriptionProvider',
            '✅ Loaded ${_allSubscriptions.length} subscriptions, ${activeSubscriptions.length} active');

        _notifyChanges();

        if (_categoryProvider != null) {
          final statusMap = <int, bool>{};
          for (final sub in _allSubscriptions) {
            statusMap[sub.categoryId] = sub.isActive;
          }
          unawaited(
              _categoryProvider!.batchUpdateSubscriptionStatus(statusMap));
        }
      } else {
        _error = response.message;
        debugLog('SubscriptionProvider',
            '❌ Failed to load subscriptions: ${response.message}');
      }
    } catch (e, stackTrace) {
      _error = e.toString();
      debugLog('SubscriptionProvider', '❌ Error loading subscriptions: $e');

      // Check if it's a rate limit error
      if (e.toString().contains('429') ||
          e.toString().contains('Too many requests')) {
        debugLog('SubscriptionProvider', '⚠️ Rate limited, using cached data');
        // Don't clear cache on rate limit
        if (_allSubscriptions.isEmpty) {
          // Try to get from cache again
          final cachedSubscriptions = await deviceService
              .getCacheItem<List<Subscription>>('subscriptions',
                  isUserSpecific: true);
          if (cachedSubscriptions != null && cachedSubscriptions.isNotEmpty) {
            _allSubscriptions = cachedSubscriptions;
            _rebuildCacheFromSubscriptions();
            _hasLoaded = true;
            debugLog('SubscriptionProvider',
                '✅ Recovered from cache after rate limit');
          }
        }
      } else if (_allSubscriptions.isEmpty) {
        _allSubscriptions = [];
        _rebuildCacheFromSubscriptions();
      }
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  void _rebuildCacheFromSubscriptions() {
    debugLog('SubscriptionProvider',
        '🔄 Rebuilding cache from ${_allSubscriptions.length} subscriptions');

    _subscriptionsByCategory = {};
    _categoryAccessCache = {};
    _categoryCheckComplete = {};
    _lastCheckTime = {};

    for (final sub in _allSubscriptions) {
      final isActive = sub.isActive;

      _subscriptionsByCategory[sub.categoryId] = sub;
      _categoryAccessCache[sub.categoryId] = isActive;
      _categoryCheckComplete[sub.categoryId] = true;
      _lastCheckTime[sub.categoryId] = DateTime.now();

      debugLog('SubscriptionProvider',
          '✅ Category ${sub.categoryId} access set to: $isActive');
    }
  }

  void _notifyChanges() {
    _subscriptionsUpdateController.add(_allSubscriptions);
    _subscriptionUpdateController.add(Map.from(_categoryAccessCache));
    for (final categoryId in _categoryAccessCache.keys) {
      _subscriptionStatusChangedController.add(categoryId);
    }
  }

  bool hasActiveSubscriptionForCategory(int categoryId) {
    if (_categoryAccessCache.containsKey(categoryId)) {
      return _categoryAccessCache[categoryId]!;
    }

    final subscription = _subscriptionsByCategory[categoryId];
    if (subscription != null) {
      final isActive = subscription.isActive;
      _categoryAccessCache[categoryId] = isActive;
      _categoryCheckComplete[categoryId] = true;
      _lastCheckTime[categoryId] = DateTime.now();
      return isActive;
    }

    return false;
  }

  Future<bool> checkHasActiveSubscriptionForCategory(int categoryId) async {
    debugLog('SubscriptionProvider',
        '🔍 Checking subscription for category: $categoryId');

    if (_categoryAccessCache.containsKey(categoryId)) {
      final result = _categoryAccessCache[categoryId]!;
      debugLog('SubscriptionProvider',
          '✅ Cache hit - category $categoryId: $result');
      return result;
    }

    if (_categoryCheckCompleters.containsKey(categoryId)) {
      debugLog('SubscriptionProvider',
          '⏳ Waiting for existing check for category: $categoryId');
      try {
        return await _categoryCheckCompleters[categoryId]!
            .future
            .timeout(_categoryCheckTimeout);
      } on TimeoutException {
        debugLog(
            'SubscriptionProvider', '⏰ Category check timeout for $categoryId');
        return false;
      }
    }

    final completer = Completer<bool>();
    _categoryCheckCompleters[categoryId] = completer;

    try {
      final response = await apiService.checkSubscriptionStatus(categoryId);

      if (response.success && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final hasSubscription = data['has_subscription'] == true;

        _categoryAccessCache[categoryId] = hasSubscription;
        _categoryCheckComplete[categoryId] = true;
        _lastCheckTime[categoryId] = DateTime.now();

        if (hasSubscription && data['id'] != null) {
          final subscription = Subscription(
            id: data['id'] as int? ?? 0,
            userId: data['user_id'] as int? ?? 0,
            categoryId: categoryId,
            startDate: DateTime.parse(data['start_date'] as String),
            expiryDate: DateTime.parse(data['expiry_date'] as String),
            status: data['status'] as String? ?? 'active',
            billingCycle: data['billing_cycle'] as String? ?? 'monthly',
            paymentId: data['payment_id'] as int?,
            createdAt: data['created_at'] != null
                ? DateTime.parse(data['created_at'] as String)
                : null,
            updatedAt: data['updated_at'] != null
                ? DateTime.parse(data['updated_at'] as String)
                : null,
            categoryName: data['category_name'] as String?,
            price: data['price'] != null
                ? double.parse(data['price'].toString())
                : null,
          );

          _subscriptionsByCategory[categoryId] = subscription;
          if (!_allSubscriptions.any((s) => s.id == subscription.id)) {
            _allSubscriptions.add(subscription);
            unawaited(deviceService.saveCacheItem(
                'subscriptions', _allSubscriptions,
                ttl: _cacheDuration, isUserSpecific: true));
          }
        }

        _subscriptionUpdateController.add({categoryId: hasSubscription});
        _subscriptionStatusChangedController.add(categoryId);

        if (_categoryProvider != null) {
          unawaited(_categoryProvider!
              .updateCategorySubscriptionStatus(categoryId, hasSubscription));
        }

        debugLog('SubscriptionProvider',
            '✅ API check - category $categoryId: $hasSubscription');
        completer.complete(hasSubscription);
        return hasSubscription;
      }

      _categoryAccessCache[categoryId] = false;
      _categoryCheckComplete[categoryId] = true;
      _lastCheckTime[categoryId] = DateTime.now();

      _subscriptionUpdateController.add({categoryId: false});
      _subscriptionStatusChangedController.add(categoryId);

      if (_categoryProvider != null) {
        unawaited(_categoryProvider!
            .updateCategorySubscriptionStatus(categoryId, false));
      }

      completer.complete(false);
      return false;
    } catch (e) {
      debugLog('SubscriptionProvider', '❌ Error checking subscription: $e');

      completer.complete(false);
      return false;
    } finally {
      _categoryCheckCompleters.remove(categoryId);
    }
  }

  Future<Map<int, bool>> checkSubscriptionsForCategories(
      List<int> categoryIds) async {
    final results = <int, bool>{};
    final updates = <int, bool>{};

    debugLog('SubscriptionProvider',
        '🔄 Checking subscriptions for categories: $categoryIds');

    for (final categoryId in categoryIds) {
      if (_categoryAccessCache.containsKey(categoryId)) {
        results[categoryId] = _categoryAccessCache[categoryId]!;
        updates[categoryId] = results[categoryId]!;
      }
    }

    final missingIds =
        categoryIds.where((id) => !results.containsKey(id)).toList();

    if (missingIds.isNotEmpty) {
      final futures =
          missingIds.map((id) => checkHasActiveSubscriptionForCategory(id));
      final newResults = await Future.wait(futures);

      for (int i = 0; i < missingIds.length; i++) {
        results[missingIds[i]] = newResults[i];
        updates[missingIds[i]] = newResults[i];
      }
    }

    if (_categoryProvider != null && updates.isNotEmpty) {
      unawaited(_categoryProvider!.batchUpdateSubscriptionStatus(updates));
    }

    debugLog(
        'SubscriptionProvider', '✅ Final subscription check results: $results');
    return results;
  }

  Future<void> preCheckActiveCategories(List<int> categoryIds) async {
    if (categoryIds.isEmpty) return;

    debugLog('SubscriptionProvider',
        '🔍 Pre-checking ${categoryIds.length} categories');

    final futures = <Future>[];
    final updates = <int, bool>{};

    for (final categoryId in categoryIds) {
      if (!_categoryAccessCache.containsKey(categoryId)) {
        futures.add(
            checkHasActiveSubscriptionForCategory(categoryId).then((result) {
          updates[categoryId] = result;
        }));
      }
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures);

      if (_categoryProvider != null && updates.isNotEmpty) {
        unawaited(_categoryProvider!.batchUpdateSubscriptionStatus(updates));
      }
    }
  }

  Future<void> refreshAfterPaymentVerification() async {
    debugLog(
        'SubscriptionProvider', '🔄 Refreshing after payment verification');

    await deviceService.clearCacheByPrefix('subscriptions');

    _allSubscriptions = [];
    _subscriptionsByCategory = {};
    _categoryAccessCache = {};
    _categoryCheckComplete = {};
    _lastCheckTime = {};
    _hasLoaded = false;

    await loadSubscriptions(forceRefresh: true);
    debugLog('SubscriptionProvider', '✅ Subscriptions refreshed');
  }

  Future<void> refreshCategorySubscription(int categoryId) async {
    try {
      await deviceService.removeCacheItem('category_access_$categoryId',
          isUserSpecific: true);

      _categoryAccessCache.remove(categoryId);
      _categoryCheckComplete.remove(categoryId);
      _lastCheckTime.remove(categoryId);

      await checkHasActiveSubscriptionForCategory(categoryId);
      debugLog('SubscriptionProvider',
          '✅ Refreshed subscription for category: $categoryId');
    } catch (e) {
      debugLog('SubscriptionProvider',
          '❌ Error refreshing category subscription: $e');
    }
  }

  Future<void> forceRefreshAllCategories() async {
    debugLog('SubscriptionProvider',
        '🔄 Force refreshing all category subscriptions');

    _categoryAccessCache.clear();
    _categoryCheckComplete.clear();
    _lastCheckTime.clear();
    _categoryCheckCompleters.clear();

    await deviceService.clearCacheByPrefix('subscriptions');
    await loadSubscriptions(forceRefresh: true);

    debugLog('SubscriptionProvider', '✅ All categories refreshed');
  }

  Future<void> clearUserData() async {
    debugLog('SubscriptionProvider', '🧹 Clearing subscription data');

    await deviceService.clearCacheByPrefix('subscriptions');

    _allSubscriptions = [];
    _subscriptionsByCategory = {};
    _categoryAccessCache = {};
    _categoryCheckComplete = {};
    _lastCheckTime = {};
    _hasLoaded = false;
    _categoryCheckCompleters.clear();

    _subscriptionUpdateController.add({});
    _subscriptionsUpdateController.add([]);

    _notifySafely();
  }

  void clearError() {
    _error = null;
    _notifySafely();
  }

  @override
  void dispose() {
    _backgroundRefreshTimer?.cancel();
    _subscriptionUpdateController.close();
    _subscriptionsUpdateController.close();
    _subscriptionStatusChangedController.close();
    _categoryCheckCompleters.clear();
    super.dispose();
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
```

---

## theme_provider.dart

**File Path:** `lib/providers/theme_provider.dart`

```dart
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../themes/app_themes.dart';
import '../utils/helpers.dart';

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  bool _isLoading = false;
  bool _hasLoaded = false;

  final GlobalKey _rootKey = GlobalKey();

  ThemeProvider() {
    _loadTheme();
  }

  ThemeMode get themeMode => _themeMode;
  ThemeData get lightTheme => AppThemes.lightTheme;
  ThemeData get darkTheme => AppThemes.darkTheme;
  bool get isLoading => _isLoading;
  GlobalKey get rootKey => _rootKey;

  Future<void> _loadTheme() async {
    if (_hasLoaded) return;

    _isLoading = true;
    debugLog('ThemeProvider', 'Loading saved theme');

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString(AppConstants.themeModeKey);

      if (savedTheme == 'dark') {
        _themeMode = ThemeMode.dark;
      } else if (savedTheme == 'light') {
        _themeMode = ThemeMode.light;
      } else {
        _themeMode = ThemeMode.light;
      }

      _hasLoaded = true;
      debugLog('ThemeProvider', 'Theme loaded: $_themeMode');
    } catch (e) {
      debugLog('ThemeProvider', 'Error loading theme: $e');
      _themeMode = ThemeMode.light;
    } finally {
      _isLoading = false;

      Future.delayed(const Duration(milliseconds: 50), () {
        if (hasListeners) {
          notifyListeners();
        }
      });
    }
  }

  Future<void> setTheme(ThemeMode themeMode) async {
    if (_themeMode == themeMode) return;

    _themeMode = themeMode;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      AppConstants.themeModeKey,
      themeMode == ThemeMode.dark ? 'dark' : 'light',
    );

    debugLog('ThemeProvider', 'Theme set to: $_themeMode');

    Future.delayed(const Duration(milliseconds: 50), () {
      notifyListeners();
    });
  }

  void toggleTheme() {
    setTheme(_themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }

  Future<void> clearUserData() async {
    debugLog('ThemeProvider', 'Theme preferences preserved (device-specific)');
  }
}
```

---

## user_provider.dart

**File Path:** `lib/providers/user_provider.dart`

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../models/user_model.dart';
import '../models/subscription_model.dart';
import '../models/payment_model.dart';
import '../models/notification_model.dart' as AppNotification;
import '../utils/helpers.dart';

class UserProvider with ChangeNotifier {
  final ApiService apiService;
  final DeviceService deviceService;

  User? _currentUser;
  List<Payment> _payments = [];
  List<AppNotification.Notification> _notifications = [];
  bool _isLoading = false;
  bool _hasLoadedProfile = false;
  bool _hasLoadedNotifications = false;
  bool _hasLoadedPayments = false;
  String? _error;
  String? _currentUserId;

  bool _isBackgroundRefreshing = false;
  bool _hasInitialCache = false;
  Timer? _backgroundRefreshTimer;
  StreamController<User?> _userUpdateController =
      StreamController<User?>.broadcast();
  StreamController<List<Payment>> _paymentsUpdateController =
      StreamController<List<Payment>>.broadcast();
  StreamController<List<AppNotification.Notification>>
      _notificationsUpdateController =
      StreamController<List<AppNotification.Notification>>.broadcast();

  DateTime? _lastProfileCacheTime;
  DateTime? _lastNotificationsCacheTime;
  DateTime? _lastPaymentsCacheTime;
  static const Duration _cacheExpiry = Duration(minutes: 10);
  static const Duration _backgroundRefreshInterval = Duration(minutes: 10);
  static const Duration _minRefreshInterval = Duration(minutes: 2);
  static final Map<String, DateTime> _lastRefreshTime = {};
  final Map<String, Completer<bool>> _ongoingRefreshes = {};

  UserProvider({required this.apiService, required this.deviceService}) {
    _init();
  }

  Future<void> _init() async {
    await _getCurrentUserId();
    _startBackgroundRefresh();
  }

  Future<void> _getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('current_user_id');
  }

  User? get currentUser => _currentUser;
  List<Payment> get payments => List.unmodifiable(_payments);
  List<AppNotification.Notification> get notifications =>
      List.unmodifiable(_notifications);
  bool get isLoading => _isLoading;
  bool get isBackgroundRefreshing => _isBackgroundRefreshing;
  bool get hasInitialCache => _hasInitialCache;
  String? get error => _error;

  Stream<User?> get userUpdates => _userUpdateController.stream;
  Stream<List<Payment>> get paymentsUpdates => _paymentsUpdateController.stream;
  Stream<List<AppNotification.Notification>> get notificationsUpdates =>
      _notificationsUpdateController.stream;

  bool _shouldRefresh(String type, {bool forceRefresh = false}) {
    if (forceRefresh) return true;
    final lastRefresh = _lastRefreshTime[type];
    if (lastRefresh == null) return true;
    final secondsSinceLastRefresh =
        DateTime.now().difference(lastRefresh).inSeconds;
    return secondsSinceLastRefresh >= _minRefreshInterval.inSeconds;
  }

  Future<bool> _executeRefresh(
      String type, Future<void> Function() refreshFunction,
      {bool forceRefresh = false}) async {
    if (!_shouldRefresh(type, forceRefresh: forceRefresh)) return false;
    if (_ongoingRefreshes.containsKey(type))
      return await _ongoingRefreshes[type]!.future;

    final completer = Completer<bool>();
    _ongoingRefreshes[type] = completer;

    try {
      await refreshFunction();
      _lastRefreshTime[type] = DateTime.now();
      completer.complete(true);
      return true;
    } catch (e) {
      completer.complete(false);
      return false;
    } finally {
      _ongoingRefreshes.remove(type);
    }
  }

  Future<void> loadUserProfile({bool forceRefresh = false}) async {
    if (!forceRefresh && _hasLoadedProfile && _currentUser != null) {
      _userUpdateController.add(_currentUser);
      return;
    }

    if (!_hasLoadedProfile || forceRefresh) {
      _isLoading = true;
      _notifySafely();
    }

    try {
      if (!forceRefresh && _currentUserId != null) {
        final cachedUser = await deviceService.getCacheItem<User>(
            'user_profile_$_currentUserId',
            isUserSpecific: true);
        if (cachedUser != null) {
          _currentUser = cachedUser;
          _hasLoadedProfile = true;
          _hasInitialCache = true;
          _lastProfileCacheTime = DateTime.now();
          _userUpdateController.add(_currentUser);
          if (_isCacheStale(_lastProfileCacheTime))
            unawaited(_refreshProfileInBackground());
          return;
        }
      }

      final response = await apiService.getMyProfile();
      if (response.success) {
        _currentUser = response.data is User
            ? response.data
            : User.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw Exception('Failed to load profile: ${response.message}');
      }

      _hasLoadedProfile = true;
      _hasInitialCache = true;
      _lastProfileCacheTime = DateTime.now();

      if (_currentUser != null && _currentUserId != null) {
        await deviceService.saveCacheItem(
            'user_profile_$_currentUserId', _currentUser!,
            ttl: _cacheExpiry, isUserSpecific: true);
      }

      _userUpdateController.add(_currentUser);
    } catch (e) {
      _error = e.toString();
      if (!forceRefresh && _currentUser != null)
        _userUpdateController.add(_currentUser);
      else
        rethrow;
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> _refreshProfileInBackground() async {
    await _executeRefresh('profile', () async {
      _isBackgroundRefreshing = true;
      try {
        final response = await apiService.getMyProfile();
        if (response.success) {
          User? updatedUser;
          if (response.data is User)
            updatedUser = response.data;
          else if (response.data is Map<String, dynamic>)
            updatedUser = User.fromJson(response.data as Map<String, dynamic>);

          if (updatedUser != null && _currentUser?.id == updatedUser.id) {
            _currentUser = updatedUser;
            _lastProfileCacheTime = DateTime.now();
            if (_currentUserId != null) {
              await deviceService.saveCacheItem(
                  'user_profile_$_currentUserId', _currentUser!,
                  ttl: _cacheExpiry, isUserSpecific: true);
            }
            if (_currentUser != null) _userUpdateController.add(_currentUser);
          }
        }
      } catch (e) {
      } finally {
        _isBackgroundRefreshing = false;
      }
    });
  }

  Future<void> loadPayments({bool forceRefresh = false}) async {
    if (!forceRefresh && _hasLoadedPayments && _payments.isNotEmpty) {
      _paymentsUpdateController.add(_payments);
      return;
    }

    if (!_hasLoadedPayments || forceRefresh) {
      _isLoading = true;
      _notifySafely();
    }

    try {
      if (!forceRefresh && _currentUserId != null) {
        final cachedPayments = await deviceService.getCacheItem<List<Payment>>(
            'user_payments_$_currentUserId',
            isUserSpecific: true);
        if (cachedPayments != null) {
          _payments = cachedPayments;
          _hasLoadedPayments = true;
          _lastPaymentsCacheTime = DateTime.now();
          _paymentsUpdateController.add(_payments);
          if (_isCacheStale(_lastPaymentsCacheTime))
            unawaited(_refreshPaymentsInBackground());
          return;
        }
      }

      final response = await apiService.getMyPayments();
      _payments = response.data ?? [];
      _hasLoadedPayments = true;
      _lastPaymentsCacheTime = DateTime.now();

      if (_currentUserId != null) {
        await deviceService.saveCacheItem(
            'user_payments_$_currentUserId', _payments,
            ttl: _cacheExpiry, isUserSpecific: true);
      }

      _paymentsUpdateController.add(_payments);
    } catch (e) {
      _error = e.toString();
      if (!forceRefresh && _payments.isNotEmpty)
        _paymentsUpdateController.add(_payments);
      else
        rethrow;
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> loadNotifications({bool forceRefresh = false}) async {
    if (!forceRefresh && _hasLoadedNotifications && _notifications.isNotEmpty) {
      _notificationsUpdateController.add(_notifications);
      return;
    }

    if (!_hasLoadedNotifications || forceRefresh) {
      _isLoading = true;
      _notifySafely();
    }

    try {
      if (!forceRefresh && _currentUserId != null) {
        final cachedNotifications = await deviceService
            .getCacheItem<List<AppNotification.Notification>>(
                'user_notifications_$_currentUserId',
                isUserSpecific: true);
        if (cachedNotifications != null) {
          _notifications = cachedNotifications;
          _hasLoadedNotifications = true;
          _lastNotificationsCacheTime = DateTime.now();
          _notificationsUpdateController.add(_notifications);
          if (_isCacheStale(_lastNotificationsCacheTime))
            unawaited(_refreshNotificationsInBackground());
          return;
        }
      }

      final response = await apiService.getMyNotifications();
      _notifications = response.data ?? [];
      _hasLoadedNotifications = true;
      _lastNotificationsCacheTime = DateTime.now();

      if (_currentUserId != null) {
        await deviceService.saveCacheItem(
            'user_notifications_$_currentUserId', _notifications,
            ttl: _cacheExpiry, isUserSpecific: true);
      }

      _notificationsUpdateController.add(_notifications);
    } catch (e) {
      _error = e.toString();
      if (!forceRefresh && _notifications.isNotEmpty)
        _notificationsUpdateController.add(_notifications);
      else
        rethrow;
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  void _startBackgroundRefresh() {
    _stopBackgroundRefresh();
    _backgroundRefreshTimer =
        Timer.periodic(_backgroundRefreshInterval, (timer) async {
      if (!_isLoading && !_isBackgroundRefreshing)
        await _refreshAllInBackground();
    });
  }

  void _stopBackgroundRefresh() {
    _backgroundRefreshTimer?.cancel();
    _backgroundRefreshTimer = null;
  }

  Future<void> _refreshAllInBackground() async {
    await Future.wait([
      _refreshProfileInBackground(),
      _refreshPaymentsInBackground(),
      _refreshNotificationsInBackground(),
    ], eagerError: false);
  }

  Future<void> _refreshPaymentsInBackground() async {
    await _executeRefresh('payments', () async {
      try {
        final response = await apiService.getMyPayments();
        if (response.data != null && response.data!.isNotEmpty) {
          _payments = response.data!;
          _lastPaymentsCacheTime = DateTime.now();
          if (_currentUserId != null) {
            await deviceService.saveCacheItem(
                'user_payments_$_currentUserId', _payments,
                ttl: _cacheExpiry, isUserSpecific: true);
          }
          _paymentsUpdateController.add(_payments);
        }
      } catch (e) {}
    });
  }

  Future<void> _refreshNotificationsInBackground() async {
    await _executeRefresh('notifications', () async {
      try {
        final response = await apiService.getMyNotifications();
        if (response.data != null) {
          _notifications = response.data!;
          _lastNotificationsCacheTime = DateTime.now();
          if (_currentUserId != null) {
            await deviceService.saveCacheItem(
                'user_notifications_$_currentUserId', _notifications,
                ttl: _cacheExpiry, isUserSpecific: true);
          }
          _notificationsUpdateController.add(_notifications);
        }
      } catch (e) {}
    });
  }

  bool _isCacheStale(DateTime? cacheTime) {
    if (cacheTime == null) return true;
    return DateTime.now().difference(cacheTime) > _cacheExpiry;
  }

  Future<void> updateProfile(
      {String? email, String? phone, String? profileImage}) async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      await apiService.updateMyProfile(
          email: email, phone: phone, profileImage: profileImage);

      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(
          email: email ?? _currentUser!.email,
          phone: phone ?? _currentUser!.phone,
          profileImage: profileImage ?? _currentUser!.profileImage,
        );
        _lastProfileCacheTime = DateTime.now();

        if (_currentUserId != null) {
          await deviceService.saveCacheItem(
              'user_profile_$_currentUserId', _currentUser!,
              ttl: _cacheExpiry, isUserSpecific: true);
        }
        _userUpdateController.add(_currentUser);
      }
    } catch (e) {
      _error = e.toString();
      String errorMessage = 'Failed to update profile';
      if (e.toString().contains('Email already in use'))
        errorMessage = 'Email already in use by another user';
      else if (e.toString().contains('phone'))
        errorMessage = 'Phone number already in use by another user';
      else if (e.toString().contains('Invalid email'))
        errorMessage = 'Please enter a valid email address';
      else if (e.toString().contains('Invalid phone'))
        errorMessage = 'Please enter a valid phone number';
      throw Exception(errorMessage);
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> markNotificationAsRead(int logId) async {
    final index = _notifications.indexWhere((n) => n.logId == logId);
    if (index != -1) {
      final notification = _notifications[index];
      _notifications[index] = AppNotification.Notification(
        logId: notification.logId,
        notificationId: notification.notificationId,
        title: notification.title,
        message: notification.message,
        deliveryStatus: notification.deliveryStatus,
        isRead: true,
        receivedAt: notification.receivedAt,
        sentAt: notification.sentAt,
        readAt: DateTime.now(),
        deliveredAt: notification.deliveredAt,
        sentBy: notification.sentBy,
      );

      if (_currentUserId != null) {
        await deviceService.saveCacheItem(
            'user_notifications_$_currentUserId', _notifications,
            ttl: _cacheExpiry, isUserSpecific: true);
      }
      _notificationsUpdateController.add(_notifications);
      _notifySafely();
    }
  }

  Future<void> clearUserData() async {
    if (_currentUserId != null) {
      await deviceService.removeCacheItem('user_profile_$_currentUserId',
          isUserSpecific: true);
      await deviceService.removeCacheItem('user_payments_$_currentUserId',
          isUserSpecific: true);
      await deviceService.removeCacheItem('user_notifications_$_currentUserId',
          isUserSpecific: true);
    }

    _currentUser = null;
    _payments.clear();
    _notifications.clear();
    _hasLoadedProfile = false;
    _hasLoadedNotifications = false;
    _hasLoadedPayments = false;
    _hasInitialCache = false;
    _lastProfileCacheTime = null;
    _lastNotificationsCacheTime = null;
    _lastPaymentsCacheTime = null;
    _lastRefreshTime.clear();
    _ongoingRefreshes.clear();
    _stopBackgroundRefresh();

    _userUpdateController.add(null);
    _paymentsUpdateController.add(_payments);
    _notificationsUpdateController.add(_notifications);
    _notifySafely();
  }

  void clearNotifications() async {
    if (_currentUserId != null) {
      await deviceService.removeCacheItem('user_notifications_$_currentUserId',
          isUserSpecific: true);
    }
    _notifications.clear();
    _hasLoadedNotifications = false;
    _lastNotificationsCacheTime = null;
    _notificationsUpdateController.add(_notifications);
    _notifySafely();
  }

  void clearError() {
    _error = null;
    _notifySafely();
  }

  @override
  void dispose() {
    _stopBackgroundRefresh();
    _userUpdateController.close();
    _paymentsUpdateController.close();
    _notificationsUpdateController.close();
    super.dispose();
  }

  void _notifySafely() {
    if (hasListeners) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (hasListeners) notifyListeners();
      });
    }
  }
}
```

---

## video_provider.dart

**File Path:** `lib/providers/video_provider.dart`

```dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../models/video_model.dart';
import '../utils/helpers.dart';
import 'package:dio/dio.dart';

enum VideoQualityLevel {
  low(360, '360p'),
  medium(480, '480p'),
  high(720, '720p'),
  highest(1080, '1080p');

  final int height;
  final String label;
  const VideoQualityLevel(this.height, this.label);
}

class VideoProvider extends ChangeNotifier {
  final ApiService apiService;
  final DeviceService deviceService;
  final Dio _dio = Dio();

  // State
  List<Video> _videos = [];
  final Map<int, List<Video>> _videosByChapter = {};
  final Map<int, bool> _hasLoadedForChapter = {};
  final Map<int, bool> _isLoadingForChapter = {};
  final Map<int, int> _videoViewCounts = {};

  // Download management - SINGLE source of truth
  final Map<int, String> _downloadedVideoPaths = {};
  final Map<int, VideoQualityLevel> _downloadedQualities = {};
  final Map<int, bool> _isDownloading = {};
  final Map<int, double> _downloadProgress = {};

  final StreamController<Map<String, dynamic>> _videoUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();

  bool _isLoading = false;
  String? _error;

  static const Duration _cacheDuration = Duration(minutes: 10);
  static const Duration _downloadMetadataCache = Duration(days: 30);

  VideoProvider({required this.apiService, required this.deviceService}) {
    _initDio();
    _loadDownloadedVideos(); // Load from DeviceService only
  }

  // Getters
  List<Video> get videos => List.unmodifiable(_videos);
  bool get isLoading => _isLoading;
  String? get error => _error;
  Stream<Map<String, dynamic>> get videoUpdates =>
      _videoUpdateController.stream;

  bool isVideoDownloaded(int videoId) =>
      _downloadedVideoPaths.containsKey(videoId);
  bool isDownloading(int videoId) => _isDownloading[videoId] == true;
  double getDownloadProgress(int videoId) => _downloadProgress[videoId] ?? 0.0;
  VideoQualityLevel? getDownloadQuality(int videoId) =>
      _downloadedQualities[videoId];
  String? getDownloadedVideoPath(int videoId) => _downloadedVideoPaths[videoId];

  bool hasLoadedForChapter(int chapterId) =>
      _hasLoadedForChapter[chapterId] ?? false;
  bool isLoadingForChapter(int chapterId) =>
      _isLoadingForChapter[chapterId] ?? false;
  List<Video> getVideosByChapter(int chapterId) =>
      List.unmodifiable(_videosByChapter[chapterId] ?? []);

  void _initDio() {
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.sendTimeout = const Duration(seconds: 30);
  }

  /// Load downloaded videos metadata from DeviceService (SINGLE source)
  Future<void> _loadDownloadedVideos() async {
    try {
      final paths = await deviceService.getCacheItem<Map<String, dynamic>>(
        'downloaded_videos',
        isUserSpecific: true,
      );

      if (paths != null) {
        for (final entry in paths.entries) {
          final id = int.tryParse(entry.key);
          final videoPath = entry.value as String?;
          if (id != null && videoPath != null) {
            final file = File(videoPath);
            if (await file.exists()) {
              _downloadedVideoPaths[id] = videoPath;
            }
          }
        }
      }

      final qualities = await deviceService.getCacheItem<Map<String, dynamic>>(
        'download_qualities',
        isUserSpecific: true,
      );

      if (qualities != null) {
        for (final entry in qualities.entries) {
          final id = int.tryParse(entry.key);
          final key = entry.value as String?;
          if (id != null && key != null) {
            switch (key) {
              case 'low':
                _downloadedQualities[id] = VideoQualityLevel.low;
                break;
              case 'medium':
                _downloadedQualities[id] = VideoQualityLevel.medium;
                break;
              case 'high':
                _downloadedQualities[id] = VideoQualityLevel.high;
                break;
              case 'highest':
                _downloadedQualities[id] = VideoQualityLevel.highest;
                break;
            }
          }
        }
      }

      debugLog('VideoProvider',
          'Loaded ${_downloadedVideoPaths.length} downloaded videos');
    } catch (e) {
      debugLog('VideoProvider', 'Error loading downloads: $e');
    }
  }

  /// Save download metadata to DeviceService
  Future<void> _saveDownloadMetadata() async {
    try {
      final paths = <String, String>{};
      for (final entry in _downloadedVideoPaths.entries) {
        paths[entry.key.toString()] = entry.value;
      }

      final qualities = <String, String>{};
      for (final entry in _downloadedQualities.entries) {
        String key = '';
        switch (entry.value) {
          case VideoQualityLevel.low:
            key = 'low';
            break;
          case VideoQualityLevel.medium:
            key = 'medium';
            break;
          case VideoQualityLevel.high:
            key = 'high';
            break;
          case VideoQualityLevel.highest:
            key = 'highest';
            break;
        }
        qualities[entry.key.toString()] = key;
      }

      await deviceService.saveCacheItem(
        'downloaded_videos',
        paths,
        isUserSpecific: true,
        ttl: _downloadMetadataCache,
      );

      await deviceService.saveCacheItem(
        'download_qualities',
        qualities,
        isUserSpecific: true,
        ttl: _downloadMetadataCache,
      );
    } catch (e) {
      debugLog('VideoProvider', 'Error saving metadata: $e');
    }
  }

  /// Load videos for a chapter (uses SINGLE endpoint)
  Future<void> loadVideosByChapter(int chapterId,
      {bool forceRefresh = false}) async {
    if (_isLoadingForChapter[chapterId] == true) return;

    // Check cache
    if (!forceRefresh && _hasLoadedForChapter[chapterId] == true) {
      return;
    }

    _isLoadingForChapter[chapterId] = true;
    _error = null;
    notifyListeners();

    try {
      debugLog('VideoProvider', 'Loading videos for chapter: $chapterId');

      // SINGLE endpoint: /chapters/$chapterId/videos
      final response = await apiService.getVideosByChapter(chapterId);

      if (!response.success) {
        throw Exception(response.message);
      }

      final responseData = response.data;
      final videosData = responseData?['videos'] ?? [];

      final list = <Video>[];
      for (final json in videosData) {
        try {
          final video = Video.fromJson(json);
          list.add(video);
          _videoViewCounts[video.id] = video.viewCount;
        } catch (e) {
          debugLog('VideoProvider', 'Error parsing video: $e');
        }
      }

      _videosByChapter[chapterId] = list;
      _hasLoadedForChapter[chapterId] = true;

      // Update global videos list
      for (final video in list) {
        if (!_videos.any((v) => v.id == video.id)) {
          _videos.add(video);
        }
      }

      // Cache in DeviceService only
      await deviceService.saveCacheItem(
        'videos_chapter_$chapterId',
        list.map((v) => v.toJson()).toList(),
        ttl: _cacheDuration,
        isUserSpecific: true,
      );

      _videoUpdateController.add({
        'type': 'videos_loaded',
        'chapter_id': chapterId,
        'count': list.length
      });

      debugLog('VideoProvider',
          'Loaded ${list.length} videos for chapter $chapterId');
    } catch (e) {
      _error = e.toString();
      debugLog('VideoProvider', 'Error loading videos: $e');

      // Try cache
      final cached = await deviceService.getCacheItem<List<dynamic>>(
        'videos_chapter_$chapterId',
        isUserSpecific: true,
      );

      if (cached != null) {
        final list = <Video>[];
        for (final json in cached) {
          try {
            list.add(Video.fromJson(json));
          } catch (e) {}
        }
        _videosByChapter[chapterId] = list;
        _hasLoadedForChapter[chapterId] = true;

        _videoUpdateController.add({
          'type': 'videos_loaded_cached',
          'chapter_id': chapterId,
          'count': list.length
        });
      } else {
        _videosByChapter[chapterId] = [];
      }
    } finally {
      _isLoadingForChapter[chapterId] = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Download video with specific quality
  Future<void> downloadVideo(
      Video video, VideoQualityLevel quality, CancelToken cancelToken) async {
    if (_isDownloading[video.id] == true) return;

    // Get quality-specific URL
    String? qualityUrl;
    switch (quality) {
      case VideoQualityLevel.low:
        qualityUrl = video.getQualityUrl('low');
        break;
      case VideoQualityLevel.medium:
        qualityUrl = video.getQualityUrl('medium');
        break;
      case VideoQualityLevel.high:
        qualityUrl = video.getQualityUrl('high');
        break;
      case VideoQualityLevel.highest:
        qualityUrl = video.getQualityUrl('highest');
        break;
    }

    if (qualityUrl == null) {
      throw Exception('Quality not available for this video');
    }

    _isDownloading[video.id] = true;
    _downloadProgress[video.id] = 0.0;
    _downloadedQualities[video.id] = quality;
    notifyListeners();

    try {
      final cacheDir = await _getCacheDirectory();
      final fileName =
          'v${video.id}_${quality.height}_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final filePath = '${cacheDir.path}/$fileName';

      debugLog(
          'VideoProvider', 'Downloading video ${video.id} at ${quality.label}');

      await _dio.download(
        qualityUrl,
        filePath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            _downloadProgress[video.id] = received / total;
            notifyListeners();
          }
        },
      );

      final file = File(filePath);
      if (!await file.exists()) throw Exception('Download failed');

      _downloadedVideoPaths[video.id] = filePath;
      _isDownloading[video.id] = false;
      _downloadProgress.remove(video.id);
      await _saveDownloadMetadata();

      _videoUpdateController.add({
        'type': 'video_downloaded',
        'video_id': video.id,
        'quality': quality.label,
      });

      debugLog('VideoProvider', 'Download complete for video ${video.id}');
      notifyListeners();
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        debugLog('VideoProvider', 'Download cancelled');
      } else {
        debugLog('VideoProvider', 'Download error: $e');
      }
      _isDownloading[video.id] = false;
      _downloadProgress.remove(video.id);
      _downloadedQualities.remove(video.id);
      notifyListeners();
      rethrow;
    }
  }

  /// Remove downloaded video
  Future<void> removeDownload(int videoId) async {
    final path = _downloadedVideoPaths[videoId];
    if (path != null) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
          debugLog('VideoProvider', 'Deleted file for video $videoId');
        }
      } catch (e) {
        debugLog('VideoProvider', 'Error deleting file: $e');
      }
    }

    _downloadedVideoPaths.remove(videoId);
    _downloadedQualities.remove(videoId);
    await _saveDownloadMetadata();

    _videoUpdateController.add({
      'type': 'video_removed',
      'video_id': videoId,
    });

    notifyListeners();
  }

  /// Clear all downloaded videos
  Future<void> clearAllDownloads() async {
    try {
      for (final path in _downloadedVideoPaths.values) {
        try {
          final file = File(path);
          if (await file.exists()) await file.delete();
        } catch (e) {}
      }
    } catch (e) {}

    _downloadedVideoPaths.clear();
    _downloadedQualities.clear();
    await _saveDownloadMetadata();

    _videoUpdateController.add({'type': 'all_downloads_cleared'});
    notifyListeners();
  }

  Future<Directory> _getCacheDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${dir.path}/.cache/videos');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  Video? getVideoById(int id) {
    try {
      return _videos.firstWhere((v) => v.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Increment view count when video is watched
  Future<void> incrementViewCount(int videoId) async {
    try {
      debugLog('VideoProvider', 'Incrementing view count for video: $videoId');
      await apiService.incrementVideoViewCount(videoId);

      final index = _videos.indexWhere((v) => v.id == videoId);
      if (index != -1) {
        final video = _videos[index];
        final newCount = (_videoViewCounts[videoId] ?? video.viewCount) + 1;
        _videoViewCounts[videoId] = newCount;

        _videos[index] = Video(
          id: video.id,
          title: video.title,
          chapterId: video.chapterId,
          filePath: video.filePath,
          fileSize: video.fileSize,
          duration: video.duration,
          thumbnailUrl: video.thumbnailUrl,
          releaseDate: video.releaseDate,
          viewCount: newCount,
          createdAt: video.createdAt,
          qualities: video.qualities,
          hasQualities: video.hasQualities,
        );

        for (final chapterVideos in _videosByChapter.values) {
          final idx = chapterVideos.indexWhere((v) => v.id == videoId);
          if (idx != -1) chapterVideos[idx] = _videos[index];
        }

        _videoUpdateController.add({
          'type': 'view_count_updated',
          'video_id': videoId,
          'view_count': newCount
        });

        notifyListeners();
      }
    } catch (e) {
      debugLog('VideoProvider', 'Error incrementing view count: $e');
    }
  }

  int getViewCount(int videoId) {
    return _videoViewCounts[videoId] ?? 0;
  }

  /// Clear user data on logout
  Future<void> clearUserData() async {
    debugLog('VideoProvider', 'Clearing user data');

    await deviceService.clearCacheByPrefix('videos_');
    await deviceService.clearCacheByPrefix('video_view_');

    _videos.clear();
    _videosByChapter.clear();
    _hasLoadedForChapter.clear();
    _isLoadingForChapter.clear();
    _videoViewCounts.clear();

    // Keep downloads (user might want to keep them after logout)
    // If you want to clear downloads on logout, uncomment:
    // await clearAllDownloads();

    _videoUpdateController.add({'type': 'all_videos_cleared'});
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _videoUpdateController.close();
    _dio.close();
    super.dispose();
  }
}
```

---


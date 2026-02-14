import 'dart:async';
import 'dart:convert';
import 'dart:math';
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

  // CRITICAL FIX: Store last login result for device change
  Map<String, dynamic>? _lastLoginResult;

  Timer? _autoLogoutTimer;
  static const Duration _sessionDuration = Duration(days: 3);

  Timer? _tokenRefreshTimer;
  static const Duration _tokenRefreshInterval = Duration(minutes: 30);

  Timer? _proactiveRefreshTimer;
  static const Duration _proactiveRefreshInterval = Duration(minutes: 5);

  StreamController<bool> _authStateController =
      StreamController<bool>.broadcast();
  StreamController<User?> _userController = StreamController<User?>.broadcast();
  StreamController<bool> _deviceChangeController =
      StreamController<bool>.broadcast();

  bool _isCheckingSubscriptionOnLogin = false;

  List<VoidCallback> _onLogoutCallbacks = [];
  List<VoidCallback> _onLoginCallbacks = [];

  AuthProvider({
    required this.apiService,
    required this.storageService,
    required this.deviceService,
  });

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing;
  bool get isInitialized => _isInitialized;
  bool get requiresDeviceChange => _requiresDeviceChange;
  String? get error => _error;
  bool get isCheckingSubscriptionOnLogin => _isCheckingSubscriptionOnLogin;

  // CRITICAL FIX: Getter for last login result
  Map<String, dynamic>? get lastLoginResult => _lastLoginResult;

  // CRITICAL FIX: New method to check if auth is truly ready for navigation
  bool get isReadyForNavigation {
    return _isInitialized &&
        (!_isAuthenticated || (_isAuthenticated && _currentUser != null));
  }

  Stream<bool> get authStateChanges => _authStateController.stream;
  Stream<User?> get userChanges => _userController.stream;
  Stream<bool> get deviceChangeRequired => _deviceChangeController.stream;

  void registerOnLogoutCallback(VoidCallback callback) {
    _onLogoutCallbacks.add(callback);
  }

  void registerOnLoginCallback(VoidCallback callback) {
    _onLoginCallbacks.add(callback);
  }

  Future<void> initialize() async {
    if (_isInitializing || _isInitialized) return;

    _isInitializing = true;
    _error = null;
    notifyListeners();

    try {
      debugLog('AuthProvider', '🔄 Initializing auth provider');

      await storageService.init();
      await deviceService.init();

      final token = await storageService.getToken();

      if (token != null && token.isNotEmpty) {
        debugLog('AuthProvider', '✅ Found existing token');

        final bool isOldToken = _isOldFormatToken(token);
        if (isOldToken) {
          debugLog(
              'AuthProvider', '⚠️ Old format token detected, forcing re-login');
          await logout(manual: false);
          _completeInitialization();
          return;
        }

        final sessionValid =
            await storageService.isSessionValid(_sessionDuration);

        if (!sessionValid) {
          debugLog('AuthProvider', '⚠️ Session expired, auto-logout');
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
          _startProactiveRefreshTimer();

          debugLog(
              'AuthProvider', '✅ User restored from storage: ${user.username}');

          _authStateController.add(true);
          _userController.add(user);
          _executeLoginCallbacks();

          final isTokenExpiring = await _isTokenExpiringSoon(token);
          if (isTokenExpiring) {
            debugLog('AuthProvider', '🔄 Token expiring soon, validating...');
            unawaited(_validateTokenInBackground());
          }
        } else {
          debugLog('AuthProvider', '❌ No user data found, clearing auth');
          await logout();
        }
      } else {
        debugLog('AuthProvider', 'ℹ️ No token found, user not authenticated');
        _isAuthenticated = false;
        _authStateController.add(false);
        _userController.add(null);
      }
    } catch (e) {
      _error = e.toString();
      debugLog('AuthProvider', '❌ Initialize error: $e');

      await logout(manual: false);
      _isAuthenticated = false;
      _authStateController.add(false);
      _userController.add(null);
    } finally {
      // Add small delay to ensure splash screen shows properly
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

      if (exp != null) {
        final expiryTime = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
        final now = DateTime.now();
        final hoursUntilExpiry = expiryTime.difference(now).inHours;

        return hoursUntilExpiry < 24;
      }
    } catch (e) {
      debugLog('AuthProvider', 'Token expiry check error: $e');
    }
    return false;
  }

  void _completeInitialization() {
    _isInitializing = false;
    _isInitialized = true;
    notifyListeners();
    debugLog('AuthProvider', '✅ Auth initialization complete');
  }

  Future<void> _validateTokenInBackground() async {
    try {
      debugLog('AuthProvider', '🔄 Validating token in background...');
      final isValid = await validateToken();
      if (!isValid) {
        debugLog('AuthProvider', '⚠️ Background token validation failed');
        await logout(manual: false);
      } else {
        debugLog('AuthProvider', '✅ Background token validation successful');
      }
    } catch (e) {
      debugLog('AuthProvider', '⚠️ Background token validation error: $e');
    }
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
    _isCheckingSubscriptionOnLogin = true;
    _error = null;
    _requiresDeviceChange = false;
    notifyListeners();

    try {
      debugLog('AuthProvider', '🔐 Logging in user: $username');

      final deviceId = await deviceService.getDeviceId();
      debugLog('AuthProvider', '📱 Using device ID: $deviceId');

      final response =
          await apiService.studentLogin(username, password, deviceId, fcmToken);

      if (response.success && response.data != null) {
        final userData = response.data!['user'];
        final user = User.fromJson(userData);

        debugLog('AuthProvider', '🧹 Clearing all cache before login');
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
        _lastLoginResult = null; // Clear any pending device change

        // CRITICAL FIX: Mark auth as initialized and NOT initializing
        _isInitialized = true;
        _isInitializing = false;

        await deviceService.setCurrentUserId(user.id.toString());

        _startAutoLogoutTimer();
        _startTokenRefreshTimer();
        _startProactiveRefreshTimer();

        debugLog('AuthProvider', '✅ Login successful: ${user.username}');
        debugLog('AuthProvider',
            '✅ Auth state: initialized=$_isInitialized, authenticated=$_isAuthenticated');

        _executeLoginCallbacks();

        _authStateController.add(true);
        _userController.add(user);
        _deviceChangeController.add(false);

        // Check if user needs to select school
        String nextStep = 'home';
        if (user.schoolId == null) {
          nextStep = 'select_school';
        }

        return {
          'success': true,
          'message': 'Login successful',
          'user': user,
          'requiresDeviceChange': false,
          'next_step': nextStep,
        };
      } else {
        _error = response.message;
        debugLog('AuthProvider', '❌ Login failed: ${response.message}');

        return {
          'success': false,
          'message': response.message,
          'requiresDeviceChange': false,
        };
      }
    } on ApiError catch (e) {
      _error = e.message;
      _requiresDeviceChange = e.action == 'device_change_required';

      debugLog('AuthProvider', '❌ Login API error: ${e.message}');
      debugLog(
          'AuthProvider', '🔧 Device change required: $_requiresDeviceChange');
      debugLog('AuthProvider', '📦 Device change data: ${e.data}');

      if (_requiresDeviceChange) {
        _deviceChangeController.add(true);

        // CRITICAL FIX: Store the complete login result for the router
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

        debugLog(
            'AuthProvider', '📦 Stored device change data: $_lastLoginResult');

        return _lastLoginResult!;
      }

      return {
        'success': false,
        'message': e.message,
        'requiresDeviceChange': false,
        'action': e.action,
        'data': e.data,
      };
    } catch (e) {
      _error = e.toString();
      debugLog('AuthProvider', '❌ Login error: $e');

      return {
        'success': false,
        'message': 'An unexpected error occurred',
        'requiresDeviceChange': false,
      };
    } finally {
      _isLoading = false;
      _isCheckingSubscriptionOnLogin = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> register(String username, String password,
      String deviceId, String? fcmToken) async {
    if (_isLoading) return {'success': false, 'message': 'Already processing'};

    _isLoading = true;
    _isCheckingSubscriptionOnLogin = true;
    _error = null;
    notifyListeners();

    try {
      debugLog('AuthProvider', '📝 Registering user: $username');

      final deviceId = await deviceService.getDeviceId();
      debugLog('AuthProvider', '📱 Using device ID: $deviceId');

      final response = await apiService.register(username, password, deviceId);

      debugLog('AuthProvider', '📦 Registration response: ${response.data}');

      if (response.success && response.data != null) {
        Map<String, dynamic> responseData = response.data!;

        debugLog(
            'AuthProvider', 'Response data type: ${responseData.runtimeType}');

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
          throw ApiError(message: 'Invalid response format from server');
        }

        final user = User.fromJson(userData);

        debugLog('AuthProvider', '✅ Parsed user: ${user.username}');

        await deviceService.clearUserCache();
        await deviceService.clearAllCache();

        await storageService.saveUser(user);
        await storageService.saveToken(token);

        await storageService.saveSessionStart();
        await storageService.markRegistrationComplete();

        _currentUser = user;
        _isAuthenticated = true;
        _requiresDeviceChange = false;
        _lastLoginResult = null; // Clear any pending device change

        // CRITICAL FIX: Mark auth as initialized
        _isInitialized = true;
        _isInitializing = false;

        await deviceService.setCurrentUserId(user.id.toString());

        _startAutoLogoutTimer();
        _startTokenRefreshTimer();
        _startProactiveRefreshTimer();

        debugLog('AuthProvider', '✅ Registration successful: ${user.username}');

        _executeLoginCallbacks();

        _authStateController.add(true);
        _userController.add(user);
        _deviceChangeController.add(false);

        // Check if user needs to select school
        String nextStep = 'home';
        if (user.schoolId == null) {
          nextStep = 'select_school';
        }

        return {
          'success': true,
          'message': 'Registration successful',
          'user': user,
          'next_step': nextStep,
        };
      } else {
        _error = response.message;
        debugLog('AuthProvider', '❌ Registration failed: ${response.message}');

        return {
          'success': false,
          'message': response.message,
        };
      }
    } on ApiError catch (e) {
      _error = e.message;
      debugLog('AuthProvider', '❌ Registration API error: ${e.message}');

      return {
        'success': false,
        'message': e.message,
      };
    } catch (e) {
      _error = e.toString();
      debugLog('AuthProvider', '❌ Registration error: $e');

      return {
        'success': false,
        'message': 'An unexpected error occurred',
      };
    } finally {
      _isLoading = false;
      _isCheckingSubscriptionOnLogin = false;
      notifyListeners();
    }
  }

  Future<void> logout({bool manual = true}) async {
    debugLog('AuthProvider',
        manual ? '👤 Manual logout' : '⏰ Auto-logout (session expired)');

    _stopAutoLogoutTimer();
    _stopTokenRefreshTimer();
    _stopProactiveRefreshTimer();

    _executeLogoutCallbacks();

    await deviceService.clearUserCache();
    await deviceService.clearCurrentUserId();

    await storageService.clearAllUserData();

    _currentUser = null;
    _isAuthenticated = false;
    _requiresDeviceChange = false;
    _error = null;
    _isCheckingSubscriptionOnLogin = false;
    _lastLoginResult = null; // Clear any pending device change

    // CRITICAL FIX: DO NOT reset isInitialized on manual logout
    // Only reset on app start or token expiry
    if (!manual) {
      _isInitialized = false;
      _isInitializing = false;
    }

    _authStateController.add(false);
    _userController.add(null);
    _deviceChangeController.add(false);

    debugLog('AuthProvider', '✅ Logout complete - cache cleared');
    notifyListeners();
  }

  void _executeLogoutCallbacks() {
    for (final callback in _onLogoutCallbacks) {
      try {
        callback();
      } catch (e) {
        debugLog('AuthProvider', 'Error executing logout callback: $e');
      }
    }
  }

  void _executeLoginCallbacks() {
    for (final callback in _onLoginCallbacks) {
      try {
        callback();
      } catch (e) {
        debugLog('AuthProvider', 'Error executing login callback: $e');
      }
    }
  }

  void _startAutoLogoutTimer() {
    _stopAutoLogoutTimer();

    _autoLogoutTimer = Timer(_sessionDuration, () async {
      debugLog('AuthProvider', '🕐 Auto-logout timer triggered');
      await logout(manual: false);
    });

    debugLog(
        'AuthProvider', '⏰ Auto-logout timer started for $_sessionDuration');
  }

  void _stopAutoLogoutTimer() {
    if (_autoLogoutTimer != null) {
      _autoLogoutTimer!.cancel();
      _autoLogoutTimer = null;
    }
  }

  void _startTokenRefreshTimer() {
    _stopTokenRefreshTimer();

    _tokenRefreshTimer = Timer.periodic(_tokenRefreshInterval, (timer) async {
      debugLog('AuthProvider', '🔄 Token refresh timer triggered');
      await refreshToken();
    });

    debugLog('AuthProvider',
        '🔑 Token refresh timer started every $_tokenRefreshInterval');
  }

  void _stopTokenRefreshTimer() {
    if (_tokenRefreshTimer != null) {
      _tokenRefreshTimer!.cancel();
      _tokenRefreshTimer = null;
    }
  }

  void _startProactiveRefreshTimer() {
    _stopProactiveRefreshTimer();

    _proactiveRefreshTimer =
        Timer.periodic(_proactiveRefreshInterval, (timer) async {
      if (_isAuthenticated && !_isLoading) {
        debugLog('AuthProvider', '🔄 Proactive token refresh check');
        await _checkAndRefreshToken();
      }
    });

    debugLog('AuthProvider',
        '⏰ Proactive refresh timer started every $_proactiveRefreshInterval');
  }

  void _stopProactiveRefreshTimer() {
    if (_proactiveRefreshTimer != null) {
      _proactiveRefreshTimer!.cancel();
      _proactiveRefreshTimer = null;
    }
  }

  Future<void> _checkAndRefreshToken() async {
    try {
      final token = await storageService.getToken();
      if (token == null) return;

      final parts = token.split('.');
      if (parts.length != 3) return;

      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final jsonPayload = json.decode(decoded);
      final exp = jsonPayload['exp'];

      if (exp != null) {
        final expiryTime = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
        final now = DateTime.now();
        final minutesUntilExpiry = expiryTime.difference(now).inMinutes;

        debugLog(
            'AuthProvider', '⏰ Token expires in $minutesUntilExpiry minutes');

        if (minutesUntilExpiry < 10 && minutesUntilExpiry > 0) {
          debugLog(
              'AuthProvider', '🔄 Token expiring soon, refreshing proactively');

          try {
            final refreshToken = await storageService.getRefreshToken();
            if (refreshToken == null) return;

            final response = await apiService.dio.post(
              '/auth/refresh-access',
              data: {'refreshToken': refreshToken},
            );

            if (response.statusCode == 200 &&
                response.data['success'] == true) {
              final newToken = response.data['data']['token'];
              await storageService.saveToken(newToken);

              debugLog('AuthProvider', '✅ Token refreshed proactively');

              _startAutoLogoutTimer();
            } else {
              debugLog('AuthProvider',
                  '⚠️ Proactive refresh failed: ${response.data}');
            }
          } catch (e) {
            debugLog('AuthProvider', '⚠️ Proactive refresh failed: $e');
          }
        }
      }
    } catch (e) {
      debugLog('AuthProvider', '❌ Token check error: $e');
    }
  }

  Future<void> refreshToken() async {
    try {
      final refreshToken = await storageService.getRefreshToken();
      if (refreshToken == null) {
        debugLog('AuthProvider', '⚠️ No refresh token available');
        return;
      }

      debugLog('AuthProvider', '🔄 Refreshing token...');

      final response = await apiService.dio.post(
        '/auth/refresh-access',
        data: {'refreshToken': refreshToken},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final newToken = response.data['data']['token'];
        await storageService.saveToken(newToken);

        _startAutoLogoutTimer();

        debugLog('AuthProvider', '✅ Token refreshed successfully');
      } else {
        debugLog('AuthProvider',
            '❌ Token refresh failed: ${response.data['message']}');
      }
    } catch (e) {
      debugLog('AuthProvider', '❌ Token refresh error: $e');
    }
  }

  Future<bool> validateToken() async {
    try {
      final response = await apiService.validateStudentToken();
      if (response.success) {
        debugLog('AuthProvider', '✅ Token validation successful');
        return true;
      } else {
        debugLog(
            'AuthProvider', '❌ Token validation failed: ${response.message}');
        return false;
      }
    } catch (e) {
      debugLog('AuthProvider', '❌ Token validation error: $e');
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

        debugLog('AuthProvider', '✅ User loaded: ${user.username}');
        return user;
      }
    } catch (e) {
      debugLog('AuthProvider', '❌ loadUser error: $e');
    }
    return null;
  }

  Future<void> updateUser(User user) async {
    _currentUser = user;
    await storageService.saveUser(user);

    _userController.add(user);

    debugLog('AuthProvider', '✅ User updated: ${user.username}');
    notifyListeners();
  }

  Future<void> updateDeviceChangeStatus(bool requiresChange) async {
    _requiresDeviceChange = requiresChange;
    _deviceChangeController.add(requiresChange);
    notifyListeners();
  }

  Future<void> clearDeviceChangeRequirement() async {
    _requiresDeviceChange = false;
    _lastLoginResult = null; // Clear stored data
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
      if (!sessionValid) {
        debugLog('AuthProvider', '⚠️ Session check failed - logging out');
        await logout(manual: false);
      } else {
        debugLog('AuthProvider', '✅ Session check passed');
      }
    } catch (e) {
      debugLog('AuthProvider', '❌ Session check error: $e');
    }
  }

  Future<bool> validateTokenForSubscription() async {
    if (!_isAuthenticated) return false;

    try {
      final token = await storageService.getToken();
      if (token == null) return false;

      final parts = token.split('.');
      if (parts.length != 3) return false;

      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final jsonPayload = json.decode(decoded);
      final exp = jsonPayload['exp'];

      if (exp != null) {
        final expiryTime = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
        final now = DateTime.now();

        if (expiryTime.difference(now).inMinutes < 1) {
          debugLog('AuthProvider',
              '⚠️ Token almost expired for subscription check, refreshing');
          await refreshToken();
        }
      }

      return true;
    } catch (e) {
      debugLog('AuthProvider', '❌ Token validation for subscription error: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _stopAutoLogoutTimer();
    _stopTokenRefreshTimer();
    _stopProactiveRefreshTimer();
    _authStateController.close();
    _userController.close();
    _deviceChangeController.close();
    _onLogoutCallbacks.clear();
    _onLoginCallbacks.clear();
    super.dispose();
  }
}

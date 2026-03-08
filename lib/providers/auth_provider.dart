import 'dart:async';
import 'dart:convert';
import 'package:familyacademyclient/utils/helpers.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/device_service.dart';
import '../services/user_session.dart';
import '../services/connectivity_service.dart';
import '../models/user_model.dart';
import '../utils/api_response.dart';

class AuthProvider with ChangeNotifier {
  final ApiService apiService;
  final StorageService storageService;
  final DeviceService deviceService;
  final ConnectivityService connectivityService;

  User? _currentUser;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  bool _isInitializing = false;
  bool _isInitialized = false;
  bool _requiresDeviceChange = false;
  String? _error;
  Map<String, dynamic>? _lastLoginResult;
  bool _isOffline = false;

  Timer? _autoLogoutTimer;
  static const Duration _sessionDuration = Duration(days: 3);

  Timer? _tokenRefreshTimer;
  static const Duration _tokenRefreshInterval = Duration(minutes: 30);

  final StreamController<bool> _authStateController =
      StreamController<bool>.broadcast();
  final StreamController<User?> _userController =
      StreamController<User?>.broadcast();
  final StreamController<bool> _deviceChangeController =
      StreamController<bool>.broadcast();
  final StreamController<String?> _deviceDeactivatedController =
      StreamController<String?>.broadcast();

  final List<VoidCallback> _onLogoutCallbacks = [];
  final List<VoidCallback> _onLoginCallbacks = [];
  StreamSubscription? _deviceDeactivationSubscription;
  StreamSubscription? _connectivitySubscription;

  AuthProvider({
    required this.apiService,
    required this.storageService,
    required this.deviceService,
    required this.connectivityService,
  }) {
    _listenToDeviceDeactivation();
    _setupConnectivityListener();
  }

  void _setupConnectivityListener() {
    _connectivitySubscription =
        connectivityService.onConnectivityChanged.listen((isOnline) {
      if (_isOffline != !isOnline) {
        _isOffline = !isOnline;
        notifyListeners();
      }
    });
  }

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing;
  bool get isInitialized => _isInitialized;
  bool get requiresDeviceChange => _requiresDeviceChange;
  String? get error => _error;
  Map<String, dynamic>? get lastLoginResult => _lastLoginResult;
  bool get isOffline => _isOffline;

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
      onError: (error) {},
    );
  }

  Future<void> _handleDeviceDeactivation(String message) async {
    _stopTimers();
    _executeLogoutCallbacks();

    await deviceService.clearCurrentUserId();
    await storageService.clearTokens();

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
    if (_isInitializing) {
      debugLog('AuthProvider', '⏳ Already initializing, waiting...');
      int waitCount = 0;
      while (_isInitializing && waitCount < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        waitCount++;
      }
      return;
    }

    if (_isInitialized) {
      debugLog('AuthProvider', '✅ Already initialized');
      return;
    }

    _isInitializing = true;
    _error = null;
    notifyListeners();

    try {
      debugLog('AuthProvider', '🔄 Starting initialization');

      // Initialize services with timeout - FIXED ERROR HANDLING
      try {
        await Future.wait([
          storageService.init().timeout(const Duration(seconds: 3)),
          deviceService.init().timeout(const Duration(seconds: 3)),
          UserSession().init().timeout(const Duration(seconds: 3)),
        ]).catchError((e) {
          debugLog('AuthProvider', '⚠️ Service initialization error: $e');
          return null;
        });
      } catch (e) {
        debugLog('AuthProvider', '⚠️ Service initialization failed: $e');
        // Continue anyway - we might have cached data
      }

      final token = await storageService.getToken();

      // Try to get user from DeviceService cache first (now integrated)
      User? user = await storageService.getUser();

      if (user != null) {
        debugLog('AuthProvider', '✅ Found cached user: ${user.username}');
        _currentUser = user;
        _isAuthenticated = true;
        await deviceService.setCurrentUserId(user.id.toString());
        await UserSession().setCurrentUser(user.id.toString());

        _startAutoLogoutTimer();
        _startTokenRefreshTimer();

        _authStateController.add(true);
        _userController.add(user);
        _executeLoginCallbacks();
      } else if (token != null) {
        debugLog('AuthProvider', '🔑 Found token, validating...');
        if (_isOldFormatToken(token)) {
          debugLog('AuthProvider', '⚠️ Old token format, logging out');
          await logout(manual: false);
        } else {
          try {
            final profileResponse = await apiService.getMyProfile();
            if (profileResponse.success && profileResponse.data != null) {
              final user = profileResponse.data!;
              debugLog('AuthProvider', '✅ Valid token, user: ${user.username}');
              await storageService.saveUser(user);
              _currentUser = user;
              _isAuthenticated = true;

              await deviceService.setCurrentUserId(user.id.toString());
              await UserSession().setCurrentUser(user.id.toString());

              _startAutoLogoutTimer();
              _startTokenRefreshTimer();

              _authStateController.add(true);
              _userController.add(user);
              _executeLoginCallbacks();
            } else {
              debugLog('AuthProvider', '❌ Token invalid, logging out');
              await logout(manual: false);
            }
          } catch (e) {
            debugLog('AuthProvider', '❌ Token validation error: $e');
            await logout(manual: false);
          }
        }
      } else {
        debugLog('AuthProvider', 'ℹ️ No user or token found');
      }
    } catch (e) {
      _error = e.toString();
      debugLog('AuthProvider', '❌ Initialization error: $e');
    } finally {
      _completeInitialization();
    }
  }

  void _completeInitialization() {
    _isInitializing = false;
    _isInitialized = true;
    debugLog('AuthProvider', '✅ Initialization complete');
    notifyListeners();
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

  Future<Map<String, dynamic>> login(
    String username,
    String password,
    String deviceId,
    String? fcmToken,
  ) async {
    if (_isLoading) {
      return {
        'success': false,
        'message': 'Already processing',
        'requiresDeviceChange': false
      };
    }

    if (_isOffline) {
      return {
        'success': false,
        'message': 'You are offline. Please connect to login.',
        'requiresDeviceChange': false
      };
    }

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

        final session = UserSession();
        final isDifferentUser =
            await session.isDifferentUserLogin(user.id.toString());

        if (isDifferentUser) {
          final oldUserId = await session.getOldUserIdToClear();
          if (oldUserId != null) {
            await deviceService.clearOldUserCache(oldUserId);
          }
        }

        await session.setCurrentUser(user.id.toString());

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
        'message': 'Login failed: ${e.toString()}',
        'requiresDeviceChange': false
      };
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> register(
    String username,
    String password,
    String deviceId,
    String? fcmToken,
  ) async {
    if (_isLoading) return {'success': false, 'message': 'Already processing'};

    if (_isOffline) {
      return {
        'success': false,
        'message': 'You are offline. Please connect to register.'
      };
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final deviceId = await deviceService.getDeviceId();
      final response =
          await apiService.register(username, password, deviceId, fcmToken);

      if (response.success && response.data != null) {
        final Map<String, dynamic> responseData = response.data!;
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

        final session = UserSession();
        await session.setCurrentUser(user.id.toString());

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
      return {
        'success': false,
        'message': 'Registration failed: ${e.toString()}'
      };
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout({bool manual = true}) async {
    _stopTimers();

    await UserSession().prepareForLogout();
    _executeLogoutCallbacks();

    await deviceService.clearCurrentUserId();
    await storageService.clearTokens();
    await UserSession().completeLogout();

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
      } catch (e) {
        // Silent fail
      }
    }
  }

  void _executeLoginCallbacks() {
    for (final callback in _onLoginCallbacks) {
      try {
        callback();
      } catch (e) {
        // Silent fail
      }
    }
  }

  void _startAutoLogoutTimer() {
    _autoLogoutTimer?.cancel();
    _autoLogoutTimer =
        Timer(_sessionDuration, () async => logout(manual: false));
  }

  void _startTokenRefreshTimer() {
    _tokenRefreshTimer?.cancel();
    _tokenRefreshTimer =
        Timer.periodic(_tokenRefreshInterval, (timer) async => refreshToken());
  }

  Future<void> refreshToken() async {
    if (_isOffline) return;

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
    } catch (e) {
      // Silent fail
    }
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
    } catch (e) {
      return null;
    }
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
    } catch (e) {
      // Silent fail
    }
  }

  @override
  void dispose() {
    _stopTimers();
    _authStateController.close();
    _userController.close();
    _deviceChangeController.close();
    _deviceDeactivatedController.close();
    _deviceDeactivationSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _onLogoutCallbacks.clear();
    _onLoginCallbacks.clear();
    super.dispose();
  }
}

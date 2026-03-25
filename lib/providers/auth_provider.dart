// lib/providers/auth_provider.dart
// PRODUCTION-READY FINAL VERSION - FIXED CONNECTIVITY CALL

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/device_service.dart';
import '../services/user_session.dart';
import '../services/connectivity_service.dart';
import '../services/hive_service.dart';
import '../services/offline_queue_manager.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'base_provider.dart';

class AuthProvider extends ChangeNotifier
    with BaseProvider<AuthProvider>, OfflineAwareProvider<AuthProvider> {
  @override
  final ConnectivityService connectivityService;

  final ApiService apiService;
  final StorageService storageService;
  final DeviceService deviceService;
  final HiveService hiveService;
  final OfflineQueueManager offlineQueueManager;

  User? _currentUser;
  bool _isAuthenticated = false;
  bool _requiresDeviceChange = false;
  Map<String, dynamic>? _lastLoginResult;

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

  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  // ===== GETTERS =====
  User? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  bool get requiresDeviceChange => _requiresDeviceChange;
  Map<String, dynamic>? get lastLoginResult => _lastLoginResult;

  Stream<bool> get authStateChanges => _authStateController.stream;
  Stream<User?> get userChanges => _userController.stream;
  Stream<bool> get deviceChangeRequired => _deviceChangeController.stream;
  Stream<String?> get deviceDeactivated => _deviceDeactivatedController.stream;

  AuthProvider({
    required this.apiService,
    required this.storageService,
    required this.deviceService,
    required this.connectivityService,
    required this.hiveService,
    required this.offlineQueueManager,
  }) {
    log('AuthProvider constructor called');
    initializeOfflineAware(
      connectivity: connectivityService,
      queue: offlineQueueManager,
    );
    _listenToDeviceDeactivation();
    _registerQueueProcessors();
  }

  void _registerQueueProcessors() {
    offlineQueueManager.registerProcessor(
      AppConstants.queueActionUpdateProfile,
      _processProfileUpdate,
    );
    log('✅ Registered queue processors');
  }

  Future<bool> _processProfileUpdate(Map<String, dynamic> data) async {
    try {
      log('Processing offline profile update');
      final response = await apiService.updateMyProfile(
        email: data['email'],
        phone: data['phone'],
        profileImage: data['profileImage'],
        schoolId: data['schoolId'],
      );
      return response.success;
    } catch (e) {
      log('Error processing profile update: $e');
      return false;
    }
  }

  void _listenToDeviceDeactivation() {
    _deviceDeactivationSubscription =
        apiService.deviceDeactivationStream.listen(
      (event) => _handleDeviceDeactivation(
          event['message'] ?? 'Device has been deactivated'),
      onError: (error) {},
    );
  }

  Future<void> _handleDeviceDeactivation(String message) async {
    log('Device deactivated: $message');
    _stopTimers();
    _executeLogoutCallbacks();

    final userId = await getCurrentUserId();
    await UserSession().prepareForLogout();

    if (userId != null) {
      await hiveService.clearUserData(userId);
      await deviceService.clearUserData(userId);

      // ✅ FIXED: Remove clearUserQueue call
      // await connectivityService.clearUserQueue(userId ?? '');
    }

    await storageService.clearUser();
    await deviceService.clearCurrentUserId();
    await storageService.clearTokens();
    await UserSession().completeLogout();

    _currentUser = null;
    _isAuthenticated = false;
    _requiresDeviceChange = false;
    setError(message);
    _lastLoginResult = null;

    _deviceDeactivatedController.add(message);
    _authStateController.add(false);
    _userController.add(null);
    _deviceChangeController.add(false);
    safeNotify();
  }

  void _stopTimers() {
    _autoLogoutTimer?.cancel();
    _tokenRefreshTimer?.cancel();
  }

  Future<String?> getCurrentUserId() async {
    if (_currentUser != null) return _currentUser!.id.toString();
    return deviceService.getCurrentUserId();
  }

  // ===== INITIALIZE =====
  Future<void> initialize() async {
    if (isLoading) {
      while (isLoading) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return;
    }

    if (isInitialized) return;

    setLoading();

    try {
      await storageService.ensureInitialized();

      final userId = await deviceService.getCurrentUserId();
      if (userId != null) {
        User? cachedUser;
        try {
          if (Hive.isBoxOpen(AppConstants.hiveUserBox)) {
            final userBox = Hive.box<dynamic>(AppConstants.hiveUserBox);
            final data = userBox.get('user_${userId}_profile');
            if (data != null && data is User) {
              cachedUser = data;
            }
          } else {
            final userBox =
                await Hive.openBox<dynamic>(AppConstants.hiveUserBox);
            final data = userBox.get('user_${userId}_profile');
            if (data != null && data is User) {
              cachedUser = data;
            }
          }
        } catch (e) {
          log('⚠️ Error reading user box: $e');
        }

        if (cachedUser != null) {
          _currentUser = cachedUser;
          _isAuthenticated = true;

          await deviceService.setCurrentUserId(userId);
          await UserSession().setCurrentUser(userId);
          await deviceService.saveDeviceInfo();

          _startAutoLogoutTimer();
          _startTokenRefreshTimer();

          _authStateController.add(true);
          _userController.add(cachedUser);
          _executeLoginCallbacks();
          setLoaded();

          log('✅ Restored from Hive cache');
          markInitialized();
          return;
        }
      }
    } catch (e) {
      log('⚠️ Error during initialization: $e');
    } finally {
      setLoaded();
      markInitialized();
    }
  }

  // ===== LOGIN with retry mechanism =====
  Future<Map<String, dynamic>> login(
      String username, String password, String deviceId, String? fcmToken,
      {int retryCount = 0}) async {
    if (isLoading) {
      return {
        'success': false,
        'message': 'Already processing',
        'requiresDeviceChange': false
      };
    }

    if (isOffline) {
      return {
        'success': false,
        'message': getUserFriendlyErrorMessage(
            'You are offline. Please connect to login.'),
        'requiresDeviceChange': false
      };
    }

    setLoading();

    try {
      final response =
          await apiService.studentLogin(username, password, deviceId, fcmToken);

      if (response.success && response.data != null) {
        final userData = response.data!['user'];
        final user = User.fromJson(userData as Map<String, dynamic>);

        final session = UserSession();
        final currentUserId = await session.getCurrentUserId();
        final isDifferentUser =
            currentUserId != null && currentUserId != user.id.toString();

        if (isDifferentUser) {
          log('🔄 Different user login detected');
          await hiveService.clearUserData(currentUserId);
          await deviceService.clearUserData(currentUserId);
          await storageService.clearUser();
          await deviceService.clearCurrentUserId();
        }

        await session.setCurrentUser(user.id.toString());
        await deviceService.setCurrentUserId(user.id.toString());
        await deviceService.saveDeviceInfo();

        await storageService.saveUser(user);
        await storageService.saveToken(response.data!['token']);
        if (response.data!['deviceToken'] != null) {
          await storageService.saveRefreshToken(response.data!['deviceToken']);
        }
        await storageService.saveSessionStart();

        try {
          if (Hive.isBoxOpen(AppConstants.hiveUserBox)) {
            final userBox = Hive.box<dynamic>(AppConstants.hiveUserBox);
            await userBox.put('user_${user.id}_profile', user);
            log('✅ Saved user to existing Hive box');
          } else {
            final userBox =
                await Hive.openBox<dynamic>(AppConstants.hiveUserBox);
            await userBox.put('user_${user.id}_profile', user);
            log('✅ Saved user to new Hive box');
          }
        } catch (e) {
          log('⚠️ Hive save error (non-critical): $e');
        }

        _currentUser = user;
        _isAuthenticated = true;
        _requiresDeviceChange = false;
        _lastLoginResult = null;
        markInitialized();
        setLoaded();

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
        String? responseAction;
        if (response.error is Map) {
          responseAction = (response.error as Map)['action']?.toString();
        }
        if (responseAction == null && response.data is Map) {
          responseAction = (response.data as Map)['action']?.toString();
        }

        if (response.statusCode == 403 &&
            responseAction == 'device_change_required') {
          _requiresDeviceChange = true;
          _deviceChangeController.add(true);
          _lastLoginResult = {
            'success': false,
            'message': response.message,
            'requiresDeviceChange': true,
            'action': responseAction,
            'data': response.data,
            'username': username,
            'password': password,
            'deviceId': deviceId,
            'fcmToken': fcmToken,
          };
          setLoaded();
          return _lastLoginResult!;
        }

        if (response.isNetworkError) {
          setError(getUserFriendlyErrorMessage(
              'Connection error. Please check your internet.'));
          return {
            'success': false,
            'message': getUserFriendlyErrorMessage(
                'Connection error. Please check your internet.'),
            'requiresDeviceChange': false
          };
        }

        setError(getUserFriendlyErrorMessage(response.message));
        return {
          'success': false,
          'message': getUserFriendlyErrorMessage(response.message),
          'requiresDeviceChange': false
        };
      }
    } on DioException catch (e) {
      if ((e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.sendTimeout) &&
          retryCount < _maxRetries) {
        log('⏱️ Login timeout, retrying (${retryCount + 1}/$_maxRetries)');
        await Future.delayed(_retryDelay * (retryCount + 1));
        return login(username, password, deviceId, fcmToken,
            retryCount: retryCount + 1);
      }

      setError(getUserFriendlyErrorMessage(e.message ?? 'Login failed'));
      _requiresDeviceChange = e.response?.statusCode == 403 &&
          (e.response?.data['action'] == 'device_change_required');

      if (_requiresDeviceChange) {
        _deviceChangeController.add(true);
        final deviceId = await deviceService.getDeviceId();
        _lastLoginResult = {
          'success': false,
          'message': e.response?.data['message'] ?? 'Device change required',
          'requiresDeviceChange': true,
          'action': 'device_change_required',
          'data': e.response?.data['data'],
          'username': username,
          'password': password,
          'deviceId': deviceId,
          'fcmToken': fcmToken,
        };
        setLoaded();
        return _lastLoginResult!;
      }

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return {
          'success': false,
          'message': getUserFriendlyErrorMessage(
              'Request timed out. Please try again.'),
          'requiresDeviceChange': false
        };
      }

      return {
        'success': false,
        'message': getUserFriendlyErrorMessage('Login failed: ${e.message}'),
        'requiresDeviceChange': false
      };
    } catch (e) {
      setError(getUserFriendlyErrorMessage(e.toString()));
      return {
        'success': false,
        'message': getUserFriendlyErrorMessage('Login failed: ${e.toString()}'),
        'requiresDeviceChange': false
      };
    } finally {
      setLoaded();
      safeNotify();
    }
  }

  // ===== REGISTER with retry mechanism =====
  Future<Map<String, dynamic>> register(
      String username, String password, String deviceId, String? fcmToken,
      {int retryCount = 0}) async {
    if (isLoading) return {'success': false, 'message': 'Already processing'};

    if (isOffline) {
      return {
        'success': false,
        'message': getUserFriendlyErrorMessage(
            'You are offline. Please connect to register.')
      };
    }

    setLoading();

    try {
      final response =
          await apiService.register(username, password, deviceId, fcmToken);

      if (response.success && response.data != null) {
        final userData = response.data!['user'];
        final token = response.data!['token'];

        final user = User.fromJson(userData as Map<String, dynamic>);

        final session = UserSession();
        final currentUserId = await session.getCurrentUserId();
        final isDifferentUser =
            currentUserId != null && currentUserId != user.id.toString();

        if (isDifferentUser) {
          log('🔄 Different user registration detected');
          await hiveService.clearUserData(currentUserId);
          await deviceService.clearUserData(currentUserId);
          await storageService.clearUser();
          await deviceService.clearCurrentUserId();
        }

        await session.setCurrentUser(user.id.toString());
        await deviceService.setCurrentUserId(user.id.toString());
        await deviceService.saveDeviceInfo();

        await storageService.saveUser(user);
        await storageService.saveToken(token);
        await storageService.saveSessionStart();
        await storageService.markRegistrationComplete();

        try {
          if (Hive.isBoxOpen(AppConstants.hiveUserBox)) {
            final userBox = Hive.box<dynamic>(AppConstants.hiveUserBox);
            await userBox.put('user_${user.id}_profile', user);
          } else {
            final userBox =
                await Hive.openBox<dynamic>(AppConstants.hiveUserBox);
            await userBox.put('user_${user.id}_profile', user);
          }
        } catch (e) {
          log('⚠️ Hive save error (non-critical): $e');
        }

        _currentUser = user;
        _isAuthenticated = true;
        _requiresDeviceChange = false;
        _lastLoginResult = null;
        markInitialized();
        setLoaded();

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
        setError(getUserFriendlyErrorMessage(response.message));
        return {
          'success': false,
          'message': getUserFriendlyErrorMessage(response.message)
        };
      }
    } on DioException catch (e) {
      if ((e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.sendTimeout) &&
          retryCount < _maxRetries) {
        log('⏱️ Registration timeout, retrying (${retryCount + 1}/$_maxRetries)');
        await Future.delayed(_retryDelay * (retryCount + 1));
        return register(username, password, deviceId, fcmToken,
            retryCount: retryCount + 1);
      }

      setError(getUserFriendlyErrorMessage(e.message ?? 'Registration failed'));

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return {
          'success': false,
          'message': getUserFriendlyErrorMessage(
              'Request timed out. Please try again.'),
        };
      }

      return {
        'success': false,
        'message':
            getUserFriendlyErrorMessage(e.message ?? 'Registration failed'),
      };
    } catch (e) {
      setError(getUserFriendlyErrorMessage(e.toString()));
      return {
        'success': false,
        'message':
            getUserFriendlyErrorMessage('Registration failed: ${e.toString()}')
      };
    } finally {
      setLoaded();
      safeNotify();
    }
  }

  // ===== APPROVE DEVICE CHANGE =====
  Future<Map<String, dynamic>> approveDeviceChange({
    required String username,
    required String password,
    required String deviceId,
  }) async {
    if (isLoading) {
      return {
        'success': false,
        'message': 'Already processing',
      };
    }

    if (isOffline) {
      return {
        'success': false,
        'message': getUserFriendlyErrorMessage(
            'You are offline. Please connect to approve device change.'),
      };
    }

    setLoading();

    try {
      final response = await apiService.approveDeviceChange(
        username: username,
        password: password,
        deviceId: deviceId,
      );

      if (response.success && response.data != null) {
        setLoaded();
        return {
          'success': true,
          'message': response.message,
          'data': response.data,
        };
      } else {
        setLoaded();
        return {
          'success': false,
          'message': response.message,
        };
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return {
          'success': false,
          'message': getUserFriendlyErrorMessage(
              'Request timed out. Please try again.'),
        };
      }
      return {
        'success': false,
        'message':
            getUserFriendlyErrorMessage(e.message ?? 'Device change failed'),
      };
    } catch (e) {
      return {
        'success': false,
        'message': getUserFriendlyErrorMessage(
            'Device change failed: ${e.toString()}'),
      };
    } finally {
      setLoaded();
      safeNotify();
    }
  }

  // ===== LOGOUT =====
  Future<void> logout({bool manual = true}) async {
    log('🔴 Logging out (manual: $manual)');

    _stopTimers();

    final userId = await getCurrentUserId();

    await UserSession().prepareForLogout();
    _executeLogoutCallbacks();

    if (userId != null) {
      await hiveService.clearUserData(userId);
      await deviceService.clearUserData(userId);
    }

    await storageService.clearUser();
    await deviceService.clearCurrentUserId();
    await storageService.clearTokens();
    await UserSession().completeLogout();

    // ✅ FIXED: Remove clearUserQueue call
    // await connectivityService.clearUserQueue(userId ?? '');

    _currentUser = null;
    _isAuthenticated = false;
    _requiresDeviceChange = false;
    clearError();
    _lastLoginResult = null;

    if (!manual) {
      markInitialized();
    }

    _authStateController.add(false);
    _userController.add(null);
    _deviceChangeController.add(false);
    setLoaded();
    safeNotify();

    log('✅ Logout complete');
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

  void registerOnLogoutCallback(VoidCallback callback) =>
      _onLogoutCallbacks.add(callback);
  void registerOnLoginCallback(VoidCallback callback) =>
      _onLoginCallbacks.add(callback);

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
    if (isOffline) return;

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
      if (response.success) return true;

      final responseError = response.error;
      final actionFromError =
          responseError is Map ? responseError['action']?.toString() : null;
      final actionFromData =
          response.data is Map ? response.data!['action']?.toString() : null;
      final action = actionFromError ?? actionFromData;

      final shouldInvalidateSession = response.statusCode == 401 ||
          (response.statusCode == 403 && action == 'device_deactivated');

      return !shouldInvalidateSession;
    } catch (e) {
      return true;
    }
  }

  // ===== LOAD USER =====
  Future<User?> loadUser() async {
    try {
      final userId = await getCurrentUserId();
      if (userId != null) {
        if (Hive.isBoxOpen(AppConstants.hiveUserBox)) {
          final userBox = Hive.box<dynamic>(AppConstants.hiveUserBox);
          final cachedUser = userBox.get('user_${userId}_profile');
          if (cachedUser != null && cachedUser is User) {
            _currentUser = cachedUser;
            _isAuthenticated = true;
            await deviceService.setCurrentUserId(userId);
            await deviceService.saveDeviceInfo();
            return cachedUser;
          }
        }
      }

      final user = await storageService.getUser();
      if (user != null) {
        _currentUser = user;
        _isAuthenticated = true;
        await deviceService.setCurrentUserId(user.id.toString());
        await deviceService.saveDeviceInfo();

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
    safeNotify();
  }

  Future<void> updateSelectedSchool(int schoolId) async {
    if (_currentUser == null) return;
    _currentUser = _currentUser!.copyWith(schoolId: schoolId);
    await storageService.saveUser(_currentUser!);
    _userController.add(_currentUser);
    safeNotify();
  }

  Future<void> updateDeviceChangeStatus(bool requiresChange) async {
    _requiresDeviceChange = requiresChange;
    _deviceChangeController.add(requiresChange);
    safeNotify();
  }

  Future<void> clearDeviceChangeRequirement() async {
    _requiresDeviceChange = false;
    _lastLoginResult = null;
    _deviceChangeController.add(false);
    safeNotify();
  }

  Future<void> checkSession() async {
    try {
      final sessionValid =
          await storageService.isSessionValid(_sessionDuration);
      if (!sessionValid) {
        await logout(manual: false);
        return;
      }

      if (!connectivityService.isOnline || !_isAuthenticated) return;

      final tokenValid = await validateToken();
      if (!tokenValid && _isAuthenticated) {
        await logout(manual: false);
      }
    } catch (e) {}
  }

  @override
  Future<void> onOnlineRefresh() async {
    log('Online - refreshing auth state');
    if (_isAuthenticated) {
      final tokenValid = await validateToken();
      if (!tokenValid) {
        if (_isAuthenticated) {
          await logout(manual: false);
        }
        return;
      }
    }

    if (_isAuthenticated && _currentUser != null) {
      await loadUser();
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
    disposeSubscriptions();
    super.dispose();
  }
}

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

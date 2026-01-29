import 'dart:async';

import 'package:familyacademyclient/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../../services/device_service.dart';
import '../../models/user_model.dart';
import '../../utils/helpers.dart';
import '../../utils/constants.dart';
import '../../utils/api_response.dart';

class AuthProvider with ChangeNotifier {
  final ApiService apiService;
  final StorageService storageService;
  final DeviceService deviceService;

  User? _user;
  bool _isLoading = false;
  String? _error;
  bool _isAuthenticated = false;
  bool _deviceChangeRequired = false;
  String? _currentDeviceId;
  DateTime? _lastLoginDate;
  bool _requiresReLogin = false;
  String? _fcmToken;

  AuthProvider({
    required this.apiService,
    required this.storageService,
  }) : deviceService = DeviceService();

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _isAuthenticated;
  bool get deviceChangeRequired => _deviceChangeRequired;
  String? get currentDeviceId => _currentDeviceId;
  bool get requiresReLogin => _requiresReLogin;
  String? get fcmToken => _fcmToken;

  Future<void> initialize() async {
    try {
      await deviceService.init();
      final storedUser = await storageService.getUser();
      final token = await storageService.getToken();
      final lastLoginString = await storageService.getLastAppState();

      if (lastLoginString != null) {
        try {
          _lastLoginDate = DateTime.parse(lastLoginString);

          if (_lastLoginDate != null) {
            final daysSinceLastLogin =
                DateTime.now().difference(_lastLoginDate!).inDays;
            if (daysSinceLastLogin >= 3) {
              _requiresReLogin = true;
              debugLog('AuthProvider',
                  'Login required: 3 days passed since last login');
            }
          }
        } catch (e) {
          debugLog('AuthProvider', 'Error parsing last login date: $e');
        }
      }

      if (storedUser != null && token != null && !_requiresReLogin) {
        _user = storedUser;
        _isAuthenticated = true;

        try {
          final response = await apiService.validateToken();
          if (response.data != null && response.data?['user'] != null) {
            _user = User.fromJson(response.data?['user']);
            await storageService.saveUser(_user!);
          }
          _updateLastLoginDate();
        } catch (e) {
          _user = null;
          _isAuthenticated = false;
          _requiresReLogin = true;
          await storageService.clearAll();
        }
      } else if (token != null && _requiresReLogin) {
        await storageService.clearTokens();
        await storageService.clearUser();
        _isAuthenticated = false;
        _requiresReLogin = true;
      }
    } catch (e) {
      _error = 'Failed to initialize authentication';
      debugLog('AuthProvider', 'initialize error: $e');
    }
    notifyListeners();
  }

  Future<void> _updateLastLoginDate() async {
    _lastLoginDate = DateTime.now();
    await storageService.saveLastAppState(_lastLoginDate!.toIso8601String());
  }

  Stream<bool> get authStream {
    final controller = StreamController<bool>();
    controller.add(_isAuthenticated);
    addListener(() {
      if (!controller.isClosed) {
        controller.add(_isAuthenticated);
      }
    });
    return controller.stream;
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> register(String username, String password, String deviceId,
      String? fcmToken) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await deviceService.init();

      debugLog('AuthProvider', 'Registering with device ID: $deviceId');

      final response = await apiService.register(
        username,
        password,
        deviceId,
        fcmToken: fcmToken, // Pass FCM token
      );

      if (response.success && response.data != null) {
        final data = response.data as Map<String, dynamic>;

        if (data['user'] != null && data['user'] is Map<String, dynamic>) {
          _user = User.fromJson(data['user'] as Map<String, dynamic>);
        } else {
          _user = User.fromJson({
            'id': 0,
            'username': username,
            'account_status': 'unpaid',
            'parent_linked': false,
            'streak_count': 0,
            'total_study_time': 0,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        }

        _isAuthenticated = true;

        if (data['token'] != null) {
          final token = data['token'].toString();
          await storageService.saveToken(token);
          debugLog('AuthProvider', 'Token saved: ${token.substring(0, 20)}...');

          try {
            await Future.delayed(const Duration(milliseconds: 500));
            await updatePrimaryDevice(deviceId);
            debugLog('AuthProvider', 'Device ID set after registration');
          } catch (e) {
            debugLog(
                'AuthProvider', 'Error setting device after registration: $e');
          }

          await _reinitializeApiServiceWithToken(token);
        }

        if (_user != null) {
          await storageService.saveUser(_user!);
          await _updateLastLoginDate();
          debugLog('AuthProvider', 'User saved: ${_user!.username}');
        }

        notifyListeners();
      } else {
        _error = response.message;
        notifyListeners();
        throw Exception(response.message);
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _reinitializeApiServiceWithToken(String token) async {
    try {
      await storageService.saveToken(token);
      debugLog('AuthProvider', 'ApiService token updated');
    } catch (e) {
      debugLog('AuthProvider', 'Error reinitializing ApiService: $e');
    }
  }

  Future<void> studentLogin(
    String username,
    String password,
    String? deviceId,
    String? fcmToken,
  ) async {
    _isLoading = true;
    _error = null;
    _deviceChangeRequired = false;
    _currentDeviceId = null;
    notifyListeners();

    try {
      debugLog('AuthProvider', '🔐 Attempting login for: $username');

      if (deviceId == null) {
        await deviceService.init();
        deviceId = await deviceService.getDeviceId();
      }

      // Store FCM token for later use
      _fcmToken = fcmToken;

      final response = await apiService.studentLogin(
        username,
        password,
        deviceId,
        fcmToken, // Pass FCM token
      );

      debugLog('AuthProvider', '✅ Login response received');

      if (response.success && response.data != null) {
        final data = response.data as Map<String, dynamic>;

        final userData = data['user'];
        final token = data['token'];

        if (userData != null && token != null) {
          debugLog('AuthProvider', '👤 User data received');
          _user = User.fromJson(userData);
          _isAuthenticated = true;

          await storageService.saveUser(_user!);
          await storageService.saveToken(token.toString());

          if (deviceId != null) {
            await storageService.saveDeviceId(deviceId);
          }

          if (data['deviceToken'] != null) {
            await storageService.saveRefreshToken(
              data['deviceToken'].toString(),
            );
          }

          await _updateLastLoginDate();
          _requiresReLogin = false;

          debugLog(
            'AuthProvider',
            '✅ User authenticated successfully. ID: ${_user!.id}',
          );

          notifyListeners();
        } else {
          throw ApiError(
            message: 'Invalid login response: missing user data or token',
          );
        }
      } else {
        if (response.data != null && response.data is Map) {
          final errorData = response.data as Map<String, dynamic>;
          if (errorData['action'] == 'device_change_required') {
            _deviceChangeRequired = true;
            _currentDeviceId = errorData['currentDeviceId'];
            _error = errorData['message'];

            debugLog(
              'AuthProvider',
              '⚠️ Device change required. Current device: $_currentDeviceId',
            );

            notifyListeners();
            return;
          } else if (errorData['action'] == 'max_device_changes_reached') {
            _deviceChangeRequired = true;
            _error = 'Maximum device changes reached. Please contact support.';
            notifyListeners();
            return;
          }
        }

        _error = response.message;
        notifyListeners();
        throw ApiError(message: response.message);
      }
    } on ApiError catch (e) {
      _error = e.message;

      if (e.action == 'device_change_required') {
        _deviceChangeRequired = true;
        _currentDeviceId = e.data is Map ? e.data['currentDeviceId'] : null;
        debugLog(
          'AuthProvider',
          '⚠️ Device change required. Current device: $_currentDeviceId',
        );
      }

      notifyListeners();
      rethrow;
    } catch (e) {
      _error = e.toString();
      debugLog('AuthProvider', '❌ Login error: $e');
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _sendFcmTokenAfterLogin() async {
    try {
      final notificationService = NotificationService();
      final fcmToken = await notificationService.getFCMToken();

      if (fcmToken != null && _isAuthenticated) {
        debugLog('AuthProvider',
            '📱 Sending FCM token after login: ${fcmToken.substring(0, 20)}...');
        await notificationService.sendFcmTokenToBackendIfAuthenticated();
      }
    } catch (e) {
      debugLog('AuthProvider', '❌ Error sending FCM token after login: $e');
    }
  }

  Future<Map<String, dynamic>> submitDeviceChangePayment({
    required String username,
    required String password,
    required String paymentMethod,
    required double amount,
    required String proofImagePath,
    required String deviceId,
    required String? fcmToken,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugLog('AuthProvider', 'Submitting device change payment');
      final response = await apiService.submitDeviceChangePayment(
        username: username,
        password: password,
        paymentMethod: paymentMethod,
        amount: amount,
        proofImagePath: proofImagePath,
        deviceId: deviceId,
      );

      if (response.data != null && response.data?['success'] == true) {
        await updatePrimaryDevice(deviceId);
        // Also update FCM token if provided
        if (fcmToken != null) {
          await apiService.updateFcmToken(fcmToken);
        }
      }

      return response.data ?? {};
    } catch (e) {
      _error = e.toString();
      debugLog('AuthProvider', 'submitDeviceChangePayment error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await apiService.logout();
    } catch (e) {
      debugLog('AuthProvider', 'Logout API error (ignored): $e');
    } finally {
      await storageService.clearTokens();
      await storageService.clearUser();
      await storageService.saveLastAppState(DateTime.now().toIso8601String());

      _user = null;
      _isAuthenticated = false;
      _error = null;
      _requiresReLogin = false;

      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logoutDueToInactivity() async {
    await storageService.clearTokens();
    await storageService.clearUser();

    _user = null;
    _isAuthenticated = false;
    _requiresReLogin = true;

    debugLog('AuthProvider', 'User logged out due to inactivity (3 days)');
    notifyListeners();
  }

  Future<void> selectSchool(int schoolId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await apiService.selectSchool(schoolId);

      if (_user != null) {
        final updatedUser = User(
          id: _user!.id,
          username: _user!.username,
          email: _user!.email,
          phone: _user!.phone,
          profileImage: _user!.profileImage,
          schoolId: schoolId,
          accountStatus: _user!.accountStatus,
          primaryDeviceId: _user!.primaryDeviceId,
          tvDeviceId: _user!.tvDeviceId,
          parentLinked: _user!.parentLinked,
          parentTelegramUsername: _user!.parentTelegramUsername,
          parentLinkDate: _user!.parentLinkDate,
          streakCount: _user!.streakCount,
          lastStreakDate: _user!.lastStreakDate,
          totalStudyTime: _user!.totalStudyTime,
          adminNotes: _user!.adminNotes,
          createdAt: _user!.createdAt,
          updatedAt: DateTime.now(),
        );

        _user = updatedUser;
        await storageService.saveUser(_user!);
      }
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> handleSuccessfulLogin(Map<String, dynamic> data) async {
    final userData = data['user'];
    final token = data['token'];

    if (userData != null && token != null) {
      debugLog('AuthProvider', '👤 User data received');
      _user = User.fromJson(userData);
      _isAuthenticated = true;

      await storageService.saveUser(_user!);
      await storageService.saveToken(token.toString());

      final deviceId = data['deviceId'];
      if (deviceId != null) {
        await storageService.saveDeviceId(deviceId);
      }

      if (data['deviceToken'] != null) {
        await storageService.saveRefreshToken(
          data['deviceToken'].toString(),
        );
      }

      await _updateLastLoginDate();
      _requiresReLogin = false;

      debugLog(
        'AuthProvider',
        '✅ User authenticated successfully. ID: ${_user!.id}',
      );

      // NEW: Send FCM token to backend after successful login
      await _sendFcmTokenAfterLogin();

      notifyListeners();
    } else {
      throw Exception('Invalid login response: missing user data or token');
    }
  }

  Future<void> updateAfterDeviceChange({
    required Map<String, dynamic> userData,
    required String token,
    String? deviceToken,
    required String deviceId,
    String? fcmToken,
  }) async {
    _user = User.fromJson(userData);
    _isAuthenticated = true;
    _deviceChangeRequired = false;

    await storageService.saveUser(_user!);
    await storageService.saveToken(token);
    await storageService.saveDeviceId(deviceId);
    await _updateLastLoginDate();

    if (deviceToken != null) {
      await storageService.saveRefreshToken(deviceToken);
    }

    // Update FCM token if provided
    if (fcmToken != null) {
      await apiService.updateFcmToken(fcmToken);
    }

    debugLog('AuthProvider', '✅ Device change completed successfully');
    notifyListeners();
  }

  Future<void> refreshUserData() async {
    if (_user == null) return;

    try {
      final response = await apiService.getMyProfile();
      if (response.data != null) {
        final currentSchoolId = _user?.schoolId;
        _user = response.data;

        if (_user?.schoolId == null && currentSchoolId != null) {
          _user = User(
            id: _user!.id,
            username: _user!.username,
            email: _user!.email,
            phone: _user!.phone,
            profileImage: _user!.profileImage,
            schoolId: currentSchoolId,
            accountStatus: _user!.accountStatus,
            primaryDeviceId: _user!.primaryDeviceId,
            tvDeviceId: _user!.tvDeviceId,
            parentLinked: _user!.parentLinked,
            parentTelegramUsername: _user!.parentTelegramUsername,
            parentLinkDate: _user!.parentLinkDate,
            streakCount: _user!.streakCount,
            lastStreakDate: _user!.lastStreakDate,
            totalStudyTime: _user!.totalStudyTime,
            adminNotes: _user!.adminNotes,
            createdAt: _user!.createdAt,
            updatedAt: DateTime.now(),
          );
        }

        await storageService.saveUser(_user!);
        notifyListeners();
      }
    } catch (e) {
      debugLog('AuthProvider', 'refreshUserData error: $e');
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<bool> checkDeviceChange(String newDeviceId) async {
    if (_user == null) return false;

    try {
      return _user!.primaryDeviceId != null &&
          _user!.primaryDeviceId != newDeviceId;
    } catch (e) {
      debugLog('AuthProvider', 'checkDeviceChange error: $e');
      return false;
    }
  }

  Future<void> updatePrimaryDevice(String deviceId) async {
    if (_user == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      await apiService.updateDevice('primary', deviceId);

      final updatedUser = User(
        id: _user!.id,
        username: _user!.username,
        email: _user!.email,
        phone: _user!.phone,
        profileImage: _user!.profileImage,
        schoolId: _user!.schoolId,
        accountStatus: _user!.accountStatus,
        primaryDeviceId: deviceId,
        tvDeviceId: _user!.tvDeviceId,
        parentLinked: _user!.parentLinked,
        parentTelegramUsername: _user!.parentTelegramUsername,
        parentLinkDate: _user!.parentLinkDate,
        streakCount: _user!.streakCount,
        lastStreakDate: _user!.lastStreakDate,
        totalStudyTime: _user!.totalStudyTime,
        adminNotes: _user!.adminNotes,
        createdAt: _user!.createdAt,
        updatedAt: DateTime.now(),
      );

      _user = updatedUser;
      await storageService.saveUser(_user!);
      await storageService.saveDeviceId(deviceId);

      debugLog('AuthProvider', '✅ Primary device updated to: $deviceId');
    } catch (e) {
      _error = e.toString();
      debugLog('AuthProvider', 'updatePrimaryDevice error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearRequiresReLogin() {
    _requiresReLogin = false;
    notifyListeners();
  }

  Future<void> checkAndRequireReLogin() async {
    if (_lastLoginDate == null) return;

    final daysSinceLastLogin =
        DateTime.now().difference(_lastLoginDate!).inDays;
    if (daysSinceLastLogin >= 3) {
      _requiresReLogin = true;
      debugLog('AuthProvider',
          'Requiring re-login: $daysSinceLastLogin days since last login');
      notifyListeners();
    }
  }

  // NEW: Get FCM token from notification service
  Future<String?> getFcmTokenFromNotificationService() async {
    try {
      final notificationService = NotificationService();
      final token = await notificationService.getFCMToken();
      return token;
    } catch (e) {
      debugLog('AuthProvider', 'Error getting FCM token: $e');
      return null;
    }
  }
}

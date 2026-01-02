import 'dart:async';

import 'package:familyacademyclient/utils/api_response.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../models/user_model.dart';
import '../utils/helpers.dart';

class AuthProvider with ChangeNotifier {
  final ApiService apiService;
  final StorageService storageService;

  User? _user;
  bool _isLoading = false;
  String? _error;
  bool _isAuthenticated = false;
  bool _deviceChangeRequired = false;
  String? _currentDeviceId;

  AuthProvider({required this.apiService, required this.storageService});

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _isAuthenticated;
  bool get deviceChangeRequired => _deviceChangeRequired;
  String? get currentDeviceId => _currentDeviceId;

  Future<void> initialize() async {
    try {
      final storedUser = await storageService.getUser();
      final token = await storageService.getToken();

      if (storedUser != null && token != null) {
        _user = storedUser;
        _isAuthenticated = true;

        try {
          final response = await apiService.validateToken();
          if (response.data != null && response.data?['user'] != null) {
            _user = User.fromJson(response.data?['user']);
            await storageService.saveUser(_user!);
          }
        } catch (e) {
          _user = null;
          _isAuthenticated = false;
          await storageService.clearAll();
        }
      }
    } catch (e) {
      _error = 'Failed to initialize authentication';
      debugLog('AuthProvider', 'initialize error: $e');
    }
    notifyListeners();
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

  Future<void> register(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await apiService.register(username, password);

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

          await _reinitializeApiServiceWithToken(token);
        }

        if (_user != null) {
          await storageService.saveUser(_user!);
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
      await storageService.clearTokens();

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
  ) async {
    _isLoading = true;
    _error = null;
    _deviceChangeRequired = false;
    _currentDeviceId = null;
    notifyListeners();

    try {
      debugLog('AuthProvider', '🔐 Attempting login for: $username');

      final response = await apiService.studentLogin(
        username,
        password,
        deviceId,
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
            await storageService
                .saveRefreshToken(data['deviceToken'].toString());
          }

          debugLog('AuthProvider',
              '✅ User authenticated successfully. ID: ${_user!.id}');

          notifyListeners();
        } else {
          throw Exception('Invalid login response: missing user data or token');
        }
      } else {
        throw Exception(response.message);
      }
    } on ApiError catch (e) {
      if (e.action == 'device_change_required') {
        _deviceChangeRequired = true;
        _currentDeviceId = e.data is Map ? e.data['currentDeviceId'] : null;
        debugLog('AuthProvider',
            '⚠️ Device change required. Current device: $_currentDeviceId');
      } else {
        _error = e.message;
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

  Future<Map<String, dynamic>> submitDeviceChangePayment({
    required String username,
    required String password,
    required String paymentMethod,
    required double amount,
    required String proofImagePath,
    required String deviceId,
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
    } finally {
      await storageService.clearAll();

      _user = null;
      _isAuthenticated = false;
      _error = null;

      _isLoading = false;
      notifyListeners();
    }
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

  Future<void> refreshUserData() async {
    if (_user == null) return;

    try {
      final response = await apiService.getMyProfile();
      if (response.data != null) {
        _user = response.data;
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
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

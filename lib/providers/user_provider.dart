// lib/providers/user_provider.dart
// COMPLETE PRODUCTION-READY FINAL VERSION - INSTANT CACHE LOADING

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../services/user_session.dart';
import '../services/connectivity_service.dart';
import '../services/hive_service.dart';
import '../services/offline_queue_manager.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';
import '../utils/api_response.dart';
import 'base_provider.dart';

class UserProvider extends ChangeNotifier
    with BaseProvider<UserProvider>, OfflineAwareProvider<UserProvider> {
  @override
  final ConnectivityService connectivityService;

  final ApiService apiService;
  final DeviceService deviceService;
  final HiveService hiveService;
  final OfflineQueueManager offlineQueueManager;

  User? _currentUser;

  bool _hasLoadedProfile = false;
  bool _hasInitialData = false;
  bool _isLoadingProfile = false;
  DateTime? _lastProfileFetch;

  int _apiCallCount = 0;
  String? _currentUserId;

  bool _isBackgroundRefreshing = false;

  static const Duration _cacheExpiry = AppConstants.cacheTTLUserProfile;
  static const Duration _minFetchInterval = Duration(minutes: 5);

  Box? _userBox;

  final StreamController<User?> _userUpdateController =
      StreamController<User?>.broadcast();

  UserProvider({
    required this.apiService,
    required this.deviceService,
    required this.connectivityService,
    required this.hiveService,
    required this.offlineQueueManager,
  }) {
    log('UserProvider constructor called');
    initializeOfflineAware(
      connectivity: connectivityService,
      queue: offlineQueueManager,
    );
    _registerQueueProcessors();
    _init();
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
      );

      if (response.success) {
        await loadUserProfile(forceRefresh: true);
      }

      return response.success;
    } catch (e) {
      log('Error processing profile update: $e');
      return false;
    }
  }

  Future<void> _init() async {
    log('_init() START');
    await _getCurrentUserId();
    await _openHiveBoxes();
    await _loadCachedData();
    log('_init() END');
  }

  Future<void> _openHiveBoxes() async {
    try {
      if (!Hive.isBoxOpen(AppConstants.hiveUserBox)) {
        _userBox = await Hive.openBox<dynamic>(AppConstants.hiveUserBox);
      } else {
        _userBox = Hive.box<dynamic>(AppConstants.hiveUserBox);
      }
      log('✅ Hive box opened');
    } catch (e) {
      log('⚠️ Error opening Hive boxes: $e');
    }
  }

  Future<void> _getCurrentUserId() async {
    final session = UserSession();
    _currentUserId = await session.getCurrentUserId();
    log('Current user ID: $_currentUserId');
  }

  Future<void> _loadCachedData() async {
    log('_loadCachedData() START');

    try {
      // Try Hive first (fastest)
      if (_userBox != null && _currentUserId != null) {
        final cachedUser = _userBox!.get('user_${_currentUserId}_profile');
        if (cachedUser != null) {
          if (cachedUser is User) {
            _currentUser = cachedUser;
            _hasLoadedProfile = true;
            _hasInitialData = true;
            _userUpdateController.add(_currentUser);
            log('✅ Loaded user from Hive INSTANTLY: ${_currentUser?.username}');
            return;
          } else if (cachedUser is Map) {
            try {
              _currentUser = User.fromJson(
                Map<String, dynamic>.from(cachedUser),
              );
              _hasLoadedProfile = true;
              _hasInitialData = true;
              _userUpdateController.add(_currentUser);
              log('✅ Loaded user from Hive INSTANTLY (converted): ${_currentUser?.username}');
              return;
            } catch (e) {
              log('Error converting user from Hive: $e');
            }
          }
        }
      }

      // If no Hive data, try DeviceService
      if (_currentUser == null) {
        log('Trying DeviceService for user');
        final cachedUser =
            await deviceService.getCacheItem<Map<String, dynamic>>(
          'user_profile',
          isUserSpecific: true,
        );
        if (cachedUser != null) {
          _currentUser = User.fromJson(cachedUser);
          _hasLoadedProfile = true;
          _hasInitialData = true;
          _userUpdateController.add(_currentUser);
          log('✅ Loaded user from DeviceService: ${_currentUser?.username}');

          if (_userBox != null && _currentUserId != null) {
            await _userBox!.put(
              'user_${_currentUserId}_profile',
              _currentUser,
            );
          }
          return;
        }
      }

      if (_currentUser == null) {
        _hasLoadedProfile = true;
        _hasInitialData = true;
        log('ℹ️ No cached user data found, but marked as loaded');
      }

      log('✅ Loaded cached data: profile=$_hasLoadedProfile, hasInitialData=$_hasInitialData');
    } catch (e) {
      log('Error loading cached data: $e');
      _hasLoadedProfile = true;
      _hasInitialData = true;
    }
  }

  Future<void> _saveUserToHive() async {
    try {
      if (_userBox != null && _currentUserId != null && _currentUser != null) {
        await _userBox!.put('user_${_currentUserId}_profile', _currentUser);
        log('💾 Saved user to Hive');
      }
    } catch (e) {
      log('Error saving user to Hive: $e');
    }
  }

  // ===== GETTERS =====
  User? get currentUser => _currentUser;

  bool get hasLoadedProfile => _hasLoadedProfile;
  bool get hasInitialData => _hasInitialData;
  bool get isLoadingProfile => _isLoadingProfile;

  bool get isBackgroundRefreshing => _isBackgroundRefreshing;

  Stream<User?> get userUpdates => _userUpdateController.stream;

  // ===== LOAD USER PROFILE - FIXED FOR INSTANT CACHE =====
  Future<void> loadUserProfile({
    bool forceRefresh = false,
    bool isManualRefresh = false,
  }) async {
    _apiCallCount++;
    final callId = _apiCallCount;

    log('loadUserProfile() CALL #$callId');

    if (isManualRefresh && isOffline) {
      throw Exception('Network error. Please check your internet connection.');
    }

    // ✅ CRITICAL: Return cached data IMMEDIATELY if we have it
    if (_hasLoadedProfile && _currentUser != null && !forceRefresh) {
      log('✅ Returning cached profile INSTANTLY');
      _userUpdateController.add(_currentUser);
      setLoaded();
      return;
    }

    if (_isLoadingProfile && !forceRefresh) {
      log('⏳ Already loading, waiting for result...');
      // Wait for loading to complete
      int attempts = 0;
      while (_isLoadingProfile && attempts < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }
      if (_currentUser != null) {
        log('✅ Got profile from existing load');
        _userUpdateController.add(_currentUser);
        setLoaded();
        return;
      }
    }

    _isLoadingProfile = true;
    setLoading();

    try {
      // STEP 1: Try Hive cache FIRST (before showing loading state)
      if (!forceRefresh && _currentUserId != null && _userBox != null) {
        log('STEP 1: Checking Hive cache');
        final cachedUser = _userBox!.get('user_${_currentUserId}_profile');

        if (cachedUser != null) {
          if (cachedUser is User) {
            _currentUser = cachedUser;
          } else if (cachedUser is Map) {
            try {
              _currentUser = User.fromJson(
                Map<String, dynamic>.from(cachedUser),
              );
            } catch (e) {
              log('Error converting Hive user: $e');
            }
          }

          if (_currentUser != null) {
            _hasLoadedProfile = true;
            _hasInitialData = true;
            _lastProfileFetch = DateTime.now();
            _isLoadingProfile = false;
            setLoaded();
            _userUpdateController.add(_currentUser);
            log('✅ Loaded user from Hive: ${_currentUser?.username}');

            // Refresh in background if online
            if (!isOffline && !isManualRefresh) {
              unawaited(_refreshProfileInBackground());
            }
            return;
          }
        }
      }

      // STEP 2: Try DeviceService cache
      if (!forceRefresh && _currentUserId != null) {
        log('STEP 2: Checking DeviceService cache');
        final cachedUser =
            await deviceService.getCacheItem<Map<String, dynamic>>(
          AppConstants.userProfileKey(_currentUserId!),
          isUserSpecific: true,
        );

        if (cachedUser != null) {
          _currentUser = User.fromJson(cachedUser);
          _hasLoadedProfile = true;
          _hasInitialData = true;
          _lastProfileFetch = DateTime.now();
          _isLoadingProfile = false;
          setLoaded();
          _userUpdateController.add(_currentUser);
          log('✅ Loaded user from DeviceService: ${_currentUser?.username}');

          if (_userBox != null) {
            await _userBox!.put(
              'user_${_currentUserId}_profile',
              _currentUser,
            );
          }

          if (!isOffline && !isManualRefresh) {
            unawaited(_refreshProfileInBackground());
          }
          return;
        }
      }

      // STEP 3: Check offline status
      if (isOffline) {
        log('STEP 3: Offline mode');
        if (_currentUser != null) {
          _hasLoadedProfile = true;
          _isLoadingProfile = false;
          setLoaded();
          _userUpdateController.add(_currentUser);
          log('✅ Showing cached profile offline');
          return;
        }

        setError('You are offline. No cached profile available.');
        _hasLoadedProfile = true;
        _isLoadingProfile = false;
        setLoaded();
        _userUpdateController.add(null);

        if (isManualRefresh) {
          throw Exception(
            'Network error. Please check your internet connection.',
          );
        }
        return;
      }

      // STEP 4: Fetch from API (with timeout and cache fallback)
      log('STEP 4: Fetching from API');

      ApiResponse<User> response;
      try {
        response = await apiService.getMyProfile().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            log('⏱️ API timeout in loadUserProfile - using cached data');
            if (_currentUser != null) {
              _hasLoadedProfile = true;
              _isLoadingProfile = false;
              setLoaded();
              _userUpdateController.add(_currentUser);
              return ApiResponse<User>(
                success: true,
                message: 'Using cached data (server timeout)',
                data: _currentUser,
              );
            }
            return ApiResponse<User>(
              success: false,
              message: 'Connection timeout. Please try again.',
            );
          },
        );
      } catch (timeoutError) {
        log('⏱️ Timeout error caught: $timeoutError');
        if (_currentUser != null) {
          _hasLoadedProfile = true;
          _isLoadingProfile = false;
          setLoaded();
          _userUpdateController.add(_currentUser);
          return;
        }
        throw TimeoutException('Request timed out');
      }

      if (response.success && response.data != null) {
        _currentUser = response.data;
        log('✅ Received profile from API: ${_currentUser?.username}');
        _hasLoadedProfile = true;
        _hasInitialData = true;
        _lastProfileFetch = DateTime.now();
        _isLoadingProfile = false;
        setLoaded();

        if (_currentUser != null && _currentUserId != null) {
          if (_userBox != null) {
            await _userBox!.put(
              'user_${_currentUserId}_profile',
              _currentUser,
            );
          }

          deviceService.saveCacheItem(
            AppConstants.userProfileKey(_currentUserId!),
            _currentUser!.toJson(),
            ttl: _cacheExpiry,
            isUserSpecific: true,
          );
        }
        _userUpdateController.add(_currentUser);
        log('✅ Success! User profile loaded');
      } else {
        throw Exception('Failed to load profile: ${response.message}');
      }
    } catch (e) {
      setError(e.toString());
      _hasLoadedProfile = true;
      _isLoadingProfile = false;
      setLoaded();
      log('❌ Error loading profile: $e');

      if (_currentUser == null && _currentUserId != null) {
        log('Attempting cache recovery');
        await _recoverProfileFromCache();
      } else if (_currentUser != null) {
        // Still have cached data, so don't show error
        setLoaded();
        _userUpdateController.add(_currentUser);
        return;
      }

      _userUpdateController.add(_currentUser);

      if (isManualRefresh) {
        rethrow;
      }
    } finally {
      safeNotify();
    }
  }

  Future<void> _refreshProfileInBackground() async {
    if (isOffline) return;

    if (_isBackgroundRefreshing) {
      log('Profile refresh already in progress');
      return;
    }

    if (_lastProfileFetch != null) {
      final age = DateTime.now().difference(_lastProfileFetch!);
      if (age < _minFetchInterval) {
        log('Skipping background refresh - last fetch was ${age.inSeconds}s ago');
        return;
      }
    }

    _isBackgroundRefreshing = true;

    try {
      final response = await apiService.getMyProfile().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          log('⏱️ API timeout in background refresh - skipping');
          return ApiResponse<User>(
            success: false,
            message: 'Timeout',
          );
        },
      );

      if (response.success && response.data != null) {
        final updatedUser = response.data;
        if (updatedUser != null && _currentUser?.id == updatedUser.id) {
          _currentUser = updatedUser;
          _lastProfileFetch = DateTime.now();
          log('Background refresh got updated user: ${updatedUser.username}');

          if (_currentUserId != null) {
            if (_userBox != null) {
              await _userBox!.put(
                'user_${_currentUserId}_profile',
                updatedUser,
              );
            }
            deviceService.saveCacheItem(
              AppConstants.userProfileKey(_currentUserId!),
              _currentUser!.toJson(),
              ttl: _cacheExpiry,
              isUserSpecific: true,
            );
          }
          _userUpdateController.add(_currentUser);
          safeNotify();
          log('🔄 Profile background refresh complete');
        }
      }
    } catch (e) {
      log('Profile background refresh error: $e');
    } finally {
      _isBackgroundRefreshing = false;
    }
  }

  Future<void> _recoverProfileFromCache() async {
    log('Attempting profile cache recovery');

    if (_userBox != null && _currentUserId != null) {
      try {
        final cachedUser = _userBox!.get('user_${_currentUserId}_profile');
        if (cachedUser != null) {
          if (cachedUser is User) {
            _currentUser = cachedUser;
          } else if (cachedUser is Map) {
            _currentUser = User.fromJson(Map<String, dynamic>.from(cachedUser));
          }
          if (_currentUser != null) {
            _hasLoadedProfile = true;
            _hasInitialData = true;
            _userUpdateController.add(_currentUser);
            log('✅ Recovered profile from Hive after error');
            return;
          }
        }
      } catch (e) {
        log('Error recovering from Hive: $e');
      }
    }

    if (_currentUserId != null) {
      try {
        final cachedUser =
            await deviceService.getCacheItem<Map<String, dynamic>>(
          AppConstants.userProfileKey(_currentUserId!),
          isUserSpecific: true,
        );
        if (cachedUser != null) {
          _currentUser = User.fromJson(cachedUser);
          _hasLoadedProfile = true;
          _hasInitialData = true;
          _userUpdateController.add(_currentUser);
          log('✅ Recovered profile from DeviceService after error');
        }
      } catch (e) {
        log('Error recovering from DeviceService: $e');
      }
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> updateProfile({
    String? email,
    String? phone,
    String? profileImage,
  }) async {
    log('updateProfile()');

    setLoading();

    try {
      if (isOffline) {
        log('📝 Offline - queuing profile update');
        await _queueProfileUpdateOffline(
          email: email,
          phone: phone,
          profileImage: profileImage,
        );
        setLoaded();
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          message: 'Profile update saved offline. Will sync when online.',
          isQueued: true,
        );
      }

      final response = await apiService
          .updateMyProfile(
        email: email,
        phone: phone,
        profileImage: profileImage,
      )
          .timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          log('⏱️ API timeout in updateProfile');
          throw TimeoutException('Request timed out');
        },
      );

      if (response.success) {
        log('✅ Profile updated successfully via API');

        if (response.data != null) {
          try {
            final updatedUser = User.fromJson(response.data!);
            _currentUser = updatedUser;
            await _saveUserToHive();
            _userUpdateController.add(_currentUser);
            log('✅ Updated user data from API response');
          } catch (e) {
            log('Error parsing updated user data: $e');
            await loadUserProfile(forceRefresh: true);
          }
        } else {
          await loadUserProfile(forceRefresh: true);
        }

        setLoaded();
        safeNotify();
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          message: 'Profile updated successfully',
          data: response.data,
        );
      } else {
        setLoaded();
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          message: response.message,
        );
      }
    } catch (e) {
      setLoaded();
      setError(e.toString());
      log('❌ Profile update error: $e');

      String errorMessage = 'Failed to update profile';
      if (e.toString().contains('Email already in use')) {
        errorMessage = 'Email already in use by another user';
      } else if (e.toString().contains('phone')) {
        errorMessage = 'Phone number already in use by another user';
      } else if (e.toString().contains('timed out')) {
        errorMessage = 'Request timed out. Please try again.';
      }

      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: errorMessage,
      );
    }
  }

  Future<void> _queueProfileUpdateOffline({
    String? email,
    String? phone,
    String? profileImage,
  }) async {
    try {
      final userId = await UserSession().getCurrentUserId();
      if (userId == null) return;

      offlineQueueManager.addItem(
        type: AppConstants.queueActionUpdateProfile,
        data: {
          'email': email,
          'phone': phone,
          'profileImage': profileImage,
          'userId': userId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      log('📝 Queued profile update for offline sync');
    } catch (e) {
      log('Error queueing profile update: $e');
    }
  }

  @override
  Future<void> onOnlineRefresh() async {
    log('Online - refreshing user data');
    if (_hasLoadedProfile) {
      await loadUserProfile(forceRefresh: true);
    }
  }

  Future<void> clearUserData() async {
    final session = UserSession();
    if (!session.shouldClearCacheOnLogout()) return;

    final userId = await session.getCurrentUserId();
    if (userId != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_profile_updates_$userId');

      await hiveService.clearUserData(userId);
    }

    if (_currentUserId != null) {
      await deviceService.removeCacheItem(
        AppConstants.userProfileKey(_currentUserId!),
        isUserSpecific: true,
      );
    }

    _currentUser = null;
    _hasLoadedProfile = false;
    _hasInitialData = false;
    _lastProfileFetch = null;

    _userUpdateController.add(null);
    safeNotify();
  }

  @override
  void dispose() {
    _userUpdateController.close();
    _userBox?.close();
    disposeSubscriptions();
    super.dispose();
  }
}

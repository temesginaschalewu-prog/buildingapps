// lib/providers/device_provider.dart
// PRODUCTION-READY FINAL VERSION

import 'dart:async';
import 'package:familyacademyclient/services/offline_queue_manager.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../services/user_session.dart';
import '../services/connectivity_service.dart';
import '../services/hive_service.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'base_provider.dart';

/// PRODUCTION-READY Device Provider
class DeviceProvider extends ChangeNotifier
    with BaseProvider<DeviceProvider>, OfflineAwareProvider<DeviceProvider> {
  @override
  final ConnectivityService connectivityService;

  final ApiService apiService;
  final DeviceService deviceService;
  final HiveService hiveService;

  String? _deviceId;
  String? _tvDeviceId;
  String? _pairingCode;
  DateTime? _pairingExpiresAt;
  bool _isPairing = false;

  // Hive box
  Box<Map<String, dynamic>>? _deviceBox;

  DeviceProvider({
    required this.apiService,
    required this.deviceService,
    required this.connectivityService,
    required this.hiveService,
  }) {
    log('DeviceProvider constructor called');
    initializeOfflineAware(
      connectivity: connectivityService,
      queue: OfflineQueueManager(),
    );
    _initializeAsync();
  }

  // Open Hive box
  Future<void> _openHiveBox() async {
    try {
      _deviceBox = await Hive.openBox<Map<String, dynamic>>('device_box');
      log('✅ Hive box opened');
    } catch (e) {
      log('⚠️ Error opening Hive box: $e');
    }
  }

  // ===== GETTERS =====
  String? get deviceId => _deviceId;
  String? get tvDeviceId => _tvDeviceId;
  String? get pairingCode => _pairingCode;
  DateTime? get pairingExpiresAt => _pairingExpiresAt;
  bool get isPairing => _isPairing;
  bool get hasTvDevice => _tvDeviceId != null && _tvDeviceId!.isNotEmpty;
  bool get isPairingExpired => _pairingExpiresAt == null
      ? true
      : DateTime.now().isAfter(_pairingExpiresAt!);

  Duration get pairingRemainingTime {
    if (_pairingExpiresAt == null) return Duration.zero;
    final now = DateTime.now();
    if (now.isAfter(_pairingExpiresAt!)) return Duration.zero;
    return _pairingExpiresAt!.difference(now);
  }

  String get formattedPairingTime {
    final duration = pairingRemainingTime;
    if (duration.inMinutes <= 0) return 'Expired';

    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  // ===== INITIALIZATION =====
  Future<void> _initializeAsync() async {
    try {
      await _openHiveBox();

      _deviceId = await deviceService.getDeviceId();
      _tvDeviceId = await deviceService.getTvDeviceId();
      await _loadPairingCode();
      await _loadCachedData();

      setLoaded();
      markInitialized();
      log('✅ DeviceProvider initialized');
    } catch (e) {
      setError(getUserFriendlyErrorMessage(e));
      log('❌ Initialization error: $e');
    }
  }

  // Load cached data from Hive
  Future<void> _loadCachedData() async {
    try {
      if (_deviceBox == null) return;

      final cachedTvId = _deviceBox!.get('tv_device_id');
      if (cachedTvId != null && _tvDeviceId == null) {
        _tvDeviceId = cachedTvId['value']?.toString();
      }

      final cachedPairing = _deviceBox!.get('pairing_info');
      if (cachedPairing != null && _pairingCode == null) {
        _pairingCode = cachedPairing['code']?.toString();
        final expiresAtStr = cachedPairing['expires_at']?.toString();
        if (expiresAtStr != null) {
          _pairingExpiresAt = DateTime.parse(expiresAtStr);
        }
        _isPairing = true;
      }

      log('✅ Loaded cached data from Hive');
    } catch (e) {
      log('Error loading cached data: $e');
    }
  }

  Future<void> initialize({bool isManualRefresh = false}) async {
    if (isInitialized) return;

    setLoading();

    try {
      await _initializeAsync();
    } catch (e) {
      if (isManualRefresh) {
        rethrow;
      }
    } finally {
      setLoaded();
      safeNotify();
    }
  }

  Future<void> _loadPairingCode() async {
    // Try Hive first
    if (_deviceBox != null) {
      final cachedPairing = _deviceBox!.get('pairing_info');
      if (cachedPairing != null) {
        _pairingCode = cachedPairing['code']?.toString();
        final expiresAtStr = cachedPairing['expires_at']?.toString();
        if (expiresAtStr != null) {
          _pairingExpiresAt = DateTime.parse(expiresAtStr);
        }
        _isPairing = true;
        return;
      }
    }

    // Fall back to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(AppConstants.pairingCodeKey);
    final expiresAt = prefs.getInt(AppConstants.pairingExpiresAtKey);

    if (code != null && expiresAt != null) {
      _pairingCode = code;
      _pairingExpiresAt = DateTime.fromMillisecondsSinceEpoch(expiresAt);
      _isPairing = true;

      // Save to Hive for next time
      if (_deviceBox != null) {
        await _deviceBox!.put('pairing_info', {
          'code': code,
          'expires_at': _pairingExpiresAt!.toIso8601String(),
        });
      }
    }
  }

  Future<void> _savePairingCode(String code, int expiresInSeconds) async {
    final expiresAt = DateTime.now().add(Duration(seconds: expiresInSeconds));

    // Save to Hive
    if (_deviceBox != null) {
      await _deviceBox!.put('pairing_info', {
        'code': code,
        'expires_at': expiresAt.toIso8601String(),
      });
    }

    // Save to SharedPreferences as fallback
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.pairingCodeKey, code);
    await prefs.setInt(
      AppConstants.pairingExpiresAtKey,
      expiresAt.millisecondsSinceEpoch,
    );

    _pairingCode = code;
    _pairingExpiresAt = expiresAt;
    _isPairing = true;
    safeNotify();
  }

  // ===== PAIR TV DEVICE =====
  Future<void> pairTvDevice(String tvDeviceId) async {
    if (!isInitialized) await initialize();

    if (isOffline) {
      setError(getUserFriendlyErrorMessage(
          'You are offline. Please connect to pair device.'));
      safeNotify();
      return;
    }

    setLoading();

    try {
      final response = await apiService.pairTvDevice(tvDeviceId);
      final data = response.data!;

      final code = data['pairing_code'];
      final expiresIn = data['expires_in'] ?? 600;

      await _savePairingCode(code, expiresIn);
      setLoaded();
      safeNotify();

      log('✅ Paired TV device, code: $code');
    } catch (e) {
      setError(getUserFriendlyErrorMessage(e));
      setLoaded();
      safeNotify();
      rethrow;
    }
  }

  // ===== VERIFY TV PAIRING =====
  Future<void> verifyTvPairing(String code) async {
    if (!isInitialized) await initialize();

    if (isOffline) {
      setError(getUserFriendlyErrorMessage(
          'You are offline. Please connect to verify pairing.'));
      safeNotify();
      return;
    }

    setLoading();

    try {
      final response = await apiService.verifyTvPairing(code);
      final data = response.data!;

      await deviceService.saveTvDeviceId(data['tv_device_id']);
      _tvDeviceId = data['tv_device_id'];

      // Save to Hive
      if (_deviceBox != null) {
        await _deviceBox!.put('tv_device_id', {'value': _tvDeviceId});
      }

      await _clearPairingState();
      await apiService.updateDevice('tv', data['tv_device_id']);

      setLoaded();
      safeNotify();
      log('✅ Verified TV pairing');
    } catch (e) {
      setError(getUserFriendlyErrorMessage(e));
      setLoaded();
      safeNotify();
      rethrow;
    }
  }

  // ===== UNPAIR TV DEVICE =====
  Future<void> unpairTvDevice() async {
    if (!isInitialized) await initialize();

    if (isOffline) {
      setError(getUserFriendlyErrorMessage(
          'You are offline. Please connect to unpair device.'));
      safeNotify();
      return;
    }

    setLoading();

    try {
      await apiService.unpairTvDevice();
      await deviceService.clearTvDeviceId();
      _tvDeviceId = null;

      // Clear from Hive
      if (_deviceBox != null) {
        await _deviceBox!.delete('tv_device_id');
      }

      await apiService.updateDevice('tv', '');
      setLoaded();
      safeNotify();
      log('✅ Unpaired TV device');
    } catch (e) {
      setError(getUserFriendlyErrorMessage(e));
      setLoaded();
      safeNotify();
      rethrow;
    }
  }

  Future<void> _clearPairingState() async {
    // Clear from Hive
    if (_deviceBox != null) {
      await _deviceBox!.delete('pairing_info');
    }

    // Clear from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.pairingCodeKey);
    await prefs.remove(AppConstants.pairingExpiresAtKey);

    _pairingCode = null;
    _pairingExpiresAt = null;
    _isPairing = false;
    safeNotify();
  }

  Future<void> cancelPairing() async {
    await _clearPairingState();
  }

  // ===== CLEAR USER DATA =====
  Future<void> clearUserData() async {
    final session = UserSession();
    if (!session.shouldClearCacheOnLogout()) return;

    // Clear device-specific data (TV pairing is device-specific, not user-specific)
    // But we'll clear TV device ID as it might be linked to user

    _tvDeviceId = null;
    _pairingCode = null;
    _pairingExpiresAt = null;
    _isPairing = false;

    // Clear from Hive
    if (_deviceBox != null) {
      await _deviceBox!.delete('tv_device_id');
      await _deviceBox!.delete('pairing_info');
    }

    // Clear from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.pairingCodeKey);
    await prefs.remove(AppConstants.pairingExpiresAtKey);
    await deviceService.clearTvDeviceId();

    safeNotify();
    log('🧹 Cleared device data');
  }

  @override
  void dispose() {
    _deviceBox?.close();
    disposeSubscriptions();
    super.dispose();
  }
}

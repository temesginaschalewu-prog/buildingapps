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
  String? _error;

  DeviceProvider({required this.apiService}) : deviceService = DeviceService();

  String? get deviceId => _deviceId;
  String? get tvDeviceId => _tvDeviceId;
  String? get pairingCode => _pairingCode;
  DateTime? get pairingExpiresAt => _pairingExpiresAt;
  bool get isPairing => _isPairing;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool get hasTvDevice => _tvDeviceId != null && _tvDeviceId!.isNotEmpty;
  bool get isPairingExpired {
    if (_pairingExpiresAt == null) return true;
    return DateTime.now().isAfter(_pairingExpiresAt!);
  }

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      debugLog('DeviceProvider', 'Initializing device provider');

      await deviceService.init();

      _deviceId = await deviceService.getDeviceId();
      debugLog('DeviceProvider', 'Device id set: $_deviceId');

      await _loadTvDeviceId();
    } catch (e) {
      _error = e.toString();
      debugLog('DeviceProvider', 'initialize error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadTvDeviceId() async {
    _tvDeviceId = await deviceService.getTvDeviceId();
    debugLog('DeviceProvider', 'Loaded tvDeviceId: $_tvDeviceId');
  }

  Future<void> _saveTvDeviceId(String deviceId) async {
    await deviceService.saveTvDeviceId(deviceId);
    _tvDeviceId = deviceId;
    notifyListeners();
    debugLog('DeviceProvider', 'Saved tvDeviceId: $deviceId');
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

  Future<void> pairTvDevice(String tvDeviceId) async {
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
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await apiService.verifyTvPairing(code);
      final data = response.data!;

      await _saveTvDeviceId(data['tv_device_id']);

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
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await apiService.unpairTvDevice();

      await _clearTvDevice();

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

  Future<void> _clearTvDevice() async {
    await deviceService.clearTvDeviceId();
    _tvDeviceId = null;
    notifyListeners();
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
}

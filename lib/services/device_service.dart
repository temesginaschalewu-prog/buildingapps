import 'dart:io';
import 'dart:math';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class DeviceService {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  late SharedPreferences _prefs;

  Future<void> init() async {
    debugLog('DeviceService', 'Initializing SharedPreferences');
    _prefs = await SharedPreferences.getInstance();
    debugLog('DeviceService', 'SharedPreferences initialized');
  }

  Future<String> getDeviceId() async {
    // First try to get saved device ID
    String? savedDeviceId = _prefs.getString(AppConstants.deviceIdKey);

    if (savedDeviceId != null && savedDeviceId.isNotEmpty) {
      debugLog('DeviceService', 'Using saved deviceId: $savedDeviceId');
      return savedDeviceId;
    }

    // Generate new persistent device ID
    String deviceId;

    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        // Use Android ID which is persistent
        final androidId = androidInfo.id;
        if (androidId != null &&
            androidId.isNotEmpty &&
            androidId != "unknown") {
          deviceId = 'ANDROID_${androidId}';
        } else {
          // Fallback to generated ID
          deviceId = 'ANDROID_${_generatePersistentId()}';
        }
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        // Use identifierForVendor which is persistent per app
        final vendorId = iosInfo.identifierForVendor;
        if (vendorId != null && vendorId.isNotEmpty) {
          deviceId = 'IOS_${vendorId}';
        } else {
          // Fallback to generated ID
          deviceId = 'IOS_${_generatePersistentId()}';
        }
      } else {
        // For desktop/other platforms, generate persistent ID
        deviceId = 'DESKTOP_${_generatePersistentId()}';
      }
    } catch (e) {
      debugLog('DeviceService', 'Error getting native device id: $e');
      // Generate persistent fallback ID
      deviceId = 'FA_${_generatePersistentId()}';
    }

    // Save device ID permanently
    debugLog('DeviceService', 'Saving persistent deviceId: $deviceId');
    await _prefs.setString(AppConstants.deviceIdKey, deviceId);

    return deviceId;
  }

  String _generatePersistentId() {
    // Generate a persistent ID based on machine info
    try {
      final machineId = Platform.localHostname.hashCode.abs().toString();
      final userName = Platform.environment['USER'] ??
          Platform.environment['USERNAME'] ??
          'unknown';
      final combined = '${machineId}_${userName}'.hashCode.abs().toString();
      return combined.substring(0, min(8, combined.length));
    } catch (e) {
      // Fallback to timestamp
      return DateTime.now().millisecondsSinceEpoch.toString().substring(8);
    }
  }

  Future<Map<String, dynamic>> getDeviceInfo() async {
    final deviceId = await getDeviceId();
    final Map<String, dynamic> info = {
      'device_id': deviceId,
      'platform': Platform.operatingSystem,
      'platform_version': Platform.operatingSystemVersion,
      'app_version': AppConstants.apiVersion,
    };

    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        info.addAll({
          'brand': androidInfo.brand,
          'model': androidInfo.model,
          'device': androidInfo.device,
          'product': androidInfo.product,
          'hardware': androidInfo.hardware,
          'android_version': androidInfo.version.release,
          'sdk_version': androidInfo.version.sdkInt,
          'is_physical_device': androidInfo.isPhysicalDevice,
        });
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        info.addAll({
          'name': iosInfo.name,
          'model': iosInfo.model,
          'system_name': iosInfo.systemName,
          'system_version': iosInfo.systemVersion,
          'is_physical_device': iosInfo.isPhysicalDevice,
          'utsname': {
            'sysname': iosInfo.utsname.sysname,
            'nodename': iosInfo.utsname.nodename,
            'release': iosInfo.utsname.release,
            'version': iosInfo.utsname.version,
            'machine': iosInfo.utsname.machine,
          },
        });
      }
    } catch (e) {
      debugLog('DeviceService', 'getDeviceInfo error: $e');
    }

    return info;
  }

  Future<bool> isTablet() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        // Check for tablet using model name or other indicators
        final model = androidInfo.model?.toLowerCase() ?? '';
        return model.contains('tab') ||
            model.contains('pad') ||
            model.contains('tablet');
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        // iOS devices have known models for tablets
        return iosInfo.model?.toLowerCase().contains('ipad') ?? false;
      }
    } catch (e) {
      debugLog('DeviceService', 'isTablet check error: $e');
    }
    return false;
  }

  Future<bool> isTV() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        // Check for TV features
        return androidInfo.systemFeatures?.contains(
              'android.software.leanback',
            ) ??
            false;
      }
    } catch (e) {
      debugLog('DeviceService', 'isTV check error: $e');
    }
    return false;
  }

  Future<void> saveTvDeviceId(String deviceId) async {
    debugLog('DeviceService', 'Saving TV device id: $deviceId');
    await _prefs.setString('tv_device_id', deviceId);
  }

  Future<String?> getTvDeviceId() async {
    final id = _prefs.getString('tv_device_id');
    debugLog('DeviceService', 'getTvDeviceId: $id');
    return id;
  }

  Future<void> clearTvDeviceId() async {
    debugLog('DeviceService', 'Clearing TV device id');
    await _prefs.remove('tv_device_id');
  }

  String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => chars.codeUnitAt(_getRandomInt(chars.length)),
      ),
    );
  }

  int _getRandomInt(int max) {
    return DateTime.now().microsecondsSinceEpoch % max;
  }
}

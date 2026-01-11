import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';

class ScreenProtectionService {
  static bool _isInitialized = false;

  /// Initialize screen protection for the entire app
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      if (Platform.isAndroid || Platform.isIOS) {
        await ScreenProtector.preventScreenshotOn();
      }
      _isInitialized = true;
      debugPrint("✅ Screen protection initialized");
    } catch (e) {
      debugPrint("❌ Failed to initialize screen protection: $e");
    }
  }

  /// Enable protection on app resume
  static Future<void> enableOnResume() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        await ScreenProtector.preventScreenshotOn();
      }
    } catch (e) {
      debugPrint("❌ Failed to enable protection on resume: $e");
    }
  }

  /// Disable protection on pause
  static Future<void> disableOnPause() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        await ScreenProtector.preventScreenshotOff();
      }
    } catch (e) {
      debugPrint("❌ Failed to disable protection on pause: $e");
    }
  }

  /// Disable all protection (use when app fully closed)
  static Future<void> disable() async {
    try {
      await ScreenProtector.preventScreenshotOff();
      WakelockPlus.disable();
    } catch (e) {
      debugPrint("❌ Failed to disable screen protection: $e");
    }
  }

  /// Protect videos (disable sleep and prevent capture)
  static Future<void> protectVideoPlayback() async {
    try {
      await ScreenProtector.protectDataLeakageOn();
      WakelockPlus.enable();
    } catch (e) {
      debugPrint("❌ Failed to protect video playback: $e");
    }
  }

  /// Restore normal protection after video
  static Future<void> restoreAfterVideo() async {
    try {
      await ScreenProtector.protectDataLeakageOff();
      WakelockPlus.disable();
    } catch (e) {
      debugPrint("❌ Failed to restore protection after video: $e");
    }
  }

  /// Check if screen recording is possible (Android 10+)
  static Future<bool> isScreenRecordingPossible() async {
    try {
      if (!Platform.isAndroid) return true;
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      return androidInfo.version.sdkInt < 29; // Android 10+
    } catch (e) {
      debugPrint("❌ Failed to check screen recording: $e");
      return true;
    }
  }
}

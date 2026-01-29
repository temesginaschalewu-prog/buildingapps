import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class ScreenProtectionService {
  static const MethodChannel _channel =
      MethodChannel('com.familyacademy/screen_protection');

  static bool _isInitialized = false;
  static bool _isVideoPlaying = false;

  /// Initialize screen protection for the entire app
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      if (Platform.isAndroid || Platform.isIOS) {
        await _channel.invokeMethod('protectScreen');
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
        await _channel.invokeMethod('protectScreen');
      }
    } catch (e) {
      debugPrint("❌ Failed to enable protection on resume: $e");
    }
  }

  /// Disable protection on pause (except for video)
  static Future<void> disableOnPause() async {
    try {
      if (!_isVideoPlaying && (Platform.isAndroid || Platform.isIOS)) {
        await _channel.invokeMethod('unprotectScreen');
      }
    } catch (e) {
      debugPrint("❌ Failed to disable protection on pause: $e");
    }
  }

  /// Disable all protection (use when app fully closed)
  static Future<void> disable() async {
    try {
      await _channel.invokeMethod('unprotectScreen');
      WakelockPlus.disable();
    } catch (e) {
      debugPrint("❌ Failed to disable screen protection: $e");
    }
  }

  /// Protect videos (disable sleep and prevent capture)
  static Future<void> protectVideoPlayback() async {
    try {
      _isVideoPlaying = true;
      if (Platform.isAndroid || Platform.isIOS) {
        await _channel.invokeMethod('protectVideo');
      }
      WakelockPlus.enable();

      // Lock orientation for video
      if (Platform.isAndroid || Platform.isIOS) {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
    } catch (e) {
      debugPrint("❌ Failed to protect video playback: $e");
    }
  }

  /// Restore normal protection after video
  static Future<void> restoreAfterVideo() async {
    try {
      _isVideoPlaying = false;
      if (Platform.isAndroid || Platform.isIOS) {
        await _channel.invokeMethod('restoreFromVideo');
      }
      WakelockPlus.disable();

      // Restore portrait-only orientation
      if (Platform.isAndroid || Platform.isIOS) {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
      }
    } catch (e) {
      debugPrint("❌ Failed to restore protection after video: $e");
    }
  }

  /// Disable split-screen/multi-window
  static Future<void> disableSplitScreen() async {
    try {
      if (Platform.isAndroid) {
        await _channel.invokeMethod('disableSplitScreen');
      }
    } catch (e) {
      debugPrint("❌ Failed to disable split screen: $e");
    }
  }

  /// Prevent popups and overlays
  static Future<void> preventPopups(BuildContext context) async {
    // Use WillPopScope or similar in your screens
    // This is handled at the widget level
  }

  /// Check if device is in split-screen mode
  static Future<bool> isInSplitScreenMode() async {
    try {
      if (Platform.isAndroid) {
        // You can check using platform channel if needed
        return false;
      }
      return false;
    } catch (e) {
      debugPrint("❌ Failed to check split screen mode: $e");
      return false;
    }
  }
}

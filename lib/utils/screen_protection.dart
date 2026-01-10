import 'dart:io';
import 'package:familyacademyclient/utils/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_protector/screen_protector.dart';

class ScreenProtectionService {
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    try {
      if (_isInitialized) return;

      if (Platform.isAndroid) {
        await ScreenProtector.preventScreenshotOn();

        await ScreenProtector.protectDataLeakageOn();

        debugLog(
            'ScreenProtection', 'Screen protection initialized successfully');
        _isInitialized = true;
      } else if (Platform.isIOS) {
        debugLog('ScreenProtection', 'Screen protection initialized for iOS');
        _isInitialized = true;
      }
    } catch (e) {
      debugLog(
          'ScreenProtection', 'Failed to initialize screen protection: $e');
    }
  }

  static Future<void> enableOnResume() async {
    try {
      if (Platform.isAndroid) {
        await ScreenProtector.preventScreenshotOn();
      }
    } catch (e) {
      debugLog('ScreenProtection', 'Failed to enable protection on resume: $e');
    }
  }

  static Future<void> disableOnPause() async {
    try {
      if (Platform.isAndroid) {
        await ScreenProtector.preventScreenshotOff();
      }
    } catch (e) {
      debugLog('ScreenProtection', 'Failed to disable protection on pause: $e');
    }
  }

  static Future<void> disable() async {
    try {
      if (Platform.isAndroid) {
        await ScreenProtector.preventScreenshotOff();
        await ScreenProtector.protectDataLeakageOff();
      }
    } catch (e) {
      debugLog('ScreenProtection', 'Failed to disable screen protection: $e');
    }
  }

  static Future<void> setSecureWindow() async {
    try {
      if (Platform.isAndroid) {
        await SystemChannels.textInput.invokeMethod('TextInput.hide');
      }
    } catch (e) {
      debugLog('ScreenProtection', 'Failed to set secure window: $e');
    }
  }
}

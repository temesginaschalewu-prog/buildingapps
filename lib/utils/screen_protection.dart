import 'package:familyacademyclient/utils/helpers.dart';
import 'package:flutter/material.dart';
import 'package:screen_protector/screen_protector.dart';

class ScreenProtectionService {
  static Future<void> initialize() async {
    try {
      await ScreenProtector.preventScreenshotOn();

      await ScreenProtector.protectDataLeakageOn();

      debugLog('ScreenProtection', 'Screen protection initialized');
    } catch (e) {
      debugLog(
          'ScreenProtection', 'Failed to initialize screen protection: $e');
    }
  }

  static Future<void> disable() async {
    try {
      await ScreenProtector.preventScreenshotOff();
      await ScreenProtector.protectDataLeakageOff();
    } catch (e) {
      debugLog('ScreenProtection', 'Failed to disable screen protection: $e');
    }
  }

  static Future<void> enableOnResume() async {
    try {
      await ScreenProtector.preventScreenshotOn();
    } catch (e) {
      debugLog('ScreenProtection', 'Failed to enable protection on resume: $e');
    }
  }

  static Future<void> disableOnPause() async {
    try {
      await ScreenProtector.preventScreenshotOff();
    } catch (e) {
      debugLog('ScreenProtection', 'Failed to disable protection on pause: $e');
    }
  }
}

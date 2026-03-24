// lib/providers/theme_provider.dart
// PRODUCTION-READY FINAL VERSION

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';
import '../utils/constants.dart';
import '../themes/app_themes.dart';
import '../services/connectivity_service.dart';
import 'base_provider.dart';

/// PRODUCTION-READY Theme Provider
class ThemeProvider extends ChangeNotifier with BaseProvider<ThemeProvider> {
  final ConnectivityService connectivityService;

  ThemeMode _themeMode = ThemeMode.light;

  // Hive box for theme preferences
  Box? _themeBox;

  final GlobalKey _rootKey = GlobalKey();

  // Use connectivity service as source of truth
  bool get _isOffline => !connectivityService.isOnline;

  ThemeProvider({required this.connectivityService}) {
    log('ThemeProvider constructor called');
    _init();
  }

  Future<void> _init() async {
    await _openHiveBox();
    await _loadTheme();
  }

  // Open Hive box
  Future<void> _openHiveBox() async {
    try {
      _themeBox = await Hive.openBox('theme_box');
      log('✅ Hive box opened');
    } catch (e) {
      log('⚠️ Error opening Hive box: $e');
    }
  }

  // ===== GETTERS =====
  ThemeMode get themeMode => _themeMode;
  ThemeData get lightTheme => AppThemes.lightTheme;
  ThemeData get darkTheme => AppThemes.darkTheme;
  @override
  bool get isOffline => _isOffline;
  GlobalKey get rootKey => _rootKey;

  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isLightMode => _themeMode == ThemeMode.light;

  // ===== LOAD THEME =====
  Future<void> _loadTheme() async {
    log('Loading saved theme');

    try {
      // STEP 1: Try Hive first
      if (_themeBox != null) {
        final savedTheme = _themeBox!.get('theme_mode');
        if (savedTheme != null) {
          _themeMode = savedTheme == 'dark' ? ThemeMode.dark : ThemeMode.light;
          setLoaded();
          log('Theme loaded from Hive: $_themeMode');
          return;
        }
      }

      // STEP 2: Fall back to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString(AppConstants.themeModeKey);

      if (savedTheme == 'dark') {
        _themeMode = ThemeMode.dark;
      } else if (savedTheme == 'light') {
        _themeMode = ThemeMode.light;
      } else {
        _themeMode = ThemeMode.light;
      }

      setLoaded();

      // Save to Hive for next time
      if (_themeBox != null) {
        await _themeBox!.put('theme_mode', savedTheme ?? 'light');
      }

      log('Theme loaded from Prefs: $_themeMode');
    } catch (e) {
      log('Error loading theme: $e');
      _themeMode = ThemeMode.light;
      setLoaded();
    } finally {
      // Notify after a short delay to ensure widgets are built
      Future.delayed(const Duration(milliseconds: 50), safeNotify);
    }
  }

  // ===== SET THEME =====
  Future<void> setTheme(ThemeMode themeMode) async {
    if (_themeMode == themeMode) return;

    _themeMode = themeMode;
    final themeString = themeMode == ThemeMode.dark ? 'dark' : 'light';

    // Save to Hive
    if (_themeBox != null) {
      await _themeBox!.put('theme_mode', themeString);
    }

    // Save to SharedPreferences as fallback
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.themeModeKey, themeString);

    log('Theme set to: $_themeMode');

    // Notify after a short delay to ensure smooth transition
    Future.delayed(const Duration(milliseconds: 50), safeNotify);
  }

  void toggleTheme() {
    setTheme(_themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }

  // ===== CLEAR USER DATA =====
  Future<void> clearUserData() async {
    log('Theme preferences preserved (device-specific)');
    // Theme is device-specific, not user-specific
    // No cache clearing needed

    // But we'll keep Hive data as it's device-specific
  }

  @override
  void dispose() {
    _themeBox?.close();
    super.dispose();
  }
}

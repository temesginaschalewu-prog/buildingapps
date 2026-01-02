import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../themes/app_themes.dart';

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  bool _isLoading = false;

  ThemeProvider() {
    _loadTheme();
  }

  ThemeMode get themeMode => _themeMode;
  ThemeData get lightTheme => AppThemes.lightTheme;
  ThemeData get darkTheme => AppThemes.darkTheme;

  Future<void> _loadTheme() async {
    _isLoading = true;
    debugLog('ThemeProvider', 'Loading saved theme');

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString(AppConstants.themeModeKey);

      if (savedTheme == 'dark') {
        _themeMode = ThemeMode.dark;
      } else if (savedTheme == 'light') {
        _themeMode = ThemeMode.light;
      } else {
        _themeMode = ThemeMode.system;
      }
    } catch (e) {
      debugLog('ThemeProvider', 'Error loading theme: $e');
      _themeMode = ThemeMode.system;
    } finally {
      _isLoading = false;
      debugLog('ThemeProvider', 'Theme loaded: $_themeMode');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  Future<void> setTheme(ThemeMode themeMode) async {
    if (_themeMode == themeMode) return;

    _themeMode = themeMode;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      AppConstants.themeModeKey,
      themeMode == ThemeMode.dark
          ? 'dark'
          : themeMode == ThemeMode.light
              ? 'light'
              : 'system',
    );

    debugLog('ThemeProvider', 'Theme set to: $_themeMode');
    notifyListeners();
  }

  void toggleTheme() {
    setTheme(_themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }
}

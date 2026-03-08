import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../themes/app_themes.dart';
import '../utils/helpers.dart';
import '../services/connectivity_service.dart';

class ThemeProvider with ChangeNotifier {
  final ConnectivityService connectivityService;

  ThemeMode _themeMode = ThemeMode.light;
  bool _isLoading = false;
  bool _hasLoaded = false;
  bool _isOffline = false;

  final GlobalKey _rootKey = GlobalKey();

  ThemeProvider({required this.connectivityService}) {
    _loadTheme();
    _setupConnectivityListener();
  }

  void _setupConnectivityListener() {
    connectivityService.onConnectivityChanged.listen((isOnline) {
      if (_isOffline != !isOnline) {
        _isOffline = !isOnline;
        notifyListeners();
      }
    });
  }

  ThemeMode get themeMode => _themeMode;
  ThemeData get lightTheme => AppThemes.lightTheme;
  ThemeData get darkTheme => AppThemes.darkTheme;
  bool get isLoading => _isLoading;
  bool get isOffline => _isOffline;
  GlobalKey get rootKey => _rootKey;

  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isLightMode => _themeMode == ThemeMode.light;

  Future<void> _loadTheme() async {
    if (_hasLoaded) return;

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
        _themeMode = ThemeMode.light;
      }

      _hasLoaded = true;
      debugLog('ThemeProvider', 'Theme loaded: $_themeMode');
    } catch (e) {
      debugLog('ThemeProvider', 'Error loading theme: $e');
      _themeMode = ThemeMode.light;
    } finally {
      _isLoading = false;

      Future.delayed(const Duration(milliseconds: 50), () {
        if (hasListeners) {
          notifyListeners();
        }
      });
    }
  }

  Future<void> setTheme(ThemeMode themeMode) async {
    if (_themeMode == themeMode) return;

    _themeMode = themeMode;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      AppConstants.themeModeKey,
      themeMode == ThemeMode.dark ? 'dark' : 'light',
    );

    debugLog('ThemeProvider', 'Theme set to: $_themeMode');

    Future.delayed(const Duration(milliseconds: 50), notifyListeners);
  }

  void toggleTheme() {
    setTheme(_themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }

  Future<void> clearUserData() async {
    debugLog('ThemeProvider', 'Theme preferences preserved (device-specific)');
    // Theme is device-specific, not user-specific
  }
}

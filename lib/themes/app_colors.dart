import 'package:flutter/material.dart';

class AppColors {
  // Telegram Dark Theme Colors
  static const Color telegramBlue = Color(0xFF2AABEE);
  static const Color telegramBlueLight = Color(0xFF3CB4EB);
  static const Color telegramBlueDark = Color(0xFF1E8BC4);
  static const Color telegramGreen = Color(0xFF34C759);
  static const Color telegramRed = Color(0xFFFF3B30);
  static const Color telegramYellow = Color(0xFFFFCC00);
  static const Color telegramGray = Color(0xFF8E8E93);

  // Background Colors
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF2F2F7);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightDivider = Color(0xFFC6C6C8);

  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkCard = Color(0xFF2C2C2E);
  static const Color darkDivider = Color(0xFF38383A);

  // Text Colors
  static const Color lightTextPrimary = Color(0xFF000000);
  static const Color lightTextSecondary = Color(0xFF8E8E93);
  static const Color lightTextTertiary = Color(0xFFC7C7CC);

  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFF8E8E93);
  static const Color darkTextTertiary = Color(0xFF48484A);

  // Semantic Colors
  static const Color success = telegramGreen;
  static const Color error = telegramRed;
  static const Color warning = telegramYellow;
  static const Color info = telegramBlue;

  // Status Colors
  static const Color statusActive = telegramGreen;
  static const Color statusPending = Color(0xFFFF9500);
  static const Color statusLocked = telegramRed;
  static const Color statusFree = telegramBlue;

  // Chat Colors
  static const Color chatBubbleUser = telegramBlue;
  static const Color chatBubbleBot = Color(0xFF3C3C43);
  static const Color chatBubbleUserLight = Color(0xFFE3F2FD);
  static const Color chatBubbleBotLight = Color(0xFFF2F2F7);

  // Gradient Colors
  static const List<Color> blueGradient = [
    Color(0xFF2AABEE),
    Color(0xFF229ED9),
  ];

  static const List<Color> purpleGradient = [
    Color(0xFFAF52DE),
    Color(0xFF8E44AD),
  ];

  static const List<Color> greenGradient = [
    Color(0xFF34C759),
    Color(0xFF2CAE4A),
  ];

  // Transparent Colors
  static const Color transparent = Colors.transparent;
  static const Color overlay = Color(0x52000000);
  static const Color shimmerBase = Color(0xFFE0E0E0);
  static const Color shimmerHighlight = Color(0xFFF5F5F5);

  // Navigation Colors
  static const Color bottomNavBar = Color(0xFFF8F8F8);
  static const Color bottomNavBarDark = Color(0xFF1C1C1E);

  // Search Bar Colors
  static const Color searchBar = Color(0xFFE9E9EB);
  static const Color searchBarDark = Color(0xFF2C2C2E);

  // Selection Colors
  static const Color selection = Color(0x1A007AFF);
  static const Color selectionDark = Color(0x1A0A84FF);

  // Get colors based on theme
  static Color getBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkBackground
        : lightBackground;
  }

  static Color getSurface(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkSurface
        : lightSurface;
  }

  static Color getCard(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkCard
        : lightCard;
  }

  static Color getTextPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkTextPrimary
        : lightTextPrimary;
  }

  static Color getTextSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkTextSecondary
        : lightTextSecondary;
  }

  // Get status color with proper context awareness
  static Color getStatusColor(String status, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (status.toLowerCase()) {
      case 'active':
      case 'verified':
      case 'subscribed':
      case 'completed':
        return success;
      case 'pending':
      case 'coming_soon':
      case 'in_progress':
        return isDark ? Color(0xFFFF9500) : Color(0xFFFF9500);
      case 'rejected':
      case 'locked':
      case 'expired':
      case 'cancelled':
        return error;
      case 'free':
        return telegramBlue;
      default:
        return isDark ? darkTextSecondary : lightTextSecondary;
    }
  }

  // Get status background color
  static Color getStatusBackground(String status, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (status.toLowerCase()) {
      case 'active':
      case 'verified':
      case 'subscribed':
        return isDark ? Color(0xFF1C3B2E) : Color(0xFFDCF7E6);
      case 'pending':
      case 'coming_soon':
        return isDark ? Color(0xFF3B2E1C) : Color(0xFFFFF3E0);
      case 'rejected':
      case 'locked':
        return isDark ? Color(0xFF3B1C1C) : Color(0xFFFFEBEE);
      case 'free':
        return isDark ? Color(0xFF1C2E3B) : Color(0xFFE3F2FD);
      default:
        return isDark ? darkSurface : lightSurface;
    }
  }
}

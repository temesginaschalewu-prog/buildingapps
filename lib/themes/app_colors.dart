import 'package:flutter/material.dart';

class AppColors {
  // Telegram Dark Theme Colors - Base
  static const Color telegramBlue = Color(0xFF2AABEE);
  static const Color telegramBlueLight = Color(0xFF3CB4EB);
  static const Color telegramBlueDark = Color(0xFF1E8BC4);
  static const Color telegramGreen = Color(0xFF34C759);
  static const Color telegramRed = Color(0xFFFF3B30);
  static const Color telegramYellow = Color(0xFFFFCC00);
  static const Color telegramOrange = Color(0xFFFF9500);
  static const Color telegramPurple = Color(0xFFAF52DE);
  static const Color telegramPink = Color(0xFFFF2D55);
  static const Color telegramTeal = Color(0xFF5AC8FA);
  static const Color telegramIndigo = Color(0xFF5856D6);
  static const Color telegramGray = Color(0xFF8E8E93);

  // ===== FADED/TRANSPARENT VARIATIONS =====
  // Blue variations (10%, 20%, 30% opacity)
  static const Color telegramBlueFaded = Color(0x1A2AABEE); // 10% opacity
  static const Color telegramBlueLightFaded = Color(0x1A3CB4EB); // 10% opacity
  static const Color telegramBlueExtraFaded = Color(0x0D2AABEE); // 5% opacity
  static const Color telegramBlueBackground = Color(0x0A2AABEE); // 4% opacity

  // Green variations
  static const Color telegramGreenFaded = Color(0x1A34C759); // 10% opacity
  static const Color telegramGreenLightFaded = Color(0x1A4CD964); // 10% opacity
  static const Color telegramGreenExtraFaded = Color(0x0D34C759); // 5% opacity
  static const Color telegramGreenBackground = Color(0x0A34C759); // 4% opacity

  // Yellow variations
  static const Color telegramYellowFaded = Color(0x1AFFCC00); // 10% opacity
  static const Color telegramYellowLightFaded =
      Color(0x1AFFD60A); // 10% opacity
  static const Color telegramYellowExtraFaded = Color(0x0DFFCC00); // 5% opacity
  static const Color telegramYellowBackground = Color(0x0AFFCC00); // 4% opacity

  // Red variations
  static const Color telegramRedFaded = Color(0x1AFF3B30); // 10% opacity
  static const Color telegramRedLightFaded = Color(0x1AFF453A); // 10% opacity
  static const Color telegramRedExtraFaded = Color(0x0DFF3B30); // 5% opacity
  static const Color telegramRedBackground = Color(0x0AFF3B30); // 4% opacity

  // Purple variations
  static const Color telegramPurpleFaded = Color(0x1AAF52DE); // 10% opacity
  static const Color telegramPurpleLightFaded =
      Color(0x1ABF5AF0); // 10% opacity
  static const Color telegramPurpleExtraFaded = Color(0x0DAF52DE); // 5% opacity
  static const Color telegramPurpleBackground = Color(0x0AAF52DE); // 4% opacity

  // Orange variations
  static const Color telegramOrangeFaded = Color(0x1AFF9500); // 10% opacity
  static const Color telegramOrangeLightFaded =
      Color(0x1AFF9F0A); // 10% opacity
  static const Color telegramOrangeExtraFaded = Color(0x0DFF9500); // 5% opacity
  static const Color telegramOrangeBackground = Color(0x0AFF9500); // 4% opacity

  // Pink variations
  static const Color telegramPinkFaded = Color(0x1AFF2D55); // 10% opacity
  static const Color telegramPinkLightFaded = Color(0x1AFF375F); // 10% opacity
  static const Color telegramPinkExtraFaded = Color(0x0DFF2D55); // 5% opacity
  static const Color telegramPinkBackground = Color(0x0AFF2D55); // 4% opacity

  // Teal variations
  static const Color telegramTealFaded = Color(0x1A5AC8FA); // 10% opacity
  static const Color telegramTealLightFaded = Color(0x1A64D2FF); // 10% opacity
  static const Color telegramTealExtraFaded = Color(0x0D5AC8FA); // 5% opacity
  static const Color telegramTealBackground = Color(0x0A5AC8FA); // 4% opacity

  // Indigo variations
  static const Color telegramIndigoFaded = Color(0x1A5856D6); // 10% opacity
  static const Color telegramIndigoLightFaded =
      Color(0x1A625EE0); // 10% opacity
  static const Color telegramIndigoExtraFaded = Color(0x0D5856D6); // 5% opacity
  static const Color telegramIndigoBackground = Color(0x0A5856D6); // 4% opacity

  // Gray variations
  static const Color telegramGrayFaded = Color(0x1A8E8E93); // 10% opacity
  static const Color telegramGrayLightFaded = Color(0x1A98989D); // 10% opacity
  static const Color telegramGrayExtraFaded = Color(0x0D8E8E93); // 5% opacity
  static const Color telegramGrayBackground = Color(0x0A8E8E93); // 4% opacity

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
  static const Color error = Color.fromARGB(255, 218, 91, 84);
  static const Color warning = telegramYellow;
  static const Color info = telegramBlue;

  // Status Colors
  static const Color statusActive = Color.fromARGB(255, 94, 200, 121);
  static const Color statusPending = Color(0xFFFF9500);
  static const Color statusLocked = Color.fromARGB(255, 141, 75, 72);
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

  static const List<Color> orangeGradient = [
    Color(0xFFFF9500),
    Color(0xFFFF8000),
  ];

  static const List<Color> pinkGradient = [
    Color(0xFFFF2D55),
    Color(0xFFE6204A),
  ];

  static const List<Color> tealGradient = [
    Color(0xFF5AC8FA),
    Color(0xFF4AB8EA),
  ];

  // Faded Gradients (for backgrounds)
  static const List<Color> blueFadedGradient = [
    Color(0x1A2AABEE),
    Color(0x0D2AABEE),
  ];

  static const List<Color> greenFadedGradient = [
    Color(0x1A34C759),
    Color(0x0D34C759),
  ];

  static const List<Color> yellowFadedGradient = [
    Color(0x1AFFCC00),
    Color(0x0DFFCC00),
  ];

  static const List<Color> redFadedGradient = [
    Color(0x1AFF3B30),
    Color(0x0DFF3B30),
  ];

  static const List<Color> purpleFadedGradient = [
    Color(0x1AAF52DE),
    Color(0x0DAF52DE),
  ];

  // Transparent Colors
  static const Color transparent = Colors.transparent;
  static const Color overlay = Color(0x52000000);
  static const Color overlayLight = Color(0x1A000000);
  static const Color overlayDark = Color(0x8A000000);
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

  // Get faded color by opacity
  static Color withOpacity(Color color, double opacity) {
    return color.withOpacity(opacity);
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
        return isDark ? telegramOrange : telegramOrange;
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

  // Get status background color (faded)
  static Color getStatusBackground(String status, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (status.toLowerCase()) {
      case 'active':
      case 'verified':
      case 'subscribed':
        return isDark ? telegramGreenExtraFaded : telegramGreenBackground;
      case 'pending':
      case 'coming_soon':
        return isDark ? telegramOrangeExtraFaded : telegramOrangeBackground;
      case 'rejected':
      case 'locked':
        return isDark ? telegramRedExtraFaded : telegramRedBackground;
      case 'free':
        return isDark ? telegramBlueExtraFaded : telegramBlueBackground;
      default:
        return isDark ? darkSurface : lightSurface;
    }
  }

  // Get faded version of any color
  static Color getFaded(Color color, {double opacity = 0.1}) {
    return color.withOpacity(opacity);
  }

  // Predefined faded colors for common use cases
  static Color get blueFaded => telegramBlueFaded;
  static Color get greenFaded => telegramGreenFaded;
  static Color get yellowFaded => telegramYellowFaded;
  static Color get redFaded => telegramRedFaded;
  static Color get purpleFaded => telegramPurpleFaded;
  static Color get orangeFaded => telegramOrangeFaded;
  static Color get pinkFaded => telegramPinkFaded;
  static Color get tealFaded => telegramTealFaded;
  static Color get indigoFaded => telegramIndigoFaded;
  static Color get grayFaded => telegramGrayFaded;

  // Extra faded (5% opacity)
  static Color get blueExtraFaded => telegramBlueExtraFaded;
  static Color get greenExtraFaded => telegramGreenExtraFaded;
  static Color get yellowExtraFaded => telegramYellowExtraFaded;
  static Color get redExtraFaded => telegramRedExtraFaded;
  static Color get purpleExtraFaded => telegramPurpleExtraFaded;
  static Color get orangeExtraFaded => telegramOrangeExtraFaded;
  static Color get pinkExtraFaded => telegramPinkExtraFaded;
  static Color get tealExtraFaded => telegramTealExtraFaded;
  static Color get indigoExtraFaded => telegramIndigoExtraFaded;
  static Color get grayExtraFaded => telegramGrayExtraFaded;

  // Background (4% opacity)
  static Color get blueBackground => telegramBlueBackground;
  static Color get greenBackground => telegramGreenBackground;
  static Color get yellowBackground => telegramYellowBackground;
  static Color get redBackground => telegramRedBackground;
  static Color get purpleBackground => telegramPurpleBackground;
  static Color get orangeBackground => telegramOrangeBackground;
  static Color get pinkBackground => telegramPinkBackground;
  static Color get tealBackground => telegramTealBackground;
  static Color get indigoBackground => telegramIndigoBackground;
  static Color get grayBackground => telegramGrayBackground;
}

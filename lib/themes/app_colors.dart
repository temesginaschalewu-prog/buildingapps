import 'package:flutter/material.dart';

class AppColors {
  static const Color telegramBlue = Color(0xFF2469F0);
  static const Color telegramBlueLight = Color(0xFF3B82F6);
  static const Color telegramBlueDark = Color(0xFF1A4FC2);

  static const Color telegramGreen = Color(0xFF10B981);
  static const Color telegramRed = Color(0xFFEF4444);
  static const Color telegramYellow = Color(0xFFF59E0B);
  static const Color telegramOrange = Color(0xFFF97316);
  static const Color telegramPurple = Color(0xFF8B5CF6);
  static const Color telegramPink = Color(0xFFEC4899);
  static const Color telegramTeal = Color(0xFF14B8A6);
  static const Color telegramIndigo = Color(0xFF6366F1);
  static const Color telegramGray = Color(0xFF6B7280);

  static const Color telegramBlueFaded = Color(0x1A2469F0);
  static const Color telegramGreenFaded = Color(0x1A10B981);
  static const Color telegramRedFaded = Color(0x1AEF4444);
  static const Color telegramYellowFaded = Color(0x1AF59E0B);
  static const Color telegramOrangeFaded = Color(0x1AF97316);
  static const Color telegramPurpleFaded = Color(0x1A8B5CF6);
  static const Color telegramPinkFaded = Color(0x1AEC4899);
  static const Color telegramTealFaded = Color(0x1A14B8A6);
  static const Color telegramIndigoFaded = Color(0x1A6366F1);
  static const Color telegramGrayFaded = Color(0x1A6B7280);

  static const Color telegramBlueBackground = Color(0x0A2469F0);
  static const Color telegramGreenBackground = Color(0x0A10B981);
  static const Color telegramRedBackground = Color(0x0AEF4444);
  static const Color telegramYellowBackground = Color(0x0AF59E0B);
  static const Color telegramOrangeBackground = Color(0x0AF97316);
  static const Color telegramPurpleBackground = Color(0x0A8B5CF6);
  static const Color telegramPinkBackground = Color(0x0AEC4899);
  static const Color telegramTealBackground = Color(0x0A14B8A6);
  static const Color telegramIndigoBackground = Color(0x0A6366F1);
  static const Color telegramGrayBackground = Color(0x0A6B7280);

  static const Color success = telegramGreen;
  static const Color error = telegramRed;
  static const Color warning = telegramYellow;
  static const Color info = telegramBlue;
  static const Color pending = telegramOrange;
  static const Color active = telegramGreen;
  static const Color locked = telegramGray;
  static const Color free = telegramBlue;

  static const List<Color> blueGradient = [telegramBlue, telegramBlueLight];
  static const List<Color> purpleGradient = [telegramPurple, Color(0xFFA78BFA)];
  static const List<Color> greenGradient = [telegramGreen, Color(0xFF34D399)];
  static const List<Color> orangeGradient = [telegramOrange, Color(0xFFFB923C)];
  static const List<Color> pinkGradient = [telegramPink, Color(0xFFF472B6)];
  static const List<Color> tealGradient = [telegramTeal, Color(0xFF2DD4BF)];
  static const List<Color> telegramGradient = [
    Color(0xFF2AABEE),
    Color(0xFF5856D6)
  ];
  static const List<Color> dangerGradient = [
    Color(0xFFFF3B30),
    Color(0xFFE6204A)
  ];
  static const List<Color> successGradient = [
    Color(0xFF34C759),
    Color(0xFF2CAE4A)
  ];
  static const List<Color> warningGradient = [
    Color(0xFFFF9F0A),
    Color(0xFFFF6B0F)
  ];
  static const List<Color> infoGradient = [
    Color(0xFF5AC8FA),
    Color(0xFF007AFF)
  ];

  static const Color lightBackground = Color(0xFFF8FAFF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightCardAlt = Color(0xFFF1F5F9);
  static const Color lightDivider = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0B1E33);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextTertiary = Color(0xFF94A3B8);
  static const Color lightBottomNavBar = Color(0xFFFFFFFF);
  static const Color lightSearchBar = Color(0xFFF1F5F9);

  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkCard = Color(0xFF2D3A4F);
  static const Color darkDivider = Color(0xFF334155);
  static const Color darkTextPrimary = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextTertiary = Color(0xFF64748B);
  static const Color darkBottomNavBar = Color(0xFF1E293B);
  static const Color darkSearchBar = Color(0xFF2D3A4F);

  static const Color chatBubbleUser = telegramBlue;
  static const Color chatBubbleBot = Color(0xFF1E293B);
  static const Color chatBubbleUserLight = Color(0xFFEFF6FF);
  static const Color chatBubbleBotLight = Color(0xFFF1F5F9);

  static const Color shimmerBase = Color(0xFFE2E8F0);
  static const Color shimmerHighlight = Color(0xFFF1F5F9);

  static const Color transparent = Colors.transparent;
  static const Color overlay = Color(0x8A000000);
  static const Color overlayLight = Color(0x1A000000);
  static const Color overlayDark = Color(0xCC000000);

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

  static Color getTextTertiary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkTextTertiary
        : lightTextTertiary;
  }

  static Color getDivider(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkDivider
        : lightDivider;
  }

  static Color getBottomNavBar(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkBottomNavBar
        : lightBottomNavBar;
  }

  static Color getSearchBar(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkSearchBar
        : lightSearchBar;
  }

  static Color get blueFaded => telegramBlueFaded;
  static Color get greenFaded => telegramGreenFaded;
  static Color get redFaded => telegramRedFaded;
  static Color get yellowFaded => telegramYellowFaded;
  static Color get orangeFaded => telegramOrangeFaded;
  static Color get purpleFaded => telegramPurpleFaded;
  static Color get pinkFaded => telegramPinkFaded;
  static Color get tealFaded => telegramTealFaded;
  static Color get indigoFaded => telegramIndigoFaded;
  static Color get grayFaded => telegramGrayFaded;

  static Color get blueBackground => telegramBlueBackground;
  static Color get greenBackground => telegramGreenBackground;
  static Color get redBackground => telegramRedBackground;
  static Color get yellowBackground => telegramYellowBackground;
  static Color get orangeBackground => telegramOrangeBackground;
  static Color get purpleBackground => telegramPurpleBackground;
  static Color get pinkBackground => telegramPinkBackground;
  static Color get tealBackground => telegramTealBackground;
  static Color get indigoBackground => telegramIndigoBackground;
  static Color get grayBackground => telegramGrayBackground;

  static Color getStatusColor(String status, BuildContext context) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'verified':
      case 'subscribed':
      case 'completed':
      case 'passed':
        return success;
      case 'pending':
      case 'coming_soon':
      case 'in_progress':
        return pending;
      case 'rejected':
      case 'locked':
      case 'expired':
      case 'cancelled':
      case 'failed':
        return error;
      case 'free':
        return free;
      default:
        return getTextSecondary(context);
    }
  }

  static Color getStatusBackground(String status, BuildContext context) {
    final color = getStatusColor(status, context);
    return color.withValues(alpha: 0.1);
  }

  static List<Color> getStatusGradient(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'verified':
      case 'subscribed':
      case 'completed':
      case 'passed':
        return successGradient;
      case 'pending':
      case 'coming_soon':
      case 'in_progress':
        return warningGradient;
      case 'rejected':
      case 'locked':
      case 'expired':
      case 'cancelled':
      case 'failed':
        return dangerGradient;
      case 'free':
        return blueGradient;
      default:
        return infoGradient;
    }
  }

  static Color withOpacity(Color color, double opacity) {
    return color.withValues(alpha: opacity);
  }

  static Color getFaded(Color color, {double opacity = 0.1}) {
    return color.withValues(alpha: opacity);
  }
}

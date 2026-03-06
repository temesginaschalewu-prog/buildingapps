import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

class AppThemes {
  static const Duration animationFast = Duration(milliseconds: 150);
  static const Duration animationMedium = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);
  static const Duration animationPage = Duration(milliseconds: 350);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: AppColors.telegramBlue,
        primaryContainer: AppColors.telegramBlueLight,
        secondary: AppColors.telegramGreen,
        secondaryContainer: Color(0x1A10B981),
        surface: AppColors.lightSurface,
        surfaceContainerHighest: AppColors.lightCardAlt,
        error: AppColors.telegramRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        outline: AppColors.lightDivider,
        outlineVariant: AppColors.lightCardAlt,
      ),
      scaffoldBackgroundColor: AppColors.lightBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.lightBackground,
        foregroundColor: AppColors.lightTextPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.lightTextPrimary,
        ),
        iconTheme: const IconThemeData(
          color: AppColors.lightTextPrimary,
          size: 24,
        ),
        toolbarHeight: 56,
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.lightBottomNavBar,
        selectedItemColor: AppColors.telegramBlue,
        unselectedItemColor: AppColors.lightTextSecondary,
        elevation: 3,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightCard,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: AppColors.lightDivider.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.telegramBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              AppColors.telegramBlue.withValues(alpha: 0.1),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          minimumSize: const Size(64, 44),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.telegramBlue,
          backgroundColor: Colors.transparent,
          side: const BorderSide(color: AppColors.telegramBlue),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          minimumSize: const Size(64, 44),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.telegramBlue,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          minimumSize: const Size(48, 36),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightCardAlt,
        hintStyle: TextStyle(
          fontSize: 14,
          color: AppColors.lightTextSecondary.withValues(alpha: 0.7),
        ),
        labelStyle: const TextStyle(fontSize: 14),
        floatingLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.telegramBlue,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.telegramBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.telegramRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.telegramRed, width: 2),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.lightCard,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.lightTextPrimary,
        ),
        contentTextStyle: TextStyle(
          fontSize: 14,
          color: AppColors.lightTextSecondary,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.darkCard,
        contentTextStyle: TextStyle(
          fontSize: 14,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        elevation: 3,
        behavior: SnackBarBehavior.floating,
        insetPadding: EdgeInsets.all(16),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.telegramBlue,
        linearTrackColor: AppColors.lightCardAlt,
        circularTrackColor: AppColors.lightCardAlt,
        linearMinHeight: 2,
      ),
      iconTheme: const IconThemeData(
        color: AppColors.lightTextSecondary,
        size: 24,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.lightDivider,
        thickness: 0.5,
        space: 0,
      ),
      listTileTheme: const ListTileThemeData(
        tileColor: Colors.transparent,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        minVerticalPadding: 0,
        iconColor: AppColors.lightTextSecondary,
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.lightTextPrimary,
        ),
        subtitleTextStyle: TextStyle(
          fontSize: 14,
          color: AppColors.lightTextSecondary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.telegramBlue,
        foregroundColor: Colors.white,
        shape: CircleBorder(),
        elevation: 3,
        sizeConstraints: BoxConstraints.tightFor(
          width: 56,
          height: 56,
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: AppColors.lightCardAlt,
        selectedColor: AppColors.telegramBlue,
        disabledColor: AppColors.lightCardAlt,
        labelStyle: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.lightTextSecondary,
        ),
        secondaryLabelStyle: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(999)),
        ),
        side: BorderSide.none,
        brightness: Brightness.light,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.telegramBlueLight,
        primaryContainer: AppColors.telegramBlueDark,
        secondary: AppColors.telegramGreen,
        secondaryContainer: Color(0x1A10B981),
        surface: AppColors.darkSurface,
        surfaceContainerHighest: AppColors.darkCard,
        error: AppColors.telegramRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        outline: AppColors.darkDivider,
        outlineVariant: AppColors.darkDivider,
      ),
      scaffoldBackgroundColor: AppColors.darkBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkBackground,
        foregroundColor: AppColors.darkTextPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.darkTextPrimary,
        ),
        iconTheme: IconThemeData(
          color: AppColors.darkTextPrimary,
          size: 24,
        ),
        toolbarHeight: 56,
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkBottomNavBar,
        selectedItemColor: AppColors.telegramBlueLight,
        unselectedItemColor: AppColors.darkTextSecondary,
        elevation: 3,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: AppColors.darkDivider.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.telegramBlueLight,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              AppColors.telegramBlueLight.withValues(alpha: 0.1),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          minimumSize: const Size(64, 44),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.telegramBlueLight,
          backgroundColor: Colors.transparent,
          side: const BorderSide(color: AppColors.telegramBlueLight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          minimumSize: const Size(64, 44),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.telegramBlueLight,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          minimumSize: const Size(48, 36),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface,
        hintStyle: TextStyle(
          fontSize: 14,
          color: AppColors.darkTextSecondary.withValues(alpha: 0.7),
        ),
        labelStyle: const TextStyle(fontSize: 14),
        floatingLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.telegramBlueLight,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.telegramBlueLight, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.telegramRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.telegramRed, width: 2),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.darkCard,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.darkTextPrimary,
        ),
        contentTextStyle: TextStyle(
          fontSize: 14,
          color: AppColors.darkTextSecondary,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.darkCard,
        contentTextStyle: TextStyle(
          fontSize: 14,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        elevation: 3,
        behavior: SnackBarBehavior.floating,
        insetPadding: EdgeInsets.all(16),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.telegramBlueLight,
        linearTrackColor: AppColors.darkDivider,
        circularTrackColor: AppColors.darkDivider,
        linearMinHeight: 2,
      ),
      iconTheme: const IconThemeData(
        color: AppColors.darkTextSecondary,
        size: 24,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkDivider,
        thickness: 0.5,
        space: 0,
      ),
      listTileTheme: const ListTileThemeData(
        tileColor: Colors.transparent,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        minVerticalPadding: 0,
        iconColor: AppColors.darkTextSecondary,
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.darkTextPrimary,
        ),
        subtitleTextStyle: TextStyle(
          fontSize: 14,
          color: AppColors.darkTextSecondary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.telegramBlueLight,
        foregroundColor: Colors.white,
        shape: CircleBorder(),
        elevation: 3,
        sizeConstraints: BoxConstraints.tightFor(
          width: 56,
          height: 56,
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: AppColors.darkSurface,
        selectedColor: AppColors.telegramBlueLight,
        disabledColor: AppColors.darkDivider,
        labelStyle: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.darkTextSecondary,
        ),
        secondaryLabelStyle: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(999)),
        ),
        side: BorderSide.none,
        brightness: Brightness.dark,
      ),
    );
  }

  static List<Effect<dynamic>> get fadeInSlideUp => [
        FadeEffect(duration: animationMedium),
        SlideEffect(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
          duration: animationMedium,
        ),
      ];

  static List<Effect<dynamic>> get scaleIn => [
        ScaleEffect(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1, 1),
          duration: animationMedium,
        ),
        FadeEffect(duration: animationMedium),
      ];
}

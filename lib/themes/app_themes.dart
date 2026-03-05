import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import 'app_colors.dart';

class AppThemes {
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 12.0;
  static const double spacingL = 16.0;
  static const double spacingXL = 20.0;
  static const double spacingXXL = 24.0;
  static const double spacingXXXL = 32.0;
  static const double spacingXXXXL = 48.0;

  static const double borderRadiusSmall = 6.0;
  static const double borderRadiusMedium = 12.0;
  static const double borderRadiusLarge = 18.0;
  static const double borderRadiusXLarge = 24.0;
  static const double borderRadiusXXLarge = 32.0;
  static const double borderRadiusFull = 999.0;

  static const double elevationNone = 0.0;
  static const double elevationLow = 1.0;
  static const double elevationMedium = 3.0;
  static const double elevationHigh = 6.0;

  static const double iconSizeXS = 16.0;
  static const double iconSizeS = 20.0;
  static const double iconSizeM = 24.0;
  static const double iconSizeL = 28.0;
  static const double iconSizeXL = 32.0;

  static const double appBarHeight = 56.0;
  static const double bottomNavBarHeight = 60.0;
  static const double fabSize = 56.0;
  static const double buttonHeightSmall = 36.0;
  static const double buttonHeightMedium = 44.0;
  static const double buttonHeightLarge = 52.0;

  static const Duration animationDurationFast = Duration(milliseconds: 150);
  static const Duration animationDurationMedium = Duration(milliseconds: 300);
  static const Duration animationDurationSlow = Duration(milliseconds: 500);
  static const Duration animationDurationPage = Duration(milliseconds: 350);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: AppColors.telegramBlue,
        primaryContainer: AppColors.telegramBlueLight,
        secondary: AppColors.telegramGreen,
        secondaryContainer: AppColors.telegramGreenFaded,
        surfaceContainerHighest: AppColors.lightAccent3,
        error: AppColors.telegramRed,
        onSecondary: Colors.white,
        outline: AppColors.lightDivider,
        outlineVariant: AppColors.lightAccent3,
      ),
      scaffoldBackgroundColor: AppColors.lightBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightBackground,
        foregroundColor: AppColors.lightTextPrimary,
        elevation: elevationNone,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.lightTextPrimary,
        ),
        iconTheme: IconThemeData(
          color: AppColors.lightTextPrimary,
          size: iconSizeM,
        ),
        toolbarHeight: appBarHeight,
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.bottomNavBar,
        selectedItemColor: AppColors.telegramBlue,
        unselectedItemColor: AppColors.lightTextSecondary,
        elevation: elevationMedium,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: AppColors.telegramBlue,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: AppColors.lightTextSecondary,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightCard,
        elevation: elevationLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusMedium),
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
          disabledBackgroundColor: AppColors.telegramBlueFaded,
          elevation: elevationNone,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadiusMedium),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: spacingXL,
            vertical: spacingM,
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          minimumSize: const Size(64, buttonHeightMedium),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.telegramBlue,
          backgroundColor: Colors.transparent,
          side: const BorderSide(color: AppColors.telegramBlue),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadiusMedium),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: spacingXL,
            vertical: spacingM,
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.telegramBlue,
          ),
          minimumSize: const Size(64, buttonHeightMedium),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.telegramBlue,
          padding: const EdgeInsets.symmetric(
            horizontal: spacingM,
            vertical: spacingS,
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.telegramBlue,
          ),
          minimumSize: const Size(48, buttonHeightSmall),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightAccent2,
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacingL,
          vertical: spacingM,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusMedium),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusMedium),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusMedium),
          borderSide: const BorderSide(
            color: AppColors.telegramBlue,
            width: 2.0,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusMedium),
          borderSide: const BorderSide(
            color: AppColors.telegramRed,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusMedium),
          borderSide: const BorderSide(
            color: AppColors.telegramRed,
            width: 2.0,
          ),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.lightCard,
        elevation: elevationHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(borderRadiusLarge)),
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
          borderRadius: BorderRadius.all(Radius.circular(borderRadiusMedium)),
        ),
        elevation: elevationMedium,
        behavior: SnackBarBehavior.floating,
        insetPadding: EdgeInsets.all(spacingL),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.telegramBlue,
        linearTrackColor: AppColors.lightAccent3,
        circularTrackColor: AppColors.lightAccent3,
        linearMinHeight: 2.0,
      ),
      iconTheme: const IconThemeData(
        color: AppColors.lightTextSecondary,
        size: iconSizeM,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.lightDivider,
        thickness: 0.5,
        space: 0,
      ),
      listTileTheme: const ListTileThemeData(
        tileColor: Colors.transparent,
        contentPadding: EdgeInsets.symmetric(
          horizontal: spacingL,
          vertical: spacingS,
        ),
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
          borderRadius: BorderRadius.all(Radius.circular(borderRadiusMedium)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.telegramBlue,
        foregroundColor: Colors.white,
        shape: CircleBorder(),
        elevation: elevationMedium,
        sizeConstraints: BoxConstraints.tightFor(
          width: fabSize,
          height: fabSize,
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: AppColors.lightAccent2,
        selectedColor: AppColors.telegramBlue,
        disabledColor: AppColors.lightAccent3,
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
        padding: EdgeInsets.symmetric(
          horizontal: spacingM,
          vertical: spacingXS,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(borderRadiusFull)),
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
        secondaryContainer: AppColors.telegramGreenFaded,
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
        elevation: elevationNone,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.darkTextPrimary,
        ),
        iconTheme: IconThemeData(
          color: AppColors.darkTextPrimary,
          size: iconSizeM,
        ),
        toolbarHeight: appBarHeight,
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.bottomNavBarDark,
        selectedItemColor: AppColors.telegramBlueLight,
        unselectedItemColor: AppColors.darkTextSecondary,
        elevation: elevationMedium,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: AppColors.telegramBlueLight,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: AppColors.darkTextSecondary,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: elevationLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusMedium),
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
          disabledBackgroundColor: AppColors.telegramBlueLightFaded,
          elevation: elevationNone,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadiusMedium),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: spacingXL,
            vertical: spacingM,
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          minimumSize: const Size(64, buttonHeightMedium),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.telegramBlueLight,
          backgroundColor: Colors.transparent,
          side: const BorderSide(color: AppColors.telegramBlueLight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadiusMedium),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: spacingXL,
            vertical: spacingM,
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.telegramBlueLight,
          ),
          minimumSize: const Size(64, buttonHeightMedium),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.telegramBlueLight,
          padding: const EdgeInsets.symmetric(
            horizontal: spacingM,
            vertical: spacingS,
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.telegramBlueLight,
          ),
          minimumSize: const Size(48, buttonHeightSmall),
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacingL,
          vertical: spacingM,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusMedium),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusMedium),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusMedium),
          borderSide: const BorderSide(
            color: AppColors.telegramBlueLight,
            width: 2.0,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusMedium),
          borderSide: const BorderSide(
            color: AppColors.telegramRed,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadiusMedium),
          borderSide: const BorderSide(
            color: AppColors.telegramRed,
            width: 2.0,
          ),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.darkCard,
        elevation: elevationHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(borderRadiusLarge)),
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
          borderRadius: BorderRadius.all(Radius.circular(borderRadiusMedium)),
        ),
        elevation: elevationMedium,
        behavior: SnackBarBehavior.floating,
        insetPadding: EdgeInsets.all(spacingL),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.telegramBlueLight,
        linearTrackColor: AppColors.darkDivider,
        circularTrackColor: AppColors.darkDivider,
        linearMinHeight: 2.0,
      ),
      iconTheme: const IconThemeData(
        color: AppColors.darkTextSecondary,
        size: iconSizeM,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkDivider,
        thickness: 0.5,
        space: 0,
      ),
      listTileTheme: const ListTileThemeData(
        tileColor: Colors.transparent,
        contentPadding: EdgeInsets.symmetric(
          horizontal: spacingL,
          vertical: spacingS,
        ),
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
          borderRadius: BorderRadius.all(Radius.circular(borderRadiusMedium)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.telegramBlueLight,
        foregroundColor: Colors.white,
        shape: CircleBorder(),
        elevation: elevationMedium,
        sizeConstraints: BoxConstraints.tightFor(
          width: fabSize,
          height: fabSize,
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
        padding: EdgeInsets.symmetric(
          horizontal: spacingM,
          vertical: spacingXS,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(borderRadiusFull)),
        ),
        side: BorderSide.none,
        brightness: Brightness.dark,
      ),
    );
  }

  static BoxDecoration cardDecoration(BuildContext context) {
    return BoxDecoration(
      color: AppColors.getCard(context),
      borderRadius: BorderRadius.circular(borderRadiusMedium),
      border: Theme.of(context).brightness == Brightness.dark
          ? Border.all(color: AppColors.darkDivider, width: 0.5)
          : Border.all(color: AppColors.lightDivider, width: 0.5),
      boxShadow: Theme.of(context).brightness == Brightness.dark
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8.0,
                offset: const Offset(0, 2),
              ),
            ]
          : [
              BoxShadow(
                color: AppColors.telegramBlue.withValues(alpha: 0.08),
                blurRadius: 8.0,
                offset: const Offset(0, 2),
              ),
            ],
    );
  }

  static BoxDecoration floatingCardDecoration(BuildContext context) {
    return BoxDecoration(
      color: AppColors.getCard(context),
      borderRadius: BorderRadius.circular(borderRadiusLarge),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.15),
          blurRadius: 16.0,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  static BoxDecoration statusDecoration(String status, BuildContext context) {
    return BoxDecoration(
      color: AppColors.getStatusBackground(status, context),
      borderRadius: BorderRadius.circular(borderRadiusFull),
      border: Border.all(
        color: AppColors.getStatusColor(status, context),
      ),
    );
  }

  static List<Effect<dynamic>> get fadeInSlideUp => [
        const FadeEffect(duration: animationDurationMedium),
        const SlideEffect(
          begin: Offset(0, 0.1),
          end: Offset.zero,
          duration: animationDurationMedium,
        ),
      ];

  static List<Effect<dynamic>> get scaleIn => [
        const ScaleEffect(
          begin: Offset(0.95, 0.95),
          end: Offset(1, 1),
          duration: animationDurationMedium,
        ),
        const FadeEffect(duration: animationDurationMedium),
      ];

  static Widget shimmerLoading({
    required double width,
    required double height,
    double borderRadius = borderRadiusMedium,
    EdgeInsetsGeometry? margin,
    Color? baseColor,
    Color? highlightColor,
  }) {
    return Shimmer.fromColors(
      baseColor: baseColor ?? AppColors.shimmerBase,
      highlightColor: highlightColor ?? AppColors.shimmerHighlight,
      period: const Duration(seconds: 1),
      child: Container(
        width: width,
        height: height,
        margin: margin,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }

  static EdgeInsetsGeometry responsivePadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth >= 1024) {
      return const EdgeInsets.symmetric(
        horizontal: spacingXXXL,
        vertical: spacingXL,
      );
    } else if (screenWidth >= 600) {
      return const EdgeInsets.symmetric(
        horizontal: spacingXXL,
        vertical: spacingL,
      );
    } else {
      return const EdgeInsets.symmetric(
        horizontal: spacingL,
        vertical: spacingM,
      );
    }
  }

  static BoxDecoration chatBubbleDecoration(bool isUser, BuildContext context) {
    return BoxDecoration(
      color: isUser ? AppColors.chatBubbleUser : AppColors.chatBubbleBot,
      borderRadius: BorderRadius.only(
        topLeft: const Radius.circular(borderRadiusLarge),
        topRight: const Radius.circular(borderRadiusLarge),
        bottomLeft: isUser
            ? const Radius.circular(borderRadiusLarge)
            : const Radius.circular(borderRadiusSmall),
        bottomRight: isUser
            ? const Radius.circular(borderRadiusSmall)
            : const Radius.circular(borderRadiusLarge),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 4.0,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
}

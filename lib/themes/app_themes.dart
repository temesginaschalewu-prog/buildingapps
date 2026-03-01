import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

class AppThemes {
  // Spacing
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 12.0;
  static const double spacingL = 16.0;
  static const double spacingXL = 20.0;
  static const double spacingXXL = 24.0;
  static const double spacingXXXL = 32.0;

  // Border Radius
  static const double borderRadiusSmall = 6.0;
  static const double borderRadiusMedium = 12.0;
  static const double borderRadiusLarge = 18.0;
  static const double borderRadiusXLarge = 24.0;
  static const double borderRadiusFull = 999.0;

  // Elevation
  static const double elevationNone = 0.0;
  static const double elevationLow = 1.0;
  static const double elevationMedium = 3.0;
  static const double elevationHigh = 6.0;

  // Icon Sizes
  static const double iconSizeXS = 16.0;
  static const double iconSizeS = 20.0;
  static const double iconSizeM = 24.0;
  static const double iconSizeL = 28.0;
  static const double iconSizeXL = 32.0;

  // Component Sizes
  static const double appBarHeight = 56.0;
  static const double bottomNavBarHeight = 60.0;
  static const double fabSize = 56.0;
  static const double buttonHeightSmall = 36.0;
  static const double buttonHeightMedium = 44.0;
  static const double buttonHeightLarge = 52.0;

  // Animation Durations
  static const Duration animationDurationFast = Duration(milliseconds: 150);
  static const Duration animationDurationMedium = Duration(milliseconds: 300);
  static const Duration animationDurationSlow = Duration(milliseconds: 500);
  static const Duration animationDurationPage = Duration(milliseconds: 350);

  // Telegram Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: AppColors.telegramBlue,
        primaryContainer: AppColors.telegramBlueLight,
        secondary: AppColors.telegramGreen,
        secondaryContainer: AppColors.telegramGreen.withValues(alpha: 0.1),
        surface: AppColors.lightSurface,
        surfaceContainerHighest: const Color(0xFFE5E5EA),
        error: AppColors.telegramRed,
        onSecondary: Colors.white,
        outline: AppColors.lightDivider,
        outlineVariant: const Color(0xFFE5E5EA),
      ),

      // Scaffold & App Bar
      scaffoldBackgroundColor: AppColors.lightBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.lightBackground,
        foregroundColor: AppColors.lightTextPrimary,
        elevation: elevationNone,
        centerTitle: false,
        titleTextStyle: AppTextStyles.appBarTitle.copyWith(
          color: AppColors.lightTextPrimary,
        ),
        iconTheme: const IconThemeData(
          color: AppColors.lightTextPrimary,
          size: iconSizeM,
        ),
        toolbarHeight: appBarHeight,
        surfaceTintColor: Colors.transparent,
      ),

      // Bottom Navigation Bar
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
          height: 1.2,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          height: 1.2,
        ),
      ),

      // Cards
      cardTheme: const CardThemeData(
        color: AppColors.lightCard,
        elevation: elevationLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(borderRadiusMedium)),
        ),
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.telegramBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.telegramBlue.withValues(alpha: 0.5),
          elevation: elevationNone,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadiusMedium),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: spacingXL,
            vertical: spacingM,
          ),
          textStyle: AppTextStyles.buttonMedium,
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
          textStyle: AppTextStyles.buttonMedium.copyWith(
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
          textStyle: AppTextStyles.buttonMedium.copyWith(
            color: AppColors.telegramBlue,
          ),
          minimumSize: const Size(48, buttonHeightSmall),
        ),
      ),

      // Input Fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurface,
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.lightTextSecondary,
        ),
        labelStyle: AppTextStyles.bodyMedium,
        floatingLabelStyle: AppTextStyles.labelMedium,
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

      // Dialogs
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.lightCard,
        elevation: elevationHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusLarge),
        ),
        titleTextStyle: AppTextStyles.headlineMedium.copyWith(
          color: AppColors.lightTextPrimary,
        ),
        contentTextStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.lightTextSecondary,
        ),
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.darkCard,
        contentTextStyle: AppTextStyles.bodyMedium.copyWith(
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusMedium),
        ),
        elevation: elevationMedium,
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.all(spacingL),
      ),

      // Progress Indicators
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.telegramBlue,
        linearTrackColor: Color(0xFFE5E5EA),
        circularTrackColor: Color(0xFFE5E5EA),
        linearMinHeight: 2.0,
      ),

      // Text Theme
      textTheme: TextTheme(
        displayLarge: AppTextStyles.displayLarge.copyWith(
          color: AppColors.lightTextPrimary,
        ),
        displayMedium: AppTextStyles.displayMedium.copyWith(
          color: AppColors.lightTextPrimary,
        ),
        displaySmall: AppTextStyles.displaySmall.copyWith(
          color: AppColors.lightTextPrimary,
        ),
        headlineLarge: AppTextStyles.headlineLarge.copyWith(
          color: AppColors.lightTextPrimary,
        ),
        headlineMedium: AppTextStyles.headlineMedium.copyWith(
          color: AppColors.lightTextPrimary,
        ),
        headlineSmall: AppTextStyles.headlineSmall.copyWith(
          color: AppColors.lightTextPrimary,
        ),
        titleLarge: AppTextStyles.titleLarge.copyWith(
          color: AppColors.lightTextPrimary,
        ),
        titleMedium: AppTextStyles.titleMedium.copyWith(
          color: AppColors.lightTextPrimary,
        ),
        titleSmall: AppTextStyles.titleSmall.copyWith(
          color: AppColors.lightTextPrimary,
        ),
        bodyLarge: AppTextStyles.bodyLarge.copyWith(
          color: AppColors.lightTextPrimary,
        ),
        bodyMedium: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.lightTextPrimary,
        ),
        bodySmall: AppTextStyles.bodySmall.copyWith(
          color: AppColors.lightTextSecondary,
        ),
        labelLarge: AppTextStyles.labelLarge.copyWith(
          color: AppColors.lightTextPrimary,
        ),
        labelMedium: AppTextStyles.labelMedium.copyWith(
          color: AppColors.lightTextSecondary,
        ),
        labelSmall: AppTextStyles.labelSmall.copyWith(
          color: AppColors.lightTextTertiary,
        ),
      ),

      // Icons
      iconTheme: const IconThemeData(
        color: AppColors.lightTextSecondary,
        size: iconSizeM,
      ),

      // Dividers
      dividerTheme: const DividerThemeData(
        color: AppColors.lightDivider,
        thickness: 0.5,
        space: 0,
      ),

      // List Tiles
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

      // Floating Action Button
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

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.lightSurface,
        selectedColor: AppColors.telegramBlue,
        disabledColor: const Color(0xFFE5E5EA),
        labelStyle: AppTextStyles.labelSmall.copyWith(
          color: AppColors.lightTextSecondary,
        ),
        secondaryLabelStyle: AppTextStyles.labelSmall.copyWith(
          color: Colors.white,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: spacingM,
          vertical: spacingXS,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusFull),
        ),
        side: BorderSide.none,
        brightness: Brightness.light,
      ),
    );
  }

  // Telegram Dark Theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: AppColors.telegramBlueLight,
        primaryContainer: AppColors.telegramBlueDark,
        secondary: AppColors.telegramGreen,
        secondaryContainer: AppColors.telegramGreen.withValues(alpha: 0.1),
        surface: AppColors.darkSurface,
        surfaceContainerHighest: const Color(0xFF2C2C2E),
        error: AppColors.telegramRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        outline: AppColors.darkDivider,
        outlineVariant: const Color(0xFF38383A),
      ),

      // Scaffold & App Bar
      scaffoldBackgroundColor: AppColors.darkBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkBackground,
        foregroundColor: AppColors.darkTextPrimary,
        elevation: elevationNone,
        centerTitle: false,
        titleTextStyle: AppTextStyles.appBarTitle.copyWith(
          color: AppColors.darkTextPrimary,
        ),
        iconTheme: const IconThemeData(
          color: AppColors.darkTextPrimary,
          size: iconSizeM,
        ),
        toolbarHeight: appBarHeight,
        surfaceTintColor: Colors.transparent,
      ),

      // Bottom Navigation Bar
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
          height: 1.2,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          height: 1.2,
        ),
      ),

      // Cards
      cardTheme: const CardThemeData(
        color: AppColors.darkCard,
        elevation: elevationLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(borderRadiusMedium)),
        ),
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.telegramBlueLight,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.telegramBlueLight.withValues(alpha: 0.5),
          elevation: elevationNone,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadiusMedium),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: spacingXL,
            vertical: spacingM,
          ),
          textStyle: AppTextStyles.buttonMedium,
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
          textStyle: AppTextStyles.buttonMedium.copyWith(
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
          textStyle: AppTextStyles.buttonMedium.copyWith(
            color: AppColors.telegramBlueLight,
          ),
          minimumSize: const Size(48, buttonHeightSmall),
        ),
      ),

      // Input Fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface,
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.darkTextSecondary,
        ),
        labelStyle: AppTextStyles.bodyMedium,
        floatingLabelStyle: AppTextStyles.labelMedium,
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

      // Dialogs
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkCard,
        elevation: elevationHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusLarge),
        ),
        titleTextStyle: AppTextStyles.headlineMedium.copyWith(
          color: AppColors.darkTextPrimary,
        ),
        contentTextStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.darkTextSecondary,
        ),
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.darkCard,
        contentTextStyle: AppTextStyles.bodyMedium.copyWith(
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusMedium),
        ),
        elevation: elevationMedium,
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.all(spacingL),
      ),

      // Progress Indicators
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.telegramBlueLight,
        linearTrackColor: Color(0xFF38383A),
        circularTrackColor: Color(0xFF38383A),
        linearMinHeight: 2.0,
      ),

      // Text Theme
      textTheme: TextTheme(
        displayLarge: AppTextStyles.displayLarge.copyWith(
          color: AppColors.darkTextPrimary,
        ),
        displayMedium: AppTextStyles.displayMedium.copyWith(
          color: AppColors.darkTextPrimary,
        ),
        displaySmall: AppTextStyles.displaySmall.copyWith(
          color: AppColors.darkTextPrimary,
        ),
        headlineLarge: AppTextStyles.headlineLarge.copyWith(
          color: AppColors.darkTextPrimary,
        ),
        headlineMedium: AppTextStyles.headlineMedium.copyWith(
          color: AppColors.darkTextPrimary,
        ),
        headlineSmall: AppTextStyles.headlineSmall.copyWith(
          color: AppColors.darkTextPrimary,
        ),
        titleLarge: AppTextStyles.titleLarge.copyWith(
          color: AppColors.darkTextPrimary,
        ),
        titleMedium: AppTextStyles.titleMedium.copyWith(
          color: AppColors.darkTextPrimary,
        ),
        titleSmall: AppTextStyles.titleSmall.copyWith(
          color: AppColors.darkTextPrimary,
        ),
        bodyLarge: AppTextStyles.bodyLarge.copyWith(
          color: AppColors.darkTextPrimary,
        ),
        bodyMedium: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.darkTextPrimary,
        ),
        bodySmall: AppTextStyles.bodySmall.copyWith(
          color: AppColors.darkTextSecondary,
        ),
        labelLarge: AppTextStyles.labelLarge.copyWith(
          color: AppColors.darkTextPrimary,
        ),
        labelMedium: AppTextStyles.labelMedium.copyWith(
          color: AppColors.darkTextSecondary,
        ),
        labelSmall: AppTextStyles.labelSmall.copyWith(
          color: AppColors.darkTextTertiary,
        ),
      ),

      // Icons
      iconTheme: const IconThemeData(
        color: AppColors.darkTextSecondary,
        size: iconSizeM,
      ),

      // Dividers
      dividerTheme: const DividerThemeData(
        color: AppColors.darkDivider,
        thickness: 0.5,
        space: 0,
      ),

      // List Tiles
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

      // Floating Action Button
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

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkSurface,
        selectedColor: AppColors.telegramBlueLight,
        disabledColor: const Color(0xFF38383A),
        labelStyle: AppTextStyles.labelSmall.copyWith(
          color: AppColors.darkTextSecondary,
        ),
        secondaryLabelStyle: AppTextStyles.labelSmall.copyWith(
          color: Colors.white,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: spacingM,
          vertical: spacingXS,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusFull),
        ),
        side: BorderSide.none,
        brightness: Brightness.dark,
      ),
    );
  }

  // Common Decorations
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
                color: Colors.black.withValues(alpha: 0.08),
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

  // Animation Effects
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

  // Loading Shimmer
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

  // Responsive padding
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

  // Chat bubble decoration
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

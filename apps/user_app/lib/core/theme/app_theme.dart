import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'color_tokens.dart';

/// Legacy AppColors class - kept for backward compatibility
/// New code should use ColorTokens instead
@Deprecated('Use ColorTokens instead')
class AppColors {
  // Light mode colors
  static const Color primary = ColorTokens.brandPrimary;
  static const Color secondary = ColorTokens.brandSecondary;
  static const Color accent = ColorTokens.brandAccent;
  static const Color surface = Color(0xFFFAFAFA); // Light gray background
  
  // Dark mode colors
  static const Color darkPrimary = ColorTokens.brandPrimary; // Keep yellow in dark mode
  static const Color darkSecondary = Color(0xFFFF6B6B); // Lighter red for dark mode
  static const Color darkSurface = Color(0xFF121212); // Material dark surface
  static const Color darkSurfaceVariant = Color(0xFF1E1E1E); // Slightly lighter dark surface
  static const Color darkBackground = Color(0xFF0A0A0A); // Very dark background
}

// Standard font sizes following Material Design guidelines
class AppFontSizes {
  static const double displayLarge = 57.0;
  static const double displayMedium = 45.0;
  static const double displaySmall = 36.0;
  static const double headlineLarge = 32.0;
  static const double headlineMedium = 28.0;
  static const double headlineSmall = 24.0;
  static const double titleLarge = 22.0;
  static const double titleMedium = 16.0;
  static const double titleSmall = 14.0;
  static const double bodyLarge = 16.0;
  static const double bodyMedium = 14.0;
  static const double bodySmall = 12.0;
  static const double labelLarge = 14.0;
  static const double labelMedium = 12.0;
  static const double labelSmall = 11.0;
}

class AppTheme {
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      brightness: Brightness.light,
    );

    final baseInter = GoogleFonts.interTextTheme();

    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.surface, // Uses token: bgApp
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: AppColors.surface, // Uses token: bgApp
        foregroundColor: const Color(0xFF1A1A1A), // Uses token: textPrimary
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white, // Uses token: bgInput
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: const Color(0xFFCCCCCC)), // Uses token: borderInput
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: ColorTokens.brandPrimary, width: 1.6), // Uses token: borderInputFocused
        ),
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w400,
          color: Color(0xFF666666), // Uses token: textSecondary
        ),
        hintStyle: const TextStyle(
          fontWeight: FontWeight.w400,
          color: Color(0xFF999999), // Uses token: textTertiary
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: colorScheme.primary, // Uses token: actionPrimary
        unselectedItemColor: const Color(0xFF999999), // Uses token: iconTertiary
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
      chipTheme: ChipThemeData(
        color: WidgetStatePropertyAll(const Color(0xFFE0E0E0)), // Uses token: borderDefault (lighter)
        labelStyle: const TextStyle(
          color: Color(0xFF1A1A1A), // Uses token: textPrimary
          fontWeight: FontWeight.w500,
        ),
        side: const BorderSide(color: Colors.transparent),
        shape: StadiumBorder(side: BorderSide.none),
      ),
      textTheme: baseInter.copyWith(
        displayLarge: baseInter.displayLarge?.copyWith(
          fontWeight: FontWeight.w600, 
          fontSize: AppFontSizes.displayLarge, 
          height: 1.17, // 64/57
        ),
        displayMedium: baseInter.displayMedium?.copyWith(
          fontWeight: FontWeight.w600, 
          fontSize: AppFontSizes.displayMedium, 
          height: 1.2, // 52/45
        ),
        displaySmall: baseInter.displaySmall?.copyWith(
          fontWeight: FontWeight.w600, 
          fontSize: AppFontSizes.displaySmall, 
          height: 1.25, // 44/36
        ),
        headlineLarge: baseInter.headlineLarge?.copyWith(
          fontWeight: FontWeight.w600, 
          fontSize: AppFontSizes.headlineLarge, 
          height: 1.25, // 40/32
        ),
        headlineMedium: baseInter.headlineMedium?.copyWith(
          fontWeight: FontWeight.w600, 
          fontSize: AppFontSizes.headlineMedium, 
          height: 1.29, // 36/28
        ),
        headlineSmall: baseInter.headlineSmall?.copyWith(
          fontWeight: FontWeight.w600, 
          fontSize: AppFontSizes.headlineSmall, 
          height: 1.33, // 32/24
        ),
        titleLarge: baseInter.titleLarge?.copyWith(
          fontWeight: FontWeight.w600, 
          fontSize: AppFontSizes.titleLarge, 
          height: 1.27, // 28/22
        ),
        titleMedium: baseInter.titleMedium?.copyWith(
          fontWeight: FontWeight.w600, 
          fontSize: AppFontSizes.titleMedium, 
          height: 1.5, // 24/16
        ),
        titleSmall: baseInter.titleSmall?.copyWith(
          fontWeight: FontWeight.w500, 
          fontSize: AppFontSizes.titleSmall, 
          height: 1.43, // 20/14
        ),
        bodyLarge: baseInter.bodyLarge?.copyWith(
          fontWeight: FontWeight.w400, 
          fontSize: AppFontSizes.bodyLarge, 
          height: 1.5, // 24/16
        ),
        bodyMedium: baseInter.bodyMedium?.copyWith(
          fontWeight: FontWeight.w400, 
          fontSize: AppFontSizes.bodyMedium, 
          height: 1.43, // 20/14
        ),
        bodySmall: baseInter.bodySmall?.copyWith(
          fontWeight: FontWeight.w400, 
          fontSize: AppFontSizes.bodySmall, 
          height: 1.33, // 16/12
        ),
        labelLarge: baseInter.labelLarge?.copyWith(
          fontWeight: FontWeight.w600, 
          fontSize: AppFontSizes.labelLarge, 
          height: 1.43, // 20/14
        ),
        labelMedium: baseInter.labelMedium?.copyWith(
          fontWeight: FontWeight.w500, 
          fontSize: AppFontSizes.labelMedium, 
          height: 1.33, // 16/12
        ),
        labelSmall: baseInter.labelSmall?.copyWith(
          fontWeight: FontWeight.w400, 
          fontSize: AppFontSizes.labelSmall, 
          height: 1.27, // 14/11
        ),
      ),
      cardTheme: const CardThemeData(
        color: Colors.white, // Uses token: bgSurface
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ColorTokens.brandPrimary, // Uses token: actionPrimary
          foregroundColor: Colors.black87, // Uses token: actionPrimaryText
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.darkPrimary,
      primary: AppColors.darkPrimary,
      secondary: AppColors.darkSecondary,
      brightness: Brightness.dark,
      surface: AppColors.darkSurface,
      surfaceVariant: AppColors.darkSurfaceVariant,
      background: AppColors.darkBackground,
    );

    final baseInter = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.darkBackground,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: AppColors.darkSurface, // Uses token: bgSurface
        foregroundColor: const Color(0xFFEAEAEA), // Uses token: textPrimary
        iconTheme: const IconThemeData(color: Color(0xFFEAEAEA)), // Uses token: iconPrimary
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurfaceVariant, // Uses token: bgInput
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          borderSide: const BorderSide(color: Color(0xFF404040)), // Uses token: borderInput
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          borderSide: const BorderSide(color: Color(0xFF404040)), // Uses token: borderInput
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: ColorTokens.brandPrimary, width: 1.6), // Uses token: borderInputFocused
        ),
        labelStyle: const TextStyle(
          color: Color(0xFFB0B0B0), // Uses token: textSecondary
          fontWeight: FontWeight.w400,
        ),
        hintStyle: const TextStyle(
          color: Color(0xFF808080), // Uses token: textTertiary
          fontWeight: FontWeight.w400,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkSurface, // Uses token: bgSurface
        selectedItemColor: ColorTokens.brandPrimary, // Uses token: actionPrimary
        unselectedItemColor: const Color(0xFF808080), // Uses token: iconTertiary
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkSurfaceVariant, // Uses token: bgElevated
        color: WidgetStatePropertyAll(AppColors.darkSurfaceVariant),
        labelStyle: const TextStyle(
          color: Color(0xFFEAEAEA), // Uses token: textPrimary
          fontWeight: FontWeight.w500,
        ),
        side: const BorderSide(color: Color(0xFF333333)), // Uses token: borderDefault
        shape: const StadiumBorder(),
      ),
      textTheme: baseInter.copyWith(
        displayLarge: baseInter.displayLarge?.copyWith(
          fontWeight: FontWeight.w600, 
          fontSize: AppFontSizes.displayLarge, 
          height: 1.17,
          color: const Color(0xFFEAEAEA), // Uses token: textPrimary
        ),
        displayMedium: baseInter.displayMedium?.copyWith(
          fontWeight: FontWeight.w600, 
          fontSize: AppFontSizes.displayMedium, 
          height: 1.2,
          color: const Color(0xFFEAEAEA), // Uses token: textPrimary
        ),
        displaySmall: baseInter.displaySmall?.copyWith(
          fontWeight: FontWeight.w600, 
          fontSize: AppFontSizes.displaySmall, 
          height: 1.25,
          color: const Color(0xFFEAEAEA), // Uses token: textPrimary
        ),
        headlineLarge: baseInter.headlineLarge?.copyWith(
          fontWeight: FontWeight.w600, 
          fontSize: AppFontSizes.headlineLarge, 
          height: 1.25,
          color: const Color(0xFFEAEAEA), // Uses token: textPrimary
        ),
        headlineMedium: baseInter.headlineMedium?.copyWith(
          fontWeight: FontWeight.w600, 
          fontSize: AppFontSizes.headlineMedium, 
          height: 1.29,
          color: const Color(0xFFEAEAEA), // Uses token: textPrimary
        ),
        headlineSmall: baseInter.headlineSmall?.copyWith(
          fontWeight: FontWeight.w600, 
          fontSize: AppFontSizes.headlineSmall, 
          height: 1.33,
          color: const Color(0xFFEAEAEA), // Uses token: textPrimary
        ),
        titleLarge: baseInter.titleLarge?.copyWith(
          fontWeight: FontWeight.w600, 
          fontSize: AppFontSizes.titleLarge, 
          height: 1.27,
          color: const Color(0xFFEAEAEA), // Uses token: textPrimary
        ),
        titleMedium: baseInter.titleMedium?.copyWith(
          fontWeight: FontWeight.w600, 
          fontSize: AppFontSizes.titleMedium, 
          height: 1.5,
          color: const Color(0xFFEAEAEA), // Uses token: textPrimary
        ),
        titleSmall: baseInter.titleSmall?.copyWith(
          fontWeight: FontWeight.w500, 
          fontSize: AppFontSizes.titleSmall, 
          height: 1.43,
          color: const Color(0xFFB0B0B0), // Uses token: textSecondary
        ),
        bodyLarge: baseInter.bodyLarge?.copyWith(
          fontWeight: FontWeight.w400, 
          fontSize: AppFontSizes.bodyLarge, 
          height: 1.5,
          color: const Color(0xFFEAEAEA), // Uses token: textPrimary (softer)
        ),
        bodyMedium: baseInter.bodyMedium?.copyWith(
          fontWeight: FontWeight.w400, 
          fontSize: AppFontSizes.bodyMedium, 
          height: 1.43,
          color: const Color(0xFFB0B0B0), // Uses token: textSecondary
        ),
        bodySmall: baseInter.bodySmall?.copyWith(
          fontWeight: FontWeight.w400, 
          fontSize: AppFontSizes.bodySmall, 
          height: 1.33,
          color: const Color(0xFF808080), // Uses token: textTertiary
        ),
        labelLarge: baseInter.labelLarge?.copyWith(
          fontWeight: FontWeight.w600, 
          fontSize: AppFontSizes.labelLarge, 
          height: 1.43,
          color: const Color(0xFFEAEAEA), // Uses token: textPrimary
        ),
        labelMedium: baseInter.labelMedium?.copyWith(
          fontWeight: FontWeight.w500, 
          fontSize: AppFontSizes.labelMedium, 
          height: 1.33,
          color: const Color(0xFFB0B0B0), // Uses token: textSecondary
        ),
        labelSmall: baseInter.labelSmall?.copyWith(
          fontWeight: FontWeight.w400, 
          fontSize: AppFontSizes.labelSmall, 
          height: 1.27,
          color: const Color(0xFF808080), // Uses token: textTertiary
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface, // Uses token: bgSurface
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ColorTokens.brandPrimary, // Uses token: actionPrimary
          foregroundColor: Colors.black87, // Uses token: actionPrimaryText
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: const Color(0xFF333333), // Uses token: borderDefault
        thickness: 1,
      ),
      listTileTheme: ListTileThemeData(
        tileColor: AppColors.darkSurfaceVariant, // Uses token: bgElevated
        textColor: const Color(0xFFEAEAEA), // Uses token: textPrimary
        iconColor: const Color(0xFFB0B0B0), // Uses token: iconSecondary
      ),
    );
  }
}

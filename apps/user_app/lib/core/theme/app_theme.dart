import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Light mode colors
  static const Color primary = Color(0xFFFDBB42);
  static const Color secondary = Color(0xFF9C100E); // Dark red/burgundy accent
  static const Color accent = Color(0xFFFFE8D6); // Soft peach bg accents
  static const Color surface = Color(0xFFFAFAFA); // Light gray background
  
  // Dark mode colors
  static const Color darkPrimary = Color(0xFFFDBB42); // Keep yellow in dark mode
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
      scaffoldBackgroundColor: AppColors.surface,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: AppColors.surface,
        foregroundColor: Colors.black87,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: Colors.black12),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: AppColors.primary, width: 1.6),
        ),
        labelStyle: const TextStyle(fontWeight: FontWeight.w400),
        hintStyle: const TextStyle(fontWeight: FontWeight.w400),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: Colors.grey.shade600,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
      chipTheme: ChipThemeData(
        color: WidgetStatePropertyAll(Colors.grey.shade200),
        labelStyle: const TextStyle(
          color: Colors.black87,
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
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
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
        backgroundColor: AppColors.darkSurface,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurfaceVariant,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: Colors.grey.shade700),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: Colors.grey.shade700),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: AppColors.darkPrimary, width: 1.6),
        ),
        labelStyle: TextStyle(color: Colors.grey.shade300, fontWeight: FontWeight.w400),
        hintStyle: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w400),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        selectedItemColor: AppColors.darkPrimary,
        unselectedItemColor: Colors.grey.shade500,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkSurfaceVariant,
        color: WidgetStatePropertyAll(AppColors.darkSurfaceVariant),
        labelStyle: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        side: BorderSide(color: Colors.grey.shade700),
        shape: const StadiumBorder(),
      ),
      textTheme: baseInter.copyWith(
        displayLarge: baseInter.displayLarge?.copyWith(
          fontWeight: FontWeight.w600, 
          fontSize: AppFontSizes.displayLarge, 
          height: 1.17,
          color: Colors.white,
        ),
        displayMedium: baseInter.displayMedium?.copyWith(
          fontWeight: FontWeight.w600, 
          fontSize: AppFontSizes.displayMedium, 
          height: 1.2,
          color: Colors.white,
        ),
        displaySmall: baseInter.displaySmall?.copyWith(
          fontWeight: FontWeight.w600, 
          fontSize: AppFontSizes.displaySmall, 
          height: 1.25,
          color: Colors.white,
        ),
        headlineLarge: baseInter.headlineLarge?.copyWith(
          fontWeight: FontWeight.w600, 
          fontSize: AppFontSizes.headlineLarge, 
          height: 1.25,
          color: Colors.white,
        ),
        headlineMedium: baseInter.headlineMedium?.copyWith(
          fontWeight: FontWeight.w600, 
          fontSize: AppFontSizes.headlineMedium, 
          height: 1.29,
          color: Colors.white,
        ),
        headlineSmall: baseInter.headlineSmall?.copyWith(
          fontWeight: FontWeight.w600, 
          fontSize: AppFontSizes.headlineSmall, 
          height: 1.33,
          color: Colors.white,
        ),
        titleLarge: baseInter.titleLarge?.copyWith(
          fontWeight: FontWeight.w600, 
          fontSize: AppFontSizes.titleLarge, 
          height: 1.27,
          color: Colors.white,
        ),
        titleMedium: baseInter.titleMedium?.copyWith(
          fontWeight: FontWeight.w600, 
          fontSize: AppFontSizes.titleMedium, 
          height: 1.5,
          color: Colors.white,
        ),
        titleSmall: baseInter.titleSmall?.copyWith(
          fontWeight: FontWeight.w500, 
          fontSize: AppFontSizes.titleSmall, 
          height: 1.43,
          color: Colors.grey.shade300,
        ),
        bodyLarge: baseInter.bodyLarge?.copyWith(
          fontWeight: FontWeight.w400, 
          fontSize: AppFontSizes.bodyLarge, 
          height: 1.5,
          color: Colors.grey.shade200,
        ),
        bodyMedium: baseInter.bodyMedium?.copyWith(
          fontWeight: FontWeight.w400, 
          fontSize: AppFontSizes.bodyMedium, 
          height: 1.43,
          color: Colors.grey.shade300,
        ),
        bodySmall: baseInter.bodySmall?.copyWith(
          fontWeight: FontWeight.w400, 
          fontSize: AppFontSizes.bodySmall, 
          height: 1.33,
          color: Colors.grey.shade400,
        ),
        labelLarge: baseInter.labelLarge?.copyWith(
          fontWeight: FontWeight.w600, 
          fontSize: AppFontSizes.labelLarge, 
          height: 1.43,
          color: Colors.white,
        ),
        labelMedium: baseInter.labelMedium?.copyWith(
          fontWeight: FontWeight.w500, 
          fontSize: AppFontSizes.labelMedium, 
          height: 1.33,
          color: Colors.grey.shade300,
        ),
        labelSmall: baseInter.labelSmall?.copyWith(
          fontWeight: FontWeight.w400, 
          fontSize: AppFontSizes.labelSmall, 
          height: 1.27,
          color: Colors.grey.shade400,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.darkPrimary,
          foregroundColor: Colors.black87,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade800,
        thickness: 1,
      ),
      listTileTheme: ListTileThemeData(
        tileColor: AppColors.darkSurfaceVariant,
        textColor: Colors.white,
        iconColor: Colors.grey.shade300,
      ),
    );
  }
}

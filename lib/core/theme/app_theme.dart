import 'package:flutter/material.dart';

/// Dark navy + gold visual identity. Minimal, high-contrast, accessible.
class AppColors {
  static const navyBackground = Color(0xFF0B1220);
  static const navySurface = Color(0xFF111A2E);
  static const navySurfaceAlt = Color(0xFF17233D);
  static const gold = Color(0xFFD4AF37);
  static const goldDim = Color(0xFF8A7320);
  static const textPrimary = Color(0xFFF5F7FA);
  static const textSecondary = Color(0xFFA9B4C7);
  static const success = Color(0xFF3DD68C);
  static const error = Color(0xFFE5484D);
}

class AppTheme {
  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: AppColors.gold,
      onPrimary: AppColors.navyBackground,
      secondary: AppColors.gold,
      surface: AppColors.navySurface,
      onSurface: AppColors.textPrimary,
      error: AppColors.error,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.navyBackground,
      fontFamily: 'Cairo', // falls back to platform font if not bundled
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.navyBackground,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.navyBackground,
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.gold),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.navySurfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
      ),
      dividerColor: const Color(0x1AFFFFFF),
      listTileTheme: const ListTileThemeData(iconColor: AppColors.gold),
    );
  }
}

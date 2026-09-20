import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF5B2C83);
  static const secondary = Color(0xFF7B3FA1);
  static const surface = Color(0xFFFFFFFF);
  static const background = Color(0xFFF7F5F8);
  static const error = Color(0xFFBA1A1A);
  static const success = Color(0xFF1B6B46);
}

abstract final class AppTheme {
  static final light = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.surface,
      error: AppColors.error,
    ),
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFFD1CAD5)),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  );
}

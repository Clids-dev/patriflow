import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF5B2C83);
  static const secondary = Color(0xFF7B3FA1);
  static const surface = Color(0xFFFFFFFF);
  static const background = Color(0xFFF7F5F8);
  static const error = Color(0xFFBA1A1A);
  static const success = Color(0xFF1B6B46);
}

abstract final class AppIcons {
  static const brand = Icons.account_balance_wallet_outlined;
  static const server = Icons.dns_outlined;
  static const link = Icons.link;
  static const save = Icons.save_outlined;
  static const settings = Icons.settings_outlined;
  static const login = Icons.lock_outline;
  static const logout = Icons.logout;
  static const error = Icons.error_outline;
  static const retry = Icons.refresh;
  static const empty = Icons.inventory_2_outlined;
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
    textTheme: const TextTheme(
      headlineMedium: TextStyle(fontWeight: FontWeight.w700),
      headlineSmall: TextStyle(fontWeight: FontWeight.w700),
      titleLarge: TextStyle(fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(height: 1.5),
      bodyMedium: TextStyle(height: 1.45),
    ),
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

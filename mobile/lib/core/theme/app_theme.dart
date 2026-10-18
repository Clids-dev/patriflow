import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF820AD1);     // #820ad1 (Nubank Moderno)
  static const secondary = Color(0xFF6D08B1);   // #6d08b1
  static const surface = Color(0xFFFFFFFF);
  static const background = Color(0xFFF0F2F5);  // #f0f2f5 (Cinza Facebook padrão do web)
  static const error = Color(0xFFF02849);       // #f02849
  static const success = Color(0xFF42B72A);     // #42b72a
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
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF111111),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE0E4E7)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}

import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF820AD1); // Roxo vibrante oficial
  static const secondary = Color(0xFF19002B); // Roxo escuro
  static const accent = Color(0xFFA855F7); // Roxo claro de destaque
  static const surface = Color(0xFFFFFFFF); // Superfícies e cartões brancos
  static const background = Color(
    0xFFF5F5F7,
  ); // Fundo principal cinza muito claro iOS
  static const textPrimary = Color(0xFF1C1C1E); // Texto quase preto
  static const textSecondary = Color(0xFF6E6E73); // Texto secundário cinza
  static const border = Color(0xFFE5E5EA); // Bordas cinza claro
  static const error = Color(0xFFFF3B30); // Vermelho status/erro
  static const success = Color(0xFF34C759); // Verde status ativo
  static const warning = Color(0xFFFF9500); // Amarelo alerta
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
      headlineMedium: TextStyle(
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      headlineSmall: TextStyle(
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      titleLarge: TextStyle(
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      bodyLarge: TextStyle(height: 1.5, color: AppColors.textPrimary),
      bodyMedium: TextStyle(height: 1.45, color: AppColors.textPrimary),
      bodySmall: TextStyle(color: AppColors.textSecondary),
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 16,
        height: 1.45,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
    ),
  );
}

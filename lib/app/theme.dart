import 'package:flutter/material.dart';

abstract final class AppColors {
  static const ink = Color(0xFF132238);
  static const muted = Color(0xFF718096);
  static const canvas = Color(0xFFF7F8FA);
  static const cream = Color(0xFFFFF8EC);
  static const saffron = Color(0xFFFFA726);
  static const coral = Color(0xFFFF7043);
  static const teal = Color(0xFF00A6A6);
  static const mint = Color(0xFFE5F7F1);
  static const line = Color(0xFFE7EBF0);
  static const success = Color(0xFF1F9D68);
}

ThemeData buildTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.saffron,
        brightness: Brightness.light,
      ).copyWith(
        primary: AppColors.ink,
        onPrimary: Colors.white,
        secondary: AppColors.saffron,
        surface: Colors.white,
        onSurface: AppColors.ink,
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.canvas,
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.canvas,
      foregroundColor: AppColors.ink,
      elevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: const TextStyle(color: AppColors.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.saffron, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: AppColors.cream,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      side: const BorderSide(color: AppColors.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      labelStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
    ),
  );
}

TextStyle displayStyle({double size = 32, Color color = AppColors.ink}) =>
    TextStyle(
      fontSize: size,
      height: 1.05,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.1,
      color: color,
    );
TextStyle bodyStyle({
  Color color = AppColors.muted,
  FontWeight weight = FontWeight.w500,
}) => TextStyle(fontSize: 14, height: 1.45, fontWeight: weight, color: color);

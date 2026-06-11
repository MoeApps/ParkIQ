// lib/theme/app_theme.dart
//
// All colors and text styles live here.
// If you want to change the look of the whole app, this is the only file you touch.

import 'package:flutter/material.dart';

// ── Brand Colors ──────────────────────────────────────────────────────────────
class AppColors {
  AppColors._(); // prevents instantiation — use as AppColors.cyan

  static const Color background   = Color(0xFF05060F); // darkest bg
  static const Color surface      = Color(0xFF0F1224); // card bg
  static const Color surfaceAlt   = Color(0xFF131629); // input bg
  static const Color border       = Color(0x14FFFFFF); // subtle border

  static const Color cyan         = Color(0xFF00D4FF);
  static const Color teal         = Color(0xFF00FFCC);
  static const Color purple       = Color(0xFF8B5CF6);
  static const Color green        = Color(0xFF22C55E);
  static const Color red          = Color(0xFFEF4444);
  static const Color amber        = Color(0xFFF59E0B);
  static const Color blue         = Color(0xFF3B82F6);

  static const Color textPrimary  = Color(0xFFF8FAFC);
  static const Color textSecond   = Color(0xFF94A3B8);
  static const Color textMuted    = Color(0xFF475569);

  // Gradient used on buttons and accents
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [cyan, teal],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ── ThemeData ─────────────────────────────────────────────────────────────────
ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      primary:    AppColors.cyan,
      secondary:  AppColors.teal,
      surface:    AppColors.surface,
      error:      AppColors.red,
    ),
    fontFamily: 'Roboto', // Flutter's built-in clean font

    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor:  AppColors.background,
      foregroundColor:  AppColors.textPrimary,
      elevation:        0,
      centerTitle:      true,
    ),

    // Input fields
    inputDecorationTheme: InputDecorationTheme(
      filled:          true,
      fillColor:       AppColors.surfaceAlt,
      hintStyle:       const TextStyle(color: AppColors.textMuted),
      border:          OutlineInputBorder(
        borderRadius:  BorderRadius.circular(10),
        borderSide:    const BorderSide(color: AppColors.border),
      ),
      enabledBorder:   OutlineInputBorder(
        borderRadius:  BorderRadius.circular(10),
        borderSide:    const BorderSide(color: AppColors.border),
      ),
      focusedBorder:   OutlineInputBorder(
        borderRadius:  BorderRadius.circular(10),
        borderSide:    const BorderSide(color: AppColors.cyan, width: 1.5),
      ),
      contentPadding:  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}

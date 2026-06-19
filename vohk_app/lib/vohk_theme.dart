import 'package:flutter/material.dart';

// ─── Vohk Color Palette ───────────────────────────────────────────────────────
class VohkColors {
  VohkColors._();

  static const background   = Color(0xFF0A0A0A); // near-black base
  static const surface      = Color(0xFF141414); // card background
  static const surfaceAlt   = Color(0xFF1C1C1C); // elevated card / input bg
  static const border       = Color(0xFF2A2A2A); // subtle dividers
  static const accent       = Color(0xFFFFCC00); // Vohk yellow
  static const accentDim    = Color(0xFF3D3000); // yellow tint for backgrounds
  static const callGreen    = Color(0xFF22C55E); // persistent call FAB
  static const online       = Color(0xFF22C55E); // online status dot
  static const restricted   = Color(0xFFFFCC00); // restricted status
  static const offline      = Color(0xFF6B7280); // offline status
  static const error        = Color(0xFFEF4444); // errors / missed calls
  static const textPrimary  = Color(0xFFFFFFFF);
  static const textSecondary= Color(0xFF9CA3AF);
  static const textMuted    = Color(0xFF6B7280);
}

// ─── Theme ────────────────────────────────────────────────────────────────────
ThemeData vohkTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: VohkColors.background,
    colorScheme: const ColorScheme.dark(
      primary:   VohkColors.accent,
      secondary: VohkColors.accent,
      surface:   VohkColors.surface,
      error:     VohkColors.error,
    ),

    // ── App Bar ───────────────────────────────────────────────────────────
    appBarTheme: const AppBarTheme(
      backgroundColor: VohkColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        color: VohkColors.textPrimary,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      iconTheme: IconThemeData(color: VohkColors.textPrimary),
    ),

    // ── Bottom Nav Bar ────────────────────────────────────────────────────
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF111111),
      selectedItemColor: VohkColors.accent,
      unselectedItemColor: VohkColors.textMuted,
      selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 11),
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),

    // ── Elevated Button ───────────────────────────────────────────────────
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: VohkColors.accent,
        foregroundColor: Colors.black,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
        elevation: 0,
      ),
    ),

    // ── Text Button ───────────────────────────────────────────────────────
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: VohkColors.accent),
    ),

    // ── Input Decoration ──────────────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: VohkColors.surfaceAlt,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: VohkColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: VohkColors.accent, width: 1.5),
      ),
      labelStyle: const TextStyle(color: VohkColors.textSecondary),
      hintStyle: const TextStyle(color: VohkColors.textMuted),
    ),

    // ── Card ──────────────────────────────────────────────────────────────
    cardTheme: CardThemeData(
      color: VohkColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: VohkColors.border),
      ),
    ),

    // ── Divider ───────────────────────────────────────────────────────────
    dividerTheme: const DividerThemeData(
      color: VohkColors.border,
      space: 1,
      thickness: 1,
    ),

    // ── Snack Bar ─────────────────────────────────────────────────────────
    snackBarTheme: SnackBarThemeData(
      backgroundColor: VohkColors.surfaceAlt,
      contentTextStyle: const TextStyle(color: VohkColors.textPrimary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),

    fontFamily: 'SF Pro Display', // Falls back to system sans-serif on Android
  );
}
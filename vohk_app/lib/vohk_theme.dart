import 'package:flutter/material.dart';

class VohkColors {
  VohkColors._();

  static const background = Color(0xFF080A09);
  static const surface = Color(0xFF101413);
  static const surfaceAlt = Color(0xFF151A18);
  static const border = Color(0xFF262C29);
  static const accent = Color(0xFF2E6BFF);
  static const accentLight = Color(0xFF648FFF);
  static const accentDim = Color(0xFF14244D);
  static const connector = Color(0xFFFFCC00);
  static const callGreen = Color(0xFF34C759);
  static const online = Color(0xFF34C759);
  static const restricted = Color(0xFFFFCC00);
  static const offline = Color(0xFF6B6B70);
  static const error = Color(0xFFFF4D4D);
  static const textPrimary = Color(0xFFF3F1EB);
  static const textSecondary = Color(0xFF969D99);
  static const textMuted = Color(0xFF626A66);
}

ThemeData vohkTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: VohkColors.background,
    colorScheme: const ColorScheme.dark(primary: VohkColors.accent, secondary: VohkColors.accent, surface: VohkColors.surface, error: VohkColors.error),
    appBarTheme: const AppBarTheme(
      backgroundColor: VohkColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(color: VohkColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.25),
      iconTheme: IconThemeData(color: VohkColors.textPrimary),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.black,
      selectedItemColor: VohkColors.accent,
      unselectedItemColor: Color(0xFF7A7A7E),
      selectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: VohkColors.accent,
        foregroundColor: Colors.white,
        disabledBackgroundColor: VohkColors.accentDim,
        disabledForegroundColor: VohkColors.textSecondary,
        minimumSize: const Size.fromHeight(48),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: VohkColors.accent)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: VohkColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: VohkColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: VohkColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: VohkColors.accent, width: 1.4),
      ),
      labelStyle: const TextStyle(color: VohkColors.textSecondary),
      hintStyle: const TextStyle(color: VohkColors.textMuted),
    ),
    cardTheme: CardThemeData(
      color: VohkColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: VohkColors.border),
      ),
    ),
    dividerTheme: const DividerThemeData(color: VohkColors.border, space: 1, thickness: 1),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: VohkColors.surfaceAlt,
      contentTextStyle: const TextStyle(color: VohkColors.textPrimary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

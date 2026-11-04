import 'package:flutter/material.dart';

/// Maroon as the brand accent, black/white for content - the accent carries
/// colour (app bar, buttons, badges), everyday text stays black-on-white so
/// it's never fighting a tinted background for contrast.
const kMaroon = Color(0xFF8E2A3B);

ThemeData buildAdminTheme() {
  final colorScheme = ColorScheme.fromSeed(seedColor: kMaroon, brightness: Brightness.light);

  return ThemeData(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: const Color(0xFFFAF7F6),
    appBarTheme: const AppBarTheme(
      backgroundColor: kMaroon,
      foregroundColor: Colors.white,
      elevation: 2,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 4,
      color: Colors.white,
      shadowColor: kMaroon.withValues(alpha: 0.2),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    textTheme: const TextTheme().apply(bodyColor: Colors.black87, displayColor: Colors.black87),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kMaroon,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 3,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kMaroon,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: kMaroon,
      foregroundColor: Colors.white,
    ),
    useMaterial3: true,
  );
}

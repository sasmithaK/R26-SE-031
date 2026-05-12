import 'package:flutter/material.dart';

class ReadingKidTheme {
  ReadingKidTheme._();

  static const Color background = Color(0xFFFFF8E1);
  static const Color card = Colors.white;
  static const Color primary = Color(0xFF2E7D32);
  static const Color accent = Color(0xFF1565C0);
  static const Color highlight = Color(0xFFFFC107);
  static const Color textMain = Color(0xFF1A1A1A);
  static const Color textSoft = Color(0xFF424242);

  static const double tapMin = 68;
  static const double radius = 24;

  static const TextStyle title = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: textMain,
    height: 1.25,
  );

  static const TextStyle passage = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    color: textMain,
    height: 1.6,
  );

  static const TextStyle chunk = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w800,
    color: textMain,
    height: 1.2,
  );

  static const TextStyle hint = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textSoft,
    height: 1.45,
  );

  static ThemeData theme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      primary: primary,
      secondary: accent,
      surface: card,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: primary,
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, tapMin),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, tapMin),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

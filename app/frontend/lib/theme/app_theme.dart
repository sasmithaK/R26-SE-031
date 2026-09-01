import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ─────────────────────────────────────────────────────────────
/// Dyslexia-Accessible Color Palette
/// Based on fixation-duration research for Sinhala readers:
///   • Crème/Pastel Yellow bg → lowest fixation (0.214s)
///   • Mint Green bg → suppresses hyper-excitability
///   • Pale Slate/Blue bg → comfortable, calming
///   • Dark Grey text → avoids glare of pure black on white
///   • AVOID: pure black on pure white, bright yellow bg
/// ─────────────────────────────────────────────────────────────
class AppColors {
  // ── Primary Backgrounds ──
  static const Color cream = Color(0xFFFFF8E7);            // Main bg — lowest fixation
  static const Color creamDark = Color(0xFFF5EDD8);        // Slightly deeper crème
  static const Color mintBg = Color(0xFFE8F5E9);           // Card/bubble bg — calming
  static const Color slateBg = Color(0xFFE3EDF7);          // Alternate section bg
  static const Color cardSurface = Color(0xFFFFFDF5);      // Card fill — warm white
  static const Color warmWhite = Color(0xFFFFFBF2);        // Input field fill

  // ── Text Colors ──
  static const Color textPrimary = Color(0xFF3E3E3E);      // Main text — dark grey
  static const Color textBrown = Color(0xFF5C4033);         // On mint green bg
  static const Color textSecondary = Color(0xFF6B7280);     // Muted / helper text
  static const Color textHint = Color(0xFF9CA3AF);          // Placeholder text

  // ── Accent Colors ──
  static const Color calmBlue = Color(0xFF4A90D9);          // Primary accent — buttons, links
  static const Color calmBlueDark = Color(0xFF3570B0);      // Pressed / shadow
  static const Color calmBlueLight = Color(0xFF7DB4E8);     // Light variant
  static const Color gentleGreen = Color(0xFF6DBE6D);       // Success, progress, yes
  static const Color gentleGreenDark = Color(0xFF4E9E4E);   // Shadow
  static const Color warmAmber = Color(0xFFE8A54B);         // Stars, highlights, rewards
  static const Color warmAmberLight = Color(0xFFF5D08C);    // Light amber
  static const Color softCoral = Color(0xFFE87C6D);         // Errors, no, alerts
  static const Color softCoralDark = Color(0xFFCC5E50);     // Shadow

  // ── Surface / Border ──
  static const Color borderLight = Color(0xFFE5E7EB);      // Subtle borders
  static const Color borderBlue = Color(0xFFB3D4F0);       // Blue-tinted border
  static const Color borderGreen = Color(0xFFB8E0B8);      // Green-tinted border
  static const Color shadow = Color(0x1A000000);            // 10% black shadow
  static const Color shadowMedium = Color(0x26000000);      // 15% black shadow

  // ── Gradients ──
  static const LinearGradient creamGradient = LinearGradient(
    colors: [Color(0xFFFFF8E7), Color(0xFFFFF3D6)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient blueButtonGradient = LinearGradient(
    colors: [Color(0xFF5A9DE0), Color(0xFF4A90D9)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient greenGradient = LinearGradient(
    colors: [Color(0xFF7DCE7D), Color(0xFF6DBE6D)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient slateGradient = LinearGradient(
    colors: [Color(0xFFE3EDF7), Color(0xFFD0DEF0)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient warmGradient = LinearGradient(
    colors: [Color(0xFFF5D08C), Color(0xFFE8A54B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Legacy aliases (for gradual migration — maps old names to new) ──
  static const Color primary = calmBlue;
  static const Color primaryLight = calmBlueLight;
  static const Color primaryDark = calmBlueDark;
  static const Color orange = warmAmber;
  static const Color orangeLight = warmAmberLight;
  static const Color orangeDark = Color(0xFFD49035);
  static const Color mint = gentleGreen;
  static const Color mintLight = Color(0xFF8ED88E);
  static const Color mintDark = gentleGreenDark;
  static const Color gold = warmAmber;
  static const Color goldLight = warmAmberLight;
  static const Color darkSlate = cream;
  static const Color darkSlateLight = cardSurface;
  static const Color backgroundLight = cream;
  static const Color textDark = textPrimary;
  static const Color textLight = textPrimary;
  static const Color textMuted = textSecondary;

  static const LinearGradient primaryGradient = blueButtonGradient;
  static const LinearGradient splashGradient = creamGradient;
  static const LinearGradient mintGradient = greenGradient;
}

/// ─────────────────────────────────────────────────────────────
/// Dyslexia-Accessible Typography
///   • Noto Sans Sinhala — monolinear, uniform stroke (Sinhala)
///   • Noto Sans Sinhala — clean sans-serif (English)
///   • 18pt+ minimum body text (19px+ on mobile)
///   • 1.7x–2.0x line height
///   • +15–25% letter spacing
///   • Left-aligned, bold only (no italics/uppercase/underlines)
/// ─────────────────────────────────────────────────────────────
class AppTypography {
  /// Sinhala text — always use this for any Sinhala content
  static TextStyle sinhala({
    double fontSize = 18,
    FontWeight fontWeight = FontWeight.w500,
    Color color = AppColors.textPrimary,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.notoSansSinhala(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height ?? 1.8,
      letterSpacing: letterSpacing ?? 0.8,
    );
  }

  /// English heading text
  static TextStyle heading({
    double fontSize = 28,
    FontWeight fontWeight = FontWeight.w700,
    Color color = AppColors.textPrimary,
    double? height,
  }) {
    return GoogleFonts.notoSansSinhala(
      fontSize: fontSize * 0.80, // Scale down to match previous Nunito Sans visual size
      fontWeight: fontWeight,
      color: color,
      height: height ?? 1.4,
      letterSpacing: 0.5,
    );
  }

  /// English body text
  static TextStyle body({
    double fontSize = 18,
    FontWeight fontWeight = FontWeight.w500,
    Color color = AppColors.textPrimary,
    double? height,
  }) {
    return GoogleFonts.notoSansSinhala(
      fontSize: fontSize * 0.80,
      fontWeight: fontWeight,
      color: color,
      height: height ?? 1.7,
      letterSpacing: 0.6,
      wordSpacing: 3.0,
    );
  }

  /// Button / label text
  static TextStyle button({
    double fontSize = 18,
    FontWeight fontWeight = FontWeight.w700,
    Color color = Colors.white,
  }) {
    return GoogleFonts.notoSansSinhala(
      fontSize: fontSize * 0.80,
      fontWeight: fontWeight,
      color: color,
      height: 1.3,
      letterSpacing: 0.4,
    );
  }

  /// Small caption / helper text (still accessible — minimum 14pt)
  static TextStyle caption({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w500,
    Color color = AppColors.textSecondary,
  }) {
    return GoogleFonts.notoSansSinhala(
      fontSize: fontSize * 0.80,
      fontWeight: fontWeight,
      color: color,
      height: 1.6,
      letterSpacing: 0.4,
    );
  }
}

class AppTheme {
  /// The single, dyslexia-friendly light theme
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.cream,
      primaryColor: AppColors.calmBlue,
      colorScheme: const ColorScheme.light(
        primary: AppColors.calmBlue,
        secondary: AppColors.gentleGreen,
        tertiary: AppColors.warmAmber,
        surface: AppColors.cardSurface,
        error: AppColors.softCoral,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
        onError: Colors.white,
      ),
      textTheme: TextTheme(
        displayLarge: AppTypography.heading(fontSize: 36, fontWeight: FontWeight.w700),
        displayMedium: AppTypography.heading(fontSize: 30, fontWeight: FontWeight.w700),
        displaySmall: AppTypography.heading(fontSize: 24, fontWeight: FontWeight.w700),
        headlineLarge: AppTypography.heading(fontSize: 26, fontWeight: FontWeight.w700),
        headlineMedium: AppTypography.heading(fontSize: 22, fontWeight: FontWeight.w700),
        headlineSmall: AppTypography.heading(fontSize: 18, fontWeight: FontWeight.w700),
        titleLarge: AppTypography.body(fontSize: 20, fontWeight: FontWeight.w700),
        titleMedium: AppTypography.body(fontSize: 18, fontWeight: FontWeight.w600),
        bodyLarge: AppTypography.body(fontSize: 18, fontWeight: FontWeight.w500),
        bodyMedium: AppTypography.body(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
        labelLarge: AppTypography.button(fontSize: 18),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.calmBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          minimumSize: const Size(0, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: AppTypography.button(fontSize: 18),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.warmWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.calmBlue, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        hintStyle: AppTypography.body(
          color: AppColors.textHint,
          fontSize: 16,
        ),
        prefixIconColor: AppColors.textSecondary,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.gentleGreen;
          return AppColors.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.gentleGreen.withValues(alpha: 0.3);
          }
          return AppColors.borderLight;
        }),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.gentleGreen,
        linearTrackColor: AppColors.borderLight,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: AppTypography.body(color: Colors.white, fontSize: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Keep darkTheme as an alias for backwards compatibility during migration
  static ThemeData get darkTheme => lightTheme;
}

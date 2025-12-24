import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App theme with dark navy gradient and glassmorphism styling
/// Uses Tajawal font for Arabic typography support
class AppTheme {
  // Primary colors
  static const Color primaryNavy = Color(0xFF0A1628);
  static const Color secondaryNavy = Color(0xFF152238);
  static const Color accentBlue = Color(0xFF1E3A5F);
  static const Color glassWhite = Color(0x1AFFFFFF);
  static const Color glassWhiteStrong = Color(0x33FFFFFF);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xB3FFFFFF);
  static const Color activeGlow = Color(0xFF4FC3F7);

  // Gradient for background
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0D1B2A), Color(0xFF1B263B), Color(0xFF0D1B2A)],
  );

  // Glass card decoration
  static BoxDecoration glassDecoration({
    double opacity = 0.1,
    double borderRadius = 24,
  }) {
    return BoxDecoration(
      color: Colors.white.withOpacity(opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  // Base text theme with Tajawal font
  static TextTheme _tajawalTextTheme(TextTheme base) {
    return GoogleFonts.tajawalTextTheme(base).copyWith(
      headlineLarge: GoogleFonts.tajawal(
        textStyle: base.headlineLarge,
        color: textPrimary,
        fontSize: 32,
        fontWeight: FontWeight.bold,
      ),
      headlineMedium: GoogleFonts.tajawal(
        textStyle: base.headlineMedium,
        color: textPrimary,
        fontSize: 24,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: GoogleFonts.tajawal(
        textStyle: base.bodyLarge,
        color: textPrimary,
        fontSize: 18,
      ),
      bodyMedium: GoogleFonts.tajawal(
        textStyle: base.bodyMedium,
        color: textSecondary,
        fontSize: 16,
      ),
    );
  }

  // Theme data with Tajawal font
  static ThemeData get darkTheme {
    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accentBlue,
        brightness: Brightness.dark,
        surface: primaryNavy,
      ),
      // Apply Tajawal to all text
      textTheme: _tajawalTextTheme(baseTheme.textTheme),
      primaryTextTheme: _tajawalTextTheme(baseTheme.primaryTextTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.tajawal(
          color: textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

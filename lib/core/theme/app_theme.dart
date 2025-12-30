import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme_provider.dart';

/// App theme with support for Night (default) and Light modes
/// Uses Tajawal font for Arabic typography support
class AppTheme {
  // ========== NIGHT MODE COLORS (Default) ==========
  static const Color nightPrimaryNavy = Color(0xFF0A1628);
  static const Color nightSecondaryNavy = Color(0xFF152238);
  static const Color nightAccentBlue = Color(0xFF1E3A5F);
  static const Color nightGlassWhite = Color(0x1AFFFFFF);
  static const Color nightTextPrimary = Color(0xFFFFFFFF);
  static const Color nightTextSecondary = Color(0xB3FFFFFF);
  static const Color nightActiveGlow = Color(0xFF4FC3F7);
  static const LinearGradient nightBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0D1B2A), Color(0xFF1B263B), Color(0xFF0D1B2A)],
  );

  // ========== LIGHT MODE COLORS ==========
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightAccentBlue = Color(0xFF2196F3);
  static const Color lightGlassTint = Color(0x0A000000);
  static const Color lightTextPrimary = Color(0xFF1A1A1A);
  static const Color lightTextSecondary = Color(0xFF6B7280);
  static const Color lightActiveGlow = Color(0xFF64B5F6);
  static const Color lightDivider = Color(0xFFE5E7EB);
  static const LinearGradient lightBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF8FAFC), Color(0xFFEFF6FF), Color(0xFFF8FAFC)],
  );

  // ========== LEGACY STATIC COLORS (for backward compatibility) ==========
  static const Color primaryNavy = nightPrimaryNavy;
  static const Color secondaryNavy = nightSecondaryNavy;
  static const Color accentBlue = nightAccentBlue;
  static const Color glassWhite = nightGlassWhite;
  static const Color glassWhiteStrong = Color(0x33FFFFFF);
  static const Color textPrimary = nightTextPrimary;
  static const Color textSecondary = nightTextSecondary;
  static const Color activeGlow = nightActiveGlow;
  static const LinearGradient backgroundGradient = nightBackgroundGradient;

  // ========== THEME-AWARE GETTERS ==========
  static bool get isLightMode => AppThemeProvider.instance.isLightMode;

  /// Current background gradient based on theme
  static LinearGradient get currentBackgroundGradient =>
      isLightMode ? lightBackgroundGradient : nightBackgroundGradient;

  /// Current text primary color
  static Color get currentTextPrimary =>
      isLightMode ? lightTextPrimary : nightTextPrimary;

  /// Current text secondary color
  static Color get currentTextSecondary =>
      isLightMode ? lightTextSecondary : nightTextSecondary;

  /// Current active glow color
  static Color get currentActiveGlow =>
      isLightMode ? lightActiveGlow : nightActiveGlow;

  /// Current accent color
  static Color get currentAccent =>
      isLightMode ? lightAccentBlue : nightAccentBlue;

  /// Current card/surface color
  static Color get currentSurface =>
      isLightMode ? lightSurface : nightSecondaryNavy;

  /// Current glass tint
  static Color get currentGlassTint =>
      isLightMode ? lightGlassTint : nightGlassWhite;

  /// Current divider color
  static Color get currentDivider =>
      isLightMode ? lightDivider : Colors.white.withOpacity(0.1);

  /// Inactive background (for unselected boxes, cards) - subtle but visible
  static Color get inactiveBackground =>
      isLightMode ? const Color(0xFFF1F5F9) : Colors.white.withOpacity(0.05);

  /// Inactive border color - for unselected items
  static Color get inactiveBorder =>
      isLightMode ? lightDivider : Colors.white.withOpacity(0.1);

  /// Icon secondary color - for subtle icons
  static Color get iconSecondary =>
      isLightMode ? lightTextSecondary : Colors.white.withOpacity(0.5);

  // Glass card decoration - theme aware
  static BoxDecoration glassDecoration({
    double opacity = 0.1,
    double borderRadius = 24,
  }) {
    if (isLightMode) {
      return BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: lightDivider, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      );
    } else {
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
  }

  // Base text theme with Tajawal font
  static TextTheme _tajawalTextTheme(TextTheme base, bool isLight) {
    final primaryColor = isLight ? lightTextPrimary : nightTextPrimary;
    final secondaryColor = isLight ? lightTextSecondary : nightTextSecondary;

    return GoogleFonts.tajawalTextTheme(base).copyWith(
      headlineLarge: GoogleFonts.tajawal(
        textStyle: base.headlineLarge,
        color: primaryColor,
        fontSize: 32,
        fontWeight: FontWeight.bold,
      ),
      headlineMedium: GoogleFonts.tajawal(
        textStyle: base.headlineMedium,
        color: primaryColor,
        fontSize: 24,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: GoogleFonts.tajawal(
        textStyle: base.bodyLarge,
        color: primaryColor,
        fontSize: 18,
      ),
      bodyMedium: GoogleFonts.tajawal(
        textStyle: base.bodyMedium,
        color: secondaryColor,
        fontSize: 16,
      ),
    );
  }

  // Dark/Night theme
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
        seedColor: nightAccentBlue,
        brightness: Brightness.dark,
        surface: nightPrimaryNavy,
      ),
      textTheme: _tajawalTextTheme(baseTheme.textTheme, false),
      primaryTextTheme: _tajawalTextTheme(baseTheme.primaryTextTheme, false),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.tajawal(
          color: nightTextPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // Light theme
  static ThemeData get lightTheme {
    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: ColorScheme.fromSeed(
        seedColor: lightAccentBlue,
        brightness: Brightness.light,
        surface: lightSurface,
      ),
      textTheme: _tajawalTextTheme(baseTheme.textTheme, true),
      primaryTextTheme: _tajawalTextTheme(baseTheme.primaryTextTheme, true),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.tajawal(
          color: lightTextPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Get current theme based on provider
  static ThemeData get currentTheme => isLightMode ? lightTheme : darkTheme;
}

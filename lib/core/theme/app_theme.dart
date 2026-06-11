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

  // ========== LIGHT MODE COLORS (Andalusian daylight) ==========
  // Warm parchment/ivory background with deep cobalt zellige-blue accents.
  // The old palette (clinical white + washed-out sky blue) had poor accent
  // contrast; cobalt passes comfortably on ivory and white cards.
  static const Color lightBackground = Color(0xFFFAF6EE);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightAccentBlue = Color(0xFF1D5FBF);
  static const Color lightGlassTint = Color(0x0A000000);
  static const Color lightTextPrimary = Color(0xFF26221A);
  static const Color lightTextSecondary = Color(0xFF6E6757);
  static const Color lightActiveGlow = Color(0xFF1D5FBF);
  static const Color lightDivider = Color(0xFFE6DEC9);
  static const LinearGradient lightBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFBF8F1), Color(0xFFF2EBDB), Color(0xFFFBF8F1)],
  );

  // ========== ISLAMIC MODE COLORS (Andalusian lapis & gold) ==========
  // Deep royal lapis blue with warm gold accents — the classic Andalusian
  // zellige palette. Distinct from Night (slate navy + cyan) and from
  // Special (black + bright gold).
  static const Color islamicPrimaryNavy = Color(0xFF0C1A3E); // Deep lapis
  static const Color islamicSecondaryNavy = Color(0xFF16294F); // Lighter lapis surface
  static const Color islamicAccentGold = Color(0xFFE8BC63); // Warm Andalusian gold
  static const Color islamicGlassWhite = Color(0x40FFFFFF); // Increased opacity (25%)
  static const Color islamicTextPrimary = Color(0xFFFFFFFF);
  static const Color islamicTextSecondary = Color(0xCCFFFFFF);
  static const Color islamicActiveGlow = Color(0xFFF0C97E); // Gold glow
  static const LinearGradient islamicBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0A1633), Color(0xFF142A5C), Color(0xFF0A1633)], // Royal lapis depth
  );

  // ========== ISLAMIC GREEN MODE COLORS ==========
  static const Color islamicGreenPrimary = Color(0xFF06201B); // Deep teal/green based on the new pattern
  static const Color islamicGreenSecondary = Color(0xFF0A2B25); // Slightly lighter for surfaces
  static const Color islamicGreenAccentGold = Color(0xFF1ABC9C); // Turquoise active glow for accent
  static const Color islamicGreenGlassWhite = Color(0x40FFFFFF); // Same 25% opacity
  static const Color islamicGreenTextPrimary = Color(0xFFFFFFFF);
  static const Color islamicGreenTextSecondary = Color(0xCCFFFFFF);
  static const Color islamicGreenActiveGlow = Color(0xFF1ABC9C); // Matching the teal/turquoise
  static const LinearGradient islamicGreenBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF041613), Color(0xFF08251F), Color(0xFF041613)], // Very deep backdrop for the green image
  );

  // ========== ISLAMIC SPECIAL MODE COLORS (Luxury Edition) ==========
  static const Color islamicSpecialPrimary = Color(0xFF0D0D0D); // Deep luxury dark
  static const Color islamicSpecialSecondary = Color(0xFF1A1A1A); // Slightly lighter for surfaces
  static const Color islamicSpecialAccentGold = Color(0xFFFFD700); // Brighter classic luxury gold
  static const Color islamicSpecialGlassWhite = Color(0x40FFFFFF); // 25% opacity white
  static const Color islamicSpecialTextPrimary = Color(0xFFFFFFFF); // Pure white for better contrast
  static const Color islamicSpecialTextSecondary = Color(0xFFE5C07B); // Brighter muted gold
  static const Color islamicSpecialActiveGlow = Color(0xFFD4AF37); // Glow gold
  static const LinearGradient islamicSpecialBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF000000), Color(0xFF0F0C05), Color(0xFF000000)], // Darker for more contrast
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
  static bool get isIslamicMode => AppThemeProvider.instance.isIslamicMode;
  static bool get isIslamicGreenMode => AppThemeProvider.instance.isIslamicGreenMode;
  static bool get isIslamicSpecialMode => AppThemeProvider.instance.isIslamicSpecialMode;
  static bool get isNightMode => AppThemeProvider.instance.isNightMode;

  /// Current background gradient based on theme
  static LinearGradient get currentBackgroundGradient {
    if (isLightMode) return lightBackgroundGradient;
    if (isIslamicMode) return islamicBackgroundGradient;
    if (isIslamicGreenMode) return islamicGreenBackgroundGradient;
    if (isIslamicSpecialMode) return islamicSpecialBackgroundGradient;
    return nightBackgroundGradient;
  }

  /// Current background image (only the Special luxury theme keeps a static
  /// image; Blue/Green Islamic themes use the procedural living background
  /// like Night mode for the animated lattice + aurora effects)
  static DecorationImage? get currentBackgroundImage {
    if (isIslamicSpecialMode) {
      return const DecorationImage(
        image: AssetImage('assets/images/islamic_bg_pattern_special.webp'),
        fit: BoxFit.cover,
        opacity: 0.65, 
      );
    }
    return null;
  }

  /// Current text primary color
  static Color get currentTextPrimary {
    if (isLightMode) return lightTextPrimary;
    if (isIslamicMode) return islamicTextPrimary;
    if (isIslamicGreenMode) return islamicGreenTextPrimary;
    if (isIslamicSpecialMode) return islamicSpecialTextPrimary;
    return nightTextPrimary;
  }

  /// Current text secondary color
  static Color get currentTextSecondary {
    if (isLightMode) return lightTextSecondary;
    if (isIslamicMode) return islamicTextSecondary;
    if (isIslamicGreenMode) return islamicGreenTextSecondary;
    if (isIslamicSpecialMode) return islamicSpecialTextSecondary;
    return nightTextSecondary;
  }

  /// Current active glow color
  static Color get currentActiveGlow {
    if (isLightMode) return lightActiveGlow;
    if (isIslamicMode) return islamicActiveGlow;
    if (isIslamicGreenMode) return islamicGreenActiveGlow;
    if (isIslamicSpecialMode) return islamicSpecialActiveGlow;
    return nightActiveGlow;
  }

  /// Current accent color
  static Color get currentAccent {
    if (isLightMode) return lightAccentBlue;
    if (isIslamicMode) return islamicAccentGold;
    if (isIslamicGreenMode) return islamicGreenAccentGold;
    if (isIslamicSpecialMode) return islamicSpecialAccentGold;
    return nightAccentBlue;
  }

  /// Current card/surface color
  static Color get currentSurface {
    if (isLightMode) return lightSurface;
    if (isIslamicMode) return islamicSecondaryNavy;
    if (isIslamicGreenMode) return islamicGreenSecondary;
    if (isIslamicSpecialMode) return islamicSpecialSecondary;
    return nightSecondaryNavy;
  }

  /// Current glass tint
  static Color get currentGlassTint {
    if (isLightMode) return lightGlassTint;
    if (isIslamicMode) return islamicGlassWhite;
    if (isIslamicGreenMode) return islamicGreenGlassWhite;
    if (isIslamicSpecialMode) return islamicSpecialGlassWhite;
    return nightGlassWhite;
  }

  // ========== ACCENT GRADIENTS (rings, pills, progress) ==========
  static const LinearGradient nightAccentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4FC3F7), Color(0xFF1E88E5)],
  );
  static const LinearGradient lightAccentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2E6FD0), Color(0xFF1A4C9E)],
  );
  static const LinearGradient islamicAccentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF0C97E), Color(0xFFC9963F)],
  );
  static const LinearGradient islamicGreenAccentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1ABC9C), Color(0xFF0E8C73)],
  );
  static const LinearGradient islamicSpecialAccentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFD700), Color(0xFFB8860B)],
  );

  /// Current accent gradient based on theme
  static LinearGradient get currentAccentGradient {
    if (isLightMode) return lightAccentGradient;
    if (isIslamicMode) return islamicAccentGradient;
    if (isIslamicGreenMode) return islamicGreenAccentGradient;
    if (isIslamicSpecialMode) return islamicSpecialAccentGradient;
    return nightAccentGradient;
  }

  /// Theme-tinted outer glow for active/highlighted cards.
  /// [intensity] scales the alpha (0..1); pass a custom [color] to override.
  static List<BoxShadow> glowShadow({Color? color, double intensity = 1.0}) {
    final glow = color ?? currentActiveGlow;
    final alphaScale = isLightMode ? 0.5 : 1.0; // softer in light mode
    return [
      BoxShadow(
        color: glow.withValues(alpha: 0.25 * intensity * alphaScale),
        blurRadius: 24,
        spreadRadius: -2,
      ),
      BoxShadow(
        color: glow.withValues(alpha: 0.12 * intensity * alphaScale),
        blurRadius: 48,
        spreadRadius: 2,
      ),
    ];
  }

  /// "Lit edge" gradient for glass borders: bright at the top where the
  /// imaginary light source hits, fading out toward the bottom.
  static LinearGradient get borderHighlightGradient {
    if (isLightMode) {
      return LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.9),
          lightDivider.withValues(alpha: 0.4),
        ],
      );
    }
    final accentTint = isIslamicSpecialMode
        ? islamicSpecialAccentGold
        : Colors.white;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        accentTint.withValues(alpha: isIslamicSpecialMode ? 0.45 : 0.35),
        Colors.white.withValues(alpha: 0.06),
      ],
    );
  }

  /// Current divider color
  static Color get currentDivider =>
      isLightMode ? lightDivider : Colors.white.withValues(alpha: 0.1);

  /// Inactive background (for unselected boxes, cards) - subtle but visible
  static Color get inactiveBackground =>
      isLightMode ? const Color(0xFFF5F0E4) : Colors.white.withValues(alpha: 0.05);

  /// Inactive border color - for unselected items
  static Color get inactiveBorder =>
      isLightMode ? lightDivider : Colors.white.withValues(alpha: 0.1);

  /// Icon secondary color - for subtle icons
  static Color get iconSecondary =>
      isLightMode ? lightTextSecondary : Colors.white.withValues(alpha: 0.5);

  // Glass card decoration - theme aware
  static BoxDecoration glassDecoration({
    double? opacity,
    double borderRadius = 24,
    BoxShape shape = BoxShape.rectangle,
  }) {
    if (isLightMode) {
      return BoxDecoration(
        color: Colors.white.withValues(alpha: opacity ?? 0.85),
        borderRadius: shape == BoxShape.circle ? null : BorderRadius.circular(borderRadius),
        shape: shape,
        border: Border.all(color: lightDivider.withValues(alpha: 0.8), width: 1),
        boxShadow: [
          // Warm-tinted shadow so cards lift off the parchment background
          BoxShadow(
            color: const Color(0xFF8A7A55).withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      );
    } else {
      // Unified minimal opacity (very transparent), but Special Edition gets a boost for visibility
      final defaultOpacity = isIslamicSpecialMode ? 0.15 : ((isIslamicMode || isIslamicGreenMode) ? 0.08 : 0.05);
      return BoxDecoration(
        color: Colors.white.withValues(alpha: opacity ?? defaultOpacity),
        borderRadius: shape == BoxShape.circle ? null : BorderRadius.circular(borderRadius),
        shape: shape,
        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      );
    }
  }

  /// Display style for clock digits, countdowns and other numerals.
  /// Space Grotesk gives the futuristic geometric look; tabular figures
  /// keep ticking digits from jittering horizontally. Digits are always
  /// Western (westernDigits), so no Arabic glyph support is needed here.
  static TextStyle displayDigits({
    double fontSize = 32,
    Color? color,
    FontWeight fontWeight = FontWeight.bold,
    double letterSpacing = 0.5,
  }) {
    return GoogleFonts.spaceGrotesk(
      fontSize: fontSize,
      color: color ?? currentTextPrimary,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
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

  // Islamic theme
  static ThemeData get islamicTheme {
    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: ColorScheme.fromSeed(
        seedColor: islamicAccentGold,
        brightness: Brightness.dark,
        surface: islamicPrimaryNavy,
      ),
      textTheme: _tajawalTextTheme(baseTheme.textTheme, false).apply(
        bodyColor: islamicTextPrimary,
        displayColor: islamicTextPrimary,
      ),
      primaryTextTheme: _tajawalTextTheme(baseTheme.primaryTextTheme, false).apply(
        bodyColor: islamicTextPrimary,
        displayColor: islamicTextPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.tajawal(
          color: islamicTextPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // Islamic Green theme
  static ThemeData get islamicGreenTheme {
    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: ColorScheme.fromSeed(
        seedColor: islamicGreenAccentGold,
        brightness: Brightness.dark,
        surface: islamicGreenPrimary,
      ),
      textTheme: _tajawalTextTheme(baseTheme.textTheme, false).apply(
        bodyColor: islamicGreenTextPrimary,
        displayColor: islamicGreenTextPrimary,
      ),
      primaryTextTheme: _tajawalTextTheme(baseTheme.primaryTextTheme, false).apply(
        bodyColor: islamicGreenTextPrimary,
        displayColor: islamicGreenTextPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.tajawal(
          color: islamicGreenTextPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // Islamic Special Theme
  static ThemeData get islamicSpecialTheme {
    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: ColorScheme.fromSeed(
        seedColor: islamicSpecialAccentGold,
        brightness: Brightness.dark,
        surface: islamicSpecialPrimary,
      ),
      textTheme: _tajawalTextTheme(baseTheme.textTheme, false).apply(
        bodyColor: islamicSpecialTextPrimary,
        displayColor: islamicSpecialTextPrimary,
      ),
      primaryTextTheme: _tajawalTextTheme(baseTheme.primaryTextTheme, false).apply(
        bodyColor: islamicSpecialTextPrimary,
        displayColor: islamicSpecialTextPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.tajawal(
          color: islamicSpecialTextPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Get current theme based on provider
  static ThemeData get currentTheme {
    if (isLightMode) return lightTheme;
    if (isIslamicMode) return islamicTheme;
    if (isIslamicGreenMode) return islamicGreenTheme;
    if (isIslamicSpecialMode) return islamicSpecialTheme;
    return darkTheme;
  }
}

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme mode enum - scalable for future themes
enum AppThemeMode {
  night, // Default dark theme
  light, // Light mode
}

/// Provider for app theme state with persistence
class AppThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'app_theme_mode';

  /// Singleton instance for global access
  static AppThemeProvider? _instance;
  static AppThemeProvider get instance {
    _instance ??= AppThemeProvider._();
    return _instance!;
  }

  AppThemeProvider._();

  AppThemeMode _mode = AppThemeMode.night;
  bool _initialized = false;

  /// Current theme mode
  AppThemeMode get mode => _mode;

  /// Convenience getters
  bool get isNightMode => _mode == AppThemeMode.night;
  bool get isLightMode => _mode == AppThemeMode.light;

  /// Initialize and load persisted theme
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString(_themeKey);

      if (savedMode != null) {
        _mode = AppThemeMode.values.firstWhere(
          (m) => m.name == savedMode,
          orElse: () => AppThemeMode.night,
        );
        debugPrint('[AppThemeProvider] Loaded theme: $_mode');
      }
    } catch (e) {
      debugPrint('[AppThemeProvider] Error loading theme: $e');
    }

    notifyListeners();
  }

  /// Set theme mode and persist
  Future<void> setTheme(AppThemeMode mode) async {
    if (_mode == mode) return;

    _mode = mode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, mode.name);
      debugPrint('[AppThemeProvider] Saved theme: $mode');
    } catch (e) {
      debugPrint('[AppThemeProvider] Error saving theme: $e');
    }
  }

  /// Toggle between night and light
  Future<void> toggleTheme() async {
    await setTheme(isNightMode ? AppThemeMode.light : AppThemeMode.night);
  }
}

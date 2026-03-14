import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'analytics_service.dart';

/// Alert mode for each prayer notification
enum AlertMode {
  sound, // Full notification with sound
  vibrate, // Silent but vibrates
  silent, // No sound, no vibration
}

/// Extension to convert AlertMode to/from int
extension AlertModeExtension on AlertMode {
  int get value {
    switch (this) {
      case AlertMode.sound:
        return 0;
      case AlertMode.vibrate:
        return 1;
      case AlertMode.silent:
        return 2;
    }
  }

  static AlertMode fromInt(int value) {
    switch (value) {
      case 1:
        return AlertMode.vibrate;
      case 2:
        return AlertMode.silent;
      default:
        return AlertMode.sound;
    }
  }

  /// Get next mode in cycle: sound -> vibrate -> silent -> sound
  AlertMode get next {
    switch (this) {
      case AlertMode.sound:
        return AlertMode.vibrate;
      case AlertMode.vibrate:
        return AlertMode.silent;
      case AlertMode.silent:
        return AlertMode.sound;
    }
  }
}

/// Service to manage per-prayer alert mode settings
class AlertModeService {
  static const _keyPrefix = 'prayer_alert_mode_';

  // Prayer keys
  static const prayerKeys = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Load all alert modes from cache
  Future<Map<String, AlertMode>> loadAlertModes() async {
    final prefs = await _preferences;
    final modes = <String, AlertMode>{};

    for (final key in prayerKeys) {
      final value = prefs.getInt('$_keyPrefix$key') ?? 0;
      modes[key] = AlertModeExtension.fromInt(value);
    }

    debugPrint('[AlertModeService] Loaded modes: $modes');
    return modes;
  }

  /// Save alert mode for a specific prayer
  Future<void> saveAlertMode(String prayerKey, AlertMode mode) async {
    final prefs = await _preferences;
    await prefs.setInt('$_keyPrefix$prayerKey', mode.value);
    AnalyticsService.instance.logAlertModeChanged(prayerKey, mode.name);
    debugPrint('[AlertModeService] Saved $prayerKey = $mode');
  }

  /// Get alert mode for a specific prayer
  Future<AlertMode> getAlertMode(String prayerKey) async {
    final prefs = await _preferences;
    final value = prefs.getInt('$_keyPrefix$prayerKey') ?? 0;
    return AlertModeExtension.fromInt(value);
  }
}

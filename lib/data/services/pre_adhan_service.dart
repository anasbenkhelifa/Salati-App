import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage pre-adhan reminder notifications
/// Allows users to get a notification X minutes before each prayer
class PreAdhanService {
  static const _keyPrefix = 'pre_adhan_';
  static const _keyEnabled = 'pre_adhan_enabled';
  static const _keyMinutes = 'pre_adhan_minutes_';

  // Prayer keys
  static const prayerKeys = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];

  // Default reminder time in minutes
  static const defaultMinutes = 15;

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Check if pre-adhan reminders are globally enabled
  Future<bool> isEnabled() async {
    final prefs = await _preferences;
    return prefs.getBool(_keyEnabled) ?? false;
  }

  /// Enable or disable pre-adhan reminders globally
  Future<void> setEnabled(bool enabled) async {
    final prefs = await _preferences;
    await prefs.setBool(_keyEnabled, enabled);
    debugPrint('[PreAdhanService] Global enabled: $enabled');
  }

  /// Get reminder minutes for a specific prayer
  Future<int> getMinutes(String prayerKey) async {
    final prefs = await _preferences;
    return prefs.getInt('$_keyMinutes$prayerKey') ?? defaultMinutes;
  }

  /// Set reminder minutes for a specific prayer
  Future<void> setMinutes(String prayerKey, int minutes) async {
    final prefs = await _preferences;
    await prefs.setInt('$_keyMinutes$prayerKey', minutes);
    debugPrint('[PreAdhanService] $prayerKey reminder: $minutes min');
  }

  /// Check if reminder is enabled for a specific prayer
  Future<bool> isPrayerReminderEnabled(String prayerKey) async {
    final prefs = await _preferences;
    return prefs.getBool('$_keyPrefix$prayerKey') ?? true; // Default on
  }

  /// Enable or disable reminder for a specific prayer
  Future<void> setPrayerReminderEnabled(String prayerKey, bool enabled) async {
    final prefs = await _preferences;
    await prefs.setBool('$_keyPrefix$prayerKey', enabled);
    debugPrint('[PreAdhanService] $prayerKey reminder enabled: $enabled');
  }

  /// Get all reminder settings as a map
  Future<Map<String, ({bool enabled, int minutes})>> getAllSettings() async {
    final result = <String, ({bool enabled, int minutes})>{};

    for (final key in prayerKeys) {
      final enabled = await isPrayerReminderEnabled(key);
      final minutes = await getMinutes(key);
      result[key] = (enabled: enabled, minutes: minutes);
    }

    return result;
  }
}

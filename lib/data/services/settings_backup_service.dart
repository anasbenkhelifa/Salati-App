import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Export/import of user settings as a JSON file. Whitelisted keys only —
/// caches (30-day prayer times, Hijri per-date entries) are intentionally
/// excluded: they rebuild themselves and would bloat the file.
class SettingsBackupService {
  static const _marker = 'salati_backup';
  static const _version = 1;

  static const List<String> _exactKeys = [
    // Preferences
    'app_language',
    'app_theme_mode',
    'hijri_offset',
    'live_notification_mode',
    'pre_adhan_enabled',
    'max_volume_override',
    'show_sunrise',
    'kahf_reminder_enabled',
    'compass_haptics_enabled',
    'adhan_selections',
    // Location + setup state (restore = instantly working app)
    'cached_setup_done',
    'cached_lat',
    'cached_lng',
    'cached_elevation',
    'cached_city_en',
    'cached_city_ar',
    'cached_country_en',
    'cached_country_ar',
    'cached_location_source',
    'cached_method_id',
    'cached_is_manual_method',
    'cached_madhab_id',
    'settings_method',
    'settings_madhab',
    'location_name_en',
    'location_name_ar',
  ];

  static const List<String> _prefixes = [
    'prayer_alert_mode_',
    'fasting_log_',
  ];

  static bool _included(String key) =>
      _exactKeys.contains(key) || _prefixes.any(key.startsWith);

  static Map<String, dynamic>? _encode(Object value) {
    if (value is bool) return {'t': 'b', 'v': value};
    if (value is int) return {'t': 'i', 'v': value};
    if (value is double) return {'t': 'd', 'v': value};
    if (value is String) return {'t': 's', 'v': value};
    if (value is List<String>) return {'t': 'l', 'v': value};
    return null;
  }

  /// Write settings to a JSON file and open the share sheet.
  static Future<bool> exportSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = <String, dynamic>{};
      for (final key in prefs.getKeys()) {
        if (!_included(key)) continue;
        final value = prefs.get(key);
        if (value == null) continue;
        final encoded = _encode(value);
        if (encoded != null) data[key] = encoded;
      }

      final payload = jsonEncode({
        _marker: _version,
        'exported_at': DateTime.now().toIso8601String(),
        'data': data,
      });

      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now().toIso8601String().substring(0, 10);
      final file = File('${dir.path}/salati_settings_$stamp.json');
      await file.writeAsString(payload);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Salati settings backup',
        ),
      );
      return true;
    } catch (e) {
      debugPrint('[SettingsBackupService] Export failed: $e');
      return false;
    }
  }

  /// Pick a backup file and restore the settings it contains.
  /// Returns true on success, false on cancel/invalid file.
  static Future<bool> importSettings() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      final path = result?.files.single.path;
      if (path == null) return false;

      final decoded = jsonDecode(await File(path).readAsString());
      if (decoded is! Map || decoded[_marker] == null) return false;
      final data = decoded['data'];
      if (data is! Map) return false;

      final prefs = await SharedPreferences.getInstance();
      var restored = 0;
      for (final entry in data.entries) {
        final key = entry.key.toString();
        // Never restore keys outside the whitelist, whatever the file says
        if (!_included(key)) continue;
        final item = entry.value;
        if (item is! Map) continue;
        final v = item['v'];
        switch (item['t']) {
          case 'b':
            if (v is bool) await prefs.setBool(key, v);
            break;
          case 'i':
            if (v is num) await prefs.setInt(key, v.toInt());
            break;
          case 'd':
            if (v is num) await prefs.setDouble(key, v.toDouble());
            break;
          case 's':
            if (v is String) await prefs.setString(key, v);
            break;
          case 'l':
            if (v is List) {
              await prefs.setStringList(
                key,
                v.map((e) => e.toString()).toList(),
              );
            }
            break;
          default:
            continue;
        }
        restored++;
      }

      debugPrint('[SettingsBackupService] Restored $restored keys');
      return restored > 0;
    } catch (e) {
      debugPrint('[SettingsBackupService] Import failed: $e');
      return false;
    }
  }
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local prayer journal: which prayers were marked as prayed, per day.
/// Stored as 'prayer_log_yyyy-MM-dd' → {"fajr":true,...}. Fully offline,
/// deliberately quiet — no notifications, no penalties.
class PrayerLogService {
  PrayerLogService._();
  static final PrayerLogService instance = PrayerLogService._();

  static const List<String> prayerKeys = [
    'fajr', 'dhuhr', 'asr', 'maghrib', 'isha',
  ];

  String _keyFor(DateTime day) =>
      'prayer_log_${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  Future<Map<String, bool>> loadDay(DateTime day) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyFor(day));
    if (raw == null) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return {for (final e in map.entries) e.key: e.value == true};
    } catch (e) {
      debugPrint('[PrayerLogService] Corrupt day entry: $e');
      return {};
    }
  }

  Future<void> setPrayed(DateTime day, String prayerKey, bool prayed) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await loadDay(day);
    current[prayerKey] = prayed;
    await prefs.setString(_keyFor(day), jsonEncode(current));
  }

  /// Last [days] days, oldest first (last element = today).
  Future<List<Map<String, bool>>> loadLastDays(int days) async {
    final now = DateTime.now();
    final result = <Map<String, bool>>[];
    for (int i = days - 1; i >= 0; i--) {
      result.add(await loadDay(now.subtract(Duration(days: i))));
    }
    return result;
  }

  static bool isDayComplete(Map<String, bool> day) =>
      prayerKeys.every((k) => day[k] == true);

  /// Consecutive fully-prayed days ending today (today itself doesn't have
  /// to be complete yet — an in-progress day never breaks the streak).
  Future<int> currentStreak() async {
    final now = DateTime.now();
    int streak = 0;
    // Today counts only when complete
    if (isDayComplete(await loadDay(now))) streak++;
    for (int i = 1; i <= 365; i++) {
      final day = await loadDay(now.subtract(Duration(days: i)));
      if (isDayComplete(day)) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }
}

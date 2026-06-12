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

  /// Mark unanswered prayers as missed (explicit false) once their window
  /// closed: for past days every unmarked prayer, for today every prayer
  /// whose NEXT prayer has already arrived. Days before the journal first
  /// existed stay untouched. The user can still flip any value later.
  Future<void> reconcile() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('prayer_journal_enabled') ?? true)) return;

    final now = DateTime.now();
    String dateKey(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    // First-use marker: never back-fill "missed" onto days before the
    // journal existed
    var since = prefs.getString('prayer_journal_since');
    if (since == null) {
      since = dateKey(now);
      await prefs.setString('prayer_journal_since', since);
    }

    // Past 7 days: unmarked → missed
    for (int i = 1; i <= 7; i++) {
      final day = now.subtract(Duration(days: i));
      if (dateKey(day).compareTo(since) < 0) break;
      final log = await loadDay(day);
      var changed = false;
      for (final key in prayerKeys) {
        if (!log.containsKey(key)) {
          log[key] = false;
          changed = true;
        }
      }
      if (changed) {
        await prefs.setString(_keyFor(day), jsonEncode(log));
      }
    }

    // Today: a prayer becomes missed once the NEXT prayer's time arrives
    final raw = prefs.getString('cached_prayer_times_by_date');
    if (raw == null) return;
    Map<String, dynamic> byDate;
    try {
      byDate = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final today = byDate[dateKey(now)];
    if (today is! Map) return;

    const apiNames = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    DateTime? parse(Object? s) {
      if (s is! String) return null;
      final parts = s.split(':');
      if (parts.length < 2) return null;
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1].split(' ')[0]);
      if (h == null || m == null) return null;
      return DateTime(now.year, now.month, now.day, h, m);
    }

    final log = await loadDay(now);
    var changed = false;
    for (int i = 0; i < prayerKeys.length - 1; i++) {
      if (log.containsKey(prayerKeys[i])) continue;
      final nextTime = parse(today[apiNames[i + 1]]);
      if (nextTime != null && now.isAfter(nextTime)) {
        log[prayerKeys[i]] = false;
        changed = true;
      }
    }
    if (changed) {
      await prefs.setString(_keyFor(now), jsonEncode(log));
    }
  }

  /// Number of prayers marked prayed between [from] and today inclusive.
  Future<int> countPrayedSince(DateTime from) async {
    final now = DateTime.now();
    var day = DateTime(from.year, from.month, from.day);
    final end = DateTime(now.year, now.month, now.day);
    int total = 0;
    while (!day.isAfter(end)) {
      final log = await loadDay(day);
      total += log.values.where((v) => v).length;
      day = day.add(const Duration(days: 1));
    }
    return total;
  }

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

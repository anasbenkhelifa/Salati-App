import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hijri date model
class HijriDate {
  final int day;
  final int month;
  final int year;
  final String monthNameAr;
  final String monthNameEn;
  final String weekdayAr;
  final String weekdayEn;

  HijriDate({
    required this.day,
    required this.month,
    required this.year,
    required this.monthNameAr,
    required this.monthNameEn,
    required this.weekdayAr,
    required this.weekdayEn,
  });

  /// Format for display (Arabic) - simple format with RLM marks
  /// Output: "3 رجب 1447" (day month year, readable order)
  String formatArabic() {
    // Use RLM (Right-to-Left Mark) to ensure proper Arabic display
    // The string is: day monthName year (all with western digits)
    return '\u200F$day $monthNameAr $year\u200F';
  }

  /// Format for display (English) - LTR, no special handling needed
  String formatEnglish() => '$day $monthNameEn $year AH';

  /// Factory from UmmahAPI response (legacy support for cache)
  factory HijriDate.fromUmmahApi(Map<String, dynamic> json) {
    final hijri = json['data']?['hijri'] ?? {};
    final gregorian = json['data']?['gregorian'] ?? {};

    return HijriDate(
      day: hijri['day'] ?? 1,
      month: hijri['month'] ?? 1,
      year: hijri['year'] ?? 1446,
      monthNameAr: hijri['month_name_arabic'] ?? '',
      monthNameEn: hijri['month_name'] ?? '',
      weekdayAr: '', 
      weekdayEn: gregorian['day_of_week'] ?? '',
    );
  }

  /// Factory from cached JSON
  factory HijriDate.fromCacheJson(Map<String, dynamic> json) {
    return HijriDate(
      day: json['day'] ?? 1,
      month: json['month'] ?? 1,
      year: json['year'] ?? 1446,
      monthNameAr: json['monthNameAr'] ?? '',
      monthNameEn: json['monthNameEn'] ?? '',
      weekdayAr: json['weekdayAr'] ?? '',
      weekdayEn: json['weekdayEn'] ?? '',
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
    'day': day,
    'month': month,
    'year': year,
    'monthNameAr': monthNameAr,
    'monthNameEn': monthNameEn,
    'weekdayAr': weekdayAr,
    'weekdayEn': weekdayEn,
  };
}

/// Service to fetch Hijri dates natively (offline)
/// Uses package: hijri (replaces UmmahAPI)
class HijriDateService {
  /// Fetch Hijri date natively for a given Gregorian date
  Future<HijriDate?> getHijriDate(DateTime gregorianDate) async {
    try {
      // Bug 3 Fix: The hijri package uses a global singleton for locale.
      // We MUST extract the localized string eagerly BEFORE switching the locale.
      HijriCalendar.setLocal('ar');
      final hijriAr = HijriCalendar.fromDate(gregorianDate);
      final monthNameAr = hijriAr.getLongMonthName();
      final weekdayAr = hijriAr.getDayName();

      HijriCalendar.setLocal('en');
      final hijriEn = HijriCalendar.fromDate(gregorianDate);
      final monthNameEn = hijriEn.getLongMonthName();
      
      return HijriDate(
        day: hijriEn.hDay,
        month: hijriEn.hMonth,
        year: hijriEn.hYear,
        monthNameAr: monthNameAr,
        monthNameEn: monthNameEn,
        weekdayAr: weekdayAr,
        weekdayEn: DateFormat('EEEE').format(gregorianDate),
      );
    } catch (e) {
      return null;
    }
  }

  /// Get the currently saved user offset for Hijri date (in days)
  Future<int> getHijriOffset() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('hijri_offset') ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Save the user offset for Hijri date (in days)
  Future<void> setHijriOffset(int offsetDays) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('hijri_offset', offsetDays);
      
      // Auto-refresh the multi-day Android cache so live notification updates instantly
      await cacheUpcomingDays();
    } catch (e) {
      debugPrint('[HijriDateService] Error saving offset: $e');
    }
  }

  /// Fetch Hijri date natively for a given Gregorian date, with user offset applied.
  /// This ensures all parts of the app (UI, notifications) share the exact same date.
  Future<HijriDate?> getAdjustedHijriDate(DateTime gregorianDate) async {
    final offsetDays = await getHijriOffset();
    // Mathematically, adjusting the Gregorian input by N days shifts the resulting Hijri date by N days
    final adjustedGregorian = gregorianDate.add(Duration(days: offsetDays));
    return getHijriDate(adjustedGregorian);
  }

  /// Number of days of Hijri dates to pre-cache for the native Android side.
  /// Matches the 30-day prayer times cache so both stay accurate offline
  /// for the same window.
  static const int daysToCacheAhead = 30;

  /// Cache the next [daysToCacheAhead] days of Hijri dates to SharedPreferences.
  /// Bug 4 Fix: The native Android Foreground Service relies entirely on this cache being present
  /// (under flutter.hijri_date_YYYY-MM-DD keys). Without it, the Android service falls back to a
  /// crude mathematical Gregorian->Hijri converter that breaks and reads as 2 months behind.
  Future<void> cacheUpcomingDays() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();

      // Prune per-date entries for days that have already passed so the
      // prefs file doesn't grow forever (each refresh writes 30 new keys).
      final todayKey =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      for (final key in prefs.getKeys()) {
        if (key.startsWith('hijri_date_') &&
            key.substring('hijri_date_'.length).compareTo(todayKey) < 0) {
          await prefs.remove(key);
        }
      }

      // Write precisely formatted JSON strings identically to the old UmmahAPI format
      for (int i = 0; i < daysToCacheAhead; i++) {
        final date = now.add(Duration(days: i));
        final key = 'hijri_date_${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

        final hijriDate = await getAdjustedHijriDate(date);
        if (hijriDate != null) {
          final jsonString = jsonEncode({
            'day': hijriDate.day,
            'month': hijriDate.month,
            'year': hijriDate.year,
            'monthNameAr': hijriDate.monthNameAr,
            'monthNameEn': hijriDate.monthNameEn,
          });
          await prefs.setString(key, jsonString);
        }
      }

      // Keep legacy timestamp for Android fallback mechanics
      await prefs.setInt('cached_hijri_updated_at', DateTime.now().millisecondsSinceEpoch);
      debugPrint('[HijriDateService] Pre-cached $daysToCacheAhead days of Hijri dates for native Android Service');
    } catch (e) {
      debugPrint('[HijriDateService] Error caching upcoming Hijri days: $e');
    }
  }

  /// Keep for legacy API backward compatibility
  Future<void> clearCache() async {}
}

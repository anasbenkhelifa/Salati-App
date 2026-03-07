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
      // Configure default locale to AR to extract arabic strings natively
      HijriCalendar.setLocal('ar');
      final hijriAr = HijriCalendar.fromDate(gregorianDate);

      // Configure default locale to EN to extract english strings natively
      HijriCalendar.setLocal('en');
      final hijriEn = HijriCalendar.fromDate(gregorianDate);
      
      return HijriDate(
        day: hijriEn.hDay,
        month: hijriEn.hMonth,
        year: hijriEn.hYear,
        monthNameAr: hijriAr.getLongMonthName(),
        monthNameEn: hijriEn.getLongMonthName(),
        weekdayAr: hijriAr.getDayName(),
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

  /// No-op: API caches are no longer necessary for native calculations
  Future<void> clearCache() async {}
}

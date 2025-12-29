import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

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

  /// Factory from UmmahAPI response
  factory HijriDate.fromUmmahApi(Map<String, dynamic> json) {
    final hijri = json['data']?['hijri'] ?? {};
    final gregorian = json['data']?['gregorian'] ?? {};

    return HijriDate(
      day: hijri['day'] ?? 1,
      month: hijri['month'] ?? 1,
      year: hijri['year'] ?? 1446,
      monthNameAr: hijri['month_name_arabic'] ?? '',
      monthNameEn: hijri['month_name'] ?? '',
      weekdayAr: '', // UmmahAPI doesn't provide Arabic weekday directly
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

  /// Convert to JSON for caching
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

/// Service to fetch and cache Hijri dates
/// Uses UmmahAPI: https://www.ummahapi.com/
class HijriDateService {
  static const String _baseUrl = 'https://www.ummahapi.com/api/hijri-date';
  static const String _cachePrefix = 'hijri_date_';

  /// Fetch Hijri date for a given Gregorian date
  /// Uses cache if available for the same day
  Future<HijriDate?> getHijriDate(DateTime gregorianDate) async {
    final dateKey = DateFormat('yyyy-MM-dd').format(gregorianDate);

    // Try cache first
    final cached = await _loadFromCache(dateKey);
    if (cached != null) {
      debugPrint('[HijriDateService] Using cached date for $dateKey');
      return cached;
    }

    // Fetch from API
    try {
      // UmmahAPI format: /api/hijri-date?date=YYYY-MM-DD
      final url = '$_baseUrl?date=$dateKey';
      debugPrint('[HijriDateService] Fetching: $url');

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          final hijriDate = HijriDate.fromUmmahApi(json);

          // Cache the result
          await _saveToCache(dateKey, hijriDate);
          debugPrint(
            '[HijriDateService] Fetched and cached: ${hijriDate.formatEnglish()}',
          );

          return hijriDate;
        } else {
          debugPrint('[HijriDateService] API error: ${json['message']}');
          return null;
        }
      } else {
        debugPrint('[HijriDateService] HTTP error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('[HijriDateService] Error: $e');
      return null;
    }
  }

  /// Load from cache
  Future<HijriDate?> _loadFromCache(String dateKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('$_cachePrefix$dateKey');
      if (jsonStr != null) {
        final json = jsonDecode(jsonStr);
        return HijriDate.fromCacheJson(json);
      }
    } catch (e) {
      debugPrint('[HijriDateService] Cache load error: $e');
    }
    return null;
  }

  /// Save to cache - writes display strings that native Android can read
  Future<void> _saveToCache(String dateKey, HijriDate date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(date.toJson());
      await prefs.setString('$_cachePrefix$dateKey', jsonStr);

      // Build the display strings
      final displayAr = date.formatArabic();
      final displayEn = date.formatEnglish();

      // Save display strings for native Android notification
      // shared_preferences automatically prefixes with "flutter." in the actual file
      await prefs.setString('cached_hijri_display_ar', displayAr);
      await prefs.setString('cached_hijri_display_en', displayEn);

      // Save timestamp to know when cache was updated
      await prefs.setInt(
        'cached_hijri_updated_at',
        DateTime.now().millisecondsSinceEpoch,
      );

      debugPrint('[HijriDateService] ========= HIJRI CACHE SAVED =========');
      debugPrint(
        '[HijriDateService] Date: ${date.day} ${date.monthNameEn} ${date.year}',
      );
      debugPrint('[HijriDateService] Display AR saved: "$displayAr"');
      debugPrint('[HijriDateService] Display EN saved: "$displayEn"');
      debugPrint('[HijriDateService] =====================================');
    } catch (e) {
      debugPrint('[HijriDateService] Cache save error: $e');
    }
  }
}

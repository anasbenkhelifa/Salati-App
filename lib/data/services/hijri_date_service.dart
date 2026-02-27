import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'foreground_service_bridge.dart';

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
  static const int _prefetchDays = 7; // Pre-fetch next 7 days

  /// Fetch Hijri date for a given Gregorian date
  /// Uses cache if available, falls back to API, then tries yesterday's cache
  Future<HijriDate?> getHijriDate(DateTime gregorianDate) async {
    final dateKey = DateFormat('yyyy-MM-dd').format(gregorianDate);

    // Try cache first
    final cached = await _loadFromCache(dateKey);
    if (cached != null) {
      debugPrint('[HijriDateService] Using cached date for $dateKey');

      // Trigger background prefetch of next 7 days (non-blocking)
      _prefetchNextDaysInBackground(gregorianDate);

      return cached;
    }

    // Fetch from API
    final fetched = await _fetchFromApi(dateKey);
    if (fetched != null) {
      // Trigger background prefetch of next 7 days
      _prefetchNextDaysInBackground(gregorianDate);
      return fetched;
    }

    // OFFLINE FALLBACK: Try to use yesterday's cached date + 1 day
    debugPrint('[HijriDateService] Trying offline fallback...');
    final yesterday = gregorianDate.subtract(const Duration(days: 1));
    final yesterdayKey = DateFormat('yyyy-MM-dd').format(yesterday);
    final yesterdayCache = await _loadFromCache(yesterdayKey);

    if (yesterdayCache != null) {
      // Increment the Hijri day (simple approximation for offline)
      final fallbackDate = _incrementHijriDay(yesterdayCache);
      debugPrint(
        '[HijriDateService] Using fallback from yesterday: ${fallbackDate.formatEnglish()}',
      );

      // Cache this fallback so it's available immediately next time
      await _saveToCache(dateKey, fallbackDate);

      return fallbackDate;
    }

    debugPrint('[HijriDateService] No cache or fallback available');
    return null;
  }

  /// Pre-fetch next N days in background (non-blocking)
  void _prefetchNextDaysInBackground(DateTime startDate) {
    // Run in background without awaiting
    Future(() async {
      debugPrint(
        '[HijriDateService] Starting background prefetch of $_prefetchDays days...',
      );

      for (int i = 1; i <= _prefetchDays; i++) {
        final futureDate = startDate.add(Duration(days: i));
        final dateKey = DateFormat('yyyy-MM-dd').format(futureDate);

        // Skip if already cached
        final existing = await _loadFromCache(dateKey);
        if (existing != null) continue;

        // Fetch and cache
        await _fetchFromApi(dateKey);

        // Small delay between requests to be nice to the API
        await Future.delayed(const Duration(milliseconds: 200));
      }

      debugPrint('[HijriDateService] Background prefetch complete');
    });
  }

  /// Fetch from API and cache result
  Future<HijriDate?> _fetchFromApi(String dateKey) async {
    try {
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

  /// Increment Hijri day by 1 (for offline fallback)
  /// Handles month/year rollover approximately
  HijriDate _incrementHijriDay(HijriDate date) {
    int newDay = date.day + 1;
    int newMonth = date.month;
    int newYear = date.year;

    // Hijri months alternate 30/29 days (approximately)
    // Use 30 as threshold for simplicity
    if (newDay > 30) {
      newDay = 1;
      newMonth++;
      if (newMonth > 12) {
        newMonth = 1;
        newYear++;
      }
    }

    // Get month names for new month
    final monthNamesAr = [
      '',
      'محرم',
      'صفر',
      'ربيع الأول',
      'ربيع الثاني',
      'جمادى الأولى',
      'جمادى الثانية',
      'رجب',
      'شعبان',
      'رمضان',
      'شوال',
      'ذو القعدة',
      'ذو الحجة',
    ];
    final monthNamesEn = [
      '',
      'Muharram',
      'Safar',
      'Rabi al-Awwal',
      'Rabi al-Thani',
      'Jumada al-Awwal',
      'Jumada al-Thani',
      'Rajab',
      'Shaban',
      'Ramadan',
      'Shawwal',
      'Dhul Qadah',
      'Dhul Hijjah',
    ];

    return HijriDate(
      day: newDay,
      month: newMonth,
      year: newYear,
      monthNameAr: newMonth <= 12 ? monthNamesAr[newMonth] : date.monthNameAr,
      monthNameEn: newMonth <= 12 ? monthNamesEn[newMonth] : date.monthNameEn,
      weekdayAr: date.weekdayAr,
      weekdayEn: date.weekdayEn,
    );
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
  /// Only saves display strings for today's date (not prefetched future dates)
  Future<void> _saveToCache(String dateKey, HijriDate date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(date.toJson());
      await prefs.setString('$_cachePrefix$dateKey', jsonStr);

      // Only update display strings if this is TODAY's date
      // This prevents prefetched future dates from overwriting today's display
      final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
      if (dateKey == todayKey) {
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

        // Trigger live notification refresh so it shows the new date
        ForegroundServiceBridge.refreshNotification();
      } else {
        debugPrint(
          '[HijriDateService] Cached future date $dateKey (not updating display)',
        );
      }
    } catch (e) {
      debugPrint('[HijriDateService] Cache save error: $e');
    }
  }
}

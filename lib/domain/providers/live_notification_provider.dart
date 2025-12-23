import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/services/foreground_service_bridge.dart';
import '../../data/services/prayer_times_api_service.dart';
import '../../data/services/prayer_times_cache_service.dart';
import '../../data/services/hijri_date_service.dart';
import '../../core/localization/western_digits.dart';

/// Provider to manage the live prayer notification with countdown
/// Uses CACHE ONLY for offline-first behavior - NO network calls
class LiveNotificationProvider extends ChangeNotifier {
  final PrayerTimesCacheService _cacheService = PrayerTimesCacheService();
  final HijriDateService _hijriService = HijriDateService();

  Timer? _updateTimer;
  CachedAppState? _cachedState;
  HijriDate? _hijriDate;

  String _locationName = '';
  bool _isArabic = false;
  bool _isRunning = false;

  // Grace window: 30 minutes after a prayer
  static const int _graceWindowMinutes = 30;

  // Prayer names
  static const List<String> _prayerNamesEn = [
    'Fajr',
    'Dhuhr',
    'Asr',
    'Maghrib',
    'Isha',
  ];
  static const List<String> _prayerNamesAr = [
    'الفجر',
    'الظهر',
    'العصر',
    'المغرب',
    'العشاء',
  ];

  /// Start the live notification service - LOADS FROM CACHE ONLY
  Future<void> start({
    required String locationName,
    required bool isArabic,
    required double latitude,
    required double longitude,
  }) async {
    if (_isRunning) return;
    _isRunning = true;

    _locationName = locationName;
    _isArabic = isArabic;

    // Load from CACHE ONLY - no network calls
    _cachedState = await _cacheService.loadAppState();

    if (_cachedState == null || _cachedState!.prayerTimes == null) {
      // No cache - show setup message
      await ForegroundServiceBridge.startService(
        title: isArabic ? 'تطبيق الأذان' : 'Adhan App',
        body:
            isArabic
                ? 'افتح التطبيق لإكمال الإعداد'
                : 'Open app to finish setup',
      );
      debugPrint('[LiveNotificationProvider] No cached data available');
      return;
    }

    // Load Hijri date from cache
    _hijriDate = await _hijriService.getHijriDate(DateTime.now());

    // Build initial content and start foreground service IMMEDIATELY
    final title = _buildTitle(DateTime.now());
    final body = _buildBodyFromCache(DateTime.now());
    await ForegroundServiceBridge.startService(title: title, body: body);

    debugPrint('[LiveNotificationProvider] Started from cache: $body');

    // Start the update timer (every second)
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateNotification();
    });
  }

  /// Update language setting - ONLY changes labels, no data refetch
  void updateLanguage(bool isArabic) {
    _isArabic = isArabic;
    _updateNotification();
  }

  /// Update location name - ONLY changes display name
  Future<void> updateLocation({
    required String locationName,
    required double latitude,
    required double longitude,
  }) async {
    _locationName = locationName;
    // Reload cache to get latest data
    _cachedState = await _cacheService.loadAppState();
    _updateNotification();
  }

  /// Get prayer times as DateTime list from cached timings
  List<DateTime> _getPrayerTimes(AlAdhanTimings timings, DateTime date) {
    final times = <DateTime>[];

    for (final timeStr in [
      timings.fajr,
      timings.dhuhr,
      timings.asr,
      timings.maghrib,
      timings.isha,
    ]) {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final hour = int.tryParse(parts[0]) ?? 0;
        final minute = int.tryParse(parts[1].split(' ')[0]) ?? 0;
        times.add(DateTime(date.year, date.month, date.day, hour, minute));
      }
    }

    return times;
  }

  /// Update the notification with current countdown
  void _updateNotification() {
    if (_cachedState == null || _cachedState!.prayerTimes == null) return;

    final now = DateTime.now();
    final title = _buildTitle(now);
    final body = _buildBodyFromCache(now);

    ForegroundServiceBridge.updateNotification(title: title, body: body);
  }

  /// Build notification body from CACHED data only
  String _buildBodyFromCache(DateTime now) {
    if (_cachedState == null || _cachedState!.prayerTimes == null) {
      return _isArabic ? 'افتح التطبيق للإعداد' : 'Open app to setup';
    }

    final timings = _cachedState!.prayerTimes!.timings;
    final today = DateTime(now.year, now.month, now.day);
    final todayTimes = _getPrayerTimes(timings, today);

    // Find the last and next prayers
    int? lastPrayerIndex;
    DateTime? lastPrayerTime;
    int? nextPrayerIndex;
    DateTime? nextPrayerTime;
    bool isGraceWindow = false;

    // Check each prayer time
    for (int i = 0; i < todayTimes.length; i++) {
      if (now.isBefore(todayTimes[i])) {
        // Found next prayer
        nextPrayerIndex = i;
        nextPrayerTime = todayTimes[i];
        break;
      } else {
        // This prayer has passed
        lastPrayerIndex = i;
        lastPrayerTime = todayTimes[i];
      }
    }

    // Check for grace window (within 30 min after last prayer)
    if (lastPrayerTime != null) {
      final elapsed = now.difference(lastPrayerTime);
      if (elapsed.inMinutes < _graceWindowMinutes) {
        isGraceWindow = true;
      }
    }

    // If all today's prayers have passed, next is tomorrow's Fajr
    if (nextPrayerIndex == null) {
      nextPrayerIndex = 0; // Fajr
      // Use today's Fajr time + 1 day as estimate
      if (todayTimes.isNotEmpty) {
        nextPrayerTime = todayTimes[0].add(const Duration(days: 1));
      }
    }

    return _buildBody(
      now: now,
      isGraceWindow: isGraceWindow,
      lastPrayerIndex: lastPrayerIndex,
      lastPrayerTime: lastPrayerTime,
      nextPrayerIndex: nextPrayerIndex,
      nextPrayerTime: nextPrayerTime,
    );
  }

  /// Build the notification title (Location | Hijri Date)
  String _buildTitle(DateTime now) {
    String dateStr;
    if (_hijriDate != null) {
      // Use Hijri date
      final hijri =
          _isArabic ? _hijriDate!.formatArabic() : _hijriDate!.formatEnglish();
      dateStr = westernDigits(hijri);
    } else {
      // Fallback to Gregorian if Hijri not available
      final dateFormat = DateFormat('EEE dd MMM', _isArabic ? 'ar' : 'en');
      dateStr = westernDigits(dateFormat.format(now));
    }
    return '$_locationName  |  $dateStr';
  }

  /// Build the notification body with countdown
  String _buildBody({
    required DateTime now,
    required bool isGraceWindow,
    int? lastPrayerIndex,
    DateTime? lastPrayerTime,
    int? nextPrayerIndex,
    DateTime? nextPrayerTime,
  }) {
    final prayerNames = _isArabic ? _prayerNamesAr : _prayerNamesEn;

    if (isGraceWindow && lastPrayerIndex != null && lastPrayerTime != null) {
      // Grace window mode: show negative counter from last prayer
      final elapsed = now.difference(lastPrayerTime);
      final countdownStr = _formatDuration(elapsed, isNegative: true);
      final prayerName = prayerNames[lastPrayerIndex];
      final timeStr = _formatPrayerTime(lastPrayerTime);

      if (_isArabic) {
        return '$countdownStr  $prayerName، $timeStr';
      } else {
        return '$countdownStr  $prayerName, $timeStr';
      }
    } else if (nextPrayerIndex != null && nextPrayerTime != null) {
      // Normal mode: show positive counter to next prayer
      final remaining = nextPrayerTime.difference(now);
      final countdownStr = _formatDuration(remaining, isNegative: false);
      final prayerName = prayerNames[nextPrayerIndex];
      final timeStr = _formatPrayerTime(nextPrayerTime);

      if (_isArabic) {
        return '$countdownStr  $prayerName، $timeStr';
      } else {
        return '$countdownStr  $prayerName, $timeStr';
      }
    }

    return _isArabic ? 'افتح التطبيق للإعداد' : 'Open app to setup';
  }

  /// Format duration as "+/- HH:MM:SS" with western digits
  String _formatDuration(Duration duration, {required bool isNegative}) {
    final hours = duration.inHours.abs();
    final minutes = (duration.inMinutes % 60).abs();
    final seconds = (duration.inSeconds % 60).abs();

    final timeStr = westernDigits(
      '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
    );

    return isNegative ? '- $timeStr' : '+ $timeStr';
  }

  /// Format prayer time for display
  String _formatPrayerTime(DateTime time) {
    if (_isArabic) {
      // Arabic: 12-hour format with م/ص
      final hour = time.hour;
      final minute = time.minute;
      final period = hour >= 12 ? 'م' : 'ص';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return westernDigits(
        '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period',
      );
    } else {
      // English: 12-hour format
      final format = DateFormat('h:mm a', 'en');
      return westernDigits(format.format(time));
    }
  }

  /// Stop the notification service
  Future<void> stop() async {
    _updateTimer?.cancel();
    await ForegroundServiceBridge.stopService();
    _isRunning = false;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

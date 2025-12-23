import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/prayer_times_api_service.dart';
import '../../data/services/prayer_times_cache_service.dart';
import '../../core/localization/western_digits.dart';

/// Provider to manage the live prayer notification with countdown
class LiveNotificationProvider extends ChangeNotifier {
  final NotificationService _notificationService = NotificationService();
  final PrayerTimesApiService _apiService = PrayerTimesApiService();
  final PrayerTimesCacheService _cacheService = PrayerTimesCacheService();

  Timer? _updateTimer;
  AlAdhanResponse? _todayTimings;
  AlAdhanResponse? _tomorrowTimings;

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

  /// Start the live notification service
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

    await _notificationService.initialize();

    // Load today's timings
    await _loadTimings(latitude, longitude);

    // Start the update timer (every second)
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateNotification();
    });

    // Initial update
    _updateNotification();
  }

  /// Update language setting
  void updateLanguage(bool isArabic) {
    _isArabic = isArabic;
    _updateNotification();
  }

  /// Update location
  Future<void> updateLocation({
    required String locationName,
    required double latitude,
    required double longitude,
  }) async {
    _locationName = locationName;
    await _loadTimings(latitude, longitude);
    _updateNotification();
  }

  /// Load today's and tomorrow's prayer timings
  Future<void> _loadTimings(double latitude, double longitude) async {
    final method = await _cacheService.loadMethod();
    final madhab = await _cacheService.loadMadhab();
    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));

    try {
      _todayTimings = await _apiService.fetchPrayerTimesByCoordinates(
        latitude: latitude,
        longitude: longitude,
        method: method,
        madhab: madhab,
        date: today,
      );

      _tomorrowTimings = await _apiService.fetchPrayerTimesByCoordinates(
        latitude: latitude,
        longitude: longitude,
        method: method,
        madhab: madhab,
        date: tomorrow,
      );
    } catch (e) {
      // Try cache for today
      final dateStr = DateFormat('dd-MM-yyyy').format(today);
      _todayTimings = await _cacheService.loadCachedResponse(
        date: dateStr,
        latitude: latitude,
        longitude: longitude,
        methodId: method.id,
        madhabId: madhab.id,
      );
    }
  }

  /// Parse time string "HH:mm" to DateTime for a given date
  DateTime _parseTime(String timeStr, DateTime date) {
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        return DateTime(date.year, date.month, date.day, hour, minute);
      }
    } catch (e) {
      // Fallback
    }
    return DateTime(date.year, date.month, date.day);
  }

  /// Get prayer times for a given date's timings
  List<DateTime> _getPrayerTimes(AlAdhanTimings timings, DateTime date) {
    return [
      _parseTime(timings.fajr, date),
      _parseTime(timings.dhuhr, date),
      _parseTime(timings.asr, date),
      _parseTime(timings.maghrib, date),
      _parseTime(timings.isha, date),
    ];
  }

  /// Update the notification content
  void _updateNotification() {
    if (_todayTimings == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayTimes = _getPrayerTimes(_todayTimings!.timings, today);

    // Find the current state
    int? lastPrayerIndex;
    int? nextPrayerIndex;
    DateTime? lastPrayerTime;
    DateTime? nextPrayerTime;
    bool isGraceWindow = false;
    bool useTomorrow = false;

    // Check each prayer
    for (int i = 0; i < todayTimes.length; i++) {
      final prayerTime = todayTimes[i];
      if (prayerTime.isBefore(now) || prayerTime.isAtSameMomentAs(now)) {
        lastPrayerIndex = i;
        lastPrayerTime = prayerTime;
      } else {
        if (nextPrayerIndex == null) {
          nextPrayerIndex = i;
          nextPrayerTime = prayerTime;
        }
      }
    }

    // Check if we're in grace window (within 30 min after last prayer)
    if (lastPrayerTime != null) {
      final graceEnd = lastPrayerTime.add(
        const Duration(minutes: _graceWindowMinutes),
      );
      if (now.isBefore(graceEnd)) {
        isGraceWindow = true;
      }
    }

    // If no next prayer today, use tomorrow's Fajr
    if (nextPrayerIndex == null && _tomorrowTimings != null) {
      final tomorrow = today.add(const Duration(days: 1));
      final tomorrowTimes = _getPrayerTimes(
        _tomorrowTimings!.timings,
        tomorrow,
      );
      nextPrayerIndex = 0; // Fajr
      nextPrayerTime = tomorrowTimes[0];
      useTomorrow = true;
    }

    // Build notification content
    String title = _buildTitle(now);
    String body = _buildBody(
      now: now,
      isGraceWindow: isGraceWindow,
      lastPrayerIndex: lastPrayerIndex,
      lastPrayerTime: lastPrayerTime,
      nextPrayerIndex: nextPrayerIndex,
      nextPrayerTime: nextPrayerTime,
      useTomorrow: useTomorrow,
    );

    _notificationService.showLiveNotification(title: title, body: body);
  }

  /// Build the notification title (Location | Weekday dd MMM)
  String _buildTitle(DateTime now) {
    final dateFormat = DateFormat('EEE dd MMM', _isArabic ? 'ar' : 'en');
    final dateStr = westernDigits(dateFormat.format(now));
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
    bool useTomorrow = false,
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

    return _isArabic ? 'جاري التحميل...' : 'Loading...';
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
      // Arabic: 24-hour format with م/ص
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
  void stop() {
    _updateTimer?.cancel();
    _notificationService.cancelNotification();
    _isRunning = false;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

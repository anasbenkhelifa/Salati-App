import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/services/foreground_service_bridge.dart';
import '../../data/services/prayer_times_api_service.dart';
import '../../data/services/prayer_times_cache_service.dart';
import '../../data/services/hijri_date_service.dart';
import '../../data/services/adhan_playback_service.dart';
import '../../core/localization/western_digits.dart';

/// Provider to manage the live prayer notification with countdown
class LiveNotificationProvider extends ChangeNotifier {
  final PrayerTimesApiService _apiService = PrayerTimesApiService();
  final PrayerTimesCacheService _cacheService = PrayerTimesCacheService();
  final HijriDateService _hijriService = HijriDateService();
  final AdhanPlaybackService _adhanService = AdhanPlaybackService();

  Timer? _updateTimer;
  AlAdhanResponse? _todayTimings;
  AlAdhanResponse? _tomorrowTimings;
  HijriDate? _hijriDate;
  String? _lastDateKey; // tracks which calendar day _hijriDate was fetched for

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

  // Prayer keys for AlertModeService (must match AlertModeService.prayerKeys)
  static const List<String> _prayerKeys = [
    'fajr',
    'dhuhr',
    'asr',
    'maghrib',
    'isha',
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

    // Load Hijri date natively with offset applied
    final startDate = DateTime.now();
    _hijriDate = await _hijriService.getAdjustedHijriDate(startDate);
    _lastDateKey = '${startDate.year}-${startDate.month}-${startDate.day}';

    // Initialize Adhan playback service
    await _adhanService.initialize();

    // Load today's timings from cache
    await _loadTimings(latitude, longitude);

    // Build initial content and start foreground service
    final title = _buildTitle(DateTime.now());
    final body = _buildInitialBody();
    await ForegroundServiceBridge.startService(title: title, body: body);

    // Start the update timer (every second)
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateNotification();
    });

    // Initial update
    _updateNotification();
  }

  String _buildInitialBody() {
    return _isArabic ? 'جاري التحميل...' : 'Loading...';
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

  /// Load today's and tomorrow's prayer timings from cache
  Future<void> _loadTimings(double latitude, double longitude) async {
    // Load from cache first
    final cached = await _cacheService.loadAppState();
    if (cached?.prayerTimes != null) {
      _todayTimings = cached!.prayerTimes;
      debugPrint('[LiveNotificationProvider] Loaded timings from cache');
      return;
    }

    // Fallback to API
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

      debugPrint('[LiveNotificationProvider] Timings loaded from API');
    } catch (e) {
      debugPrint('[LiveNotificationProvider] Error loading timings: $e');
    }
  }

  /// Get prayer times as DateTime list for a given day
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
    if (_todayTimings == null) return;

    final now = DateTime.now();

    // Refresh Hijri date when the calendar day changes (handles midnight rollover)
    final currentDateKey = '${now.year}-${now.month}-${now.day}';
    if (_lastDateKey != null && currentDateKey != _lastDateKey) {
      _lastDateKey = currentDateKey;
      // Fire-and-forget: update _hijriDate natively with offset
      _hijriService.getAdjustedHijriDate(now).then((date) {
        if (date != null) {
          _hijriDate = date;
          debugPrint('[LiveNotificationProvider] Hijri date refreshed for $currentDateKey: ${date.formatEnglish()}');
        }
      });
    }
    final today = DateTime(now.year, now.month, now.day);
    final todayTimes = _getPrayerTimes(_todayTimings!.timings, today);

    // Find the last and next prayers
    int? lastPrayerIndex;
    DateTime? lastPrayerTime;
    int? nextPrayerIndex;
    DateTime? nextPrayerTime;
    bool isGraceWindow = false;
    bool useTomorrow = false;

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

        // Trigger Adhan playback within the first 3 seconds of grace window
        // This ensures we don't miss the trigger due to timer jitter
        if (elapsed.inSeconds <= 3 && lastPrayerIndex != null) {
          final prayerKey = _prayerKeys[lastPrayerIndex];
          _adhanService.triggerForPrayer(prayerKey, lastPrayerTime);
        }
      }
    }

    // If all today's prayers have passed
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

    // Update via foreground service bridge
    ForegroundServiceBridge.updateNotification(title: title, body: body);
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

  /// Format duration using shared formatter
  /// - isNegative=true means grace window (after prayer) → PLUS sign
  /// - isNegative=false means normal countdown (before prayer) → MINUS sign
  String _formatDuration(Duration duration, {required bool isNegative}) {
    // Use shared formatter that handles "hide hours when 0" + western digits
    return formatCountdownWithSign(duration, sign: isNegative ? '+' : '-');
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

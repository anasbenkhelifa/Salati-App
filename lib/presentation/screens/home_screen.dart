import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/strings.dart';
import '../../core/localization/western_digits.dart';
import '../../core/localization/app_locale_provider.dart';
import '../../domain/providers/hijri_date_provider.dart';
import '../../domain/providers/prayer_times_api_provider.dart';
import '../../data/services/prayer_times_api_service.dart';
import '../widgets/apple_glass_card.dart';

/// Home screen with LIVE clock, Hijri date, and Prayer Status
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Timer _timer;
  DateTime _now = DateTime.now();
  final HijriDateProvider _hijriProvider = HijriDateProvider();
  final PrayerTimesApiProvider _prayerProvider = PrayerTimesApiProvider();

  // Grace window: 30 minutes after a prayer
  static const int _graceWindowMinutes = 30;
  // Warning: last 20 minutes before prayer
  static const int _warningMinutes = 20;

  @override
  void initState() {
    super.initState();
    // Update every second for analog clock second hand + prayer countdown
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
    // Initialize providers
    _initProviders();
  }

  Future<void> _initProviders() async {
    // Add listeners FIRST to catch all notifyListeners calls
    _hijriProvider.addListener(_onUpdate);
    _prayerProvider.addListener(_onUpdate);

    // Then initialize - providers will notifyListeners when data is loaded
    _hijriProvider.initialize();
    await _prayerProvider.initialize();

    // If prayer data is still null after first init, the cache might not have been ready.
    // Wait a bit and try again (handles first start timing issue)
    if (_prayerProvider.response == null && mounted) {
      debugPrint('[HomeScreen] Prayer response null, retrying in 2s...');
      await Future.delayed(const Duration(seconds: 2));
      if (_prayerProvider.response == null && mounted) {
        debugPrint('[HomeScreen] Still null, reloading from cache...');
        await _prayerProvider.reloadFromCache();
        if (mounted) setState(() {});
      }
    }
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer.cancel();
    _hijriProvider.removeListener(_onUpdate);
    _prayerProvider.removeListener(_onUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Title
          Text(
            t(context, 'home'),
            style: TextStyle(
              color: AppTheme.currentTextPrimary,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          // Main glass panel - Expanded to fill available space
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildMainPanel(context),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildMainPanel(BuildContext context) {
    final localeController = AppLocaleProvider.of(context);
    final isArabic = localeController.locale.languageCode == 'ar';

    // Calculate time components (HH:MM only, no seconds)
    final hour12 =
        _now.hour > 12 ? _now.hour - 12 : (_now.hour == 0 ? 12 : _now.hour);
    final hourStr = westernDigits(hour12.toString());
    final minuteStr = westernDigits(_now.minute.toString().padLeft(2, '0'));
    final period =
        _now.hour >= 12 ? (isArabic ? 'م' : 'PM') : (isArabic ? 'ص' : 'AM');

    // Get Hijri date - ALWAYS western digits
    final hijriDate = _hijriProvider.getFormattedDate(isArabic);
    final dateStr = westernDigits(hijriDate);

    return Column(
      children: [
        // ===== BOX 1: Clock + Digital Time + Date =====
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          decoration: AppTheme.glassDecoration(opacity: 0.08, borderRadius: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Analog clock
              _buildAnalogClock(),
              const SizedBox(height: 20),
              // Digital time - HH:MM centered, AM/PM positioned beside
              Builder(
                builder: (context) {
                  final timeStyle = TextStyle(
                    color: AppTheme.currentTextPrimary,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  );
                  final timeText = '$hourStr:$minuteStr';

                  final textPainter = TextPainter(
                    text: TextSpan(text: timeText, style: timeStyle),
                    textDirection: TextDirection.ltr,
                  )..layout();

                  const gap = 8.0;
                  final amPmOffset = (textPainter.width / 2) + gap;

                  return SizedBox(
                    width: double.infinity,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(timeText, style: timeStyle),
                        Transform.translate(
                          offset: Offset(amPmOffset, 0),
                          child: Text(
                            period,
                            style: TextStyle(
                              color: AppTheme.currentTextPrimary.withOpacity(
                                0.6,
                              ),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              // Hijri Date in pill-shaped badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color:
                      AppTheme.isLightMode
                          ? AppTheme.currentActiveGlow.withOpacity(0.08)
                          : AppTheme.currentActiveGlow.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.currentActiveGlow.withOpacity(0.2),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.currentActiveGlow.withOpacity(0.15),
                      blurRadius: 8,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Text(
                  dateStr,
                  style: TextStyle(
                    color: AppTheme.currentActiveGlow,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ===== BOX 2: Prayer Status =====
        _buildPrayerStatus(context, isArabic),
      ],
    );
  }

  Widget _buildPrayerStatus(BuildContext context, bool isArabic) {
    final response = _prayerProvider.response;
    if (response == null) {
      return _buildPrayerStatusLoading(isArabic);
    }

    // Calculate prayer status using same logic as notification
    final prayerStatus = _calculatePrayerStatus(response.timings, isArabic);

    return AppleGlassCard(
      borderRadius: 24,
      blurSigma: 22,
      borderColor: prayerStatus.color.withOpacity(0.3),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Prayer name (BIGGER, no title label)
          Text(
            prayerStatus.prayerName,
            style: TextStyle(
              color: AppTheme.currentTextPrimary,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          // Prayer time (BIGGER)
          Text(
            prayerStatus.prayerTime,
            style: TextStyle(
              color: AppTheme.currentTextSecondary.withOpacity(0.7),
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          // Live countdown with color (true centering)
          SizedBox(
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Centered time (anchor)
                Text(
                  prayerStatus.countdownTime,
                  style: TextStyle(
                    color: prayerStatus.color,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                // Sign positioned to the left of center
                Transform.translate(
                  offset: Offset(
                    prayerStatus.countdownTime.length > 5 ? -85 : -55,
                    0,
                  ),
                  child: Text(
                    prayerStatus.countdownSign,
                    style: TextStyle(
                      color: prayerStatus.color.withOpacity(0.7),
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerStatusLoading(bool isArabic) {
    return AppleGlassCard(
      borderRadius: 24,
      blurSigma: 22,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isArabic ? 'حالة الصلاة' : 'Prayer Status',
            style: TextStyle(
              color: AppTheme.currentTextSecondary.withOpacity(0.7),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isArabic ? 'جاري التحميل...' : 'Loading...',
            style: TextStyle(
              color: AppTheme.currentTextSecondary.withOpacity(0.5),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  /// Calculate prayer status - SAME LOGIC as live notification
  _PrayerStatus _calculatePrayerStatus(AlAdhanTimings timings, bool isArabic) {
    final prayerNames =
        isArabic
            ? ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء']
            : ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

    final today = DateTime(_now.year, _now.month, _now.day);
    final times = _getPrayerTimes(timings, today);

    // Find last and next prayers
    int? lastPrayerIndex;
    DateTime? lastPrayerTime;
    int? nextPrayerIndex;
    DateTime? nextPrayerTime;
    bool isGraceWindow = false;

    for (int i = 0; i < times.length; i++) {
      if (_now.isBefore(times[i])) {
        nextPrayerIndex = i;
        nextPrayerTime = times[i];
        break;
      } else {
        lastPrayerIndex = i;
        lastPrayerTime = times[i];
      }
    }

    // Check for grace window (within 30 min after last prayer)
    if (lastPrayerTime != null) {
      final elapsed = _now.difference(lastPrayerTime);
      if (elapsed.inMinutes < _graceWindowMinutes) {
        isGraceWindow = true;
      }
    }

    // If all prayers passed, next is tomorrow's Fajr
    if (nextPrayerIndex == null) {
      nextPrayerIndex = 0;
      nextPrayerTime = times[0].add(const Duration(days: 1));
    }

    // Determine color and countdown
    Color color;
    String countdownSign;
    String countdownTime;
    String prayerName;
    String prayerTime;

    if (isGraceWindow && lastPrayerIndex != null && lastPrayerTime != null) {
      // Grace window: counting UP from last prayer
      final elapsed = _now.difference(lastPrayerTime);
      final parts = formatCountdownParts(elapsed, sign: '+');
      countdownSign = parts.sign;
      countdownTime = parts.time;
      color = const Color(0xFF4CAF50); // Calm green
      prayerName = prayerNames[lastPrayerIndex];
      prayerTime = _formatPrayerTime(lastPrayerTime, isArabic);
    } else {
      // Normal countdown to next prayer
      final remaining = nextPrayerTime!.difference(_now);
      final parts = formatCountdownParts(remaining, sign: '-');
      countdownSign = parts.sign;
      countdownTime = parts.time;
      prayerName = prayerNames[nextPrayerIndex!];
      prayerTime = _formatPrayerTime(nextPrayerTime, isArabic);

      // Color: red if within last 20 minutes, otherwise normal
      if (remaining.inMinutes < _warningMinutes) {
        color = const Color(0xFFE57373); // Calm red
      } else {
        color = AppTheme.currentActiveGlow; // Normal accent color
      }
    }

    return _PrayerStatus(
      prayerName: prayerName,
      prayerTime: prayerTime,
      countdownSign: countdownSign,
      countdownTime: countdownTime,
      color: color,
    );
  }

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

  String _formatPrayerTime(DateTime time, bool isArabic) {
    if (isArabic) {
      final hour = time.hour;
      final minute = time.minute;
      final period = hour >= 12 ? 'م' : 'ص';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return westernDigits(
        '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period',
      );
    } else {
      final hour = time.hour;
      final minute = time.minute;
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return westernDigits(
        '$displayHour:${minute.toString().padLeft(2, '0')} $period',
      );
    }
  }

  Widget _buildAnalogClock() {
    final hourAngle =
        ((_now.hour % 12) + _now.minute / 60 + _now.second / 3600) *
        (2 * math.pi / 12);
    final minuteAngle = (_now.minute + _now.second / 60) * (2 * math.pi / 60);
    final secondAngle = _now.second * (2 * math.pi / 60);

    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppTheme.currentTextSecondary.withOpacity(0.3),
          width: 3,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Hour marks
          ...List.generate(12, (index) {
            final angle = (index * 30) * math.pi / 180;
            return Transform.rotate(
              angle: angle,
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 2,
                  height: 10,
                  color: AppTheme.currentTextSecondary,
                ),
              ),
            );
          }),
          // Hour hand
          Transform.rotate(
            angle: hourAngle,
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.only(top: 50),
                width: 5,
                height: 50,
                decoration: BoxDecoration(
                  color: AppTheme.currentTextPrimary,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
          ),
          // Minute hand
          Transform.rotate(
            angle: minuteAngle,
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.only(top: 30),
                width: 3,
                height: 70,
                decoration: BoxDecoration(
                  color: AppTheme.currentTextPrimary.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            ),
          ),
          // Second hand
          Transform.rotate(
            angle: secondAngle,
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.only(top: 15),
                width: 1.5,
                height: 65,
                decoration: BoxDecoration(
                  color: AppTheme.currentActiveGlow,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ),
          // Center dot
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: AppTheme.currentActiveGlow,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper class for prayer status display
class _PrayerStatus {
  final String prayerName;
  final String prayerTime;
  final String countdownSign;
  final String countdownTime;
  final Color color;

  _PrayerStatus({
    required this.prayerName,
    required this.prayerTime,
    required this.countdownSign,
    required this.countdownTime,
    required this.color,
  });
}

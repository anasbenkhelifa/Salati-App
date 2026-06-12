import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/tour/tour_key_registry.dart';
import '../../core/localization/strings.dart';
import '../../core/localization/western_digits.dart';
import '../../core/localization/app_locale_provider.dart';
import '../../domain/providers/hijri_date_provider.dart';
import '../../domain/providers/prayer_times_api_provider.dart';
import '../../data/services/prayer_times_api_service.dart';
import '../widgets/apple_glass_card.dart';
import '../widgets/glass_container.dart';
import '../widgets/crescent_loader.dart';
import '../widgets/location_picker_sheet.dart';
import '../widgets/pressable_scale.dart';
import '../widgets/hijri_calendar_sheet.dart';
import '../../data/services/bilingual_location_service.dart';
import 'package:provider/provider.dart';

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
  late final PrayerTimesApiProvider _prayerProvider;

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
    _prayerProvider = context.read<PrayerTimesApiProvider>();
    _initProviders();
  }

  Future<void> _initProviders() async {
    // Add listeners FIRST to catch all notifyListeners calls
    _hijriProvider.addListener(_onUpdate);
    _prayerProvider.addListener(_onUpdate);

    // Then initialize - providers will notifyListeners when data is loaded
    _hijriProvider.initialize();

    // PrayerTimesApiProvider is already initialized centrally in main.dart
    // Just handle UI state retry if needed.

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
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
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
        ),
      ),
    );
  }

  Widget _buildMainPanel(BuildContext context) {
    final localeController = AppLocaleProvider.of(context);
    final isArabic = localeController.locale.languageCode == 'ar';

    // Calculate time components for the header (digital clock)
    final hour12 =
        _now.hour > 12 ? _now.hour - 12 : (_now.hour == 0 ? 12 : _now.hour);
    final hourStr = westernDigits(hour12.toString());
    final minuteStr = westernDigits(_now.minute.toString().padLeft(2, '0'));
    final period =
        _now.hour >= 12 ? (isArabic ? 'م' : 'PM') : (isArabic ? 'ص' : 'AM');

    final hijriDate = _hijriProvider.getFormattedDate(isArabic);
    final dateStr = westernDigits(hijriDate);

    return GlassContainer(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      borderRadius: 32,
      child: Column(
        children: [
          // Row 1: Digital Time and Hijri Date at the top of the dashboard
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Digital Time
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$hourStr:$minuteStr',
                    style: AppTheme.displayDigits(fontSize: 32, letterSpacing: 1),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    period,
                    style: TextStyle(
                      color: AppTheme.currentTextPrimary.withValues(alpha: 0.6),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              // Hijri Date — tap to open the full Hijri calendar.
              // Styled as a button (gradient fill, glow, chevron) so it
              // reads as clickable, not just a label.
              PressableScale(
                key: TourKeyRegistry.instance.hijriChipKey,
                onTap: () => HijriCalendarSheet.show(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: AppTheme.currentAccentGradient.colors
                          .map((c) => c.withValues(
                              alpha: AppTheme.isLightMode ? 0.14 : 0.24))
                          .toList(),
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.currentActiveGlow.withValues(alpha: 0.5),
                      width: 1.2,
                    ),
                    boxShadow: AppTheme.glowShadow(intensity: 0.35),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_month,
                        size: 14,
                        color: AppTheme.currentActiveGlow,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        dateStr,
                        style: TextStyle(
                          color: AppTheme.currentActiveGlow,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(
                        Icons.expand_more,
                        size: 14,
                        color:
                            AppTheme.currentActiveGlow.withValues(alpha: 0.8),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Row 2: Premium Analog Clock Centerpiece with prayer progress
          // ring. FittedBox scales the fixed 268dp design DOWN on short or
          // narrow screens (and never up), so no layout overflows anywhere.
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: _buildClockCenterpiece(),
                ),
              ),
            ),
          ),

          // Row 3: Prayer Status
          _buildPrayerDashboardSection(context, isArabic),
        ],
      ),
    );
  }

  Widget _buildPrayerDashboardSection(BuildContext context, bool isArabic) {
    final state = _prayerProvider.state;
    final response = _prayerProvider.response;

    // Handle non-success states with clear, actionable UI
    if (state == PrayerDataState.locationDisabled) {
      return _buildErrorState(
        context,
        icon: Icons.location_off,
        message: isArabic
            ? 'خدمة الموقع معطلة'
            : 'Location services are disabled',
        buttonLabel: isArabic ? 'تفعيل GPS' : 'Enable GPS',
        onPressed: () => _prayerProvider.openLocationSettings(),
        secondaryLabel: t(context, 'chooseCityManually'),
        onSecondary: () => _pickCityManually(context),
      );
    }

    if (state == PrayerDataState.permissionDenied) {
      return _buildErrorState(
        context,
        icon: Icons.location_disabled,
        message: isArabic
            ? 'يرجى السماح بالوصول للموقع'
            : 'Location permission required',
        buttonLabel: isArabic ? 'فتح الإعدادات' : 'Open Settings',
        onPressed: () => _prayerProvider.openAppSettings(),
        secondaryLabel: t(context, 'chooseCityManually'),
        onSecondary: () => _pickCityManually(context),
      );
    }

    if (state == PrayerDataState.error) {
      return _buildErrorState(
        context,
        icon: Icons.error_outline,
        message: isArabic ? 'حدث خطأ' : 'Something went wrong',
        buttonLabel: isArabic ? 'إعادة المحاولة' : 'Retry',
        onPressed: () => _prayerProvider.requestPermission(),
        secondaryLabel: t(context, 'chooseCityManually'),
        onSecondary: () => _pickCityManually(context),
      );
    }

    if (response == null) {
      return const SizedBox(
        height: 100,
        child: Center(child: CrescentLoader()),
      );
    }

    final prayerStatus = _calculatePrayerStatus(
      context,
      response.timings,
      isArabic,
    );

    return Container(
      key: TourKeyRegistry.instance.prayerDashboardKey,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.currentTextPrimary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.currentTextSecondary.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left side: Next Prayer Name and Time
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                prayerStatus.prayerName,
                style: TextStyle(
                  color: AppTheme.currentTextPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                prayerStatus.prayerTime,
                style: TextStyle(
                  color: AppTheme.currentTextSecondary.withValues(alpha: 0.7),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          // Right side: Countdown (FittedBox: shrinks instead of overflowing
          // on narrow screens / large system fonts)
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    prayerStatus.countdownSign,
                    style: TextStyle(
                      color: prayerStatus.color.withValues(alpha: 0.7),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    prayerStatus.countdownTime,
                    style: AppTheme.displayDigits(
                      fontSize: 32,
                      color: prayerStatus.color,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Calculate prayer status - SAME LOGIC as live notification
  _PrayerStatus _calculatePrayerStatus(
    BuildContext context,
    AlAdhanTimings timings,
    bool isArabic,
  ) {
    final prayerNames = [
      t(context, 'fajr'),
      t(context, 'dhuhr'),
      t(context, 'asr'),
      t(context, 'maghrib'),
      t(context, 'isha'),
    ];

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

  /// Fraction of the interval between the previous and next prayer that
  /// has already elapsed (0..1), or null when prayer data isn't loaded.
  double? _prayerIntervalProgress() {
    final response = _prayerProvider.response;
    if (response == null) return null;
    final today = DateTime(_now.year, _now.month, _now.day);
    final times = _getPrayerTimes(response.timings, today);
    if (times.length < 5) return null;

    DateTime? prev;
    DateTime? next;
    for (final t in times) {
      if (_now.isBefore(t)) {
        next = t;
        break;
      }
      prev = t;
    }
    // Before Fajr: count from yesterday's Isha. After Isha: to tomorrow's Fajr.
    prev ??= times[4].subtract(const Duration(days: 1));
    next ??= times[0].add(const Duration(days: 1));

    final total = next.difference(prev).inSeconds;
    if (total <= 0) return null;
    return (_now.difference(prev).inSeconds / total).clamp(0.0, 1.0);
  }

  /// Analog clock wrapped in the prayer-interval progress ring.
  Widget _buildClockCenterpiece() {
    const ringSize = 268.0;
    final progress = _prayerIntervalProgress();

    return SizedBox(
      width: ringSize,
      height: ringSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (progress != null)
            CustomPaint(
              size: const Size(ringSize, ringSize),
              painter: _PrayerProgressRingPainter(
                progress: progress,
                colors: AppTheme.currentAccentGradient.colors,
                trackColor:
                    AppTheme.currentTextSecondary.withValues(alpha: 0.12),
              ),
            ),
          _buildPremiumAnalogClock(),
        ],
      ),
    );
  }

  Widget _buildPremiumAnalogClock() {
    final hourAngle =
        ((_now.hour % 12) + _now.minute / 60 + _now.second / 3600) *
        (2 * math.pi / 12);
    final minuteAngle = (_now.minute + _now.second / 60) * (2 * math.pi / 60);
    final secondAngle = _now.second * (2 * math.pi / 60);

    final clockSize = 240.0;

    return Container(
      width: clockSize,
      height: clockSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.currentTextPrimary.withValues(alpha: 0.02),
        border: Border.all(
          color: AppTheme.currentTextSecondary.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: CustomPaint(
        painter: _PremiumClockFacePainter(
          textColor: AppTheme.currentTextPrimary,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Internal subtle ring
            Container(
              width: clockSize - 30,
              height: clockSize - 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.currentTextSecondary.withValues(alpha: 0.05),
                  width: 1,
                ),
              ),
            ),
            // Hour hand
            Transform.rotate(
              angle: hourAngle,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.only(bottom: clockSize / 2),
                  child: Container(
                    width: 6,
                    height: 65,
                    decoration: BoxDecoration(
                      color: AppTheme.currentTextPrimary,
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.currentTextPrimary.withValues(alpha: 0.4),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Minute hand
            Transform.rotate(
              angle: minuteAngle,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.only(bottom: clockSize / 2),
                  child: Container(
                    width: 4,
                    height: 90,
                    decoration: BoxDecoration(
                      color: AppTheme.currentTextPrimary.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.currentTextPrimary.withValues(alpha: 0.3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Second hand
            Transform.rotate(
              angle: secondAngle,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: clockSize / 2 - 15,
                  ), // overhang
                  child: Container(
                    width: 2,
                    height: 105,
                    decoration: BoxDecoration(
                      color: AppTheme.currentActiveGlow,
                      borderRadius: BorderRadius.circular(1),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.currentActiveGlow.withValues(alpha: 0.6),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Center mounting pin
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: AppTheme.currentTextPrimary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: AppTheme.currentActiveGlow,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// GPS-less onboarding: pick a city from the search sheet instead of
  /// granting location permission. Completes first-run setup fully.
  Future<void> _pickCityManually(BuildContext context) async {
    final result = await LocationPickerSheet.show(context);
    if (result == null || !mounted) return;

    // Resolve both-language names so the location follows the app language
    final bilingual = await BilingualLocationService().getLocationNames(
      result.lat,
      result.lng,
    );

    await _prayerProvider.setManualLocation(
      lat: result.lat,
      lng: result.lng,
      cityAr: (bilingual != null && bilingual.cityAr.isNotEmpty)
          ? bilingual.cityAr
          : result.cityName,
      cityEn: (bilingual != null && bilingual.cityEn.isNotEmpty)
          ? bilingual.cityEn
          : result.cityName,
      countryAr: (bilingual != null && bilingual.countryAr.isNotEmpty)
          ? bilingual.countryAr
          : result.countryName,
      countryEn: (bilingual != null && bilingual.countryEn.isNotEmpty)
          ? bilingual.countryEn
          : result.countryName,
      isoCountryCode: result.isoCountryCode.isNotEmpty
          ? result.isoCountryCode
          : (bilingual?.isoCountryCode ?? ''),
    );
    if (mounted) setState(() {});
  }

  /// Build a clear, actionable error state for the prayer dashboard
  Widget _buildErrorState(
    BuildContext context, {
    required IconData icon,
    required String message,
    required String buttonLabel,
    required VoidCallback onPressed,
    String? secondaryLabel,
    VoidCallback? onSecondary,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: AppTheme.currentTextPrimary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.currentTextSecondary.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.currentTextSecondary, size: 36),
          const SizedBox(height: 10),
          Text(
            message,
            style: TextStyle(
              color: AppTheme.currentTextSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.currentActiveGlow,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            ),
            child: Text(buttonLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          if (secondaryLabel != null && onSecondary != null) ...[
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: onSecondary,
              icon: Icon(
                Icons.search,
                size: 18,
                color: AppTheme.currentActiveGlow,
              ),
              label: Text(
                secondaryLabel,
                style: TextStyle(
                  color: AppTheme.currentActiveGlow,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Ring around the clock showing how far the day has progressed between
/// the previous prayer and the next one. Gradient stroke with a glowing
/// head dot at the leading edge.
class _PrayerProgressRingPainter extends CustomPainter {
  final double progress;
  final List<Color> colors;
  final Color trackColor;

  _PrayerProgressRingPainter({
    required this.progress,
    required this.colors,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 5.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = trackColor;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    // Progress arc: starts at 12 o'clock, sweeps clockwise
    const startAngle = -math.pi / 2;
    final sweep = 2 * math.pi * progress;
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [colors.first, colors.last, colors.first],
        transform: const GradientRotation(startAngle),
      ).createShader(rect);
    canvas.drawArc(rect, startAngle, sweep, false, arcPaint);

    // Glowing head dot at the leading edge
    final headAngle = startAngle + sweep;
    final head = Offset(
      center.dx + radius * math.cos(headAngle),
      center.dy + radius * math.sin(headAngle),
    );
    final glowPaint = Paint()
      ..color = colors.last.withValues(alpha: 0.7)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    canvas.drawCircle(head, 7, glowPaint);
    canvas.drawCircle(head, 4.5, Paint()..color = colors.first);
  }

  @override
  bool shouldRepaint(covariant _PrayerProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.colors != colors ||
        oldDelegate.trackColor != trackColor;
  }
}

class _PremiumClockFacePainter extends CustomPainter {
  final Color textColor;
  _PremiumClockFacePainter({required this.textColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw tick marks
    final tickPaint =
        Paint()
          ..color = textColor.withValues(alpha: 0.4)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;

    final boldTickPaint =
        Paint()
          ..color = textColor.withValues(alpha: 0.8)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 60; i++) {
      final isHour = i % 5 == 0;
      final angle = (i * 6) * math.pi / 180;

      final tickLength = isHour ? 12.0 : 6.0;
      final p1 = Offset(
        center.dx + (radius - 5) * math.cos(angle - math.pi / 2),
        center.dy + (radius - 5) * math.sin(angle - math.pi / 2),
      );
      final p2 = Offset(
        center.dx + (radius - 5 - tickLength) * math.cos(angle - math.pi / 2),
        center.dy + (radius - 5 - tickLength) * math.sin(angle - math.pi / 2),
      );

      canvas.drawLine(p1, p2, isHour ? boldTickPaint : tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PremiumClockFacePainter oldDelegate) {
    return oldDelegate.textColor != textColor;
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

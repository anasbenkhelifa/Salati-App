import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/strings.dart';
import '../../core/localization/western_digits.dart';
import '../../core/localization/app_locale_provider.dart';

/// Home screen with LIVE clock - updates every second
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Update every second using DateTime.now() for resilience
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _now = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // Title at top
          const SizedBox(height: 24),
          Text(
            t(context, 'home'),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          // Clock centered in remaining space
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildClockSection(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClockSection(BuildContext context) {
    final localeController = AppLocaleProvider.of(context);
    final lang = localeController.locale.languageCode;

    // Calculate time components from _now
    final hour12 =
        _now.hour > 12 ? _now.hour - 12 : (_now.hour == 0 ? 12 : _now.hour);
    final minute = _now.minute.toString().padLeft(2, '0');
    final second = _now.second.toString().padLeft(2, '0');
    final period =
        _now.hour >= 12
            ? (lang == 'ar' ? 'م' : 'PM')
            : (lang == 'ar' ? 'ص' : 'AM');
    final timeStr = westernDigits('$hour12:$minute:$second $period');

    // Format date - ALWAYS western digits
    final dateStr = westernDigits(DateFormat('d MMMM y', lang).format(_now));

    return Container(
      padding: const EdgeInsets.all(40),
      decoration: AppTheme.glassDecoration(opacity: 0.08, borderRadius: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Analog clock - LIVE
          _buildAnalogClock(),
          const SizedBox(height: 32),
          // Label
          Text(
            t(context, 'currentTime'),
            style: TextStyle(
              color: AppTheme.textSecondary.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          // Digital time - LIVE, WESTERN DIGITS
          Text(
            timeStr,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 44,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          // Date - WESTERN DIGITS
          Text(
            dateStr,
            style: TextStyle(
              color: AppTheme.textSecondary.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalogClock() {
    // Calculate hand angles from _now
    // Hour hand: 360° / 12 hours = 30° per hour, plus minute fraction
    final hourAngle =
        ((_now.hour % 12) + _now.minute / 60 + _now.second / 3600) *
        (2 * math.pi / 12);
    // Minute hand: 360° / 60 minutes = 6° per minute, plus second fraction
    final minuteAngle = (_now.minute + _now.second / 60) * (2 * math.pi / 60);
    // Second hand: 360° / 60 seconds = 6° per second
    final secondAngle = _now.second * (2 * math.pi / 60);

    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 3),
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
                  margin: const EdgeInsets.only(top: 8),
                  width: 2,
                  height: 12,
                  color: Colors.white.withOpacity(0.6),
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
                margin: const EdgeInsets.only(top: 45),
                width: 4,
                height: 45,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
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
                width: 2.5,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
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
                margin: const EdgeInsets.only(top: 20),
                width: 1.5,
                height: 70,
                decoration: BoxDecoration(
                  color: AppTheme.activeGlow,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ),
          // Center dot
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: AppTheme.activeGlow,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

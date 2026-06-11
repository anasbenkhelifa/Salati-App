import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_motion.dart';
import '../../core/localization/strings.dart';
import '../../core/localization/western_digits.dart';
import '../../core/localization/app_locale_provider.dart';
import 'app_sheet.dart';

/// Ramadan fasting tracker: tap a day to mark it fasted. Stored locally
/// per Hijri year ('fasting_log_<year>'), fully offline.
class FastingTrackerSheet extends StatefulWidget {
  const FastingTrackerSheet({super.key});

  static Future<void> show(BuildContext context) {
    HapticFeedback.lightImpact();
    return AppSheet.show(
      context,
      builder: (_) => const FastingTrackerSheet(),
    );
  }

  @override
  State<FastingTrackerSheet> createState() => _FastingTrackerSheetState();
}

class _FastingTrackerSheetState extends State<FastingTrackerSheet> {
  final HijriCalendar _converter = HijriCalendar();

  int _hijriYear = 1447;
  int _daysInRamadan = 30;
  int _todayDay = 0; // 0 = not currently Ramadan
  Set<int> _fasted = {};
  SharedPreferences? _prefs;

  String get _prefsKey => 'fasting_log_$_hijriYear';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final offset = prefs.getInt('hijri_offset') ?? 0;
    final adjusted = DateTime.now().add(Duration(days: offset));
    final h = HijriCalendar.fromDate(adjusted);

    // Track the current Hijri year's Ramadan (even when opened outside it)
    final year = h.hYear;
    final days = _converter.getDaysInMonth(year, 9);
    final today = h.hMonth == 9 ? h.hDay : 0;

    Set<int> fasted = {};
    final raw = prefs.getString('fasting_log_$year');
    if (raw != null) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        fasted = map.entries
            .where((e) => e.value == true)
            .map((e) => int.parse(e.key))
            .toSet();
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _prefs = prefs;
        _hijriYear = year;
        _daysInRamadan = days;
        _todayDay = today;
        _fasted = fasted;
      });
    }
  }

  Future<void> _toggle(int day) async {
    // Future days can't be marked while Ramadan is ongoing
    if (_todayDay > 0 && day > _todayDay) return;
    HapticFeedback.selectionClick();
    setState(() {
      if (_fasted.contains(day)) {
        _fasted.remove(day);
      } else {
        _fasted.add(day);
      }
    });
    final map = {for (final d in _fasted) '$d': true};
    await _prefs?.setString(_prefsKey, jsonEncode(map));
  }

  @override
  Widget build(BuildContext context) {
    final locale = AppLocaleProvider.of(context);
    final isArabic = locale.isArabic;
    final glow = AppTheme.currentActiveGlow;

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: AppSheet(
        maxHeightFactor: 0.8,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetHeader(
              icon: Icons.nights_stay,
              title: t(context, 'fastingTracker'),
              subtitle: westernDigits(
                isArabic ? 'رمضان $_hijriYear' : 'Ramadan $_hijriYear',
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (int d = 1; d <= _daysInRamadan; d++) _dayCircle(d),
                  ],
                ),
              ),
            ),
            // Footer: progress
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: AppTheme.currentAccentGradient.colors
                      .map((c) => c.withValues(alpha: 0.12))
                      .toList(),
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: glow.withValues(alpha: 0.35)),
              ),
              child: Text(
                westernDigits(
                  '${_fasted.length} / $_daysInRamadan ${t(context, 'daysFasted')}',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: glow,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayCircle(int day) {
    final glow = AppTheme.currentActiveGlow;
    final fasted = _fasted.contains(day);
    final isToday = day == _todayDay;
    final isFuture = _todayDay > 0 && day > _todayDay;

    return GestureDetector(
      onTap: () => _toggle(day),
      child: AnimatedContainer(
        duration: AppMotion.fast,
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          gradient: fasted ? AppTheme.currentAccentGradient : null,
          color: fasted
              ? null
              : (AppTheme.isLightMode
                  ? AppTheme.inactiveBackground
                  : Colors.white.withValues(alpha: 0.06)),
          shape: BoxShape.circle,
          border: Border.all(
            color: isToday
                ? glow
                : (fasted
                    ? Colors.transparent
                    : AppTheme.inactiveBorder),
            width: isToday ? 2 : 1,
          ),
          boxShadow: fasted ? AppTheme.glowShadow(intensity: 0.35) : null,
        ),
        child: Center(
          child: Opacity(
            opacity: isFuture ? 0.35 : 1,
            child: fasted
                ? Icon(
                    Icons.check,
                    size: 18,
                    color: AppTheme.currentAccentGradient.colors.first
                                .computeLuminance() >
                            0.5
                        ? Colors.black87
                        : Colors.white,
                  )
                : Text(
                    westernDigits('$day'),
                    style: TextStyle(
                      color: AppTheme.currentTextPrimary,
                      fontSize: 14,
                      fontWeight:
                          isToday ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

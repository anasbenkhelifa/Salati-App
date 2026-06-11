import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_motion.dart';
import '../../core/localization/strings.dart';
import '../../core/localization/western_digits.dart';
import '../../core/localization/app_locale_provider.dart';
import 'app_sheet.dart';

/// Full offline Hijri calendar: month grid with the Gregorian equivalent in
/// every cell, month/year navigation, and a footer showing the selected day
/// in both calendars.
///
/// Backed by the `hijri` package's Umm al-Qura tables — pure offline math,
/// valid from 1356 AH (1937 CE) to 1500 AH (2077 CE). The user's manual
/// Hijri offset (Settings) is applied so the calendar always agrees with the
/// date shown across the app.
class HijriCalendarSheet extends StatefulWidget {
  const HijriCalendarSheet({super.key});

  static Future<void> show(BuildContext context) {
    HapticFeedback.lightImpact();
    return AppSheet.show(
      context,
      builder: (_) => const HijriCalendarSheet(),
    );
  }

  @override
  State<HijriCalendarSheet> createState() => _HijriCalendarSheetState();
}

class _HijriCalendarSheetState extends State<HijriCalendarSheet> {
  // Umm al-Qura table limits, kept one year inside the package's hard
  // bounds (1356–1500) so month-length lookups never touch the table edge.
  static const int _minYear = 1357;
  static const int _maxYear = 1499;

  static const List<String> _monthsAr = [
    'محرم', 'صفر', 'ربيع الأول', 'ربيع الثاني',
    'جمادى الأولى', 'جمادى الآخرة', 'رجب', 'شعبان',
    'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة',
  ];
  static const List<String> _monthsEn = [
    'Muharram', 'Safar', 'Rabi\' al-Awwal', 'Rabi\' al-Thani',
    'Jumada al-Awwal', 'Jumada al-Thani', 'Rajab', 'Sha\'ban',
    'Ramadan', 'Shawwal', 'Dhu al-Qi\'dah', 'Dhu al-Hijjah',
  ];

  // Week starts on Sunday; Directionality flips the row for Arabic.
  static const List<String> _weekdaysAr = ['أحد', 'إثن', 'ثلا', 'أرب', 'خمي', 'جمع', 'سبت'];
  static const List<String> _weekdaysEn = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  static const List<String> _weekdaysFr = ['Dim', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam'];

  final HijriCalendar _converter = HijriCalendar();

  int _offsetDays = 0;
  late int _todayYear, _todayMonth, _todayDay;
  late int _viewYear, _viewMonth;
  int? _selectedDay;

  @override
  void initState() {
    super.initState();
    _computeToday();
    _viewYear = _todayYear;
    _viewMonth = _todayMonth;
    _selectedDay = _todayDay;

    // Apply the user's manual Hijri offset once loaded
    SharedPreferences.getInstance().then((prefs) {
      final offset = prefs.getInt('hijri_offset') ?? 0;
      if (offset != 0 && mounted) {
        setState(() {
          _offsetDays = offset;
          _computeToday();
          _viewYear = _todayYear;
          _viewMonth = _todayMonth;
          _selectedDay = _todayDay;
        });
      }
    });
  }

  void _computeToday() {
    final adjusted = DateTime.now().add(Duration(days: _offsetDays));
    final h = HijriCalendar.fromDate(adjusted);
    _todayYear = h.hYear;
    _todayMonth = h.hMonth;
    _todayDay = h.hDay;
  }

  /// Gregorian day a Hijri date falls on, honoring the user's offset.
  DateTime _gregorianFor(int y, int m, int d) =>
      _converter.hijriToGregorian(y, m, d).subtract(Duration(days: _offsetDays));

  int _daysInMonth(int y, int m) => _converter.getDaysInMonth(y, m);

  void _shiftMonth(int delta) {
    HapticFeedback.selectionClick();
    var m = _viewMonth + delta;
    var y = _viewYear;
    while (m > 12) {
      m -= 12;
      y++;
    }
    while (m < 1) {
      m += 12;
      y--;
    }
    if (y < _minYear || y > _maxYear) return;
    setState(() {
      _viewYear = y;
      _viewMonth = m;
      _selectedDay = null;
    });
  }

  void _shiftYear(int delta) {
    HapticFeedback.selectionClick();
    final y = (_viewYear + delta).clamp(_minYear, _maxYear);
    setState(() {
      _viewYear = y;
      _selectedDay = null;
    });
  }

  void _jumpToToday() {
    HapticFeedback.selectionClick();
    setState(() {
      _viewYear = _todayYear;
      _viewMonth = _todayMonth;
      _selectedDay = _todayDay;
    });
  }

  String _monthName(int month, String lang) =>
      lang == 'ar' ? _monthsAr[month - 1] : _monthsEn[month - 1];

  @override
  Widget build(BuildContext context) {
    final locale = AppLocaleProvider.of(context);
    final lang = locale.locale.languageCode;
    final isArabic = lang == 'ar';

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: AppSheet(
        maxHeightFactor: 0.88,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetHeader(
              icon: Icons.calendar_month,
              title: t(context, 'hijriCalendar'),
              trailing: _todayButton(context),
            ),
            _monthNavigator(lang),
            const SizedBox(height: 8),
            _weekdayHeader(lang),
            const SizedBox(height: 4),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AnimatedSwitcher(
                  duration: AppMotion.fast,
                  switchInCurve: AppMotion.enter,
                  switchOutCurve: AppMotion.exit,
                  child: _monthGrid(
                    key: ValueKey('$_viewYear-$_viewMonth'),
                  ),
                ),
              ),
            ),
            _selectedFooter(lang),
          ],
        ),
      ),
    );
  }

  Widget _todayButton(BuildContext context) {
    return GestureDetector(
      onTap: _jumpToToday,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          gradient: AppTheme.currentAccentGradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppTheme.glowShadow(intensity: 0.5),
        ),
        child: Text(
          t(context, 'today'),
          style: TextStyle(
            color: _onGradient,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Color get _onGradient =>
      AppTheme.currentAccentGradient.colors.first.computeLuminance() > 0.5
          ? Colors.black87
          : Colors.white;

  Widget _monthNavigator(String lang) {
    final glow = AppTheme.currentActiveGlow;
    // Gregorian span of the displayed Hijri month, e.g. "Mar – Apr 2026"
    final first = _gregorianFor(_viewYear, _viewMonth, 1);
    final last = _gregorianFor(
        _viewYear, _viewMonth, _daysInMonth(_viewYear, _viewMonth));
    final fmt = DateFormat('MMM yyyy', lang);
    final span = first.month == last.month
        ? fmt.format(first)
        : '${DateFormat('MMM', lang).format(first)} – ${fmt.format(last)}';

    Widget navButton(IconData icon, VoidCallback onTap) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.inactiveBackground,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: AppTheme.inactiveBorder),
          ),
          child: Icon(icon, color: glow, size: 19),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          navButton(Icons.keyboard_double_arrow_left, () => _shiftYear(-1)),
          const SizedBox(width: 6),
          navButton(Icons.chevron_left, () => _shiftMonth(-1)),
          Expanded(
            child: Column(
              children: [
                Text(
                  westernDigits('${_monthName(_viewMonth, lang)} $_viewYear'),
                  style: TextStyle(
                    color: AppTheme.currentTextPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  westernDigits(span),
                  style: TextStyle(
                    color: AppTheme.currentTextSecondary.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          navButton(Icons.chevron_right, () => _shiftMonth(1)),
          const SizedBox(width: 6),
          navButton(Icons.keyboard_double_arrow_right, () => _shiftYear(1)),
        ],
      ),
    );
  }

  Widget _weekdayHeader(String lang) {
    final labels = lang == 'ar'
        ? _weekdaysAr
        : (lang == 'fr' ? _weekdaysFr : _weekdaysEn);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: labels.map((label) {
          final isJumua = label == labels[5]; // Friday column
          return Expanded(
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: isJumua
                      ? AppTheme.currentActiveGlow
                      : AppTheme.currentTextSecondary.withValues(alpha: 0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _monthGrid({required Key key}) {
    final daysInMonth = _daysInMonth(_viewYear, _viewMonth);
    final firstGreg = _gregorianFor(_viewYear, _viewMonth, 1);
    // Column index with the week starting on Sunday (DateTime: Mon=1..Sun=7)
    final leadingBlanks = firstGreg.weekday % 7;

    final cells = <Widget>[
      for (int i = 0; i < leadingBlanks; i++) const SizedBox(),
      for (int d = 1; d <= daysInMonth; d++) _dayCell(d),
    ];
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox());
    }

    return Column(
      key: key,
      children: [
        for (int row = 0; row < cells.length ~/ 7; row++)
          Row(
            children: [
              for (int col = 0; col < 7; col++)
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1.05,
                    child: cells[row * 7 + col],
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _dayCell(int day) {
    final greg = _gregorianFor(_viewYear, _viewMonth, day);
    final isToday = _viewYear == _todayYear &&
        _viewMonth == _todayMonth &&
        day == _todayDay;
    final isSelected = _selectedDay == day;
    final isFriday = greg.weekday == DateTime.friday;
    final glow = AppTheme.currentActiveGlow;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedDay = day);
      },
      child: AnimatedContainer(
        duration: AppMotion.fast,
        margin: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          gradient: isToday ? AppTheme.currentAccentGradient : null,
          color: isToday
              ? null
              : (isSelected ? glow.withValues(alpha: 0.12) : null),
          borderRadius: BorderRadius.circular(12),
          border: isSelected && !isToday
              ? Border.all(color: glow.withValues(alpha: 0.65), width: 1.3)
              : null,
          boxShadow: isToday ? AppTheme.glowShadow(intensity: 0.5) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              westernDigits('$day'),
              style: TextStyle(
                color: isToday
                    ? _onGradient
                    : (isFriday ? glow : AppTheme.currentTextPrimary),
                fontSize: 15,
                fontWeight:
                    isToday || isFriday ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            Text(
              westernDigits('${greg.day}'),
              style: TextStyle(
                color: (isToday ? _onGradient : AppTheme.currentTextSecondary)
                    .withValues(alpha: 0.65),
                fontSize: 9.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectedFooter(String lang) {
    final day = _selectedDay;
    if (day == null) return const SizedBox(height: 16);

    final greg = _gregorianFor(_viewYear, _viewMonth, day);
    final hijriText = westernDigits(
      lang == 'ar'
          ? '‏$day ${_monthName(_viewMonth, lang)} $_viewYear هـ‏'
          : '$day ${_monthName(_viewMonth, lang)} $_viewYear AH',
    );
    final gregText =
        westernDigits(DateFormat('EEEE, d MMMM yyyy', lang).format(greg));

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppTheme.currentAccentGradient.colors
              .map((c) => c.withValues(alpha: 0.12))
              .toList(),
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.currentActiveGlow.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        children: [
          Text(
            hijriText,
            style: TextStyle(
              color: AppTheme.currentActiveGlow,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            gregText,
            style: TextStyle(
              color: AppTheme.currentTextSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

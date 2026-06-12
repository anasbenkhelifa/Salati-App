import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_motion.dart';
import '../../core/localization/strings.dart';
import '../../core/localization/western_digits.dart';
import '../../core/localization/app_locale_provider.dart';
import '../../data/services/prayer_log_service.dart';
import 'app_sheet.dart';

/// Gentle weekly prayer journal: seven day-columns of soft dots, a quiet
/// count, month/year totals, and — only when earned — a streak line.
/// Dots are tappable, so a forgotten prayer can be checked later.
/// No reds, no "missed" labels, no pressure.
class PrayerLogSheet extends StatefulWidget {
  const PrayerLogSheet({super.key});

  static Future<void> show(BuildContext context) {
    HapticFeedback.lightImpact();
    return AppSheet.show(
      context,
      builder: (_) => const PrayerLogSheet(),
    );
  }

  @override
  State<PrayerLogSheet> createState() => _PrayerLogSheetState();
}

class _PrayerLogSheetState extends State<PrayerLogSheet> {
  List<Map<String, bool>>? _week; // oldest → today
  int _streak = 0;
  int _monthCount = 0;
  int _yearCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Settle "missed" states before showing the week
    await PrayerLogService.instance.reconcile();
    final now = DateTime.now();
    final week = await PrayerLogService.instance.loadLastDays(7);
    final streak = await PrayerLogService.instance.currentStreak();
    final monthCount = await PrayerLogService.instance
        .countPrayedSince(DateTime(now.year, now.month, 1));
    final yearCount = await PrayerLogService.instance
        .countPrayedSince(DateTime(now.year, 1, 1));
    if (mounted) {
      setState(() {
        _week = week;
        _streak = streak;
        _monthCount = monthCount;
        _yearCount = yearCount;
      });
    }
  }

  Future<void> _toggleDot(int dayIndex, String prayerKey) async {
    final week = _week;
    if (week == null) return;
    final date = DateTime.now().subtract(Duration(days: 6 - dayIndex));
    final newValue = !(week[dayIndex][prayerKey] ?? false);
    HapticFeedback.selectionClick();
    setState(() => week[dayIndex][prayerKey] = newValue);
    await PrayerLogService.instance.setPrayed(date, prayerKey, newValue);
    // Streak / totals may have changed
    final streak = await PrayerLogService.instance.currentStreak();
    final now = DateTime.now();
    final monthCount = await PrayerLogService.instance
        .countPrayedSince(DateTime(now.year, now.month, 1));
    final yearCount = await PrayerLogService.instance
        .countPrayedSince(DateTime(now.year, 1, 1));
    if (mounted) {
      setState(() {
        _streak = streak;
        _monthCount = monthCount;
        _yearCount = yearCount;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = AppLocaleProvider.of(context);
    final lang = locale.locale.languageCode;
    final isArabic = lang == 'ar';
    final glow = AppTheme.currentActiveGlow;
    final week = _week;

    final int prayedCount = week == null
        ? 0
        : week
            .expand((d) => PrayerLogService.prayerKeys.map((k) => d[k] == true))
            .where((v) => v)
            .length;

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: AppSheet(
        maxHeightFactor: 0.82,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetHeader(
              icon: Icons.spa,
              title: t(context, 'prayerJournal'),
              subtitle: t(context, 'thisWeek'),
            ),
            if (week == null)
              const Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              )
            else
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Seven day-columns of tappable dots (top = Fajr)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            for (int i = 0; i < week.length; i++)
                              _dayColumn(context, week[i], i, lang),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Quiet summary
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: AppTheme.currentAccentGradient.colors
                                .map((c) => c.withValues(alpha: 0.10))
                                .toList(),
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border:
                              Border.all(color: glow.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  westernDigits('$prayedCount'),
                                  style: AppTheme.displayDigits(
                                      fontSize: 30, color: glow),
                                ),
                                Text(
                                  westernDigits(' / 35'),
                                  style: TextStyle(
                                    color: AppTheme.currentTextSecondary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  t(context, 'thisWeek'),
                                  style: TextStyle(
                                    color: AppTheme.currentTextSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Month / year totals
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _periodPill(
                                    t(context, 'thisMonth'), _monthCount),
                                const SizedBox(width: 10),
                                _periodPill(t(context, 'thisYear'), _yearCount),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Streak appears only once it exists — never a
                      // broken-streak message
                      if (_streak >= 2) ...[
                        const SizedBox(height: 12),
                        Text(
                          westernDigits(
                              '🌱 $_streak ${t(context, 'dayStreak')}'),
                          style: TextStyle(
                            color: glow,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),
                      // إن الصلاة كانت على المؤمنين كتاباً موقوتاً
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 22),
                        child: Text(
                          'إِنَّ الصَّلَاةَ كَانَتْ عَلَى الْمُؤْمِنِينَ كِتَابًا مَوْقُوتًا',
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                          style: GoogleFonts.amiri(
                            color: const Color(0xFF5DBB63),
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            height: 1.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _periodPill(String label, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.currentActiveGlow.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        westernDigits('$label: $count'),
        style: TextStyle(
          color: AppTheme.currentTextSecondary,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _dayColumn(
    BuildContext context,
    Map<String, bool> day,
    int index,
    String lang,
  ) {
    final glow = AppTheme.currentActiveGlow;
    final isToday = index == 6;
    final date = DateTime.now().subtract(Duration(days: 6 - index));
    final label = DateFormat.E(lang).format(date);

    return AnimatedContainer(
      duration: AppMotion.fast,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: isToday ? glow.withValues(alpha: 0.10) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isToday
            ? Border.all(color: glow.withValues(alpha: 0.35))
            : null,
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: isToday ? glow : AppTheme.currentTextSecondary,
              fontSize: 11,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          for (final key in PrayerLogService.prayerKeys)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _toggleDot(index, key),
              // Generous hit box around a small dot
              child: SizedBox(
                width: 26,
                height: 19,
                child: Center(
                  child: AnimatedContainer(
                    duration: AppMotion.fast,
                    width: day[key] == true ? 10 : 8,
                    height: day[key] == true ? 10 : 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: day[key] == true
                          ? AppTheme.currentAccentGradient
                          : null,
                      // missed (false) = quiet filled grey; unmarked = faint
                      color: day[key] == true
                          ? null
                          : AppTheme.currentTextSecondary.withValues(
                              alpha: day[key] == false ? 0.28 : 0.12),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

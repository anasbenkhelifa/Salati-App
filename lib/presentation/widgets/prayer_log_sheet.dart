import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_motion.dart';
import '../../core/localization/strings.dart';
import '../../core/localization/western_digits.dart';
import '../../core/localization/app_locale_provider.dart';
import '../../data/services/prayer_log_service.dart';
import 'app_sheet.dart';

/// Gentle weekly prayer journal: seven day-columns of soft dots, a quiet
/// count, and — only when earned — a streak line. No reds, no "missed",
/// no pressure.
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final week = await PrayerLogService.instance.loadLastDays(7);
    final streak = await PrayerLogService.instance.currentStreak();
    if (mounted) {
      setState(() {
        _week = week;
        _streak = streak;
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
        maxHeightFactor: 0.7,
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
            else ...[
              // Seven day-columns of soft dots (top = Fajr ... bottom = Isha)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: AppTheme.currentAccentGradient.colors
                        .map((c) => c.withValues(alpha: 0.10))
                        .toList(),
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: glow.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      westernDigits('$prayedCount'),
                      style: AppTheme.displayDigits(fontSize: 30, color: glow),
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
              ),

              // Streak appears only once it exists — never a broken-streak
              // message
              if (_streak >= 2) ...[
                const SizedBox(height: 12),
                Text(
                  westernDigits('🌱 $_streak ${t(context, 'dayStreak')}'),
                  style: TextStyle(
                    color: glow,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],

              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  t(context, 'everyPrayerCounts'),
                  style: TextStyle(
                    color: AppTheme.currentTextSecondary.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ],
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
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
          const SizedBox(height: 8),
          for (final key in PrayerLogService.prayerKeys) ...[
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: AppMotion.normal,
              curve: AppMotion.enter,
              builder: (context, v, child) =>
                  Opacity(opacity: v, child: child),
              child: Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(bottom: 5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: day[key] == true
                      ? AppTheme.currentAccentGradient
                      : null,
                  color: day[key] == true
                      ? null
                      : AppTheme.currentTextSecondary.withValues(alpha: 0.15),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

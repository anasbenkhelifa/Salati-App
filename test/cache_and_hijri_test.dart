import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adhan_app/data/services/prayer_times_api_service.dart';
import 'package:adhan_app/data/services/prayer_times_cache_service.dart';
import 'package:adhan_app/data/services/hijri_date_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PrayerTimesCacheService', () {
    late PrayerTimesCacheService cache;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      cache = PrayerTimesCacheService();
    });

    test('setup flag starts false and persists after markSetupDone', () async {
      expect(await cache.isSetupDone(), isFalse);
      await cache.markSetupDone();
      expect(await cache.isSetupDone(), isTrue);
    });

    test('30-day multi-day cache roundtrips intact', () async {
      final byDate = {
        '2026-06-15': {
          'Fajr': '03:55',
          'Sunrise': '05:33',
          'Dhuhr': '12:21',
          'Asr': '15:41',
          'Maghrib': '19:08',
          'Isha': '20:38',
        },
        '2026-06-16': {
          'Fajr': '03:55',
          'Sunrise': '05:33',
          'Dhuhr': '12:21',
          'Asr': '15:42',
          'Maghrib': '19:09',
          'Isha': '20:39',
        },
      };

      await cache.savePrayerTimesByDate(byDate);
      final loaded = await cache.loadPrayerTimesByDate();

      expect(loaded, isNotNull);
      expect(loaded!.length, 2);
      expect(loaded['2026-06-15']!['Fajr'], '03:55');
      expect(loaded['2026-06-16']!['Isha'], '20:39');
    });

    test('multi-day cache returns null when never written', () async {
      expect(await cache.loadPrayerTimesByDate(), isNull);
    });

    test('method roundtrip preserves choice and manual flag', () async {
      await cache.saveMethod(CalculationMethodId.ummAlQura, isManual: true);
      expect(await cache.loadMethod(), CalculationMethodId.ummAlQura);
      expect(await cache.loadIsManualMethod(), isTrue);

      await cache.saveMethod(CalculationMethodId.mwl, isManual: false);
      expect(await cache.loadMethod(), CalculationMethodId.mwl);
      expect(await cache.loadIsManualMethod(), isFalse);
    });
  });

  group('HijriDateService', () {
    late HijriDateService hijri;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      hijri = HijriDateService();
    });

    test('produces a structurally valid Hijri date', () async {
      final date = await hijri.getHijriDate(DateTime(2026, 6, 15));
      expect(date, isNotNull);
      expect(date!.month, inInclusiveRange(1, 12));
      expect(date.day, inInclusiveRange(1, 30));
      // 2026 CE falls in 1447–1448 AH
      expect(date.year, inInclusiveRange(1447, 1448));
      expect(date.monthNameAr, isNotEmpty);
      expect(date.monthNameEn, isNotEmpty);
    });

    test('offset defaults to 0 and persists when set', () async {
      expect(await hijri.getHijriOffset(), 0);
      await hijri.setHijriOffset(2);
      expect(await hijri.getHijriOffset(), 2);
    });

    test('adjusted date equals plain date shifted by the offset', () async {
      final base = DateTime(2026, 6, 15);
      await hijri.setHijriOffset(1);

      final adjusted = await hijri.getAdjustedHijriDate(base);
      final shifted =
          await hijri.getHijriDate(base.add(const Duration(days: 1)));

      expect(adjusted!.day, shifted!.day);
      expect(adjusted.month, shifted.month);
      expect(adjusted.year, shifted.year);
    });

    test('cacheUpcomingDays writes 30 per-date keys for the native side',
        () async {
      await hijri.cacheUpcomingDays();
      final prefs = await SharedPreferences.getInstance();

      final keys =
          prefs.getKeys().where((k) => k.startsWith('hijri_date_')).toList();
      expect(keys.length, HijriDateService.daysToCacheAhead);

      // Today's entry must exist and parse as the expected JSON shape
      final now = DateTime.now();
      final todayKey =
          'hijri_date_${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      expect(prefs.getString(todayKey), isNotNull);
      expect(prefs.getString(todayKey), contains('"monthNameAr"'));
      expect(prefs.getInt('cached_hijri_updated_at'), isNotNull);
    });

    test('cacheUpcomingDays prunes stale past-date entries', () async {
      SharedPreferences.setMockInitialValues({
        'hijri_date_2020-01-01': '{"day":6,"month":5,"year":1441}',
      });
      hijri = HijriDateService();

      await hijri.cacheUpcomingDays();
      final prefs = await SharedPreferences.getInstance();

      expect(prefs.getString('hijri_date_2020-01-01'), isNull,
          reason: 'stale per-date entries must be pruned');
      final keys = prefs.getKeys().where((k) => k.startsWith('hijri_date_'));
      expect(keys.length, HijriDateService.daysToCacheAhead);
    });
  });
}

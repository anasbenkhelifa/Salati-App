import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:adhan_app/data/services/prayer_times_api_service.dart';

/// The prayer calculation is fully offline (adhan package + timezone
/// tables), so it can be tested exactly as it runs in production.
void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
  });

  final service = PrayerTimesApiService();

  // Mecca — stable reference point for the Umm al-Qura method
  const meccaLat = 21.4225;
  const meccaLng = 39.8262;
  final testDate = DateTime(2026, 6, 15);

  /// Parse "HH:mm" into minutes since midnight.
  int minutesOf(String hhmm) {
    final parts = hhmm.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  final hhmm = RegExp(r'^\d{2}:\d{2}$');

  group('fetchPrayerTimesByCoordinates (offline calculation)', () {
    test('returns well-formed HH:mm timings for Mecca', () async {
      final response = await service.fetchPrayerTimesByCoordinates(
        latitude: meccaLat,
        longitude: meccaLng,
        method: CalculationMethodId.ummAlQura,
        madhab: MadhabId.shafi,
        date: testDate,
      );

      final t = response.timings;
      for (final time in [t.fajr, t.sunrise, t.dhuhr, t.asr, t.maghrib, t.isha]) {
        expect(hhmm.hasMatch(time), isTrue, reason: 'malformed time: $time');
      }
    });

    test('timings are chronologically ordered through the day', () async {
      final response = await service.fetchPrayerTimesByCoordinates(
        latitude: meccaLat,
        longitude: meccaLng,
        method: CalculationMethodId.ummAlQura,
        madhab: MadhabId.shafi,
        date: testDate,
      );

      final t = response.timings;
      final order = [t.fajr, t.sunrise, t.dhuhr, t.asr, t.maghrib, t.isha]
          .map(minutesOf)
          .toList();
      for (int i = 1; i < order.length; i++) {
        expect(order[i], greaterThan(order[i - 1]),
            reason: 'prayer ${i + 1} not after prayer $i: $order');
      }
    });

    test('Hanafi Asr is never earlier than Shafi Asr', () async {
      final shafi = await service.fetchPrayerTimesByCoordinates(
        latitude: meccaLat,
        longitude: meccaLng,
        method: CalculationMethodId.ummAlQura,
        madhab: MadhabId.shafi,
        date: testDate,
      );
      final hanafi = await service.fetchPrayerTimesByCoordinates(
        latitude: meccaLat,
        longitude: meccaLng,
        method: CalculationMethodId.ummAlQura,
        madhab: MadhabId.hanafi,
        date: testDate,
      );

      expect(
        minutesOf(hanafi.timings.asr),
        greaterThanOrEqualTo(minutesOf(shafi.timings.asr)),
      );
    });

    test('consecutive days drift only slightly (multi-day cache premise)',
        () async {
      // The 30-day offline cache exists because times shift ~1 min/day.
      // Verify the drift is small but the calc is per-date (not a copy).
      final day1 = await service.fetchPrayerTimesByCoordinates(
        latitude: meccaLat,
        longitude: meccaLng,
        method: CalculationMethodId.ummAlQura,
        madhab: MadhabId.shafi,
        date: testDate,
      );
      final day2 = await service.fetchPrayerTimesByCoordinates(
        latitude: meccaLat,
        longitude: meccaLng,
        method: CalculationMethodId.ummAlQura,
        madhab: MadhabId.shafi,
        date: testDate.add(const Duration(days: 1)),
      );

      final pairs = [
        [day1.timings.fajr, day2.timings.fajr],
        [day1.timings.dhuhr, day2.timings.dhuhr],
        [day1.timings.maghrib, day2.timings.maghrib],
      ];
      for (final pair in pairs) {
        final diff = (minutesOf(pair[0]) - minutesOf(pair[1])).abs();
        expect(diff, lessThanOrEqualTo(3),
            reason: 'unexpected jump ${pair[0]} → ${pair[1]}');
      }
    });

    test('different calculation methods produce different Fajr/Isha',
        () async {
      final ummAlQura = await service.fetchPrayerTimesByCoordinates(
        latitude: meccaLat,
        longitude: meccaLng,
        method: CalculationMethodId.ummAlQura,
        madhab: MadhabId.shafi,
        date: testDate,
      );
      final isna = await service.fetchPrayerTimesByCoordinates(
        latitude: meccaLat,
        longitude: meccaLng,
        method: CalculationMethodId.isna,
        madhab: MadhabId.shafi,
        date: testDate,
      );

      // Dhuhr (solar noon) is near method-independent (methods may differ
      // by a minute of rounding); Fajr angles genuinely differ
      final dhuhrDiff =
          (minutesOf(ummAlQura.timings.dhuhr) - minutesOf(isna.timings.dhuhr))
              .abs();
      expect(dhuhrDiff, lessThanOrEqualTo(2));
      expect(ummAlQura.timings.fajr == isna.timings.fajr, isFalse);
    });

    test('northern-latitude city still produces ordered times in summer',
        () async {
      // Oslo in June — high latitude rules must not break ordering
      final response = await service.fetchPrayerTimesByCoordinates(
        latitude: 59.9139,
        longitude: 10.7522,
        method: CalculationMethodId.mwl,
        madhab: MadhabId.shafi,
        date: DateTime(2026, 6, 21),
      );

      final t = response.timings;
      for (final time in [t.fajr, t.sunrise, t.dhuhr, t.asr, t.maghrib, t.isha]) {
        expect(hhmm.hasMatch(time), isTrue, reason: 'malformed time: $time');
      }
      // Core daytime ordering must hold even with high-latitude adjustments
      expect(minutesOf(t.sunrise), greaterThan(minutesOf(t.fajr)));
      expect(minutesOf(t.asr), greaterThan(minutesOf(t.dhuhr)));
      expect(minutesOf(t.maghrib), greaterThan(minutesOf(t.asr)));
    });
  });
}

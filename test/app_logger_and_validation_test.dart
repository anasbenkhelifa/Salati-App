import 'package:flutter_test/flutter_test.dart';
import 'package:adhan_app/core/utils/app_logger.dart';
import 'package:adhan_app/data/services/prayer_times_api_service.dart';

/// Unit tests for AppLogger and API response validation
void main() {
  group('AppLogger', () {
    test('info does not throw', () {
      expect(() => AppLogger.info('Test', 'info message'), returnsNormally);
    });

    test('warning does not throw', () {
      expect(() => AppLogger.warning('Test', 'warning message'), returnsNormally);
    });

    test('error does not throw', () {
      expect(
        () => AppLogger.error('Test', 'error message',
            error: Exception('test'), stackTrace: StackTrace.current),
        returnsNormally,
      );
    });

    test('error without optional params does not throw', () {
      expect(() => AppLogger.error('Test', 'simple error'), returnsNormally);
    });
  });

  group('AlAdhanTimings.fromJson validation', () {
    test('should parse valid prayer times correctly', () {
      final json = {
        'Fajr': '05:30',
        'Sunrise': '06:45',
        'Dhuhr': '12:15',
        'Asr': '15:30',
        'Maghrib': '18:00',
        'Isha': '19:30',
        'Imsak': '05:20',
        'Midnight': '00:00',
      };

      final timings = AlAdhanTimings.fromJson(json);

      expect(timings.fajr, equals('05:30'));
      expect(timings.sunrise, equals('06:45'));
      expect(timings.dhuhr, equals('12:15'));
      expect(timings.asr, equals('15:30'));
      expect(timings.maghrib, equals('18:00'));
      expect(timings.isha, equals('19:30'));
      expect(timings.imsak, equals('05:20'));
      expect(timings.midnight, equals('00:00'));
    });

    test('should handle lowercase keys', () {
      final json = {
        'fajr': '05:30',
        'sunrise': '06:45',
        'dhuhr': '12:15',
        'asr': '15:30',
        'maghrib': '18:00',
        'isha': '19:30',
        'imsak': '05:20',
        'midnight': '00:00',
      };

      final timings = AlAdhanTimings.fromJson(json);
      expect(timings.fajr, equals('05:30'));
    });

    test('should handle missing fields with empty defaults', () {
      final json = <String, dynamic>{};

      final timings = AlAdhanTimings.fromJson(json);
      expect(timings.fajr, isEmpty);
      expect(timings.sunrise, isEmpty);
      expect(timings.dhuhr, isEmpty);
      expect(timings.asr, isEmpty);
      expect(timings.maghrib, isEmpty);
      expect(timings.isha, isEmpty);
    });

    test('should strip parenthetical annotations from times', () {
      final json = {
        'Fajr': '05:30 (EET)',
        'Sunrise': '06:45 (EET)',
        'Dhuhr': '12:15 (EET)',
        'Asr': '15:30 (EET)',
        'Maghrib': '18:00 (EET)',
        'Isha': '19:30 (EET)',
        'Imsak': '05:20 (EET)',
        'Midnight': '00:00 (EET)',
      };

      final timings = AlAdhanTimings.fromJson(json);
      expect(timings.fajr, equals('05:30'));
      expect(timings.sunrise, equals('06:45'));
    });
  });

  group('AlAdhanMeta.fromJson validation', () {
    test('should parse valid metadata correctly', () {
      final json = {
        'timezone': 'Africa/Algiers',
        'method': {'name': 'Muslim World League'},
        'school': 'Standard',
        'latitude': 36.75,
        'longitude': 3.04,
      };

      final meta = AlAdhanMeta.fromJson(json);
      expect(meta.timezone, equals('Africa/Algiers'));
      expect(meta.method, equals('Muslim World League'));
      expect(meta.school, equals('Standard'));
      expect(meta.latitude, equals(36.75));
      expect(meta.longitude, equals(3.04));
    });

    test('should clamp out-of-range latitude', () {
      final json = {
        'latitude': 100.0,
        'longitude': 3.04,
      };

      final meta = AlAdhanMeta.fromJson(json);
      expect(meta.latitude, equals(90.0));
    });

    test('should clamp out-of-range longitude', () {
      final json = {
        'latitude': 36.75,
        'longitude': -200.0,
      };

      final meta = AlAdhanMeta.fromJson(json);
      expect(meta.longitude, equals(-180.0));
    });

    test('should handle missing fields with defaults', () {
      final json = <String, dynamic>{};

      final meta = AlAdhanMeta.fromJson(json);
      expect(meta.timezone, isEmpty);
      expect(meta.method, isEmpty);
      expect(meta.school, isEmpty);
      expect(meta.latitude, equals(0.0));
      expect(meta.longitude, equals(0.0));
    });

    test('should handle method as string instead of map', () {
      final json = {
        'method': 'MWL',
        'latitude': 0.0,
        'longitude': 0.0,
      };

      final meta = AlAdhanMeta.fromJson(json);
      expect(meta.method, equals('MWL'));
    });
  });

  group('AlAdhanResponse.fromJson', () {
    test('should parse full response JSON correctly', () {
      final json = {
        'data': {
          'timings': {
            'Fajr': '05:30',
            'Sunrise': '06:45',
            'Dhuhr': '12:15',
            'Asr': '15:30',
            'Maghrib': '18:00',
            'Isha': '19:30',
            'Imsak': '05:20',
            'Midnight': '00:00',
          },
          'meta': {
            'timezone': 'Africa/Algiers',
            'method': {'name': 'MWL'},
            'school': 'Standard',
            'latitude': 36.75,
            'longitude': 3.04,
          },
          'date': {'readable': '15 Mar 2026'},
        },
      };

      final response = AlAdhanResponse.fromJson(json);
      expect(response.timings.fajr, equals('05:30'));
      expect(response.meta.timezone, equals('Africa/Algiers'));
      expect(response.dateReadable, equals('15 Mar 2026'));
      expect(response.isFromCache, isFalse);
    });

    test('should handle flat JSON (no data wrapper)', () {
      final json = {
        'timings': {
          'Fajr': '05:30',
          'Sunrise': '06:45',
          'Dhuhr': '12:15',
          'Asr': '15:30',
          'Maghrib': '18:00',
          'Isha': '19:30',
          'Imsak': '05:20',
          'Midnight': '00:00',
        },
        'meta': {
          'timezone': 'UTC',
          'method': {'name': 'ISNA'},
          'school': 'Hanafi',
          'latitude': 40.71,
          'longitude': -74.01,
        },
        'date': {'readable': '15 Mar 2026'},
      };

      final response = AlAdhanResponse.fromJson(json);
      expect(response.timings.fajr, equals('05:30'));
      expect(response.meta.method, equals('ISNA'));
    });

    test('should round-trip toJson/fromJson', () {
      final original = AlAdhanResponse(
        timings: AlAdhanTimings(
          fajr: '05:00',
          sunrise: '06:30',
          dhuhr: '12:00',
          asr: '15:15',
          maghrib: '18:30',
          isha: '20:00',
          imsak: '04:50',
          midnight: '00:15',
        ),
        meta: AlAdhanMeta(
          timezone: 'Europe/Paris',
          method: 'France',
          school: 'Standard',
          latitude: 48.85,
          longitude: 2.35,
        ),
        dateReadable: '15 Mar 2026',
      );

      final json = original.toJson();
      final restored = AlAdhanResponse.fromJson(json);

      expect(restored.timings.fajr, equals(original.timings.fajr));
      expect(restored.timings.isha, equals(original.timings.isha));
      expect(restored.meta.timezone, equals(original.meta.timezone));
      expect(restored.meta.latitude, equals(original.meta.latitude));
      expect(restored.dateReadable, equals(original.dateReadable));
    });
  });
}

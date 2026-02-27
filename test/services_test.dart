import 'package:flutter_test/flutter_test.dart';
import 'package:adhan_app/data/services/hijri_date_service.dart';
import 'package:adhan_app/data/services/alert_mode_service.dart';

/// Unit tests for data models and pure functions
void main() {
  group('HijriDate Model', () {
    test('should format Arabic date correctly', () {
      final date = HijriDate(
        day: 3,
        month: 7,
        year: 1446,
        monthNameAr: 'رجب',
        monthNameEn: 'Rajab',
        weekdayAr: 'الثلاثاء',
        weekdayEn: 'Tuesday',
      );

      final formatted = date.formatArabic();
      expect(formatted, contains('3'));
      expect(formatted, contains('رجب'));
      expect(formatted, contains('1446'));
    });

    test('should format English date correctly', () {
      final date = HijriDate(
        day: 15,
        month: 1,
        year: 1446,
        monthNameAr: 'محرم',
        monthNameEn: 'Muharram',
        weekdayAr: 'الأحد',
        weekdayEn: 'Sunday',
      );

      expect(date.formatEnglish(), equals('15 Muharram 1446 AH'));
    });

    test('should serialize to JSON correctly', () {
      final date = HijriDate(
        day: 10,
        month: 12,
        year: 1445,
        monthNameAr: 'ذو الحجة',
        monthNameEn: 'Dhul Hijjah',
        weekdayAr: 'الجمعة',
        weekdayEn: 'Friday',
      );

      final json = date.toJson();
      expect(json['day'], equals(10));
      expect(json['month'], equals(12));
      expect(json['year'], equals(1445));
      expect(json['monthNameAr'], equals('ذو الحجة'));
      expect(json['monthNameEn'], equals('Dhul Hijjah'));
    });

    test('should deserialize from cache JSON correctly', () {
      final json = {
        'day': 5,
        'month': 9,
        'year': 1446,
        'monthNameAr': 'رمضان',
        'monthNameEn': 'Ramadan',
        'weekdayAr': 'السبت',
        'weekdayEn': 'Saturday',
      };

      final date = HijriDate.fromCacheJson(json);
      expect(date.day, equals(5));
      expect(date.month, equals(9));
      expect(date.year, equals(1446));
      expect(date.monthNameAr, equals('رمضان'));
      expect(date.monthNameEn, equals('Ramadan'));
    });

    test('should handle missing JSON fields with defaults', () {
      final json = <String, dynamic>{};
      final date = HijriDate.fromCacheJson(json);

      expect(date.day, equals(1));
      expect(date.month, equals(1));
      expect(date.year, equals(1446));
      expect(date.monthNameAr, equals(''));
      expect(date.monthNameEn, equals(''));
    });
  });

  group('AlertMode Enum', () {
    test('should convert to int correctly', () {
      expect(AlertMode.sound.value, equals(0));
      expect(AlertMode.vibrate.value, equals(1));
      expect(AlertMode.silent.value, equals(2));
    });

    test('should convert from int correctly', () {
      expect(AlertModeExtension.fromInt(0), equals(AlertMode.sound));
      expect(AlertModeExtension.fromInt(1), equals(AlertMode.vibrate));
      expect(AlertModeExtension.fromInt(2), equals(AlertMode.silent));
    });

    test('should default to sound for invalid int', () {
      expect(AlertModeExtension.fromInt(-1), equals(AlertMode.sound));
      expect(AlertModeExtension.fromInt(99), equals(AlertMode.sound));
    });

    test('should cycle to next mode correctly', () {
      expect(AlertMode.sound.next, equals(AlertMode.vibrate));
      expect(AlertMode.vibrate.next, equals(AlertMode.silent));
      expect(AlertMode.silent.next, equals(AlertMode.sound));
    });
  });

  group('AlertModeService', () {
    test('prayerKeys should have 5 prayers', () {
      expect(AlertModeService.prayerKeys.length, equals(5));
      expect(AlertModeService.prayerKeys, contains('fajr'));
      expect(AlertModeService.prayerKeys, contains('dhuhr'));
      expect(AlertModeService.prayerKeys, contains('asr'));
      expect(AlertModeService.prayerKeys, contains('maghrib'));
      expect(AlertModeService.prayerKeys, contains('isha'));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:adhan_app/core/localization/western_digits.dart';

void main() {
  group('westernDigits', () {
    test('converts Arabic-Indic digits', () {
      expect(westernDigits('٠١٢٣٤٥٦٧٨٩'), '0123456789');
    });

    test('converts Eastern Arabic-Indic (Persian) digits', () {
      expect(westernDigits('۰۱۲۳۴۵۶۷۸۹'), '0123456789');
    });

    test('leaves Western digits and text untouched', () {
      expect(westernDigits('05:50 Fajr'), '05:50 Fajr');
      expect(westernDigits('الفجر 05:50'), 'الفجر 05:50');
    });

    test('converts mixed digit systems in one string', () {
      expect(westernDigits('١٤٤7 AH — ۲۰26'), '1447 AH — 2026');
    });

    test('empty string passes through', () {
      expect(westernDigits(''), '');
    });
  });

  group('formatCountdownParts', () {
    test('hides hours when under one hour (MM:SS)', () {
      final parts = formatCountdownParts(
        const Duration(minutes: 5, seconds: 3),
        sign: '-',
      );
      expect(parts.time, '05:03');
      expect(parts.sign, '-');
    });

    test('shows HH:MM:SS when one hour or more', () {
      final parts = formatCountdownParts(
        const Duration(hours: 2, minutes: 5, seconds: 3),
        sign: '-',
      );
      expect(parts.time, '02:05:03');
    });

    test('exactly one hour keeps the hours block', () {
      final parts =
          formatCountdownParts(const Duration(hours: 1), sign: '-');
      expect(parts.time, '01:00:00');
    });

    test('zero duration renders 00:00', () {
      expect(formatCountdownParts(Duration.zero, sign: '-').time, '00:00');
    });

    test('59:59 boundary stays in MM:SS form', () {
      final parts = formatCountdownParts(
        const Duration(minutes: 59, seconds: 59),
        sign: '-',
      );
      expect(parts.time, '59:59');
    });

    test('grace-window sign passes through', () {
      final parts = formatCountdownParts(
        const Duration(minutes: 12),
        sign: '+',
      );
      expect(parts.sign, '+');
      expect(parts.combined, '+ 12:00');
    });

    test('legacy combined formatter matches parts', () {
      expect(
        formatCountdownWithSign(const Duration(minutes: 7, seconds: 30),
            sign: '-'),
        '- 07:30',
      );
    });
  });
}

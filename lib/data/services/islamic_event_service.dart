import 'hijri_date_service.dart';

/// Enum representing special Islamic events
enum IslamicEvent {
  islamicNewYear(1, 1, 'Islamic New Year', 'رأس السنة الهجرية', '🌙'),
  ashura(1, 10, 'Ashura', 'عاشوراء', '📿'),
  mawlid(3, 12, 'Mawlid an-Nabi', 'المولد النبوي الشريف', '🕌'),
  israMiraj(7, 27, "Isra' and Mi'raj", 'الإسراء والمعراج', '✨'),
  ramadanStart(9, 1, 'First of Ramadan', 'أول رمضان', '🌙'),
  laylatAlQadr(9, 27, 'Laylat al-Qadr', 'ليلة القدر', '⭐'),
  eidAlFitr(10, 1, 'Eid al-Fitr', 'عيد الفطر المبارك', '🎉'),
  eidAlAdha(12, 10, 'Eid al-Adha', 'عيد الأضحى المبارك', '🐑');

  final int month;
  final int day;
  final String nameEn;
  final String nameAr;
  final String emoji;

  const IslamicEvent(
    this.month,
    this.day,
    this.nameEn,
    this.nameAr,
    this.emoji,
  );
}

/// Service for detecting Islamic events and Ramadan mode
class IslamicEventService {
  /// Ramadan is the 9th month in the Islamic calendar
  static const int ramadanMonth = 9;

  /// Shawwal is the 10th month (Eid al-Fitr)
  static const int shawwalMonth = 10;

  /// Dhul Hijjah is the 12th month (Eid al-Adha)
  static const int dhulHijjahMonth = 12;

  /// Check if current date is in Ramadan
  static bool isRamadan(HijriDate date) {
    return date.month == ramadanMonth;
  }

  /// Check if current date is Eid al-Fitr (1 Shawwal)
  static bool isEidAlFitr(HijriDate date) {
    return date.month == shawwalMonth && date.day == 1;
  }

  /// Check if current date is Eid al-Adha (10 Dhul Hijjah)
  static bool isEidAlAdha(HijriDate date) {
    return date.month == dhulHijjahMonth && date.day == 10;
  }

  /// Check if it's Eid (either Fitr or Adha)
  static bool isEid(HijriDate date) {
    return isEidAlFitr(date) || isEidAlAdha(date);
  }

  /// Check if it's in the last 10 nights of Ramadan (Laylat al-Qadr period)
  static bool isLastTenNights(HijriDate date) {
    return date.month == ramadanMonth && date.day >= 21;
  }

  /// Get the current Islamic event if today is a special day
  static IslamicEvent? getCurrentEvent(HijriDate date) {
    for (final event in IslamicEvent.values) {
      if (date.month == event.month && date.day == event.day) {
        return event;
      }
    }
    return null;
  }

  /// Get upcoming event within the next N days (for upcoming event cards)
  /// Returns null if no special events in the period
  static IslamicEvent? getUpcomingEvent(HijriDate date, {int withinDays = 7}) {
    // Simplified: just check if today is a special event day
    // For a complete implementation, you'd need Hijri date arithmetic
    return getCurrentEvent(date);
  }

  /// Get Ramadan status message
  static String getRamadanStatus(HijriDate date, {required bool isArabic}) {
    if (!isRamadan(date)) return '';

    final daysRemaining = 30 - date.day; // Ramadan is typically 29-30 days

    if (isArabic) {
      if (daysRemaining <= 0) {
        return 'آخر أيام رمضان';
      } else if (daysRemaining == 1) {
        return 'يوم واحد باقٍ من رمضان';
      } else if (daysRemaining <= 10) {
        return '$daysRemaining أيام باقية من رمضان';
      }
      return 'رمضان كريم';
    } else {
      if (daysRemaining <= 0) {
        return 'Last days of Ramadan';
      } else if (daysRemaining == 1) {
        return '1 day left in Ramadan';
      } else if (daysRemaining <= 10) {
        return '$daysRemaining days left in Ramadan';
      }
      return 'Ramadan Kareem';
    }
  }

  /// Get Eid greeting message
  static String getEidGreeting(HijriDate date, {required bool isArabic}) {
    if (isEidAlFitr(date)) {
      return isArabic ? 'عيد فطر مبارك! 🎉' : 'Eid Mubarak! 🎉';
    } else if (isEidAlAdha(date)) {
      return isArabic ? 'عيد أضحى مبارك! 🐑' : 'Eid Mubarak! 🐑';
    }
    return '';
  }

  /// Get label for prayer time during Ramadan
  /// Returns special labels for Suhoor (Fajr) and Iftar (Maghrib)
  static String? getRamadanPrayerLabel(
    String prayerName,
    HijriDate date, {
    required bool isArabic,
  }) {
    if (!isRamadan(date)) return null;

    switch (prayerName.toLowerCase()) {
      case 'fajr':
        return isArabic ? 'السحور' : 'Suhoor';
      case 'maghrib':
        return isArabic ? 'الإفطار' : 'Iftar';
      default:
        return null;
    }
  }
}

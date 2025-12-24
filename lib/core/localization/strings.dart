import 'package:flutter/material.dart';
import 'app_locale_provider.dart';

/// Simple localization strings helper
const Map<String, Map<String, String>> _strings = {
  'ar': {
    'qibla': 'القبلة',
    'home': 'الرئيسية',
    'prayerTimes': 'مواقيت الصلاة',
    'settings': 'الإعدادات',
    'currentTime': 'الوقت الآن',
    'language': 'اللغة',
    'arabic': 'العربية',
    'english': 'English',
    'location': 'الموقع',
    'fullScreenNotification': 'إشعار ملء الشاشة',
    'compassHaptics': 'اهتزاز البوصلة',
    'chooseTheme': 'اختيار المظهر',
    'shareApp': 'مشاركة التطبيق',
    'rateApp': 'تقييم التطبيق',
    'aboutApp': 'عن التطبيق',
    'qiblaDirection': 'جهة الشرق',
    'fajr': 'الفجر',
    'dhuhr': 'الظهر',
    'asr': 'العصر',
    'maghrib': 'المغرب',
    'isha': 'العشاء',
    'country': 'الجزائر',
    'city': 'باتنة',
    // Location picker
    'changeLocation': 'تغيير الموقع',
    'selectLocation': 'اختيار الموقع',
    'searchPlaceholder': 'ابحث عن مدينة أو مكان...',
    'noResults': 'لا توجد نتائج',
    'confirm': 'تأكيد',
    'cancel': 'إلغاء',
    'searchRequiresInternet': 'البحث يحتاج إنترنت',
  },
  'en': {
    'qibla': 'Qibla',
    'home': 'Home',
    'prayerTimes': 'Prayer Times',
    'settings': 'Settings',
    'currentTime': 'Current Time',
    'language': 'Language',
    'arabic': 'العربية',
    'english': 'English',
    'location': 'Location',
    'fullScreenNotification': 'Full Screen Notification',
    'compassHaptics': 'Compass Haptics',
    'chooseTheme': 'Choose Theme',
    'shareApp': 'Share App',
    'rateApp': 'Rate App',
    'aboutApp': 'About App',
    'qiblaDirection': 'East Direction',
    'fajr': 'Fajr',
    'dhuhr': 'Dhuhr',
    'asr': 'Asr',
    'maghrib': 'Maghrib',
    'isha': 'Isha',
    'country': 'Algeria',
    'city': 'Batna',
    // Location picker
    'changeLocation': 'Change location',
    'selectLocation': 'Select location',
    'searchPlaceholder': 'Search for a city or place...',
    'noResults': 'No results found',
    'confirm': 'Confirm',
    'cancel': 'Cancel',
    'searchRequiresInternet': 'Search requires internet',
  },
};

/// Get translated string by key
String t(BuildContext context, String key) {
  final controller = AppLocaleProvider.of(context);
  final langCode = controller.locale.languageCode;
  return _strings[langCode]?[key] ?? _strings['en']?[key] ?? key;
}

/// Get prayer name by index
String getPrayerName(BuildContext context, int index) {
  final keys = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
  if (index < 0 || index >= keys.length) return '';
  return t(context, keys[index]);
}

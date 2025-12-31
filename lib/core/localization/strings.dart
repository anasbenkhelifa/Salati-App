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
    // Controls section
    'controlsTitle': 'التحكم',
    'controlsSubtitle': 'الإشعارات، الاهتزاز، المظهر',
    // Location picker
    'changeLocation': 'تغيير الموقع',
    'selectLocation': 'اختيار الموقع',
    'searchPlaceholder': 'ابحث عن مدينة أو مكان...',
    'noResults': 'لا توجد نتائج',
    'confirm': 'تأكيد',
    'cancel': 'إلغاء',
    'searchRequiresInternet': 'البحث يحتاج إنترنت',
    // Theme
    'nightMode': 'الوضع الداكن',
    'lightMode': 'الوضع الفاتح',
    // Adhan selection
    'selectAdhan': 'اختيار الأذان',
    'defaultAdhan': 'الأذان الافتراضي',
    'customAdhans': 'أذاناتي',
    'addCustomAdhan': 'إضافة أذان خاص',
    'applyToAllPrayers': 'تطبيق على كل الصلوات',
    'deleteAdhan': 'حذف الأذان',
    'fileTooLong': 'الملف طويل جداً (5 دقائق كحد أقصى)',
    'invalidFormat': 'صيغة غير مدعومة',
    'adhanAdded': 'تم إضافة الأذان',
    'adhanDeleted': 'تم حذف الأذان',
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
    // Controls section
    'controlsTitle': 'Controls',
    'controlsSubtitle': 'Notifications, haptics, theme',
    // Location picker
    'changeLocation': 'Change location',
    'selectLocation': 'Select location',
    'searchPlaceholder': 'Search for a city or place...',
    'noResults': 'No results found',
    'confirm': 'Confirm',
    'cancel': 'Cancel',
    'searchRequiresInternet': 'Search requires internet',
    // Theme
    'nightMode': 'Night Mode',
    'lightMode': 'Light Mode',
    // Adhan selection
    'selectAdhan': 'Select Adhan',
    'defaultAdhan': 'Default Adhan',
    'customAdhans': 'My Adhans',
    'addCustomAdhan': 'Add Custom Adhan',
    'applyToAllPrayers': 'Apply to All Prayers',
    'deleteAdhan': 'Delete Adhan',
    'fileTooLong': 'File too long (5 minutes max)',
    'invalidFormat': 'Unsupported format',
    'adhanAdded': 'Adhan added',
    'adhanDeleted': 'Adhan deleted',
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

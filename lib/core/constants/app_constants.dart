/// App-wide constants
class AppConstants {
  // Screen indices for navigation
  static const int qiblaIndex = 0;
  static const int homeIndex = 1;
  static const int prayerTimesIndex = 2;
  static const int settingsIndex = 3;

  // App info
  static const String appName = 'أذان';
  static const String appNameEn = 'Adhan';

  // Prayer names in Arabic
  static const List<String> prayerNames = [
    'الفجر',
    'الظهر',
    'العصر',
    'المغرب',
    'العشاء',
  ];

  // Placeholder prayer times
  static const List<String> prayerTimes = [
    '٠٦:١٠',
    '١٢:٣٥',
    '١٥:٠٩',
    '١٧:٢٧',
    '١٨:٥٨',
  ];
}

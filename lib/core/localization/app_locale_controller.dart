import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';
import '../../data/services/analytics_service.dart';

/// Controller for app-wide locale management
class AppLocaleController extends ChangeNotifier {
  Locale _locale = const Locale('ar');
  bool _initialized = false;

  Locale get locale => _locale;

  bool get isArabic => _locale.languageCode == 'ar';

  TextDirection get textDirection =>
      _locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr;

  /// Initialize locale from saved preference, or detect device language on first launch.
  /// Once user manually changes language, the saved preference is always respected.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLang = prefs.getString('app_language');

      if (savedLang != null) {
        // User has a saved preference — always respect it
        _locale = Locale(savedLang);
        debugPrint('[AppLocaleController] Loaded saved language: $savedLang');
      } else {
        // First launch — detect device language
        final deviceLang = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
        String detectedLang;
        if (deviceLang == 'ar') {
          detectedLang = 'ar';
        } else if (deviceLang == 'fr') {
          detectedLang = 'fr';
        } else {
          detectedLang = 'en'; // Fallback for all other languages
        }
        _locale = Locale(detectedLang);
        await prefs.setString('app_language', detectedLang);
        debugPrint('[AppLocaleController] First launch — device=$deviceLang, set=$detectedLang');
      }

      _initialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[AppLocaleController] Error initializing: $e');
    }
  }

  void setLocale(Locale newLocale) {
    AnalyticsService.instance.logLanguageChanged(newLocale.languageCode);
    if (_locale != newLocale) {
      _locale = newLocale;
      _saveLanguageToCache(newLocale.languageCode);
      notifyListeners();
    }
  }

  void toggle() {
    setLocale(
      _locale.languageCode == 'ar' ? const Locale('en') : const Locale('ar'),
    );
  }

  /// Save language to SharedPreferences for native Android service access
  Future<void> _saveLanguageToCache(String langCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_language', langCode);
      debugPrint('[AppLocaleController] Saved app_language: $langCode');

      // Update home screen widget to reflect language change
      await HomeWidget.updateWidget(
        name: 'PrayerWidgetProvider',
        iOSName: 'PrayerWidget',
        qualifiedAndroidName: 'com.example.adhan_app.PrayerWidgetProvider',
      );
      debugPrint('[AppLocaleController] Widget update triggered');
    } catch (e) {
      debugPrint('[AppLocaleController] Error saving language: $e');
    }
  }
}

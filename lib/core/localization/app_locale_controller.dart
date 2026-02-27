import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';

/// Controller for app-wide locale management
class AppLocaleController extends ChangeNotifier {
  Locale _locale = const Locale('ar');
  bool _initialized = false;

  Locale get locale => _locale;

  bool get isArabic => _locale.languageCode == 'ar';

  TextDirection get textDirection =>
      _locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr;

  /// Initialize locale from saved preference or set default Arabic
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLang = prefs.getString('app_language');

      if (savedLang != null) {
        // Load saved language
        _locale = Locale(savedLang);
        debugPrint('[AppLocaleController] Loaded saved language: $savedLang');
      } else {
        // First launch - save Arabic as default
        await prefs.setString('app_language', 'ar');
        debugPrint('[AppLocaleController] First launch - saved default: ar');
      }

      _initialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[AppLocaleController] Error initializing: $e');
    }
  }

  void setLocale(Locale newLocale) {
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

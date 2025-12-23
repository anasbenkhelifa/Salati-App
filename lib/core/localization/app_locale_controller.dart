import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controller for app-wide locale management
class AppLocaleController extends ChangeNotifier {
  Locale _locale = const Locale('ar');

  Locale get locale => _locale;

  bool get isArabic => _locale.languageCode == 'ar';

  TextDirection get textDirection =>
      _locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr;

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
    } catch (e) {
      debugPrint('[AppLocaleController] Error saving language: $e');
    }
  }
}

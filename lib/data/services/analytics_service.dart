import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized analytics service for tracking all user actions.
/// Uses Firebase Analytics under the hood.
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  static AnalyticsService get instance => _instance;
  AnalyticsService._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  // ── App Lifecycle ──────────────────────────────────────────────

  /// Log when the app is opened
  Future<void> logAppOpened() async {
    await _analytics.logAppOpen();
    debugPrint('[Analytics] app_open');
  }

  /// Set user properties from saved preferences for aggregate segmentation
  Future<void> setUserProperties() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final theme = prefs.getString('app_theme_mode') ?? 'islamicGreen';
      final lang = prefs.getString('app_language') ?? 'ar';
      final liveNotif = prefs.getInt('live_notification_mode') ?? 1;
      final maxVol = prefs.getBool('max_volume_override') ?? false;
      final preAdhan = prefs.getBool('pre_adhan_enabled') ?? true;

      await _analytics.setUserProperty(name: 'theme', value: theme);
      await _analytics.setUserProperty(name: 'language', value: lang);
      await _analytics.setUserProperty(name: 'live_notif_mode', value: _liveNotifModeName(liveNotif));
      await _analytics.setUserProperty(name: 'max_volume', value: maxVol.toString());
      await _analytics.setUserProperty(name: 'pre_adhan', value: preAdhan.toString());
      debugPrint('[Analytics] User properties set: theme=$theme, lang=$lang');
    } catch (e) {
      debugPrint('[Analytics] Error setting user properties: $e');
    }
  }

  // ── Theme ──────────────────────────────────────────────────────

  Future<void> logThemeChanged(String theme) async {
    await _analytics.logEvent(name: 'theme_changed', parameters: {'theme': theme});
    await _analytics.setUserProperty(name: 'theme', value: theme);
    debugPrint('[Analytics] theme_changed: $theme');
  }

  // ── Language ───────────────────────────────────────────────────

  Future<void> logLanguageChanged(String language) async {
    await _analytics.logEvent(name: 'language_changed', parameters: {'language': language});
    await _analytics.setUserProperty(name: 'language', value: language);
    debugPrint('[Analytics] language_changed: $language');
  }

  // ── Page Views ─────────────────────────────────────────────────

  /// Logs a screen change. Uses Firebase's reserved `screen_view` event so the
  /// data lands in the GA4 *Screens* report — a custom `page_view` event would
  /// only show up as an unattached custom event (and collides with the name
  /// GA4 auto-collects on web).
  Future<void> logPageView(String pageName) async {
    await _analytics.logScreenView(
      screenName: pageName,
      screenClass: 'AppShell',
    );
    debugPrint('[Analytics] screen_view: $pageName');
  }

  // ── Settings Toggles ──────────────────────────────────────────

  Future<void> logLiveNotifModeChanged(int mode) async {
    final modeName = _liveNotifModeName(mode);
    await _analytics.logEvent(name: 'live_notif_mode_changed', parameters: {'mode': modeName});
    await _analytics.setUserProperty(name: 'live_notif_mode', value: modeName);
    debugPrint('[Analytics] live_notif_mode_changed: $modeName');
  }

  Future<void> logMaxVolumeToggled(bool enabled) async {
    await _analytics.logEvent(name: 'max_volume_toggled', parameters: {'enabled': enabled.toString()});
    await _analytics.setUserProperty(name: 'max_volume', value: enabled.toString());
    debugPrint('[Analytics] max_volume_toggled: $enabled');
  }

  Future<void> logPreAdhanToggled(bool enabled) async {
    await _analytics.logEvent(name: 'pre_adhan_toggled', parameters: {'enabled': enabled.toString()});
    await _analytics.setUserProperty(name: 'pre_adhan', value: enabled.toString());
    debugPrint('[Analytics] pre_adhan_toggled: $enabled');
  }

  Future<void> logCompassHapticsToggled(bool enabled) async {
    await _analytics.logEvent(name: 'compass_haptics_toggled', parameters: {'enabled': enabled.toString()});
    debugPrint('[Analytics] compass_haptics_toggled: $enabled');
  }

  // ── Alert Mode (per prayer) ────────────────────────────────────

  Future<void> logAlertModeChanged(String prayer, String mode) async {
    await _analytics.logEvent(name: 'alert_mode_changed', parameters: {
      'prayer': prayer,
      'mode': mode,
    });
    debugPrint('[Analytics] alert_mode_changed: $prayer=$mode');
  }

  // ── Location ───────────────────────────────────────────────────

  Future<void> logLocationSet(String city, String country) async {
    await _analytics.logEvent(name: 'location_set', parameters: {
      'city': city,
      'country': country,
    });
    debugPrint('[Analytics] location_set: $city, $country');
  }

  // ── Calculation Method ─────────────────────────────────────────

  Future<void> logCalculationMethodChanged(String method) async {
    await _analytics.logEvent(name: 'calculation_method_changed', parameters: {'method': method});
    debugPrint('[Analytics] calculation_method_changed: $method');
  }

  // ── Helpers ────────────────────────────────────────────────────

  String _liveNotifModeName(int mode) {
    switch (mode) {
      case 0: return 'disabled';
      case 1: return 'static';
      case 2: return 'dynamic';
      default: return 'unknown';
    }
  }
}

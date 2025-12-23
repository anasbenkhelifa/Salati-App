import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'prayer_times_api_service.dart';

/// Cached app state for offline-first behavior
class CachedAppState {
  final double latitude;
  final double longitude;
  final String cityEn;
  final String cityAr;
  final String countryEn;
  final String countryAr;
  final AlAdhanResponse? prayerTimes;
  final String prayerTimesDate; // yyyy-MM-dd
  final CalculationMethodId method;
  final MadhabId madhab;
  final DateTime updatedAt;

  CachedAppState({
    required this.latitude,
    required this.longitude,
    required this.cityEn,
    required this.cityAr,
    required this.countryEn,
    required this.countryAr,
    required this.prayerTimes,
    required this.prayerTimesDate,
    required this.method,
    required this.madhab,
    required this.updatedAt,
  });

  /// Check if prayer times are for today
  bool get isToday {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return prayerTimesDate == today;
  }

  /// Get city-only display name (for notification)
  String getCityOnly(bool isArabic) {
    if (isArabic) {
      return cityAr.isNotEmpty ? cityAr : countryAr;
    } else {
      return cityEn.isNotEmpty ? cityEn : countryEn;
    }
  }

  /// Get full display name (for Prayer Times screen)
  String getFullDisplayName(bool isArabic) {
    if (isArabic) {
      return '$countryAr • $cityAr';
    } else {
      return '$countryEn • $cityEn';
    }
  }
}

/// Service to cache API responses, location, and settings
class PrayerTimesCacheService {
  // Keys
  static const _keySetupDone = 'cached_setup_done';
  static const _keyLat = 'cached_lat';
  static const _keyLng = 'cached_lng';
  static const _keyCityEn = 'cached_city_en';
  static const _keyCityAr = 'cached_city_ar';
  static const _keyCountryEn = 'cached_country_en';
  static const _keyCountryAr = 'cached_country_ar';
  static const _keyPrayerTimesJson = 'cached_prayer_times_json';
  static const _keyPrayerTimesDate = 'cached_prayer_times_date';
  static const _keyMethodId = 'cached_method_id';
  static const _keyMadhabId = 'cached_madhab_id';
  static const _keyUpdatedAt = 'cached_updated_at';

  // Legacy keys (for backwards compatibility)
  static const _keySettingsMethod = 'settings_method';
  static const _keySettingsMadhab = 'settings_madhab';
  static const _keyLocationNameEn = 'location_name_en';
  static const _keyLocationNameAr = 'location_name_ar';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ========== SETUP FLAG ==========

  /// Check if first-time setup has been completed
  Future<bool> isSetupDone() async {
    final prefs = await _preferences;
    return prefs.getBool(_keySetupDone) ?? false;
  }

  /// Mark setup as complete
  Future<void> markSetupDone() async {
    final prefs = await _preferences;
    await prefs.setBool(_keySetupDone, true);
    debugPrint('[PrayerTimesCacheService] Setup marked as done');
  }

  // ========== UNIFIED CACHE ==========

  /// Save complete app state to cache
  Future<void> saveAppState({
    required double latitude,
    required double longitude,
    required String cityEn,
    required String cityAr,
    required String countryEn,
    required String countryAr,
    required AlAdhanResponse prayerTimes,
    required String prayerTimesDate,
    required CalculationMethodId method,
    required MadhabId madhab,
  }) async {
    final prefs = await _preferences;

    await prefs.setDouble(_keyLat, latitude);
    await prefs.setDouble(_keyLng, longitude);
    await prefs.setString(_keyCityEn, cityEn);
    await prefs.setString(_keyCityAr, cityAr);
    await prefs.setString(_keyCountryEn, countryEn);
    await prefs.setString(_keyCountryAr, countryAr);
    await prefs.setString(
      _keyPrayerTimesJson,
      jsonEncode(prayerTimes.toJson()),
    );
    await prefs.setString(_keyPrayerTimesDate, prayerTimesDate);
    await prefs.setInt(_keyMethodId, method.id);
    await prefs.setInt(_keyMadhabId, madhab.id);
    await prefs.setInt(_keyUpdatedAt, DateTime.now().millisecondsSinceEpoch);

    // Also save legacy keys for backwards compatibility
    await prefs.setInt(_keySettingsMethod, method.id);
    await prefs.setInt(_keySettingsMadhab, madhab.id);
    await prefs.setString(_keyLocationNameEn, '$countryEn • $cityEn');
    await prefs.setString(_keyLocationNameAr, '$countryAr • $cityAr');

    await markSetupDone();

    debugPrint(
      '[PrayerTimesCacheService] App state saved: $cityEn, $prayerTimesDate',
    );
  }

  /// Load complete app state from cache
  Future<CachedAppState?> loadAppState() async {
    final prefs = await _preferences;

    final lat = prefs.getDouble(_keyLat);
    final lng = prefs.getDouble(_keyLng);

    if (lat == null || lng == null) {
      debugPrint('[PrayerTimesCacheService] No cached location');
      return null;
    }

    final cityEn = prefs.getString(_keyCityEn) ?? '';
    final cityAr = prefs.getString(_keyCityAr) ?? '';
    final countryEn = prefs.getString(_keyCountryEn) ?? '';
    final countryAr = prefs.getString(_keyCountryAr) ?? '';
    final prayerTimesJson = prefs.getString(_keyPrayerTimesJson);
    final prayerTimesDate = prefs.getString(_keyPrayerTimesDate) ?? '';
    final methodId = prefs.getInt(_keyMethodId) ?? 3;
    final madhabId = prefs.getInt(_keyMadhabId) ?? 1;
    final updatedAt = prefs.getInt(_keyUpdatedAt) ?? 0;

    AlAdhanResponse? prayerTimes;
    if (prayerTimesJson != null) {
      try {
        prayerTimes = AlAdhanResponse.fromJson(
          jsonDecode(prayerTimesJson),
          isFromCache: true,
        );
      } catch (e) {
        debugPrint('[PrayerTimesCacheService] Error parsing prayer times: $e');
      }
    }

    final method = CalculationMethodId.values.firstWhere(
      (m) => m.id == methodId,
      orElse: () => CalculationMethodId.mwl,
    );

    final madhab = MadhabId.values.firstWhere(
      (m) => m.id == madhabId,
      orElse: () => MadhabId.shafi,
    );

    debugPrint(
      '[PrayerTimesCacheService] Loaded state: $cityEn, date=$prayerTimesDate',
    );

    return CachedAppState(
      latitude: lat,
      longitude: lng,
      cityEn: cityEn,
      cityAr: cityAr,
      countryEn: countryEn,
      countryAr: countryAr,
      prayerTimes: prayerTimes,
      prayerTimesDate: prayerTimesDate,
      method: method,
      madhab: madhab,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAt),
    );
  }

  /// Update only prayer times in cache (for daily refresh using cached location)
  Future<void> updatePrayerTimes({
    required AlAdhanResponse prayerTimes,
    required String prayerTimesDate,
  }) async {
    final prefs = await _preferences;
    await prefs.setString(
      _keyPrayerTimesJson,
      jsonEncode(prayerTimes.toJson()),
    );
    await prefs.setString(_keyPrayerTimesDate, prayerTimesDate);
    await prefs.setInt(_keyUpdatedAt, DateTime.now().millisecondsSinceEpoch);
    debugPrint(
      '[PrayerTimesCacheService] Prayer times updated for $prayerTimesDate',
    );
  }

  // ========== SETTINGS (legacy support) ==========

  /// Save calculation method setting
  Future<void> saveMethod(CalculationMethodId method) async {
    final prefs = await _preferences;
    await prefs.setInt(_keySettingsMethod, method.id);
    await prefs.setInt(_keyMethodId, method.id);
  }

  /// Load calculation method setting
  Future<CalculationMethodId> loadMethod() async {
    final prefs = await _preferences;
    final methodId =
        prefs.getInt(_keyMethodId) ?? prefs.getInt(_keySettingsMethod);
    if (methodId != null) {
      return CalculationMethodId.values.firstWhere(
        (m) => m.id == methodId,
        orElse: () => CalculationMethodId.mwl,
      );
    }
    return CalculationMethodId.mwl;
  }

  /// Save madhab setting
  Future<void> saveMadhab(MadhabId madhab) async {
    final prefs = await _preferences;
    await prefs.setInt(_keySettingsMadhab, madhab.id);
    await prefs.setInt(_keyMadhabId, madhab.id);
  }

  /// Load madhab setting
  Future<MadhabId> loadMadhab() async {
    final prefs = await _preferences;
    final madhabId =
        prefs.getInt(_keyMadhabId) ?? prefs.getInt(_keySettingsMadhab);
    if (madhabId != null) {
      return MadhabId.values.firstWhere(
        (m) => m.id == madhabId,
        orElse: () => MadhabId.shafi,
      );
    }
    return MadhabId.shafi;
  }

  // ========== LOCATION NAME (legacy support) ==========

  /// Save location display name
  Future<void> saveLocationName({
    required String nameEn,
    required String nameAr,
  }) async {
    final prefs = await _preferences;
    await prefs.setString(_keyLocationNameEn, nameEn);
    await prefs.setString(_keyLocationNameAr, nameAr);
  }

  /// Load location display name
  Future<({String nameEn, String nameAr})> loadLocationName() async {
    final prefs = await _preferences;
    return (
      nameEn: prefs.getString(_keyLocationNameEn) ?? 'Current Location',
      nameAr: prefs.getString(_keyLocationNameAr) ?? 'الموقع الحالي',
    );
  }

  // ========== LEGACY METHODS (for backwards compatibility) ==========

  Future<void> saveLastPosition(double latitude, double longitude) async {
    final prefs = await _preferences;
    await prefs.setDouble(_keyLat, latitude);
    await prefs.setDouble(_keyLng, longitude);
  }

  Future<({double lat, double lon})?> loadLastPosition() async {
    final prefs = await _preferences;
    final lat = prefs.getDouble(_keyLat);
    final lon = prefs.getDouble(_keyLng);
    if (lat != null && lon != null) {
      return (lat: lat, lon: lon);
    }
    return null;
  }

  Future<void> saveApiResponse({
    required AlAdhanResponse response,
    required String date,
    required double latitude,
    required double longitude,
    required int methodId,
    required int madhabId,
  }) async {
    await updatePrayerTimes(prayerTimes: response, prayerTimesDate: date);
  }

  Future<AlAdhanResponse?> loadCachedResponse({
    required String date,
    required double latitude,
    required double longitude,
    required int methodId,
    required int madhabId,
  }) async {
    final state = await loadAppState();
    if (state?.prayerTimesDate == date) {
      return state?.prayerTimes;
    }
    return null;
  }
}

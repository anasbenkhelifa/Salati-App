import 'package:shared_preferences/shared_preferences.dart';

/// Service to cache location data locally
class CacheService {
  static const _keyLat = 'cached_latitude';
  static const _keyLng = 'cached_longitude';
  static const _keyUpdated = 'cached_updated';
  static const _keyCountryAr = 'cached_country_ar';
  static const _keyCountryEn = 'cached_country_en';
  static const _keyCityAr = 'cached_city_ar';
  static const _keyCityEn = 'cached_city_en';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Save location coordinates
  Future<void> saveLocation(double lat, double lng) async {
    final prefs = await _preferences;
    await prefs.setDouble(_keyLat, lat);
    await prefs.setDouble(_keyLng, lng);
    await prefs.setInt(_keyUpdated, DateTime.now().millisecondsSinceEpoch);
  }

  /// Get cached location (lat, lng) or null if not cached
  Future<({double lat, double lng})?> getLocation() async {
    final prefs = await _preferences;
    final lat = prefs.getDouble(_keyLat);
    final lng = prefs.getDouble(_keyLng);
    if (lat != null && lng != null) {
      return (lat: lat, lng: lng);
    }
    return null;
  }

  /// Save location names
  Future<void> saveLocationNames({
    required String countryAr,
    required String countryEn,
    required String cityAr,
    required String cityEn,
  }) async {
    final prefs = await _preferences;
    await prefs.setString(_keyCountryAr, countryAr);
    await prefs.setString(_keyCountryEn, countryEn);
    await prefs.setString(_keyCityAr, cityAr);
    await prefs.setString(_keyCityEn, cityEn);
  }

  /// Get cached location names
  Future<({String countryAr, String countryEn, String cityAr, String cityEn})?>
  getLocationNames() async {
    final prefs = await _preferences;
    final countryAr = prefs.getString(_keyCountryAr);
    final countryEn = prefs.getString(_keyCountryEn);
    final cityAr = prefs.getString(_keyCityAr);
    final cityEn = prefs.getString(_keyCityEn);

    if (countryAr != null &&
        countryEn != null &&
        cityAr != null &&
        cityEn != null) {
      return (
        countryAr: countryAr,
        countryEn: countryEn,
        cityAr: cityAr,
        cityEn: cityEn,
      );
    }
    return null;
  }

  /// Check if cache exists
  Future<bool> hasCache() async {
    final prefs = await _preferences;
    return prefs.containsKey(_keyLat) && prefs.containsKey(_keyLng);
  }

  /// Get last updated timestamp
  Future<DateTime?> getLastUpdated() async {
    final prefs = await _preferences;
    final ms = prefs.getInt(_keyUpdated);
    if (ms != null) {
      return DateTime.fromMillisecondsSinceEpoch(ms);
    }
    return null;
  }
}

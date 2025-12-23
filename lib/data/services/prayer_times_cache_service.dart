import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'prayer_times_api_service.dart';

/// Service to cache API responses, location, and settings
class PrayerTimesCacheService {
  static const _keyApiResponse = 'cached_api_response';
  static const _keyApiDate = 'cached_api_date';
  static const _keyApiLat = 'cached_api_lat';
  static const _keyApiLon = 'cached_api_lon';
  static const _keyApiMethod = 'cached_api_method';
  static const _keyApiMadhab = 'cached_api_madhab';
  static const _keySettingsMethod = 'settings_method';
  static const _keySettingsMadhab = 'settings_madhab';
  static const _keyLastLat = 'last_known_lat';
  static const _keyLastLon = 'last_known_lon';
  static const _keyLocationNameEn = 'location_name_en';
  static const _keyLocationNameAr = 'location_name_ar';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Round lat/lon to 3 decimals for cache key (~111m precision)
  String _roundCoord(double coord) => coord.toStringAsFixed(3);

  /// Save API response to cache
  Future<void> saveApiResponse({
    required AlAdhanResponse response,
    required String date,
    required double latitude,
    required double longitude,
    required int methodId,
    required int madhabId,
  }) async {
    final prefs = await _preferences;
    await prefs.setString(_keyApiResponse, jsonEncode(response.toJson()));
    await prefs.setString(_keyApiDate, date);
    await prefs.setString(_keyApiLat, _roundCoord(latitude));
    await prefs.setString(_keyApiLon, _roundCoord(longitude));
    await prefs.setInt(_keyApiMethod, methodId);
    await prefs.setInt(_keyApiMadhab, madhabId);
  }

  /// Load cached API response if valid for the given parameters
  Future<AlAdhanResponse?> loadCachedResponse({
    required String date,
    required double latitude,
    required double longitude,
    required int methodId,
    required int madhabId,
  }) async {
    final prefs = await _preferences;

    // Check if cache matches current parameters (with rounded coords)
    final cachedDate = prefs.getString(_keyApiDate);
    final cachedLat = prefs.getString(_keyApiLat);
    final cachedLon = prefs.getString(_keyApiLon);
    final cachedMethod = prefs.getInt(_keyApiMethod);
    final cachedMadhab = prefs.getInt(_keyApiMadhab);

    if (cachedDate == date &&
        cachedLat == _roundCoord(latitude) &&
        cachedLon == _roundCoord(longitude) &&
        cachedMethod == methodId &&
        cachedMadhab == madhabId) {
      final responseJson = prefs.getString(_keyApiResponse);
      if (responseJson != null) {
        try {
          final json = jsonDecode(responseJson);
          return AlAdhanResponse.fromJson(json, isFromCache: true);
        } catch (e) {
          return null;
        }
      }
    }
    return null;
  }

  /// Save calculation method setting
  Future<void> saveMethod(CalculationMethodId method) async {
    final prefs = await _preferences;
    await prefs.setInt(_keySettingsMethod, method.id);
  }

  /// Load calculation method setting
  Future<CalculationMethodId> loadMethod() async {
    final prefs = await _preferences;
    final methodId = prefs.getInt(_keySettingsMethod);
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
  }

  /// Load madhab setting
  Future<MadhabId> loadMadhab() async {
    final prefs = await _preferences;
    final madhabId = prefs.getInt(_keySettingsMadhab);
    if (madhabId != null) {
      return MadhabId.values.firstWhere(
        (m) => m.id == madhabId,
        orElse: () => MadhabId.shafi,
      );
    }
    return MadhabId.shafi;
  }

  /// Save last known position
  Future<void> saveLastPosition(double latitude, double longitude) async {
    final prefs = await _preferences;
    await prefs.setDouble(_keyLastLat, latitude);
    await prefs.setDouble(_keyLastLon, longitude);
  }

  /// Load last known position
  Future<({double lat, double lon})?> loadLastPosition() async {
    final prefs = await _preferences;
    final lat = prefs.getDouble(_keyLastLat);
    final lon = prefs.getDouble(_keyLastLon);
    if (lat != null && lon != null) {
      return (lat: lat, lon: lon);
    }
    return null;
  }

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
}

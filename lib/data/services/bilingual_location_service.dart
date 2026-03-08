import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'city_translations.dart';

/// Bilingual location data model
class BilingualLocation {
  final double latitude;
  final double longitude;
  final String cityEn;
  final String cityAr;
  final String countryEn;
  final String countryAr;
  final String isoCountryCode;

  BilingualLocation({
    required this.latitude,
    required this.longitude,
    required this.cityEn,
    required this.cityAr,
    required this.countryEn,
    required this.countryAr,
    required this.isoCountryCode,
  });

  /// Get FULL display name (Country • City) for Prayer Times screen
  String getDisplayName(bool isArabic) {
    if (isArabic) {
      return '$countryAr • $cityAr';
    } else {
      return '$countryEn • $cityEn';
    }
  }

  /// Get CITY ONLY display name for notification header
  String getCityOnly(bool isArabic) {
    if (isArabic) {
      return cityAr.isNotEmpty ? cityAr : countryAr;
    } else {
      return cityEn.isNotEmpty ? cityEn : countryEn;
    }
  }

  /// Convert to JSON for caching
  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'cityEn': cityEn,
    'cityAr': cityAr,
    'countryEn': countryEn,
    'countryAr': countryAr,
    'isoCountryCode': isoCountryCode,
  };

  /// Factory from cached JSON
  factory BilingualLocation.fromJson(Map<String, dynamic> json) {
    return BilingualLocation(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      cityEn: json['cityEn'] ?? '',
      cityAr: json['cityAr'] ?? '',
      countryEn: json['countryEn'] ?? '',
      countryAr: json['countryAr'] ?? '',
      isoCountryCode: json['isoCountryCode'] ?? 'DZ',
    );
  }
}

/// Service to get bilingual location names using offline `geocoding` package
class BilingualLocationService {
  static const String _cacheKey = 'bilingual_location_cache';

  /// Reverse geocode to get bilingual location names
  /// Fetches both English and Arabic names natively via device OS and caches them
  Future<BilingualLocation?> getLocationNames(
    double latitude,
    double longitude,
  ) async {
    // Try cache first (with proximity check)
    final cached = await _loadFromCache();
    if (cached != null &&
        _isNearby(cached.latitude, cached.longitude, latitude, longitude)) {
      debugPrint('[BilingualLocationService] Using cached location');
      return cached;
    }

    try {
      // Fetch English version natively (no explicit locale identifier forced)
      final enResult = await _fetchFromNativeGeocoding(latitude, longitude);

      if (enResult != null) {
        final cityEn = enResult['city'] ?? '';
        final countryEn = enResult['country'] ?? '';

        final isoCountryCode = enResult['isoCountryCode'] ?? 'DZ';

        // Attempt to translate via local mapping, otherwise fallback to English
        final cityAr = CityTranslations.lookup(cityEn) ?? cityEn;
        final countryAr = CityTranslations.lookup(countryEn) ?? countryEn;

        final location = BilingualLocation(
          latitude: latitude,
          longitude: longitude,
          cityEn: cityEn,
          cityAr: cityAr,
          countryEn: countryEn,
          countryAr: countryAr,
          isoCountryCode: isoCountryCode,
        );

        // Cache the result
        await _saveToCache(location);
        debugPrint(
          '[BilingualLocationService] Fetched: EN=${location.getDisplayName(false)}, AR=${location.getDisplayName(true)}',
        );

        return location;
      }
    } catch (e) {
      debugPrint('[BilingualLocationService] Error: $e');
    }

    return null;
  }

  /// Fetch location natively via OS
  Future<Map<String, String>?> _fetchFromNativeGeocoding(
    double lat,
    double lon,
  ) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lon);
      
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return {
          'city': place.locality ?? place.subLocality ?? place.administrativeArea ?? '',
          'country': place.country ?? '',
          'isoCountryCode': place.isoCountryCode ?? 'DZ',
        };
      }
    } catch (e) {
      debugPrint('[BilingualLocationService] Native geocoding error: $e');
    }
    return null;
  }

  /// Check if coordinates are nearby (within ~1km)
  bool _isNearby(double lat1, double lon1, double lat2, double lon2) {
    const threshold = 0.01; // ~1km
    return (lat1 - lat2).abs() < threshold && (lon1 - lon2).abs() < threshold;
  }

  /// Load from cache
  Future<BilingualLocation?> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_cacheKey);
      if (jsonStr != null) {
        final json = jsonDecode(jsonStr);
        return BilingualLocation.fromJson(json);
      }
    } catch (e) {
      debugPrint('[BilingualLocationService] Cache load error: $e');
    }
    return null;
  }

  /// Save to cache
  Future<void> _saveToCache(BilingualLocation location) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(location.toJson());
      await prefs.setString(_cacheKey, jsonStr);
    } catch (e) {
      debugPrint('[BilingualLocationService] Cache save error: $e');
    }
  }
}

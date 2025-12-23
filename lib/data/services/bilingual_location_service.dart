import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Bilingual location data model
class BilingualLocation {
  final double latitude;
  final double longitude;
  final String cityEn;
  final String cityAr;
  final String countryEn;
  final String countryAr;

  BilingualLocation({
    required this.latitude,
    required this.longitude,
    required this.cityEn,
    required this.cityAr,
    required this.countryEn,
    required this.countryAr,
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
    );
  }
}

/// Service to get bilingual location names using Nominatim API
class BilingualLocationService {
  static const String _nominatimBaseUrl =
      'https://nominatim.openstreetmap.org/reverse';
  static const String _cacheKey = 'bilingual_location_cache';

  /// Reverse geocode to get bilingual location names
  /// Fetches both English and Arabic names and caches them
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
      // Fetch English version
      final enResult = await _fetchFromNominatim(latitude, longitude, 'en');

      // Fetch Arabic version
      final arResult = await _fetchFromNominatim(latitude, longitude, 'ar');

      if (enResult != null && arResult != null) {
        final location = BilingualLocation(
          latitude: latitude,
          longitude: longitude,
          cityEn:
              enResult['city'] ??
              enResult['town'] ??
              enResult['village'] ??
              enResult['state'] ??
              '',
          cityAr:
              arResult['city'] ??
              arResult['town'] ??
              arResult['village'] ??
              arResult['state'] ??
              '',
          countryEn: enResult['country'] ?? '',
          countryAr: arResult['country'] ?? '',
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

  /// Fetch location from Nominatim with specific language
  Future<Map<String, String>?> _fetchFromNominatim(
    double lat,
    double lon,
    String lang,
  ) async {
    try {
      final url = Uri.parse(
        '$_nominatimBaseUrl?lat=$lat&lon=$lon&format=json&accept-language=$lang&addressdetails=1',
      );

      final response = await http
          .get(url, headers: {'User-Agent': 'AdhanApp/1.0 (prayer times app)'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final address = json['address'] as Map<String, dynamic>?;

        if (address != null) {
          return {
            'city':
                address['city']?.toString() ??
                address['town']?.toString() ??
                address['village']?.toString() ??
                '',
            'town': address['town']?.toString() ?? '',
            'village': address['village']?.toString() ?? '',
            'state': address['state']?.toString() ?? '',
            'country': address['country']?.toString() ?? '',
          };
        }
      }
    } catch (e) {
      debugPrint('[BilingualLocationService] Nominatim error ($lang): $e');
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

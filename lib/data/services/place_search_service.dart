import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/place_result.dart';
import '../../core/localization/western_digits.dart';

/// Service for searching places using OpenStreetMap Nominatim API
class PlaceSearchService {
  static const String _baseUrl = 'https://nominatim.openstreetmap.org/search';
  static const String _userAgent = 'AdhanApp/1.0 (Flutter)';

  /// Search for places by query
  /// Returns list of PlaceResult, empty list on error
  Future<List<PlaceResult>> search(
    String query, {
    required bool isArabic,
  }) async {
    if (query.trim().isEmpty) return [];

    try {
      final langCode = isArabic ? 'ar' : 'en';
      final uri = Uri.parse(_baseUrl).replace(
        queryParameters: {
          'format': 'json',
          'addressdetails': '1',
          'limit': '8',
          'q': query,
          'accept-language': langCode,
        },
      );

      debugPrint('[PlaceSearchService] Searching: $query (lang=$langCode)');

      final response = await http
          .get(
            uri,
            headers: {'User-Agent': _userAgent, 'Accept-Language': langCode},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('[PlaceSearchService] HTTP error: ${response.statusCode}');
        return [];
      }

      final List<dynamic> data = json.decode(response.body);

      final results =
          data
              .map(
                (json) =>
                    PlaceResult.fromNominatim(json as Map<String, dynamic>),
              )
              .where((place) => place.lat != 0 && place.lng != 0)
              .map(
                (place) => PlaceResult(
                  lat: place.lat,
                  lng: place.lng,
                  cityName: westernDigits(place.cityName),
                  countryName: westernDigits(place.countryName),
                  isoCountryCode: place.isoCountryCode,
                  displayLabel: westernDigits(place.displayLabel),
                ),
              )
              .toList();

      debugPrint('[PlaceSearchService] Found ${results.length} results');
      return results;
    } catch (e) {
      debugPrint('[PlaceSearchService] Error: $e');
      return [];
    }
  }
}

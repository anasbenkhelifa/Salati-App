import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Response model for Qibla direction API
class QiblaResponse {
  final double direction;
  final double distanceKm;
  final String compassBearing;
  final bool isFromCache;
  final String requestUrl;

  QiblaResponse({
    required this.direction,
    required this.distanceKm,
    required this.compassBearing,
    this.isFromCache = false,
    this.requestUrl = '',
  });

  /// Parse from IslamicAPI format
  factory QiblaResponse.fromIslamicApi(
    Map<String, dynamic> json, {
    String requestUrl = '',
  }) {
    final qibla = json['data']?['qibla'] ?? {};
    final direction = qibla['direction'] ?? {};
    final distance = qibla['distance'] ?? {};

    return QiblaResponse(
      direction: (direction['degrees'] ?? 0.0).toDouble(),
      distanceKm: (distance['value'] ?? 0.0).toDouble(),
      compassBearing: direction['from'] ?? 'North',
      isFromCache: false,
      requestUrl: requestUrl,
    );
  }

  /// Parse from cache
  factory QiblaResponse.fromCache(double direction) {
    return QiblaResponse(
      direction: direction,
      distanceKm: 0,
      compassBearing: '',
      isFromCache: true,
    );
  }
}

/// Service to fetch Qibla direction from IslamicAPI
/// https://islamicapi.com/doc/prayer-time/ (includes qibla in response)
class QiblaApiService {
  static const String _baseUrl = 'https://islamicapi.com/api/v1/prayer-time/';
  static const String _apiKey =
      '0LXJrCmyBRD1KDXf3R4SaSdJgbIQLr5tSzS0Kj9CW6XQZ0yS';
  static const Duration _cacheDuration = Duration(days: 30);

  /// Get cache key for coordinates
  String _getCacheKey(double lat, double lon) {
    // Round to 2 decimal places to avoid too many cache entries
    return 'qibla_${lat.toStringAsFixed(2)}_${lon.toStringAsFixed(2)}';
  }

  /// Fetch Qibla direction by coordinates
  Future<QiblaResponse> fetchQiblaDirection({
    required double latitude,
    required double longitude,
  }) async {
    final cacheKey = _getCacheKey(latitude, longitude);

    // Try cache first
    final cached = await _loadFromCache(cacheKey);
    if (cached != null) {
      debugPrint('[QiblaApiService] Using cached qibla: ${cached.direction}°');
      return cached;
    }

    // IslamicAPI prayer-time endpoint includes qibla
    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'api_key': _apiKey,
      },
    );

    final requestUrl = uri.toString();
    debugPrint('[QiblaApiService] Fetching qibla from: $requestUrl');

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['code'] == 200 && json['status'] == 'success') {
          final qiblaResponse = QiblaResponse.fromIslamicApi(
            json,
            requestUrl: requestUrl,
          );

          // Cache the result
          await _saveToCache(cacheKey, qiblaResponse.direction);

          debugPrint(
            '[QiblaApiService] Qibla fetched: ${qiblaResponse.direction}°',
          );
          return qiblaResponse;
        } else {
          throw Exception('API error: ${json['message']}');
        }
      } else {
        throw Exception('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[QiblaApiService] Error: $e');

      // Try to return any cached value as fallback
      final fallback = await _loadAnyCache();
      if (fallback != null) {
        debugPrint('[QiblaApiService] Using fallback cache');
        return fallback;
      }

      rethrow;
    }
  }

  /// Load from cache
  Future<QiblaResponse?> _loadFromCache(String cacheKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final direction = prefs.getDouble(cacheKey);
      final timestamp = prefs.getInt('${cacheKey}_ts');

      if (direction != null && timestamp != null) {
        final cachedAt = DateTime.fromMillisecondsSinceEpoch(timestamp);
        if (DateTime.now().difference(cachedAt) < _cacheDuration) {
          return QiblaResponse.fromCache(direction);
        }
      }
    } catch (e) {
      debugPrint('[QiblaApiService] Cache load error: $e');
    }
    return null;
  }

  /// Load any cached qibla as fallback
  Future<QiblaResponse?> _loadAnyCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final direction = prefs.getDouble('cached_qibla_direction');
      if (direction != null) {
        return QiblaResponse.fromCache(direction);
      }
    } catch (e) {
      debugPrint('[QiblaApiService] Fallback cache error: $e');
    }
    return null;
  }

  /// Save to cache
  Future<void> _saveToCache(String cacheKey, double direction) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(cacheKey, direction);
      await prefs.setInt(
        '${cacheKey}_ts',
        DateTime.now().millisecondsSinceEpoch,
      );

      // Also save as global fallback
      await prefs.setDouble('cached_qibla_direction', direction);
    } catch (e) {
      debugPrint('[QiblaApiService] Cache save error: $e');
    }
  }
}

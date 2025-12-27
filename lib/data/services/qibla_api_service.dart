import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Response model for Qibla API
class QiblaResponse {
  final double direction;
  final double latitude;
  final double longitude;
  final bool isFromCache;
  final String requestUrl;
  final double? distanceKm;
  final String? compassBearing;

  QiblaResponse({
    required this.direction,
    required this.latitude,
    required this.longitude,
    this.isFromCache = false,
    this.requestUrl = '',
    this.distanceKm,
    this.compassBearing,
  });

  /// Parse from UmmahAPI response format
  factory QiblaResponse.fromUmmahApi(
    Map<String, dynamic> json, {
    bool isFromCache = false,
    String requestUrl = '',
    required double lat,
    required double lon,
  }) {
    final data = json['data'] ?? {};
    return QiblaResponse(
      direction: (data['qibla_direction'] ?? 0.0).toDouble(),
      latitude: lat,
      longitude: lon,
      isFromCache: isFromCache,
      requestUrl: requestUrl,
      distanceKm: (data['distance_km'] ?? 0.0).toDouble(),
      compassBearing: data['compass_bearing'] as String?,
    );
  }
}

/// Service to fetch Qibla direction from UmmahAPI
/// https://www.ummahapi.com/
class QiblaApiService {
  static const String _baseUrl = 'https://www.ummahapi.com/api/qibla';
  static const String _cacheKeyPrefix = 'qibla_cache_';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Round lat/lon to 2 decimals for cache key (~1.1km precision)
  String _getCacheKey(double lat, double lon) {
    return '${_cacheKeyPrefix}${lat.toStringAsFixed(2)}_${lon.toStringAsFixed(2)}';
  }

  /// Fetch Qibla direction by coordinates (uses UmmahAPI)
  Future<QiblaResponse> fetchQiblaDirection({
    required double latitude,
    required double longitude,
  }) async {
    // UmmahAPI format: /api/qibla?lat={lat}&lng={lng}
    final requestUrl = '$_baseUrl?lat=$latitude&lng=$longitude';

    try {
      final response = await http
          .get(Uri.parse(requestUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          final qiblaResponse = QiblaResponse.fromUmmahApi(
            json,
            requestUrl: requestUrl,
            lat: latitude,
            lon: longitude,
          );

          // Cache the result
          await _cacheResponse(latitude, longitude, qiblaResponse.direction);

          return qiblaResponse;
        } else {
          throw Exception('API error: ${json['message'] ?? 'Unknown error'}');
        }
      } else {
        throw Exception('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      // Try to load from cache
      final cached = await _loadCachedDirection(latitude, longitude);
      if (cached != null) {
        return QiblaResponse(
          direction: cached,
          latitude: latitude,
          longitude: longitude,
          isFromCache: true,
          requestUrl: requestUrl,
        );
      }
      rethrow;
    }
  }

  /// Cache the Qibla direction
  Future<void> _cacheResponse(double lat, double lon, double direction) async {
    final prefs = await _preferences;
    final key = _getCacheKey(lat, lon);
    await prefs.setDouble(key, direction);
  }

  /// Load cached direction
  Future<double?> _loadCachedDirection(double lat, double lon) async {
    final prefs = await _preferences;
    final key = _getCacheKey(lat, lon);
    return prefs.getDouble(key);
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Response model for AlAdhan Qibla API
class QiblaResponse {
  final double direction;
  final double latitude;
  final double longitude;
  final bool isFromCache;
  final String requestUrl;

  QiblaResponse({
    required this.direction,
    required this.latitude,
    required this.longitude,
    this.isFromCache = false,
    this.requestUrl = '',
  });

  factory QiblaResponse.fromJson(
    Map<String, dynamic> json, {
    bool isFromCache = false,
    String requestUrl = '',
    required double lat,
    required double lon,
  }) {
    final data = json['data'];
    return QiblaResponse(
      direction: (data['direction'] ?? 0.0).toDouble(),
      latitude: lat,
      longitude: lon,
      isFromCache: isFromCache,
      requestUrl: requestUrl,
    );
  }
}

/// Service to fetch Qibla direction from AlAdhan API
class QiblaApiService {
  static const String _baseUrl = 'https://api.aladhan.com/v1/qibla';
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

  /// Fetch Qibla direction by coordinates
  Future<QiblaResponse> fetchQiblaDirection({
    required double latitude,
    required double longitude,
  }) async {
    final requestUrl = '$_baseUrl/$latitude/$longitude';

    try {
      final response = await http
          .get(Uri.parse(requestUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['code'] == 200 && json['status'] == 'OK') {
          final qiblaResponse = QiblaResponse.fromJson(
            json,
            requestUrl: requestUrl,
            lat: latitude,
            lon: longitude,
          );

          // Cache the result
          await _cacheResponse(latitude, longitude, qiblaResponse.direction);

          return qiblaResponse;
        } else {
          throw Exception('API error: ${json['status']}');
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

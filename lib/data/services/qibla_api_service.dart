import 'package:flutter/foundation.dart';
import 'package:adhan/adhan.dart';
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

  /// Parse from IslamicAPI format (legacy support)
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

/// Service to compute Qibla direction OFFLINE natively
/// Uses package: adhan
class QiblaApiService {
  /// Calculate Qibla direction exclusively locally
  Future<QiblaResponse> fetchQiblaDirection({
    required double latitude,
    required double longitude,
  }) async {
    try {
      debugPrint('[QiblaApiService] Calculating Qibla Offline for: $latitude, $longitude');
      final coordinates = Coordinates(latitude, longitude);
      final qibla = Qibla(coordinates);
      
      // Cache it just for the legacy fallback structures to have it
      await _saveToCache(qibla.direction);
      
      return QiblaResponse(
        direction: qibla.direction,
        distanceKm: 0.0, // adhan package doesn't compute distance directly, but often unneeded
        compassBearing: 'Calculated Offline',
        isFromCache: false,
        requestUrl: 'offline://calculated',
      );
    } catch (e) {
      debugPrint('[QiblaApiService] Error calculating Qibla locally: $e');
      
      // Fallback
      final fallback = await _loadAnyCache();
      if (fallback != null) {
        return fallback;
      }
      
      rethrow;
    }
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

  /// Save to cache exclusively for global legacy fallback mapping
  Future<void> _saveToCache(double direction) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('cached_qibla_direction', direction);
    } catch (e) {
      debugPrint('[QiblaApiService] Cache save error: $e');
    }
  }
}

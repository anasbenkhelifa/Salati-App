import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/services/qibla_api_service.dart';

/// State for the Qibla data
enum QiblaDataState {
  loading,
  success,
  permissionDenied,
  locationDisabled,
  noCompass,
  error,
}

/// Provider to manage Qibla compass data
class QiblaProvider extends ChangeNotifier {
  final QiblaApiService _apiService = QiblaApiService();

  QiblaDataState _state = QiblaDataState.loading;
  double? _qiblaBearing; // Fixed bearing from API (0-360)
  double _rawHeading = 0; // Raw device heading (0-360)
  double _smoothedHeading = 0; // Smoothed heading for display (0-360)
  double? _latitude;
  double? _longitude;
  String? _errorMessage;
  bool _isFromCache = false;
  String _requestUrl = '';
  bool _hasCompass = false;
  bool _isAligned = false;

  StreamSubscription<CompassEvent>? _compassSubscription;
  DateTime _lastUpdateTime = DateTime.now();

  // Smoothing settings
  static const double _smoothingAlpha = 0.22;
  static const int _minUpdateIntervalMs = 55; // ~18 FPS
  static const double _minChangeDegrees = 0.5;

  // Alignment thresholds with hysteresis
  static const double _alignOnThreshold = 2.0;
  static const double _alignOffThreshold = 4.0;

  // Getters
  QiblaDataState get state => _state;
  double? get qiblaBearing => _qiblaBearing;
  double get rawHeading => _rawHeading;
  double get smoothedHeading => _smoothedHeading;
  double? get latitude => _latitude;
  double? get longitude => _longitude;
  String? get errorMessage => _errorMessage;
  bool get isFromCache => _isFromCache;
  String get requestUrl => _requestUrl;
  bool get hasCompass => _hasCompass;
  bool get isAligned => _isAligned;

  /// Get the heading as integer degrees (0-360) for center display
  /// This is the REAL compass heading, NOT offset by Qibla
  int get headingDegrees => _smoothedHeading.round() % 360;

  /// Get the rotation for the compass dial (in radians)
  /// Dial rotates opposite to heading so north indicator stays at top when facing north
  double get dialRotationRadians => -_smoothedHeading * (math.pi / 180);

  /// Normalize angle to [0, 360)
  double _normalizeAngle360(double angle) {
    while (angle < 0) {
      angle += 360;
    }
    while (angle >= 360) {
      angle -= 360;
    }
    return angle;
  }

  /// Calculate shortest angular difference (handles wrap-around)
  /// Returns value in range [-180, +180]
  double _shortestAngleDiff(double from, double to) {
    double diff = to - from;
    while (diff > 180) {
      diff -= 360;
    }
    while (diff < -180) {
      diff += 360;
    }
    return diff;
  }

  /// Initialize Qibla provider
  Future<void> initialize() async {
    _state = QiblaDataState.loading;
    notifyListeners();

    _hasCompass = FlutterCompass.events != null;
    await _acquireLocationAndFetch();

    if (_hasCompass) {
      _startCompassListening();
    }
  }

  /// Acquire GPS location and fetch Qibla bearing
  Future<void> _acquireLocationAndFetch() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      final cached = await _loadCachedPosition();
      if (cached != null) {
        _latitude = cached.lat;
        _longitude = cached.lon;
        await _fetchQiblaBearing();
      } else {
        _state = QiblaDataState.locationDisabled;
        _errorMessage = 'Location services are disabled';
        notifyListeners();
      }
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        final cached = await _loadCachedPosition();
        if (cached != null) {
          _latitude = cached.lat;
          _longitude = cached.lon;
          await _fetchQiblaBearing();
        } else {
          _state = QiblaDataState.permissionDenied;
          _errorMessage = 'Location permission denied';
          notifyListeners();
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      final cached = await _loadCachedPosition();
      if (cached != null) {
        _latitude = cached.lat;
        _longitude = cached.lon;
        await _fetchQiblaBearing();
      } else {
        _state = QiblaDataState.permissionDenied;
        _errorMessage = 'Location permission permanently denied';
        notifyListeners();
      }
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      _latitude = position.latitude;
      _longitude = position.longitude;
      await _saveCachedPosition(_latitude!, _longitude!);
      await _fetchQiblaBearing();
    } catch (e) {
      final cached = await _loadCachedPosition();
      if (cached != null) {
        _latitude = cached.lat;
        _longitude = cached.lon;
        await _fetchQiblaBearing();
      } else {
        _state = QiblaDataState.error;
        _errorMessage = 'Could not get location: $e';
        notifyListeners();
      }
    }
  }

  /// Fetch Qibla bearing from API
  Future<void> _fetchQiblaBearing() async {
    if (_latitude == null || _longitude == null) {
      _state = QiblaDataState.error;
      _errorMessage = 'No location available';
      notifyListeners();
      return;
    }

    try {
      final response = await _apiService.fetchQiblaDirection(
        latitude: _latitude!,
        longitude: _longitude!,
      );

      _qiblaBearing = response.direction; // Fixed bearing from API (0-360)
      _isFromCache = response.isFromCache;
      _requestUrl = response.requestUrl;
      _state = _hasCompass ? QiblaDataState.success : QiblaDataState.noCompass;
      _errorMessage = null;
    } catch (e) {
      _state = QiblaDataState.error;
      _errorMessage = 'Could not get Qibla direction: $e';
    }

    notifyListeners();
  }

  /// Start listening to compass events
  void _startCompassListening() {
    _compassSubscription?.cancel();
    _compassSubscription = FlutterCompass.events?.listen((event) {
      if (event.heading == null || _qiblaBearing == null) return;

      final now = DateTime.now();
      final elapsed = now.difference(_lastUpdateTime).inMilliseconds;
      if (elapsed < _minUpdateIntervalMs) return;

      final newHeading = event.heading!;
      _rawHeading = newHeading;

      // Apply EMA smoothing to heading with wrap-around handling
      double diff = _shortestAngleDiff(_smoothedHeading, newHeading);
      if (diff.abs() < _minChangeDegrees) return;

      _smoothedHeading = _normalizeAngle360(
        _smoothedHeading + _smoothingAlpha * diff,
      );

      // Alignment check: is current heading aligned with Qibla bearing?
      // diff = how far heading is from qiblaBearing
      final alignmentError = _shortestAngleDiff(
        _smoothedHeading,
        _qiblaBearing!,
      );
      final absError = alignmentError.abs();

      // Hysteresis for alignment state
      if (_isAligned) {
        if (absError >= _alignOffThreshold) {
          _isAligned = false;
        }
      } else {
        if (absError <= _alignOnThreshold) {
          _isAligned = true;
        }
      }

      _lastUpdateTime = now;
      notifyListeners();
    });
  }

  Future<({double lat, double lon})?> _loadCachedPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('qibla_last_lat');
    final lon = prefs.getDouble('qibla_last_lon');
    if (lat != null && lon != null) {
      return (lat: lat, lon: lon);
    }
    return null;
  }

  Future<void> _saveCachedPosition(double lat, double lon) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('qibla_last_lat', lat);
    await prefs.setDouble('qibla_last_lon', lon);
  }

  Future<void> refresh() async {
    _state = QiblaDataState.loading;
    notifyListeners();
    await _acquireLocationAndFetch();
  }

  Future<void> requestPermission() async {
    await Geolocator.requestPermission();
    await refresh();
  }

  Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }

  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  @override
  void dispose() {
    _compassSubscription?.cancel();
    super.dispose();
  }
}

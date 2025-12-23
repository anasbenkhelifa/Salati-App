import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_compass/flutter_compass.dart';
import '../../data/services/prayer_times_cache_service.dart';
import '../../data/services/qibla_api_service.dart';

/// State for the Qibla data
enum QiblaDataState {
  loading,
  success,
  noLocationCached, // User needs to set up location via Prayer Times
  noQiblaCached, // Location exists but no qibla cached (and offline)
  noCompass,
  error,
}

/// Provider to manage Qibla compass data - OFFLINE-FIRST
/// Does NOT request GPS. Uses cached location from Prayer Times.
class QiblaProvider extends ChangeNotifier {
  final QiblaApiService _apiService = QiblaApiService();
  final PrayerTimesCacheService _cacheService = PrayerTimesCacheService();

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
  bool _isUpdating = false; // Non-blocking update indicator

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
  bool get isUpdating => _isUpdating;

  /// Get the heading as integer degrees (0-360) for center display
  int get headingDegrees => _smoothedHeading.round() % 360;

  /// Get the rotation for the compass dial (in radians)
  double get dialRotationRadians => -_smoothedHeading * (math.pi / 180);

  /// Normalize angle to [0, 360)
  double _normalizeAngle360(double angle) {
    while (angle < 0) angle += 360;
    while (angle >= 360) angle -= 360;
    return angle;
  }

  /// Calculate shortest angular difference (handles wrap-around)
  double _shortestAngleDiff(double from, double to) {
    double diff = to - from;
    while (diff > 180) diff -= 360;
    while (diff < -180) diff += 360;
    return diff;
  }

  /// Initialize Qibla provider - CACHE-FIRST, no GPS
  Future<void> initialize() async {
    _state = QiblaDataState.loading;
    notifyListeners();

    _hasCompass = FlutterCompass.events != null;

    // Load from cache first - NO GPS
    await _loadFromCache();

    if (_hasCompass && _qiblaBearing != null) {
      _startCompassListening();
    }
  }

  /// Load qibla from cache - uses cached location from Prayer Times
  Future<void> _loadFromCache() async {
    debugPrint('[QiblaProvider] Loading from cache...');

    // Check if location is cached (set by Prayer Times)
    final appState = await _cacheService.loadAppState();

    if (appState == null) {
      // No location cached - user needs to setup via Prayer Times
      _state = QiblaDataState.noLocationCached;
      _errorMessage = 'Open Prayer Times and update location first';
      debugPrint('[QiblaProvider] No cached location - needs setup');
      notifyListeners();
      return;
    }

    _latitude = appState.latitude;
    _longitude = appState.longitude;

    // Check if qibla direction is cached
    final cachedQibla = await _cacheService.loadQiblaDirection();

    if (cachedQibla != null) {
      // Use cached qibla instantly
      _qiblaBearing = cachedQibla;
      _isFromCache = true;
      _state = _hasCompass ? QiblaDataState.success : QiblaDataState.noCompass;
      debugPrint('[QiblaProvider] Using cached qibla: $cachedQibla');
      notifyListeners();
      return;
    }

    // No cached qibla - try to fetch (non-blocking)
    await _fetchQiblaInBackground();
  }

  /// Fetch qibla direction from API (non-blocking)
  Future<void> _fetchQiblaInBackground() async {
    if (_latitude == null || _longitude == null) {
      _state = QiblaDataState.noLocationCached;
      notifyListeners();
      return;
    }

    _isUpdating = true;
    notifyListeners();

    try {
      final response = await _apiService.fetchQiblaDirection(
        latitude: _latitude!,
        longitude: _longitude!,
      );

      _qiblaBearing = response.direction;
      _isFromCache = false;
      _requestUrl = response.requestUrl;

      // Save to cache
      await _cacheService.saveQiblaDirection(response.direction);

      _state = _hasCompass ? QiblaDataState.success : QiblaDataState.noCompass;
      _errorMessage = null;

      if (_hasCompass) {
        _startCompassListening();
      }

      debugPrint(
        '[QiblaProvider] Fetched and cached qibla: ${response.direction}',
      );
    } catch (e) {
      debugPrint('[QiblaProvider] Failed to fetch qibla: $e');
      // Offline - show appropriate state
      if (_qiblaBearing == null) {
        _state = QiblaDataState.noQiblaCached;
        _errorMessage = 'Update location in Prayer Times when online';
      }
      // If we already have a cached qibla, keep it and don't change state
    }

    _isUpdating = false;
    notifyListeners();
  }

  /// Refresh qibla when location is updated (called by Prayer Times provider)
  Future<void> refreshFromNewLocation(double latitude, double longitude) async {
    debugPrint(
      '[QiblaProvider] Refreshing from new location: $latitude, $longitude',
    );
    _latitude = latitude;
    _longitude = longitude;
    _isFromCache = false;
    await _fetchQiblaInBackground();
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

      // Alignment check
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

  /// Soft refresh from cache (on resume) - no GPS, no network
  Future<void> softRefresh() async {
    debugPrint('[QiblaProvider] Soft refresh from cache');
    final cachedQibla = await _cacheService.loadQiblaDirection();
    if (cachedQibla != null && cachedQibla != _qiblaBearing) {
      _qiblaBearing = cachedQibla;
      _isFromCache = true;
      if (_state != QiblaDataState.success && _hasCompass) {
        _state = QiblaDataState.success;
        _startCompassListening();
      }
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _compassSubscription?.cancel();
    super.dispose();
  }
}

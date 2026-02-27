import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  // Static instance for cross-provider access
  static QiblaProvider? _instance;
  static QiblaProvider? get instance => _instance;

  QiblaProvider() {
    _instance = this;
  }

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

  // Haptic tick settings
  bool _compassHapticsEnabled = true;
  int? _lastTickDegree;
  int _lastTickMs = 0;
  static const int _tickThrottleMs = 100; // Max 10 ticks/second

  // Page visibility - haptics only fire when Qibla is active
  bool _isQiblaActive = false;
  bool get isQiblaActive => _isQiblaActive;

  // App lifecycle state - stop compass when app is backgrounded
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;
  AppLifecycleState get appLifecycleState => _appLifecycleState;

  bool get compassHapticsEnabled => _compassHapticsEnabled;

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

  /// Load compass haptics setting from SharedPreferences
  Future<void> _loadHapticsSetting() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _compassHapticsEnabled = prefs.getBool('compass_haptics_enabled') ?? true;
    } catch (e) {
      debugPrint('[QiblaProvider] Error loading haptics setting: $e');
    }
  }

  /// Set compass haptics enabled/disabled and save
  Future<void> setCompassHaptics(bool enabled) async {
    if (_compassHapticsEnabled == enabled) return;
    _compassHapticsEnabled = enabled;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('compass_haptics_enabled', enabled);
    } catch (e) {
      debugPrint('[QiblaProvider] Error saving haptics setting: $e');
    }
  }

  /// Initialize Qibla provider - CACHE-FIRST, no GPS
  Future<void> initialize() async {
    _state = QiblaDataState.loading;
    notifyListeners();

    // Load haptics setting
    await _loadHapticsSetting();

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
  /// Now accepts qiblaDirection directly to avoid re-fetching from cache
  void refreshFromNewLocation(
    double latitude,
    double longitude,
    double qiblaDirection,
  ) {
    debugPrint(
      '[QiblaProvider] Refreshing from new location: $latitude, $longitude, qibla=$qiblaDirection',
    );
    _latitude = latitude;
    _longitude = longitude;
    _qiblaBearing = qiblaDirection;
    _isFromCache = false;
    _state = _hasCompass ? QiblaDataState.success : QiblaDataState.noCompass;
    _errorMessage = null;

    // Start compass if not already running
    if (_hasCompass && _compassSubscription == null) {
      _startCompassListening();
    }

    notifyListeners();
  }

  /// Start listening to compass events
  void _startCompassListening() {
    if (_compassSubscription != null) {
      debugPrint('[QiblaProvider] Compass already listening, skipping');
      return;
    }
    debugPrint('[QiblaProvider] startCompass');
    _compassSubscription = FlutterCompass.events?.listen((event) {
      if (event.heading == null || _qiblaBearing == null) return;
      if (!_isQiblaActive)
        return; // Guard: only update when Qibla page is active

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

      // Haptic tick ONLY when: app resumed AND Qibla is active AND haptics enabled
      final canTriggerHaptics =
          _appLifecycleState == AppLifecycleState.resumed &&
          _isQiblaActive &&
          _compassHapticsEnabled &&
          _lastTickDegree != null;

      if (canTriggerHaptics) {
        final currentDegree = _smoothedHeading.round() % 360;
        if (currentDegree != _lastTickDegree) {
          final nowMs = now.millisecondsSinceEpoch;
          if (nowMs - _lastTickMs >= _tickThrottleMs) {
            debugPrint('[QiblaProvider] HAPTIC TRIGGERED');
            HapticFeedback.selectionClick();
            _lastTickMs = nowMs;
          }
        }
        _lastTickDegree = currentDegree;
      } else {
        _lastTickDegree = _smoothedHeading.round() % 360;
      }

      notifyListeners();
    });
  }

  /// Stop listening to compass events
  void _stopCompassListening() {
    if (_compassSubscription != null) {
      debugPrint('[QiblaProvider] stopCompass');
      _compassSubscription?.cancel();
      _compassSubscription = null;
      // Reset haptic state to prevent burst on resume
      _lastTickDegree = null;
      _lastTickMs = 0;
    }
  }

  /// Set Qibla page active/inactive - controls compass and haptics
  void setActive(bool active) {
    if (_isQiblaActive == active) return;
    _isQiblaActive = active;
    debugPrint('[QiblaProvider] setActive($active), currentState=$_state');

    if (active) {
      // If we're in an error state, try to reinitialize
      // This handles the case where location cache wasn't ready on first load
      if (_state == QiblaDataState.noLocationCached ||
          _state == QiblaDataState.error ||
          _state == QiblaDataState.loading) {
        debugPrint('[QiblaProvider] Reinitializing due to state: $_state');
        initialize();
      } else if (_hasCompass && _qiblaBearing != null) {
        // Resuming - start compass if we have bearing
        _startCompassListening();
      }
    } else {
      // Leaving - stop compass immediately
      _stopCompassListening();
    }
  }

  /// Handle app lifecycle changes - stop compass when app goes to background
  void onAppLifecycleChanged(AppLifecycleState state) {
    final prevState = _appLifecycleState;
    _appLifecycleState = state;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      // App going to background - stop compass immediately
      debugPrint('[QiblaProvider] LIFE: $state -> stopCompass');
      _stopCompassListening();
    } else if (state == AppLifecycleState.resumed &&
        prevState != AppLifecycleState.resumed) {
      // App returning to foreground - only restart if Qibla is active
      debugPrint('[QiblaProvider] LIFE: resumed (qiblaActive=$_isQiblaActive)');
      if (_isQiblaActive && _hasCompass && _qiblaBearing != null) {
        _startCompassListening();
      }
    }
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

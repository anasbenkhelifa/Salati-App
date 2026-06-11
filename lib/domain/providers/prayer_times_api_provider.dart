import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../../data/services/prayer_times_api_service.dart';
import '../../data/services/prayer_times_cache_service.dart';
import '../../data/services/bilingual_location_service.dart';
import '../../data/services/qibla_api_service.dart';
import '../../data/services/adhan_alarm_service.dart';
import '../../notification_manager.dart';
import '../../data/services/prayer_method_resolver.dart';
import '../../data/services/hijri_date_service.dart';
import 'qibla_provider.dart';

/// State for the prayer times data
enum PrayerDataState {
  loading,
  success,
  permissionDenied,
  locationDisabled,
  error,
  offline, // Using cached data, couldn't refresh
}

/// Provider to manage prayer times data from AlAdhan API using GPS
/// Implements OFFLINE-FIRST behavior: loads from cache first, only refreshes when needed
class PrayerTimesApiProvider extends ChangeNotifier with WidgetsBindingObserver {
  final PrayerTimesApiService _apiService = PrayerTimesApiService();
  final PrayerTimesCacheService _cacheService = PrayerTimesCacheService();
  final BilingualLocationService _locationService = BilingualLocationService();
  final QiblaApiService _qiblaApiService = QiblaApiService();

  PrayerDataState _state = PrayerDataState.loading;
  AlAdhanResponse? _response;
  String? _errorMessage;
  bool _isOfflineMode = false;

  // Settings
  CalculationMethodId _method = CalculationMethodId.mwl;
  bool _isManualMethod = false;
  MadhabId _madhab = MadhabId.shafi;

  // Location (from cache)
  double? _latitude;
  double? _longitude;
  double _elevation = 0; // GPS altitude in metres, for horizon-dip correction
  String _cityEn = '';
  String _cityAr = '';
  String _countryEn = '';
  String _countryAr = '';
  String _isoCountryCode = 'DZ';
  DateTime? _lastUpdatedAt;

  // Debug info
  String _requestUrl = '';
  String _deviceTimezone = '';
  bool _isFromCache = false;
  bool _cacheIsToday = false;
  String? _prayerTimesDate;
  Timer? _midnightTimer;

  // Guard against concurrent location refresh calls
  bool _isRefreshingLocation = false;

  // Singleton instance
  static final PrayerTimesApiProvider instance = PrayerTimesApiProvider._internal();

  PrayerTimesApiProvider._internal() {
    WidgetsBinding.instance.addObserver(this);
    _setupMidnightTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnightTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // If setup failed earlier (GPS off, permission denied, or the location
      // permission request collided with the notification dialog on first
      // run), retry now — the user may have just granted permission, and
      // dismissing any permission dialog triggers a resume.
      if (!_setupInProgress &&
          (_state == PrayerDataState.locationDisabled ||
              _state == PrayerDataState.permissionDenied ||
              (_state == PrayerDataState.error && _response == null))) {
        debugPrint('[PrayerTimesApiProvider] App resumed — retrying setup...');
        _firstTimeSetup();
        return;
      }
      _checkMidnightAndRefresh();
    }
  }

  void _checkMidnightAndRefresh() { // Dual-architecture refresh
    if (_prayerTimesDate == null || _latitude == null || _longitude == null) return;
    
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (_prayerTimesDate != today) {
      debugPrint('[PrayerTimesApiProvider] Midnight passed! Auto-refreshing prayer times...');
      _setupMidnightTimer(); // Re-schedule next midnight precisely
      _refreshPrayerTimesOnly(_latitude!, _longitude!, today);
    }
  }

  void _setupMidnightTimer() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    // Schedule exactly 1 second after midnight tomorrow
    final tomorrow = DateTime(now.year, now.month, now.day + 1, 0, 0, 1);
    final durationToMidnight = tomorrow.difference(now);
    
    _midnightTimer = Timer(durationToMidnight, () {
      debugPrint('[PrayerTimesApiProvider] Midnight Timer fired!');
      _checkMidnightAndRefresh();
    });
  }

  // Getters
  PrayerDataState get state => _state;
  AlAdhanResponse? get response => _response;
  String? get errorMessage => _errorMessage;
  CalculationMethodId get method => _method;
  bool get isManualMethod => _isManualMethod;
  MadhabId get madhab => _madhab;
  double? get latitude => _latitude;
  double? get longitude => _longitude;
  String get requestUrl => _requestUrl;
  String get deviceTimezone => _deviceTimezone;
  bool get isFromCache => _isFromCache;
  bool get isOfflineMode => _isOfflineMode;
  DateTime? get lastUpdatedAt => _lastUpdatedAt;

  /// Get location name for Prayer Times screen (full: Country • City)
  String getLocationName(bool isArabic) {
    if (isArabic) {
      if (_countryAr.isNotEmpty && _cityAr.isNotEmpty) {
        return '$_countryAr • $_cityAr';
      }
      return _cityAr.isNotEmpty ? _cityAr : 'الموقع الحالي';
    } else {
      if (_countryEn.isNotEmpty && _cityEn.isNotEmpty) {
        return '$_countryEn • $_cityEn';
      }
      return _cityEn.isNotEmpty ? _cityEn : 'Current Location';
    }
  }

  /// Get city-only name for notification
  String getCityOnly(bool isArabic) {
    if (isArabic) {
      return _cityAr.isNotEmpty ? _cityAr : _countryAr;
    } else {
      return _cityEn.isNotEmpty ? _cityEn : _countryEn;
    }
  }

  /// Get "last updated" display string
  String get lastUpdatedDisplay {
    if (_lastUpdatedAt == null) return '';
    final format = DateFormat('MMM d, HH:mm');
    return format.format(_lastUpdatedAt!);
  }

  // Legacy getters for backwards compatibility
  String get locationNameEn => getLocationName(false);
  String get locationNameAr => getLocationName(true);

  /// Get next prayer index (0=fajr, 1=dhuhr, 2=asr, 3=maghrib, 4=isha)
  int get nextPrayerIndex {
    if (_response == null) return 0;

    final now = DateTime.now();
    final times = _parsedTimes;

    for (int i = 0; i < times.length; i++) {
      if (times[i].isAfter(now)) {
        return i;
      }
    }

    return 0; // All prayers passed, next is tomorrow's Fajr
  }

  /// Get all prayer times as DateTime (parsed from HH:mm strings)
  List<DateTime> get _parsedTimes {
    if (_response == null) return [];

    final today = DateTime.now();
    final timings = _response!.timings;

    return [
      _parseTime(timings.fajr, today),
      _parseTime(timings.dhuhr, today),
      _parseTime(timings.asr, today),
      _parseTime(timings.maghrib, today),
      _parseTime(timings.isha, today),
    ];
  }

  /// Parse HH:mm string to DateTime for today
  DateTime _parseTime(String timeStr, DateTime date) {
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1].split(' ')[0]);
        return DateTime(date.year, date.month, date.day, hour, minute);
      }
    } catch (e) {
      // Fallback to midnight
    }
    return DateTime(date.year, date.month, date.day);
  }

  /// Get countdown to next prayer
  Duration getCountdown() {
    if (_response == null) return Duration.zero;

    final now = DateTime.now();
    final times = _parsedTimes;

    for (final time in times) {
      if (time.isAfter(now)) {
        return time.difference(now);
      }
    }

    // All prayers passed, calculate to tomorrow's estimated Fajr
    if (times.isNotEmpty) {
      final tomorrowFajr = times[0].add(const Duration(days: 1));
      return tomorrowFajr.difference(now);
    }

    return Duration.zero;
  }

  /// Initialize - CACHE FIRST, instant rendering, background refresh
  /// Phase A: Load from cache immediately and notify
  /// Phase B: Background refresh (unawaited) if needed
  bool _initialized = false;

  Future<void> initialize() async {
    debugPrint('[PrayerTimesApiProvider] initialize() called');

    // Guard against multiple initializations
    if (_initialized) {
      debugPrint('[PrayerTimesApiProvider] Already initialized, skipping');
      return;
    }
    _initialized = true;

    _deviceTimezone = DateTime.now().timeZoneName;

    // Load settings synchronously-ish
    _method = await _cacheService.loadMethod();
    _isManualMethod = await _cacheService.loadIsManualMethod();
    _madhab = await _cacheService.loadMadhab();

    // Check if setup was already done
    final setupDone = await _cacheService.isSetupDone();
    debugPrint('[PrayerTimesApiProvider] setupDone=$setupDone');

    if (setupDone) {
      // PHASE A: Load cache immediately and notify UI
      await _loadFromCacheInstant();
      // PHASE B: Refresh in background if needed (unawaited)
      _refreshIfNeeded();
    } else {
      // FIRST RUN: Need GPS + network. Never awaited here — main() awaits
      // initialize(), and blocking would hold runApp() hostage behind the
      // permission dialog (black screen). The setup itself is triggered by
      // NotificationManager via ensureFirstTimeSetup() AFTER the
      // notification-permission flow settles, so the two permission dialogs
      // never collide. The timer is a safety net in case that path fails.
      debugPrint(
        '[PrayerTimesApiProvider] FIRST RUN - waiting for permission flow...',
      );
      _state = PrayerDataState.loading;
      notifyListeners();
      Timer(const Duration(seconds: 10), () {
        if (_state == PrayerDataState.loading && _response == null) {
          debugPrint(
            '[PrayerTimesApiProvider] Fallback: starting first-time setup',
          );
          unawaited(_firstTimeSetup());
        }
      });
    }
  }

  /// Run first-time setup if it hasn't completed yet. Called by
  /// NotificationManager once the notification permission flow settles,
  /// sequencing the permission dialogs (notification → location).
  Future<void> ensureFirstTimeSetup() async {
    final setupDone = await _cacheService.isSetupDone();
    if (setupDone) return;
    await _firstTimeSetup();
  }

  /// Phase A: Load from cache immediately and notify UI - NO network calls
  Future<void> _loadFromCacheInstant() async {
    debugPrint('[PrayerTimesApiProvider] Loading from cache (instant)...');

    final cached = await _cacheService.loadAppState();
    if (cached == null) {
      // Cache corrupted, need first-time setup
      _state = PrayerDataState.loading;
      notifyListeners();
      await _firstTimeSetup();
      return;
    }

    // Set cached values IMMEDIATELY
    _latitude = cached.latitude;
    _longitude = cached.longitude;
    _elevation = cached.elevation;
    _cityEn = cached.cityEn;
    _cityAr = cached.cityAr;
    _countryEn = cached.countryEn;
    _countryAr = cached.countryAr;
    _method = cached.method;
    _isManualMethod = cached.isManualMethod;
    _madhab = cached.madhab;
    _lastUpdatedAt = cached.updatedAt;
    _response = cached.prayerTimes;
    _isFromCache = true;
    _cacheIsToday = cached.isToday;
    _prayerTimesDate = cached.prayerTimesDate;
    _state = PrayerDataState.success;

    // NOTIFY UI IMMEDIATELY - Home can now render with cached data
    notifyListeners();
    debugPrint('[PrayerTimesApiProvider] UI notified with cached data');

    // Schedule Adhan alarms from cached prayer times
    AdhanAlarmService.scheduleAllAlarms();
  }

  /// Force reload from cache - skips initialization guard
  /// Used by HomeScreen when it needs to retry loading after Prayer Times tab populated cache
  Future<void> reloadFromCache() async {
    debugPrint('[PrayerTimesApiProvider] reloadFromCache called');
    final setupDone = await _cacheService.isSetupDone();
    if (setupDone) {
      await _loadFromCacheInstant();
    }
  }

  /// Phase B: Background refresh - always recalculate to ensure params are fresh
  /// (e.g. Isha interval changes depending on Ramadan)
  void _refreshIfNeeded() {
    if (_response == null || _latitude == null || _longitude == null) return;

    // Always recalculate in background to pick up any parameter changes
    debugPrint(
      '[PrayerTimesApiProvider] Refreshing prayer times in background...',
    );
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _refreshPrayerTimesOnly(_latitude!, _longitude!, today);
  }

  /// Number of days to pre-calculate ahead so alarms stay exact while the
  /// phone is fully offline and the app isn't opened
  static const int _daysToCacheAhead = 30;

  /// Pre-calculate prayer times for the next [_daysToCacheAhead] days and
  /// store them date-keyed for the native side (alarms, foreground service,
  /// widget). Pure offline math - no network involved.
  ///
  /// Must complete BEFORE alarms are (re)scheduled so the native scheduler
  /// reads fresh data.
  Future<void> _cacheMultiDayPrayerTimes(double lat, double lng) async {
    try {
      final byDate = <String, Map<String, String>>{};
      final dateFormat = DateFormat('yyyy-MM-dd');
      final start = DateTime.now();

      for (int i = 0; i < _daysToCacheAhead; i++) {
        final date = DateTime(start.year, start.month, start.day + i);
        final response = await _apiService.fetchPrayerTimesByCoordinates(
          latitude: lat,
          longitude: lng,
          method: _method,
          madhab: _madhab,
          date: date,
          elevation: _elevation,
        );
        byDate[dateFormat.format(date)] = {
          'Fajr': response.timings.fajr,
          'Sunrise': response.timings.sunrise,
          'Dhuhr': response.timings.dhuhr,
          'Asr': response.timings.asr,
          'Maghrib': response.timings.maghrib,
          'Isha': response.timings.isha,
        };
      }

      await _cacheService.savePrayerTimesByDate(byDate);

      // Keep the Hijri per-date cache in sync with the same offline window,
      // even when the live notification (its other refresher) is disabled
      await HijriDateService().cacheUpcomingDays();
    } catch (e) {
      debugPrint('[PrayerTimesApiProvider] Multi-day cache failed: $e');
    }
  }

  /// Refresh only prayer times using cached location (no GPS)
  Future<void> _refreshPrayerTimesOnly(
    double lat,
    double lng,
    String dateStr,
  ) async {
    debugPrint(
      '[PrayerTimesApiProvider] Refreshing prayer times for $dateStr...',
    );

    try {
      final response = await _apiService.fetchPrayerTimesByCoordinates(
        latitude: lat,
        longitude: lng,
        method: _method,
        madhab: _madhab,
        date: DateTime.now(),
        elevation: _elevation,
      );

      _response = response;
      _requestUrl = response.requestUrl;
      _isFromCache = false;
      _isOfflineMode = false;
      _prayerTimesDate = dateStr;
      _state = PrayerDataState.success;

      // Update cache with new prayer times
      await _cacheService.updatePrayerTimes(
        prayerTimes: response,
        prayerTimesDate: dateStr,
      );

      // Refresh the 30-day offline cache BEFORE rescheduling so the native
      // scheduler picks up exact per-date times
      await _cacheMultiDayPrayerTimes(lat, lng);

      // Reschedule alarms so they match the freshly calculated times
      AdhanAlarmService.scheduleAllAlarms();

      debugPrint('[PrayerTimesApiProvider] Prayer times refreshed');
    } catch (e) {
      debugPrint('[PrayerTimesApiProvider] Offline, using cached times: $e');
      _isOfflineMode = true;
      // Keep existing _response from cache
      if (_response != null) {
        _state = PrayerDataState.offline;
      } else {
        _state = PrayerDataState.error;
        _errorMessage = 'No internet connection';
      }
    }

    notifyListeners();
  }

  /// Re-entry guard: dialogs trigger app resumes which trigger retries —
  /// without this, a retry could start a second setup mid-flight.
  bool _setupInProgress = false;

  /// First time setup - requires GPS and network
  Future<void> _firstTimeSetup() async {
    if (_setupInProgress) {
      debugPrint('[PrayerTimesApiProvider] Setup already in progress');
      return;
    }
    _setupInProgress = true;
    try {
      await _firstTimeSetupInner();
    } catch (e) {
      // A permission request that collides with another plugin's dialog can
      // throw (or time out). Land in permissionDenied so the resume-retry
      // and the error-state UI both offer a way forward — never stay stuck
      // in loading.
      debugPrint('[PrayerTimesApiProvider] Setup permission phase failed: $e');
      _state = PrayerDataState.permissionDenied;
      _errorMessage = 'Location permission request failed';
      notifyListeners();
    } finally {
      _setupInProgress = false;
    }
  }

  Future<void> _firstTimeSetupInner() async {
    debugPrint('[PrayerTimesApiProvider] First time setup...');

    // Check location services
    debugPrint('[PrayerTimesApiProvider] Checking location services...');
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    debugPrint(
      '[PrayerTimesApiProvider] Location services enabled: $serviceEnabled',
    );
    if (!serviceEnabled) {
      _state = PrayerDataState.locationDisabled;
      _errorMessage = 'Location services are disabled';
      notifyListeners();
      return;
    }

    // Check permission
    debugPrint('[PrayerTimesApiProvider] Checking location permission...');
    var permission = await Geolocator.checkPermission();
    debugPrint('[PrayerTimesApiProvider] Current permission: $permission');
    if (permission == LocationPermission.denied) {
      debugPrint('[PrayerTimesApiProvider] Requesting permission...');
      // Timeout: a request colliding with another permission dialog can
      // hang forever; recover instead of freezing first-run
      permission = await Geolocator.requestPermission()
          .timeout(const Duration(seconds: 60));
      debugPrint(
        '[PrayerTimesApiProvider] Permission after request: $permission',
      );
      if (permission == LocationPermission.denied) {
        _state = PrayerDataState.permissionDenied;
        _errorMessage = 'Location permission denied';
        notifyListeners();
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _state = PrayerDataState.permissionDenied;
      _errorMessage = 'Location permission permanently denied';
      notifyListeners();
      return;
    }

    // Get GPS location - OPTIMIZED: try last known first, then fresh
    try {
      debugPrint('[PrayerTimesApiProvider] Getting location...');

      Position? position;

      // Try last known position first for instant result
      try {
        position = await Geolocator.getLastKnownPosition();
        if (position != null) {
          debugPrint(
            '[PrayerTimesApiProvider] Using last known position instantly',
          );
        }
      } catch (e) {
        debugPrint('[PrayerTimesApiProvider] No last known position: $e');
      }

      // If no last known, get fresh position (reduced timeout: 8s instead of 15s)
      position ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium, // Medium is faster than high
          timeLimit: Duration(seconds: 8),
        ),
      );

      _latitude = position.latitude;
      _longitude = position.longitude;
      _elevation = position.altitude; // metres above sea level (for horizon dip)
      debugPrint(
        '[PrayerTimesApiProvider] Got position: $_latitude, $_longitude, alt=${_elevation}m',
      );

      // OPTIMIZATION: Resolve location first to get country code
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      debugPrint('[PrayerTimesApiProvider] Resolving location & country code...');
      final location = await _locationService.getLocationNames(
        position.latitude,
        position.longitude,
      );

      if (location != null) {
        final loc = location as BilingualLocation;
        _cityEn = loc.cityEn;
        _cityAr = loc.cityAr;
        _countryEn = loc.countryEn;
        _countryAr = loc.countryAr;
        _isoCountryCode = loc.isoCountryCode;
        
        // Auto-detect method if user hasn't explicitly set one manually
        if (!_isManualMethod) {
          _method = PrayerMethodResolver.resolveFromCountry(_isoCountryCode);
        }
      }

      debugPrint('[PrayerTimesApiProvider] Fetching data in parallel using resolved method...');
      final results = await Future.wait([
        // 1. Prayer times
        _apiService.fetchPrayerTimesByCoordinates(
          latitude: position.latitude,
          longitude: position.longitude,
          method: _method,
          madhab: _madhab,
          date: DateTime.now(),
          elevation: _elevation,
        ),
        // 2. Qibla (from IslamicAPI - included in prayer times response but fetch separately for reliability)
        _qiblaApiService.fetchQiblaDirection(
          latitude: position.latitude,
          longitude: position.longitude,
        ),
      ], eagerError: false);

      // Process results
      final response = results[0] as AlAdhanResponse;
      final qiblaResponse = results[1];

      _response = response;
      _requestUrl = response.requestUrl;
      _isFromCache = false;
      _lastUpdatedAt = DateTime.now();
      _prayerTimesDate = today;

      // Save to cache (AWAIT during first-time setup to ensure data persists)
      await _cacheService.saveAppState(
        latitude: position.latitude,
        longitude: position.longitude,
        elevation: _elevation,
        cityEn: _cityEn,
        cityAr: _cityAr,
        countryEn: _countryEn,
        countryAr: _countryAr,
        prayerTimes: response,
        prayerTimesDate: today,
        method: _method,
        isManualMethod: _isManualMethod,
        madhab: _madhab,
      );

      // Save qibla direction
      if (qiblaResponse != null) {
        _cacheService.saveQiblaDirection(
          (qiblaResponse as dynamic).direction ?? 0.0,
        );
      }

      // Reinitialize Qibla so it picks up the new location/direction
      QiblaProvider.instance?.initialize();

      _state = PrayerDataState.success;

      // Build the 30-day offline cache before the notification service starts
      // (starting it schedules the native alarms)
      await _cacheMultiDayPrayerTimes(position.latitude, position.longitude);

      // CRITICAL: Mark setup as done so NotificationManager will start
      await _cacheService.markSetupDone();

      // Start live notification now that setup is complete
      await NotificationManager.instance?.refreshFromCache();

      debugPrint(
        '[PrayerTimesApiProvider] First time setup complete (optimized)',
      );
    } catch (e) {
      _state = PrayerDataState.error;
      _errorMessage = 'Setup failed: $e';
      debugPrint('[PrayerTimesApiProvider] First time setup error: $e');
    }

    notifyListeners();
  }

  /// Manually refresh location - ONLY called when user taps "Update Location"
  Future<bool> refreshLocation() async {
    if (_isRefreshingLocation) {
      debugPrint('[PrayerTimesApiProvider] Refresh already in progress, ignoring');
      return false;
    }
    _isRefreshingLocation = true;
    debugPrint('[PrayerTimesApiProvider] Manual location refresh requested...');

    final previousState = _state;
    _state = PrayerDataState.loading;
    notifyListeners();

    try {
      // Check location services
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services disabled');
      }

      // Check permission
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission denied');
      }

      // Get fresh GPS location (reduced timeout: 8s). If the provider throttles
      // or times out — common when stationary and tapping repeatedly, the OS
      // blocks fresh fixes as "too fast"/"too close" — fall back to the last
      // known position, which is never throttled and accurate enough here.
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium, // Medium is faster
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (e) {
        debugPrint(
          '[PrayerTimesApiProvider] Fresh fix failed ($e), using last known...',
        );
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) {
        throw Exception('No location available (fresh fix throttled, no cached fix)');
      }

      _latitude = position.latitude;
      _longitude = position.longitude;
      _elevation = position.altitude; // metres above sea level (for horizon dip)

      // OPTIMIZATION: Resolve location first to get country code
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      debugPrint('[PrayerTimesApiProvider] Resolving location & country code...');
      final location = await _locationService.getLocationNames(
        position.latitude,
        position.longitude,
      );

      if (location != null) {
        final loc = location as BilingualLocation;
        _cityEn = loc.cityEn;
        _cityAr = loc.cityAr;
        _countryEn = loc.countryEn;
        _countryAr = loc.countryAr;
        _isoCountryCode = loc.isoCountryCode;

        // Auto-detect method if user hasn't explicitly set one manually
        if (!_isManualMethod) {
          _method = PrayerMethodResolver.resolveFromCountry(_isoCountryCode);
        }
      }

      debugPrint('[PrayerTimesApiProvider] Fetching data in parallel using resolved method...');
      final results = await Future.wait([
        // 1. Prayer times
        _apiService.fetchPrayerTimesByCoordinates(
          latitude: position.latitude,
          longitude: position.longitude,
          method: _method,
          madhab: _madhab,
          date: DateTime.now(),
          elevation: _elevation,
        ),
        // 2. Qibla
        _qiblaApiService.fetchQiblaDirection(
          latitude: position.latitude,
          longitude: position.longitude,
        ),
      ], eagerError: false);

      // Process results
      final response = results[0] as AlAdhanResponse;
      final qiblaResponse = results[1];

      _response = response;
      _requestUrl = response.requestUrl;
      _isFromCache = false;
      _isOfflineMode = false;
      _lastUpdatedAt = DateTime.now();
      _prayerTimesDate = today;

      // Save to cache (don't await)
      _cacheService.saveAppState(
        latitude: position.latitude,
        longitude: position.longitude,
        elevation: _elevation,
        cityEn: _cityEn,
        cityAr: _cityAr,
        countryEn: _countryEn,
        countryAr: _countryAr,
        prayerTimes: response,
        prayerTimesDate: today,
        method: _method,
        isManualMethod: _isManualMethod,
        madhab: _madhab,
      );

      _state = PrayerDataState.success;
      notifyListeners();

      // Rebuild the 30-day offline cache for the new location, then reschedule
      // the native alarms (previously alarms kept the old location's times
      // until the next midnight refresh)
      await _cacheMultiDayPrayerTimes(position.latitude, position.longitude);
      AdhanAlarmService.scheduleAllAlarms();

      // Update Qibla provider
      if (qiblaResponse != null) {
        _cacheService.saveQiblaDirection(
          (qiblaResponse as dynamic).direction ?? 0.0,
        );
        QiblaProvider.instance?.refreshFromNewLocation(
          position.latitude,
          position.longitude,
          (qiblaResponse as dynamic).direction ?? 0.0,
        );
      }

      debugPrint(
        '[PrayerTimesApiProvider] Location refresh complete (optimized)',
      );
      return true;
    } catch (e) {
      debugPrint('[PrayerTimesApiProvider] Location refresh failed: $e');
      _state = previousState;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isRefreshingLocation = false;
    }
  }

  /// Update calculation method and refetch
  Future<void> setMethod(CalculationMethodId method, {bool isManual = true}) async {
    if (_method != method || _isManualMethod != isManual) {
      _method = method;
      _isManualMethod = isManual;
      await _cacheService.saveMethod(method, isManual: isManual);

      // Refresh prayer times with new method (using cached location)
      if (_latitude != null && _longitude != null) {
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        await _refreshPrayerTimesOnly(_latitude!, _longitude!, today);
      }
    }
  }

  /// Automatically resolve method based on country code
  Future<void> autoDetectMethod() async {
    final detectedMethod = PrayerMethodResolver.resolveFromCountry(_isoCountryCode);
    await setMethod(detectedMethod, isManual: false);
  }

  /// Update madhab and refetch
  Future<void> setMadhab(MadhabId madhab) async {
    if (_madhab != madhab) {
      _madhab = madhab;
      await _cacheService.saveMadhab(madhab);

      // Refresh prayer times with new madhab (using cached location)
      if (_latitude != null && _longitude != null) {
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        await _refreshPrayerTimesOnly(_latitude!, _longitude!, today);
      }
    }
  }

  /// Request permission and retry (for first-time setup)
  Future<void> requestPermission() async {
    await Geolocator.requestPermission();
    await _firstTimeSetup();
  }

  /// Open app settings
  Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }

  /// Open location settings
  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  /// Set manual location from place picker (no GPS)
  /// Saves to cache with source='manual' and fetches prayer times + qibla by coordinates
  Future<bool> setManualLocation({
    required double lat,
    required double lng,
    required String cityAr,
    required String cityEn,
    required String countryAr,
    required String countryEn,
    String isoCountryCode = '',
  }) async {
    debugPrint(
      '[PrayerTimesApiProvider] setManualLocation: $cityEn, $countryEn ($lat, $lng), iso=$isoCountryCode',
    );

    _state = PrayerDataState.loading;
    notifyListeners();

    try {
      // Update in-memory state
      _latitude = lat;
      _longitude = lng;
      _elevation = 0; // manual city: no GPS altitude → no horizon-dip correction
      _cityAr = cityAr.isNotEmpty ? cityAr : cityEn;
      _cityEn = cityEn.isNotEmpty ? cityEn : cityAr;
      _countryAr = countryAr.isNotEmpty ? countryAr : countryEn;
      _countryEn = countryEn.isNotEmpty ? countryEn : countryAr;
      _lastUpdatedAt = DateTime.now();

      // Auto-resolve the calculation method from the chosen country (e.g. an
      // Algerian city → Algeria method with its calibrated offsets), unless the
      // user has explicitly picked a method. Mirrors the GPS path. Persist it so
      // it survives restarts (manual-location cache doesn't store the method).
      if (isoCountryCode.isNotEmpty) {
        _isoCountryCode = isoCountryCode;
      }
      if (!_isManualMethod && _isoCountryCode.isNotEmpty) {
        _method = PrayerMethodResolver.resolveFromCountry(_isoCountryCode);
        await _cacheService.saveMethod(_method, isManual: false);
      }

      // Save to cache with manual source
      await _cacheService.saveManualLocation(
        lat: lat,
        lng: lng,
        cityAr: _cityAr,
        cityEn: _cityEn,
        countryAr: _countryAr,
        countryEn: _countryEn,
      );

      // Fetch prayer times by coordinates
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await _refreshPrayerTimesOnly(lat, lng, today);

      // Fetch qibla by coordinates and notify QiblaProvider
      try {
        final qiblaResponse = await _qiblaApiService.fetchQiblaDirection(
          latitude: lat,
          longitude: lng,
        );
        await _cacheService.saveQiblaDirection(qiblaResponse.direction);
        QiblaProvider.instance?.refreshFromNewLocation(
          lat,
          lng,
          qiblaResponse.direction,
        );
      } catch (e) {
        debugPrint('[PrayerTimesApiProvider] Qibla fetch failed: $e');
      }

      _isFromCache = false;
      _isOfflineMode = false;
      _state = PrayerDataState.success;
      notifyListeners();

      debugPrint('[PrayerTimesApiProvider] Manual location set successfully');
      return true;
    } catch (e) {
      debugPrint('[PrayerTimesApiProvider] setManualLocation failed: $e');
      _state = PrayerDataState.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}

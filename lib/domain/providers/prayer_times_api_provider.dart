import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../../data/services/prayer_times_api_service.dart';
import '../../data/services/prayer_times_cache_service.dart';
import '../../data/services/bilingual_location_service.dart';
import '../../data/services/qibla_api_service.dart';

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
class PrayerTimesApiProvider extends ChangeNotifier {
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
  MadhabId _madhab = MadhabId.shafi;

  // Location (from cache)
  double? _latitude;
  double? _longitude;
  String _cityEn = '';
  String _cityAr = '';
  String _countryEn = '';
  String _countryAr = '';
  DateTime? _lastUpdatedAt;

  // Debug info
  String _requestUrl = '';
  String _deviceTimezone = '';
  bool _isFromCache = false;

  // Getters
  PrayerDataState get state => _state;
  AlAdhanResponse? get response => _response;
  String? get errorMessage => _errorMessage;
  CalculationMethodId get method => _method;
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

  /// Initialize - CACHE FIRST, no GPS unless first run
  Future<void> initialize() async {
    _state = PrayerDataState.loading;
    _deviceTimezone = DateTime.now().timeZoneName;
    notifyListeners();

    // Load settings
    _method = await _cacheService.loadMethod();
    _madhab = await _cacheService.loadMadhab();

    // Check if setup was already done
    final setupDone = await _cacheService.isSetupDone();

    if (setupDone) {
      // CACHE-FIRST: Load from cache, no GPS
      await _loadFromCache();
    } else {
      // FIRST RUN: Need GPS + network
      await _firstTimeSetup();
    }
  }

  /// Load from cache (offline-first)
  Future<void> _loadFromCache() async {
    debugPrint('[PrayerTimesApiProvider] Loading from cache...');

    final cached = await _cacheService.loadAppState();
    if (cached == null) {
      // Cache corrupted, do first-time setup
      await _firstTimeSetup();
      return;
    }

    // Set cached values
    _latitude = cached.latitude;
    _longitude = cached.longitude;
    _cityEn = cached.cityEn;
    _cityAr = cached.cityAr;
    _countryEn = cached.countryEn;
    _countryAr = cached.countryAr;
    _method = cached.method;
    _madhab = cached.madhab;
    _lastUpdatedAt = cached.updatedAt;

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    if (cached.isToday && cached.prayerTimes != null) {
      // Cache is for today, use it directly
      _response = cached.prayerTimes;
      _isFromCache = true;
      _isOfflineMode = false;
      _state = PrayerDataState.success;
      debugPrint('[PrayerTimesApiProvider] Using cached data for today');
    } else if (cached.prayerTimes != null) {
      // Cache is old, try to refresh prayer times ONLY (no GPS)
      _response = cached.prayerTimes; // Show old data first
      _isFromCache = true;
      _state = PrayerDataState.success;
      notifyListeners();

      // Try to refresh prayer times in background
      await _refreshPrayerTimesOnly(cached.latitude, cached.longitude, today);
    } else {
      // No prayer times at all, need to fetch
      await _refreshPrayerTimesOnly(cached.latitude, cached.longitude, today);
    }

    notifyListeners();
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
      );

      _response = response;
      _requestUrl = response.requestUrl;
      _isFromCache = false;
      _isOfflineMode = false;
      _state = PrayerDataState.success;

      // Update cache with new prayer times
      await _cacheService.updatePrayerTimes(
        prayerTimes: response,
        prayerTimesDate: dateStr,
      );

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

  /// First time setup - requires GPS and network
  Future<void> _firstTimeSetup() async {
    debugPrint('[PrayerTimesApiProvider] First time setup...');

    // Check location services
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _state = PrayerDataState.locationDisabled;
      _errorMessage = 'Location services are disabled';
      notifyListeners();
      return;
    }

    // Check permission
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
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

    // Get GPS location
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      _latitude = position.latitude;
      _longitude = position.longitude;

      // Reverse geocode
      final location = await _locationService.getLocationNames(
        position.latitude,
        position.longitude,
      );

      if (location != null) {
        _cityEn = location.cityEn;
        _cityAr = location.cityAr;
        _countryEn = location.countryEn;
        _countryAr = location.countryAr;
      }

      // Fetch prayer times
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final response = await _apiService.fetchPrayerTimesByCoordinates(
        latitude: position.latitude,
        longitude: position.longitude,
        method: _method,
        madhab: _madhab,
        date: DateTime.now(),
      );

      _response = response;
      _requestUrl = response.requestUrl;
      _isFromCache = false;
      _lastUpdatedAt = DateTime.now();

      // Save to cache
      await _cacheService.saveAppState(
        latitude: position.latitude,
        longitude: position.longitude,
        cityEn: _cityEn,
        cityAr: _cityAr,
        countryEn: _countryEn,
        countryAr: _countryAr,
        prayerTimes: response,
        prayerTimesDate: today,
        method: _method,
        madhab: _madhab,
      );

      _state = PrayerDataState.success;
      debugPrint('[PrayerTimesApiProvider] First time setup complete');
    } catch (e) {
      _state = PrayerDataState.error;
      _errorMessage = 'Setup failed: $e';
      debugPrint('[PrayerTimesApiProvider] First time setup error: $e');
    }

    notifyListeners();
  }

  /// Manually refresh location - ONLY called when user taps "Update Location"
  Future<bool> refreshLocation() async {
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

      // Get fresh GPS location
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      _latitude = position.latitude;
      _longitude = position.longitude;

      // Reverse geocode
      final location = await _locationService.getLocationNames(
        position.latitude,
        position.longitude,
      );

      if (location != null) {
        _cityEn = location.cityEn;
        _cityAr = location.cityAr;
        _countryEn = location.countryEn;
        _countryAr = location.countryAr;
      }

      // Fetch fresh prayer times
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final response = await _apiService.fetchPrayerTimesByCoordinates(
        latitude: position.latitude,
        longitude: position.longitude,
        method: _method,
        madhab: _madhab,
        date: DateTime.now(),
      );

      _response = response;
      _requestUrl = response.requestUrl;
      _isFromCache = false;
      _isOfflineMode = false;
      _lastUpdatedAt = DateTime.now();

      // Save to cache
      await _cacheService.saveAppState(
        latitude: position.latitude,
        longitude: position.longitude,
        cityEn: _cityEn,
        cityAr: _cityAr,
        countryEn: _countryEn,
        countryAr: _countryAr,
        prayerTimes: response,
        prayerTimesDate: today,
        method: _method,
        madhab: _madhab,
      );

      _state = PrayerDataState.success;
      notifyListeners();

      // Also fetch and cache Qibla direction
      try {
        final qiblaResponse = await _qiblaApiService.fetchQiblaDirection(
          latitude: position.latitude,
          longitude: position.longitude,
        );
        await _cacheService.saveQiblaDirection(qiblaResponse.direction);
        debugPrint(
          '[PrayerTimesApiProvider] Qibla also updated: ${qiblaResponse.direction}',
        );
      } catch (qiblaError) {
        debugPrint(
          '[PrayerTimesApiProvider] Qibla update failed (non-blocking): $qiblaError',
        );
      }

      debugPrint('[PrayerTimesApiProvider] Location refresh complete');
      return true;
    } catch (e) {
      debugPrint('[PrayerTimesApiProvider] Location refresh failed: $e');
      // Restore previous state, keep old cached values
      _state = previousState;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Update calculation method and refetch
  Future<void> setMethod(CalculationMethodId method) async {
    if (_method != method) {
      _method = method;
      await _cacheService.saveMethod(method);

      // Refresh prayer times with new method (using cached location)
      if (_latitude != null && _longitude != null) {
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        await _refreshPrayerTimesOnly(_latitude!, _longitude!, today);
      }
    }
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
}

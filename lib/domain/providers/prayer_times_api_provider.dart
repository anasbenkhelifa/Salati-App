import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../data/services/prayer_times_api_service.dart';
import '../../data/services/prayer_times_cache_service.dart';

/// State for the prayer times data
enum PrayerDataState {
  loading,
  success,
  permissionDenied,
  locationDisabled,
  error,
}

/// Provider to manage prayer times data from AlAdhan API using GPS
class PrayerTimesApiProvider extends ChangeNotifier {
  final PrayerTimesApiService _apiService = PrayerTimesApiService();
  final PrayerTimesCacheService _cacheService = PrayerTimesCacheService();

  PrayerDataState _state = PrayerDataState.loading;
  AlAdhanResponse? _response;
  String? _errorMessage;

  // Settings
  CalculationMethodId _method = CalculationMethodId.mwl;
  MadhabId _madhab = MadhabId.shafi;

  // Location
  double? _latitude;
  double? _longitude;
  String _locationNameEn = 'Current Location';
  String _locationNameAr = 'الموقع الحالي';

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
  String get locationNameEn => _locationNameEn;
  String get locationNameAr => _locationNameAr;
  String get requestUrl => _requestUrl;
  String get deviceTimezone => _deviceTimezone;
  bool get isFromCache => _isFromCache;

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
        final minute = int.parse(parts[1]);
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

  /// Initialize and load prayer times
  Future<void> initialize() async {
    _state = PrayerDataState.loading;
    notifyListeners();

    // Load saved settings
    _method = await _cacheService.loadMethod();
    _madhab = await _cacheService.loadMadhab();

    // Load cached location name
    final cachedName = await _cacheService.loadLocationName();
    _locationNameEn = cachedName.nameEn;
    _locationNameAr = cachedName.nameAr;

    // Get device timezone info
    _deviceTimezone = DateTime.now().timeZoneName;

    // Get location and fetch prayer times
    await _acquireLocationAndFetch();
  }

  /// Acquire GPS location and fetch prayer times
  Future<void> _acquireLocationAndFetch() async {
    // Check if location service is enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Try to use cached position
      final cached = await _cacheService.loadLastPosition();
      if (cached != null) {
        _latitude = cached.lat;
        _longitude = cached.lon;
        await _fetchPrayerTimes();
      } else {
        _state = PrayerDataState.locationDisabled;
        _errorMessage = 'Location services are disabled';
        notifyListeners();
      }
      return;
    }

    // Check permission
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Try cached position
        final cached = await _cacheService.loadLastPosition();
        if (cached != null) {
          _latitude = cached.lat;
          _longitude = cached.lon;
          await _fetchPrayerTimes();
        } else {
          _state = PrayerDataState.permissionDenied;
          _errorMessage = 'Location permission denied';
          notifyListeners();
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Try cached position
      final cached = await _cacheService.loadLastPosition();
      if (cached != null) {
        _latitude = cached.lat;
        _longitude = cached.lon;
        await _fetchPrayerTimes();
      } else {
        _state = PrayerDataState.permissionDenied;
        _errorMessage = 'Location permission permanently denied';
        notifyListeners();
      }
      return;
    }

    // Get current position
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      _latitude = position.latitude;
      _longitude = position.longitude;

      // Cache the position
      await _cacheService.saveLastPosition(_latitude!, _longitude!);

      // Reverse geocode for display name
      await _reverseGeocode();

      // Fetch prayer times
      await _fetchPrayerTimes();
    } catch (e) {
      // Try cached position
      final cached = await _cacheService.loadLastPosition();
      if (cached != null) {
        _latitude = cached.lat;
        _longitude = cached.lon;
        await _fetchPrayerTimes();
      } else {
        _state = PrayerDataState.error;
        _errorMessage = 'Could not get location: $e';
        notifyListeners();
      }
    }
  }

  /// Reverse geocode to get display name
  Future<void> _reverseGeocode() async {
    if (_latitude == null || _longitude == null) return;

    try {
      final placemarks = await placemarkFromCoordinates(
        _latitude!,
        _longitude!,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final city = place.locality ?? place.subAdministrativeArea ?? '';
        final country = place.country ?? '';

        if (city.isNotEmpty || country.isNotEmpty) {
          _locationNameEn = [
            city,
            country,
          ].where((s) => s.isNotEmpty).join(', ');
          // For Arabic, use same name (geocoding usually returns in device language)
          // If Arabic needed, would need translation API
          _locationNameAr = _locationNameEn;

          // Cache the name
          await _cacheService.saveLocationName(
            nameEn: _locationNameEn,
            nameAr: _locationNameAr,
          );
        }
      }
    } catch (e) {
      // Keep default names
    }
  }

  /// Fetch prayer times from API
  Future<void> _fetchPrayerTimes() async {
    if (_latitude == null || _longitude == null) {
      _state = PrayerDataState.error;
      _errorMessage = 'No location available';
      notifyListeners();
      return;
    }

    final today = DateTime.now();
    final dateStr = DateFormat('dd-MM-yyyy').format(today);

    try {
      // Fetch from API using coordinates
      final response = await _apiService.fetchPrayerTimesByCoordinates(
        latitude: _latitude!,
        longitude: _longitude!,
        method: _method,
        madhab: _madhab,
        date: today,
      );

      _response = response;
      _requestUrl = response.requestUrl;
      _isFromCache = false;

      // Cache the response
      await _cacheService.saveApiResponse(
        response: response,
        date: dateStr,
        latitude: _latitude!,
        longitude: _longitude!,
        methodId: _method.id,
        madhabId: _madhab.id,
      );

      _state = PrayerDataState.success;
      _errorMessage = null;
    } catch (e) {
      // Try to load from cache
      final cached = await _cacheService.loadCachedResponse(
        date: dateStr,
        latitude: _latitude!,
        longitude: _longitude!,
        methodId: _method.id,
        madhabId: _madhab.id,
      );

      if (cached != null) {
        _response = cached;
        _isFromCache = true;
        _state = PrayerDataState.success;
        _errorMessage = null;
      } else {
        _state = PrayerDataState.error;
        _errorMessage = 'Network error: $e';
      }
    }

    notifyListeners();
  }

  /// Update calculation method and refetch
  Future<void> setMethod(CalculationMethodId method) async {
    if (_method != method) {
      _method = method;
      await _cacheService.saveMethod(method);
      await _fetchPrayerTimes();
    }
  }

  /// Update madhab and refetch
  Future<void> setMadhab(MadhabId madhab) async {
    if (_madhab != madhab) {
      _madhab = madhab;
      await _cacheService.saveMadhab(madhab);
      await _fetchPrayerTimes();
    }
  }

  /// Refresh location and prayer times
  Future<void> refresh() async {
    _state = PrayerDataState.loading;
    notifyListeners();
    await _acquireLocationAndFetch();
  }

  /// Request permission and retry
  Future<void> requestPermission() async {
    await Geolocator.requestPermission();
    await refresh();
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

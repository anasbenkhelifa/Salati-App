import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../domain/providers/live_notification_provider.dart';
import '../data/services/notification_service.dart';
import '../data/services/bilingual_location_service.dart';
import 'core/localization/app_locale_provider.dart';

/// Widget that manages the live notification lifecycle
class NotificationManager extends StatefulWidget {
  final Widget child;

  const NotificationManager({super.key, required this.child});

  /// Global access to notification manager state
  static _NotificationManagerState? of(BuildContext context) {
    return context.findAncestorStateOfType<_NotificationManagerState>();
  }

  @override
  State<NotificationManager> createState() => _NotificationManagerState();
}

class _NotificationManagerState extends State<NotificationManager>
    with WidgetsBindingObserver {
  final LiveNotificationProvider _notificationProvider =
      LiveNotificationProvider();
  final NotificationService _notificationService = NotificationService();
  final BilingualLocationService _bilingualLocationService =
      BilingualLocationService();

  bool _initialized = false;
  bool _hasPermission = false;
  BilingualLocation? _bilingualLocation;
  double? _latitude;
  double? _longitude;

  bool get hasPermission => _hasPermission;
  NotificationService get service => _notificationService;
  LiveNotificationProvider get provider => _notificationProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeNotification();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationProvider.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _initialized) {
      _refreshLocation();
    }
  }

  Future<void> _initializeNotification() async {
    // Initialize notification service and check permission
    _hasPermission = await _notificationService.initialize();

    if (!_hasPermission) {
      debugPrint('[NotificationManager] No notification permission');
      return;
    }

    // Get location and start live notifications
    await _refreshLocation();
  }

  Future<void> _refreshLocation() async {
    try {
      // Check location permission
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      _latitude = position.latitude;
      _longitude = position.longitude;

      // Get bilingual location names using Nominatim API
      _bilingualLocation = await _bilingualLocationService.getLocationNames(
        position.latitude,
        position.longitude,
      );

      // Start notification with current language - use CITY ONLY for notification header
      final isArabic = mounted ? AppLocaleProvider.of(context).isArabic : false;
      // Use getCityOnly for notification (e.g., "Batna" or "باتنة")
      final locationName =
          _bilingualLocation?.getCityOnly(isArabic) ??
          '${position.latitude.toStringAsFixed(2)}, ${position.longitude.toStringAsFixed(2)}';

      await _notificationProvider.start(
        locationName: locationName,
        isArabic: isArabic,
        latitude: position.latitude,
        longitude: position.longitude,
      );

      _initialized = true;
      debugPrint(
        '[NotificationManager] Live notification started with location: $locationName',
      );
    } catch (e) {
      debugPrint('[NotificationManager] Error: $e');
    }
  }

  /// Request notification permission
  Future<bool> requestPermission() async {
    _hasPermission = await _notificationService.requestPermission();
    if (_hasPermission && !_initialized) {
      await _refreshLocation();
    }
    if (mounted) setState(() {});
    return _hasPermission;
  }

  /// Test notification function
  Future<bool> testNotification() async {
    return await _notificationService.showTestNotification();
  }

  /// Start live notifications manually
  Future<void> startLiveNotification() async {
    if (!_hasPermission) {
      _hasPermission = await requestPermission();
    }
    if (_hasPermission) {
      await _refreshLocation();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Update notification with CITY ONLY when language changes
    if (_initialized &&
        _bilingualLocation != null &&
        _latitude != null &&
        _longitude != null) {
      final isArabic = AppLocaleProvider.of(context).isArabic;
      // Use getCityOnly for notification (e.g., "Batna" or "باتنة")
      final locationName = _bilingualLocation!.getCityOnly(isArabic);

      // Update the notification with the new language-appropriate location name
      _notificationProvider.updateLanguage(isArabic);

      // Also update location name in provider
      _notificationProvider.updateLocation(
        locationName: locationName,
        latitude: _latitude!,
        longitude: _longitude!,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

import 'package:flutter/material.dart';
import '../domain/providers/live_notification_provider.dart';
import '../data/services/notification_service.dart';
import '../data/services/prayer_times_cache_service.dart';
import '../data/services/hijri_date_service.dart';
import 'core/localization/app_locale_provider.dart';

/// Widget that manages the live notification lifecycle
/// Uses CACHE-ONLY for notification - NO GPS or network calls
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
  final PrayerTimesCacheService _cacheService = PrayerTimesCacheService();

  bool _initialized = false;
  bool _hasPermission = false;

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
    // DO NOT refresh location on resume - use cache only
    // This is intentional for offline-first behavior
    if (state == AppLifecycleState.resumed && _initialized) {
      // Just update the notification language if it changed
      final isArabic = mounted ? AppLocaleProvider.of(context).isArabic : false;
      _notificationProvider.updateLanguage(isArabic);
    }
  }

  Future<void> _initializeNotification() async {
    // Initialize notification service and check permission
    _hasPermission = await _notificationService.initialize();

    if (!_hasPermission) {
      debugPrint('[NotificationManager] No notification permission');
      return;
    }

    // Load from CACHE ONLY - no GPS, no network
    await _startFromCache();

    // Refresh Hijri cache in background (non-blocking, after UI is visible)
    _refreshHijriCacheInBackground();
  }

  /// Refresh Hijri cache from API - runs AFTER app is visible
  /// This was moved from main() to avoid blocking app startup
  void _refreshHijriCacheInBackground() {
    // Fire and forget - don't await
    Future(() async {
      try {
        final hijriService = HijriDateService();
        final today = DateTime.now();
        final hijriDate = await hijriService.getHijriDate(today);
        if (hijriDate != null) {
          debugPrint(
            '[NotificationManager] Hijri cache refreshed: ${hijriDate.formatEnglish()}',
          );
        }
      } catch (e) {
        debugPrint('[NotificationManager] Hijri refresh error (non-fatal): $e');
      }
    });
  }

  /// Start notification using CACHED data only - NO GPS
  Future<void> _startFromCache() async {
    try {
      // Check if setup was done
      final setupDone = await _cacheService.isSetupDone();

      if (!setupDone) {
        debugPrint(
          '[NotificationManager] Setup not done, skipping notification',
        );
        // Don't start notification until first-time setup is complete
        return;
      }

      // Load cached state
      final cached = await _cacheService.loadAppState();

      if (cached == null) {
        debugPrint('[NotificationManager] No cached data available');
        return;
      }

      // Start notification with cached data
      final isArabic = mounted ? AppLocaleProvider.of(context).isArabic : false;
      final locationName = cached.getCityOnly(isArabic);

      await _notificationProvider.start(
        locationName: locationName,
        isArabic: isArabic,
        latitude: cached.latitude,
        longitude: cached.longitude,
      );

      _initialized = true;
      debugPrint(
        '[NotificationManager] Notification started from cache: $locationName',
      );
    } catch (e) {
      debugPrint('[NotificationManager] Error starting from cache: $e');
    }
  }

  /// Called when cache is updated (e.g., after location refresh)
  Future<void> refreshFromCache() async {
    if (!_hasPermission) return;
    await _startFromCache();
  }

  /// Request notification permission
  Future<bool> requestPermission() async {
    _hasPermission = await _notificationService.requestPermission();
    if (_hasPermission && !_initialized) {
      await _startFromCache();
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
      await _startFromCache();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Update notification language when app language changes
    if (_initialized) {
      _updateNotificationLanguage();
    }
  }

  Future<void> _updateNotificationLanguage() async {
    final isArabic = AppLocaleProvider.of(context).isArabic;

    // Load cached location name for the new language
    final cached = await _cacheService.loadAppState();
    if (cached != null) {
      final locationName = cached.getCityOnly(isArabic);

      _notificationProvider.updateLanguage(isArabic);
      _notificationProvider.updateLocation(
        locationName: locationName,
        latitude: cached.latitude,
        longitude: cached.longitude,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

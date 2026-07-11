import 'package:flutter/material.dart';
import 'package:adhan_app/domain/providers/live_notification_provider.dart';
import 'package:adhan_app/data/services/notification_service.dart';
import 'package:adhan_app/data/services/prayer_times_cache_service.dart';
import 'package:adhan_app/data/services/hijri_date_service.dart';
import 'package:adhan_app/core/localization/app_locale_provider.dart';
import 'package:adhan_app/domain/providers/prayer_times_api_provider.dart';

/// Widget that manages the live notification lifecycle
/// Uses CACHE-ONLY for notification - NO GPS or network calls
class NotificationManager extends StatefulWidget {
  final Widget child;

  const NotificationManager({super.key, required this.child});

  /// Global access to notification manager state
  static _NotificationManagerState? of(BuildContext context) {
    return context.findAncestorStateOfType<_NotificationManagerState>();
  }

  /// Static instance for global access (set when state is created)
  static _NotificationManagerState? instance;

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
    NotificationManager.instance = this;
    WidgetsBinding.instance.addObserver(this);
    _initializeNotification();
  }

  @override
  void dispose() {
    NotificationManager.instance = null;
    WidgetsBinding.instance.removeObserver(this);
    _notificationProvider.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _initialized) {
      // Resume Dart-side timer and update language
      final isArabic = mounted ? AppLocaleProvider.of(context).isArabic : false;
      _notificationProvider.updateLanguage(isArabic);
      _notificationProvider.resumeTimer();
    } else if (state == AppLifecycleState.paused && _initialized) {
      // Pause Dart-side timer — native service handles updates independently
      _notificationProvider.pauseTimer();
    }
  }

  Future<void> _initializeNotification() async {
    debugPrint('[NotificationManager] Starting initialization...');

    // STEP 1: Initialize notification plugin ONLY (creates channels, no permission request)
    await _notificationService.initializePluginOnly();
    debugPrint('[NotificationManager] Notification service initialized');

    // STEP 2: Request BOTH permissions explicitly at startup
    await _requestAllPermissions();

    // STEP 3: Check if we have notification permission now
    _hasPermission = await _notificationService.areNotificationsEnabled();
    debugPrint(
      '[NotificationManager] Notification permission: $_hasPermission',
    );

    // STEP 4: First run only — now that the notification permission flow
    // has settled, run location setup. Sequencing the two dialogs
    // (notification → location) prevents the collision that froze the
    // app on a fresh install.
    try {
      await PrayerTimesApiProvider.instance.ensureFirstTimeSetup();
    } catch (e) {
      debugPrint('[NotificationManager] First-time setup failed: $e');
    }

    // Load from CACHE ONLY - no GPS, no network
    await _startFromCache();

    // Keep the weekly Surah Al-Kahf reminder in sync (non-blocking)
    _notificationService.syncKahfReminder();

    // Journal: "did you pray?" nudges + weekly/monthly/yearly summaries
    _notificationService.syncPrayedReminders();

    // Refresh Hijri cache in background (non-blocking, after UI is visible)
    _refreshHijriCacheInBackground();
  }

  /// Request notification permission at startup
  /// NOTE: Location permission is handled by PrayerTimesApiProvider — not here.
  Future<void> _requestAllPermissions() async {
    // Request notification permission (Android 13+)
    debugPrint('[NotificationManager] Requesting notification permission...');
    final notifResult = await _notificationService.requestPermission();
    debugPrint(
      '[NotificationManager] Notification permission result: $notifResult',
    );
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

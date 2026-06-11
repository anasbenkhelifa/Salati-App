import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:lat_lng_to_timezone/lat_lng_to_timezone.dart' as tzmap;

/// Service to manage the persistent live prayer notification
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const String channelId = 'adhan_live';
  static const String channelName = 'Prayer Times Live';
  static const String channelDescription = 'Ongoing prayer times notification';
  static const int notificationId = 1001;

  bool _isInitialized = false;
  bool _hasPermission = false;

  bool get hasPermission => _hasPermission;

  /// Initialize the notification service
  Future<bool> initialize() async {
    if (_isInitialized) return _hasPermission;

    debugPrint('[NotificationService] Initializing...');

    // Android initialization
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // iOS initialization (optional for future)
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(initSettings);
    debugPrint('[NotificationService] Plugin initialized');

    // Create the notification channel (Android 8+)
    await _createChannel();

    _isInitialized = true;

    // Check/request permission
    _hasPermission = await _checkAndRequestPermission();
    debugPrint('[NotificationService] Permission: $_hasPermission');

    return _hasPermission;
  }

  /// Initialize WITHOUT requesting permission (just setup plugin and channel)
  Future<void> initializePluginOnly() async {
    if (_isInitialized) return;

    debugPrint('[NotificationService] Initializing plugin only...');

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(initSettings);
    await _createChannel();
    _isInitialized = true;
    debugPrint(
      '[NotificationService] Plugin initialized (no permission request)',
    );
  }

  /// Create the notification channel
  Future<void> _createChannel() async {
    const androidChannel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDescription,
      importance: Importance.low, // LOW = silent, shows in tray
      playSound: false,
      enableVibration: false,
      showBadge: false,
    );

    final androidPlugin =
        _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(androidChannel);
      debugPrint('[NotificationService] Channel "$channelId" created');
    }
  }

  /// Check and request notification permission (Android 13+)
  Future<bool> _checkAndRequestPermission() async {
    if (!Platform.isAndroid) return true;

    final androidPlugin =
        _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    if (androidPlugin == null) return false;

    // Check if already granted
    final granted = await androidPlugin.areNotificationsEnabled() ?? false;
    if (granted) {
      debugPrint(
        '[NotificationService] Notification permission already granted',
      );
      return true;
    }

    // Request permission (Android 13+)
    debugPrint('[NotificationService] Requesting notification permission...');
    final result = await androidPlugin.requestNotificationsPermission();
    debugPrint('[NotificationService] Permission request result: $result');
    return result ?? false;
  }

  /// Request permission explicitly (can be called from UI)
  Future<bool> requestPermission() async {
    if (!_isInitialized) await initialize();

    final androidPlugin =
        _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    if (androidPlugin == null) return false;

    final result = await androidPlugin.requestNotificationsPermission();
    _hasPermission = result ?? false;
    debugPrint(
      '[NotificationService] Permission after request: $_hasPermission',
    );
    return _hasPermission;
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    final androidPlugin =
        _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    if (androidPlugin == null) return false;
    return await androidPlugin.areNotificationsEnabled() ?? false;
  }

  /// Show or update the ongoing notification
  Future<void> showLiveNotification({
    required String title,
    required String body,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (!_hasPermission) {
      debugPrint(
        '[NotificationService] Cannot show notification - no permission',
      );
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true, // Cannot be dismissed
      autoCancel: false,
      showWhen: false, // Hide timestamp
      playSound: false,
      enableVibration: false,
      onlyAlertOnce: true, // Don't alert on updates
      category: AndroidNotificationCategory.service,
      visibility: NotificationVisibility.public,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _notifications.show(notificationId, title, body, notificationDetails);

    debugPrint('[NotificationService] Notification updated: $title');
  }

  /// Show a test notification to verify everything works
  Future<bool> showTestNotification() async {
    debugPrint('[NotificationService] Showing test notification...');

    if (!_isInitialized) {
      await initialize();
    }

    if (!_hasPermission) {
      debugPrint('[NotificationService] Test failed - no permission');
      return false;
    }

    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      playSound: false,
      enableVibration: false,
      onlyAlertOnce: true,
      category: AndroidNotificationCategory.service,
      visibility: NotificationVisibility.public,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _notifications.show(
      notificationId,
      'Adhan Live Test',
      'If you see this, notifications work!',
      notificationDetails,
    );

    debugPrint('[NotificationService] Test notification posted!');
    return true;
  }

  /// Cancel the live notification
  Future<void> cancelNotification() async {
    await _notifications.cancel(notificationId);
    debugPrint('[NotificationService] Notification cancelled');
  }

  // ───────────────────── Surah Al-Kahf Friday reminder ─────────────────────

  static const int kahfNotificationId = 3001;
  static const String _kahfChannelId = 'jumuah_reminders';

  /// (Re)schedule or cancel the weekly Friday-morning Surah Al-Kahf
  /// reminder based on the 'kahf_reminder_enabled' pref (default on).
  /// Fully offline: local timezone resolved from cached coordinates.
  Future<void> syncKahfReminder() async {
    try {
      if (!_isInitialized) await initializePluginOnly();
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('kahf_reminder_enabled') ?? true;

      if (!enabled) {
        await _notifications.cancel(kahfNotificationId);
        debugPrint('[NotificationService] Kahf reminder cancelled');
        return;
      }

      // Resolve local timezone from cached location (offline)
      tz.Location location = tz.UTC;
      final lat = prefs.getDouble('cached_lat');
      final lng = prefs.getDouble('cached_lng');
      if (lat != null && lng != null) {
        try {
          location = tz.getLocation(tzmap.latLngToTimezoneString(lat, lng));
        } catch (_) {}
      }

      // Next Friday 09:00 local; repeats weekly via dayOfWeekAndTime
      final now = tz.TZDateTime.now(location);
      var next = tz.TZDateTime(location, now.year, now.month, now.day, 9);
      while (next.weekday != DateTime.friday || !next.isAfter(now)) {
        next = next.add(const Duration(days: 1));
      }

      final lang = prefs.getString('app_language') ?? 'ar';
      final String title;
      final String body;
      switch (lang) {
        case 'ar':
          title = 'جمعة مباركة 🌿';
          body = 'لا تنسَ قراءة سورة الكهف اليوم';
          break;
        case 'fr':
          title = 'Joumou\'a moubaraka 🌿';
          body = 'N\'oubliez pas de lire la sourate Al-Kahf aujourd\'hui';
          break;
        default:
          title = 'Blessed Friday 🌿';
          body = 'Don\'t forget to read Surah Al-Kahf today';
      }

      const androidDetails = AndroidNotificationDetails(
        _kahfChannelId,
        'Jumu\'ah Reminders',
        channelDescription: 'Friday Surah Al-Kahf reminder',
        importance: Importance.high,
        priority: Priority.high,
      );

      await _notifications.zonedSchedule(
        kahfNotificationId,
        title,
        body,
        next,
        const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
      debugPrint('[NotificationService] Kahf reminder scheduled for $next');
    } catch (e) {
      debugPrint('[NotificationService] Kahf reminder sync failed: $e');
    }
  }
}

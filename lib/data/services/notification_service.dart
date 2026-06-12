import 'dart:async';
import 'dart:convert';
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

  // ───────────────────── Prayer journal reminders & summaries ──────────────

  static const int _prayedReminderBaseId = 4100; // +0..4 today, +10..14 tmrw
  static const int _weeklySummaryId = 4201;
  static const int _monthlySummaryId = 4202;
  static const int _yearlySummaryId = 4203;
  static const String _journalChannelId = 'journal_reminders';

  static const _apiNames = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
  static const _namesAr = ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'];
  static const _namesEn = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

  AndroidNotificationDetails get _journalDetails =>
      const AndroidNotificationDetails(
        _journalChannelId,
        'Prayer Journal',
        channelDescription: 'Gentle prayer journal reminders',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );

  tz.Location _localLocation(SharedPreferences prefs) {
    final lat = prefs.getDouble('cached_lat');
    final lng = prefs.getDouble('cached_lng');
    if (lat != null && lng != null) {
      try {
        return tz.getLocation(tzmap.latLngToTimezoneString(lat, lng));
      } catch (_) {}
    }
    return tz.UTC;
  }

  /// Cancel the "did you pray X?" reminder for today's prayer [index].
  Future<void> cancelPrayedReminder(int index) async {
    await _notifications.cancel(_prayedReminderBaseId + index);
  }

  /// (Re)schedule the journal notifications:
  ///  - "Did you pray X?" 25 minutes after each adhan (today + tomorrow,
  ///    already-marked prayers skipped)
  ///  - weekly / monthly / yearly summary prompts
  /// All cancelled when the journal is disabled in Controls.
  Future<void> syncPrayedReminders() async {
    try {
      if (!_isInitialized) await initializePluginOnly();
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('prayer_journal_enabled') ?? true;

      // Clear all journal notifications first
      for (int d = 0; d < 2; d++) {
        for (int i = 0; i < 5; i++) {
          await _notifications.cancel(_prayedReminderBaseId + d * 10 + i);
        }
      }
      if (!enabled) {
        await _notifications.cancel(_weeklySummaryId);
        await _notifications.cancel(_monthlySummaryId);
        await _notifications.cancel(_yearlySummaryId);
        debugPrint('[NotificationService] Journal reminders disabled');
        return;
      }

      final location = _localLocation(prefs);
      final lang = prefs.getString('app_language') ?? 'ar';
      final now = tz.TZDateTime.now(location);

      final raw = prefs.getString('cached_prayer_times_by_date');
      if (raw != null) {
        final byDate = jsonDecode(raw) as Map<String, dynamic>;
        for (int dayOffset = 0; dayOffset < 2; dayOffset++) {
          final day = now.add(Duration(days: dayOffset));
          final dateKey =
              '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
          final timings = byDate[dateKey];
          if (timings is! Map) continue;

          // Skip prayers already marked today
          Map<String, dynamic> log = {};
          if (dayOffset == 0) {
            final logRaw = prefs.getString('prayer_log_$dateKey');
            if (logRaw != null) {
              try {
                log = jsonDecode(logRaw) as Map<String, dynamic>;
              } catch (_) {}
            }
          }

          for (int i = 0; i < _apiNames.length; i++) {
            final prayerKey = _apiNames[i].toLowerCase();
            if (log.containsKey(prayerKey)) continue;
            final timeStr = timings[_apiNames[i]];
            if (timeStr is! String) continue;
            final parts = timeStr.split(':');
            if (parts.length < 2) continue;
            final h = int.tryParse(parts[0]);
            final m = int.tryParse(parts[1].split(' ')[0]);
            if (h == null || m == null) continue;

            final fireAt = tz.TZDateTime(
              location, day.year, day.month, day.day, h, m,
            ).add(const Duration(minutes: 25));
            if (!fireAt.isAfter(now)) continue;

            final name = lang == 'ar' ? _namesAr[i] : _namesEn[i];
            final String title;
            final String body;
            switch (lang) {
              case 'ar':
                title = 'هل صليت $name؟ 🌱';
                body = 'اضغط لتسجيلها في سجل الصلاة';
                break;
              case 'fr':
                title = 'Avez-vous prié $name ? 🌱';
                body = 'Touchez pour la noter dans votre journal';
                break;
              default:
                title = 'Did you pray $name? 🌱';
                body = 'Tap to check it off in your journal';
            }

            await _notifications.zonedSchedule(
              _prayedReminderBaseId + dayOffset * 10 + i,
              title,
              body,
              fireAt,
              NotificationDetails(android: _journalDetails),
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.absoluteTime,
            );
          }
        }
      }

      // Periodic summaries: generic prompt, real numbers live in the sheet
      final String sumTitle;
      final String sumBody;
      switch (lang) {
        case 'ar':
          sumTitle = 'ملخص صلاتك 🌱';
          sumBody = 'افتح سجل الصلاة لترى إحصاءاتك';
          break;
        case 'fr':
          sumTitle = 'Votre bilan de prière 🌱';
          sumBody = 'Ouvrez le journal pour voir vos statistiques';
          break;
        default:
          sumTitle = 'Your prayer summary 🌱';
          sumBody = 'Open your journal to see your stats';
      }

      tz.TZDateTime nextAt(bool Function(tz.TZDateTime) match, int hour) {
        var d = tz.TZDateTime(location, now.year, now.month, now.day, hour);
        while (!match(d) || !d.isAfter(now)) {
          d = d.add(const Duration(days: 1));
        }
        return d;
      }

      // Weekly: Sunday evening
      await _notifications.zonedSchedule(
        _weeklySummaryId, sumTitle, sumBody,
        nextAt((d) => d.weekday == DateTime.sunday, 20),
        NotificationDetails(android: _journalDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
      // Monthly: 1st at 09:00
      await _notifications.zonedSchedule(
        _monthlySummaryId, sumTitle, sumBody,
        nextAt((d) => d.day == 1, 9),
        NotificationDetails(android: _journalDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
      );
      // Yearly: Jan 1 at 09:30
      await _notifications.zonedSchedule(
        _yearlySummaryId, sumTitle, sumBody,
        nextAt((d) => d.day == 1 && d.month == 1, 9),
        NotificationDetails(android: _journalDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
      );

      debugPrint('[NotificationService] Journal reminders synced');
    } catch (e) {
      debugPrint('[NotificationService] Journal reminder sync failed: $e');
    }
  }
}

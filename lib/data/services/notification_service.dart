import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
}

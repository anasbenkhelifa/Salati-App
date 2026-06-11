import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Background/terminated FCM handler. Must be a top-level function annotated
/// with @pragma('vm:entry-point'). "Notification" messages (what the Firebase
/// console Messaging composer sends) are rendered automatically by the system
/// tray when the app is backgrounded/terminated, so this only needs to exist
/// for completeness and any future data-only messages.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[Push] Background message: ${message.messageId}');
}

/// Firebase Cloud Messaging integration: registers the device for push,
/// displays notifications while the app is in the foreground, and exposes the
/// FCM token for testing.
class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();
  static PushNotificationService get instance => _instance;

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  // Channel used for foreground display AND as the default channel for
  // system-rendered background notifications (see AndroidManifest meta-data).
  static const String channelId = 'general_announcements';
  static const String channelName = 'Announcements';
  static const String channelDescription =
      'Updates and announcements from Salati';
  static const int _notificationId = 4001;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      // Register the background handler before anything else.
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // iOS only: ask for push permission. On Android this would fire the
      // POST_NOTIFICATIONS dialog from main() — OUTSIDE the sequenced
      // permission flow — colliding with the geolocator request and leaving
      // geolocator's "request in progress" flag stuck until app restart
      // (first-run froze with no location dialog). Android's notification
      // permission is requested by NotificationManager instead, and that
      // grant covers FCM too (same POST_NOTIFICATIONS permission).
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _fcm.requestPermission();
      }

      // Set up the local-notifications plugin + channel for foreground display.
      await _local.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_adhan'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      const channel = AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.high,
      );
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // Foreground messages are NOT shown in the tray automatically — render
      // them ourselves.
      FirebaseMessaging.onMessage.listen(_showForeground);

      // Subscribe to a broadcast topic so console campaigns targeting the "all"
      // topic reach every install (token / "all users" targeting also works).
      await _fcm.subscribeToTopic('all');

      final token = await _fcm.getToken();
      debugPrint('[Push] ===== FCM TOKEN =====');
      debugPrint('[Push] $token');
      debugPrint('[Push] =====================');
    } catch (e) {
      debugPrint('[Push] Initialization failed: $e');
    }
  }

  Future<void> _showForeground(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return; // data-only message: nothing to display
    debugPrint('[Push] Foreground message: ${notification.title}');
    await _local.show(
      _notificationId,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_stat_adhan',
        ),
      ),
    );
  }

  /// FCM registration token (handy for sending a test message from the console).
  Future<String?> getToken() => _fcm.getToken();
}

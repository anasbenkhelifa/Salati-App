import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bridge to communicate with Android ForegroundService via MethodChannel
class ForegroundServiceBridge {
  static const _channel = MethodChannel(
    'com.example.adhan_app/foreground_service',
  );

  /// Start the foreground service with initial notification content
  static Future<bool> startService({
    required String title,
    required String body,
  }) async {
    try {
      final result = await _channel.invokeMethod('startService', {
        'title': title,
        'body': body,
      });
      debugPrint('[ForegroundServiceBridge] startService: $result');
      return result == true;
    } catch (e) {
      debugPrint('[ForegroundServiceBridge] startService error: $e');
      return false;
    }
  }

  /// Stop the foreground service
  static Future<bool> stopService() async {
    try {
      final result = await _channel.invokeMethod('stopService');
      debugPrint('[ForegroundServiceBridge] stopService: $result');
      return result == true;
    } catch (e) {
      debugPrint('[ForegroundServiceBridge] stopService error: $e');
      return false;
    }
  }

  /// Update the notification content
  static Future<bool> updateNotification({
    required String title,
    required String body,
  }) async {
    try {
      final result = await _channel.invokeMethod('updateNotification', {
        'title': title,
        'body': body,
      });
      return result == true;
    } catch (e) {
      debugPrint('[ForegroundServiceBridge] updateNotification error: $e');
      return false;
    }
  }

  /// Check if the service is currently running
  static Future<bool> isRunning() async {
    try {
      final result = await _channel.invokeMethod('isRunning');
      return result == true;
    } catch (e) {
      debugPrint('[ForegroundServiceBridge] isRunning error: $e');
      return false;
    }
  }

  /// Check if live notification is enabled in settings
  static Future<bool> isEnabled() async {
    try {
      final result = await _channel.invokeMethod('isEnabled');
      return result == true;
    } catch (e) {
      debugPrint('[ForegroundServiceBridge] isEnabled error: $e');
      return true; // Default to enabled
    }
  }

  /// Set the enabled flag in SharedPreferences
  static Future<bool> setEnabled(bool enabled) async {
    try {
      final result = await _channel.invokeMethod('setEnabled', {
        'enabled': enabled,
      });
      debugPrint('[ForegroundServiceBridge] setEnabled($enabled): $result');
      return result == true;
    } catch (e) {
      debugPrint('[ForegroundServiceBridge] setEnabled error: $e');
      return false;
    }
  }
}

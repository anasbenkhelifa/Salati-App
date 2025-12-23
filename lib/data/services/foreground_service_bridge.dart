import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service to communicate with native Android foreground service
class ForegroundServiceBridge {
  static const MethodChannel _channel = MethodChannel(
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
      debugPrint('[ForegroundServiceBridge] Service started: $result');
      return result == true;
    } catch (e) {
      debugPrint('[ForegroundServiceBridge] Error starting service: $e');
      return false;
    }
  }

  /// Stop the foreground service
  static Future<bool> stopService() async {
    try {
      final result = await _channel.invokeMethod('stopService');
      debugPrint('[ForegroundServiceBridge] Service stopped: $result');
      return result == true;
    } catch (e) {
      debugPrint('[ForegroundServiceBridge] Error stopping service: $e');
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
      debugPrint('[ForegroundServiceBridge] Error updating notification: $e');
      return false;
    }
  }

  /// Check if the service is currently running
  static Future<bool> isServiceRunning() async {
    try {
      final result = await _channel.invokeMethod('isServiceRunning');
      return result == true;
    } catch (e) {
      debugPrint('[ForegroundServiceBridge] Error checking service: $e');
      return false;
    }
  }

  /// Check if live notification is enabled in preferences
  static Future<bool> isEnabled() async {
    try {
      final result = await _channel.invokeMethod('isEnabled');
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// Set enabled state in preferences
  static Future<bool> setEnabled(bool enabled) async {
    try {
      final result = await _channel.invokeMethod('setEnabled', {
        'enabled': enabled,
      });
      return result == true;
    } catch (e) {
      return false;
    }
  }
}

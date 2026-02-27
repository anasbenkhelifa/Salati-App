import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service for managing Adhan alarm scheduling via platform channel.
/// Uses Android AlarmManager with setExactAndAllowWhileIdle() for reliable
/// alarm firing even in Doze mode.
class AdhanAlarmService {
  static const _channel = MethodChannel('com.example.adhan_app/alarm');

  /// Schedule all remaining prayer alarms for today from cached prayer times.
  /// Call this after:
  /// - App startup (if cache exists)
  /// - Prayer times refresh
  /// - User enables live notification
  static Future<void> scheduleAllAlarms() async {
    try {
      await _channel.invokeMethod('scheduleAllAlarms');
      debugPrint('[AdhanAlarmService] All alarms scheduled');
    } catch (e) {
      debugPrint('[AdhanAlarmService] Error scheduling alarms: $e');
    }
  }

  /// Cancel all scheduled prayer alarms.
  static Future<void> cancelAllAlarms() async {
    try {
      await _channel.invokeMethod('cancelAllAlarms');
      debugPrint('[AdhanAlarmService] All alarms cancelled');
    } catch (e) {
      debugPrint('[AdhanAlarmService] Error cancelling alarms: $e');
    }
  }

  /// Reschedule alarms from cache (typically called after boot/time change).
  static Future<void> rescheduleFromCache() async {
    try {
      await _channel.invokeMethod('rescheduleFromCache');
      debugPrint('[AdhanAlarmService] Alarms rescheduled from cache');
    } catch (e) {
      debugPrint('[AdhanAlarmService] Error rescheduling: $e');
    }
  }

  /// Cancel all alarms and reschedule them (for when settings like pre-adhan change).
  static Future<void> rescheduleAllAlarms() async {
    try {
      await cancelAllAlarms();
      await scheduleAllAlarms();
      debugPrint('[AdhanAlarmService] All alarms rescheduled');
    } catch (e) {
      debugPrint('[AdhanAlarmService] Error rescheduling all: $e');
    }
  }

  /// Check if exact alarms are allowed (Android 12+ requires permission).
  static Future<bool> isExactAlarmAllowed() async {
    try {
      final result = await _channel.invokeMethod<bool>('isExactAlarmAllowed');
      return result ?? false;
    } catch (e) {
      debugPrint('[AdhanAlarmService] Error checking permission: $e');
      return false;
    }
  }

  /// Open system settings for exact alarm permission (Android 12+).
  /// Returns true if settings opened, false if not needed.
  static Future<bool> openExactAlarmSettings() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'openExactAlarmSettings',
      );
      return result ?? false;
    } catch (e) {
      debugPrint('[AdhanAlarmService] Error opening settings: $e');
      return false;
    }
  }

  /// Open battery optimization settings.
  static Future<void> openBatterySettings() async {
    try {
      await _channel.invokeMethod('openBatterySettings');
    } catch (e) {
      debugPrint('[AdhanAlarmService] Error opening battery settings: $e');
    }
  }
}

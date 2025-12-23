import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import 'alert_mode_service.dart';

/// Service responsible for playing Adhan audio and triggering vibration
/// based on the per-prayer AlertMode setting.
///
/// Uses native Android MediaPlayer for reliable playback when app is backgrounded.
class AdhanPlaybackService {
  static final AdhanPlaybackService _instance =
      AdhanPlaybackService._internal();
  factory AdhanPlaybackService() => _instance;
  AdhanPlaybackService._internal();

  static const _channel = MethodChannel('com.example.adhan_app/adhan');

  final AlertModeService _alertModeService = AlertModeService();

  // Track the last triggered prayer to avoid duplicate triggers
  String? _lastTriggeredPrayer;
  DateTime? _lastTriggeredDate;

  /// Initialize the service
  Future<void> initialize() async {
    debugPrint('[AdhanPlaybackService] Initialized');
  }

  /// Dispose resources
  Future<void> dispose() async {
    debugPrint('[AdhanPlaybackService] Disposed');
  }

  /// Trigger Adhan playback or vibration based on the alert mode for the given prayer
  ///
  /// [prayerKey] - The prayer key (fajr, dhuhr, asr, maghrib, isha)
  /// [prayerDateTime] - The exact DateTime of this prayer (used to prevent duplicate triggers)
  /// [prayerName] - Localized prayer name for notification
  /// [prayerTimeFormatted] - Formatted prayer time string for notification
  /// [isArabic] - Whether to use Arabic labels
  ///
  /// Returns true if a trigger was executed, false if skipped
  Future<bool> triggerForPrayer(
    String prayerKey,
    DateTime prayerDateTime, {
    String? prayerName,
    String? prayerTimeFormatted,
    bool isArabic = false,
  }) async {
    // Prevent duplicate triggers for the same prayer on the same date
    final today = DateTime(
      prayerDateTime.year,
      prayerDateTime.month,
      prayerDateTime.day,
    );
    if (_lastTriggeredPrayer == prayerKey &&
        _lastTriggeredDate != null &&
        _lastTriggeredDate!.year == today.year &&
        _lastTriggeredDate!.month == today.month &&
        _lastTriggeredDate!.day == today.day) {
      debugPrint(
        '[AdhanPlaybackService] Skipping $prayerKey - already triggered today',
      );
      return false;
    }

    // Get the alert mode for this prayer
    final mode = await _alertModeService.getAlertMode(prayerKey);
    debugPrint('[AdhanPlaybackService] Triggering $prayerKey with mode: $mode');

    // Mark as triggered
    _lastTriggeredPrayer = prayerKey;
    _lastTriggeredDate = today;

    switch (mode) {
      case AlertMode.sound:
        await _playAdhanNative(
          prayerName: prayerName ?? _getPrayerName(prayerKey, isArabic),
          prayerTime: prayerTimeFormatted ?? '',
          isArabic: isArabic,
        );
        return true;
      case AlertMode.vibrate:
        await _vibrateOnly();
        return true;
      case AlertMode.silent:
        debugPrint('[AdhanPlaybackService] Silent mode - no action');
        return false;
    }
  }

  /// Get localized prayer name
  String _getPrayerName(String prayerKey, bool isArabic) {
    const namesEn = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    const namesAr = ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'];
    const keys = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];

    final index = keys.indexOf(prayerKey);
    if (index >= 0) {
      return isArabic ? namesAr[index] : namesEn[index];
    }
    return prayerKey;
  }

  /// Play Adhan via native Android MediaPlayer
  Future<void> _playAdhanNative({
    required String prayerName,
    required String prayerTime,
    required bool isArabic,
  }) async {
    try {
      await _channel.invokeMethod('playAdhan', {
        'prayerName': prayerName,
        'prayerTime': prayerTime,
        'isArabic': isArabic,
      });
      debugPrint('[AdhanPlaybackService] Native playAdhan called');
    } catch (e) {
      debugPrint('[AdhanPlaybackService] Error calling native playAdhan: $e');
    }
  }

  /// Vibrate only (no sound)
  Future<void> _vibrateOnly() async {
    try {
      final hasVibrator = await Vibration.hasVibrator() ?? false;
      if (!hasVibrator) {
        debugPrint('[AdhanPlaybackService] Device has no vibrator');
        return;
      }

      final hasAmplitudeControl =
          await Vibration.hasAmplitudeControl() ?? false;

      if (hasAmplitudeControl) {
        await Vibration.vibrate(
          pattern: [0, 500, 200, 500, 200, 500],
          intensities: [0, 255, 0, 255, 0, 255],
        );
      } else {
        await Vibration.vibrate(pattern: [0, 500, 200, 500, 200, 500]);
      }

      debugPrint('[AdhanPlaybackService] Vibration triggered');
    } catch (e) {
      debugPrint('[AdhanPlaybackService] Error vibrating: $e');
    }
  }

  /// Stop any currently playing Adhan
  Future<void> stopAdhan() async {
    try {
      await _channel.invokeMethod('stopAdhan');
      debugPrint('[AdhanPlaybackService] Adhan stopped');
    } catch (e) {
      debugPrint('[AdhanPlaybackService] Error stopping Adhan: $e');
    }
  }

  /// Reset the trigger guard (used when a new day starts or for debug)
  void resetTriggerGuard() {
    _lastTriggeredPrayer = null;
    _lastTriggeredDate = null;
    debugPrint('[AdhanPlaybackService] Trigger guard reset');
  }

  /// Check if Adhan is currently playing (via native)
  Future<bool> get isPlaying async {
    try {
      final result = await _channel.invokeMethod<bool>('isAdhanPlaying');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }
}

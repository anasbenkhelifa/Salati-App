import 'package:flutter/foundation.dart';

/// Centralized logging utility for the Salati App.
///
/// Wraps [debugPrint] with log-level support and a consistent tag format.
/// All output is suppressed in release builds via [kDebugMode].
///
/// Usage:
/// ```dart
/// AppLogger.info('PrayerService', 'Fetched prayer times');
/// AppLogger.warning('Cache', 'Stale data detected');
/// AppLogger.error('Location', 'GPS unavailable', error: e);
/// ```
class AppLogger {
  AppLogger._();

  /// Log an informational message (debug builds only).
  static void info(String tag, String message) {
    if (kDebugMode) {
      debugPrint('[$tag] $message');
    }
  }

  /// Log a warning message (debug builds only).
  static void warning(String tag, String message) {
    if (kDebugMode) {
      debugPrint('[⚠ $tag] $message');
    }
  }

  /// Log an error message with optional error and stack trace (debug builds only).
  static void error(String tag, String message, {Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      debugPrint('[❌ $tag] $message');
      if (error != null) {
        debugPrint('[❌ $tag] Error: $error');
      }
      if (stackTrace != null) {
        debugPrint('[❌ $tag] StackTrace: $stackTrace');
      }
    }
  }
}

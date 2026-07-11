import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Result of an update check.
class UpdateInfo {
  /// A newer version is available.
  final bool available;

  /// Installed version is below the minimum supported — the update must be
  /// applied (dialog is non-dismissible).
  final bool forced;

  /// Optional "what's new" text from Remote Config.
  final String changelog;

  const UpdateInfo({
    required this.available,
    required this.forced,
    required this.changelog,
  });

  static const none = UpdateInfo(available: false, forced: false, changelog: '');
}

/// Remote-Config-driven update + feature-flag layer. One fetch powers:
///  - update availability + forced (min-version) gating
///  - the APK download URL and changelog
///  - remote feature flags (kill-switches) so a feature can be turned off
///    without shipping a new APK
class UpdateService {
  static const String _latestVersionKey = 'latest_version';
  static const String _minVersionKey = 'min_supported_version';
  static const String _apkUrlKey = 'apk_download_url';
  static const String _changelogKey = 'update_changelog';
  static const String _apkSha256Key = 'apk_sha256';

  static const String _defaultApkUrl =
      'https://pub-01160e77f7394a43946f810025efb70d.r2.dev/Salati.apk';

  static bool _ready = false;

  /// Fetch + activate Remote Config once per session. Safe to call often.
  static Future<void> ensureFetched() async {
    if (_ready) return;
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: const Duration(hours: 1),
        ),
      );
      await rc.setDefaults(const <String, dynamic>{
        _latestVersionKey: '1.0.0',
        _minVersionKey: '0.0.0',
        _apkUrlKey: _defaultApkUrl,
        _changelogKey: '',
        _apkSha256Key: '',
      });
      await rc.fetchAndActivate();
      _ready = true;
    } catch (e) {
      debugPrint('[UpdateService] Remote Config fetch failed: $e');
    }
  }

  /// Direct APK download URL (Remote Config, falling back to the R2 mirror).
  static String getApkUrl() {
    try {
      final url = FirebaseRemoteConfig.instance.getString(_apkUrlKey).trim();
      return url.isNotEmpty ? url : _defaultApkUrl;
    } catch (_) {
      return _defaultApkUrl;
    }
  }

  /// Expected SHA-256 of the update APK (hex, from Remote Config). Empty when
  /// not configured — callers then skip the integrity check.
  static String getApkSha256() {
    try {
      return FirebaseRemoteConfig.instance.getString(_apkSha256Key).trim();
    } catch (_) {
      return '';
    }
  }

  /// Remote feature kill-switch. Reads RC bool `feature_<name>`; returns
  /// [defaultValue] when the param is missing — so a flag is only ever an
  /// override, never a hard dependency.
  static bool isFeatureEnabled(String name, {bool defaultValue = true}) {
    try {
      final rc = FirebaseRemoteConfig.instance;
      final all = rc.getAll();
      final key = 'feature_$name';
      if (!all.containsKey(key)) return defaultValue;
      return rc.getBool(key);
    } catch (_) {
      return defaultValue;
    }
  }

  /// Full update check: availability, forced gating, changelog.
  static Future<UpdateInfo> checkForUpdate() async {
    try {
      await ensureFetched();
      final rc = FirebaseRemoteConfig.instance;

      final latest = rc.getString(_latestVersionKey).trim();
      final minVer = rc.getString(_minVersionKey).trim();
      final changelog = rc.getString(_changelogKey).trim();
      if (latest.isEmpty) return UpdateInfo.none;

      final current = (await PackageInfo.fromPlatform()).version.trim();

      final available =
          _isNewer(remote: latest, installed: current);
      final forced = minVer.isNotEmpty &&
          minVer != '0.0.0' &&
          _isNewer(remote: minVer, installed: current);

      return UpdateInfo(
        available: available || forced,
        forced: forced,
        changelog: changelog,
      );
    } catch (e) {
      debugPrint('[UpdateService] Update check failed: $e');
      return UpdateInfo.none;
    }
  }

  /// Backward-compatible boolean check.
  static Future<bool> isUpdateAvailable() async =>
      (await checkForUpdate()).available;

  static bool _isNewer({
    required String remote,
    required String installed,
  }) {
    final r = remote.split('.');
    final i = installed.split('.');
    final n = r.length > i.length ? r.length : i.length;
    for (int k = 0; k < n; k++) {
      final rp = k < r.length ? int.tryParse(_digitsOnly(r[k])) ?? 0 : 0;
      final ip = k < i.length ? int.tryParse(_digitsOnly(i[k])) ?? 0 : 0;
      if (rp > ip) return true;
      if (rp < ip) return false;
    }
    return false;
  }

  static String _digitsOnly(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      if (ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57) {
        buffer.write(ch);
      }
    }
    return buffer.toString();
  }
}

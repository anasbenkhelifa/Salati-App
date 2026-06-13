import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateService {
  static const String _latestVersionKey = 'latest_version';
  static const String _apkUrlKey = 'apk_download_url';

  /// Direct APK download URL from Remote Config (falls back to Cloudflare R2 URL
  /// if not configured).
  static String getApkUrl() {
    const defaultUrl = 'https://pub-01160e77f7394a43946f810025efb70d.r2.dev/Salati.apk';
    try {
      final url = FirebaseRemoteConfig.instance.getString(_apkUrlKey).trim();
      return url.isNotEmpty ? url : defaultUrl;
    } catch (_) {
      return defaultUrl;
    }
  }

  static Future<bool> isUpdateAvailable() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;

      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: const Duration(hours: 1),
        ),
      );

      await remoteConfig.setDefaults(const <String, dynamic>{
        _latestVersionKey: '1.0.0',
        _apkUrlKey: 'https://pub-01160e77f7394a43946f810025efb70d.r2.dev/Salati.apk',
      });

      await remoteConfig.fetchAndActivate();

      final latestVersion = remoteConfig.getString(_latestVersionKey).trim();
      if (latestVersion.isEmpty) {
        return false;
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version.trim();

      return _isRemoteVersionNewer(
        remoteVersion: latestVersion,
        installedVersion: currentVersion,
      );
    } catch (e) {
      debugPrint('[UpdateService] Update check failed: $e');
      return false;
    }
  }

  static bool _isRemoteVersionNewer({
    required String remoteVersion,
    required String installedVersion,
  }) {
    final remoteSegments = remoteVersion.split('.');
    final installedSegments = installedVersion.split('.');
    final maxLength =
        remoteSegments.length > installedSegments.length
            ? remoteSegments.length
            : installedSegments.length;

    for (int i = 0; i < maxLength; i++) {
      final remotePart =
          i < remoteSegments.length
              ? int.tryParse(_digitsOnly(remoteSegments[i])) ?? 0
              : 0;
      final installedPart =
          i < installedSegments.length
              ? int.tryParse(_digitsOnly(installedSegments[i])) ?? 0
              : 0;

      if (remotePart > installedPart) {
        return true;
      }
      if (remotePart < installedPart) {
        return false;
      }
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

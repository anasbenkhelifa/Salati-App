import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Self-update for sideloaded installs: downloads the new APK in-app and
/// hands it to Android's system installer (the one OS confirmation dialog
/// is mandatory and cannot be skipped).
class ApkUpdateService {
  static const _channel = MethodChannel('com.example.adhan_app/updater');

  /// Whether the app may launch APK installs (Android 8+ per-app setting).
  static Future<bool> canRequestPackageInstalls() async {
    try {
      return await _channel.invokeMethod<bool>('canRequestPackageInstalls') ??
          false;
    } catch (e) {
      debugPrint('[ApkUpdateService] canRequestPackageInstalls failed: $e');
      return false;
    }
  }

  /// Opens the system "install unknown apps" page for this app.
  static Future<void> openInstallPermissionSettings() async {
    try {
      await _channel.invokeMethod('openInstallPermissionSettings');
    } catch (e) {
      debugPrint('[ApkUpdateService] openInstallPermissionSettings: $e');
    }
  }

  /// Streams the APK to app storage, reporting progress 0..1.
  /// Returns the file path, or null on failure.
  static Future<String?> downloadApk(
    String url,
    void Function(double progress) onProgress,
  ) async {
    final client = http.Client();
    IOSink? sink;
    try {
      final dir = await getApplicationSupportDirectory();
      final updatesDir = Directory('${dir.path}/updates');
      if (!updatesDir.existsSync()) {
        updatesDir.createSync(recursive: true);
      }
      final file = File('${updatesDir.path}/salati_update.apk');
      if (file.existsSync()) file.deleteSync();

      final response = await client.send(http.Request('GET', Uri.parse(url)));
      if (response.statusCode != 200) {
        debugPrint('[ApkUpdateService] HTTP ${response.statusCode}');
        return null;
      }

      final total = response.contentLength ?? 0;
      var received = 0;
      sink = file.openWrite();
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress(received / total);
      }
      await sink.flush();
      await sink.close();
      sink = null;

      debugPrint('[ApkUpdateService] Downloaded ${file.lengthSync()} bytes');
      return file.path;
    } catch (e) {
      debugPrint('[ApkUpdateService] Download failed: $e');
      try {
        await sink?.close();
      } catch (_) {}
      return null;
    } finally {
      client.close();
    }
  }

  /// Verifies the downloaded file's SHA-256 against [expectedHex] (from Remote
  /// Config). Returns true when [expectedHex] is empty (check not configured)
  /// or matches. A mismatch means a corrupted or tampered download — never
  /// install it. Android's installer also rejects an APK not signed with the
  /// app's key, so this is fail-fast defense-in-depth.
  static Future<bool> verifySha256(String path, String expectedHex) async {
    final expected = expectedHex.trim().toLowerCase();
    if (expected.isEmpty) return true;
    try {
      final bytes = await File(path).readAsBytes();
      final actual = sha256.convert(bytes).toString();
      final ok = actual == expected;
      if (!ok) {
        debugPrint('[ApkUpdateService] SHA-256 mismatch: '
            'expected $expected got $actual');
      }
      return ok;
    } catch (e) {
      debugPrint('[ApkUpdateService] SHA-256 check failed: $e');
      return false;
    }
  }

  /// Hands the APK to the system installer.
  static Future<bool> installApk(String path) async {
    try {
      return await _channel
              .invokeMethod<bool>('installApk', {'path': path}) ??
          false;
    } catch (e) {
      debugPrint('[ApkUpdateService] installApk failed: $e');
      return false;
    }
  }
}

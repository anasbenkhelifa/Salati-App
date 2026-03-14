import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

class RatingService {
  // Singleton instance
  static final RatingService _instance = RatingService._internal();
  static RatingService get instance => _instance;

  RatingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Submits the rating and comment to Cloud Firestore and logs to Analytics.
  Future<void> submitRating({
    required int stars,
    required String comment,
  }) async {
    try {
      // Gather App Version
      String appVersion = 'unknown';
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
      } catch (e) {
        debugPrint('[RatingService] Failed to get PackageInfo: $e');
      }

      // Gather Device Model
      String deviceModel = 'unknown';
      try {
        final deviceInfo = DeviceInfoPlugin();
        if (Platform.isAndroid) {
          final androidInfo = await deviceInfo.androidInfo;
          deviceModel = '${androidInfo.manufacturer} ${androidInfo.model}';
        } else if (Platform.isIOS) {
          final iosInfo = await deviceInfo.iosInfo;
          deviceModel = iosInfo.utsname.machine;
        }
      } catch (e) {
        debugPrint('[RatingService] Failed to get DeviceInfo: $e');
      }

      final platformName = Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'other');

      // Save to Firestore (with timeout to prevent infinite hang)
      await _firestore.collection('ratings').add({
        'stars': stars,
        'comment': comment.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'platform': platformName,
        'appVersion': appVersion,
        'deviceModel': deviceModel,
      }).timeout(const Duration(seconds: 10));

      // Log to Firebase Analytics
      await _analytics.logEvent(
        name: 'app_rated',
        parameters: {
          'stars': stars,
        },
      );
      
      debugPrint('[RatingService] Successfully submitted $stars-star rating.');
    } catch (e) {
      debugPrint('[RatingService] Exception submitting rating: $e');
      throw Exception('Failed to submit rating: $e');
    }
  }
}

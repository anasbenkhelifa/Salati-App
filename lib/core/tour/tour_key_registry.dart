import 'package:flutter/material.dart';

/// Singleton registry of GlobalKeys for the guided app tour.
/// Each screen registers its keys in initState().
/// The tour service reads them here to build TargetFocus steps.
class TourKeyRegistry {
  TourKeyRegistry._();
  static final TourKeyRegistry instance = TourKeyRegistry._();

  // Qibla page
  final GlobalKey compassDialKey = GlobalKey(debugLabel: 'tour_compass');

  // Home page
  final GlobalKey prayerDashboardKey = GlobalKey(debugLabel: 'tour_dashboard');
  final GlobalKey hijriChipKey = GlobalKey(debugLabel: 'tour_hijri_chip');

  // Prayer Times page
  final GlobalKey locationHeaderKey = GlobalKey(debugLabel: 'tour_location');
  final GlobalKey prayerAlertModeKey = GlobalKey(debugLabel: 'tour_alert_mode');
  final GlobalKey prayerCardKey = GlobalKey(debugLabel: 'tour_prayer_card');

  // Settings page
  final GlobalKey controlsTileKey = GlobalKey(debugLabel: 'tour_controls');
  final GlobalKey themeTileKey = GlobalKey(debugLabel: 'tour_theme');
  final GlobalKey languageTileKey = GlobalKey(debugLabel: 'tour_language');
}

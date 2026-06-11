import 'package:flutter/animation.dart';

/// Centralized motion tokens — every animation in the app should use these
/// so the whole UI moves with one consistent rhythm.
///
/// Rule of thumb:
///  - [tap]      press feedback, icon swaps
///  - [fast]     small element transitions (chips, toggles)
///  - [normal]   card/page element entrances, indicator slides
///  - [slow]     large surface changes (theme crossfade, hero moments)
///  - [ambient]  background drift cycles (seconds, not millis)
class AppMotion {
  AppMotion._();

  // ===== Durations =====
  static const Duration tap = Duration(milliseconds: 120);
  static const Duration fast = Duration(milliseconds: 250);
  static const Duration normal = Duration(milliseconds: 400);
  static const Duration slow = Duration(milliseconds: 700);

  /// Full cycle of the ambient background drift (lattice + aurora).
  static const Duration ambient = Duration(seconds: 24);

  // ===== Curves =====
  /// Entrances: fast start, gentle settle.
  static const Curve enter = Curves.easeOutCubic;

  /// Exits: gentle start, fast end.
  static const Curve exit = Curves.easeInCubic;

  /// Playful pop for small elements (slight overshoot).
  static const Curve pop = Curves.easeOutBack;

  /// Indicator slides / nav morph (pronounced glide).
  static const Curve glide = Curves.easeOutQuint;

  /// Symmetric in-out for looping/breathing animations.
  static const Curve breathe = Curves.easeInOut;

  // ===== Stagger =====
  /// Delay between cascading list/card entrances.
  static const Duration staggerStep = Duration(milliseconds: 40);
}

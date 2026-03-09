import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/app_locale_provider.dart';
import '../../domain/providers/prayer_times_api_provider.dart';
import 'tour_key_registry.dart';

/// Guided app tour service.
/// Handles page navigation timing, data readiness, and tour state persistence.
class AppTourService {
  static const _prefKey = 'tour_completed';
  static bool _isRunning = false;

  /// Whether the tour is currently active (used by AppShell for PopScope).
  static bool get isRunning => _isRunning;

  /// Show the tour only if the user hasn't completed it before.
  static Future<void> showTourIfFirstTime(
    BuildContext context,
    PageController pageController,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefKey) == true) return;

    // Wait for prayer data to be ready (max 5 seconds)
    final provider = PrayerTimesApiProvider.instance;
    int waited = 0;
    while (provider.response == null && waited < 5000) {
      await Future.delayed(const Duration(milliseconds: 250));
      waited += 250;
    }

    // Additional 1500ms delay for UI to fully settle
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!context.mounted) return;

    await _showTour(context, pageController);
  }

  /// Force-show the tour (for "Replay Tour" button).
  static Future<void> replayTour(
    BuildContext context,
    PageController pageController,
  ) async {
    await resetTour();
    if (!context.mounted) return;
    await _showTour(context, pageController);
  }

  /// Reset the tour flag so it can be shown again.
  static Future<void> resetTour() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, false);
  }

  /// Mark tour as completed.
  static Future<void> _markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
  }

  /// Navigate to a page and wait for the animation + widget build.
  static Future<void> _navigateToPage(
    PageController controller,
    int page,
  ) async {
    if (controller.page?.round() == page) return;
    await controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
    // 500ms delay for the target widgets to build after page animation
    await Future.delayed(const Duration(milliseconds: 500));
  }

  static Future<void> _showTour(
    BuildContext context,
    PageController pageController,
  ) async {
    _isRunning = true;
    final keys = TourKeyRegistry.instance;
    final isArabic = AppLocaleProvider.of(context).isArabic;

    // ── Step 1: Qibla Compass ──
    await _navigateToPage(pageController, 0);
    if (!context.mounted) { _isRunning = false; return; }

    await _showSingleStep(
      context,
      key: keys.compassDialKey,
      title: isArabic ? 'بوصلة القبلة' : 'Qibla Compass',
      description: isArabic
          ? 'وجّه هاتفك للعثور على اتجاه مكة. يهتز الهاتف عند المحاذاة.'
          : 'Point your phone to find Mecca. It vibrates when aligned.',
      contentAlign: ContentAlign.bottom,
    );

    // ── Step 2: Home Dashboard ──
    await _navigateToPage(pageController, 1);
    if (!context.mounted) { _isRunning = false; return; }

    await _showSingleStep(
      context,
      key: keys.prayerDashboardKey,
      title: isArabic ? 'لوحة الصلاة' : 'Prayer Dashboard',
      description: isArabic
          ? 'يعرض الصلاة القادمة والعد التنازلي الحي لها.'
          : 'Shows the next prayer and a live countdown.',
      contentAlign: ContentAlign.top,
    );

    // ── Step 3: Location Header ──
    await _navigateToPage(pageController, 2);
    if (!context.mounted) { _isRunning = false; return; }

    await _showSingleStep(
      context,
      key: keys.locationHeaderKey,
      title: isArabic ? 'الموقع' : 'Your Location',
      description: isArabic
          ? 'اضغط للبحث عن أي مدينة يدوياً، أو اضغط أيقونة GPS للتحديد التلقائي.'
          : 'Tap to search any city manually, or press the GPS icon to auto-detect.',
      contentAlign: ContentAlign.bottom,
    );

    // ── Step 4: Alert Mode Toggle ──
    if (!context.mounted) { _isRunning = false; return; }

    await _showSingleStep(
      context,
      key: keys.prayerAlertModeKey,
      title: isArabic ? 'وضع التنبيه' : 'Alert Mode',
      description: isArabic
          ? 'اضغط هنا للتبديل بين صوت / اهتزاز / صامت لكل صلاة.'
          : 'Tap here to toggle Sound / Vibrate / Silent for each prayer.',
      contentAlign: ContentAlign.bottom,
    );

    // ── Step 5: Custom Adhan Selection ──
    if (!context.mounted) { _isRunning = false; return; }

    await _showSingleStep(
      context,
      key: keys.prayerCardKey,
      title: isArabic ? 'أذان مخصص' : 'Custom Adhan',
      description: isArabic
          ? 'اضغط على أي صلاة لاختيار صوت أذان مخصص لها.'
          : 'Tap any prayer to pick a custom Adhan sound for it.',
      contentAlign: ContentAlign.bottom,
    );

    // ── Step 6: Controls Tile ──
    await _navigateToPage(pageController, 3);
    if (!context.mounted) { _isRunning = false; return; }

    await _showSingleStep(
      context,
      key: keys.controlsTileKey,
      title: isArabic ? 'لوحة التحكم' : 'Controls',
      description: isArabic
          ? 'افتح لتعديل الإشعارات، الاهتزاز، وإعدادات أخرى.'
          : 'Open to adjust notifications, haptics, and more.',
      contentAlign: ContentAlign.bottom,
    );

    // ── Step 7: Theme Tile ──
    if (!context.mounted) { _isRunning = false; return; }

    await _showSingleStep(
      context,
      key: keys.themeTileKey,
      title: isArabic ? 'المظهر' : 'App Theme',
      description: isArabic
          ? 'اختر بين الوضع الليلي، الفاتح، الإسلامي، أو الإصدار الخاص.'
          : 'Choose Night, Light, Islamic, or Special Edition.',
      contentAlign: ContentAlign.bottom,
    );

    // ── Step 8: Language Tile ──
    if (!context.mounted) { _isRunning = false; return; }

    await _showSingleStep(
      context,
      key: keys.languageTileKey,
      title: isArabic ? 'اللغة' : 'Language',
      description: isArabic
          ? 'بدّل بين العربية والإنجليزية فوراً.'
          : 'Switch between English and Arabic instantly.',
      contentAlign: ContentAlign.bottom,
    );

    // Tour complete — navigate back to Home and persist
    await _navigateToPage(pageController, 1);
    await _markCompleted();
    _isRunning = false;
  }

  /// Show a single coach mark step and wait for the user to tap to dismiss.
  static Future<void> _showSingleStep(
    BuildContext context, {
    required GlobalKey key,
    required String title,
    required String description,
    ContentAlign contentAlign = ContentAlign.bottom,
  }) async {
    // Guard: if the key's widget isn't mounted, skip this step
    if (key.currentContext == null) return;

    final completer = Completer<void>();

    final tutorial = TutorialCoachMark(
      targets: [
        TargetFocus(
          identify: key.toString(),
          keyTarget: key,
          alignSkip: Alignment.topRight,
          enableOverlayTab: true,
          enableTargetTab: true,
          shape: ShapeLightFocus.RRect,
          radius: 20,
          paddingFocus: 8,
          contents: [
            TargetContent(
              align: contentAlign,
              builder: (context, controller) {
                return _buildTooltipCard(title, description);
              },
            ),
          ],
        ),
      ],
      colorShadow: Colors.black,
      opacityShadow: 0.75,
      hideSkip: true,
      onFinish: () {
        if (!completer.isCompleted) completer.complete();
      },
      onClickTarget: (target) {
        if (!completer.isCompleted) completer.complete();
      },
      onClickOverlay: (target) {
        if (!completer.isCompleted) completer.complete();
      },
      onSkip: () {
        if (!completer.isCompleted) completer.complete();
        return true;
      },
    );

    tutorial.show(context: context);
    await completer.future;
    // Small delay between steps for smooth feel
    await Future.delayed(const Duration(milliseconds: 300));
  }

  /// Frosted glass tooltip card matching the app's aesthetic.
  static Widget _buildTooltipCard(String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 15,
                    height: 1.4,
                    decoration: TextDecoration.none,
                    fontWeight: FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '↓ Tap anywhere to continue',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    decoration: TextDecoration.none,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

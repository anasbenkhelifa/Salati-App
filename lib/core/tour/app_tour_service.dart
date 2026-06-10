import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/app_locale_provider.dart';
import '../../domain/providers/prayer_times_api_provider.dart';
import '../../presentation/screens/controls_screen.dart';
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

    // Wait for prayer data initialization to complete (max 10 seconds)
    // We wait for the state to leave 'loading' — not just for response != null
    final provider = PrayerTimesApiProvider.instance;
    int waited = 0;
    while (provider.state == PrayerDataState.loading && waited < 10000) {
      await Future.delayed(const Duration(milliseconds: 250));
      waited += 250;
    }

    // If setup failed (GPS off, permission denied, error) — DO NOT show tour.
    // The tour depends on fully rendered widgets that only exist when data is loaded.
    if (provider.state != PrayerDataState.success &&
        provider.state != PrayerDataState.offline) {
      debugPrint(
        '[AppTourService] Skipping tour — provider state: ${provider.state}',
      );
      return;
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

  /// Get localized text for 3 languages
  static String _l(
    String lang, {
    required String ar,
    required String fr,
    required String en,
  }) {
    if (lang == 'ar') return ar;
    if (lang == 'fr') return fr;
    return en;
  }

  static Future<void> _showTour(
    BuildContext context,
    PageController pageController,
  ) async {
    _isRunning = true;
    final keys = TourKeyRegistry.instance;
    final lang = AppLocaleProvider.of(context).locale.languageCode;

    // ── Step 1: Qibla Compass ──
    await _navigateToPage(pageController, 0);
    if (!context.mounted || !_isRunning) {
      _isRunning = false;
      return;
    }

    await _showSingleStep(
      context,
      key: keys.compassDialKey,
      title: _l(
        lang,
        ar: 'بوصلة القبلة',
        fr: 'Boussole Qibla',
        en: 'Qibla Compass',
      ),
      description: _l(
        lang,
        ar: 'وجّه هاتفك للعثور على اتجاه مكة. يهتز الهاتف عند المحاذاة.',
        fr:
            'Orientez votre téléphone vers La Mecque. Il vibre quand il est aligné.',
        en: 'Point your phone to find Mecca. It vibrates when aligned.',
      ),
      contentAlign: ContentAlign.bottom,
      lang: lang,
    );

    // ── Step 2: Home Dashboard ──
    await _navigateToPage(pageController, 1);
    if (!context.mounted || !_isRunning) {
      _isRunning = false;
      return;
    }

    await _showSingleStep(
      context,
      key: keys.prayerDashboardKey,
      title: _l(
        lang,
        ar: 'لوحة الصلاة',
        fr: 'Tableau de Prière',
        en: 'Prayer Dashboard',
      ),
      description: _l(
        lang,
        ar: 'يعرض الصلاة القادمة والعد التنازلي الحي لها.',
        fr: 'Affiche la prochaine prière et un compte à rebours en direct.',
        en: 'Shows the next prayer and a live countdown.',
      ),
      contentAlign: ContentAlign.top,
      lang: lang,
    );

    // ── Step 3: Location Header ──
    await _navigateToPage(pageController, 2);
    if (!context.mounted || !_isRunning) {
      _isRunning = false;
      return;
    }

    await _showSingleStep(
      context,
      key: keys.locationHeaderKey,
      title: _l(lang, ar: 'الموقع', fr: 'Votre Position', en: 'Your Location'),
      description: _l(
        lang,
        ar: 'اضغط للبحث عن أي مدينة يدوياً، أو اضغط أيقونة GPS للتحديد التلقائي.',
        fr:
            'Appuyez pour chercher une ville ou utilisez le GPS pour la détection auto.',
        en:
            'Tap to search any city manually, or press the GPS icon to auto-detect.',
      ),
      contentAlign: ContentAlign.bottom,
      lang: lang,
    );

    // ── Step 4: Alert Mode Toggle ──
    if (!context.mounted || !_isRunning) {
      _isRunning = false;
      return;
    }

    await _showSingleStep(
      context,
      key: keys.prayerAlertModeKey,
      title: _l(
        lang,
        ar: 'وضع التنبيه',
        fr: 'Mode d\'Alerte',
        en: 'Alert Mode',
      ),
      description: _l(
        lang,
        ar: 'اضغط هنا للتبديل بين صوت / اهتزاز / صامت لكل صلاة.',
        fr: 'Appuyez pour basculer entre Son / Vibration / Silencieux.',
        en: 'Tap here to toggle Sound / Vibrate / Silent for each prayer.',
      ),
      contentAlign: ContentAlign.bottom,
      lang: lang,
    );

    // ── Step 5: Custom Adhan Selection ──
    if (!context.mounted || !_isRunning) {
      _isRunning = false;
      return;
    }

    await _showSingleStep(
      context,
      key: keys.prayerCardKey,
      title: _l(
        lang,
        ar: 'أذان مخصص',
        fr: 'Adhan Personnalisé',
        en: 'Custom Adhan',
      ),
      description: _l(
        lang,
        ar: 'اضغط على أي صلاة لاختيار صوت أذان مخصص لها.',
        fr: 'Appuyez sur une prière pour choisir un son d\'Adhan personnalisé.',
        en: 'Tap any prayer to pick a custom Adhan sound for it.',
      ),
      contentAlign: ContentAlign.bottom,
      lang: lang,
    );

    // ── Step 6: Controls Tile ──
    await _navigateToPage(pageController, 3);
    if (!context.mounted || !_isRunning) {
      _isRunning = false;
      return;
    }

    await _showSingleStep(
      context,
      key: keys.controlsTileKey,
      title: _l(lang, ar: 'لوحة التحكم', fr: 'Contrôles', en: 'Controls'),
      description: _l(
        lang,
        ar: 'افتح لتعديل الإشعارات، الاهتزاز، وإعدادات أخرى.',
        fr: 'Ouvrez pour ajuster les notifications, vibrations, et plus.',
        en: 'Open to adjust notifications, haptics, and more.',
      ),
      contentAlign: ContentAlign.bottom,
      lang: lang,
    );

    // ── Step 7: Theme Picker (push INTO Controls screen) ──
    if (!context.mounted || !_isRunning) {
      _isRunning = false;
      return;
    }

    // Push into Controls screen
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ControlsScreen()));
    // Wait for the route to fully animate and build
    await Future.delayed(const Duration(milliseconds: 800));

    if (!context.mounted || !_isRunning) {
      _isRunning = false;
      return;
    }
    await _showSingleStep(
      context,
      key: keys.themeTileKey,
      title: _l(lang, ar: 'المظهر', fr: 'Thème', en: 'App Theme'),
      description: _l(
        lang,
        ar: 'اختر بين الوضع الليلي، الفاتح، الإسلامي، أو الإصدار الخاص.',
        fr: 'Choisissez entre Nuit, Clair, Islamique Bleu ou Vert.',
        en: 'Choose Night, Light, Islamic Blue, or Islamic Green.',
      ),
      contentAlign: ContentAlign.bottom,
      lang: lang,
    );

    // Pop back from Controls to Settings
    if (context.mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      await Future.delayed(const Duration(milliseconds: 400));
    }

    // ── Step 8: Language Tile ──
    if (!context.mounted || !_isRunning) {
      _isRunning = false;
      return;
    }

    await _showSingleStep(
      context,
      key: keys.languageTileKey,
      title: _l(lang, ar: 'اللغة', fr: 'Langue', en: 'Language'),
      description: _l(
        lang,
        ar: 'بدّل بين العربية والفرنسية والإنجليزية فوراً.',
        fr: 'Basculez entre l\'arabe, le français et l\'anglais instantanément.',
        en: 'Switch between Arabic, French, and English instantly.',
      ),
      contentAlign: ContentAlign.bottom,
      lang: lang,
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
    required String lang,
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
                return _buildTooltipCard(title, description, lang);
              },
            ),
          ],
        ),
      ],
      colorShadow: Colors.black,
      opacityShadow: 0.75,
      hideSkip: false,
      textSkip: _l(lang, ar: 'تخطي', fr: 'Passer', en: 'Skip'),
      alignSkip: Alignment.topRight,
      onSkip: () {
        _markCompleted();
        _isRunning = false;
        if (!completer.isCompleted) completer.complete();
        return true;
      },
      onFinish: () {
        if (!completer.isCompleted) completer.complete();
      },
      onClickTarget: (target) {
        if (!completer.isCompleted) completer.complete();
      },
      onClickOverlay: (target) {
        if (!completer.isCompleted) completer.complete();
      },
    );

    tutorial.show(context: context);
    await completer.future;
    // Small delay between steps for smooth feel
    await Future.delayed(const Duration(milliseconds: 300));
  }

  /// Frosted glass tooltip card matching the app's aesthetic.
  static Widget _buildTooltipCard(
    String title,
    String description,
    String lang,
  ) {
    final continueText = _l(
      lang,
      ar: '↓ اضغط في أي مكان للمتابعة',
      fr: '↓ Appuyez n\'importe où pour continuer',
      en: '↓ Tap anywhere to continue',
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
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
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 15,
                    height: 1.4,
                    decoration: TextDecoration.none,
                    fontWeight: FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  continueText,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
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

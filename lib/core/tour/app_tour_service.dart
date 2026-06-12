import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_motion.dart';
import '../../core/localization/app_locale_provider.dart';
import '../../domain/providers/prayer_times_api_provider.dart';
import '../../presentation/screens/controls_screen.dart';
import '../../presentation/widgets/hijri_calendar_sheet.dart';
import '../../presentation/widgets/prayer_log_sheet.dart';
import '../../presentation/widgets/salati_logo.dart';
import 'tour_key_registry.dart';

/// Guided app tour service.
/// Handles page navigation timing, data readiness, and tour state persistence.
///
/// Presentation: a welcome overlay, glass tooltip cards with step icons and
/// progress dots, a gradient Next button, haptic ticks between steps, and a
/// celebratory completion overlay.
class AppTourService {
  static const _prefKey = 'tour_completed';
  static bool _isRunning = false;

  /// Total spotlight steps (for the progress dots).
  static const int _totalSteps = 10;

  /// Open a sheet during the tour, let the user look at it, then close it.
  static Future<void> _demoSheet(
    BuildContext context,
    Future<void> Function(BuildContext) open,
  ) async {
    if (!context.mounted || !_isRunning) return;
    open(context); // not awaited — we close it ourselves
    await Future.delayed(const Duration(milliseconds: 2800));
    if (context.mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    await Future.delayed(const Duration(milliseconds: 350));
  }

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

    // The user may have interacted during the settle delay: close any sheet
    // or dialog they opened (tour targets would be hidden behind it) and
    // return to the home page so the spotlight finds its widgets.
    Navigator.of(context).popUntil((route) => route.isFirst);
    await _navigateToPage(pageController, 1);

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

    // ── Welcome moment ──
    final startTour = await _showIntro(context, lang);
    if (!startTour || !context.mounted) {
      await _markCompleted();
      _isRunning = false;
      return;
    }

    // ── Step 1: Qibla Compass ──
    await _navigateToPage(pageController, 0);
    if (!context.mounted || !_isRunning) {
      _isRunning = false;
      return;
    }

    await _showSingleStep(
      context,
      key: keys.compassDialKey,
      stepIndex: 0,
      icon: Icons.explore,
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
      stepIndex: 1,
      icon: Icons.access_time_filled,
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

    // ── Step 3: Hijri Calendar chip ──
    if (!context.mounted || !_isRunning) {
      _isRunning = false;
      return;
    }

    await _showSingleStep(
      context,
      key: keys.hijriChipKey,
      stepIndex: 2,
      icon: Icons.calendar_month,
      title: _l(
        lang,
        ar: 'التقويم الهجري',
        fr: 'Calendrier hégirien',
        en: 'Hijri Calendar',
      ),
      description: _l(
        lang,
        ar: 'اضغط على شارة التاريخ لفتح تقويم هجري كامل مع التاريخ الميلادي المقابل.',
        fr:
            'Touchez la date pour ouvrir un calendrier hégirien complet avec les équivalents grégoriens.',
        en:
            'Tap the date chip to open a full Hijri calendar with Gregorian equivalents.',
      ),
      contentAlign: ContentAlign.bottom,
      lang: lang,
    );

    // Show the calendar itself for a moment
    await _demoSheet(context, (c) => HijriCalendarSheet.show(c));

    // ── Step 4: Location Header ──
    await _navigateToPage(pageController, 2);
    if (!context.mounted || !_isRunning) {
      _isRunning = false;
      return;
    }

    await _showSingleStep(
      context,
      key: keys.locationHeaderKey,
      stepIndex: 3,
      icon: Icons.location_on,
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
      stepIndex: 4,
      icon: Icons.notifications_active,
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
      stepIndex: 5,
      icon: Icons.music_note,
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

    // ── Step 7: Prayer Journal ──
    if (!context.mounted || !_isRunning) {
      _isRunning = false;
      return;
    }

    await _showSingleStep(
      context,
      key: keys.journalIconKey,
      stepIndex: 6,
      icon: Icons.spa,
      title: _l(
        lang,
        ar: 'سجل الصلاة',
        fr: 'Journal de prière',
        en: 'Prayer Journal',
      ),
      description: _l(
        lang,
        ar:
            'علّم الصلوات التي أديتها، وتابع إحصاءاتك الأسبوعية وأيامك المتواصلة.',
        fr:
            'Cochez vos prières accomplies et suivez vos statistiques et votre série de jours.',
        en:
            'Mark the prayers you\'ve prayed and follow your weekly stats and streak.',
      ),
      contentAlign: ContentAlign.bottom,
      lang: lang,
    );

    // Show the journal itself for a moment
    await _demoSheet(context, (c) => PrayerLogSheet.show(c));

    // ── Step 8: Controls Tile ──
    await _navigateToPage(pageController, 3);
    if (!context.mounted || !_isRunning) {
      _isRunning = false;
      return;
    }

    await _showSingleStep(
      context,
      key: keys.controlsTileKey,
      stepIndex: 7,
      icon: Icons.tune,
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
      stepIndex: 8,
      icon: Icons.palette,
      title: _l(lang, ar: 'المظهر', fr: 'Thème', en: 'App Theme'),
      description: _l(
        lang,
        ar: 'اختر بين الوضع الليلي، الفاتح، الإسلامي، أو الإصدار الخاص.',
        fr: 'Choisissez entre Nuit, Clair, Islamique Bleu ou Vert.',
        en: 'Choose Night, Light, Islamic Blue, or Islamic Green.',
      ),
      // The theme tile sits low on the Controls screen — placing the card
      // below it pushed it half off-screen; above keeps it fully visible
      contentAlign: ContentAlign.top,
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
      stepIndex: 9,
      icon: Icons.translate,
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

    // Tour complete — navigate back to Home, celebrate, and persist
    await _navigateToPage(pageController, 1);
    await _markCompleted();
    _isRunning = false;

    if (context.mounted) {
      await _showOutro(context, lang);
    }
  }

  // ───────────────────────── Welcome / completion overlays ──────────────────

  /// Full-screen welcome moment. Returns true to start the tour.
  static Future<bool> _showIntro(BuildContext context, String lang) async {
    HapticFeedback.lightImpact();
    final result = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'tour-intro',
      barrierColor: Colors.black.withValues(alpha: 0.72),
      transitionDuration: AppMotion.normal,
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(parent: animation, curve: AppMotion.enter);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(curved), child: child),
        );
      },
      pageBuilder: (dialogContext, _, __) {
        return _OverlayCard(
          lang: lang,
          icon: Icons.mosque,
          iconWidget: const Center(child: SalatiLogo(size: 46)),
          title: _l(
            lang,
            ar: 'مرحباً بك في صلاتي',
            fr: 'Bienvenue sur Salati',
            en: 'Welcome to Salati',
          ),
          message: _l(
            lang,
            ar: 'جولة سريعة على أهم الميزات — أقل من دقيقة.',
            fr: 'Un tour rapide des fonctions clés — moins d\'une minute.',
            en: 'A quick tour of the key features — under a minute.',
          ),
          primaryLabel: _l(
            lang,
            ar: 'ابدأ الجولة',
            fr: 'Commencer',
            en: 'Start Tour',
          ),
          secondaryLabel: _l(lang, ar: 'تخطي', fr: 'Passer', en: 'Skip'),
          onPrimary: () => Navigator.of(dialogContext).pop(true),
          onSecondary: () => Navigator.of(dialogContext).pop(false),
        );
      },
    );
    return result ?? false;
  }

  /// Celebration overlay once the tour finishes. Auto-dismisses.
  static Future<void> _showOutro(BuildContext context, String lang) async {
    HapticFeedback.mediumImpact();
    Timer? autoClose;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'tour-outro',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: AppMotion.normal,
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(parent: animation, curve: AppMotion.pop);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(curved), child: child),
        );
      },
      pageBuilder: (dialogContext, _, __) {
        autoClose = Timer(const Duration(milliseconds: 2600), () {
          if (Navigator.of(dialogContext).canPop()) {
            Navigator.of(dialogContext).pop();
          }
        });
        return _OverlayCard(
          lang: lang,
          icon: Icons.check_circle,
          title: _l(
            lang,
            ar: '✨ أنت جاهز الآن',
            fr: '✨ Vous êtes prêt',
            en: '✨ You\'re all set',
          ),
          message: _l(
            lang,
            ar: 'يمكنك إعادة الجولة في أي وقت من الإعدادات.',
            fr: 'Vous pouvez revoir le tour à tout moment depuis Réglages.',
            en: 'You can replay the tour anytime from Settings.',
          ),
        );
      },
    );
    autoClose?.cancel();
  }

  /// Show a single coach mark step and wait for the user to advance.
  static Future<void> _showSingleStep(
    BuildContext context, {
    required GlobalKey key,
    required int stepIndex,
    required IconData icon,
    required String title,
    required String description,
    required String lang,
    ContentAlign contentAlign = ContentAlign.bottom,
  }) async {
    // Guard: if the key's widget isn't mounted, skip this step
    if (key.currentContext == null) return;

    HapticFeedback.selectionClick();
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
                return _buildTooltipCard(
                  stepIndex: stepIndex,
                  icon: icon,
                  title: title,
                  description: description,
                  lang: lang,
                  onNext: () => controller.next(),
                );
              },
            ),
          ],
        ),
      ],
      colorShadow: Colors.black,
      opacityShadow: 0.78,
      focusAnimationDuration: const Duration(milliseconds: 500),
      pulseAnimationDuration: const Duration(milliseconds: 1100),
      hideSkip: false,
      textSkip: _l(lang, ar: 'تخطي', fr: 'Passer', en: 'Skip'),
      textStyleSkip: TextStyle(
        color: Colors.white.withValues(alpha: 0.85),
        fontSize: 15,
        fontWeight: FontWeight.w600,
        decoration: TextDecoration.none,
      ),
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

  /// Glass tooltip card: step icon badge, progress dots, gradient Next
  /// button — entering with a slide+fade.
  static Widget _buildTooltipCard({
    required int stepIndex,
    required IconData icon,
    required String title,
    required String description,
    required String lang,
    required VoidCallback onNext,
  }) {
    final glow = AppTheme.currentActiveGlow;
    final gradient = AppTheme.currentAccentGradient;
    final onGradient =
        gradient.colors.first.computeLuminance() > 0.5
            ? Colors.black87
            : Colors.white;
    final nextLabel = stepIndex == _totalSteps - 1
        ? _l(lang, ar: 'إنهاء', fr: 'Terminer', en: 'Finish')
        : _l(lang, ar: 'التالي', fr: 'Suivant', en: 'Next');

    return Directionality(
      textDirection: lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: AppMotion.normal,
        curve: AppMotion.enter,
        builder: (context, v, child) {
          return Opacity(
            opacity: v,
            child: Transform.translate(offset: Offset(0, 20 * (1 - v)), child: child),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: glow.withValues(alpha: 0.4)),
                  boxShadow: AppTheme.glowShadow(intensity: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header: gradient icon badge + step label + title
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: gradient,
                            borderRadius: BorderRadius.circular(13),
                            boxShadow: AppTheme.glowShadow(intensity: 0.6),
                          ),
                          child: Icon(icon, color: onGradient, size: 23),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _l(
                                  lang,
                                  ar: 'خطوة ${stepIndex + 1} من $_totalSteps',
                                  fr: 'Étape ${stepIndex + 1} sur $_totalSteps',
                                  en: 'Step ${stepIndex + 1} of $_totalSteps',
                                ),
                                style: TextStyle(
                                  color: glow,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 15,
                        height: 1.45,
                        decoration: TextDecoration.none,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Footer: progress dots + Next button
                    Row(
                      children: [
                        ...List.generate(_totalSteps, (i) {
                          final active = i == stepIndex;
                          return AnimatedContainer(
                            duration: AppMotion.fast,
                            margin: const EdgeInsetsDirectional.only(end: 5),
                            width: active ? 18 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              gradient: active ? gradient : null,
                              color: active
                                  ? null
                                  : Colors.white.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                        const Spacer(),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onNext();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              gradient: gradient,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: AppTheme.glowShadow(intensity: 0.6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  nextLabel,
                                  style: TextStyle(
                                    color: onGradient,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Icon(
                                  lang == 'ar'
                                      ? Icons.arrow_back_rounded
                                      : Icons.arrow_forward_rounded,
                                  color: onGradient,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared glass overlay card used by the tour's intro and outro moments.
class _OverlayCard extends StatelessWidget {
  final String lang;
  final IconData icon;
  final Widget? iconWidget;
  final String title;
  final String message;
  final String? primaryLabel;
  final String? secondaryLabel;
  final VoidCallback? onPrimary;
  final VoidCallback? onSecondary;

  const _OverlayCard({
    required this.lang,
    required this.icon,
    this.iconWidget,
    required this.title,
    required this.message,
    this.primaryLabel,
    this.secondaryLabel,
    this.onPrimary,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final glow = AppTheme.currentActiveGlow;
    final gradient = AppTheme.currentAccentGradient;
    final onGradient = gradient.colors.first.computeLuminance() > 0.5
        ? Colors.black87
        : Colors.white;

    return Directionality(
      textDirection: lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: glow.withValues(alpha: 0.4)),
                  boxShadow: AppTheme.glowShadow(intensity: 0.7),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Glowing icon in a gradient ring
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: gradient.colors
                              .map((c) => c.withValues(alpha: 0.25))
                              .toList(),
                        ),
                        border: Border.all(
                          color: glow.withValues(alpha: 0.6),
                          width: 1.5,
                        ),
                        boxShadow: AppTheme.glowShadow(intensity: 0.9),
                      ),
                      child: iconWidget ??
                          Icon(icon, color: glow, size: 40),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 15,
                        height: 1.5,
                        decoration: TextDecoration.none,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    if (primaryLabel != null) ...[
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onPrimary?.call();
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: gradient,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: AppTheme.glowShadow(intensity: 0.8),
                          ),
                          child: Center(
                            child: Text(
                              primaryLabel!,
                              style: TextStyle(
                                color: onGradient,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (secondaryLabel != null) ...[
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: onSecondary,
                        child: Text(
                          secondaryLabel!,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

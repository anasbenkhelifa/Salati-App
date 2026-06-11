import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../screens/qibla_screen.dart';
import '../screens/home_screen.dart';
import '../screens/prayer_times_screen.dart';
import '../screens/settings_screen.dart';
import '../widgets/floating_nav_bar.dart';
import '../widgets/glass_container.dart';
import '../widgets/living_background.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_theme_provider.dart';
import '../../domain/providers/qibla_provider.dart';
import '../../core/tour/app_tour_service.dart';
import '../../core/theme/app_motion.dart';
import '../../data/services/analytics_service.dart';
import '../../data/services/hijri_date_service.dart';
import '../../data/services/islamic_event_service.dart';
import '../../data/services/adhan_alarm_service.dart';
import '../../core/localization/strings.dart';
import '../../domain/providers/prayer_times_api_provider.dart';
import '../../services/update_service.dart';
import '../../widgets/update_dialog.dart';
import '../widgets/rate_app_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/localization/app_locale_provider.dart';

/// Main app shell with floating bottom navigation and swipe navigation
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  /// Expose page controller for tour replay from Settings
  static PageController? activePageController;

  /// Expose a persistent context for tour replay
  static BuildContext? activeContext;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 1; // Start on Home (index 1)
  late final PageController _pageController;

  // Page order: Qibla (0), Home (1), Prayer Times (2), Settings (3)
  final List<Widget> _pages = const [
    _KeepAlivePage(child: QiblaScreen()),
    _KeepAlivePage(child: HomeScreen()),
    _KeepAlivePage(child: PrayerTimesScreen()),
    _KeepAlivePage(child: SettingsScreen()),
  ];

  bool _tourTriggered = false;

  /// Aurora tint for special occasions (Ramadan/Eid), null otherwise
  Color? _eventTint;

  /// Startup veil: fades/scales out after the first frame for a soft landing
  bool _startupRevealDone = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    AppShell.activePageController = _pageController;
    _loadEventTint();
    // Listen to theme changes
    AppThemeProvider.instance.addListener(_onThemeChange);
    // Listen to prayer data state for tour & rating prompt
    PrayerTimesApiProvider.instance.addListener(_onPrayerDataChanged);
    _warmUpShaders();
    // Try to trigger tour immediately if data is already loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryTriggerTourAndRatingPrompt();
    });
  }

  /// Warm the auroras during Ramadan (amber) and Eid (festive gold).
  Future<void> _loadEventTint() async {
    try {
      final hijri =
          await HijriDateService().getAdjustedHijriDate(DateTime.now());
      if (hijri == null || !mounted) return;
      Color? tint;
      if (IslamicEventService.isEid(hijri)) {
        tint = const Color(0xFFFFD27D);
      } else if (IslamicEventService.isRamadan(hijri)) {
        tint = const Color(0xFFFFB347);
      }
      if (tint != null) setState(() => _eventTint = tint);
    } catch (_) {
      // Cosmetic only — ignore failures
    }
  }

  Future<void> _warmUpShaders() async {
    // Force Flutter to compile blur shaders during a non-visible frame
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final blurPaint = Paint()
      ..imageFilter = ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 1, 1), blurPaint);
    final picture = recorder.endRecording();
    final image = await picture.toImage(1, 1);
    image.dispose();
    picture.dispose();
  }

  @override
  void dispose() {
    _pageController.dispose();
    AppShell.activePageController = null;
    AppShell.activeContext = null;
    AppThemeProvider.instance.removeListener(_onThemeChange);
    PrayerTimesApiProvider.instance.removeListener(_onPrayerDataChanged);
    super.dispose();
  }

  void _onThemeChange() {
    if (mounted) setState(() {});
  }

  /// Called whenever prayer data state changes (e.g., GPS off → GPS on recovery)
  void _onPrayerDataChanged() {
    _tryTriggerTourAndRatingPrompt();
  }

  /// Trigger the tour when data becomes available, and show rating prompt on 2nd/3rd open
  void _tryTriggerTourAndRatingPrompt() {
    if (!mounted || _tourTriggered) return;
    final provider = PrayerTimesApiProvider.instance;
    if (provider.state == PrayerDataState.success ||
        provider.state == PrayerDataState.offline) {
      _tourTriggered = true;
      // Small delay for UI to fully settle, then trigger tour
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          AppTourService.showTourIfFirstTime(context, _pageController).then((_) async {
            // After the tour: one-time battery exemption prompt (reliable adhan)
            await _checkBatteryExemptionPrompt();

            // Then the rating prompt
            await _checkRatingPrompt();

            // After tour/rating - check for update
            final shouldUpdate = await UpdateService.isUpdateAvailable();
            if (mounted && shouldUpdate) {
              await showUpdateDialog(context);
            }
          });
        }
      });
    }
  }

  /// One-time prompt asking for battery-optimization exemption so the adhan
  /// fires reliably on aggressive OEMs (Samsung/Xiaomi background killing).
  /// Shown once after the tour; always reachable later from Controls.
  Future<void> _checkBatteryExemptionPrompt() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('battery_prompt_shown') ?? false) return;

    final alreadyExempt =
        await AdhanAlarmService.isIgnoringBatteryOptimizations();
    await prefs.setBool('battery_prompt_shown', true);
    if (alreadyExempt || !mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.currentSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: AppTheme.currentAccentGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: AppTheme.glowShadow(intensity: 0.5),
              ),
              child: const Icon(Icons.notifications_active,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                t(context, 'batteryPromptTitle'),
                style: TextStyle(
                  color: AppTheme.currentTextPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 19,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          t(context, 'batteryPromptBody'),
          style: TextStyle(color: AppTheme.currentTextSecondary, height: 1.45),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              t(context, 'later'),
              style: TextStyle(color: AppTheme.currentTextSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              AdhanAlarmService.openBatterySettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.currentActiveGlow,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            ),
            child: Text(
              t(context, 'allow'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  /// Show a rating prompt on the 3rd app open, and every 7 opens after that
  Future<void> _checkRatingPrompt() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    
    // Check if the user has already successfully submitted a rating
    final hasRatedApp = prefs.getBool('has_rated_app') ?? false;
    if (hasRatedApp) return;

    final openCount = (prefs.getInt('app_open_count') ?? 0) + 1;
    await prefs.setInt('app_open_count', openCount);

    // Show prompt on 3rd open, or every 7 opens after that (e.g. 10, 17, 24)
    if (openCount == 3 || (openCount > 3 && (openCount - 3) % 7 == 0)) {
      if (!mounted) return;
      // Wait a moment for the app to feel settled
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      _showRatingPromptDialog();
    }
  }

  void _showRatingPromptDialog() {
    final locale = AppLocaleProvider.of(context).locale.languageCode;
    
    String title;
    String content;
    String laterText;
    String rateText;
    
    switch (locale) {
      case 'ar':
        title = 'هل تعجبك صلاتي؟';
        content = 'إذا أعجبك التطبيق، يرجى تقييمنا! رأيك يساعدنا كثيراً ⭐';
        laterText = 'لاحقاً';
        rateText = 'قيّمنا ⭐';
        break;
      case 'fr':
        title = 'Vous aimez Salati ?';
        content = 'Si vous aimez l\'application, évaluez-nous ! Votre avis nous aide beaucoup ⭐';
        laterText = 'Plus tard';
        rateText = 'Évaluer ⭐';
        break;
      default:
        title = 'Enjoying Salati?';
        content = 'If you like the app, please rate us! Your feedback helps a lot ⭐';
        laterText = 'Maybe Later';
        rateText = 'Rate Us ⭐';
    }
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.currentSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          title,
          style: TextStyle(color: AppTheme.currentTextPrimary, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Text(
          content,
          style: TextStyle(color: AppTheme.currentTextSecondary),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              laterText,
              style: TextStyle(color: AppTheme.currentTextSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => const RateAppSheet(),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.currentActiveGlow,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            ),
            child: Text(
              rateText,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  /// Animate to page when bottom nav is tapped
  void _onNavTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  /// Update current index when page is swiped
  /// Page names for analytics tracking
  static const _pageNames = ['Qibla', 'Home', 'Prayer Times', 'Settings'];

  void _onPageChanged(int index) {
    // Notify Qibla about page visibility (Qibla is at index 0)
    QiblaProvider.instance?.setActive(index == 0);

    // Log page view to analytics
    if (index >= 0 && index < _pageNames.length) {
      AnalyticsService.instance.logPageView(_pageNames[index]);
    }

    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Calculate bottom padding for content
    const bottomPadding =
        FloatingNavBar.navBarHeight + FloatingNavBar.navBarBottomMargin + 8;

    // Keep a reference to a persistent, mounted context for tour replay
    AppShell.activeContext = context;

    return PopScope(
      canPop: !AppTourService.isRunning,
      child: Scaffold(
        // AnimatedContainer lerps the gradient, so switching themes
        // crossfades the whole background instead of snapping
        body: AnimatedContainer(
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            gradient: AppTheme.currentBackgroundGradient,
          ),
          child: Stack(
            children: [
              // 0a. Special theme's pattern image. ImageFiltered over a
              // STATIC child is blurred once and cached by the raster cache
              // — unlike the old screen-wide BackdropFilter, which re-blurred
              // every frame because the living background animates beneath it.
              if (AppTheme.currentBackgroundImage != null)
                Positioned.fill(
                  child: RepaintBoundary(
                    child: ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                      child: Image.asset(
                        'assets/images/islamic_bg_pattern_special.webp',
                        fit: BoxFit.cover,
                        opacity: const AlwaysStoppedAnimation(0.65),
                      ),
                    ),
                  ),
                ),

              // 0b. Living background: drifting rosette pattern + aurora
              // glows. The pattern's softening is baked into its cached
              // image, so NO global BackdropFilter is needed above it —
              // that filter used to re-blur the whole screen every frame.
              Positioned.fill(
                child: LivingBackground(
                  pageController: _pageController,
                  eventTint: _eventTint,
                ),
              ),

              // 2. Sliding Content Layer - just colored boxes, NO BackdropFilter inside
              Padding(
                padding: const EdgeInsets.only(bottom: bottomPadding),
                child: Directionality(
                  textDirection:
                      TextDirection.ltr, // Always LTR for natural swipe feel
                  child: GlassStyle(
                    isBlurLayer: false, // Tell all glass containers to NOT render their blur
                    isContentLayer: true,
                    // Layer 1: Swipeable Main Content with Responsive Constraint
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: PageView.builder(
                          controller: _pageController,
                          physics: AppTourService.isRunning
                              ? const NeverScrollableScrollPhysics() // Disable swipe during tour
                              : const ClampingScrollPhysics(),       // Prevents overscroll glow issues
                          onPageChanged: _onPageChanged,
                          itemCount: _pages.length,
                          // Pages scale down + fade slightly as they leave
                          // center, giving the swipe a layered depth feel.
                          // Transform/opacity only — children stay stable.
                          itemBuilder: (context, index) {
                            return AnimatedBuilder(
                              animation: _pageController,
                              builder: (context, child) {
                                double delta = 0;
                                if (_pageController.hasClients &&
                                    _pageController
                                        .position.haveDimensions) {
                                  delta = ((_pageController.page ??
                                              _currentIndex.toDouble()) -
                                          index)
                                      .abs()
                                      .clamp(0.0, 1.0);
                                }
                                return Opacity(
                                  opacity: 1.0 - 0.35 * delta,
                                  child: Transform.scale(
                                    scale: 1.0 - 0.06 * delta,
                                    child: child,
                                  ),
                                );
                              },
                              child: _pages[index],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Floating nav bar - synced with PageView
              FloatingNavBar(currentIndex: _currentIndex, onTap: _onNavTapped),

              // Startup reveal: a veil matching the background that fades
              // and zooms away right after launch — a soft landing instead
              // of content popping in.
              if (!_startupRevealDone)
                Positioned.fill(
                  child: IgnorePointer(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 900),
                      curve: AppMotion.enter,
                      onEnd: () =>
                          setState(() => _startupRevealDone = true),
                      builder: (context, v, _) {
                        return Opacity(
                          opacity: 1 - v,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: AppTheme.currentBackgroundGradient,
                            ),
                            child: Center(
                              child: Transform.scale(
                                scale: 1 + 0.6 * v,
                                child: Icon(
                                  Icons.mosque,
                                  size: 72,
                                  color: AppTheme.currentActiveGlow,
                                  shadows: [
                                    Shadow(
                                      color: AppTheme.currentActiveGlow
                                          .withValues(alpha: 0.8),
                                      blurRadius: 32,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wrapper widget to keep page state alive when swiping
class _KeepAlivePage extends StatefulWidget {
  final Widget child;

  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return widget.child;
  }
}

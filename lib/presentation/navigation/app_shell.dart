import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../screens/qibla_screen.dart';
import '../screens/home_screen.dart';
import '../screens/prayer_times_screen.dart';
import '../screens/settings_screen.dart';
import '../widgets/floating_nav_bar.dart';
import '../widgets/glass_container.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_theme_provider.dart';
import '../../domain/providers/qibla_provider.dart';
import '../../core/tour/app_tour_service.dart';
import '../../data/services/analytics_service.dart';
import '../../domain/providers/prayer_times_api_provider.dart';
import '../widgets/rate_app_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    AppShell.activePageController = _pageController;
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

  Future<void> _warmUpShaders() async {
    // Force Flutter to compile blur shaders during a non-visible frame
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();
    canvas.drawRect(const Rect.fromLTWH(0, 0, 1, 1), paint);
    final picture = recorder.endRecording();
    final image = await picture.toImage(1, 1);
    
    // This triggers shader compilation silently
    final blurPaint = Paint()
      ..imageFilter = ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3); // Matching our global sigma 3
    image.dispose();
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
          AppTourService.showTourIfFirstTime(context, _pageController).then((_) {
            // After tour completes (or is skipped because already done), check rating prompt
            _checkRatingPrompt();
          });
        }
      });
    }
  }

  /// Show a rating prompt on the 2nd or 3rd app open
  Future<void> _checkRatingPrompt() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final openCount = (prefs.getInt('app_open_count') ?? 0) + 1;
    await prefs.setInt('app_open_count', openCount);

    // Show prompt on 2nd or 3rd open, but only once
    if (openCount >= 2 && openCount <= 3 && !(prefs.getBool('rating_prompt_shown') ?? false)) {
      await prefs.setBool('rating_prompt_shown', true);
      if (!mounted) return;
      // Wait a moment for the app to feel settled
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      _showRatingPromptDialog();
    }
  }

  void _showRatingPromptDialog() {
    final isArabic = Directionality.of(context) == TextDirection.rtl;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.currentSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          isArabic ? 'هل تعجبك صلاتي؟' : 'Enjoying Salati?',
          style: TextStyle(color: AppTheme.currentTextPrimary, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Text(
          isArabic
              ? 'إذا أعجبك التطبيق، يرجى تقييمنا! رأيك يساعدنا كثيراً ⭐'
              : 'If you like the app, please rate us! Your feedback helps a lot ⭐',
          style: TextStyle(color: AppTheme.currentTextSecondary),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              isArabic ? 'لاحقاً' : 'Maybe Later',
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
              isArabic ? 'قيّمنا ⭐' : 'Rate Us ⭐',
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
        body: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.currentBackgroundGradient,
            image: AppTheme.currentBackgroundImage,
          ),
          child: Stack(
            children: [
              // 1. Static Full-Screen Blur Layer - NEVER moves!
              Positioned.fill(
                child: RepaintBoundary(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                    child: Container(color: Colors.transparent),
                  ),
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
                          itemBuilder: (context, index) => _pages[index],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Floating nav bar - synced with PageView
              FloatingNavBar(currentIndex: _currentIndex, onTap: _onNavTapped),
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

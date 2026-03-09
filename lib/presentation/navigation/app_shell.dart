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

/// Main app shell with floating bottom navigation and swipe navigation
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  /// Expose page controller for tour replay from Settings
  static PageController? activePageController;

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

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    AppShell.activePageController = _pageController;
    // Listen to theme changes
    AppThemeProvider.instance.addListener(_onThemeChange);
    _warmUpShaders();
    // Trigger guided tour after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AppTourService.showTourIfFirstTime(context, _pageController);
      }
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
    AppThemeProvider.instance.removeListener(_onThemeChange);
    super.dispose();
  }

  void _onThemeChange() {
    if (mounted) setState(() {});
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
  void _onPageChanged(int index) {
    // Notify Qibla about page visibility (Qibla is at index 0)
    QiblaProvider.instance?.setActive(index == 0);

    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Calculate bottom padding for content
    const bottomPadding =
        FloatingNavBar.navBarHeight + FloatingNavBar.navBarBottomMargin + 8;

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
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: _onPageChanged,
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      children: _pages,
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

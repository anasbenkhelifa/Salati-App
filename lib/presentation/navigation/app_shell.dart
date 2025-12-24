import 'package:flutter/material.dart';
import '../screens/qibla_screen.dart';
import '../screens/home_screen.dart';
import '../screens/prayer_times_screen.dart';
import '../screens/settings_screen.dart';
import '../widgets/floating_nav_bar.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/providers/qibla_provider.dart';

/// Main app shell with floating bottom navigation and swipe navigation
class AppShell extends StatefulWidget {
  const AppShell({super.key});

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
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: Stack(
          children: [
            // PageView for swipe navigation with state preservation
            // Force LTR directionality so swipe physics work naturally in both languages
            // (In RTL, PageView would reverse swipe direction which feels unnatural)
            Padding(
              padding: const EdgeInsets.only(bottom: bottomPadding),
              child: Directionality(
                textDirection:
                    TextDirection.ltr, // Always LTR for natural swipe feel
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
            // Floating nav bar - synced with PageView
            FloatingNavBar(currentIndex: _currentIndex, onTap: _onNavTapped),
          ],
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

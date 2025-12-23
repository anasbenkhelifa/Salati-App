import 'package:flutter/material.dart';
import '../screens/qibla_screen.dart';
import '../screens/home_screen.dart';
import '../screens/prayer_times_screen.dart';
import '../screens/settings_screen.dart';
import '../widgets/floating_nav_bar.dart';
import '../../core/theme/app_theme.dart';

/// Main app shell with floating bottom navigation
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 1; // Start on Home (index 1)

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
            // Screen content with IndexedStack to preserve state
            Padding(
              padding: const EdgeInsets.only(bottom: bottomPadding),
              child: IndexedStack(
                index: _currentIndex,
                children: const [
                  QiblaScreen(), // index 0
                  HomeScreen(), // index 1
                  PrayerTimesScreen(), // index 2
                  SettingsScreen(), // index 3
                ],
              ),
            ),
            // Floating nav bar
            FloatingNavBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}

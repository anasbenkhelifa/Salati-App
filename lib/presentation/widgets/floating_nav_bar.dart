import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'apple_glass_card.dart';

/// Custom floating glassmorphism bottom navigation bar
/// Features a single animated Apple liquid glass indicator that slides between icons
class FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const FloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  // Nav bar height for external padding calculations
  static const double navBarHeight = 72;
  static const double navBarBottomMargin = 24;
  static const int _itemCount = 4;
  static const double _indicatorWidth = 52;
  static const double _indicatorHeight = 46;

  // Icon definitions
  static const List<IconData> _icons = [
    Icons.explore_outlined,
    Icons.home_outlined,
    Icons.access_time,
    Icons.settings_outlined,
  ];

  static const List<IconData> _activeIcons = [
    Icons.explore,
    Icons.home,
    Icons.access_time_filled,
    Icons.settings,
  ];

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 24,
      right: 24,
      bottom: navBarBottomMargin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: navBarHeight,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Colors.white.withOpacity(0.15),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            // Force LTR so icons are always: Qibla, Home, PrayerTimes, Settings
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth = constraints.maxWidth / _itemCount;
                  // Calculate indicator position (center of selected item)
                  final indicatorLeft =
                      (currentIndex * itemWidth) +
                      (itemWidth - _indicatorWidth) / 2;

                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Layer 1: Animated Apple Glass indicator (slides smoothly)
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        left: indicatorLeft,
                        child: AppleGlassCard(
                          width: _indicatorWidth,
                          height: _indicatorHeight,
                          borderRadius: 16,
                          glowColor: AppTheme.activeGlow,
                          glowOpacity: 0.4,
                          blurSigma: 22,
                        ),
                      ),

                      // Layer 2: Row of icons (on top)
                      Row(
                        children: List.generate(_itemCount, (index) {
                          return _buildNavItem(index);
                        }),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Individual nav item (icon only, no glow - glow is handled by indicator)
  Widget _buildNavItem(int index) {
    final isActive = currentIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        borderRadius: BorderRadius.circular(16),
        child: Center(
          child: AnimatedScale(
            duration: const Duration(milliseconds: 200),
            scale: isActive ? 1.1 : 1.0,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isActive ? _activeIcons[index] : _icons[index],
                key: ValueKey(isActive),
                color:
                    isActive
                        ? AppTheme.activeGlow
                        : Colors.white.withOpacity(0.6),
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

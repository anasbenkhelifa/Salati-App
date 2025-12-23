import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Custom floating glassmorphism bottom navigation bar
/// Wrapped in LTR directionality to maintain left→right icon order
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
              child: Row(
                children: [
                  _buildNavItem(
                    context,
                    0,
                    Icons.explore_outlined,
                    Icons.explore,
                  ),
                  _buildNavItem(context, 1, Icons.home_outlined, Icons.home),
                  _buildNavItem(
                    context,
                    2,
                    Icons.access_time,
                    Icons.access_time_filled,
                  ),
                  _buildNavItem(
                    context,
                    3,
                    Icons.settings_outlined,
                    Icons.settings,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    int index,
    IconData icon,
    IconData activeIcon,
  ) {
    final isActive = currentIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        borderRadius: BorderRadius.circular(16),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(10),
            decoration:
                isActive
                    ? BoxDecoration(
                      color: AppTheme.activeGlow.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.activeGlow.withOpacity(0.3),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    )
                    : null,
            child: Icon(
              isActive ? activeIcon : icon,
              color:
                  isActive
                      ? AppTheme.activeGlow
                      : Colors.white.withOpacity(0.6),
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}

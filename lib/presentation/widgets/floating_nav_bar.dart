import 'dart:io' show Platform;
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import '../../core/theme/app_theme.dart';

/// Feature flag for liquid glass effect
const bool _useLiquidNavBar = true;

/// Custom floating liquid glass bottom navigation bar
/// Uses Apple-like liquid glass effect on supported platforms (Android/iOS/macOS)
/// Falls back to regular blur effect on Windows/Web/Linux or if effect fails
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

  /// Check if liquid glass is supported on this platform
  /// Only works on Impeller: Android/iOS/macOS
  static bool get isLiquidGlassSupported {
    if (!_useLiquidNavBar) return false;
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 24,
      right: 24,
      bottom: navBarBottomMargin,
      child: SizedBox(
        height: navBarHeight,
        child:
            isLiquidGlassSupported
                ? _LiquidNavBarContent(currentIndex: currentIndex, onTap: onTap)
                : _buildFallbackNavBar(),
      ),
    );
  }

  /// Build fallback blur navbar for unsupported platforms
  Widget _buildFallbackNavBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: _NavBarIcons(currentIndex: currentIndex, onTap: onTap),
        ),
      ),
    );
  }
}

/// Liquid glass navbar content - wrapped in try/catch for fallback
class _LiquidNavBarContent extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const _LiquidNavBarContent({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    try {
      return LiquidGlassLayer(
        child: LiquidGlass(
          shape: LiquidRoundedSuperellipse(borderRadius: 32),
          child: Container(
            height: FloatingNavBar.navBarHeight,
            child: _NavBarIcons(currentIndex: currentIndex, onTap: onTap),
          ),
        ),
      );
    } catch (e) {
      debugPrint('[FloatingNavBar] LiquidGlass failed, using fallback: $e');
      return _FallbackGlass(currentIndex: currentIndex, onTap: onTap);
    }
  }
}

/// Fallback glass design for when liquid glass fails
class _FallbackGlass extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const _FallbackGlass({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
          ),
          child: _NavBarIcons(currentIndex: currentIndex, onTap: onTap),
        ),
      ),
    );
  }
}

/// Nav bar icons - shared between liquid and fallback
class _NavBarIcons extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const _NavBarIcons({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: FloatingNavBar.navBarHeight,
      // Force LTR so icons are always: Qibla, Home, PrayerTimes, Settings
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            _buildNavItem(0, Icons.explore_outlined, Icons.explore),
            _buildNavItem(1, Icons.home_outlined, Icons.home),
            _buildNavItem(2, Icons.access_time, Icons.access_time_filled),
            _buildNavItem(3, Icons.settings_outlined, Icons.settings),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon) {
    final isActive = currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
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

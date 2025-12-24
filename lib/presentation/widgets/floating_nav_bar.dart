import 'dart:io' show Platform;
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import '../../core/theme/app_theme.dart';

/// Feature flag for liquid glass effect
const bool _useLiquidNavBar = true;

/// Floating liquid glass bottom navigation bar
/// NO BACKPLATE - only the liquid glass pill itself
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
    // ONLY the pill, positioned at bottom - NO extra containers/backgrounds
    return Positioned(
      left: 24,
      right: 24,
      bottom: navBarBottomMargin,
      child: SizedBox(
        height: navBarHeight,
        // Direct to glass pill - no wrapping containers
        child:
            isLiquidGlassSupported
                ? _LiquidPill(currentIndex: currentIndex, onTap: onTap)
                : _FallbackPill(currentIndex: currentIndex, onTap: onTap),
      ),
    );
  }
}

/// Liquid glass pill - ONLY the refractive glass effect, nothing behind it
class _LiquidPill extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const _LiquidPill({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    try {
      return LiquidGlassLayer(
        settings: const LiquidGlassSettings(
          thickness: 20, // Strong refraction
          glassColor: Color(0x00000000), // FULLY TRANSPARENT - no tint
          lightIntensity: 2.0, // Strong specular highlight
          lightAngle: -0.4, // Light from top-left
          ambientStrength: 0.5, // Ambient light
        ),
        child: LiquidGlass(
          shape: LiquidRoundedSuperellipse(borderRadius: 36),
          glassContainsChild: false, // Icons on TOP, not inside
          child: SizedBox(
            height: FloatingNavBar.navBarHeight,
            child: _NavBarIcons(currentIndex: currentIndex, onTap: onTap),
          ),
        ),
      );
    } catch (e) {
      debugPrint('[FloatingNavBar] LiquidGlass failed: $e');
      return _FallbackPill(currentIndex: currentIndex, onTap: onTap);
    }
  }
}

/// Fallback pill for unsupported platforms - minimal blur, NO solid background
class _FallbackPill extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const _FallbackPill({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(36),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        // Container ONLY for border - no solid fill
        child: Container(
          decoration: BoxDecoration(
            // NO solid color - fully transparent
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(36),
            // Thin subtle border only
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 0.5,
            ),
          ),
          child: _NavBarIcons(currentIndex: currentIndex, onTap: onTap),
        ),
      ),
    );
  }
}

/// Nav bar icons - just the icons, no background at all
class _NavBarIcons extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const _NavBarIcons({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        children: [
          _buildNavItem(0, Icons.explore_outlined, Icons.explore),
          _buildNavItem(1, Icons.home_outlined, Icons.home),
          _buildNavItem(2, Icons.access_time, Icons.access_time_filled),
          _buildNavItem(3, Icons.settings_outlined, Icons.settings),
        ],
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
                      : Colors.white.withOpacity(0.7),
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}

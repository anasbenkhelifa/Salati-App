import 'dart:ui';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:oc_liquid_glass/oc_liquid_glass.dart';
import '../../core/theme/app_theme.dart';
import 'apple_glass_card.dart';
import 'liquid_active_indicator.dart';

/// Custom floating glassmorphism bottom navigation bar
/// Features a single animated Apple liquid glass indicator that slides between icons
/// Uses real refraction (oc_liquid_glass) on supported platforms, falling back to blur
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

  /// Check if LiquidGlass can be used (platforms supporting Impeller/shaders)
  bool get _canUseLiquidGlass {
    if (kIsWeb) return false;
    try {
      // Basic check for platforms where shader support is consistent
      // Does not guarantee Impeller is active, but oc_liquid_glass usually
      // works on recent Android/iOS versions gracefully
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        // Main nav bar blur (frosted glass background)
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

                  final bool useLiquidParams = _canUseLiquidGlass;

                  // The main content of the navbar
                  Widget contentStack = Stack(
                    alignment: Alignment.center,
                    children: [
                      // Layer 1: Animated indicator (slides smoothly)
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        left: indicatorLeft,
                        child:
                            useLiquidParams
                                ? LiquidActiveIndicator(
                                  width: _indicatorWidth,
                                  height: _indicatorHeight,
                                  borderRadius: 16,
                                  // Tint for the droplet
                                  color: AppTheme.activeGlow.withOpacity(0.2),
                                )
                                : AppleGlassCard(
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

                  // If valid platform, wrap with OCLiquidGlassGroup to enable shader effect
                  if (useLiquidParams) {
                    return OCLiquidGlassGroup(
                      settings: OCLiquidGlassSettings(
                        // Tuning per "droplet/gel pill" request
                        refractStrength: -0.12, // Slight refraction
                        blurRadiusPx: 1.5, // Soft blur
                        specStrength: 18.0, // Shiny highlights
                        lightbandColor: Colors.white.withOpacity(0.4),
                      ),
                      child: contentStack,
                    );
                  }

                  return contentStack;
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

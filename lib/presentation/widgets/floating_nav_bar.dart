import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_motion.dart';
import 'glass_container.dart';

/// Custom floating glassmorphism bottom navigation bar.
/// The indicator is a glass pill that stretches while it travels between
/// icons and settles back behind the active one, with a glow bloom on the
/// active icon.
class FloatingNavBar extends StatefulWidget {
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
  State<FloatingNavBar> createState() => _FloatingNavBarState();
}

class _FloatingNavBarState extends State<FloatingNavBar>
    with SingleTickerProviderStateMixin {
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

  late final AnimationController _controller;
  late double _fromIndex;
  late double _toIndex;

  @override
  void initState() {
    super.initState();
    _fromIndex = _toIndex = widget.currentIndex.toDouble();
    _controller = AnimationController(vsync: this, duration: AppMotion.normal)
      ..value = 1.0;
  }

  @override
  void didUpdateWidget(FloatingNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != oldWidget.currentIndex) {
      // Retarget from wherever the pill currently is, so rapid taps and
      // swipes stay fluid instead of jumping
      _fromIndex = _animatedIndex;
      _toIndex = widget.currentIndex.toDouble();
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Current interpolated position of the pill in item-index space.
  double get _animatedIndex {
    final t = AppMotion.glide.transform(_controller.value);
    return lerpDouble(_fromIndex, _toIndex, t)!;
  }

  /// Stretch factor: 1.0 at rest, peaks mid-flight, scaled by how far the
  /// pill is traveling (a 3-tab jump stretches more than a neighbor hop).
  double get _stretch {
    final distance = (_toIndex - _fromIndex).abs().clamp(0.0, 3.0);
    if (distance == 0) return 1.0;
    final peak = 0.35 + 0.18 * distance;
    return 1.0 + peak * math.sin(math.pi * _controller.value);
  }

  @override
  Widget build(BuildContext context) {
    final isLightMode = AppTheme.isLightMode;

    return Positioned(
      left: 24,
      right: 24,
      bottom: FloatingNavBar.navBarBottomMargin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        // Content-only glass: page content never slides under the nav bar
        // (pages are padded above it), so a BackdropFilter here would only
        // re-blur the already-soft animated background every frame for
        // nothing. The translucent fill + lit edge carry the glass look.
        child: GlassStyle(
          isBlurLayer: false,
          isContentLayer: true,
          child: GlassContainer(
            height: FloatingNavBar.navBarHeight,
            borderRadius: 32,
            // Force LTR so icons are always: Qibla, Home, PrayerTimes, Settings
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth = constraints.maxWidth / _itemCount;

                  return AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      final pillWidth = _indicatorWidth * _stretch;
                      final pillCenter =
                          (_animatedIndex * itemWidth) + itemWidth / 2;

                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // Layer 1: morphing accent-gradient pill with glow
                          Positioned(
                            left: pillCenter - pillWidth / 2,
                            child: Container(
                              width: pillWidth,
                              height: _indicatorHeight,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors:
                                      AppTheme.currentAccentGradient.colors
                                          .map(
                                            (c) => c.withValues(
                                              alpha: isLightMode ? 0.18 : 0.30,
                                            ),
                                          )
                                          .toList(),
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppTheme.currentActiveGlow.withValues(
                                    alpha: 0.55,
                                  ),
                                  width: 1.2,
                                ),
                                boxShadow: AppTheme.glowShadow(intensity: 1.2),
                              ),
                            ),
                          ),

                          // Layer 2: row of icons (on top)
                          Row(
                            children: List.generate(_itemCount, (index) {
                              return _buildNavItem(index, isLightMode);
                            }),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Individual nav item; the active icon scales up with a glow bloom.
  Widget _buildNavItem(int index, bool isLightMode) {
    final isActive = widget.currentIndex == index;
    final glowColor = AppTheme.currentActiveGlow;

    final inactiveColor =
        isLightMode
            ? AppTheme.lightTextSecondary
            : Colors.white.withValues(alpha: 0.6);

    return Expanded(
      child: InkWell(
        onTap: () => widget.onTap(index),
        borderRadius: BorderRadius.circular(16),
        child: Center(
          child: AnimatedScale(
            duration: AppMotion.fast,
            curve: AppMotion.pop,
            scale: isActive ? 1.15 : 1.0,
            child: AnimatedSwitcher(
              duration: AppMotion.fast,
              switchInCurve: AppMotion.enter,
              switchOutCurve: AppMotion.exit,
              child: Icon(
                isActive ? _activeIcons[index] : _icons[index],
                key: ValueKey(isActive),
                color: isActive ? glowColor : inactiveColor,
                size: 26,
                shadows:
                    isActive
                        ? [
                          Shadow(
                            color: glowColor.withValues(
                              alpha: isLightMode ? 0.5 : 0.9,
                            ),
                            blurRadius: 14,
                          ),
                        ]
                        : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

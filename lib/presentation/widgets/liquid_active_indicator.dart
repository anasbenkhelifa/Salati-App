import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:oc_liquid_glass/oc_liquid_glass.dart';
import '../../core/theme/app_theme.dart';

/// Liquid glass refraction indicator for navbar active tab
///
/// Uses oc_liquid_glass for real refraction/distortion effect on supported platforms.
/// Falls back to a simple blur/glow indicator on unsupported platforms.
///
/// Requirements for oc_liquid_glass:
/// - Impeller rendering engine (Android with Flutter 3.16+)
/// - GPU fragment shader support
class LiquidActiveIndicator extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final Color? glowColor;
  final double glowOpacity;

  const LiquidActiveIndicator({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 16,
    this.glowColor,
    this.glowOpacity = 0.4,
  });

  /// Check if oc_liquid_glass can run (requires Impeller on Android)
  /// Web and non-Android platforms fall back to simple indicator
  static bool get canUseLiquidGlass {
    if (kIsWeb) return false;
    try {
      // oc_liquid_glass works on Android with Impeller (default in Flutter 3.16+)
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Outer container with glow shadow
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow:
            glowColor != null
                ? [
                  BoxShadow(
                    color: glowColor!.withOpacity(glowOpacity),
                    blurRadius: 14,
                    spreadRadius: 2,
                  ),
                ]
                : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child:
            canUseLiquidGlass
                ? _buildLiquidGlassIndicator()
                : _buildFallbackIndicator(),
      ),
    );
  }

  /// Real liquid glass refraction effect using oc_liquid_glass
  /// Creates a droplet-like pill that visibly distorts the background
  Widget _buildLiquidGlassIndicator() {
    return OCLiquidGlassGroup(
      // Settings for a subtle, elegant liquid droplet look
      settings: const OCLiquidGlassSettings(
        refractStrength: -0.06, // Negative = concave lens refraction
        blurRadiusPx: 1.5, // Subtle frosted blur
        distortFalloffPx: 8.0, // Smooth edge distortion falloff
        distortExponent: 2.0, // Gradual falloff curve
        specStrength: 18.0, // Visible but not harsh specular
        specPower: 8.0, // Medium-sharp highlights
        specAngle: 0.8, // ~45° light angle
        specWidth: 3.0, // Thin specular band
        lightbandOffsetPx: 6.0, // Light band near edge
        lightbandWidthPx: 8.0, // Width of light band
        lightbandStrength: 0.3, // Subtle light band
        lightbandColor: Colors.white70,
        blendPx: 4.0, // Edge blending
      ),
      child: OCLiquidGlass(
        enabled: true,
        width: width,
        height: height,
        borderRadius: borderRadius,
        // Subtle tint color matching the app theme
        color: AppTheme.activeGlow.withOpacity(0.15),
        // Soft shadow for depth
        shadow: BoxShadow(
          color: AppTheme.activeGlow.withOpacity(0.2),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
        child: const SizedBox(), // Empty child, we just want the glass effect
      ),
    );
  }

  /// Fallback indicator for platforms without Impeller/shader support
  /// Uses simple blur + gradient effect
  Widget _buildFallbackIndicator() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        // Subtle gradient for visual interest
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.activeGlow.withOpacity(0.25),
            AppTheme.activeGlow.withOpacity(0.15),
          ],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.5),
      ),
    );
  }
}

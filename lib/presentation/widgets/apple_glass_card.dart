import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Apple-style liquid glass card with blur, vibrancy, and subtle effects
///
/// In dark mode: Full liquid glass effect with blur, vibrancy, noise
/// In light mode: Clean solid white card with subtle shadow (no glass)
class AppleGlassCard extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final Widget? child;
  final Color? glowColor;
  final double glowOpacity;
  final double blurSigma;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;

  const AppleGlassCard({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 20,
    this.child,
    this.glowColor,
    this.glowOpacity = 0.4,
    this.blurSigma = 20,
    this.padding,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = AppTheme.isLightMode;

    // Light mode: Clean solid design (no glass effects - looks better)
    if (isLight) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          color: Colors.white,
          border: Border.all(
            color: borderColor ?? AppTheme.lightDivider,
            width: 1,
          ),
          boxShadow:
              glowColor != null
                  ? [
                    // Subtle colored shadow for glow effect
                    BoxShadow(
                      color: glowColor!.withOpacity(0.15),
                      blurRadius: 8,
                      spreadRadius: 0,
                    ),
                    // Soft drop shadow for depth
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                  : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
        ),
        padding: padding,
        child: child,
      );
    }

    // Dark mode: Full liquid glass effect
    final effectiveBorderColor = borderColor ?? Colors.white.withOpacity(0.15);

    Widget glassStack = Stack(
      fit: StackFit.passthrough,
      children: [
        // Layer 1: Backdrop blur
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: Container(color: Colors.transparent),
          ),
        ),

        // Layer 2: Vibrancy overlay
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.12),
                  Colors.white.withOpacity(0.04),
                ],
              ),
            ),
          ),
        ),

        // Layer 3: Soft highlight gradient
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.5],
                colors: [Colors.white.withOpacity(0.10), Colors.transparent],
              ),
            ),
          ),
        ),

        // Layer 4: Procedural noise
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: _NoisePainter(
                  borderRadius: borderRadius,
                  opacity: 0.04,
                ),
              );
            },
          ),
        ),

        // Layer 5: Thin border
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: effectiveBorderColor, width: 0.5),
            ),
          ),
        ),

        // Layer 6: Child content
        if (child != null)
          Padding(padding: padding ?? EdgeInsets.zero, child: child!),
      ],
    );

    Widget clippedGlass = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: glassStack,
    );

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
      child: clippedGlass,
    );
  }
}

/// Custom painter for subtle procedural noise (dark mode only)
class _NoisePainter extends CustomPainter {
  final double borderRadius;
  final double opacity;

  static final Map<int, List<Offset>> _noiseCache = {};

  _NoisePainter({this.borderRadius = 16, this.opacity = 0.04});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 ||
        size.height <= 0 ||
        size.width.isInfinite ||
        size.height.isInfinite)
      return;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );
    canvas.clipRRect(rrect);

    final cacheKey = (size.width.toInt() << 16) | size.height.toInt();
    if (!_noiseCache.containsKey(cacheKey)) {
      _noiseCache[cacheKey] = _generateNoisePoints(size);
    }

    final points = _noiseCache[cacheKey]!;
    final paint =
        Paint()
          ..color = Colors.white.withOpacity(opacity)
          ..strokeWidth = 1;

    for (final point in points) {
      canvas.drawCircle(point, 0.5, paint);
    }
  }

  List<Offset> _generateNoisePoints(Size size) {
    final random = math.Random(42);
    final points = <Offset>[];

    const gridSize = 3;
    for (double x = 0; x < size.width; x += gridSize) {
      for (double y = 0; y < size.height; y += gridSize) {
        if (random.nextDouble() > 0.5) {
          final jitterX = random.nextDouble() * gridSize;
          final jitterY = random.nextDouble() * gridSize;
          points.add(Offset(x + jitterX, y + jitterY));
        }
      }
    }

    return points;
  }

  @override
  bool shouldRepaint(covariant _NoisePainter oldDelegate) {
    return oldDelegate.opacity != opacity ||
        oldDelegate.borderRadius != borderRadius;
  }
}

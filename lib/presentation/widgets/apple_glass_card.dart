import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Apple-style liquid glass card with blur, vibrancy, and subtle effects
///
/// Features:
/// - Strong BackdropFilter blur for glassmorphism
/// - Vibrancy effect (saturation boost) via color overlay
/// - Subtle procedural noise texture
/// - Thin border with highlight
/// - Optional outer glow
/// - Child content rendered crisp on top
///
/// Sizing behavior:
/// - If width/height provided: uses fixed sizing
/// - If width/height null: sizes to fit child content (using IntrinsicHeight/Width)
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
    final effectiveBorderColor = borderColor ?? Colors.white.withOpacity(0.15);

    // Build the glass effect stack
    Widget glassStack = Stack(
      fit: StackFit.passthrough,
      children: [
        // Layer 1: Backdrop blur (strong glassmorphism)
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: Container(color: Colors.transparent),
          ),
        ),

        // Layer 2: Vibrancy effect (saturation boost via color overlay)
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

        // Layer 3: Soft highlight gradient (top-left shine)
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

        // Layer 4: Procedural noise for texture (very subtle)
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

        // Layer 5: Thin border for definition
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: effectiveBorderColor, width: 0.5),
            ),
          ),
        ),

        // Layer 6: Child content (crisp on top)
        if (child != null)
          Padding(padding: padding ?? EdgeInsets.zero, child: child!),
      ],
    );

    // Wrap with ClipRRect for rounded corners on blur
    Widget clippedGlass = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: glassStack,
    );

    // Apply outer container with optional glow
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

/// Custom painter for subtle procedural noise
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

    // Create a clipping path for rounded rectangle
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );
    canvas.clipRRect(rrect);

    // Use cached noise points or generate new ones
    final cacheKey = (size.width.toInt() << 16) | size.height.toInt();
    if (!_noiseCache.containsKey(cacheKey)) {
      _noiseCache[cacheKey] = _generateNoisePoints(size);
    }

    final points = _noiseCache[cacheKey]!;
    final paint =
        Paint()
          ..color = Colors.white.withOpacity(opacity)
          ..strokeWidth = 1;

    // Draw noise as small dots
    for (final point in points) {
      canvas.drawCircle(point, 0.5, paint);
    }
  }

  List<Offset> _generateNoisePoints(Size size) {
    final random = math.Random(42);
    final points = <Offset>[];

    // Generate sparse noise (every 3rd pixel in a grid pattern with jitter)
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

import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'glass_container.dart';

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
    return GlassContainer(
      width: width,
      height: height,
      borderRadius: borderRadius,
      padding: padding,
      child: child ?? const SizedBox.shrink(),
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
          ..color = Colors.white.withValues(alpha: opacity)
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

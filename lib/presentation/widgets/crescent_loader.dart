import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Rotating crescent loading indicator in the theme accent gradient —
/// replaces the stock CircularProgressIndicator on branded surfaces.
class CrescentLoader extends StatefulWidget {
  final double size;

  const CrescentLoader({super.key, this.size = 40});

  @override
  State<CrescentLoader> createState() => _CrescentLoaderState();
}

class _CrescentLoaderState extends State<CrescentLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Transform.rotate(
            angle: _controller.value * 2 * math.pi,
            child: CustomPaint(
              painter: _CrescentPainter(
                colors: AppTheme.currentAccentGradient.colors,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CrescentPainter extends CustomPainter {
  final List<Color> colors;

  _CrescentPainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // Crescent = full disc minus a smaller disc shifted toward one side
    final crescent = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: center, radius: r)),
      Path()
        ..addOval(Rect.fromCircle(
          center: Offset(center.dx + r * 0.42, center.dy - r * 0.18),
          radius: r * 0.82,
        )),
    );

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      ).createShader(Rect.fromCircle(center: center, radius: r))
      ..style = PaintingStyle.fill;

    // Soft glow beneath, then the crescent itself
    canvas.drawPath(
      crescent,
      Paint()
        ..color = colors.first.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(crescent, paint);
  }

  @override
  bool shouldRepaint(covariant _CrescentPainter oldDelegate) =>
      oldDelegate.colors != colors;
}

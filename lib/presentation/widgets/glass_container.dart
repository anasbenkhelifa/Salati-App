import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class GlassStyle extends InheritedWidget {
  final bool isBlurLayer;
  final bool isContentLayer;

  const GlassStyle({
    super.key,
    required this.isBlurLayer,
    required this.isContentLayer,
    required super.child,
  });

  static GlassStyle? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<GlassStyle>();
  }

  @override
  bool updateShouldNotify(GlassStyle oldWidget) {
    return isBlurLayer != oldWidget.isBlurLayer || isContentLayer != oldWidget.isContentLayer;
  }
}

/// Reusable glass container that applies a true frosted glass effect
/// (blurring the background behind it) and themed borders/colors.
///
/// Glass 2.0: gradient fill (brighter toward the top = inner highlight),
/// a 1px gradient "lit edge" border, and an optional theme-tinted [glow].
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blurSigma;
  final double? customOpacity;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final BoxShape shape;

  /// When true, the card carries a soft outer glow in the theme accent
  /// (or [glowColor]). Use sparingly — active/highlighted cards only.
  final bool glow;
  final Color? glowColor;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.blurSigma = 3, // A slight notch of blur
    this.customOpacity,
    this.padding,
    this.width,
    this.height,
    this.shape = BoxShape.rectangle,
    this.glow = false,
    this.glowColor,
  });

  /// Gradient fill: slightly brighter at the top, like light falling on
  /// the pane. Light mode keeps the original near-solid white card.
  BoxDecoration _fillDecoration() {
    final radius = shape == BoxShape.circle
        ? null
        : BorderRadius.circular(borderRadius);

    if (AppTheme.isLightMode) {
      return BoxDecoration(
        color: Colors.white.withValues(alpha: customOpacity ?? 0.9),
        borderRadius: radius,
        shape: shape,
        boxShadow: [
          // Warm-tinted lift so white cards read against the parchment bg
          BoxShadow(
            color: const Color(0xFF8A7A55).withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          if (glow) ...AppTheme.glowShadow(color: glowColor),
        ],
      );
    }

    final base = customOpacity ??
        (AppTheme.isIslamicSpecialMode
            ? 0.15
            : ((AppTheme.isIslamicMode || AppTheme.isIslamicGreenMode)
                ? 0.08
                : 0.05));
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: base + 0.05),
          Colors.white.withValues(alpha: base * 0.75),
        ],
      ),
      borderRadius: radius,
      shape: shape,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.10),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
        if (glow) ...AppTheme.glowShadow(color: glowColor),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final glassStyle = GlassStyle.of(context);
    final bool isBlurLayer = glassStyle?.isBlurLayer ?? true;
    final bool isContentLayer = glassStyle?.isContentLayer ?? true;

    Widget blurredBox = BackdropFilter(
      filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: shape == BoxShape.circle ? null : BorderRadius.circular(borderRadius),
          shape: shape,
          color: Colors.transparent, // Only blurring, no color needed
        ),
      ),
    );

    Widget blurWidget = shape == BoxShape.circle
      ? ClipOval(child: blurredBox)
      : ClipRRect(borderRadius: BorderRadius.circular(borderRadius), child: blurredBox);

    Widget contentWidget = CustomPaint(
      foregroundPainter: _GlassEdgePainter(
        borderRadius: borderRadius,
        shape: shape,
        gradient: AppTheme.borderHighlightGradient,
      ),
      child: Container(
        width: width,
        height: height,
        padding: padding,
        decoration: _fillDecoration(),
        child: child,
      ),
    );

    if (isBlurLayer && !isContentLayer) {
      // ONLY render the blur shape. Use Opacity(0) on child to maintain exact identical layout bounds!
      return Stack(
        fit: StackFit.loose,
        children: [
          Positioned.fill(child: blurWidget),
          Opacity(opacity: 0.0, child: contentWidget),
        ],
      );
    } else if (!isBlurLayer && isContentLayer) {
      // ONLY render the content and borders
      return contentWidget;
    }

    // Default standalone rendering
    return Stack(
      fit: StackFit.loose,
      children: [
        Positioned.fill(child: blurWidget),
        contentWidget,
      ],
    );
  }
}

/// Strokes the 1px "lit edge" gradient border on top of the glass fill.
/// A painter is needed because BoxDecoration borders can't take gradients.
class _GlassEdgePainter extends CustomPainter {
  final double borderRadius;
  final BoxShape shape;
  final Gradient gradient;

  _GlassEdgePainter({
    required this.borderRadius,
    required this.shape,
    required this.gradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || !size.isFinite) return;

    // Inset by half the stroke so the line hugs the fill's edge crisply
    final rect = Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader = gradient.createShader(rect);

    if (shape == BoxShape.circle) {
      canvas.drawOval(rect, paint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(borderRadius)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GlassEdgePainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius ||
        oldDelegate.shape != shape ||
        oldDelegate.gradient != gradient;
  }
}

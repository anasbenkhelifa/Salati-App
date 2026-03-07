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
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blurSigma;
  final double? customOpacity;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final BoxShape shape;

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
  });

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

    Widget contentWidget = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: AppTheme.glassDecoration(
        opacity: customOpacity ?? (AppTheme.isLightMode ? 0.9 : 0.08),
        borderRadius: shape == BoxShape.circle ? 0 : borderRadius,
        shape: shape,
      ),
      child: child,
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

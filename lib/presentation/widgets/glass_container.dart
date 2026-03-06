import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

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
    this.blurSigma = 5, // A slight notch of blur
    this.customOpacity,
    this.padding,
    this.width,
    this.height,
    this.shape = BoxShape.rectangle,
  });

  @override
  Widget build(BuildContext context) {
    Widget blurredBackground = RepaintBoundary(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: AppTheme.glassDecoration(
            opacity: customOpacity ?? (AppTheme.isLightMode ? 0.9 : 0.08),
            borderRadius: shape == BoxShape.circle ? 0 : borderRadius,
            shape: shape,
          ),
          child: child,
        ),
      ),
    );

    if (shape == BoxShape.circle) {
      return ClipOval(child: blurredBackground);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: blurredBackground,
    );
  }
}

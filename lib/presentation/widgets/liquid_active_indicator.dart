import 'package:flutter/material.dart';
import 'package:oc_liquid_glass/oc_liquid_glass.dart';

/// Liquid glass active indicator that creates a realistic droplet refraction effect.
/// This widget wraps the oc_liquid_glass implementation.
class LiquidActiveIndicator extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final Color? color;

  const LiquidActiveIndicator({
    super.key,
    required this.width,
    required this.height,
    required this.borderRadius,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    // The OCLiquidGlass widget creates the refraction effect
    // based on the background content behind the OCLiquidGlassGroup
    return OCLiquidGlass(
      width: width,
      height: height,
      borderRadius: borderRadius,
      // Use provided color or transparent fallback
      color: color ?? Colors.transparent,
      child: const SizedBox(),
    );
  }
}

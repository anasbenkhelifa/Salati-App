import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/theme/app_theme.dart';

/// The Salati app mark (rounded-square lapis & gold logo) rendered from
/// the bundled SVG — crisp at any size.
class SalatiLogo extends StatelessWidget {
  final double size;

  /// Adds the theme glow behind the logo (hero placements).
  final bool glow;

  const SalatiLogo({super.key, required this.size, this.glow = false});

  @override
  Widget build(BuildContext context) {
    final logo = ClipRRect(
      // Matches the SVG's own corner radius (19/96)
      borderRadius: BorderRadius.circular(size * 0.2),
      child: SvgPicture.asset(
        'assets/icon_source/salati-icon-512.svg',
        width: size,
        height: size,
      ),
    );
    if (!glow) return logo;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.2),
        boxShadow: AppTheme.glowShadow(intensity: 0.9),
      ),
      child: logo,
    );
  }
}
